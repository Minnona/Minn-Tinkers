local MT = MinnTinkers

local FRIENDLY_ICON = 6 -- Square
local ENEMY_ICON = 8 -- Skull
local DISCOVERY_SECONDS = 8
local DISCOVERY_INTERVAL = 0.25

local module = {
    name = "PvP",
    desc = "Shows clickable flag-carrier names beside Blizzard's battleground objectives and marks friendly/enemy carriers.",
    category = "PvP",
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

local function safe_register(frame, event)
    if frame and event then pcall(frame.RegisterEvent, frame, event) end
end

local function safe_unregister(frame, event)
    if frame and event then pcall(frame.UnregisterEvent, frame, event) end
end

local function combat_locked()
    return InCombatLockdown and InCombatLockdown()
end

local function in_battleground()
    if not IsInInstance then return false end
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "pvp"
end

local function strip_codes(text)
    text = tostring(text or "")
    text = string.gsub(text, "|Hplayer:[^|]+|h%[([^%]]+)%]|h", "%1")
    text = string.gsub(text, "|Hplayer:[^|]+|h([^|]+)|h", "%1")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

local function clean_name(text)
    text = trim(strip_codes(text))
    text = string.gsub(text, "^%[", "")
    text = string.gsub(text, "%]$", "")
    text = string.gsub(text, "[!%.,:;]+$", "")
    text = trim(text)

    local name = string.match(text, "^([^%s]+)")
    if not name then return nil end

    name = string.gsub(name, "%c", "")
    name = string.gsub(name, "[/;]", "")
    if name == "" then return nil end
    return name
end

local function name_key(name)
    name = clean_name(name)
    if not name then return "" end
    name = string.gsub(name, "%-.+$", "")
    return lower(name)
end

local function display_name(name)
    name = clean_name(name) or "Unknown"
    return string.gsub(name, "%-.+$", "")
end

local function unit_name_key(unit)
    if not unit or not UnitExists or not UnitExists(unit) or not UnitName then return "" end
    return name_key(UnitName(unit))
end

local function unit_matches(unit, name)
    local key = name_key(name)
    return key ~= "" and unit_name_key(unit) == key
end

local function flag_faction(text)
    text = lower(text)
    if string.find(text, "alliance flag", 1, true) then return "Alliance" end
    if string.find(text, "horde flag", 1, true) then return "Horde" end
    return "Neutral"
end

local function text_after(original, lowered, marker)
    local startAt = string.find(lowered, marker, 1, true)
    if not startAt then return nil end
    return clean_name(string.sub(original, startAt + string.len(marker)))
end

local function text_before(original, lowered, marker)
    local startAt = string.find(lowered, marker, 1, true)
    if not startAt then return nil end
    return clean_name(string.sub(original, 1, startAt - 1))
end

function module:ParseSystemMessage(text)
    text = trim(strip_codes(text))
    local lowered = lower(text)
    if text == "" or not string.find(lowered, "flag", 1, true) then return nil end

    local faction = flag_faction(lowered)
    local name = text_after(text, lowered, "flag was picked up by ")
        or text_after(text, lowered, "flag has been picked up by ")
        or text_after(text, lowered, "flag has been taken by ")
        or text_before(text, lowered, " picked up the ")
        or text_before(text, lowered, " has picked up the ")
        or text_before(text, lowered, " has taken the ")

    if name then
        return "pickup", faction, name
    end

    name = text_after(text, lowered, "flag was dropped by ")
        or text_after(text, lowered, "flag has been dropped by ")
        or text_before(text, lowered, " dropped the ")

    if name or string.find(lowered, "flag was dropped", 1, true) or string.find(lowered, "flag has been dropped", 1, true) then
        return "clear", faction, name
    end

    if string.find(lowered, "captured the", 1, true)
        or string.find(lowered, "flag was captured", 1, true)
        or string.find(lowered, "flag has been captured", 1, true)
        or string.find(lowered, "flags are now placed", 1, true)
        or string.find(lowered, "flag has been reset", 1, true)
        or string.find(lowered, "flag is now placed", 1, true) then
        return "reset", faction
    end

    if string.find(lowered, "flag was returned", 1, true)
        or string.find(lowered, "flag has been returned", 1, true)
        or string.find(lowered, "returned the", 1, true) then
        return "clear", faction
    end

    return nil
end

function module:ExtractWorldStateCarrier(text)
    text = trim(strip_codes(text))
    local lowered = lower(text)
    if text == "" then return nil end

    local name = text_after(text, lowered, "flag carrier: ")
        or text_after(text, lowered, "carrier: ")
        or text_after(text, lowered, "carried by ")
        or text_after(text, lowered, "held by ")

    if name and lower(name) ~= "none" and lower(name) ~= "unknown" then return name end
    return nil
end

function module:FindFriendlyUnit(name)
    if unit_matches("player", name) then return "player" end

    for i = 1, 40 do
        local unit = "raid" .. tostring(i)
        if unit_matches(unit, name) then return unit end
    end

    for i = 1, 4 do
        local unit = "party" .. tostring(i)
        if unit_matches(unit, name) then return unit end
    end

    return nil
end

function module:FindEnemyUnit(name)
    local direct = { "target", "focus", "mouseover", "targettarget", "focustarget" }
    for _, unit in ipairs(direct) do
        if unit_matches(unit, name) then return unit end
    end

    for i = 1, 40 do
        local unit = "raid" .. tostring(i) .. "target"
        if unit_matches(unit, name) then return unit end
    end

    for i = 1, 4 do
        local unit = "party" .. tostring(i) .. "target"
        if unit_matches(unit, name) then return unit end
    end

    return nil
end

function module:FindAnyUnit(name)
    return self:FindFriendlyUnit(name) or self:FindEnemyUnit(name)
end

function module:ShowSlotTooltip(slot, owner)
    if not slot or not slot.name or not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    GameTooltip:SetText(display_name(slot.name), 1, 1, 1)
    if slot.readyName == slot.name then
        GameTooltip:AddLine("Click to target if the carrier is visible.", nil, nil, nil, true)
    else
        GameTooltip:AddLine("Targeting will be ready after combat ends.", 1, 0.35, 0.2, true)
    end
    GameTooltip:Show()
end

function module:CreateSlot(key, y, prefix, color)
    local anchor = WorldStateAlwaysUpFrame or UIParent
    if not anchor or not UIParent then return nil end

    local action = CreateFrame("Button", "MinnTinkers_BattlegroundsPvP_" .. key .. "Target", UIParent, "SecureActionButtonTemplate")
    action:SetWidth(210)
    action:SetHeight(18)
    action:SetPoint("TOPLEFT", anchor, "TOP", 40, y)
    action:RegisterForClicks("AnyUp")
    action:SetFrameStrata("HIGH")
    action:EnableMouse(false)
    pcall(action.SetAttribute, action, "type1", nil)
    action:Show()

    local visual = CreateFrame("Frame", nil, UIParent)
    visual:SetWidth(210)
    visual:SetHeight(18)
    visual:SetPoint("TOPLEFT", anchor, "TOP", 40, y)
    visual:SetFrameStrata("HIGH")
    visual:SetFrameLevel(action:GetFrameLevel() + 1)
    visual:EnableMouse(false)

    local label = visual:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints(visual)
    label:SetJustifyH("LEFT")
    label:SetText("")

    local slot = {
        action = action,
        visual = visual,
        label = label,
        prefix = prefix,
        color = color
    }

    action:SetScript("OnEnter", function(self) module:ShowSlotTooltip(slot, self) end)
    action:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    visual:SetScript("OnEnter", function(self) module:ShowSlotTooltip(slot, self) end)
    visual:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    visual:Hide()
    return slot
end

function module:CreateDisplay()
    if self.slots then return true end
    if combat_locked() then
        self.displayPending = true
        return false
    end
    self.slots = {
        friendly = self:CreateSlot("Friendly", -16, "Friendly FC: ", "|cff33aaff"),
        enemy = self:CreateSlot("Enemy", -36, "Enemy FC: ", "|cffff4040")
    }
    self.displayPending = false
    return true
end

function module:ApplySlotSecure(slot)
    if not slot then return end
    local name = slot.name

    if combat_locked() then
        if name and slot.readyName == name then
            slot.visual:Show()
            slot.visual:EnableMouse(false)
        elseif not name and not slot.readyName then
            slot.visual:Hide()
            slot.visual:EnableMouse(false)
        else
            slot.visual:Show()
            slot.visual:EnableMouse(true)
        end
        slot.pendingSecure = slot.readyName ~= name
        return
    end

    local ok = true
    if name then
        ok = pcall(slot.action.SetAttribute, slot.action, "type1", "macro")
        if ok then ok = pcall(slot.action.SetAttribute, slot.action, "macrotext", "/targetexact " .. tostring(name)) end
    else
        ok = pcall(slot.action.SetAttribute, slot.action, "macrotext", "")
        if ok then ok = pcall(slot.action.SetAttribute, slot.action, "type1", nil) end
    end

    if ok then
        slot.readyName = name
        slot.pendingSecure = false
        slot.action:EnableMouse(name and true or false)
        slot.visual:EnableMouse(false)
        if name then slot.visual:Show() else slot.visual:Hide() end
    else
        slot.pendingSecure = true
        slot.visual:Show()
        slot.visual:EnableMouse(true)
    end
end

function module:SetSlot(slot, name)
    if not slot then return end
    slot.name = name
    if name then
        slot.label:SetText(tostring(slot.color) .. tostring(slot.prefix) .. "|r" .. display_name(name))
        slot.visual:Show()
    else
        slot.label:SetText("")
    end
    self:ApplySlotSecure(slot)
end

function module:ApplyPendingSecure()
    if not self.slots then return end
    self:ApplySlotSecure(self.slots.friendly)
    self:ApplySlotSecure(self.slots.enemy)
end

function module:ClearCarrierMarker(carrier)
    if not carrier then return end
    local icon = carrier.markerIcon
    if not icon then return end

    local unit = self:FindAnyUnit(carrier.name)
    local needsRetry = false
    if unit and GetRaidTargetIndex and GetRaidTargetIndex(unit) == icon and SetRaidTarget then
        pcall(SetRaidTarget, unit, 0)
        needsRetry = GetRaidTargetIndex(unit) == icon
    elseif not unit then
        needsRetry = true
    end

    if needsRetry then
        self.staleMarkers = self.staleMarkers or {}
        self.staleMarkers[name_key(carrier.name)] = { name = carrier.name, icon = icon }
    end

    carrier.markerIcon = nil
    carrier.markerGUID = nil
end

function module:ClearStaleMarkers()
    for key, marker in pairs(self.staleMarkers or {}) do
        local unit = self:FindAnyUnit(marker.name)
        if unit then
            if GetRaidTargetIndex and GetRaidTargetIndex(unit) == marker.icon and SetRaidTarget then
                pcall(SetRaidTarget, unit, 0)
                if GetRaidTargetIndex(unit) ~= marker.icon then self.staleMarkers[key] = nil end
            else
                self.staleMarkers[key] = nil
            end
        end
    end
end

function module:TryMarkCarrier(carrier, side)
    if not carrier then return false end
    local unit
    local icon

    if side == "friendly" then
        unit = self:FindFriendlyUnit(carrier.name)
        icon = FRIENDLY_ICON
    else
        unit = self:FindEnemyUnit(carrier.name)
        icon = ENEMY_ICON
    end

    if not unit then return false end
    carrier.unit = unit

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return true end
    if not GetRaidTargetIndex or not SetRaidTarget then return true end

    if GetRaidTargetIndex(unit) == icon then
        return true
    end

    local now = GetTime and GetTime() or 0
    if carrier.lastMarkAttempt and now - carrier.lastMarkAttempt < 0.75 then return true end
    carrier.lastMarkAttempt = now

    pcall(SetRaidTarget, unit, icon)
    if GetRaidTargetIndex(unit) == icon then
        carrier.markerIcon = icon
        carrier.markerGUID = UnitGUID and UnitGUID(unit) or nil
    end
    return true
end

function module:SetCarrier(flag, name)
    name = clean_name(name)
    if not name then return false end
    flag = flag or "Neutral"

    for otherFlag, carrier in pairs(self.carriers or {}) do
        if otherFlag ~= flag and name_key(carrier.name) == name_key(name) then
            self:ClearCarrierMarker(carrier)
            self.carriers[otherFlag] = nil
        end
    end

    local old = self.carriers and self.carriers[flag]
    if old and name_key(old.name) == name_key(name) then return false end
    if old then self:ClearCarrierMarker(old) end

    self.carriers = self.carriers or {}
    self.carriers[flag] = { name = name, flag = flag }
    if self.staleMarkers then self.staleMarkers[name_key(name)] = nil end
    return true
end

function module:ClearFlag(flag)
    flag = flag or "Neutral"
    local carrier = self.carriers and self.carriers[flag]
    if not carrier then return end
    self:ClearCarrierMarker(carrier)
    self.carriers[flag] = nil
end

function module:ClearName(name)
    local key = name_key(name)
    if key == "" then return end
    for flag, carrier in pairs(self.carriers or {}) do
        if name_key(carrier.name) == key then
            self:ClearCarrierMarker(carrier)
            self.carriers[flag] = nil
        end
    end
end

function module:ClearAll()
    for _, carrier in pairs(self.carriers or {}) do self:ClearCarrierMarker(carrier) end
    self.carriers = {}
    self.discoveryRemaining = 0
    if self.slots then
        self:SetSlot(self.slots.friendly, nil)
        self:SetSlot(self.slots.enemy, nil)
    end
end

function module:ScanWorldStates()
    if not GetNumWorldStateUI or not GetWorldStateUIInfo then return false end
    local changed = false
    local count = GetNumWorldStateUI() or 0

    for i = 1, count do
        local _, state, text, icon, dynamicIcon, tooltip, dynamicTooltip, extendedUI = GetWorldStateUIInfo(i)
        if (tonumber(state) or 0) > 0 and (not extendedUI or extendedUI == "") then
            local info = table.concat({ tostring(text or ""), tostring(icon or ""), tostring(dynamicIcon or ""), tostring(tooltip or ""), tostring(dynamicTooltip or "") }, " ")
            local name = self:ExtractWorldStateCarrier(dynamicTooltip) or self:ExtractWorldStateCarrier(tooltip)
            if name and self:SetCarrier(flag_faction(info), name) then changed = true end
        end
    end

    return changed
end

function module:RefreshAll()
    self:CreateDisplay()
    if not in_battleground() then
        if self.slots then
            self:SetSlot(self.slots.friendly, nil)
            self:SetSlot(self.slots.enemy, nil)
        end
        return
    end

    self:ClearStaleMarkers()
    local friendly
    local enemy
    local waitingForEnemy = false

    for _, carrier in pairs(self.carriers or {}) do
        local friendlyUnit = self:FindFriendlyUnit(carrier.name)
        local side = friendlyUnit and "friendly" or "enemy"

        if carrier.side and carrier.side ~= side then self:ClearCarrierMarker(carrier) end
        carrier.side = side

        local found = self:TryMarkCarrier(carrier, side)
        if side == "friendly" then
            friendly = carrier
        else
            enemy = carrier
            if not found then waitingForEnemy = true end
        end
    end

    self:SetSlot(self.slots and self.slots.friendly, friendly and friendly.name or nil)
    self:SetSlot(self.slots and self.slots.enemy, enemy and enemy.name or nil)
    if not waitingForEnemy then self.discoveryRemaining = 0 end
end

function module:EnsureOnUpdate(core)
    if not self.frame then return end
    self.frame:SetScript("OnUpdate", function(frame, elapsed) module:OnUpdate(core, frame, elapsed) end)
end

function module:ScheduleRefresh(core, delay)
    delay = tonumber(delay) or 0
    if self.refreshPending then
        self.refreshDelay = math.min(self.refreshDelay or delay, delay)
    else
        self.refreshPending = true
        self.refreshDelay = delay
    end
    self:EnsureOnUpdate(core)
end

function module:StartDiscovery(core)
    self.discoveryRemaining = DISCOVERY_SECONDS
    self.discoveryElapsed = 0
    self:EnsureOnUpdate(core)
end

function module:OnUpdate(core, frame, elapsed)
    local refresh = false

    if self.refreshPending then
        self.refreshDelay = (self.refreshDelay or 0) - elapsed
        if self.refreshDelay <= 0 then
            self.refreshPending = false
            refresh = true
        end
    end

    if (self.discoveryRemaining or 0) > 0 then
        self.discoveryRemaining = self.discoveryRemaining - elapsed
        self.discoveryElapsed = (self.discoveryElapsed or 0) + elapsed
        if self.discoveryElapsed >= DISCOVERY_INTERVAL then
            self.discoveryElapsed = 0
            refresh = true
        end
    end

    if refresh then self:RefreshAll(core) end

    if not self.refreshPending and (self.discoveryRemaining or 0) <= 0 then
        frame:SetScript("OnUpdate", nil)
    end
end

function module:OnSystemMessage(core, text)
    local action, flag, name = self:ParseSystemMessage(text)
    if not action then return end

    if action == "pickup" then
        self:SetCarrier(flag, name)
        self:StartDiscovery(core)
    elseif action == "clear" then
        if flag and flag ~= "Neutral" then self:ClearFlag(flag)
        elseif name then self:ClearName(name)
        else self:ClearFlag("Neutral") end
    elseif action == "reset" then
        self:ClearAll()
    end

    self:ScheduleRefresh(core, 0)
end

function module:OnEvent(core, event, ...)
    if self.disableCleanupPending and event == "PLAYER_REGEN_ENABLED" then
        self.disableCleanupPending = false
        self:ApplyPendingSecure()
        safe_unregister(self.frame, "PLAYER_REGEN_ENABLED")
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if self.displayPending then self:CreateDisplay() end
        self:ApplyPendingSecure()
        self:ScheduleRefresh(core, 0)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_ENTERING_BATTLEGROUND" or event == "ZONE_CHANGED_NEW_AREA" then
        if not in_battleground() then
            self:ClearAll()
        else
            if self:ScanWorldStates() then self:StartDiscovery(core) end
            self:ScheduleRefresh(core, 0.1)
        end
        return
    end

    if not in_battleground() then return end

    if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        self:OnSystemMessage(core, ...)
    elseif event == "UPDATE_WORLD_STATES" then
        if self:ScanWorldStates() then self:StartDiscovery(core) end
        self:ScheduleRefresh(core, 0.05)
    elseif event == "RAID_TARGET_UPDATE" then
        self:ScheduleRefresh(core, 0.1)
    else
        self:ScheduleRefresh(core, 0)
    end
end

local EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_ENTERING_BATTLEGROUND",
    "ZONE_CHANGED_NEW_AREA",
    "CHAT_MSG_BG_SYSTEM_ALLIANCE",
    "CHAT_MSG_BG_SYSTEM_HORDE",
    "CHAT_MSG_BG_SYSTEM_NEUTRAL",
    "UPDATE_WORLD_STATES",
    "RAID_ROSTER_UPDATE",
    "PARTY_MEMBERS_CHANGED",
    "UNIT_TARGET",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
    "UPDATE_MOUSEOVER_UNIT",
    "RAID_TARGET_UPDATE",
    "PLAYER_REGEN_ENABLED"
}

function module:OnEnable(core)
    self.disableCleanupPending = false
    self.carriers = self.carriers or {}
    self.staleMarkers = self.staleMarkers or {}
    self:CreateDisplay()

    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event, ...) module:OnEvent(core, event, ...) end)
    end

    for _, event in ipairs(EVENTS) do safe_register(self.frame, event) end

    if in_battleground() then
        if self:ScanWorldStates() then self:StartDiscovery(core) end
        self:ScheduleRefresh(core, 0.1)
    else
        self:ClearAll()
    end
end

function module:OnDisable(core)
    self:ClearAll()
    self.refreshPending = false
    self.discoveryRemaining = 0

    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        for _, event in ipairs(EVENTS) do safe_unregister(self.frame, event) end
    end

    if combat_locked() and self.slots then
        self.disableCleanupPending = true
        safe_register(self.frame, "PLAYER_REGEN_ENABLED")
    else
        self:ApplyPendingSecure()
    end
end

function module:BuildOptions(core, panel, y)
    return y
end

function module:RefreshOptions(core)
end

MT:RegisterModule("BattlegroundsPvP", module)
