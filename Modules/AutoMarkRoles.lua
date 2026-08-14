local MT = MinnTinkers

local module = {
    name = "Auto-mark tank/healer roles",
    desc = "Marks the detected tank with Star and healer with Moon, with optional same-dungeon memory through Mythic+ activation.",
    category = "Universal",
    defaults = {
        enabled = true,
        keepMarked = true,
        rememberDungeonRoles = true,
        tankIcon = 1,
        healerIcon = 5,
        delay = 1.5,
        markInDungeons = true,
        markInRaids = false
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

local function NormalizeName(name)
    name = string.lower(tostring(name or ""))
    name = string.gsub(name, "%-.*$", "")
    return name
end

local function IconName(icon)
    icon = tonumber(icon) or 0
    if icon == 1 then return "Star" end
    if icon == 2 then return "Circle" end
    if icon == 3 then return "Diamond" end
    if icon == 4 then return "Triangle" end
    if icon == 5 then return "Moon" end
    if icon == 6 then return "Square" end
    if icon == 7 then return "Cross" end
    if icon == 8 then return "Skull" end
    return "Unknown"
end

function module:GetDB(core)
    return core:GetModuleDB(self.key)
end

function module:ShouldMark(core)
    local db = self:GetDB(core)
    if not db then return false end

    local inInstance, instanceType = IsInInstance()

    if not inInstance then
        return false
    end

    if instanceType == "party" and db.markInDungeons then
        return true
    end

    if instanceType == "raid" and db.markInRaids then
        return true
    end

    return false
end

function module:GetRole(unit)
    if not unit or not UnitExists(unit) then return "NONE" end

    if UnitGroupRolesAssigned then
        local role1, role2, role3 = UnitGroupRolesAssigned(unit)

        -- Newer/backported format: one string: TANK / HEALER / DAMAGER / NONE.
        if type(role1) == "string" then
            if role1 ~= "" then
                return role1
            end
            return "NONE"
        end

        -- WotLK/private-server format: three booleans: tank, healer, damage.
        if role1 == true then
            return "TANK"
        end

        if role2 == true then
            return "HEALER"
        end

        if role3 == true then
            return "DAMAGER"
        end
    end

    return "NONE"
end

function module:GetRawRoleText(unit)
    if not unit or not UnitExists(unit) then return "missing" end

    if not UnitGroupRolesAssigned then
        return "UnitGroupRolesAssigned unavailable"
    end

    local role1, role2, role3 = UnitGroupRolesAssigned(unit)
    return tostring(role1) .. ", " .. tostring(role2) .. ", " .. tostring(role3)
end

function module:GetUnitLabel(unit)
    if not unit or not UnitExists(unit) then
        return tostring(unit or "unknown")
    end

    local name, realm = UnitName(unit)
    if not name or name == "" then
        return tostring(unit)
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

function module:UnitAlreadyListed(unit, seen)
    if not unit or not UnitExists(unit) then return true end

    local guid = UnitGUID and UnitGUID(unit)
    if guid then
        if seen[guid] then
            return true
        end
        seen[guid] = true
        return false
    end

    local name = UnitName(unit)
    if name then
        if seen[name] then
            return true
        end
        seen[name] = true
    end

    return false
end

function module:GetGroupUnits()
    local units = {}
    local seen = {}

    if UnitInRaid and UnitInRaid("player") then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and not self:UnitAlreadyListed(unit, seen) then
                table.insert(units, unit)
            end
        end
    else
        if UnitExists("player") and not self:UnitAlreadyListed("player", seen) then
            table.insert(units, "player")
        end

        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and not self:UnitAlreadyListed(unit, seen) then
                table.insert(units, unit)
            end
        end
    end

    return units
end

function module:GetDungeonKey()
    if not IsInInstance then return nil end
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "party" then return nil end

    local instanceName, instanceID = nil, nil
    if GetInstanceInfo then
        instanceName, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    end
    if tonumber(instanceID) and tonumber(instanceID) > 0 then return "instance:" .. tostring(instanceID) end
    instanceName = tostring(instanceName or "")
    if instanceName == "" then return nil end
    return string.lower(instanceName)
end

function module:ClearRoleMemory()
    self.roleMemory = nil
end

function module:SyncRoleMemory(core)
    local db = self:GetDB(core)
    if not db or not db.rememberDungeonRoles then
        self:ClearRoleMemory()
        return nil
    end

    local instanceKey = self:GetDungeonKey()
    if not instanceKey then
        self:ClearRoleMemory()
        return nil
    end

    if self.roleMemory and self.roleMemory.instanceKey ~= instanceKey then
        self:ClearRoleMemory()
    end

    self.roleMemory = self.roleMemory or { instanceKey = instanceKey }
    return self.roleMemory
end

function module:GetUnitIdentity(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return nil end
    local name = UnitName and UnitName(unit) or nil
    local guid = UnitGUID and UnitGUID(unit) or nil
    if not guid and not name then return nil end
    return { guid = guid, name = name }
end

function module:FindRememberedUnit(identity)
    if type(identity) ~= "table" then return nil end
    for _, unit in ipairs(self:GetGroupUnits()) do
        local guid = UnitGUID and UnitGUID(unit) or nil
        if identity.guid and guid and identity.guid == guid then return unit end
        if not identity.guid and NormalizeName(identity.name) ~= "" and NormalizeName(UnitName and UnitName(unit) or nil) == NormalizeName(identity.name) then
            return unit
        end
    end
    return nil
end

function module:GetMarkedRoleUnits(core)
    local db = self:GetDB(core)
    if not db or not GetRaidTargetIndex then return nil, nil end

    local tankIcon = self:NormalizeIcon(db.tankIcon, 1)
    local healerIcon = self:NormalizeIcon(db.healerIcon, 5)
    local tankUnit, healerUnit = nil, nil
    for _, unit in ipairs(self:GetGroupUnits()) do
        local icon = GetRaidTargetIndex(unit)
        if icon == tankIcon and not tankUnit then tankUnit = unit end
        if icon == healerIcon and not healerUnit then healerUnit = unit end
    end
    return tankUnit, healerUnit
end

function module:RememberRoleUnits(core, tankUnit, healerUnit)
    local memory = self:SyncRoleMemory(core)
    if not memory then return end
    if tankUnit then memory.tank = self:GetUnitIdentity(tankUnit) end
    if healerUnit then memory.healer = self:GetUnitIdentity(healerUnit) end
end

function module:GetRoleUnits(core)
    local tankUnit = nil
    local healerUnit = nil
    local units = self:GetGroupUnits()

    for _, unit in ipairs(units) do
        local role = self:GetRole(unit)

        if role == "TANK" and not tankUnit then
            tankUnit = unit
        elseif role == "HEALER" and not healerUnit then
            healerUnit = unit
        end

        if tankUnit and healerUnit then
            break
        end
    end

    return tankUnit, healerUnit
end

function module:ResolveRoleUnits(core)
    local tankUnit, healerUnit = self:GetRoleUnits(core)
    local memory = self:SyncRoleMemory(core)
    if not memory then return tankUnit, healerUnit, false end

    if tankUnit or healerUnit then
        self:RememberRoleUnits(core, tankUnit, healerUnit)
    end

    if not memory.tank or not memory.healer then
        local markedTank, markedHealer = self:GetMarkedRoleUnits(core)
        if not memory.tank and markedTank then memory.tank = self:GetUnitIdentity(markedTank) end
        if not memory.healer and markedHealer then memory.healer = self:GetUnitIdentity(markedHealer) end
    end

    local usedMemory = false
    if not tankUnit and memory.tank then
        tankUnit = self:FindRememberedUnit(memory.tank)
        usedMemory = tankUnit and true or usedMemory
        if not tankUnit then memory.tank = nil end
    end
    if not healerUnit and memory.healer then
        healerUnit = self:FindRememberedUnit(memory.healer)
        usedMemory = healerUnit and true or usedMemory
        if not healerUnit then memory.healer = nil end
    end

    return tankUnit, healerUnit, usedMemory
end

function module:NormalizeIcon(icon, fallback)
    icon = tonumber(icon) or fallback
    if icon < 1 or icon > 8 then icon = fallback end
    return icon
end

function module:MarkUnit(core, unit, icon, label, manual)
    if not unit or not UnitExists(unit) then
        return false, "missing"
    end

    if GetRaidTargetIndex(unit) == icon then
        return true, "already"
    end

    local ok, err = pcall(SetRaidTarget, unit, icon)

    if not ok then
        if manual then
            core:Print("Could not mark " .. label .. ". You may need leader/assist permissions. Error: " .. tostring(err))
        end
        return false, "error"
    end

    if GetRaidTargetIndex(unit) ~= icon then
        if manual then
            core:Print("Found " .. label .. " as " .. self:GetUnitLabel(unit) .. ", but " .. IconName(icon) .. " did not stick. You may need leader/assist permissions, or the server blocked the marker.")
        end
        return false, "not_stuck"
    end

    return true, "marked"
end

function module:MarkRoles(core, manual, attempt)
    local db = self:GetDB(core)
    if not db then return end

    attempt = attempt or 1

    if not manual and not self:ShouldMark(core) then
        self:SyncRoleMemory(core)
        return
    end

    local tankUnit, healerUnit, usedMemory = self:ResolveRoleUnits(core)

    if not tankUnit and not healerUnit then
        if manual then
            if UnitGroupRolesAssigned then
                core:Print("No tank or healer role found in your current party/raid, and no remembered dungeon roles are available.")
            else
                core:Print("Role API is unavailable and no remembered dungeon roles are available.")
            end
        elseif attempt < 5 then
            self:ScheduleMark(core, 1.0, attempt + 1)
        end
        return
    end

    local tankIcon = self:NormalizeIcon(db.tankIcon, 1)
    local healerIcon = self:NormalizeIcon(db.healerIcon, 5)
    local tankOK = true
    local healerOK = true

    -- Mark tank first. If the healer had Star from an old marker, this moves Star to the tank.
    if tankUnit then
        tankOK = self:MarkUnit(core, tankUnit, tankIcon, "tank", manual)
    end

    -- Then mark healer. If the tank had Moon from an old marker, this moves Moon to the healer.
    if healerUnit then
        healerOK = self:MarkUnit(core, healerUnit, healerIcon, "healer", manual)
    end

    if manual then
        if usedMemory then core:Print("Using tank/healer identities remembered for this dungeon.") end
        if tankUnit then
            core:Print("Tank: " .. self:GetUnitLabel(tankUnit) .. " -> " .. IconName(tankIcon) .. ".")
        else
            core:Print("Tank: not found.")
        end

        if healerUnit then
            core:Print("Healer: " .. self:GetUnitLabel(healerUnit) .. " -> " .. IconName(healerIcon) .. ".")
        else
            core:Print("Healer: not found.")
        end
    end

    if not manual and attempt < 3 then
        local needRetry = false

        if tankUnit and GetRaidTargetIndex(tankUnit) ~= tankIcon then
            needRetry = true
        end

        if healerUnit and GetRaidTargetIndex(healerUnit) ~= healerIcon then
            needRetry = true
        end

        if needRetry then
            self:ScheduleMark(core, 1.0, attempt + 1)
        end
    end
end

function module:ScheduleMark(core, delay, attempt)
    if not self.frame then return end

    self.pending = true
    self.elapsed = 0
    self.delay = delay or 1.0
    self.attempt = attempt or 1

    self.frame:SetScript("OnUpdate", function(frame, elapsed)
        module.elapsed = (module.elapsed or 0) + elapsed

        if module.elapsed >= (module.delay or 1.0) then
            frame:SetScript("OnUpdate", nil)
            module.pending = false
            module:MarkRoles(core, false, module.attempt or 1)
        end
    end)
end

function module:PrintRoles(core)
    if not UnitGroupRolesAssigned then
        core:Print("Role API is not available; checking remembered dungeon roles.")
    end

    core:Print("Current role scan:")

    local units = self:GetGroupUnits()
    for _, unit in ipairs(units) do
        core:Print(unit .. " - " .. self:GetUnitLabel(unit) .. " - " .. tostring(self:GetRole(unit)) .. " - raw: " .. self:GetRawRoleText(unit))
    end

    local tankUnit, healerUnit, usedMemory = self:ResolveRoleUnits(core)
    local source = usedMemory and " (remembered for this dungeon)" or ""
    core:Print("Detected tank: " .. (tankUnit and self:GetUnitLabel(tankUnit) or "none") .. source)
    core:Print("Detected healer: " .. (healerUnit and self:GetUnitLabel(healerUnit) or "none") .. source)
end

function module:OnEvent(core, event)
    local db = self:GetDB(core)
    if not db then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" or event == "LFG_ROLE_CHECK_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        self:SyncRoleMemory(core)
        self:ScheduleMark(core, db.delay or 1.5, 1)
        return
    end

    if event == "RAID_TARGET_UPDATE" and db.keepMarked then
        if self:ShouldMark(core) then
            local tankUnit, healerUnit = self:ResolveRoleUnits(core)
            local tankIcon = self:NormalizeIcon(db.tankIcon, 1)
            local healerIcon = self:NormalizeIcon(db.healerIcon, 5)
            local needMark = false

            if tankUnit and GetRaidTargetIndex(tankUnit) ~= tankIcon then
                needMark = true
            end

            if healerUnit and GetRaidTargetIndex(healerUnit) ~= healerIcon then
                needMark = true
            end

            if needMark then
                self:ScheduleMark(core, 0.2, 1)
            end
        end
    end
end

function module:OnEnable(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(frame, event)
            module:OnEvent(core, event)
        end)
    end

    SafeRegisterEvent(self.frame, "PLAYER_ENTERING_WORLD")
    SafeRegisterEvent(self.frame, "ZONE_CHANGED_NEW_AREA")
    SafeRegisterEvent(self.frame, "PARTY_MEMBERS_CHANGED")
    SafeRegisterEvent(self.frame, "RAID_ROSTER_UPDATE")
    SafeRegisterEvent(self.frame, "RAID_TARGET_UPDATE")
    SafeRegisterEvent(self.frame, "LFG_ROLE_CHECK_UPDATE")
    SafeRegisterEvent(self.frame, "PLAYER_ROLES_ASSIGNED")

    local db = self:GetDB(core)
    self:SyncRoleMemory(core)
    self:ScheduleMark(core, db and db.delay or 1.5, 1)
end

function module:OnDisable(core)
    if self.frame then
        SafeUnregisterEvent(self.frame, "PLAYER_ENTERING_WORLD")
        SafeUnregisterEvent(self.frame, "ZONE_CHANGED_NEW_AREA")
        SafeUnregisterEvent(self.frame, "PARTY_MEMBERS_CHANGED")
        SafeUnregisterEvent(self.frame, "RAID_ROSTER_UPDATE")
        SafeUnregisterEvent(self.frame, "RAID_TARGET_UPDATE")
        SafeUnregisterEvent(self.frame, "LFG_ROLE_CHECK_UPDATE")
        SafeUnregisterEvent(self.frame, "PLAYER_ROLES_ASSIGNED")
        self.frame:SetScript("OnUpdate", nil)
    end

    self.pending = false
    self:ClearRoleMemory()
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}

    local keepMarked = core:CreateCheckbox(
        panel,
        "MinnTinkers_AutoMarkRoles_KeepMarked",
        "Keep Star on tank and Moon on healer",
        "Keep Star on tank and Moon on healer",
        "If someone removes or changes the tank/healer marker, the addon will re-apply it while you are in a 5-man dungeon.",
        42,
        y,
        core:GetModuleDB(self.key).keepMarked,
        function(checked)
            core:GetModuleDB(module.key).keepMarked = checked
        end
    )

    core.optionControls[self.key].keepMarked = keepMarked
    y = y - 30

    local rememberDungeonRoles = core:CreateCheckbox(
        panel,
        "MinnTinkers_AutoMarkRoles_RememberDungeonRoles",
        "Remember tank/healer through Mythic+ activation",
        "Remember tank/healer through Mythic+ activation",
        "Remembers the Star/Moon players for the current dungeon and lets Keep Marked restore them if Mythic+ activation removes role data or raid markers. Memory is cleared when you leave or enter another dungeon.",
        42,
        y,
        core:GetModuleDB(self.key).rememberDungeonRoles,
        function(checked)
            core:GetModuleDB(module.key).rememberDungeonRoles = checked
            if not checked then module:ClearRoleMemory() end
        end
    )

    core.optionControls[self.key].rememberDungeonRoles = rememberDungeonRoles
    y = y - 30

    local markRaids = core:CreateCheckbox(
        panel,
        "MinnTinkers_AutoMarkRoles_MarkRaids",
        "Also mark tank/healer in raids",
        "Also mark tank/healer in raids",
        "Disabled by default. Leave this off unless you specifically want Star/Moon role markers in raids too.",
        42,
        y,
        core:GetModuleDB(self.key).markInRaids,
        function(checked)
            core:GetModuleDB(module.key).markInRaids = checked
        end
    )

    core.optionControls[self.key].markInRaids = markRaids

    return y - 30
end

function module:RefreshOptions(core)
    local controls = core.optionControls[self.key]
    local db = core:GetModuleDB(self.key)

    if not controls or not db then return end

    if controls.keepMarked then
        controls.keepMarked:SetChecked(db.keepMarked and true or false)
    end

    if controls.rememberDungeonRoles then
        controls.rememberDungeonRoles:SetChecked(db.rememberDungeonRoles and true or false)
    end

    if controls.markInRaids then
        controls.markInRaids:SetChecked(db.markInRaids and true or false)
    end
end

MT:RegisterModule("AutoMarkRoles", module)
