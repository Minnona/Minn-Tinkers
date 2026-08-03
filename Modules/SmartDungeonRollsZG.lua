local MT = MinnTinkers
local smartRolls = MT and MT.modules and MT.modules.SmartDungeonRolls

local ROLL_NEED = 1

local function lower(text)
    return string.lower(tostring(text or ""))
end

local function normalize_zone(text)
    text = lower(text)
    text = string.gsub(text, "[%s%p_%-]+", "")
    return text
end

local function is_zul_gurub()
    local instanceName, instanceType = nil, nil
    if GetInstanceInfo then
        instanceName, instanceType = GetInstanceInfo()
    end

    local zoneName = GetRealZoneText and GetRealZoneText() or nil
    local a = normalize_zone(instanceName)
    local b = normalize_zone(zoneName)

    if a == "zulgurub" or b == "zulgurub" then
        return true
    end

    return false
end

if smartRolls and not smartRolls.zgNeedPatchApplied then
    smartRolls.zgNeedPatchApplied = true
    smartRolls.defaults = smartRolls.defaults or {}
    if smartRolls.defaults.needGreenBlueInZG == nil then
        smartRolls.defaults.needGreenBlueInZG = true
    end

    local originalDoRoll = smartRolls.DoRoll

    function smartRolls:DoRoll(core, rollID)
        local db = self:GetDB(core)

        if db and db.enabled and db.needGreenBlueInZG and is_zul_gurub() and not self:IsPaused(core) then
            local info = self:GetRollInfo(rollID)
            if not info or not info.name then
                return false, "waiting for item info"
            end

            if info.quality == 2 or info.quality == 3 then
                if info.canNeed then
                    if self.PrintDecision then
                        self:PrintDecision(core, info, ROLL_NEED, "Zul'Gurub green/blue override")
                    end

                    local ok, err = pcall(RollOnLoot, rollID, ROLL_NEED)
                    if not ok and db.printDecisions then
                        local itemText = info.link or info.name or "unknown item"
                        core:Print("Roll failed on " .. tostring(itemText) .. ": " .. tostring(err))
                    end

                    return true, "Zul'Gurub green/blue need"
                end

                if db.printDecisions then
                    local itemText = info.link or info.name or "unknown item"
                    core:Print("Roll: Manual on " .. tostring(itemText) .. " (Zul'Gurub green/blue, Need unavailable).")
                end

                return true, "Zul'Gurub green/blue need unavailable"
            end
        end

        if originalDoRoll then
            return originalDoRoll(self, core, rollID)
        end

        return true, "missing original roll handler"
    end

    local originalBuildOptions = smartRolls.BuildOptions

    function smartRolls:BuildOptions(core, panel, y)
        local resultY = y
        if originalBuildOptions then
            resultY = originalBuildOptions(self, core, panel, y) or y
        end

        core.optionControls[self.key] = core.optionControls[self.key] or {}
        local controls = core.optionControls[self.key]
        local db = self:GetDB(core) or {}

        controls.needGreenBlueInZG = core:CreateCheckbox(
            panel,
            "MinnTinkers_SmartRolls_ZGNeedGreenBlue",
            "Zul'Gurub: Need all green/blue items",
            "Zul'Gurub: Need all green/blue items",
            "When inside Zul'Gurub, this rolls Need on any green or blue item if Need is available. This works even when general raid auto-rolls are disabled.",
            42,
            resultY,
            db.needGreenBlueInZG,
            function(checked)
                core:GetModuleDB(smartRolls.key).needGreenBlueInZG = checked
            end
        )
        resultY = resultY - 30

        local helpText = core:CreateText(panel, "ZG override is narrow: only Zul'Gurub, only green/blue quality, only Need when available.", 42, resultY, 520, "GameFontDisableSmall")
        resultY = resultY - math.ceil((helpText:GetStringHeight() or 24) + 12)

        return resultY
    end

    local originalRefreshOptions = smartRolls.RefreshOptions

    function smartRolls:RefreshOptions(core)
        if originalRefreshOptions then
            originalRefreshOptions(self, core)
        end

        local controls = core.optionControls and core.optionControls[self.key]
        local db = self:GetDB(core)
        if controls and controls.needGreenBlueInZG and db then
            controls.needGreenBlueInZG:SetChecked(db.needGreenBlueInZG and true or false)
        end
    end
end
