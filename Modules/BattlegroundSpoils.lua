local MT = MinnTinkers

local module = {
    name = "Battleground Spoils Auto-Select",
    desc = "Automatically selects the only real stat choice from Battleground Spoils gossip windows.",
    category = "Universal",
    defaults = {
        enabled = true,
        scanSeconds = 1.0,
        scanInterval = 0.05
    }
}

local SPOILS_TITLE = "battleground spoils"

local STAT_WORDS = {
    strength = true,
    agility = true,
    stamina = true,
    intellect = true,
    spirit = true
}

local CANCEL_WORDS = {
    ["nevermind"] = true,
    ["nevermind."] = true,
    ["never mind"] = true,
    ["never mind."] = true,
    ["goodbye"] = true,
    ["goodbye."] = true,
    ["cancel"] = true,
    ["cancel."] = true
}

local function now()
    return GetTime and GetTime() or 0
end

local function trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function lower(text)
    return string.lower(tostring(text or ""))
end

local function clean_option(text)
    text = tostring(text or "")
    text = string.gsub(text, "|T.-|t", "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = trim(text)
    return text
end

local function safe_register(frame, event)
    if frame and event then pcall(frame.RegisterEvent, frame, event) end
end

local function safe_unregister(frame, event)
    if frame and event then pcall(frame.UnregisterEvent, frame, event) end
end

function module:GetDB(core)
    return core:GetModuleDB(self.key)
end

function module:GetFrameText(globalName)
    local frame = _G[globalName]
    if frame and frame.GetText then
        local text = frame:GetText()
        if text and text ~= "" then return tostring(text) end
    end
    return nil
end

function module:GetWindowTitle()
    local names = {
        "GossipFrameNpcNameText",
        "GossipFrameTitleText",
        "GossipFrameGreetingNpcNameText",
        "ItemTextTitleText",
        "QuestFrameNpcNameText"
    }

    for _, globalName in ipairs(names) do
        local text = self:GetFrameText(globalName)
        if text and text ~= "" then return text end
    end

    if UnitName then
        local npcName = UnitName("npc")
        if npcName and npcName ~= "" then return tostring(npcName) end
    end

    return nil
end

function module:GetGreetingText()
    if GetGossipText then
        local text = GetGossipText()
        if text and text ~= "" then return tostring(text) end
    end

    local names = {
        "GossipFrameGreetingText",
        "GossipGreetingText",
        "GossipFrameGreetingPanelText"
    }

    for _, globalName in ipairs(names) do
        local text = self:GetFrameText(globalName)
        if text and text ~= "" then return text end
    end

    return ""
end

function module:IsSpoilsWindow()
    local title = lower(self:GetWindowTitle() or "")
    if title == SPOILS_TITLE then return true end

    local greeting = lower(self:GetGreetingText() or "")
    if string.find(greeting, "choose a primary stat", 1, true) and string.find(greeting, "receive equipment", 1, true) then
        return true
    end

    return false
end

function module:IsCancelOption(text)
    text = lower(clean_option(text))
    text = string.gsub(text, "%s+", " ")
    return CANCEL_WORDS[text] and true or false
end

function module:IsStatOption(text)
    text = lower(clean_option(text))
    text = string.gsub(text, "[%p%c]", "")
    text = trim(text)
    return STAT_WORDS[text] and true or false
end

function module:GetSpoilsChoices()
    local statChoices = {}
    local unknownChoices = {}

    if not GetGossipOptions then return statChoices, unknownChoices end

    local options = { GetGossipOptions() }
    for i = 1, table.getn(options), 2 do
        local text = options[i]
        local optionIndex = math.floor((i + 1) / 2)
        local cleaned = clean_option(text)

        if cleaned and cleaned ~= "" then
            if self:IsCancelOption(cleaned) then
                -- Ignore close/cancel options.
            elseif self:IsStatOption(cleaned) then
                table.insert(statChoices, { index = optionIndex, text = cleaned })
            else
                table.insert(unknownChoices, { index = optionIndex, text = cleaned })
            end
        end
    end

    return statChoices, unknownChoices
end

function module:TrySelect(core)
    local db = self:GetDB(core)
    if not db or not db.enabled then return true end

    if not SelectGossipOption then return true end
    if not self:IsSpoilsWindow() then return true end

    local statChoices, unknownChoices = self:GetSpoilsChoices()

    if table.getn(statChoices) == 1 and table.getn(unknownChoices) == 0 then
        local choice = statChoices[1]
        pcall(SelectGossipOption, choice.index)
        return true
    end

    return true
end

function module:StopScanner()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end

    self.scanStopAt = nil
    self.scanElapsed = 0
    self.nextScanAt = 0
end

function module:StartScanner(core)
    local db = self:GetDB(core)
    if not db or not db.enabled then return end

    local scanSeconds = tonumber(db.scanSeconds) or 1.0
    if scanSeconds < 0.25 then scanSeconds = 0.25 end
    if scanSeconds > 5 then scanSeconds = 5 end

    self.scanStopAt = now() + scanSeconds
    self.scanElapsed = 0
    self.nextScanAt = 0

    if self.frame then
        self.frame:SetScript("OnUpdate", function(_, elapsed)
            module:OnUpdate(core, elapsed)
        end)
    end
end

function module:OnUpdate(core, elapsed)
    local db = self:GetDB(core)
    if not db or not db.enabled then self:StopScanner() return end

    local current = now()
    if self.scanStopAt and current > self.scanStopAt then
        self:StopScanner()
        return
    end

    self.scanElapsed = (self.scanElapsed or 0) + (elapsed or 0)
    local interval = tonumber(db.scanInterval) or 0.05
    if interval < 0.02 then interval = 0.02 end
    if interval > 0.5 then interval = 0.5 end

    if self.scanElapsed < (self.nextScanAt or 0) then
        return
    end

    self.nextScanAt = self.scanElapsed + interval

    if self:TrySelect(core) then
        self:StopScanner()
    end
end

function module:OnEvent(core, event)
    if event == "GOSSIP_SHOW" then
        self:StartScanner(core)
        return
    end

    if event == "GOSSIP_CLOSED" then
        self:StopScanner()
        return
    end
end

function module:OnEnable(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event)
            module:OnEvent(core, event)
        end)
    end

    safe_register(self.frame, "GOSSIP_SHOW")
    safe_register(self.frame, "GOSSIP_CLOSED")
end

function module:OnDisable(core)
    if self.frame then
        safe_unregister(self.frame, "GOSSIP_SHOW")
        safe_unregister(self.frame, "GOSSIP_CLOSED")
    end

    self:StopScanner()
end

function module:BuildOptions(core, panel, y)
    return y
end

function module:RefreshOptions(core)
end

MT:RegisterModule("BattlegroundSpoils", module)
