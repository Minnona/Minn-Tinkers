local MT = MinnTinkers

-- Compact crowded option pages by removing redundant inline notes and rarely-used
-- debug print controls. Detailed descriptions remain available through tooltips.

local function ensure_controls(core, key)
    core.optionControls[key] = core.optionControls[key] or {}
    return core.optionControls[key]
end

local function force_db_false(module, field)
    if not module or module["compactForce_" .. field] then return end
    module["compactForce_" .. field] = true

    local originalGetDB = module.GetDB
    if not originalGetDB then return end

    function module:GetDB(core)
        local db = originalGetDB(self, core)
        if db then db[field] = false end
        return db
    end
end

local function no_extra_options(moduleKey)
    local module = MT.modules and MT.modules[moduleKey]
    if not module then return end

    function module:BuildOptions(core, panel, y)
        ensure_controls(core, self.key)
        return y
    end

    function module:RefreshOptions(core)
        -- Module enable checkbox is handled by the core options builder.
    end
end

local function compact_wardrobe()
    local module = MT.modules and MT.modules.WardrobeAutoAccept
    if not module then return end

    force_db_false(module, "printAccepted")

    function module:BuildOptions(core, panel, y)
        local controls = ensure_controls(core, self.key)
        local db = self:GetDB(core)

        controls.requireRecentModifiedClick = core:CreateCheckbox(
            panel,
            "MinnTinkers_WardrobeAutoAccept_RequireClick",
            "Require recent Ctrl+Alt item click",
            "Require recent Ctrl+Alt item click",
            "Only auto-accepts wardrobe confirmations shortly after you Ctrl+Alt+Click an item from your bags.",
            42,
            y,
            db and db.requireRecentModifiedClick,
            function(checked)
                core:GetModuleDB(module.key).requireRecentModifiedClick = checked
            end
        )

        return y - 28
    end

    function module:RefreshOptions(core)
        local controls = core.optionControls and core.optionControls[self.key]
        local db = self:GetDB(core)
        if controls and controls.requireRecentModifiedClick and db then
            controls.requireRecentModifiedClick:SetChecked(db.requireRecentModifiedClick and true or false)
        end
    end
end

local function compact_minimap()
    local module = MT.modules and MT.modules.MinimapButton
    if not module then return end

    function module:BuildOptions(core, panel, y)
        local controls = ensure_controls(core, self.key)
        local db = self:GetDB(core)

        controls.lockButton = core:CreateCheckbox(
            panel,
            "MinnTinkers_MinimapButton_Lock",
            "Lock minimap button position",
            "Lock minimap button position",
            "Prevents dragging the minimap button by accident. Right-clicking the button also toggles this.",
            42,
            y,
            db and db.lockButton,
            function(checked)
                core:GetModuleDB(module.key).lockButton = checked
            end
        )
        y = y - 34

        controls.resetPosition = core:CreateOptionButton(panel, "MinnTinkers_MinimapButton_Reset", "Reset minimap position", 42, y, 170, 24, function()
            module:ResetPosition(core)
        end)

        return y - 34
    end

    function module:RefreshOptions(core)
        local controls = core.optionControls and core.optionControls[self.key]
        local db = self:GetDB(core)
        if controls and controls.lockButton and db then
            controls.lockButton:SetChecked(db.lockButton and true or false)
        end
        self:UpdatePosition(core)
    end
end

local function hidden_text_stub()
    return setmetatable({
        GetStringHeight = function() return -12 end,
        SetText = function() end,
        SetWidth = function() end,
        SetJustifyH = function() end,
        Hide = function() end,
        Show = function() end
    }, {
        __index = function()
            return function() return 0 end
        end
    })
end

local function strip_text_lines(moduleKey, rules)
    local module = MT.modules and MT.modules[moduleKey]
    if not module or not module.BuildOptions or module.compactTextWrapped then return end

    module.compactTextWrapped = true
    local originalBuildOptions = module.BuildOptions

    function module:BuildOptions(core, panel, y)
        if not core or not core.CreateText then
            return originalBuildOptions(self, core, panel, y)
        end

        local originalCreateText = core.CreateText
        local hardAdjust = 0

        core.CreateText = function(coreSelf, parent, text, x, textY, width, fontObject)
            text = tostring(text or "")
            for needle, adjust in pairs(rules or {}) do
                if string.find(text, needle, 1, true) then
                    hardAdjust = hardAdjust + (tonumber(adjust) or 0)
                    return hidden_text_stub()
                end
            end
            return originalCreateText(coreSelf, parent, text, x, textY, width, fontObject)
        end

        local ok, resultY = pcall(originalBuildOptions, self, core, panel, y)
        core.CreateText = originalCreateText

        if not ok then error(resultY) end
        if type(resultY) == "number" then return resultY + hardAdjust end
        return resultY
    end
end

if MT and MT.modules then
    force_db_false(MT.modules.AutoSkipGossip, "printSkipped")
    force_db_false(MT.modules.BattlegroundSpoils, "printSelected")

    no_extra_options("AutoSkipGossip")
    no_extra_options("BattlegroundSpoils")
    compact_wardrobe()
    compact_minimap()

    strip_text_lines("PopupGuard", {
        ["Popup Guard only changes allowlisted StaticPopup dialogs"] = 0
    })

    strip_text_lines("SmartDungeonRolls", {
        ["Commands: /minn rolls"] = 30,
        ["ZG override is narrow"] = 0
    })

    strip_text_lines("RaidRollHelper", {
        ["Announcements use start/10s/5s/winner only"] = 34
    })
end
