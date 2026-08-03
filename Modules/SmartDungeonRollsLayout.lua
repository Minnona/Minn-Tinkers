local MT = MinnTinkers
local smartRolls = MT and MT.modules and MT.modules.SmartDungeonRolls

if smartRolls and smartRolls.BuildOptions and not smartRolls.layoutNormalized then
    smartRolls.layoutNormalized = true

    local originalBuildOptions = smartRolls.BuildOptions

    local function normalize_button(button, x, width)
        if not button then return end

        local point, relativeTo, relativePoint, _, yOfs = button:GetPoint(1)
        button:ClearAllPoints()
        button:SetPoint(point or "TOPLEFT", relativeTo or button:GetParent(), relativePoint or "TOPLEFT", x, yOfs or 0)
        button:SetWidth(width)
    end

    function smartRolls:BuildOptions(core, panel, y)
        local resultY = originalBuildOptions(self, core, panel, y)
        local controls = core.optionControls and core.optionControls[self.key]
        if controls then
            local x = 42
            local width = 450
            normalize_button(controls.greenBlueMode, x, width)
            normalize_button(controls.noDisenchantFallback, x, width)
            normalize_button(controls.purpleMode, x, width)
            normalize_button(controls.recipeFallback, x, width)
            normalize_button(controls.lockboxMode, x, width)
            normalize_button(controls.otherMode, x, width)
        end
        return resultY
    end
end
