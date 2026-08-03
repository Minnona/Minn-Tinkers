local MT = MinnTinkers

-- Keeps crowded option pages readable by removing redundant grey footnotes.
-- Detailed descriptions still exist on checkbox/button tooltips.
local RULES = {
    MinimapButton = {
        ["Uses the built-in frog-style Hex icon"] = 0
    },
    AutoSkipGossip = {
        ["Safe mode: only skips"] = 0
    },
    WardrobeAutoAccept = {
        ["Only accepts the specific wardrobe popup"] = 0
    },
    BattlegroundSpoils = {
        ["Only works on Battleground Spoils"] = 0
    },
    PopupGuard = {
        ["Popup Guard only changes allowlisted StaticPopup dialogs"] = 0
    },
    SmartDungeonRolls = {
        ["Commands: /minn rolls"] = 30,
        ["ZG override is narrow"] = 0
    },
    RaidRollHelper = {
        ["Announcements use start/10s/5s/winner only"] = 34
    }
}

local function matches_rule(moduleKey, text, fontObject)
    if fontObject ~= "GameFontDisableSmall" then return nil end

    local rules = RULES[moduleKey]
    if not rules then return nil end

    text = tostring(text or "")
    for needle, hardAdjust in pairs(rules) do
        if string.find(text, needle, 1, true) then
            return tonumber(hardAdjust) or 0
        end
    end

    return nil
end

local function fake_text()
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

local function wrap_module(moduleKey)
    if not MT or not MT.modules then return end

    local module = MT.modules[moduleKey]
    if not module or not module.BuildOptions or module.compactOptionsWrapped then return end

    module.compactOptionsWrapped = true
    local originalBuildOptions = module.BuildOptions

    function module:BuildOptions(core, panel, y)
        if not core or not core.CreateText then
            return originalBuildOptions(self, core, panel, y)
        end

        local originalCreateText = core.CreateText
        local hardAdjust = 0

        core.CreateText = function(coreSelf, parent, text, x, textY, width, fontObject)
            local adjust = matches_rule(moduleKey, text, fontObject)
            if adjust ~= nil then
                hardAdjust = hardAdjust + adjust
                return fake_text()
            end

            return originalCreateText(coreSelf, parent, text, x, textY, width, fontObject)
        end

        local ok, resultY = pcall(originalBuildOptions, self, core, panel, y)
        core.CreateText = originalCreateText

        if not ok then
            error(resultY)
        end

        if type(resultY) == "number" then
            return resultY + hardAdjust
        end

        return resultY
    end
end

for moduleKey in pairs(RULES) do
    wrap_module(moduleKey)
end
