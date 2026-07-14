local MT = MinnTinkers

local module = {
    name = "Vengeful Pact stance",
    desc = "Shows a one-click Vengeful Pact button when entering a dungeon. It does not keep forcing the pact after you change it manually.",
    category = "Felsworn",
    characterRule = {
        class = "Felsworn"
    },
    defaults = {
        enabled = true,
        spellID = 803882,
        spellName = "Vengeful Pact",
        delay = 1.5,
        useInDungeons = true,
        useInRaids = false,
        printReminder = false,
        checkInterval = 2,
        postClickCheckDuration = 8
    }
}

function module:GetDB(core)
    return core:GetModuleDB(self.key)
end

function module:ResolveSpell(core)
    local db = self:GetDB(core)
    if not db then return nil, nil end

    local spellID = tonumber(db.spellID) or 803882
    local spellName = nil

    if GetSpellInfo then
        spellName = GetSpellInfo(spellID)
    end

    if not spellName or spellName == "" then
        spellName = db.spellName or "Vengeful Pact"
    end

    return spellID, spellName
end

function module:HasPactBuff(core)
    local spellID, spellName = self:ResolveSpell(core)
    if not spellID and not spellName then return false end

    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, auraSpellID = UnitBuff("player", i)

        if not name then
            break
        end

        if auraSpellID and spellID and tonumber(auraSpellID) == tonumber(spellID) then
            return true
        end

        if spellName and (name == spellName or (core.NameMatches and core:NameMatches(name, spellName))) then
            return true
        end
    end

    return false
end

function module:ShouldOfferPact(core)
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

    local button = CreateFrame("Button", "MinnTinkersVengefulPactButton", UIParent, "SecureActionButtonTemplate")
    button:SetWidth(180)
    button:SetHeight(28)
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    if core.EnsureButtonFontString then
        core:EnsureButtonFontString(button)
    end
    button:SetText("Cast Vengeful Pact")
    button:RegisterForClicks("AnyUp")
    button:Hide()

    button.minnTooltipTitle = "Minn Tinkers"
    button.minnTooltipText = "Click to cast the configured pact. WoW blocks addons from casting this automatically on dungeon entry."

    if core.SkinSpellButton then
        core:SkinSpellButton(button, button:GetText())
    end

    button:SetScript("PostClick", function()
        module:ScheduleButtonCheck(core, 0.4)
    end)

    self.button = button
    return button
end

function module:ConfigureButton(core)
    local _, spellName = self:ResolveSpell(core)

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

function module:ShowPactButton(core, manual)
    local db = self:GetDB(core)
    if not db then return end

    if not core:ModuleAllowedForCharacter(self.key, manual) then
        self:HideButton()
        return
    end

    if not manual and not self:ShouldOfferPact(core) then
        self:HideButton()
        return
    end

    if self:HasPactBuff(core) then
        self:HideButton()
        if manual then
            local _, spellName = self:ResolveSpell(core)
            core:Print(tostring(spellName or "Configured pact") .. " is already active.")
        end
        return
    end

    local spellID, spellName = self:ResolveSpell(core)

    if not spellName or spellName == "" then
        if manual then
            core:Print("Could not find configured pact spell. Current spell ID: " .. tostring(spellID or "nil"))
        end
        return
    end

    if not self:ConfigureButton(core) then
        if manual then
            core:Print("Cannot prepare pact button while in combat. Try again after combat.")
        end
        return
    end

    local button = self:CreateButton(core)
    button:Show()

    local instanceKey = self:GetInstanceKey()

    if manual or (db.printReminder and self.printedForInstanceKey ~= instanceKey) then
        core:Print("Click the Vengeful Pact button to cast " .. tostring(spellName) .. ".")
        self.printedForInstanceKey = instanceKey
    end
end

function module:ScheduleButtonCheck(core, delay)
    self.nextButtonCheck = delay or 0.5
    self.buttonCheckElapsed = 0
    self.buttonCheckStartedAt = GetTime and GetTime() or 0
end

function module:OnDungeonEntry(core)
    if not self:ShouldOfferPact(core) then
        self:HideButton()
        return
    end

    local instanceKey = self:GetInstanceKey()

    if self.lastInstanceKey == instanceKey then
        if self.button and self.button:IsShown() and self:HasPactBuff(core) then
            self:HideButton()
        end
        return
    end

    self.lastInstanceKey = instanceKey
    self.printedForInstanceKey = nil
    self:ShowPactButton(core, false)
end

function module:ScheduleDungeonEntry(core, delay)
    self.nextEntryCheck = delay or 1.5
    self.entryElapsed = 0
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

    if self.nextButtonCheck then
        self.buttonCheckElapsed = (self.buttonCheckElapsed or 0) + elapsed
        if self.buttonCheckElapsed >= self.nextButtonCheck then
            self.buttonCheckElapsed = 0

            if self:HasPactBuff(core) then
                self.nextButtonCheck = nil
                self:HideButton()
            else
                local now = GetTime and GetTime() or 0
                local started = tonumber(self.buttonCheckStartedAt or now) or now
                local maxDuration = tonumber(db.postClickCheckDuration) or 8

                if now > 0 and started > 0 and (now - started) >= maxDuration then
                    self.nextButtonCheck = nil
                else
                    self.nextButtonCheck = 0.75
                end
            end
        end
    end

    self.pulseElapsed = (self.pulseElapsed or 0) + elapsed
    if self.pulseElapsed >= (tonumber(db.checkInterval) or 2) then
        self.pulseElapsed = 0

        if self.button and self.button:IsShown() and self:HasPactBuff(core) then
            self:HideButton()
        end
    end
end

function module:OnEvent(core, event, arg1)
    local db = self:GetDB(core)
    if not db then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        self:ScheduleDungeonEntry(core, db.delay or 1.5)
        return
    end

    if event == "UNIT_AURA" and arg1 == "player" then
        if self:HasPactBuff(core) then
            self:HideButton()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if self.pendingHide then
            self:HideButton()
        end

        if self.needsButtonUpdate then
            self.needsButtonUpdate = false
            self:ShowPactButton(core, false)
        end
    end
end

function module:OnEnable(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(frame, event, arg1)
            module:OnEvent(core, event, arg1)
        end)
    end

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
    self.nextButtonCheck = nil
    self.buttonCheckElapsed = nil
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}

    local printReminder = core:CreateCheckbox(
        panel,
        "MinnTinkers_VengefulPact_PrintReminder",
        "Print pact reminder",
        "Print pact reminder",
        "Shows one chat reminder when the one-click pact button appears.",
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
        "MinnTinkers_VengefulPact_UseRaids",
        "Also offer pact in raids",
        "Also offer pact in raids",
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

MT:RegisterModule("VengefulPact", module)
