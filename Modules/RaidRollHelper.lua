local MT = MinnTinkers

local module = {
    name = "Raid Roll Helper",
    desc = "Master-looter helper for MS/OS raid loot rolls with duplicate handling, tie rerolls, and multi-copy winners.",
    category = "Universal",
    defaults = {
        enabled = true,
        requireMasterLooter = true,
        autoStart = true,
        duration = 10,
        announceDuplicates = true,
        autoTieReroll = true,
        debug = false,
        channel = "auto",
        maxCopies = 10
    }
}

local MS_MAX = 100
local OS_MAX = 99

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

function module:GetDB(core)
    return core:GetModuleDB(self.key)
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

function module:CanStart(core, manual)
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
    if db.requireMasterLooter and not self:IsMasterLooter(core) then
        if manual then core:Print("You are not detected as master looter. Use /minn ml to check.") end
        return false
    end
    return true
end

function module:CountItemLinks(text)
    local count = 0
    for _ in string.gmatch(tostring(text or ""), "|Hitem:") do count = count + 1 end
    return count
end

function module:ParseStartText(text)
    text = trim(text)
    if text == "" or self:CountItemLinks(text) ~= 1 then return nil end

    local before, link, after = string.match(text, "^%s*(.-)%s*(|c%x+|Hitem:.-|h%[.-%]|h|r)%s*(.-)%s*$")
    if not link then return nil end

    before = trim(before)
    after = trim(after)
    if after ~= "" then return nil end

    local count = 1
    if before ~= "" then
        local n = string.match(before, "^(%d+)$") or string.match(before, "^(%d+)x$") or string.match(before, "^x(%d+)$")
        if not n then return nil end
        count = tonumber(n) or 1
    end

    local db = self:GetDB(MT) or {}
    local maxCopies = tonumber(db.maxCopies) or 10
    if count < 1 then count = 1 end
    if count > maxCopies then count = maxCopies end
    return link, count
end

function module:StartRoll(core, link, copies, manual)
    if not self:CanStart(core, manual) then return false end

    copies = tonumber(copies) or 1
    local duration = tonumber((self:GetDB(core) or {}).duration) or 10
    if duration < 3 then duration = 10 end

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
        countdowns = { 10, 5, 3, 2, 1 },
        countdownIndex = 1,
        reroll = false,
        baseWinners = {}
    }

    self:Send(core, "Roll 1-100 MS / 1-99 OS for " .. (copies > 1 and (tostring(copies) .. "x ") or "") .. tostring(link) .. ".")
    self:EnsureTimer(core)
    return true
end

function module:StartFromText(core, text, manual)
    local link, copies = self:ParseStartText(text)
    if not link then
        if manual then core:Print("Usage: /minn roll [itemlink] or /minn roll 3 [itemlink]") end
        return false
    end
    return self:StartRoll(core, link, copies, manual)
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
            self:Send(core, short_name(roll.player) .. " rolled more than once. First roll " .. tostring(first.roll) .. " " .. tostring(first.category) .. " will be accepted.")
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
    if #sorted <= slots then result.winners = sorted return result end

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

    result.winners = sorted
    return result
end

function module:StartReroll(core, previous, tie, baseWinners)
    local duration = tonumber((self:GetDB(core) or {}).duration) or 10
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
        countdowns = { 10, 5, 3, 2, 1 },
        countdownIndex = 1,
        reroll = true,
        category = tie.category,
        allowed = allowed,
        baseWinners = copy_list(baseWinners or {})
    }

    local rangeMax = tie.category == "OS" and OS_MAX or MS_MAX
    self:Send(core, "Tie for " .. tostring(previous.item) .. ": " .. format_names(tie.players) .. " rolled " .. tostring(tie.roll) .. " " .. tostring(tie.category) .. ". Reroll 1-" .. tostring(rangeMax) .. " for " .. tostring(tie.slots) .. " " .. (tie.slots == 1 and "copy" or "copies") .. ".")
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

    if #winners == 1 and active.copies == 1 then
        local winner = winners[1]
        self:Send(core, "Winner " .. tostring(winner.category) .. ": " .. short_name(winner.player) .. " " .. tostring(winner.roll) .. " for " .. tostring(active.item) .. ".")
    else
        self:Send(core, "Winners for " .. (active.copies > 1 and (tostring(active.copies) .. "x ") or "") .. tostring(active.item) .. ":")
        for i, winner in ipairs(winners) do
            self:Send(core, tostring(i) .. ". " .. short_name(winner.player) .. " " .. tostring(winner.roll) .. " " .. tostring(winner.category))
        end
        if #winners < active.copies then
            self:Send(core, "Only " .. tostring(#winners) .. " valid winner" .. (#winners == 1 and "" or "s") .. " for " .. tostring(active.copies) .. " copies.")
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
            if #ms == 0 then self:Send(core, "No MS rolls for " .. tostring(active.item) .. ". Checking OS rolls.") end
            self:StartReroll(core, active, osResult.tie, base)
            return
        end
        if #ms == 0 and #osResult.winners > 0 then self:Send(core, "No MS rolls for " .. tostring(active.item) .. ". Using OS rolls.") end
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
            self:Send(core, tostring(checkpoint) .. "...")
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

    local link, copies = self:ParseStartText(text)
    if not link then return end
    if not self:CanStart(core, false) then self:Debug(core, "Auto-start blocked.") return end
    self:StartRoll(core, link, copies, false)
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
    for _, roll in ipairs(active.rolls or {}) do core:Print(short_name(roll.player) .. " - " .. tostring(roll.roll) .. " " .. tostring(roll.category)) end
    if active.ignored and #active.ignored > 0 then core:Print("Ignored/duplicate rolls: " .. tostring(#active.ignored)) end
end

function module:Cancel(core)
    if not self.active then core:Print("No active raid roll to cancel.") return end
    self:Send(core, "Cancelled roll for " .. tostring(self.active.item) .. ".")
    self.lastRoll = self.active
    self.active = nil
    if self.frame then self.frame:SetScript("OnUpdate", nil) end
end

function module:StartFromText(core, text, manual)
    local link, copies = self:ParseStartText(text)
    if not link then if manual then core:Print("Usage: /minn roll [itemlink] or /minn roll 3 [itemlink]") end return false end
    return self:StartRoll(core, link, copies, manual)
end

function module:HandleSlash(core, message)
    message = core:Trim(message)
    local command, rest = string.match(message or "", "^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    rest = core:Trim(rest)

    if command == "roll" or command == "raidroll" or command == "lootroll" then
        local subcommand = string.lower((string.match(rest or "", "^(%S*)") or ""))
        if subcommand == "" or subcommand == "status" then self:PrintStatus(core)
        elseif subcommand == "cancel" or subcommand == "stop" then self:Cancel(core)
        elseif subcommand == "log" then self:PrintLog(core)
        elseif subcommand == "ml" or subcommand == "master" then self:PrintMasterLootStatus(core)
        elseif subcommand == "on" then core:SetModuleEnabled("RaidRollHelper", true) core:Print("RaidRollHelper enabled.")
        elseif subcommand == "off" then core:SetModuleEnabled("RaidRollHelper", false) core:Print("RaidRollHelper disabled.")
        else self:StartFromText(core, rest, true) end
        return true
    end

    if command == "ml" or command == "masterlooter" then self:PrintMasterLootStatus(core) return true end
    return false
end

function module:InstallSlashHook(core)
    if self.slashHooked then return end
    self.slashHooked = true
    local original = SlashCmdList and SlashCmdList["MINNTINKERS"]
    SlashCmdList["MINNTINKERS"] = function(message)
        if module:HandleSlash(core, message) then return end
        if original then original(message) end
    end
end

function module:OnEnable(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event, text) if event == "CHAT_MSG_SYSTEM" then module:OnSystemMessage(core, text) end end)
    end
    register(self.frame, "CHAT_MSG_SYSTEM")
    if not self.hooked and hooksecurefunc and SendChatMessage then
        self.hooked = true
        hooksecurefunc("SendChatMessage", function(text, chatType) if module.enabled then module:OnOutgoingChat(core, text, chatType) end end)
    end
end

function module:OnDisable(core)
    if self.frame then unregister(self.frame, "CHAT_MSG_SYSTEM") self.frame:SetScript("OnUpdate", nil) end
    self.active = nil
end

MT.version = "0.1.17"
module:InstallSlashHook(MT)
MT:RegisterModule("RaidRollHelper", module)
