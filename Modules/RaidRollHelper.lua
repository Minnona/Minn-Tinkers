local MT = MinnTinkers

local DEFAULT_DURATION = 15
local MS_MAX = 100
local OS_MAX = 99

local module = {
    name = "Raid Roll Helper",
    desc = "Master-looter helper for MS/OS raid loot rolls with duplicate handling, tie rerolls, and multi-copy winners.",
    category = "RaidRolls",
    defaults = {
        enabled = true,
        requireMasterLooter = true,
        autoStart = true,
        autoStartFromMasterLooter = true,
        autoStartFromRaidLeader = true,
        duration = DEFAULT_DURATION,
        announceDuplicates = true,
        autoTieReroll = true,
        debug = false,
        channel = "auto",
        maxCopies = 10
    }
}

local ROLL_WORDS = { roll = true, rolls = true, rolling = true, ["/roll"] = true }
local ROLL_RANGES = { ["1-100"] = true, ["1-99"] = true }
local FILLER_WORDS = { ["for"] = true }
local FLEXIBLE_WORDS = {
    ["on"] = true,
    ["please"] = true,
    ["now"] = true,
    ["ms"] = true,
    ["os"] = true,
    ["ms/os"] = true,
    ["main"] = true,
    ["mainspec"] = true,
    ["main-spec"] = true,
    ["off"] = true,
    ["offspec"] = true,
    ["off-spec"] = true,
    ["spec"] = true,
    ["need"] = true,
    ["greed"] = true,
    ["open"] = true,
    ["only"] = true
}
local FLEXIBLE_SEPARATORS = { ["/"] = true, [">"] = true }

local function trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function lower(text)
    return string.lower(tostring(text or ""))
end

local function player_key(name)
    name = tostring(name or "")
    name = string.gsub(name, "%-.+$", "")
    return lower(name)
end

local function short_name(name)
    if Ambiguate then
        local ok, result = pcall(Ambiguate, name, "short")
        if ok and result and result ~= "" then return result end
    end
    return tostring(name or "Unknown")
end

local function copy_list(src)
    local dst = {}
    if type(src) ~= "table" then return dst end
    for i, value in ipairs(src) do dst[i] = value end
    return dst
end

local function append_list(dst, src)
    if type(src) ~= "table" then return dst end
    for _, value in ipairs(src) do table.insert(dst, value) end
    return dst
end

local function format_names(rolls)
    local names = {}
    for _, roll in ipairs(rolls or {}) do table.insert(names, short_name(roll.player)) end
    return table.concat(names, ", ")
end

local function format_winner(winner, showCategory)
    if showCategory then
        return short_name(winner.player) .. " " .. tostring(winner.roll) .. " " .. tostring(winner.category)
    end
    return short_name(winner.player) .. " " .. tostring(winner.roll)
end

local function is_raid()
    return GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0
end

local function is_party()
    return GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0
end

local function can_raid_warning()
    return (IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())
end

local function register(frame, event)
    if frame and event then pcall(frame.RegisterEvent, frame, event) end
end

local function unregister(frame, event)
    if frame and event then pcall(frame.UnregisterEvent, frame, event) end
end

local function cycle_value(value, values)
    local index = 1
    for i, item in ipairs(values) do
        if item == value then index = i break end
    end
    index = index + 1
    if index > table.getn(values) then index = 1 end
    return values[index]
end

local function new_countdowns(duration)
    duration = tonumber(duration) or DEFAULT_DURATION
    local checkpoints = {}
    if duration > 10 then table.insert(checkpoints, 10) end
    if duration > 5 then table.insert(checkpoints, 5) end
    return checkpoints
end

local function parse_count_token(token)
    token = lower(trim(token))
    if token == "" then return nil end

    local n = string.match(token, "^x(%d+)$") or string.match(token, "^(%d+)x$") or string.match(token, "^(%d+)$")
    if not n then return nil end
    return tonumber(n)
end

function module:GetDB(core)
    local db = core:GetModuleDB(self.key)
    if db and not db.defaultDurationMigratedTo15 then
        if db.duration == nil or tonumber(db.duration) == 10 then
            db.duration = DEFAULT_DURATION
        end
        db.defaultDurationMigratedTo15 = true
    end
    return db
end

function module:Debug(core, text)
    local db = self:GetDB(core)
    if db and db.debug then core:Print("Raid Roll Helper: " .. tostring(text)) end
end

function module:GetChannel(core)
    local db = self:GetDB(core) or {}
    if db.channel == "raid_warning" then return "RAID_WARNING" end
    if db.channel == "raid" then return "RAID" end
    if db.channel == "party" then return "PARTY" end

    if is_raid() then
        if can_raid_warning() then return "RAID_WARNING" end
        return "RAID"
    end
    if is_party() then return "PARTY" end
    return "SAY"
end

function module:Send(core, text)
    text = tostring(text or "")
    if text == "" then return end

    local channel = self:GetChannel(core)
    local ok = pcall(SendChatMessage, text, channel)
    if not ok and channel == "RAID_WARNING" then
        if is_raid() then pcall(SendChatMessage, text, "RAID")
        elseif is_party() then pcall(SendChatMessage, text, "PARTY")
        else pcall(SendChatMessage, text, "SAY") end
    end
end

function module:GetMasterLooterInfo()
    local method, partyMaster, raidMaster
    if GetLootMethod then method, partyMaster, raidMaster = GetLootMethod() end

    local player = UnitName and UnitName("player") or nil
    local master = nil
    local isMaster = false

    if method == "master" then
        if partyMaster == 0 then
            master = player
            isMaster = true
        elseif type(raidMaster) == "number" and raidMaster > 0 and UnitName then
            master = UnitName("raid" .. tostring(raidMaster))
            isMaster = master and player and player_key(master) == player_key(player)
        elseif type(partyMaster) == "number" and partyMaster > 0 and UnitName then
            master = UnitName("party" .. tostring(partyMaster))
            isMaster = master and player and player_key(master) == player_key(player)
        end
    end

    return method or "unknown", master or "unknown", isMaster, partyMaster, raidMaster
end

function module:IsMasterLooter(core)
    local method, _, isMaster = self:GetMasterLooterInfo()
    return method == "master" and isMaster
end

function module:PrintMasterLootStatus(core)
    local method, master, isMaster, partyMaster, raidMaster = self:GetMasterLooterInfo()
    core:Print("Loot method: " .. tostring(method) .. "; master looter: " .. tostring(master) .. "; you are master looter: " .. (isMaster and "yes" or "no") .. ".")
    core:Print("Raw master values: party=" .. tostring(partyMaster) .. ", raid=" .. tostring(raidMaster) .. ".")
end

function module:GetRaidMemberStatus(name)
    local targetKey = player_key(name)
    if targetKey == "" or not GetRaidRosterInfo or not GetNumRaidMembers then return nil, nil, false end

    for i = 1, (GetNumRaidMembers() or 0) do
        local raidName, rank, _, _, _, _, _, _, _, _, isML = GetRaidRosterInfo(i)
        if raidName and player_key(raidName) == targetKey then
            return raidName, tonumber(rank) or 0, isML and true or false
        end
    end

    return nil, nil, false
end

function module:IsTrustedAnnouncer(core, sender)
    local db = self:GetDB(core)
    if not db then return false end

    local senderKey = player_key(sender)
    if senderKey == "" then return false end

    local playerName = UnitName and UnitName("player") or nil
    if playerName and senderKey == player_key(playerName) then
        return false
    end

    local _, master = self:GetMasterLooterInfo()
    if db.autoStartFromMasterLooter and master and master ~= "unknown" and player_key(master) == senderKey then
        return true, "master looter"
    end

    local _, rank, isML = self:GetRaidMemberStatus(sender)

    if db.autoStartFromMasterLooter and isML then
        return true, "master looter"
    end

    if db.autoStartFromRaidLeader and rank == 2 then
        return true, "raid leader"
    end

    return false
end

function module:CanStart(core, manual, allowWithoutMasterLooter)
    local db = self:GetDB(core)
    if not db or not db.enabled then
        if manual then core:Print("Raid Roll Helper is disabled.") end
        return false
    end
    if not is_raid() and not is_party() then
        if manual then core:Print("Raid Roll Helper needs a party or raid.") end
        return false
    end
    if self.active then
        if manual then core:Print("A raid roll is already active. Use /minn roll cancel first.") end
        return false
    end
    if db.requireMasterLooter and not allowWithoutMasterLooter and not self:IsMasterLooter(core) then
        if manual then core:Print("You are not detected as master looter. Use /minn roll ml to check.") end
        return false
    end
    return true
end

function module:CountItemLinks(text)
    local count = 0
    for _ in string.gmatch(tostring(text or ""), "|Hitem:") do count = count + 1 end
    return count
end

function module:ParseStartText(core, text)
    text = trim(text)
    if text == "" then return nil, nil, "empty text" end
    if self:CountItemLinks(text) ~= 1 then return nil, nil, "expected exactly one item link" end

    local before, link, after = string.match(text, "^%s*(.-)%s*(|c%x+|Hitem:.-|h%[.-%]|h|r)%s*(.-)%s*$")
    if not link then return nil, nil, "item link was not recognized" end

    before = trim(before)
    after = trim(after)

    local db = self:GetDB(core) or {}
    local maxCopies = tonumber(db.maxCopies) or 10
    local count = 1
    local sawCount = false
    local pendingX = false
    local sawFlexibleWord = false
    local sawRollCue = false

    local outside = lower(trim(before .. " " .. after))
    outside = string.gsub(outside, "1%s*%-%s*100", "1-100")
    outside = string.gsub(outside, "1%s*%-%s*99", "1-99")
    outside = string.gsub(outside, "%s*>%s*", " > ")
    outside = string.gsub(outside, "[,;:!%?%.%(%)]", " ")
    outside = string.gsub(outside, "%s+", " ")
    outside = trim(outside)

    local tokens = {}
    for token in string.gmatch(outside, "%S+") do
        table.insert(tokens, token)
        if ROLL_WORDS[token] or ROLL_RANGES[token] then sawRollCue = true end
    end

    for _, token in ipairs(tokens) do
        if pendingX then
            local n = tonumber(token)
            if not n or sawCount then return nil, nil, "invalid copy count" end
            if n < 1 or n > maxCopies then return nil, nil, "copy count is outside 1-" .. tostring(maxCopies) end
            count = n
            sawCount = true
            pendingX = false
        elseif token == "x" then
            pendingX = true
        elseif ROLL_WORDS[token] or FILLER_WORDS[token] then
            -- Allowed roll wording.
        elseif ROLL_RANGES[token] then
            -- A roll range is instruction text, not a copy count.
        elseif FLEXIBLE_WORDS[token] or FLEXIBLE_SEPARATORS[token] then
            sawFlexibleWord = true
        else
            local n = parse_count_token(token)
            if n then
                local isPlainRangeMaximum = string.match(token, "^%d+$") and sawRollCue and (n == 99 or n == 100)
                if not isPlainRangeMaximum then
                    if sawCount then return nil, nil, "more than one copy count" end
                    if n < 1 or n > maxCopies then return nil, nil, "copy count is outside 1-" .. tostring(maxCopies) end
                    count = n
                    sawCount = true
                end
            else
                return nil, nil, "unsupported word: " .. tostring(token)
            end
        end
    end

    if pendingX then return nil, nil, "copy count is missing after x" end
    if sawFlexibleWord and not sawRollCue then return nil, nil, "loot wording requires a roll cue" end

    count = tonumber(count) or 1

    return link, count
end

function module:StartRoll(core, link, copies, manual, allowWithoutMasterLooter)
    if not self:CanStart(core, manual, allowWithoutMasterLooter) then return false end

    copies = tonumber(copies) or 1
    local duration = tonumber((self:GetDB(core) or {}).duration) or DEFAULT_DURATION
    if duration < 3 then duration = DEFAULT_DURATION end

    self.active = {
        item = link,
        copies = copies,
        slots = copies,
        endsAt = (GetTime and GetTime() or 0) + duration,
        duration = duration,
        rolls = {},
        rollsByPlayer = {},
        ignored = {},
        duplicateNotified = {},
        countdowns = new_countdowns(duration),
        countdownIndex = 1,
        reroll = false,
        baseWinners = {}
    }

    self:Send(core, "Roll 1-100 MS / 1-99 OS for " .. (copies > 1 and (tostring(copies) .. "x ") or "") .. tostring(link) .. ". " .. tostring(duration) .. "s.")
    self:EnsureTimer(core)
    return true
end

function module:StartFromText(core, text, manual)
    local link, copies, parseError = self:ParseStartText(core, text)
    if not link then
        self:Debug(core, "Ignored manual start: " .. tostring(parseError or "not recognized"))
        if manual then core:Print("Usage: /minn roll [itemlink] or /minn roll 3 [itemlink]") end
        return false
    end
    return self:StartRoll(core, link, copies, manual, false)
end

function module:ParseSystemRoll(text)
    local player, roll, low, high = string.match(tostring(text or ""), "^(.+) rolls (%d+) %((%d+)%-(%d+)%)%.?$")
    if not player then return nil end

    roll, low, high = tonumber(roll), tonumber(low), tonumber(high)
    if not roll or not low or not high then return nil end

    local category = "INVALID"
    if low == 1 and high == MS_MAX then category = "MS"
    elseif low == 1 and high == OS_MAX then category = "OS" end

    return { player = short_name(player), roll = roll, low = low, high = high, category = category }
end

function module:AcceptRoll(core, roll)
    local active = self.active
    if not active or not roll then return end

    if roll.category == "INVALID" then
        table.insert(active.ignored, roll)
        self:Debug(core, "Ignored invalid roll range from " .. tostring(roll.player) .. ".")
        return
    end

    if active.reroll then
        if active.category and roll.category ~= active.category then
            table.insert(active.ignored, roll)
            self:Debug(core, "Ignored wrong reroll range from " .. tostring(roll.player) .. ".")
            return
        end
        if active.allowed and not active.allowed[player_key(roll.player)] then
            table.insert(active.ignored, roll)
            self:Debug(core, "Ignored reroll from non-tied player " .. tostring(roll.player) .. ".")
            return
        end
    end

    local key = player_key(roll.player)
    local first = active.rollsByPlayer[key]
    if first then
        table.insert(active.ignored, roll)
        local db = self:GetDB(core) or {}
        if db.announceDuplicates and not active.duplicateNotified[key] then
            active.duplicateNotified[key] = true
            self:Send(core, short_name(roll.player) .. " rolled more than once. First roll " .. tostring(first.roll) .. " will be accepted.")
        end
        return
    end

    active.rollsByPlayer[key] = roll
    table.insert(active.rolls, roll)
end

function module:GetPools(active)
    local ms, os = {}, {}
    for _, roll in ipairs((active and active.rolls) or {}) do
        if roll.category == "MS" then table.insert(ms, roll)
        elseif roll.category == "OS" then table.insert(os, roll) end
    end
    return ms, os
end

function module:SortRolls(list)
    table.sort(list, function(a, b)
        if a.roll == b.roll then return tostring(a.player) < tostring(b.player) end
        return a.roll > b.roll
    end)
end

function module:GetBestSet(pool, slots, category)
    local result = { winners = {}, tie = nil }
    slots = tonumber(slots) or 0
    if slots <= 0 then return result end

    local sorted = copy_list(pool)
    self:SortRolls(sorted)
    if #sorted == 0 then return result end

    if #sorted <= slots then
        result.winners = sorted
        return result
    end

    local cutoff = sorted[slots].roll
    local above, tied = {}, {}
    for _, roll in ipairs(sorted) do
        if roll.roll > cutoff then table.insert(above, roll)
        elseif roll.roll == cutoff then table.insert(tied, roll) end
    end

    local slotsForTie = slots - #above
    if #tied > slotsForTie then
        result.winners = above
        result.tie = { roll = cutoff, players = tied, slots = slotsForTie, category = category }
        return result
    end

    for i = 1, slots do
        if sorted[i] then table.insert(result.winners, sorted[i]) end
    end
    return result
end

function module:ShouldShowCategories(active, winners)
    if active and active.category == "OS" then return true end

    for _, roll in ipairs((active and active.rolls) or {}) do
        if roll.category == "OS" then return true end
    end

    for _, roll in ipairs((active and active.baseWinners) or {}) do
        if roll.category == "OS" then return true end
    end

    for _, roll in ipairs(winners or {}) do
        if roll.category == "OS" then return true end
    end

    return false
end

function module:StartReroll(core, previous, tie, baseWinners)
    local duration = tonumber((self:GetDB(core) or {}).duration) or DEFAULT_DURATION
    if duration < 3 then duration = DEFAULT_DURATION end

    local allowed = {}
    for _, roll in ipairs(tie.players or {}) do allowed[player_key(roll.player)] = true end

    self.active = {
        item = previous.item,
        copies = previous.copies,
        slots = tie.slots,
        endsAt = (GetTime and GetTime() or 0) + duration,
        duration = duration,
        rolls = {},
        rollsByPlayer = {},
        ignored = {},
        duplicateNotified = {},
        countdowns = new_countdowns(duration),
        countdownIndex = 1,
        reroll = true,
        category = tie.category,
        allowed = allowed,
        baseWinners = copy_list(baseWinners or {})
    }

    local rangeMax = tie.category == "OS" and OS_MAX or MS_MAX
    local categoryText = tie.category == "OS" and " OS" or ""
    self:Send(core, "Tie for " .. tostring(previous.item) .. ": " .. format_names(tie.players) .. " rolled " .. tostring(tie.roll) .. categoryText .. ". Reroll 1-" .. tostring(rangeMax) .. " for " .. tostring(tie.slots) .. " " .. (tie.slots == 1 and "copy" or "copies") .. ".")
    self:EnsureTimer(core)
end

function module:AnnounceFinal(core, active, winners)
    winners = winners or {}
    if #winners == 0 then
        self:Send(core, "No valid rolls for " .. tostring(active.item) .. ".")
        self.lastRoll = active
        self.active = nil
        return
    end

    local showCategory = self:ShouldShowCategories(active, winners)

    if #winners == 1 and active.copies == 1 then
        local winner = winners[1]
        local prefix = showCategory and ("Winner " .. tostring(winner.category) .. ": ") or "Winner: "
        self:Send(core, prefix .. format_winner(winner, false) .. " for " .. tostring(active.item) .. ".")
    else
        self:Send(core, "Winners for " .. (active.copies > 1 and (tostring(active.copies) .. "x ") or "") .. tostring(active.item) .. ":")
        for i, winner in ipairs(winners) do
            self:Send(core, tostring(i) .. ". " .. format_winner(winner, showCategory))
        end
    end

    active.finalWinners = winners
    self.lastRoll = active
    self.active = nil
end

function module:FinishRoll(core)
    local active = self.active
    if not active then return end

    if active.reroll then
        local base = copy_list(active.baseWinners or {})
        local result = self:GetBestSet(active.rolls or {}, active.slots or 1, active.category or "MS")
        if result.tie and (self:GetDB(core) or {}).autoTieReroll then
            local newBase = copy_list(base)
            append_list(newBase, result.winners)
            self:StartReroll(core, active, result.tie, newBase)
            return
        end
        append_list(base, result.winners)
        if #result.winners == 0 and #(active.rolls or {}) == 0 then self:Send(core, "No valid rerolls for " .. tostring(active.item) .. ".") end
        self:AnnounceFinal(core, active, base)
        return
    end

    local ms, os = self:GetPools(active)
    local winners = {}
    local msResult = self:GetBestSet(ms, active.slots or 1, "MS")
    if msResult.tie and (self:GetDB(core) or {}).autoTieReroll then self:StartReroll(core, active, msResult.tie, msResult.winners) return end
    append_list(winners, msResult.winners)

    local remaining = (active.slots or 1) - #winners
    if remaining > 0 then
        local osResult = self:GetBestSet(os, remaining, "OS")
        if osResult.tie and (self:GetDB(core) or {}).autoTieReroll then
            local base = copy_list(winners)
            append_list(base, osResult.winners)
            self:StartReroll(core, active, osResult.tie, base)
            return
        end
        append_list(winners, osResult.winners)
    end

    self:AnnounceFinal(core, active, winners)
end

function module:OnUpdate(core)
    local active = self.active
    if not active then if self.frame then self.frame:SetScript("OnUpdate", nil) end return end

    local now = GetTime and GetTime() or 0
    local remaining = math.ceil((active.endsAt or now) - now)
    while active.countdowns and active.countdowns[active.countdownIndex] do
        local checkpoint = active.countdowns[active.countdownIndex]
        if remaining <= checkpoint then
            self:Send(core, tostring(checkpoint) .. "s...")
            active.countdownIndex = active.countdownIndex + 1
        else
            break
        end
    end

    if now >= (active.endsAt or now) then
        if self.frame then self.frame:SetScript("OnUpdate", nil) end
        self:FinishRoll(core)
    end
end

function module:EnsureTimer(core)
    if self.frame then self.frame:SetScript("OnUpdate", function() module:OnUpdate(core) end) end
end

function module:OnSystemMessage(core, text)
    if not self.active then return end
    local roll = self:ParseSystemRoll(text)
    if roll then self:AcceptRoll(core, roll) end
end

function module:OnOutgoingChat(core, text, chatType)
    local db = self:GetDB(core)
    if not db or not db.enabled or not db.autoStart or self.active then return end
    chatType = tostring(chatType or "")
    if chatType ~= "RAID" and chatType ~= "RAID_WARNING" and chatType ~= "PARTY" then return end

    local link, copies, parseError = self:ParseStartText(core, text)
    if not link then
        self:Debug(core, "Ignored your chat start: " .. tostring(parseError or "not recognized"))
        return
    end
    if not self:CanStart(core, false, false) then self:Debug(core, "Auto-start blocked.") return end
    self:StartRoll(core, link, copies, false, false)
end

function module:OnIncomingChat(core, event, text, sender)
    local db = self:GetDB(core)
    if not db or not db.enabled or self.active then return end

    if event ~= "CHAT_MSG_RAID" and event ~= "CHAT_MSG_RAID_LEADER" and event ~= "CHAT_MSG_RAID_WARNING" then return end

    if self:CountItemLinks(text) ~= 1 then return end

    local trusted, reason = self:IsTrustedAnnouncer(core, sender)
    if not trusted then
        self:Debug(core, "Ignored item link from non-trusted announcer: " .. tostring(sender))
        return
    end

    local link, copies, parseError = self:ParseStartText(core, text)
    if not link then
        self:Debug(core, "Ignored trusted announcement: " .. tostring(parseError or "not recognized"))
        return
    end

    self:Debug(core, "Starting from " .. tostring(reason or "trusted announcer") .. ": " .. tostring(sender))
    self:StartRoll(core, link, copies, false, true)
end

function module:PrintStatus(core)
    local active = self.active
    if not active then
        core:Print(self.lastRoll and ("No active raid roll. Last item: " .. tostring(self.lastRoll.item) .. ".") or "No active raid roll.")
        return
    end
    local remaining = math.max(0, math.ceil((active.endsAt or 0) - (GetTime and GetTime() or 0)))
    local ms, os = self:GetPools(active)
    core:Print("Active raid roll: " .. tostring(active.item) .. ", " .. tostring(remaining) .. "s left, " .. tostring(active.copies or 1) .. " copy/copies.")
    core:Print("MS rolls: " .. tostring(#ms) .. "; OS rolls: " .. tostring(#os) .. "; ignored/duplicates: " .. tostring(#(active.ignored or {})) .. ".")
end

function module:PrintLog(core)
    local active = self.active or self.lastRoll
    if not active then core:Print("No raid roll log available.") return end
    core:Print("Raid roll log for " .. tostring(active.item) .. ":")
    local sorted = copy_list(active.rolls)
    self:SortRolls(sorted)
    for _, roll in ipairs(sorted) do core:Print(short_name(roll.player) .. " - " .. tostring(roll.roll) .. " " .. tostring(roll.category)) end
    if active.ignored and #active.ignored > 0 then core:Print("Ignored/duplicate rolls: " .. tostring(#active.ignored)) end
end

function module:Cancel(core)
    if not self.active then core:Print("No active raid roll to cancel.") return end
    self:Send(core, "Cancelled roll for " .. tostring(self.active.item) .. ".")
    self.lastRoll = self.active
    self.active = nil
    if self.frame then self.frame:SetScript("OnUpdate", nil) end
end

function module:HandleRollCommand(core, message)
    message = core:Trim(message)
    local subcommand, rest = string.match(message or "", "^(%S*)%s*(.-)$")
    subcommand = string.lower(subcommand or "")
    rest = core:Trim(rest)

    if subcommand == "" or subcommand == "status" then self:PrintStatus(core)
    elseif subcommand == "cancel" or subcommand == "stop" then self:Cancel(core)
    elseif subcommand == "log" then self:PrintLog(core)
    elseif subcommand == "ml" or subcommand == "master" or subcommand == "masterlooter" then self:PrintMasterLootStatus(core)
    elseif subcommand == "on" then core:SetModuleEnabled("RaidRollHelper", true) core:Print("Raid Roll Helper enabled.")
    elseif subcommand == "off" then core:SetModuleEnabled("RaidRollHelper", false) core:Print("Raid Roll Helper disabled.")
    else self:StartFromText(core, message, true) end
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}
    local controls = core.optionControls[self.key]
    local db = self:GetDB(core)

    local requireML = core:CreateCheckbox(panel, "MinnTinkers_RaidRollHelper_RequireML", "Require me to be master looter for my own starts", "Require me to be master looter for my own starts", "Prevents your own/manual raid roll starts unless you are detected as master looter. Trusted raid leader/master-looter announcements can still be tracked.", 42, y, db.requireMasterLooter, function(checked) core:GetModuleDB(module.key).requireMasterLooter = checked end)
    controls.requireMasterLooter = requireML
    y = y - 28

    local autoStart = core:CreateCheckbox(panel, "MinnTinkers_RaidRollHelper_AutoStart", "Auto-start when I link one item", "Auto-start when I link one item", "Starts from one item link with safe roll wording, MS/OS wording, a roll range, or an optional copy count.", 42, y, db.autoStart, function(checked) core:GetModuleDB(module.key).autoStart = checked end)
    controls.autoStart = autoStart
    y = y - 28

    local autoStartML = core:CreateCheckbox(panel, "MinnTinkers_RaidRollHelper_AutoStartML", "Auto-start from master looter item links", "Auto-start from master looter item links", "Tracks safe roll announcements from the detected master looter, including MS/OS wording, roll ranges, and copy counts.", 42, y, db.autoStartFromMasterLooter, function(checked) core:GetModuleDB(module.key).autoStartFromMasterLooter = checked end)
    controls.autoStartFromMasterLooter = autoStartML
    y = y - 28

    local autoStartLeader = core:CreateCheckbox(panel, "MinnTinkers_RaidRollHelper_AutoStartLeader", "Auto-start from raid leader item links", "Auto-start from raid leader item links", "Tracks safe roll announcements from the raid leader, including MS/OS wording, roll ranges, and copy counts.", 42, y, db.autoStartFromRaidLeader, function(checked) core:GetModuleDB(module.key).autoStartFromRaidLeader = checked end)
    controls.autoStartFromRaidLeader = autoStartLeader
    y = y - 28

    local duplicates = core:CreateCheckbox(panel, "MinnTinkers_RaidRollHelper_Duplicates", "Announce duplicate rolls", "Announce duplicate rolls", "First valid roll counts. Extra rolls are ignored and optionally announced.", 42, y, db.announceDuplicates, function(checked) core:GetModuleDB(module.key).announceDuplicates = checked end)
    controls.announceDuplicates = duplicates
    y = y - 28

    local ties = core:CreateCheckbox(panel, "MinnTinkers_RaidRollHelper_Ties", "Auto-handle cutoff ties with rerolls", "Auto-handle cutoff ties with rerolls", "If a tie affects who wins, only tied players are asked to reroll.", 42, y, db.autoTieReroll, function(checked) core:GetModuleDB(module.key).autoTieReroll = checked end)
    controls.autoTieReroll = ties
    y = y - 34

    local durationButton = core:CreateOptionButton(panel, "MinnTinkers_RaidRollHelper_Duration", "", 42, y, 220, 24, function()
        local d = core:GetModuleDB(module.key)
        d.duration = cycle_value(tonumber(d.duration) or DEFAULT_DURATION, { 15, 20, 30, 10 })
        core:RefreshOptions()
    end)
    controls.duration = durationButton

    local channelButton = core:CreateOptionButton(panel, "MinnTinkers_RaidRollHelper_Channel", "", 272, y, 220, 24, function()
        local d = core:GetModuleDB(module.key)
        d.channel = cycle_value(d.channel or "auto", { "auto", "raid_warning", "raid", "party" })
        core:RefreshOptions()
    end)
    controls.channel = channelButton
    y = y - 34

    core:CreateOptionButton(panel, "MinnTinkers_RaidRollHelper_CheckML", "Check master looter", 42, y, 150, 24, function() module:PrintMasterLootStatus(core) end)
    core:CreateOptionButton(panel, "MinnTinkers_RaidRollHelper_Status", "Roll status", 202, y, 120, 24, function() module:PrintStatus(core) end)
    core:CreateOptionButton(panel, "MinnTinkers_RaidRollHelper_Log", "Roll log", 332, y, 100, 24, function() module:PrintLog(core) end)
    y = y - 34

    core:CreateOptionButton(panel, "MinnTinkers_RaidRollHelper_Cancel", "Cancel active roll", 42, y, 150, 24, function() module:Cancel(core) end)
    y = y - 34

    core:CreateText(panel, "Supported starts: [item], roll [item] MS, roll 1-100 [item], [item] x2 roll MS.", 42, y, 520, "GameFontDisableSmall")
    y = y - 34

    return y
end

function module:RefreshOptions(core)
    local controls = core.optionControls[self.key]
    local db = self:GetDB(core)
    if not controls or not db then return end

    if controls.requireMasterLooter then controls.requireMasterLooter:SetChecked(db.requireMasterLooter and true or false) end
    if controls.autoStart then controls.autoStart:SetChecked(db.autoStart and true or false) end
    if controls.autoStartFromMasterLooter then controls.autoStartFromMasterLooter:SetChecked(db.autoStartFromMasterLooter and true or false) end
    if controls.autoStartFromRaidLeader then controls.autoStartFromRaidLeader:SetChecked(db.autoStartFromRaidLeader and true or false) end
    if controls.announceDuplicates then controls.announceDuplicates:SetChecked(db.announceDuplicates and true or false) end
    if controls.autoTieReroll then controls.autoTieReroll:SetChecked(db.autoTieReroll and true or false) end

    if controls.duration then controls.duration:SetText("Duration: " .. tostring(db.duration or DEFAULT_DURATION) .. "s") end
    if controls.channel then
        local label = "Auto"
        if db.channel == "raid_warning" then label = "Raid Warning"
        elseif db.channel == "raid" then label = "Raid"
        elseif db.channel == "party" then label = "Party" end
        controls.channel:SetText("Channel: " .. label)
    end
end

function module:OnEnable(core)
    self:GetDB(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event, text, sender)
            if event == "CHAT_MSG_SYSTEM" then
                module:OnSystemMessage(core, text)
            else
                module:OnIncomingChat(core, event, text, sender)
            end
        end)
    end

    register(self.frame, "CHAT_MSG_SYSTEM")
    register(self.frame, "CHAT_MSG_RAID")
    register(self.frame, "CHAT_MSG_RAID_LEADER")
    register(self.frame, "CHAT_MSG_RAID_WARNING")

    if not self.hooked and hooksecurefunc and SendChatMessage then
        self.hooked = true
        hooksecurefunc("SendChatMessage", function(text, chatType) if module.enabled then module:OnOutgoingChat(core, text, chatType) end end)
    end
end

function module:OnDisable(core)
    if self.frame then
        unregister(self.frame, "CHAT_MSG_SYSTEM")
        unregister(self.frame, "CHAT_MSG_RAID")
        unregister(self.frame, "CHAT_MSG_RAID_LEADER")
        unregister(self.frame, "CHAT_MSG_RAID_WARNING")
        self.frame:SetScript("OnUpdate", nil)
    end
    self.active = nil
end

MT:RegisterModule("RaidRollHelper", module)
