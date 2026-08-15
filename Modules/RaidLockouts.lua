local MT = MinnTinkers

local STORE_SCHEMA = 1
local EXPIRED_RETENTION = 30 * 24 * 60 * 60
local REQUEST_THROTTLE = 5
local STALE_SECONDS = 3 * 24 * 60 * 60

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

local module = {
    name = "Raid lockout tracker",
    desc = "Tracks raid lockouts and reset times across characters that use this account's SavedVariables.",
    category = "RaidLockouts",
    defaults = {
        enabled = true,
        currentRealmOnly = true,
        showExpired = false,
        viewMode = "raid"
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

function module:FormatAge(timestamp, currentTime)
    timestamp = tonumber(timestamp) or 0
    currentTime = tonumber(currentTime) or now_time()
    if timestamp <= 0 then return "never" end

    local elapsed = math.max(0, currentTime - timestamp)
    if elapsed < 60 then return "just now" end
    if elapsed < 3600 then return tostring(math.floor(elapsed / 60)) .. "m ago" end
    if elapsed < 86400 then return tostring(math.floor(elapsed / 3600)) .. "h ago" end
    return tostring(math.floor(elapsed / 86400)) .. "d ago"
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
    return store
end

function module:GetSettings(core)
    local db = core and core:GetModuleDB(self.key) or nil
    return db or self.defaults
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

function module:CollectCurrentLockouts(currentTime)
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

    table.sort(lockouts, function(a, b)
        if lower(a.name) ~= lower(b.name) then return lower(a.name) < lower(b.name) end
        if difficulty_rank(a.difficultyKey) ~= difficulty_rank(b.difficultyKey) then
            return difficulty_rank(a.difficultyKey) < difficulty_rank(b.difficultyKey)
        end
        return (a.maxPlayers or 0) < (b.maxPlayers or 0)
    end)
    return lockouts
end

function module:SnapshotCurrentCharacter(core, currentTime)
    local store = self:GetStore(core)
    if not store then return false end

    currentTime = tonumber(currentTime) or now_time()
    local info = self:GetCurrentCharacter()
    local key = character_key(info.name, info.realm, info.guid)
    store.characters[key] = {
        name = info.name,
        realm = info.realm,
        guid = info.guid,
        className = info.className,
        classToken = info.classToken,
        faction = info.faction,
        lastScan = currentTime,
        lockouts = self:CollectCurrentLockouts(currentTime)
    }

    self.scanPending = false
    self.lastSnapshotAt = currentTime
    self.statusMessage = "Updated " .. tostring(info.name) .. " " .. self:FormatAge(currentTime, currentTime) .. "."
    self:PruneStore(core, currentTime)
    self:RefreshReport(core)
    return true
end

function module:RequestSnapshot(core, force)
    if not RequestRaidInfo then
        self.statusMessage = "Raid lockout API is unavailable."
        self:RefreshReport(core)
        return false
    end

    local currentTime = now_time()
    if not force and self.lastRequestAt and currentTime - self.lastRequestAt < REQUEST_THROTTLE then
        return false
    end

    self.lastRequestAt = currentTime
    self.scanPending = true
    self.statusMessage = "Requesting current character lockouts..."
    local ok = pcall(RequestRaidInfo)
    if not ok then
        self.scanPending = false
        self.statusMessage = "Could not request raid lockouts."
    end
    self:RefreshReport(core)
    return ok and true or false
end

function module:ForgetCurrentCharacter(core)
    local store = self:GetStore(core)
    if not store then return end
    local info = self:GetCurrentCharacter()
    local key = character_key(info.name, info.realm, info.guid)
    store.characters[key] = nil
    self.statusMessage = "Forgot stored data for " .. tostring(info.name) .. ". Refresh to add it again."
    self:RefreshReport(core)
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

function module:FormatLockoutEntry(character, lockout, currentTime, includeRealm)
    local name = tostring(character.name or "Unknown")
    if includeRealm then name = name .. "-" .. tostring(character.realm or "UnknownRealm") end

    local remaining, resetKnown = self:GetRemaining(character, lockout, currentTime)
    local timer = resetKnown and self:FormatDuration(remaining) or "reset unknown"
    if resetKnown and remaining <= 0 then timer = "|cff777777" .. timer .. "|r" end

    local details = {}
    if (tonumber(lockout.maxPlayers) or 0) > 0 then table.insert(details, tostring(lockout.maxPlayers) .. "p") end
    if lockout.extended then table.insert(details, "extended") end
    if table.getn(details) > 0 then timer = timer .. ", " .. table.concat(details, ", ") end
    return name .. " (" .. timer .. ")"
end

function module:BuildRaidView(lines, characters, currentTime, showExpired, includeRealm)
    local raids = {}

    for _, character in ipairs(characters) do
        for _, lockout in ipairs(character.lockouts or {}) do
            local remaining, resetKnown = self:GetRemaining(character, lockout, currentTime)
            if not resetKnown or showExpired or remaining > 0 then
                local raidName = trim(lockout.name)
                local difficulty = trim(lockout.difficultyKey)
                if raidName ~= "" then
                    raids[raidName] = raids[raidName] or {}
                    raids[raidName][difficulty] = raids[raidName][difficulty] or {}
                    table.insert(raids[raidName][difficulty], { character = character, lockout = lockout })
                end
            end
        end
    end

    local raidNames = {}
    for raidName in pairs(raids) do table.insert(raidNames, raidName) end
    table.sort(raidNames, function(a, b) return lower(a) < lower(b) end)

    if table.getn(raidNames) == 0 then
        table.insert(lines, "|cffaaaaaaNo saved raid lockouts in this view.|r")
        return
    end

    for _, raidName in ipairs(raidNames) do
        table.insert(lines, "|cffffd100" .. raidName .. "|r")
        local difficulties = raids[raidName]

        for _, difficulty in ipairs(DIFFICULTY_ORDER) do
            local entries = difficulties[difficulty] or {}
            table.sort(entries, function(a, b) return lower(a.character.name) < lower(b.character.name) end)
            local names = {}
            for _, entry in ipairs(entries) do
                table.insert(names, self:FormatLockoutEntry(entry.character, entry.lockout, currentTime, includeRealm))
            end
            local color = DIFFICULTY_COLOR[difficulty] or "|cffffffff"
            table.insert(lines, "  " .. color .. difficulty .. ":|r " .. (table.getn(names) > 0 and table.concat(names, ", ") or "|cff666666-|r"))
        end

        local extras = {}
        for difficulty in pairs(difficulties) do
            if not DIFFICULTY_RANK[difficulty] then table.insert(extras, difficulty) end
        end
        table.sort(extras, function(a, b) return lower(a) < lower(b) end)
        for _, difficulty in ipairs(extras) do
            local names = {}
            for _, entry in ipairs(difficulties[difficulty]) do
                table.insert(names, self:FormatLockoutEntry(entry.character, entry.lockout, currentTime, includeRealm))
            end
            table.insert(lines, "  |cffffffff" .. difficulty .. ":|r " .. table.concat(names, ", "))
        end
        table.insert(lines, "")
    end
end

function module:BuildCharacterView(lines, characters, currentTime, showExpired, includeRealm)
    if table.getn(characters) == 0 then
        table.insert(lines, "|cffaaaaaaNo characters have been scanned in this view.|r")
        return
    end

    for _, character in ipairs(characters) do
        local heading = tostring(character.name or "Unknown")
        if includeRealm then heading = heading .. "-" .. tostring(character.realm or "UnknownRealm") end
        heading = heading .. " |cff888888(scanned " .. self:FormatAge(character.lastScan, currentTime) .. ")|r"
        table.insert(lines, "|cffffd100" .. heading .. "|r")

        local visible = 0
        for _, lockout in ipairs(character.lockouts or {}) do
            local remaining, resetKnown = self:GetRemaining(character, lockout, currentTime)
            if not resetKnown or showExpired or remaining > 0 then
                visible = visible + 1
                local difficulty = trim(lockout.difficultyKey)
                local color = DIFFICULTY_COLOR[difficulty] or "|cffffffff"
                local timer = resetKnown and self:FormatDuration(remaining) or "reset unknown"
                if resetKnown and remaining <= 0 then timer = "|cff777777" .. timer .. "|r" end
                local size = (tonumber(lockout.maxPlayers) or 0) > 0 and (" - " .. tostring(lockout.maxPlayers) .. "p") or ""
                local extended = lockout.extended and " - extended" or ""
                table.insert(lines, "  " .. tostring(lockout.name or "Unknown Raid") .. " - " .. color .. difficulty .. "|r" .. size .. " - " .. timer .. extended)
            end
        end

        if visible == 0 then table.insert(lines, "  |cff666666No saved raid lockouts.|r") end
        table.insert(lines, "")
    end
end

function module:BuildReport(core, currentTime)
    currentTime = tonumber(currentTime) or now_time()
    local db = self:GetSettings(core)
    local currentRealmOnly = db.currentRealmOnly ~= false
    local showExpired = db.showExpired and true or false
    local characters = self:GetVisibleCharacters(core, currentTime, currentRealmOnly)
    local lines = {}

    table.insert(lines, "|cffaaaaaaOffline characters show their last collected snapshot; log into them to refresh it.|r")
    table.insert(lines, "")

    if db.viewMode == "character" then
        self:BuildCharacterView(lines, characters, currentTime, showExpired, not currentRealmOnly)
    else
        self:BuildRaidView(lines, characters, currentTime, showExpired, not currentRealmOnly)
    end

    table.insert(lines, "|cffffd100Known characters|r")
    if table.getn(characters) == 0 then
        table.insert(lines, "  |cff666666None yet. Log into a character with tracking enabled.|r")
    else
        for _, character in ipairs(characters) do
            local active = 0
            for _, lockout in ipairs(character.lockouts or {}) do
                local remaining, resetKnown = self:GetRemaining(character, lockout, currentTime)
                if not resetKnown or remaining > 0 then active = active + 1 end
            end
            local name = tostring(character.name or "Unknown")
            if not currentRealmOnly then name = name .. "-" .. tostring(character.realm or "UnknownRealm") end
            local age = self:FormatAge(character.lastScan, currentTime)
            if currentTime - (tonumber(character.lastScan) or 0) > STALE_SECONDS then age = "|cffff6666" .. age .. " (stale)|r" end
            table.insert(lines, "  " .. name .. " - " .. tostring(active) .. " active - scanned " .. age)
        end
    end

    return table.concat(lines, "\n"), table.getn(lines)
end

function module:RefreshReport(core)
    if not self.reportLabel then return end
    local report, lineCount = self:BuildReport(core, now_time())
    self.reportLabel:SetText(report)

    local height = math.max(120, (tonumber(lineCount) or 1) * 16)
    self.reportLabel:SetHeight(height)
    if self.settingsPage and self.reportY then
        self.settingsPage:SetHeight(math.max(520, math.abs(self.reportY) + height + 50))
    end

    if self.statusLabel then
        self.statusLabel:SetText(self.statusMessage or "Waiting for the current character scan.")
    end

    local controls = core.optionControls and core.optionControls[self.key]
    local db = self:GetSettings(core)
    if controls and controls.viewMode then
        controls.viewMode:SetText(db.viewMode == "character" and "View: by character" or "View: by raid")
    end
end

function module:OnEvent(core, event)
    if event == "UPDATE_INSTANCE_INFO" then
        self:SnapshotCurrentCharacter(core, now_time())
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "RAID_INSTANCE_WELCOME" then
        self:RequestSnapshot(core, false)
    end
end

local EVENTS = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "RAID_INSTANCE_WELCOME",
    "UPDATE_INSTANCE_INFO"
}

function module:OnEnable(core)
    self:GetStore(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event) module:OnEvent(core, event) end)
    end
    for _, event in ipairs(EVENTS) do safe_register(self.frame, event) end
    self:RequestSnapshot(core, false)
end

function module:OnDisable(core)
    self.scanPending = false
    if self.frame then
        for _, event in ipairs(EVENTS) do safe_unregister(self.frame, event) end
    end
    self.statusMessage = "Tracking is disabled; stored snapshots remain available."
    self:RefreshReport(core)
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}
    local controls = core.optionControls[self.key]
    local db = self:GetSettings(core)

    controls.currentRealmOnly = core:CreateCheckbox(
        panel,
        "MinnTinkers_RaidLockouts_CurrentRealmOnly",
        "Show current realm only",
        "Show current realm only",
        "Hides snapshots collected from characters on other realms without deleting them.",
        42,
        y,
        db.currentRealmOnly,
        function(checked)
            core:GetModuleDB(module.key).currentRealmOnly = checked
            module:RefreshReport(core)
        end
    )
    y = y - 30

    controls.showExpired = core:CreateCheckbox(
        panel,
        "MinnTinkers_RaidLockouts_ShowExpired",
        "Show recently expired lockouts",
        "Show recently expired lockouts",
        "Displays expired offline snapshots for up to 30 days. Current-character scans replace old data immediately.",
        42,
        y,
        db.showExpired,
        function(checked)
            core:GetModuleDB(module.key).showExpired = checked
            module:RefreshReport(core)
        end
    )
    y = y - 36

    controls.viewMode = core:CreateOptionButton(panel, "MinnTinkers_RaidLockouts_View", "View: by raid", 42, y, 160, 24, function()
        local settings = core:GetModuleDB(module.key)
        settings.viewMode = settings.viewMode == "character" and "raid" or "character"
        module:RefreshReport(core)
    end)

    controls.refresh = core:CreateOptionButton(panel, "MinnTinkers_RaidLockouts_Refresh", "Refresh this character", 212, y, 170, 24, function()
        if module.enabled then module:RequestSnapshot(core, true)
        else core:Print("Enable Raid lockout tracker before refreshing.") end
    end)

    controls.forget = core:CreateOptionButton(panel, "MinnTinkers_RaidLockouts_Forget", "Forget this character", 392, y, 160, 24, function()
        module:ForgetCurrentCharacter(core)
    end)
    y = y - 34

    self.statusLabel = core:CreateText(panel, "Waiting for the current character scan.", 42, y, 520, "GameFontHighlightSmall")
    y = y - 30
    core:CreateText(panel, "Saved raid lockouts", 42, y, 520, "GameFontNormal")
    y = y - 24

    self.reportLabel = core:CreateText(panel, "", 42, y, 520, "GameFontHighlightSmall")
    self.reportLabel:SetJustifyV("TOP")
    self.reportY = y
    self.settingsPage = panel

    panel:SetScript("OnShow", function()
        module:RefreshReport(core)
        if module.enabled then module:RequestSnapshot(core, false) end
    end)

    self:RefreshReport(core)
    return y - 360
end

function module:RefreshOptions(core)
    local controls = core.optionControls[self.key]
    local db = self:GetSettings(core)
    if not controls or not db then return end

    if controls.currentRealmOnly then controls.currentRealmOnly:SetChecked(db.currentRealmOnly and true or false) end
    if controls.showExpired then controls.showExpired:SetChecked(db.showExpired and true or false) end
    self:RefreshReport(core)
end

MT:RegisterModule("RaidLockouts", module)
