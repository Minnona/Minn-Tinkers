local MT = MinnTinkers

local module = {
    name = "Man'ari Intuition buff",
    desc = "Shows a one-click self-buff button for Man'ari Intuition when it is missing or about to expire in a dungeon.",
    category = "Felsworn",
    characterRule = {
        class = "Felsworn"
    },
    defaults = {
        enabled = true,
        spellName = "Man'ari Intuition",
        delay = 1.5,
        refreshThreshold = 300,
        checkInterval = 5,
        useInDungeons = true,
        useInRaids = false,
        printReminder = false
    }
}

local function FormatTime(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < 0 then seconds = 0 end

    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds - minutes * 60)

    if minutes >= 60 then
        local hours = math.floor(minutes / 60)
        local leftoverMinutes = minutes - hours * 60
        return tostring(hours) .. "h " .. tostring(leftoverMinutes) .. "m"
    end

    if minutes > 0 then
        return tostring(minutes) .. "m " .. tostring(remainingSeconds) .. "s"
    end

    return tostring(remainingSeconds) .. "s"
end

function module:GetDB(core)
    return core:GetModuleDB(self.key)
end

function module:ResolveSpell(core)
    local db = self:GetDB(core)
    if not db then return nil end

    local spellName = db.spellName or "Man'ari Intuition"

    spellName = string.gsub(tostring(spellName or ""), "^%s+", "")
    spellName = string.gsub(spellName, "%s+$", "")

    if spellName == "" then
        spellName = "Man'ari Intuition"
    end

    return spellName
end

function module:GetBuffInfo(core)
    local spellName = self:ResolveSpell(core)
    if not spellName or spellName == "" then return false, nil, nil, nil end

    for i = 1, 40 do
        local name, _, _, _, _, duration, expirationTime = UnitBuff("player", i)

        if not name then
            break
        end

        if name == spellName then
            local remaining = nil

            if expirationTime and expirationTime > 0 then
                remaining = expirationTime - GetTime()
                if remaining < 0 then remaining = 0 end
            end

            return true, remaining, duration, name
        end
    end

    return false, nil, nil, nil
end

function module:NeedsBuff(core)
    local db = self:GetDB(core)
    if not db then return false, nil, nil end

    local hasBuff, remaining, duration, buffName = self:GetBuffInfo(core)

    if not hasBuff then
        return true, remaining, buffName
    end

    if remaining and remaining <= (tonumber(db.refreshThreshold) or 300) then
        return true, remaining, buffName
    end

    return false, remaining, buffName
end

function module:ShouldOfferBuff(core)
    local db = self:GetDB(core)
    if not db then return false end

    if not core:ModuleAllowedForCharacter(self.key, false) then
        self.lastInstanceKey = nil
        self.printedForInstanceKey = nil
        return false
    end

    local inInstance, instanceType = IsInInstance()

    if not inInstance then
        self.lastInstanceKey = nil
        self.printedForInstanceKey = nil
        return false
    end

    if instanceType == "party" and db.useInDungeons then
        return true
    end

    if instanceType == "raid" and db.useInRaids then
        return true
    end

    return false
end

function module:GetInstanceKey()
    local name = nil

    if GetInstanceInfo then
        name = GetInstanceInfo()
    end

    if not name or name == "" then
        name = GetRealZoneText and GetRealZoneText() or "unknown"
    end

    local _, instanceType = IsInInstance()
    return tostring(instanceType or "none") .. ":" .. tostring(name or "unknown")
end

function module:CreateButton(core)
    if self.button then return self.button end

    local button = CreateFrame("Button", "MinnTinkersManariIntuitionButton", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    button:SetWidth(190)
    button:SetHeight(28)
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -155)
    button:SetText("Cast Man'ari Intuition")
    button:RegisterForClicks("AnyUp")
    button:Hide()

    button.minnTooltipTitle = "Minn Tinkers"
    button.minnTooltipText = "Click to cast Man'ari Intuition on yourself when the buff is missing or close to expiring."

    if core.SkinSpellButton then
        core:SkinSpellButton(button, button:GetText())
    end

    button:SetScript("PostClick", function()
        module.nextImmediateCheck = 0.4
    end)

    self.button = button
    return button
end

function module:ConfigureButton(core)
    local spellName = self:ResolveSpell(core)

    if not spellName or spellName == "" then
        return false
    end

    local button = self:CreateButton(core)

    if InCombatLockdown and InCombatLockdown() then
        self.needsButtonUpdate = true
        return false
    end

    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", spellName)
    button:SetAttribute("unit", "player")
    button:SetText("Cast " .. spellName)

    if core.SkinSpellButton then
        core:SkinSpellButton(button, spellName)
    end

    return true
end

function module:HideButton()
    if not self.button then return end

    if InCombatLockdown and InCombatLockdown() then
        self.pendingHide = true
        return
    end

    self.button:Hide()
    self.pendingHide = false
end

function module:ShowBuffButton(core, manual)
    local db = self:GetDB(core)
    if not db then return end

    if not core:ModuleAllowedForCharacter(self.key, manual) then
        self:HideButton()
        return
    end

    if not manual and not self:ShouldOfferBuff(core) then
        self:HideButton()
        return
    end

    local needsBuff, remaining = self:NeedsBuff(core)

    if not needsBuff then
        self:HideButton()

        if manual then
            local spellName = self:ResolveSpell(core)
            if remaining then
                core:Print(tostring(spellName or "Configured buff") .. " is active for another " .. FormatTime(remaining) .. ".")
            else
                core:Print(tostring(spellName or "Configured buff") .. " is already active.")
            end
        end

        return
    end

    local spellName = self:ResolveSpell(core)

    if not spellName or spellName == "" then
        if manual then
            core:Print("Could not find configured Man'ari Intuition spell name.")
        end
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self.pendingShow = true
        return
    end

    if not self:ConfigureButton(core) then
        if manual then
            core:Print("Cannot prepare Man'ari Intuition button while in combat. Try again after combat.")
        end
        return
    end

    local button = self:CreateButton(core)
    button:Show()
    self.pendingShow = false

    local instanceKey = self:GetInstanceKey()

    if manual or (db.printReminder and self.printedForInstanceKey ~= instanceKey) then
        if remaining then
            core:Print("Click the Man'ari Intuition button to refresh " .. tostring(spellName) .. ". Remaining: " .. FormatTime(remaining) .. ".")
        else
            core:Print("Click the Man'ari Intuition button to cast " .. tostring(spellName) .. ".")
        end
        self.printedForInstanceKey = instanceKey
    end
end

function module:OnDungeonEntry(core)
    if not self:ShouldOfferBuff(core) then
        self:HideButton()
        return
    end

    local instanceKey = self:GetInstanceKey()

    if self.lastInstanceKey ~= instanceKey then
        self.lastInstanceKey = instanceKey
        self.printedForInstanceKey = nil
    end

    self:ShowBuffButton(core, false)
end

function module:OnUpdate(core, elapsed)
    local db = self:GetDB(core)
    if not db then return end

    if self.nextEntryCheck then
        self.entryElapsed = (self.entryElapsed or 0) + elapsed
        if self.entryElapsed >= self.nextEntryCheck then
            self.nextEntryCheck = nil
            self.entryElapsed = 0
            self:OnDungeonEntry(core)
        end
    end

    if self.nextImmediateCheck then
        self.immediateElapsed = (self.immediateElapsed or 0) + elapsed
        if self.immediateElapsed >= self.nextImmediateCheck then
            self.nextImmediateCheck = nil
            self.immediateElapsed = 0
            self:ShowBuffButton(core, false)
        end
    end

    self.pulseElapsed = (self.pulseElapsed or 0) + elapsed
    if self.pulseElapsed >= (tonumber(db.checkInterval) or 5) then
        self.pulseElapsed = 0
        self:ShowBuffButton(core, false)
    end
end

function module:ScheduleDungeonEntry(core, delay)
    self.nextEntryCheck = delay or 1.5
    self.entryElapsed = 0
end

function module:OnEvent(core, event, arg1)
    local db = self:GetDB(core)
    if not db then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        self:ScheduleDungeonEntry(core, db.delay or 1.5)
        return
    end

    if event == "UNIT_AURA" and arg1 == "player" then
        self:ShowBuffButton(core, false)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if self.pendingHide then
            self:HideButton()
        end

        if self.needsButtonUpdate or self.pendingShow then
            self.needsButtonUpdate = false
            self.pendingShow = false
            self:ShowBuffButton(core, false)
        end
    end
end

function module:OnEnable(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
    end

    self.frame:SetScript("OnEvent", function(frame, event, arg1)
        module:OnEvent(core, event, arg1)
    end)

    self.frame:SetScript("OnUpdate", function(frame, elapsed)
        module:OnUpdate(core, elapsed)
    end)

    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self.frame:RegisterEvent("RAID_ROSTER_UPDATE")
    self.frame:RegisterEvent("UNIT_AURA")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    local db = self:GetDB(core)
    self:ScheduleDungeonEntry(core, db and db.delay or 1.5)
end

function module:OnDisable(core)
    if self.frame then
        self.frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        self.frame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
        self.frame:UnregisterEvent("PARTY_MEMBERS_CHANGED")
        self.frame:UnregisterEvent("RAID_ROSTER_UPDATE")
        self.frame:UnregisterEvent("UNIT_AURA")
        self.frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        self.frame:SetScript("OnUpdate", nil)
    end

    self:HideButton()
    self.lastInstanceKey = nil
    self.printedForInstanceKey = nil
    self.nextEntryCheck = nil
    self.nextImmediateCheck = nil
    self.pendingShow = nil
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}

    local printReminder = core:CreateCheckbox(
        panel,
        "MinnTinkers_ManariIntuition_PrintReminder",
        "Print Man'ari Intuition reminder",
        "Print Man'ari Intuition reminder",
        "Shows one chat reminder when the one-click Man'ari Intuition button appears.",
        42,
        y,
        core:GetModuleDB(self.key).printReminder,
        function(checked)
            core:GetModuleDB(module.key).printReminder = checked
        end
    )

    core.optionControls[self.key].printReminder = printReminder
    y = y - 30

    local useRaids = core:CreateCheckbox(
        panel,
        "MinnTinkers_ManariIntuition_UseRaids",
        "Also offer Man'ari Intuition in raids",
        "Also offer Man'ari Intuition in raids",
        "Disabled by default. The module normally only appears in 5-man dungeons.",
        42,
        y,
        core:GetModuleDB(self.key).useInRaids,
        function(checked)
            core:GetModuleDB(module.key).useInRaids = checked
        end
    )

    core.optionControls[self.key].useInRaids = useRaids

    return y - 30
end

function module:RefreshOptions(core)
    local controls = core.optionControls[self.key]
    local db = core:GetModuleDB(self.key)

    if not controls or not db then return end

    if controls.printReminder then
        controls.printReminder:SetChecked(db.printReminder and true or false)
    end

    if controls.useInRaids then
        controls.useInRaids:SetChecked(db.useInRaids and true or false)
    end
end

MT:RegisterModule("ManariIntuition", module)
