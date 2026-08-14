local captured

MinnTinkers = {
    RegisterModule = function(_, _, module)
        captured = module
    end
}

dofile("Modules/BattlegroundsPvP.lua")

local cases = {
    { "The Alliance flag was picked up by Friendlyone!", "pickup", "Alliance", "Friendlyone" },
    { "The Horde flag has been picked up by Enemyone!", "pickup", "Horde", "Enemyone" },
    { "The flag has been taken by Enemythree!", "pickup", "Neutral", "Enemythree" },
    { "Friendlytwo picked up the Horde flag!", "pickup", "Horde", "Friendlytwo" },
    { "Enemyone has taken the Alliance flag!", "pickup", "Alliance", "Enemyone" },
    { "The Alliance flag was dropped by Enemyone!", "clear", "Alliance", "Enemyone" },
    { "The Horde flag was returned to its base by Friendlyone!", "clear", "Horde", nil },
    { "Friendlyone captured the Horde flag!", "reset", "Horde", nil },
    { "The flags are now placed at their bases.", "reset", "Neutral", nil }
}

for index, test in ipairs(cases) do
    local action, flag, name = captured:ParseSystemMessage(test[1])
    assert(action == test[2], "case " .. tostring(index) .. " action was " .. tostring(action))
    assert(flag == test[3], "case " .. tostring(index) .. " flag was " .. tostring(flag))
    assert(name == test[4], "case " .. tostring(index) .. " name was " .. tostring(name))
end

assert(captured:ParseSystemMessage("The battle begins in one minute.") == nil, "unrelated message was accepted")
assert(captured:ExtractWorldStateCarrier("Flag carrier: Friendlyone") == "Friendlyone", "carrier tooltip was not parsed")
assert(captured:ExtractWorldStateCarrier("Status: At base") == nil, "base tooltip was accepted")

local raidIcon = 8
local markerCalls = 0
UnitExists = function(unit) return unit == "target" end
UnitName = function(unit) if unit == "target" then return "Enemyone" end end
GetRaidTargetIndex = function() return raidIcon end
SetRaidTarget = function(_, icon) raidIcon = icon markerCalls = markerCalls + 1 end
GetTime = function() return 10 end

local preexisting = { name = "Enemyone" }
assert(captured:TryMarkCarrier(preexisting, "enemy"), "pre-marked enemy was not discovered")
assert(preexisting.markerIcon == nil, "pre-existing Skull was incorrectly claimed")
captured:ClearCarrierMarker(preexisting)
assert(markerCalls == 0 and raidIcon == 8, "pre-existing Skull was cleared")

raidIcon = 0
local owned = { name = "Enemyone" }
assert(captured:TryMarkCarrier(owned, "enemy"), "enemy was not discovered for marking")
assert(markerCalls == 1 and owned.markerIcon == 8 and raidIcon == 8, "Skull was not applied and tracked")
captured:ClearCarrierMarker(owned)
assert(markerCalls == 2 and raidIcon == 0, "owned Skull was not cleared")

local combat = true
local function new_region()
    local region = { shown = true, mouse = true, level = 1, attributes = {} }
    function region:SetWidth() end
    function region:SetHeight() end
    function region:SetPoint() end
    function region:RegisterForClicks() end
    function region:SetFrameStrata() end
    function region:SetFrameLevel(level) self.level = level end
    function region:GetFrameLevel() return self.level end
    function region:EnableMouse(enabled) self.mouse = enabled and true or false end
    function region:SetAttribute(key, value) self.attributes[key] = value end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:SetScript() end
    function region:SetAllPoints() end
    function region:SetJustifyH() end
    function region:SetText(text) self.text = text end
    function region:CreateFontString() return new_region() end
    return region
end

UIParent = new_region()
WorldStateAlwaysUpFrame = new_region()
CreateFrame = function() return new_region() end
InCombatLockdown = function() return combat end

captured.slots = nil
assert(not captured:CreateDisplay() and captured.displayPending, "secure display was created during combat")
combat = false
assert(captured:CreateDisplay() and captured.slots, "secure display was not created after combat")

local friendlySlot = captured.slots.friendly
captured:SetSlot(friendlySlot, "Friendlyone")
assert(friendlySlot.readyName == "Friendlyone", "friendly secure target was not prepared")
assert(friendlySlot.action.attributes.macrotext == "/targetexact Friendlyone", "friendly target macro was incorrect")
assert(friendlySlot.action.mouse, "ready secure target was not clickable")

combat = true
captured:SetSlot(friendlySlot, "Friendlytwo")
assert(friendlySlot.readyName == "Friendlyone", "secure target changed during combat")
assert(friendlySlot.visual.mouse, "stale secure target was not blocked")

combat = false
captured:ApplyPendingSecure()
assert(friendlySlot.readyName == "Friendlytwo", "pending secure target was not applied")
assert(not friendlySlot.visual.mouse, "ready secure target remained blocked")

captured:SetSlot(friendlySlot, nil)
assert(not friendlySlot.action.mouse, "empty secure target still intercepted clicks")

print("BattlegroundsPvP tests passed: " .. tostring(#cases + 17))
