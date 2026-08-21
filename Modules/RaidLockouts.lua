local MT = MinnTinkers

local STORE_SCHEMA = 1
local EXPIRED_RETENTION = 30 * 24 * 60 * 60
local REQUEST_THROTTLE = 5
local ASCENSION_STANDALONE_ORDER = 1000
local TABLE_WIDTH = 556
local TABLE_LABEL_WIDTH = 180
local TABLE_LINE_HEIGHT = 15
local TABLE_HEADER_HEIGHT = 20

local DIFFICULTY_ORDER = { "Normal", "Heroic", "Mythic", "Ascended" }
local DIFFICULTY_RANK = {
    Normal = 1,
    Heroic = 2,
    Mythic = 3,
    Ascended = 4
}
local DIFFICULTY_COLOR = {
    Normal = "|cff66ff66",
    Heroic = "|cff3399ff",
    Mythic = "|cffff66ff",
    Ascended = "|cffff9933"
}
local RESETTABLE_COLOR = "|cff777777"

local RAID_CATALOG = {
    { key = "moltencore", label = "Molten Core" },
    { key = "zulgurub", label = "Zul'Gurub" },
    { key = "onyxiaslair", label = "Onyxia's Lair" }
}
local WORLD_BOSS_CATALOG = {
    { key = "atalzul", label = "Atal'Zul" },
    { key = "azuregos", label = "Azuregos" },
    { key = "emeriss", label = "Emeriss" },
    { key = "kaldros", label = "Kaldros" },
    { key = "lethon", label = "Lethon" },
    { key = "kazzak", label = "Kazzak" },
    { key = "setis", label = "Setis" },
    { key = "snowgrave", label = "Snowgrave" },
    { key = "taerar", label = "Taerar" },
    { key = "soggoth", label = "Soggoth" },
    { key = "ysondre", label = "Ysondre" }
}
local RAID_DIFFICULTIES = { "Normal", "Heroic", "Mythic", "Ascended" }
local WORLD_BOSS_DIFFICULTIES = { "Normal", "Heroic" }

local module = {
    name = "Raid lockout tracker",
    desc = "Tracks raid lockouts and reset times across characters that use this account's SavedVariables.",
    category = "RaidLockouts",
    alwaysEnabled = true,
    hideEnabledToggle = true,
    defaults = {
        enabled = true
    }
}

local function trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function lower(text)
    return string.lower(tostring(text or ""))
end

local function now_time()
    return time and time() or 0
end

local function safe_register(frame, event)
    if frame and event then pcall(frame.RegisterEvent, frame, event) end
end

local function safe_unregister(frame, event)
    if frame and event then pcall(frame.UnregisterEvent, frame, event) end
end

local function character_key(name, realm, guid)
    local identity = trim(guid)
    if identity == "" then identity = lower(trim(name)) end
    return lower(trim(realm)) .. "\031" .. identity
end

local function difficulty_rank(name)
    return DIFFICULTY_RANK[name] or 99
end

local function content_key(name)
    local value = lower(trim(name))
    value = string.gsub(value, "%s*%(pve%)%s*$", "")
    if value == "kaldros depthbreaker" then value = "kaldros" end
    if value == "lord kazzak" then value = "kazzak" end
    return string.gsub(value, "[^%w]", "")
end

local function content_difficulty_key(name, difficulty)
    return content_key(name) .. "\031" .. lower(trim(difficulty))
end

local function display_content_name(name)
    local value = trim(name)
    value = string.gsub(value, "%s*%([Pp][Vv][Ee]%)%s*$", "")
    if lower(value) == "kaldros depthbreaker" then return "Kaldros" end
    if lower(value) == "lord kazzak" then return "Kazzak" end
    return value
end

local function copy_catalog(source)
    local result = {}
    for _, entry in ipairs(source) do
        table.insert(result, { key = entry.key, label = entry.label })
    end
    return result
end

local function catalog_keys(catalog)
    local result = {}
    for _, entry in ipairs(catalog) do result[entry.key] = true end
    return result
end

local SEEDED_RAID_KEYS = catalog_keys(RAID_CATALOG)
local SEEDED_WORLD_BOSS_KEYS = catalog_keys(WORLD_BOSS_CATALOG)

function module:NormalizeDifficulty(difficultyName, difficultyID)
    local name = trim(difficultyName)
    local lowered = lower(name)

    if not string.find(lowered, "bloodforged", 1, true) then
        if string.find(lowered, "ascended", 1, true) then return "Ascended" end
        if string.find(lowered, "mythic", 1, true) then return "Mythic" end
        if string.find(lowered, "heroic", 1, true) then return "Heroic" end
        if string.find(lowered, "normal", 1, true) then return "Normal" end
    end

    if name ~= "" then return name end

    difficultyID = tonumber(difficultyID)
    if difficultyID == 3 then return "Normal" end
    if difficultyID == 4 then return "Heroic" end
    if difficultyID == 5 then return "Mythic" end
    if difficultyID == 6 then return "Ascended" end
    return "Difficulty " .. tostring(difficultyID or "Unknown")
end

function module:NormalizeLootDifficulty(difficultyID)
    difficultyID = tonumber(difficultyID)
    if difficultyID == 1 then return "Normal" end
    if difficultyID == 2 then return "Heroic" end
    if difficultyID == 3 then return "Mythic" end
    if difficultyID == 4 then return "Ascended" end
    return "Difficulty " .. tostring(difficultyID or "Unknown")
end

function module:FormatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds <= 0 then return "expired" end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if days > 0 then return tostring(days) .. "d " .. tostring(hours) .. "h" end
    if hours > 0 then return tostring(hours) .. "h " .. tostring(minutes) .. "m" end
    if minutes > 0 then return tostring(minutes) .. "m" end
    return "<1m"
end

function module:ResolveResetAt(currentTime, resetValue)
    currentTime = tonumber(currentTime) or now_time()
    resetValue = tonumber(resetValue)
    if not resetValue or resetValue <= 0 then return 0, false end

    -- The standard client returns seconds remaining. Some Ascension builds have
    -- returned an absolute Unix timestamp instead, so accept both shapes.
    if resetValue >= 1000000000 then return resetValue, true end
    return currentTime + resetValue, true
end

function module:GetRemaining(character, lockout, currentTime)
    currentTime = tonumber(currentTime) or now_time()
    local resetAt = tonumber(lockout and lockout.resetAt) or 0
    local resetKnown = lockout and lockout.resetKnown

    if resetKnown == nil then
        -- v0.1.35-v0.1.37 stored zero-duration Ascension lockouts with
        -- resetAt equal to lastScan, which made them immediately disappear.
        local lastScan = tonumber(character and character.lastScan) or 0
        resetKnown = resetAt > 0 and resetAt > lastScan
    end

    if not resetKnown then return nil, false end
    return resetAt - currentTime, true
end

function module:GetStore(core)
    local global = core and core.globalDB or MinnTinkersDB
    if type(global) ~= "table" then return nil end

    if type(global.raidLockouts) ~= "table" then global.raidLockouts = {} end
    local store = global.raidLockouts
    store.schema = STORE_SCHEMA
    if type(store.characters) ~= "table" then store.characters = {} end
    if type(store.knownInstances) ~= "table" then store.knownInstances = {} end
    return store
end

function module:IsWorldBossLockout(lockout)
    if type(lockout) ~= "table" then return false end
    local key = content_key(lockout.name)
    if SEEDED_WORLD_BOSS_KEYS[key] then return true end
    if SEEDED_RAID_KEYS[key] then return false end
    if lockout.source == "ascensionLoot" then return true end
    return string.find(lower(lockout.name), "(pve)", 1, true) ~= nil
end

function module:RememberKnownContent(store, lockouts)
    if type(store) ~= "table" or type(store.knownInstances) ~= "table" then return end
    for _, lockout in ipairs(lockouts or {}) do
        local key = content_key(lockout.name)
        if key ~= "" and not SEEDED_RAID_KEYS[key] and not SEEDED_WORLD_BOSS_KEYS[key] then
            store.knownInstances[key] = {
                name = display_content_name(lockout.name),
                category = self:IsWorldBossLockout(lockout) and "worldBoss" or "raid"
            }
        end
    end
end

function module:GetContentCatalog(core)
    local raids = copy_catalog(RAID_CATALOG)
    local worldBosses = copy_catalog(WORLD_BOSS_CATALOG)
    local store = self:GetStore(core)
    local discoveredRaids = {}
    local discoveredWorldBosses = {}
    local seen = {}

    for _, entry in ipairs(raids) do seen[entry.key] = true end
    for _, entry in ipairs(worldBosses) do seen[entry.key] = true end

    if store then
        for _, character in pairs(store.characters) do
            self:RememberKnownContent(store, character.lockouts)
        end
        for key, entry in pairs(store.knownInstances) do
            if not seen[key] and type(entry) == "table" and trim(entry.name) ~= "" then
                local target = entry.category == "worldBoss" and discoveredWorldBosses or discoveredRaids
                table.insert(target, { key = key, label = trim(entry.name) })
                seen[key] = true
            end
        end
    end

    local sortByLabel = function(a, b) return lower(a.label) < lower(b.label) end
    table.sort(discoveredRaids, sortByLabel)
    table.sort(discoveredWorldBosses, sortByLabel)
    for _, entry in ipairs(discoveredRaids) do table.insert(raids, entry) end
    for _, entry in ipairs(discoveredWorldBosses) do table.insert(worldBosses, entry) end
    return raids, worldBosses
end

function module:GetCurrentCharacter()
    local name = UnitName and UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "UnknownRealm"
    local localizedClass, classToken = nil, nil
    if UnitClass then localizedClass, classToken = UnitClass("player") end

    return {
        name = tostring(name or "Unknown"),
        realm = tostring(realm or "UnknownRealm"),
        guid = UnitGUID and UnitGUID("player") or nil,
        className = localizedClass,
        classToken = classToken,
        faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    }
end

function module:IsCurrentCharacter(character, current)
    if type(character) ~= "table" or type(current) ~= "table" then return false end
    local characterGUID = trim(character.guid)
    local currentGUID = trim(current.guid)
    if characterGUID ~= "" and currentGUID ~= "" then return characterGUID == currentGUID end
    return lower(trim(character.name)) == lower(trim(current.name))
        and lower(trim(character.realm)) == lower(trim(current.realm))
end

function module:GetResetTargets()
    local targets = {}
    local api = C_Instance
    if type(api) ~= "table" or type(api.GetSavedMapAndDifficulty) ~= "function" then return targets end

    local ok, locks = pcall(api.GetSavedMapAndDifficulty, api)
    if not ok or type(locks) ~= "table" then return targets end

    for _, lockout in ipairs(locks) do
        local mapID = type(lockout) == "table" and tonumber(lockout.mapID) or nil
        local difficultyID = type(lockout) == "table" and tonumber(lockout.difficultyID) or nil
        local name = nil
        if mapID and type(GetMapName) == "function" then
            local nameOK, mapName = pcall(GetMapName, mapID)
            if nameOK then name = trim(mapName) end
        end
        if mapID and difficultyID and name and name ~= "" then
            local difficulty = self:NormalizeLootDifficulty(difficultyID)
            targets[content_difficulty_key(name, difficulty)] = {
                mapID = mapID,
                difficultyID = difficultyID,
                mapName = name,
                difficultyKey = difficulty
            }
        end
    end

    return targets
end

function module:CanResetSpecificInstance()
    if type(IsInInstance) == "function" then
        local ok, inInstance = pcall(IsInInstance)
        if ok and inInstance then return false, "Leave the instance before resetting a saved ID." end
    end

    local groupSize = 0
    if type(GetNumPartyMembers) == "function" then groupSize = groupSize + (tonumber(GetNumPartyMembers()) or 0) end
    if type(GetNumRaidMembers) == "function" then groupSize = groupSize + (tonumber(GetNumRaidMembers()) or 0) end
    if groupSize > 0 and type(IsPartyLeader) == "function" and not IsPartyLeader() then
        return false, "Only the group leader can reset a saved ID."
    end
    if type(HasLFGRestrictions) == "function" and HasLFGRestrictions() then
        return false, "Saved IDs cannot be reset while group-finder restrictions are active."
    end
    return true
end

function module:ShowResetConfirmation(core, target)
    local mapID = type(target) == "table" and tonumber(target.mapID) or nil
    local difficultyID = type(target) == "table" and tonumber(target.difficultyID) or nil
    if not mapID or not difficultyID or type(StaticPopup_Show) ~= "function" then return false end

    local allowed, reason = self:CanResetSpecificInstance()
    if not allowed then
        if core and core.Print then core:Print(reason) end
        return false
    end

    local mapName = trim(target.mapName)
    if mapName == "" then mapName = tostring(mapID) end
    local difficultyName = _G["GENERIC_DIFFICULTY" .. tostring(difficultyID)] or target.difficultyKey or tostring(difficultyID)
    local ok = pcall(StaticPopup_Show, "COMFIRM_RESET_SPECIFIC_INSTANCE", mapName, difficultyName, { mapID, difficultyID })
    return ok
end

function module:PruneStore(core, currentTime)
    local store = self:GetStore(core)
    if not store then return end
    currentTime = tonumber(currentTime) or now_time()

    for _, character in pairs(store.characters) do
        if type(character.lockouts) ~= "table" then character.lockouts = {} end
        for index = table.getn(character.lockouts), 1, -1 do
            local lockout = character.lockouts[index]
            local resetAt = type(lockout) == "table" and tonumber(lockout.resetAt) or 0
            local _, resetKnown = self:GetRemaining(character, lockout, currentTime)
            if resetKnown and resetAt > 0 and resetAt < currentTime - EXPIRED_RETENTION then
                table.remove(character.lockouts, index)
            end
        end
    end
end

function module:SortLockouts(lockouts)
    table.sort(lockouts, function(a, b)
        if lower(a.name) ~= lower(b.name) then return lower(a.name) < lower(b.name) end
        if difficulty_rank(a.difficultyKey) ~= difficulty_rank(b.difficultyKey) then
            return difficulty_rank(a.difficultyKey) < difficulty_rank(b.difficultyKey)
        end
        return (a.maxPlayers or 0) < (b.maxPlayers or 0)
    end)
end

function module:CollectStandardLockouts(currentTime)
    local lockouts = {}
    if not GetNumSavedInstances or not GetSavedInstanceInfo then return lockouts end

    local count = tonumber(GetNumSavedInstances()) or 0
    for index = 1, count do
        local ok, name, instanceID, resetSeconds, difficultyID, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName = pcall(GetSavedInstanceInfo, index)
        if ok and isRaid and (locked or extended) and trim(name) ~= "" then
            local normalizedDifficulty = self:NormalizeDifficulty(difficultyName, difficultyID)
            local resetAt, resetKnown = self:ResolveResetAt(currentTime, resetSeconds)
            table.insert(lockouts, {
                name = trim(name),
                instanceID = instanceID,
                instanceIDMostSig = instanceIDMostSig,
                difficultyID = tonumber(difficultyID),
                difficultyName = trim(difficultyName),
                difficultyKey = normalizedDifficulty,
                maxPlayers = tonumber(maxPlayers) or 0,
                locked = locked and true or false,
                extended = extended and true or false,
                resetAt = resetAt,
                resetKnown = resetKnown
            })
        end
    end

    return lockouts
end

function module:CollectAscensionLootLockouts(currentTime)
    local lockouts = {}
    local resetHints = {}
    local api = C_LootLockout
    if type(api) ~= "table" or type(api.GetLootLockouts) ~= "function" or type(api.GetEncounterData) ~= "function" then
        return lockouts, resetHints
    end

    local ok, rawLockouts = pcall(api.GetLootLockouts, "player")
    if not ok or type(rawLockouts) ~= "table" then return lockouts, resetHints end

    for rawMapID, difficulties in pairs(rawLockouts) do
        if type(difficulties) == "table" then
            for _, encounters in pairs(difficulties) do
                if type(encounters) == "table" then
                    local encounterCount = 0
                    local sampleEncounterID = nil
                    local sampleRemaining = nil
                    local maximumRemaining = 0
                    for rawEncounterID, rawRemaining in pairs(encounters) do
                        local encounterID = tonumber(rawEncounterID)
                        rawRemaining = tonumber(rawRemaining)
                        if encounterID and rawRemaining and rawRemaining > 0 then
                            encounterCount = encounterCount + 1
                            sampleEncounterID = encounterID
                            sampleRemaining = rawRemaining
                            maximumRemaining = math.max(maximumRemaining, rawRemaining)
                        end
                    end

                    -- Ascension records ordinary raids as one loot lock per boss.
                    -- Standalone world bosses use a single encounter with order 1000.
                    -- Keep standalone bosses as rows. For ordinary raids, retain only a
                    -- reset hint so Lucifron/Magmadar/etc. never become table rows.
                    if encounterCount > 0 and sampleEncounterID then
                        local dataOK, name, mapID, difficultyID, _, orderIndex, remaining = pcall(api.GetEncounterData, "player", sampleEncounterID)
                        name = trim(name)
                        mapID = tonumber(mapID) or tonumber(rawMapID)
                        difficultyID = tonumber(difficultyID)
                        remaining = tonumber(remaining)
                        if not remaining or remaining <= 0 then remaining = sampleRemaining end
                        if encounterCount > 1 then
                            remaining = math.max(tonumber(remaining) or 0, maximumRemaining)
                        end

                        if dataOK and encounterCount == 1 and name ~= "" and tonumber(orderIndex) == ASCENSION_STANDALONE_ORDER then
                            local difficulty = self:NormalizeLootDifficulty(difficultyID)
                            local resetAt, resetKnown = self:ResolveResetAt(currentTime, remaining)
                            table.insert(lockouts, {
                                name = name,
                                instanceID = sampleEncounterID,
                                instanceIDMostSig = mapID,
                                mapID = mapID,
                                encounterID = sampleEncounterID,
                                difficultyID = difficultyID,
                                difficultyName = difficulty,
                                difficultyKey = difficulty,
                                maxPlayers = 0,
                                locked = true,
                                extended = false,
                                resetAt = resetAt,
                                resetKnown = resetKnown,
                                source = "ascensionLoot"
                            })
                        elseif dataOK and mapID and difficultyID and type(GetMapName) == "function" then
                            local nameOK, mapName = pcall(GetMapName, mapID)
                            mapName = nameOK and trim(mapName) or ""
                            if mapName ~= "" then
                                local difficulty = self:NormalizeLootDifficulty(difficultyID)
                                local resetAt, resetKnown = self:ResolveResetAt(currentTime, remaining)
                                local hintKey = content_difficulty_key(mapName, difficulty)
                                local existing = resetHints[hintKey]
                                if resetKnown and (not existing or resetAt > existing.resetAt) then
                                    resetHints[hintKey] = {
                                        mapID = mapID,
                                        difficultyID = difficultyID,
                                        difficultyKey = difficulty,
                                        resetAt = resetAt,
                                        resetKnown = true
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return lockouts, resetHints
end

function module:CollectCurrentLockouts(currentTime)
    local lockouts = self:CollectStandardLockouts(currentTime)
    local byNameDifficulty = {}
    local ascensionLockouts, resetHints = self:CollectAscensionLootLockouts(currentTime)

    for _, lockout in ipairs(lockouts) do
        local key = lower(trim(lockout.name)) .. "\031" .. lower(trim(lockout.difficultyKey))
        if not byNameDifficulty[key] then byNameDifficulty[key] = lockout end

        local hint = resetHints[content_difficulty_key(lockout.name, lockout.difficultyKey)]
        if hint and hint.resetKnown and not lockout.resetKnown then
            lockout.resetAt = hint.resetAt
            lockout.resetKnown = true
            lockout.mapID = hint.mapID
            lockout.lootDifficultyID = hint.difficultyID
            lockout.resetSource = "ascensionBosses"
        end
    end

    for _, lockout in ipairs(ascensionLockouts) do
        local key = lower(trim(lockout.name)) .. "\031" .. lower(trim(lockout.difficultyKey))
        local existing = byNameDifficulty[key]
        if existing then
            if lockout.resetKnown and not existing.resetKnown then
                existing.resetAt = lockout.resetAt
                existing.resetKnown = true
            end
        else
            table.insert(lockouts, lockout)
            byNameDifficulty[key] = lockout
        end
    end

    self:SortLockouts(lockouts)
    return lockouts
end

function module:SnapshotCurrentCharacter(core, currentTime)
    local store = self:GetStore(core)
    if not store then return false end

    currentTime = tonumber(currentTime) or now_time()
    local info = self:GetCurrentCharacter()
    local key = character_key(info.name, info.realm, info.guid)
    local lockouts = self:CollectCurrentLockouts(currentTime)
    self:RememberKnownContent(store, lockouts)
    store.characters[key] = {
        name = info.name,
        realm = info.realm,
        guid = info.guid,
        className = info.className,
        classToken = info.classToken,
        faction = info.faction,
        lastScan = currentTime,
        lockouts = lockouts
    }

    self.scanPending = false
    self.lastSnapshotAt = currentTime
    self:PruneStore(core, currentTime)
    self:RefreshTable(core)
    return true
end

function module:RequestSnapshot(core, force)
    local api = C_LootLockout
    local canRequestStandard = type(RequestRaidInfo) == "function"
    local canRequestAscension = type(api) == "table"
        and type(api.QueryInstanceBinds) == "function"
        and type(api.GetLootLockouts) == "function"
        and type(api.GetEncounterData) == "function"

    if not canRequestStandard and not canRequestAscension then
        self:RefreshTable(core)
        return false
    end

    local currentTime = now_time()
    if not force and self.lastRequestAt and currentTime - self.lastRequestAt < REQUEST_THROTTLE then
        return false
    end

    self.lastRequestAt = currentTime
    self.scanPending = true
    local standardOK = false
    local ascensionOK = false
    if canRequestStandard then standardOK = pcall(RequestRaidInfo) end
    if canRequestAscension then
        local queryOK, queryResult = pcall(api.QueryInstanceBinds)
        ascensionOK = queryOK and queryResult ~= false
    end

    local requested = standardOK or ascensionOK
    if not requested then
        self.scanPending = false
    end
    self:RefreshTable(core)
    return requested
end

function module:RequestStandardRefreshAfterBind(core)
    if type(RequestRaidInfo) == "function" then
        local ok = pcall(RequestRaidInfo)
        if ok then
            self.scanPending = true
            return true
        end
    end

    -- Custom-only clients have no standard cache/event to wait for.
    self:SnapshotCurrentCharacter(core, now_time())
    return false
end

function module:GetVisibleCharacters(core, currentTime, currentRealmOnly)
    local store = self:GetStore(core)
    local characters = {}
    if not store then return characters end

    local currentRealm = GetRealmName and GetRealmName() or "UnknownRealm"
    for _, character in pairs(store.characters) do
        if type(character) == "table" and (not currentRealmOnly or lower(character.realm) == lower(currentRealm)) then
            table.insert(characters, character)
        end
    end

    table.sort(characters, function(a, b)
        if lower(a.name) ~= lower(b.name) then return lower(a.name) < lower(b.name) end
        return lower(a.realm) < lower(b.realm)
    end)
    return characters
end

local function build_model_rows(catalog, difficulties, category)
    local rows = {}
    for _, content in ipairs(catalog) do
        local row = {
            key = content.key,
            label = content.label,
            category = category,
            cells = {},
            minimumResetAt = nil,
            maximumResetAt = nil
        }
        for _, difficulty in ipairs(difficulties) do
            row.cells[difficulty] = { byName = {}, entries = {} }
        end
        table.insert(rows, row)
    end
    return rows
end

function module:BuildTableModel(core, currentTime)
    currentTime = tonumber(currentTime) or now_time()
    local raidCatalog, worldBossCatalog = self:GetContentCatalog(core)
    local model = {
        raids = build_model_rows(raidCatalog, RAID_DIFFICULTIES, "raid"),
        worldBosses = build_model_rows(worldBossCatalog, WORLD_BOSS_DIFFICULTIES, "worldBoss")
    }
    local rowsByKey = {}
    local currentCharacter = self:GetCurrentCharacter()
    local resetTargets = self:GetResetTargets()

    for _, row in ipairs(model.raids) do rowsByKey[row.key] = row end
    for _, row in ipairs(model.worldBosses) do rowsByKey[row.key] = row end

    for _, character in ipairs(self:GetVisibleCharacters(core, currentTime, true)) do
        local isCurrentCharacter = self:IsCurrentCharacter(character, currentCharacter)
        for _, lockout in ipairs(character.lockouts or {}) do
            local row = rowsByKey[content_key(lockout.name)]
            local difficulty = trim(lockout.difficultyKey)
            local cell = row and row.cells[difficulty] or nil
            if cell then
                local remaining, resetKnown = self:GetRemaining(character, lockout, currentTime)
                local resettable = not resetKnown or remaining <= 0
                local name = tostring(character.name or "Unknown")
                local nameKey = lower(name)
                local existing = cell.byName[nameKey]
                local resetTarget = isCurrentCharacter and resetTargets[content_difficulty_key(lockout.name, difficulty)] or nil
                if not existing or (existing.resettable and not resettable) then
                    cell.byName[nameKey] = {
                        name = name,
                        resettable = resettable,
                        isCurrentCharacter = isCurrentCharacter,
                        resetTarget = resetTarget
                    }
                elseif resetTarget and not existing.resetTarget then
                    existing.resetTarget = resetTarget
                    existing.isCurrentCharacter = true
                end

                if resetKnown and remaining > 0 then
                    local resetAt = tonumber(lockout.resetAt)
                    if resetAt then
                        row.minimumResetAt = math.min(row.minimumResetAt or resetAt, resetAt)
                        row.maximumResetAt = math.max(row.maximumResetAt or resetAt, resetAt)
                    end
                end
            end
        end
    end

    for _, section in ipairs({ model.raids, model.worldBosses }) do
        for _, row in ipairs(section) do
            if row.maximumResetAt and row.minimumResetAt and row.maximumResetAt - row.minimumResetAt <= 300 then
                row.resetAt = row.maximumResetAt
            end
            for _, cell in pairs(row.cells) do
                for _, entry in pairs(cell.byName) do table.insert(cell.entries, entry) end
                table.sort(cell.entries, function(a, b) return lower(a.name) < lower(b.name) end)
            end
        end
    end

    return model
end

function module:FormatCellText(entries, difficulty)
    local lines = {}
    for _, entry in ipairs(entries or {}) do
        local color = entry.resettable and RESETTABLE_COLOR or (DIFFICULTY_COLOR[difficulty] or "|cffffffff")
        table.insert(lines, color .. tostring(entry.name or "Unknown") .. "|r")
    end
    if table.getn(lines) == 0 then return "|cff555555-|r" end
    return table.concat(lines, "\n")
end

function module:FormatRowLabel(row, currentTime)
    local label = tostring(row and row.label or "Unknown")
    local resetAt = tonumber(row and row.resetAt)
    currentTime = tonumber(currentTime) or now_time()
    if resetAt and resetAt > currentTime then
        label = label .. " |cffaaaaaa(" .. self:FormatDuration(resetAt - currentTime) .. ")|r"
    end
    return label
end

local function set_frame_background(frame, alpha)
    if not frame.background then
        frame.background = frame:CreateTexture(nil, "BACKGROUND")
        frame.background:SetAllPoints(frame)
    end
    frame.background:SetTexture(1, 1, 1, alpha or 0.04)
end

function module:CreateSectionControls(panel, sectionKey, difficulties)
    self.tableSections = self.tableSections or {}
    local section = self.tableSections[sectionKey]
    if section then return section end

    section = {
        difficulties = difficulties,
        rows = {}
    }
    section.header = CreateFrame("Frame", nil, panel)
    section.header:SetWidth(TABLE_WIDTH)
    section.header:SetHeight(TABLE_HEADER_HEIGHT)

    section.nameHeader = section.header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    section.nameHeader:SetPoint("TOPLEFT", section.header, "TOPLEFT", 6, 0)
    section.nameHeader:SetWidth(TABLE_LABEL_WIDTH - 12)
    section.nameHeader:SetJustifyH("LEFT")
    section.nameHeader:SetText(sectionKey == "raids" and "Raid" or "World boss")

    local cellWidth = (TABLE_WIDTH - TABLE_LABEL_WIDTH) / table.getn(difficulties)
    section.cellWidth = cellWidth
    section.difficultyHeaders = {}
    for index, difficulty in ipairs(difficulties) do
        local label = section.header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", section.header, "TOPLEFT", TABLE_LABEL_WIDTH + ((index - 1) * cellWidth), 0)
        label:SetWidth(cellWidth)
        label:SetJustifyH("CENTER")
        label:SetText((DIFFICULTY_COLOR[difficulty] or "|cffffffff") .. difficulty .. "|r")
        section.difficultyHeaders[difficulty] = label
    end

    self.tableSections[sectionKey] = section
    return section
end

function module:EnsureRowControls(panel, section, row)
    local controls = section.rows[row.key]
    if controls then return controls end

    controls = { cells = {} }
    controls.frame = CreateFrame("Frame", nil, panel)
    controls.frame:SetWidth(TABLE_WIDTH)
    controls.label = controls.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    controls.label:SetPoint("TOPLEFT", controls.frame, "TOPLEFT", 6, -5)
    controls.label:SetWidth(TABLE_LABEL_WIDTH - 12)
    controls.label:SetJustifyH("LEFT")
    controls.label:SetJustifyV("TOP")

    for index, difficulty in ipairs(section.difficulties) do
        local cell = {
            x = TABLE_LABEL_WIDTH + ((index - 1) * section.cellWidth) + 6,
            width = section.cellWidth - 12,
            buttons = {}
        }
        cell.placeholder = controls.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        cell.placeholder:SetPoint("TOPLEFT", controls.frame, "TOPLEFT", cell.x, -5)
        cell.placeholder:SetWidth(cell.width)
        cell.placeholder:SetJustifyH("LEFT")
        cell.placeholder:SetJustifyV("TOP")
        cell.placeholder:SetText("|cff555555-|r")
        controls.cells[difficulty] = cell
    end

    section.rows[row.key] = controls
    return controls
end

function module:EnsureCellButton(rowControls, cellControls, index)
    local button = cellControls.buttons[index]
    if button then return button end

    button = CreateFrame("Button", nil, rowControls.frame)
    button:SetWidth(cellControls.width)
    button:SetHeight(TABLE_LINE_HEIGHT)
    if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp") end
    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    button.text:SetAllPoints(button)
    button.text:SetJustifyH("LEFT")
    button.text:SetJustifyV("MIDDLE")
    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints(button)
    button.highlight:SetTexture(1, 1, 1, 0.09)

    button:SetScript("OnClick", function(self)
        if self.resetTarget then module:ShowResetConfirmation(self.core, self.resetTarget) end
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.resetTarget then
            GameTooltip:SetText("Reset " .. tostring(self.resetTarget.mapName or self.rowLabel), 1, 1, 1)
            GameTooltip:AddLine("Click to open Ascension's saved-ID reset confirmation.", nil, nil, nil, true)
        elseif not self.isCurrentCharacter then
            GameTooltip:SetText(tostring(self.entryName or "Saved character"), 1, 1, 1)
            GameTooltip:AddLine("Log into this character to reset its saved ID.", nil, nil, nil, true)
        else
            GameTooltip:SetText(tostring(self.entryName or "Saved ID"), 1, 1, 1)
            GameTooltip:AddLine("This saved ID is not currently available in Ascension's reset list.", nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    cellControls.buttons[index] = button
    return button
end

function module:RefreshCellControls(core, rowControls, cellControls, entries, difficulty, row)
    entries = entries or {}
    if table.getn(entries) == 0 then cellControls.placeholder:Show()
    else cellControls.placeholder:Hide() end

    local visible = 0
    for index, entry in ipairs(entries) do
        local button = self:EnsureCellButton(rowControls, cellControls, index)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", rowControls.frame, "TOPLEFT", cellControls.x, -5 - ((index - 1) * TABLE_LINE_HEIGHT))
        button.text:SetText(self:FormatCellText({ entry }, difficulty))
        button.core = core
        button.entryName = entry.name
        button.isCurrentCharacter = entry.isCurrentCharacter
        button.resetTarget = entry.resetTarget
        button.rowLabel = row.label
        button.highlight:SetAlpha(entry.resetTarget and 1 or 0)
        button:Show()
        visible = index
    end

    for index = visible + 1, table.getn(cellControls.buttons) do
        cellControls.buttons[index]:Hide()
    end
end

function module:RefreshTableSection(core, panel, section, rows, currentTime, y)
    section.header:ClearAllPoints()
    section.header:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
    section.header:Show()
    y = y - TABLE_HEADER_HEIGHT - 2

    local visibleRows = {}
    for index, row in ipairs(rows) do
        local controls = self:EnsureRowControls(panel, section, row)
        visibleRows[row.key] = true
        local maxLines = 1
        for _, difficulty in ipairs(section.difficulties) do
            maxLines = math.max(maxLines, table.getn(row.cells[difficulty].entries))
        end
        local rowHeight = math.max(24, (maxLines * TABLE_LINE_HEIGHT) + 10)

        controls.frame:ClearAllPoints()
        controls.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
        controls.frame:SetHeight(rowHeight)
        set_frame_background(controls.frame, index % 2 == 0 and 0.055 or 0.025)
        controls.label:SetHeight(rowHeight - 8)
        controls.label:SetText(self:FormatRowLabel(row, currentTime))
        for _, difficulty in ipairs(section.difficulties) do
            controls.cells[difficulty].placeholder:SetHeight(rowHeight - 8)
            self:RefreshCellControls(core, controls, controls.cells[difficulty], row.cells[difficulty].entries, difficulty, row)
        end
        controls.frame:Show()
        y = y - rowHeight
    end

    for key, controls in pairs(section.rows) do
        if not visibleRows[key] then controls.frame:Hide() end
    end
    return y - 14
end

function module:RefreshTable(core)
    if not self.settingsPage or not self.tableTopY then return end
    local currentTime = now_time()
    local model = self:BuildTableModel(core, currentTime)
    local raidSection = self:CreateSectionControls(self.settingsPage, "raids", RAID_DIFFICULTIES)
    local worldBossSection = self:CreateSectionControls(self.settingsPage, "worldBosses", WORLD_BOSS_DIFFICULTIES)
    local y = self.tableTopY

    y = self:RefreshTableSection(core, self.settingsPage, raidSection, model.raids, currentTime, y)
    y = self:RefreshTableSection(core, self.settingsPage, worldBossSection, model.worldBosses, currentTime, y)

    if self.legendLabel then
        self.legendLabel:ClearAllPoints()
        self.legendLabel:SetPoint("TOPLEFT", self.settingsPage, "TOPLEFT", 12, y)
        self.legendLabel:SetText("Click your character's name to reset that saved ID. |cff777777Grey = expired/resettable.|r")
        y = y - 24
    end
    self.settingsPage:SetHeight(math.max(520, math.abs(y) + 28))
end

function module:OnEvent(core, event, ...)
    if event == "UPDATE_INSTANCE_INFO" then
        self:SnapshotCurrentCharacter(core, now_time())
    elseif event == "QUERY_INSTANCE_BINDS_RESULT" then
        local first, second = ...
        local success = first
        if type(second) == "boolean" then success = second end
        if success ~= false then self:RequestStandardRefreshAfterBind(core) end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "RAID_INSTANCE_WELCOME" then
        self:RequestSnapshot(core, false)
    end
end

local EVENTS = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "RAID_INSTANCE_WELCOME",
    "UPDATE_INSTANCE_INFO",
    "QUERY_INSTANCE_BINDS_RESULT"
}

function module:OnEnable(core)
    self:GetStore(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event, ...) module:OnEvent(core, event, ...) end)
    end
    for _, event in ipairs(EVENTS) do safe_register(self.frame, event) end
    self:RequestSnapshot(core, false)
end

function module:OnDisable(core)
    self.scanPending = false
    if self.frame then
        for _, event in ipairs(EVENTS) do safe_unregister(self.frame, event) end
    end
    self:RefreshTable(core)
end

function module:BuildOptions(core, panel, y)
    self.settingsPage = panel
    self.tableTopY = y
    self.tableSections = {}
    self.legendLabel = core:CreateText(panel, "", 12, y, TABLE_WIDTH, "GameFontHighlightSmall")

    panel:SetScript("OnShow", function()
        module:RefreshTable(core)
        module:RequestSnapshot(core, false)
    end)

    self:RefreshTable(core)
    return y - 450
end

function module:RefreshOptions(core)
    self:RefreshTable(core)
end

MT:RegisterModule("RaidLockouts", module)
