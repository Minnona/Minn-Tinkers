local captured

if not table.getn then
    table.getn = function(values) return #values end
end

MinnTinkers = {
    RegisterModule = function(_, _, module)
        captured = module
    end
}

dofile("Modules/SmartDungeonRolls.lua")

assert(captured.defaults.skipBoPConfirmations == false, "BoP confirmation skipping did not default off")

local db = {
    enabled = true,
    skipBoPConfirmations = false
}
local core = {
    GetModuleDB = function() return db end
}

local inInstance = true
local instanceType = "party"
IsInInstance = function() return inInstance, instanceType end

local confirmedSlots = {}
local confirmedRolls = {}
local hiddenPopups = {}
GetLootSlotLink = function(slotID)
    if slotID == 4 then return "|cffa335ee|Hitem:12345:0:0:0:0:0:0:0|h[Test BoP Item]|h|r" end
end
ConfirmLootSlot = function(slotID)
    table.insert(confirmedSlots, slotID)
end
ConfirmLootRoll = function(rollID, rollType)
    table.insert(confirmedRolls, { rollID = rollID, rollType = rollType })
end
StaticPopup_Hide = function(which, data)
    table.insert(hiddenPopups, { which = which, data = data })
end

assert(not captured:ConfirmBindLoot(core, 4), "disabled BoP option confirmed a direct pickup")
assert(not captured:ConfirmBoPRoll(core, 12, 1), "disabled BoP option confirmed a loot roll")
assert(table.getn(confirmedSlots) == 0 and table.getn(confirmedRolls) == 0, "disabled BoP option called a confirmation API")

db.skipBoPConfirmations = true
inInstance = false
instanceType = "none"
assert(captured:ShouldSkipBoPConfirmation(core), "enabled BoP option remained blocked outside an instance")
assert(captured:ConfirmBindLoot(core, 4), "open-world BoP pickup was not confirmed")
assert(captured:ConfirmBoPRoll(core, 10, 1), "open-world BoP roll confirmation was not accepted")
assert(confirmedSlots[1] == 4, "wrong open-world loot slot was confirmed")
assert(confirmedRolls[1].rollID == 10 and confirmedRolls[1].rollType == 1, "wrong open-world loot roll was confirmed")

inInstance = true
instanceType = "pvp"
assert(captured:ShouldSkipBoPConfirmation(core), "enabled BoP option remained blocked inside a battleground")
assert(captured:ConfirmBindLoot(core, 4), "battleground BoP pickup was not confirmed")
assert(confirmedSlots[2] == 4, "wrong battleground loot slot was confirmed")

instanceType = "party"
assert(not captured:ConfirmBindLoot(core, 0), "invalid loot slot was confirmed")
assert(not captured:ConfirmBindLoot(core, 5), "empty loot slot was confirmed")
assert(captured:ConfirmBindLoot(core, 4), "valid dungeon BoP pickup was not confirmed")
assert(confirmedSlots[3] == 4, "wrong dungeon loot slot was confirmed")
assert(hiddenPopups[4] and hiddenPopups[4].which == "LOOT_BIND", "dungeon BoP popup was not hidden")

assert(not captured:ConfirmBoPRoll(core, 0, 1), "invalid roll ID was confirmed")
assert(not captured:ConfirmBoPRoll(core, 12, 0), "Pass was treated as a BoP confirmation")
assert(not captured:ConfirmBoPRoll(core, 12, 4), "unknown roll type was confirmed")
assert(captured:ConfirmBoPRoll(core, 12, 1), "valid Need confirmation was not accepted")
assert(confirmedRolls[2].rollID == 12 and confirmedRolls[2].rollType == 1, "wrong Need roll was confirmed")
assert(hiddenPopups[5] and hiddenPopups[5].which == "CONFIRM_LOOT_ROLL" and hiddenPopups[5].data == 12, "BoP roll popup was not hidden")

instanceType = "raid"
assert(captured:ConfirmBoPRoll(core, 13, 2), "valid raid Greed confirmation was not accepted")
assert(confirmedRolls[3].rollType == 2, "wrong Greed roll type was confirmed")

local registered = {}
local unregistered = {}
local scripts = {}
CreateFrame = function()
    local frame = {}
    function frame:RegisterEvent(event) registered[event] = true end
    function frame:UnregisterEvent(event) unregistered[event] = true end
    function frame:SetScript(kind, handler) scripts[kind] = handler end
    return frame
end

captured.frame = nil
captured:OnEnable(core)
assert(registered.START_LOOT_ROLL, "loot roll event was not registered")
assert(registered.LOOT_BIND_CONFIRM, "direct BoP confirmation event was not registered")
assert(registered.CONFIRM_LOOT_ROLL, "BoP roll confirmation event was not registered")
assert(registered.CONFIRM_DISENCHANT_ROLL, "Disenchant confirmation event was not registered")
assert(scripts.OnEvent, "Smart Dungeon Rolls event handler was not installed")

scripts.OnEvent(nil, "CONFIRM_DISENCHANT_ROLL", 14)
assert(confirmedRolls[4].rollID == 14 and confirmedRolls[4].rollType == 3, "Disenchant confirmation did not use the correct roll type")

captured:OnDisable(core)
assert(unregistered.START_LOOT_ROLL, "loot roll event was not unregistered")
assert(unregistered.LOOT_BIND_CONFIRM, "direct BoP confirmation event was not unregistered")
assert(unregistered.CONFIRM_LOOT_ROLL, "BoP roll confirmation event was not unregistered")
assert(unregistered.CONFIRM_DISENCHANT_ROLL, "Disenchant confirmation event was not unregistered")

print("SmartDungeonRolls tests passed")
