local MT = MinnTinkers

local module = {
    name = "Auto-skip gossip",
    desc = "Safely skips boring NPC gossip when there is exactly one gossip option and no quest options. Hold Shift while opening an NPC to bypass it for that interaction.",
    category = "Universal",
    defaults = {
        enabled = true,
        printSkipped = false
    }
}

local function SafeRegisterEvent(frame, event)
    if not frame or not event then return end
    pcall(frame.RegisterEvent, frame, event)
end

local function SafeUnregisterEvent(frame, event)
    if not frame or not event then return end
    pcall(frame.UnregisterEvent, frame, event)
end

function module:GetDB(core)
    return core:GetModuleDB(self.key)
end

function module:GetGossipCounts()
    local options = 0
    local activeQuests = 0
    local availableQuests = 0

    if GetNumGossipOptions then
        options = tonumber(GetNumGossipOptions()) or 0
    end

    if GetNumGossipActiveQuests then
        activeQuests = tonumber(GetNumGossipActiveQuests()) or 0
    end

    if GetNumGossipAvailableQuests then
        availableQuests = tonumber(GetNumGossipAvailableQuests()) or 0
    end

    return options, activeQuests, availableQuests
end

function module:GetFirstOptionText()
    if not GetGossipOptions then return nil end

    local optionText = GetGossipOptions()
    if optionText and optionText ~= "" then
        return tostring(optionText)
    end

    return nil
end

function module:CanSkip(core, manual)
    if self.skipThisInteraction then
        if manual then
            core:Print("Gossip auto-skip is bypassed for this NPC interaction.")
        end
        return false
    end

    if IsShiftKeyDown and IsShiftKeyDown() then
        self.skipThisInteraction = true
        if manual then
            core:Print("Gossip auto-skip bypassed while Shift is held.")
        end
        return false
    end

    local options, activeQuests, availableQuests = self:GetGossipCounts()
    local questCount = (activeQuests or 0) + (availableQuests or 0)

    if questCount > 0 then
        if manual then
            core:Print("Not skipping gossip: quest options are visible.")
        end
        return false
    end

    if options ~= 1 then
        if manual then
            core:Print("Not skipping gossip: found " .. tostring(options) .. " gossip option" .. (options == 1 and "" or "s") .. ". Safe mode only skips exactly one option.")
        end
        return false
    end

    return true
end

function module:TrySkip(core, manual)
    if not self:CanSkip(core, manual) then
        return
    end

    if not SelectGossipOption then
        if manual then
            core:Print("SelectGossipOption is not available on this client/server.")
        end
        return
    end

    local db = self:GetDB(core)
    local optionText = self:GetFirstOptionText()
    local ok, err = pcall(SelectGossipOption, 1)

    if not ok then
        if manual then
            core:Print("Could not skip gossip option: " .. tostring(err))
        end
        return
    end

    if db and db.printSkipped then
        core:Print("Skipped gossip" .. (optionText and (": " .. optionText) or "."))
    elseif manual then
        core:Print("Skipped one safe gossip option" .. (optionText and (": " .. optionText) or "."))
    end
end

function module:OnEvent(core, event)
    if event == "GOSSIP_SHOW" then
        self:TrySkip(core, false)
        return
    end

    if event == "GOSSIP_CLOSED" or event == "PLAYER_TARGET_CHANGED" then
        self.skipThisInteraction = false
        return
    end
end

function module:OnEnable(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(frame, event)
            module:OnEvent(core, event)
        end)
    end

    SafeRegisterEvent(self.frame, "GOSSIP_SHOW")
    SafeRegisterEvent(self.frame, "GOSSIP_CLOSED")
    SafeRegisterEvent(self.frame, "PLAYER_TARGET_CHANGED")
end

function module:OnDisable(core)
    if self.frame then
        SafeUnregisterEvent(self.frame, "GOSSIP_SHOW")
        SafeUnregisterEvent(self.frame, "GOSSIP_CLOSED")
        SafeUnregisterEvent(self.frame, "PLAYER_TARGET_CHANGED")
    end

    self.skipThisInteraction = false
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}

    local printSkipped = core:CreateCheckbox(
        panel,
        "MinnTinkers_AutoSkipGossip_PrintSkipped",
        "Print skipped gossip line",
        "Print skipped gossip line",
        "Shows a chat message when Minn Tinkers auto-selects a safe gossip option.",
        42,
        y,
        core:GetModuleDB(self.key).printSkipped,
        function(checked)
            core:GetModuleDB(module.key).printSkipped = checked
        end
    )

    core.optionControls[self.key].printSkipped = printSkipped
    y = y - 30

    local helpText = core:CreateText(panel, "Safe mode: only skips when there is exactly one gossip option and no quest options. Hold Shift while opening/talking to an NPC to bypass it for that interaction.", 42, y, 520, "GameFontDisableSmall")
    y = y - math.ceil((helpText:GetStringHeight() or 24) + 12)

    core:CreateOptionButton(panel, "MinnTinkers_AutoSkipGossip_TryNow", "Try current gossip", 42, y, 180, 24, function()
        module:TrySkip(core, true)
    end)

    return y - 38
end

function module:RefreshOptions(core)
    local controls = core.optionControls[self.key]
    local db = core:GetModuleDB(self.key)

    if not controls or not db then return end

    if controls.printSkipped then
        controls.printSkipped:SetChecked(db.printSkipped and true or false)
    end
end

MT:RegisterModule("AutoSkipGossip", module)
