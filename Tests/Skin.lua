local MT = {}
MinnTinkers = MT

GameFontHighlightSmall = {}

hooksecurefunc = function(target, methodName, hook)
    local original = target[methodName]
    target[methodName] = function(self, ...)
        local results = { original(self, ...) }
        hook(self, ...)
        return unpack(results)
    end
end

dofile("Skin.lua")

local function new_texture()
    return {
        hidden = false,
        shown = false,
        points = {},
        Hide = function(self) self.hidden = true self.shown = false end,
        Show = function(self) self.shown = true self.hidden = false end,
        SetParent = function(self, parent)
            self.parent = parent
            if self.owner and parent ~= self.owner then
                self.owner.checkedTexture = nil
            end
        end,
        ClearAllPoints = function(self) self.points = {} end,
        SetPoint = function(self, ...) table.insert(self.points, { ... }) end
    }
end

local function new_text()
    return {
        fontObject = nil,
        color = nil,
        SetFontObject = function(self, fontObject) self.fontObject = fontObject end,
        SetTextColor = function(self, ...) self.color = { ... } end
    }
end

local function new_checkbox(name)
    local checkbox = { name = name, checked = true, hooks = {} }
    function checkbox:GetName() return self.name end
    function checkbox:GetChecked() return self.checked end
    function checkbox:SetChecked(checked)
        self.checked = checked and true or false
    end
    function checkbox:GetCheckedTexture() return self.checkedTexture end
    function checkbox:HookScript(scriptName, handler) self.hooks[scriptName] = handler end
    return checkbox
end

local function install_named_regions(name)
    local regions = {
        Left = new_texture(),
        Middle = new_texture(),
        Right = new_texture(),
        Text = new_text()
    }
    for suffix, region in pairs(regions) do
        _G[name .. suffix] = region
    end
    return regions
end

_G.ElvUI = nil
_G.E = nil
IsAddOnLoaded = function() return false end

local vanilla = new_checkbox("MinnTinkersSkinTestVanilla")
local vanillaRegions = install_named_regions(vanilla.name)
MT:SkinCheckBox(vanilla)
assert(not vanilla.minnElvUISkinned, "vanilla checkbox was marked as ElvUI-skinned")
assert(vanillaRegions.Left.hidden and vanillaRegions.Middle.hidden and vanillaRegions.Right.hidden, "vanilla checkbox fallback did not hide Blizzard regions")
assert(vanillaRegions.Text.fontObject == GameFontHighlightSmall, "vanilla checkbox text font was not preserved")

local handledCheckbox
local skins = {
    HandleCheckBox = function(_, checkbox)
        handledCheckbox = checkbox
        checkbox.elvSkinApplied = true
        checkbox.backdrop = {}
        checkbox.checkedTexture = new_texture()
        checkbox.checkedTexture.parent = checkbox
        checkbox.checkedTexture.owner = checkbox
    end
}
local engine = {
    GetModule = function(_, moduleName, silent)
        assert(moduleName == "Skins" and silent == true, "wrong ElvUI module lookup")
        return skins
    end
}
_G.ElvUI = { engine }

local elv = new_checkbox("MinnTinkersSkinTestElv")
local elvRegions = install_named_regions(elv.name)
MT:SkinCheckBox(elv)
local elvIndicator = elv.minnElvUICheckedTexture
assert(handledCheckbox == elv, "ElvUI did not receive the Minn Tinkers checkbox")
assert(elv.minnElvUISkinned, "successful ElvUI checkbox skinning was not recorded")
assert(elv:GetCheckedTexture() == nil, "test client did not reproduce the checked-texture lookup loss")
assert(elvIndicator and elvIndicator.parent == elv.backdrop, "ElvUI checked texture was not retained and reparented to its visible backdrop")
assert(table.getn(elvIndicator.points) == 2, "ElvUI checked texture was not anchored to both sides of its backdrop")
assert(elvIndicator.points[1][1] == "TOPLEFT" and elvIndicator.points[1][2] == elv.backdrop, "ElvUI checked texture used the wrong top-left anchor")
assert(elvIndicator.points[2][1] == "BOTTOMRIGHT" and elvIndicator.points[2][2] == elv.backdrop, "ElvUI checked texture used the wrong bottom-right anchor")
assert(elvIndicator.shown and not elvIndicator.hidden, "initial active checkbox state was not shown")
elv:SetChecked(false)
assert(elvIndicator.hidden and not elvIndicator.shown, "programmatic checkbox disable did not hide the ElvUI indicator")
elv:SetChecked(true)
assert(elvIndicator.shown and not elvIndicator.hidden, "programmatic checkbox enable did not show the ElvUI indicator")
elv.checked = false
elv.hooks.OnClick(elv)
assert(elvIndicator.hidden and not elvIndicator.shown, "clicked checkbox state did not hide the ElvUI indicator")
assert(not elvRegions.Left.hidden and not elvRegions.Middle.hidden and not elvRegions.Right.hidden, "vanilla fallback ran after successful ElvUI skinning")
assert(elvRegions.Text.fontObject == GameFontHighlightSmall, "ElvUI-skinned checkbox text was not preserved")

skins.HandleCheckBox = function()
    error("simulated ElvUI skin failure")
end

local failed = new_checkbox("MinnTinkersSkinTestFailedElv")
local failedRegions = install_named_regions(failed.name)
local ok = pcall(MT.SkinCheckBox, MT, failed)
assert(ok, "ElvUI skin failure escaped into Minn Tinkers")
assert(not failed.minnElvUISkinned, "failed ElvUI skinning was recorded as successful")
assert(failedRegions.Left.hidden and failedRegions.Middle.hidden and failedRegions.Right.hidden, "failed ElvUI skinning did not use the vanilla fallback")

print("Skin tests passed")
