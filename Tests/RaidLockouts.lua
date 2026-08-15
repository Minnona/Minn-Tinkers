local captured

if not table.getn then
    table.getn = function(values) return #values end
end
unpack = unpack or table.unpack

MinnTinkers = {
    RegisterModule = function(_, _, module)
        captured = module
    end
}

dofile("Modules/RaidLockouts.lua")

assert(captured:NormalizeDifficulty("Normal Raid", 3) == "Normal", "normal difficulty name was not normalized")
assert(captured:NormalizeDifficulty("25 Player (Heroic)", 4) == "Heroic", "heroic difficulty name was not normalized")
assert(captured:NormalizeDifficulty("Mythic Raid", 5) == "Mythic", "mythic difficulty name was not normalized")
assert(captured:NormalizeDifficulty("Ascended Raid", 6) == "Ascended", "ascended difficulty name was not normalized")
assert(captured:NormalizeDifficulty("Heroic Bloodforged", 2) == "Heroic Bloodforged", "custom difficulty was collapsed into a standard tier")
assert(captured:FormatDuration(90061) == "1d 1h", "day reset duration was formatted incorrectly")
assert(captured:FormatDuration(3661) == "1h 1m", "hour reset duration was formatted incorrectly")
assert(captured:FormatDuration(0) == "expired", "expired reset duration was formatted incorrectly")
local durationResetAt, durationResetKnown = captured:ResolveResetAt(100000, 7200)
assert(durationResetKnown and durationResetAt == 107200, "relative reset duration was not normalized")
local absoluteResetAt, absoluteResetKnown = captured:ResolveResetAt(100000, 1787000000)
assert(absoluteResetKnown and absoluteResetAt == 1787000000, "absolute reset timestamp was not preserved")
local unknownResetAt, unknownResetKnown = captured:ResolveResetAt(100000, 0)
assert(not unknownResetKnown and unknownResetAt == 0, "zero Ascension reset duration was treated as expired")

local settings = {
    enabled = true,
    currentRealmOnly = true,
    showExpired = false,
    viewMode = "raid"
}
local core = {
    globalDB = {},
    optionControls = {},
    GetModuleDB = function() return settings end
}

UnitName = function() return "Testchar" end
GetRealmName = function() return "Bronzebeard" end
UnitGUID = function() return "Player-1-ABC" end
UnitClass = function() return "Mage", "MAGE" end
UnitFactionGroup = function() return "Alliance" end

local saved = {
    { "Molten Core", 101, 7200, 3, true, false, 1, true, 40, "Normal Raid" },
    { "Blackwing Lair", 102, 9000, 4, false, false, 1, true, 40, "Heroic Raid" },
    { "Zul'Gurub", 103, 10800, 5, true, false, 1, true, 20, "Mythic Raid" },
    { "The Deadmines", 104, 12000, 5, true, false, 1, false, 5, "Mythic" },
    { "Molten Core", 105, 14400, 6, false, true, 1, true, 40, "Ascended Raid" },
    { "Snowgrave (PvE)", 106, 0, 1, true, false, 0, true, 40, "Normal (10-25 Players)" }
}

GetNumSavedInstances = function() return table.getn(saved) end
GetSavedInstanceInfo = function(index) return unpack(saved[index]) end

local currentTime = 100000
assert(captured:SnapshotCurrentCharacter(core, currentTime), "current character snapshot failed")

local store = core.globalDB.raidLockouts
local character
for _, value in pairs(store.characters) do character = value end
assert(character and character.name == "Testchar", "current character identity was not stored")
assert(table.getn(character.lockouts) == 4, "snapshot did not keep exactly the locked raid instances: " .. tostring(table.getn(character.lockouts)))
assert(character.lockouts[1].resetAt == currentTime + 7200, "absolute reset time was not stored")

local report = captured:BuildReport(core, currentTime)
assert(string.find(report, "Molten Core", 1, true), "raid-grouped report omitted a raid")
assert(string.find(report, "Normal:", 1, true), "raid-grouped report omitted Normal")
assert(string.find(report, "Mythic:", 1, true), "raid-grouped report omitted Mythic")
assert(string.find(report, "Ascended:", 1, true), "raid-grouped report omitted Ascended")
assert(string.find(report, "Testchar", 1, true), "raid-grouped report omitted the character")
assert(string.find(report, "Snowgrave", 1, true), "zero-duration Ascension lockout disappeared from the report")
assert(not string.find(report, "reset unknown", 1, true), "unknown-reset label was shown")
assert(not string.find(report, "40p", 1, true), "maximum raid size was shown in the raid view")

local snowgrave
for _, lockout in ipairs(character.lockouts) do
    if lockout.name == "Snowgrave (PvE)" then snowgrave = lockout end
end
assert(snowgrave and snowgrave.resetKnown == false, "zero-duration lockout was not stored as reset-unknown")
snowgrave.resetAt = character.lastScan
snowgrave.resetKnown = nil
report = captured:BuildReport(core, currentTime + 60)
assert(string.find(report, "Snowgrave", 1, true), "legacy zero-duration snapshot disappeared as expired")

store.characters.other = {
    name = "Otherchar",
    realm = "Area 52",
    lastScan = currentTime - 400000,
    lockouts = {
        {
            name = "Expired Raid",
            difficultyKey = "Heroic",
            difficultyName = "Heroic Raid",
            maxPlayers = 25,
            resetAt = currentTime - 60
        }
    }
}

report = captured:BuildReport(core, currentTime)
assert(not string.find(report, "Otherchar", 1, true), "current-realm view included another realm")

settings.currentRealmOnly = false
report = captured:BuildReport(core, currentTime)
assert(string.find(report, "Otherchar%-Area 52") ~= nil, "all-realm view omitted the other character")
assert(not string.find(report, "Expired Raid", 1, true), "expired lockout was shown while hidden")

settings.showExpired = true
report = captured:BuildReport(core, currentTime)
assert(string.find(report, "Expired Raid", 1, true), "expired lockout was omitted when enabled")
assert(string.find(report, "stale", 1, true), "stale character snapshot was not identified")

settings.viewMode = "character"
report = captured:BuildReport(core, currentTime)
assert(string.find(report, "scanned", 1, true), "character-grouped view omitted scan age")
assert(string.find(report, "Zul'Gurub", 1, true), "character-grouped view omitted a lockout")
assert(string.find(report, "Snowgrave", 1, true), "character-grouped view omitted an unknown-reset lockout")
assert(not string.find(report, "40p", 1, true), "maximum raid size was shown in the character view")

captured:ForgetCurrentCharacter(core)
local foundCurrent = false
for _, value in pairs(store.characters) do
    if value.name == "Testchar" then foundCurrent = true end
end
assert(not foundCurrent, "forget current character did not remove its snapshot")

print("RaidLockouts tests passed")
