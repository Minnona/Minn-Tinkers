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
assert(captured:NormalizeDifficulty("Heroic (10-25 Players)", 1) == "Heroic", "readable standard difficulty did not override its numeric ID")
assert(captured:NormalizeDifficulty("", 3) == "Normal", "standard Normal difficulty ID was not normalized")
assert(captured:NormalizeDifficulty("", 4) == "Heroic", "standard Heroic difficulty ID was not normalized")
assert(captured:NormalizeDifficulty("", 5) == "Mythic", "standard Mythic difficulty ID was not normalized")
assert(captured:NormalizeDifficulty("", 6) == "Ascended", "standard Ascended difficulty ID was not normalized")
assert(captured:NormalizeDifficulty("Heroic Bloodforged", 2) == "Heroic Bloodforged", "custom difficulty was collapsed into a standard tier")
assert(captured:NormalizeLootDifficulty(1) == "Normal", "Ascension Normal difficulty was not normalized")
assert(captured:NormalizeLootDifficulty(2) == "Heroic", "Ascension Heroic difficulty was not normalized")
assert(captured:NormalizeLootDifficulty(3) == "Mythic", "Ascension Mythic difficulty was not normalized")
assert(captured:NormalizeLootDifficulty(4) == "Ascended", "Ascension Ascended difficulty was not normalized")
assert(captured:FormatDuration(90061) == "1d 1h", "day reset duration was formatted incorrectly")
assert(captured:FormatDuration(3661) == "1h 1m", "hour reset duration was formatted incorrectly")
assert(captured:FormatDuration(0) == "expired", "expired reset duration was formatted incorrectly")
local durationResetAt, durationResetKnown = captured:ResolveResetAt(100000, 7200)
assert(durationResetKnown and durationResetAt == 107200, "relative reset duration was not normalized")
local absoluteResetAt, absoluteResetKnown = captured:ResolveResetAt(100000, 1787000000)
assert(absoluteResetKnown and absoluteResetAt == 1787000000, "absolute reset timestamp was not preserved")
local unknownResetAt, unknownResetKnown = captured:ResolveResetAt(100000, 0)
assert(not unknownResetKnown and unknownResetAt == 0, "zero Ascension reset duration was treated as expired")

local settings = { enabled = true }
local printed = {}
local core = {
    globalDB = {},
    optionControls = {},
    GetModuleDB = function() return settings end,
    Print = function(_, message) table.insert(printed, message) end
}

UnitName = function() return "Testchar" end
GetRealmName = function() return "Bronzebeard" end
UnitGUID = function() return "Player-1-ABC" end
UnitClass = function() return "Mage", "MAGE" end
UnitFactionGroup = function() return "Alliance" end
IsInInstance = function() return false, "none" end
GetNumPartyMembers = function() return 0 end
GetNumRaidMembers = function() return 0 end
IsPartyLeader = function() return true end
HasLFGRestrictions = function() return false end

local mapNames = {
    [249] = "Zul'Gurub",
    [409] = "Molten Core",
    [777] = "Snowgrave (PvE)",
    [891] = "Kaldros Depthbreaker (PvE)"
}
GetMapName = function(mapID) return mapNames[mapID] end
C_Instance = {
    GetSavedMapAndDifficulty = function()
        return {
            { mapID = 249, difficultyID = 3 },
            { mapID = 409, difficultyID = 1 },
            { mapID = 409, difficultyID = 4 },
            { mapID = 777, difficultyID = 1 },
            { mapID = 891, difficultyID = 2 }
        }
    end
}
_G.GENERIC_DIFFICULTY1 = "Normal"
_G.GENERIC_DIFFICULTY2 = "Heroic"
_G.GENERIC_DIFFICULTY3 = "Mythic"
_G.GENERIC_DIFFICULTY4 = "Ascended"

local saved = {
    { "Molten Core", 101, 7200, 3, true, false, 1, true, 40, "Normal Raid" },
    { "Molten Core", 107, 0, 4, true, false, 1, true, 40, "Heroic (10-25 Players)" },
    { "Blackwing Lair", 102, 9000, 4, false, false, 1, true, 40, "Heroic Raid" },
    { "Zul'Gurub", 103, 0, 5, true, false, 1, true, 20, "Mythic Raid" },
    { "The Deadmines", 104, 12000, 5, true, false, 1, false, 5, "Mythic" },
    { "Molten Core", 105, 7200, 6, false, true, 1, true, 40, "Ascended Raid" },
    { "Snowgrave (PvE)", 106, 0, 1, true, false, 0, true, 40, "Normal (10-25 Players)" }
}

GetNumSavedInstances = function() return table.getn(saved) end
GetSavedInstanceInfo = function(index) return unpack(saved[index]) end

local currentTime = 100000
time = function() return currentTime end
assert(captured:SnapshotCurrentCharacter(core, currentTime), "current character snapshot failed")

local store = core.globalDB.raidLockouts
local character
for _, value in pairs(store.characters) do character = value end
assert(character and character.name == "Testchar", "current character identity was not stored")
assert(table.getn(character.lockouts) == 5, "snapshot did not keep exactly the locked raid instances: " .. tostring(table.getn(character.lockouts)))

local function find_row(rows, key)
    for _, row in ipairs(rows or {}) do
        if row.key == key then return row end
    end
end

local function find_entry(entries, name)
    for _, entry in ipairs(entries or {}) do
        if entry.name == name then return entry end
    end
end

local model = captured:BuildTableModel(core, currentTime)
local moltenCore = find_row(model.raids, "moltencore")
local zulGurub = find_row(model.raids, "zulgurub")
local snowgraveRow = find_row(model.worldBosses, "snowgrave")
assert(moltenCore, "raid table omitted Molten Core")
assert(find_entry(moltenCore.cells.Normal.entries, "Testchar"), "Normal raid cell omitted the character")
assert(find_entry(moltenCore.cells.Heroic.entries, "Testchar").resettable, "unknown Heroic raid reset was not shown as manually resettable")
assert(find_entry(moltenCore.cells.Ascended.entries, "Testchar"), "Ascended raid cell omitted the character")
assert(zulGurub and find_entry(zulGurub.cells.Mythic.entries, "Testchar"), "Mythic raid cell omitted the character")
assert(find_entry(zulGurub.cells.Mythic.entries, "Testchar").resettable, "unknown Mythic raid reset was not shown as manually resettable")
assert(snowgraveRow and find_entry(snowgraveRow.cells.Normal.entries, "Testchar"), "world-boss table omitted Snowgrave")
assert(find_entry(snowgraveRow.cells.Normal.entries, "Testchar").resettable, "unknown reset was not shown as manually resettable")
assert(moltenCore.resetAt == currentTime + 7200, "common raid reset was not moved to the raid row")
assert(string.find(captured:FormatRowLabel(moltenCore, currentTime), "(2h 0m)", 1, true), "raid row omitted its reset duration")
assert(find_row(model.worldBosses, "emeriss"), "seeded world boss without a lockout was omitted")
assert(find_row(model.worldBosses, "ysondre"), "seeded world boss catalog was incomplete")
assert(captured:FormatCellText({}, "Normal") == "|cff555555-|r", "empty table cell did not use a dash")
assert(string.find(captured:FormatCellText(moltenCore.cells.Normal.entries, "Normal"), "|cff66ff66Testchar|r", 1, true), "active Normal character was not difficulty-colored")
assert(string.find(captured:FormatCellText(snowgraveRow.cells.Normal.entries, "Normal"), "|cff777777Testchar|r", 1, true), "resettable character was not grey")
local moltenCoreNormalEntry = find_entry(moltenCore.cells.Normal.entries, "Testchar")
assert(moltenCoreNormalEntry.isCurrentCharacter, "current character table entry was not identified")
assert(moltenCoreNormalEntry.resetTarget and moltenCoreNormalEntry.resetTarget.mapID == 409 and moltenCoreNormalEntry.resetTarget.difficultyID == 1, "current saved ID was not resolved to Ascension's reset target")

local shownPopup
StaticPopup_Show = function(which, text1, text2, data)
    shownPopup = { which = which, text1 = text1, text2 = text2, data = data }
    return {}
end
assert(captured:ShowResetConfirmation(core, moltenCoreNormalEntry.resetTarget), "saved-ID reset confirmation was not opened")
assert(shownPopup.which == "COMFIRM_RESET_SPECIFIC_INSTANCE", "wrong Ascension reset confirmation was opened")
assert(shownPopup.text1 == "Molten Core" and shownPopup.text2 == "Normal", "reset confirmation labels were incorrect")
assert(shownPopup.data[1] == 409 and shownPopup.data[2] == 1, "reset confirmation received the wrong map or difficulty")

IsInInstance = function() return true, "raid" end
shownPopup = nil
assert(not captured:ShowResetConfirmation(core, moltenCoreNormalEntry.resetTarget), "saved ID could be reset from inside an instance")
assert(not shownPopup and printed[table.getn(printed)] == "Leave the instance before resetting a saved ID.", "inside-instance reset did not fail safely")
IsInInstance = function() return false, "none" end

GetNumPartyMembers = function() return 1 end
IsPartyLeader = function() return false end
assert(not captured:ShowResetConfirmation(core, moltenCoreNormalEntry.resetTarget), "non-leader could open a saved-ID reset confirmation")
assert(printed[table.getn(printed)] == "Only the group leader can reset a saved ID.", "non-leader reset did not fail safely")
GetNumPartyMembers = function() return 0 end
IsPartyLeader = function() return true end

HasLFGRestrictions = function() return true end
assert(not captured:ShowResetConfirmation(core, moltenCoreNormalEntry.resetTarget), "LFG-restricted player could open a saved-ID reset confirmation")
assert(printed[table.getn(printed)] == "Saved IDs cannot be reset while group-finder restrictions are active.", "LFG-restricted reset did not fail safely")
HasLFGRestrictions = function() return false end

local snowgrave
for _, lockout in ipairs(character.lockouts) do
    if lockout.name == "Snowgrave (PvE)" then snowgrave = lockout end
end
assert(snowgrave and snowgrave.resetKnown == false, "zero-duration lockout was not stored as reset-unknown")
snowgrave.resetAt = character.lastScan
snowgrave.resetKnown = nil
model = captured:BuildTableModel(core, currentTime + 60)
snowgraveRow = find_row(model.worldBosses, "snowgrave")
assert(find_entry(snowgraveRow.cells.Normal.entries, "Testchar").resettable, "legacy zero-duration snapshot disappeared from the table")

local queryCount = 0
C_LootLockout = {
    QueryInstanceBinds = function()
        queryCount = queryCount + 1
        return true
    end,
    GetLootLockouts = function(unit)
        assert(unit == "player", "Ascension loot lockouts were not queried with a unit token")
        return {
            [891] = { [1] = { [37001] = 438881 } },
            [409] = { [1] = { [4126] = 93281, [4127] = 93281 } },
            [249] = { [2] = { [4149] = 80000 } },
            [777] = { [0] = { [50001] = 5000 } }
        }
    end,
    GetEncounterData = function(unit, encounterID)
        assert(unit == "player", "Ascension encounter data was not queried with a unit token")
        if encounterID == 37001 then
            return "Kaldros Depthbreaker (PvE)", 891, 2, "Interface\\Icons\\inv_misc_questionmark", 1000, 438663
        elseif encounterID == 4126 then
            return "Lucifron", 409, 2, "", 1, 93281
        elseif encounterID == 4127 then
            return "Magmadar", 409, 2, "", 2, 93281
        elseif encounterID == 4149 then
            return "High Priestess Jeklik", 249, 3, "", 1, 80000
        elseif encounterID == 50001 then
            return "Snowgrave (PvE)", 777, 1, "", 1000, 5000
        end
    end
}

local merged = captured:CollectCurrentLockouts(currentTime)
assert(table.getn(merged) == 6, "custom lockout merge added duplicates or raid boss rows: " .. tostring(table.getn(merged)))
local kaldros
local lucifron
local jeklik
local moltenCoreHeroic
local zulGurubMythic
local snowgraveCount = 0
for _, lockout in ipairs(merged) do
    if lockout.name == "Kaldros Depthbreaker (PvE)" then kaldros = lockout end
    if lockout.name == "Lucifron" then lucifron = lockout end
    if lockout.name == "High Priestess Jeklik" then jeklik = lockout end
    if lockout.name == "Molten Core" and lockout.difficultyKey == "Heroic" then moltenCoreHeroic = lockout end
    if lockout.name == "Zul'Gurub" and lockout.difficultyKey == "Mythic" then zulGurubMythic = lockout end
    if lockout.name == "Snowgrave (PvE)" then snowgraveCount = snowgraveCount + 1 end
end
assert(kaldros and kaldros.difficultyKey == "Heroic", "Kaldros custom Heroic lockout was not collected")
assert(kaldros.resetKnown and kaldros.resetAt == currentTime + 438663, "Kaldros custom reset time was not stored")
assert(not lucifron, "multi-boss raid loot locks were exposed as boss lockout rows")
assert(not jeklik, "partial ordinary raid loot lock was exposed as a boss lockout row")
assert(moltenCoreHeroic and moltenCoreHeroic.resetKnown and moltenCoreHeroic.resetAt == currentTime + 93281, "Molten Core Heroic did not inherit its hidden boss reset")
assert(moltenCoreHeroic.resetSource == "ascensionBosses", "Molten Core Heroic did not record the hidden reset source")
assert(zulGurubMythic and zulGurubMythic.resetKnown and zulGurubMythic.resetAt == currentTime + 80000, "partial Zul'Gurub Mythic did not inherit its hidden boss reset")
assert(snowgraveCount == 1, "custom lockout duplicated an existing standard lockout")

local standardRequestCount = 0
RequestRaidInfo = function() standardRequestCount = standardRequestCount + 1 end
captured.lastRequestAt = nil
assert(captured:RequestSnapshot(core, true), "combined lockout refresh request failed")
assert(standardRequestCount == 1, "standard raid information was not requested")
assert(queryCount == 1, "Ascension instance binds were not requested")

captured:OnEvent(core, "QUERY_INSTANCE_BINDS_RESULT", true, "QUERY_INSTANCE_BINDS_OK")
for _, value in pairs(store.characters) do
    if value.name == "Testchar" then character = value end
end
local eventKaldros = false
for _, lockout in ipairs(character.lockouts or {}) do
    if lockout.name == "Kaldros Depthbreaker (PvE)" then eventKaldros = true end
end
assert(eventKaldros, "successful Ascension bind query did not refresh the character snapshot")

model = captured:BuildTableModel(core, currentTime)
moltenCore = find_row(model.raids, "moltencore")
zulGurub = find_row(model.raids, "zulgurub")
local kaldrosRow = find_row(model.worldBosses, "kaldros")
local eventMoltenCoreHeroic = find_entry(moltenCore.cells.Heroic.entries, "Testchar")
local eventZulGurubMythic = find_entry(zulGurub.cells.Mythic.entries, "Testchar")
assert(eventMoltenCoreHeroic and not eventMoltenCoreHeroic.resettable, "hidden Molten Core reset did not make Heroic active")
assert(string.find(captured:FormatCellText(moltenCore.cells.Heroic.entries, "Heroic"), "|cff3399ffTestchar|r", 1, true), "backfilled Heroic raid character was not difficulty-colored")
assert(eventZulGurubMythic and not eventZulGurubMythic.resettable, "hidden Zul'Gurub reset did not make Mythic active")
assert(zulGurub.resetAt == currentTime + 80000, "partial Zul'Gurub reset was not moved to the raid row")
assert(kaldrosRow and kaldrosRow.label == "Kaldros", "Kaldros was not normalized to its compact table label")
local kaldrosEntry = find_entry(kaldrosRow.cells.Heroic.entries, "Testchar")
assert(kaldrosEntry, "Kaldros was not placed in the Heroic world-boss column")
assert(kaldrosEntry.resetTarget and kaldrosEntry.resetTarget.mapID == 891 and kaldrosEntry.resetTarget.difficultyID == 2, "Kaldros was not linked to its Heroic reset target")
assert(kaldrosRow.resetAt == currentTime + 438663, "world-boss reset was not moved to its row")

store.characters.other = {
    name = "Otherchar",
    realm = "Area 52",
    lastScan = currentTime - 400000,
    lockouts = {
        {
            name = "Molten Core",
            difficultyKey = "Normal",
            difficultyName = "Heroic Raid",
            maxPlayers = 25,
            resetAt = currentTime + 7200,
            resetKnown = true
        }
    }
}

store.characters.second = {
    name = "Secondchar",
    realm = "Bronzebeard",
    lastScan = currentTime,
    lockouts = {
        {
            name = "Molten Core",
            difficultyKey = "Normal",
            difficultyName = "Normal Raid",
            resetAt = currentTime + 7200,
            resetKnown = true
        }
    }
}

model = captured:BuildTableModel(core, currentTime)
moltenCore = find_row(model.raids, "moltencore")
assert(not find_entry(moltenCore.cells.Normal.entries, "Otherchar"), "current-realm table included another realm")
assert(table.getn(moltenCore.cells.Normal.entries) == 2, "current-realm characters were not collected into one cell")
assert(not find_entry(moltenCore.cells.Normal.entries, "Secondchar").resetTarget, "offline character was given a live reset target")
local stackedNames = captured:FormatCellText(moltenCore.cells.Normal.entries, "Normal")
assert(string.find(stackedNames, "Secondchar|r\n|cff66ff66Testchar", 1, true), "character names were not stacked vertically in alphabetical order")

print("RaidLockouts tests passed")
