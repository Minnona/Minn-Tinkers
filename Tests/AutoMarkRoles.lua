local captured

MinnTinkers = {
    RegisterModule = function(_, _, module)
        captured = module
    end
}

dofile("Modules/AutoMarkRoles.lua")

local db = {
    enabled = true,
    keepMarked = true,
    rememberDungeonRoles = true,
    tankIcon = 1,
    healerIcon = 5,
    delay = 0,
    markInDungeons = true,
    markInRaids = false
}
local core = {
    GetModuleDB = function() return db end,
    Print = function() end
}

local tank = { name = "Tankchar", guid = "Tank-GUID", role = "TANK" }
local healer = { name = "Healchar", guid = "Healer-GUID", role = "HEALER" }
local damage = { name = "Damagechar", guid = "Damage-GUID", role = "DAMAGER" }
local units = {
    player = tank,
    party1 = healer,
    party2 = damage
}
local marks = {}
local inDungeon = true
local instanceID = 555
local difficultyName = "Normal"
local rolesAvailable = true

IsInInstance = function() return inDungeon, inDungeon and "party" or "none" end
GetInstanceInfo = function() return "Shadow Labyrinth", "party", 1, difficultyName, 5, 0, false, instanceID end
UnitInRaid = function() return false end
UnitExists = function(unit) return units[unit] ~= nil end
UnitName = function(unit) return units[unit] and units[unit].name or nil end
UnitGUID = function(unit) return units[unit] and units[unit].guid or nil end
UnitGroupRolesAssigned = function(unit)
    if not rolesAvailable or not units[unit] then return "NONE" end
    return units[unit].role
end
GetRaidTargetIndex = function(unit)
    local guid = UnitGUID(unit)
    return guid and marks[guid] or nil
end
SetRaidTarget = function(unit, icon)
    local guid = UnitGUID(unit)
    if not guid then return end
    if icon and icon > 0 then
        for markedGUID, markedIcon in pairs(marks) do
            if markedIcon == icon then marks[markedGUID] = nil end
        end
        marks[guid] = icon
    else
        marks[guid] = nil
    end
end

captured:MarkRoles(core, false, 1)
assert(marks[tank.guid] == 1, "initial tank was not marked with Star")
assert(marks[healer.guid] == 5, "initial healer was not marked with Moon")
assert(captured.roleMemory and captured.roleMemory.tank.guid == tank.guid, "tank identity was not remembered")
assert(captured.roleMemory and captured.roleMemory.healer.guid == healer.guid, "healer identity was not remembered")

rolesAvailable = false
difficultyName = "Mythic+ 7"
marks = {}
captured:MarkRoles(core, false, 1)
assert(marks[tank.guid] == 1, "remembered tank was not restored after Mythic+ activation")
assert(marks[healer.guid] == 5, "remembered healer was not restored after Mythic+ activation")

units.player = damage
units.party2 = tank
marks = {}
captured:MarkRoles(core, false, 1)
assert(GetRaidTargetIndex("party2") == 1, "remembered tank did not follow its GUID to a new party token")
assert(GetRaidTargetIndex("party1") == 5, "remembered healer was lost after party token changes")

instanceID = 777
marks = {}
captured:MarkRoles(core, false, 1)
assert(next(marks) == nil, "remembered roles leaked into a different dungeon")

instanceID = 555
inDungeon = false
captured:SyncRoleMemory(core)
assert(captured.roleMemory == nil, "role memory was not cleared after leaving the dungeon")

inDungeon = true
marks = {}
captured:MarkRoles(core, false, 1)
assert(next(marks) == nil, "old dungeon roles were reused after leaving and re-entering")

marks[tank.guid] = 1
marks[healer.guid] = 5
captured:MarkRoles(core, false, 1)
assert(captured.roleMemory and captured.roleMemory.tank.guid == tank.guid, "existing Star holder was not remembered without role data")
assert(captured.roleMemory and captured.roleMemory.healer.guid == healer.guid, "existing Moon holder was not remembered without role data")

marks = {}
captured:MarkRoles(core, false, 1)
assert(marks[tank.guid] == 1 and marks[healer.guid] == 5, "remembered entry markers were not restored")

db.rememberDungeonRoles = false
captured:SyncRoleMemory(core)
rolesAvailable = true
marks = {}
captured:MarkRoles(core, false, 1)
rolesAvailable = false
marks = {}
captured:MarkRoles(core, false, 1)
assert(next(marks) == nil, "disabled role memory still restored markers")

print("AutoMarkRoles tests passed")
