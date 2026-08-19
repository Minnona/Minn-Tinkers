local captured

if not table.getn then
    table.getn = function(values) return #values end
end
unpack = unpack or table.unpack

MinnTinkers = {
    RegisterModule = function(_, key, module)
        module.key = key
        captured = module
    end
}

local registered = {}
local unregistered = {}
local eventFrame = {
    RegisterEvent = function(_, event) registered[event] = true end,
    UnregisterEvent = function(_, event) unregistered[event] = true end,
    SetScript = function(self, script, handler) self[script] = handler end
}

CreateFrame = function() return eventFrame end

ChatFrame1 = { index = 1 }
ChatFrame3 = { index = 3 }

local windowNames = {
    [1] = "General",
    [3] = "Channels"
}

local memberships = {
    [1] = {
        { "General - Stormwind City", 1 },
        { "World", 4 },
        { "Trade - City", 2 }
    },
    [3] = {
        { "World", 4 }
    }
}

GetChatWindowInfo = function(index)
    return windowNames[index]
end

GetChatWindowChannels = function(index)
    local values = {}
    for _, channel in ipairs(memberships[index] or {}) do
        table.insert(values, channel[1])
        table.insert(values, channel[2])
    end
    return unpack(values)
end

local removes = {}
local adds = {}

local function find_channel(index, name)
    for position, channel in ipairs(memberships[index] or {}) do
        if channel[1] == name then return position, channel end
    end
    return nil, nil
end

ChatFrame_RemoveChannel = function(frame, name)
    table.insert(removes, { frame = frame.index, name = name })
    local position = find_channel(frame.index, name)
    if position then table.remove(memberships[frame.index], position) end
end

ChatFrame_AddChannel = function(frame, name)
    table.insert(adds, { frame = frame.index, name = name })
    if not find_channel(frame.index, name) then
        memberships[frame.index] = memberships[frame.index] or {}
        table.insert(memberships[frame.index], { name, 99 })
    end
end

local inInstance = true
local instanceType = "raid"
IsInInstance = function() return inInstance, instanceType end

dofile("Modules/InstanceChannelMute.lua")

local settings = {
    enabled = true,
    suppressInDungeons = true,
    suppressInRaids = true,
    suppressInBattlegrounds = true,
    selectedFrames = { ["1"] = true },
    selectedChannels = {
        general = "General",
        world = "World",
        lookingforgroup = "LookingForGroup"
    },
    restoreChannels = {}
}

local core = {
    GetModuleDB = function(_, key)
        assert(key == "InstanceChannelMute", "unexpected module DB key")
        return settings
    end
}

local windows = captured:DiscoverWindows(core)
assert(table.getn(windows) == 2, "configured chat windows were not discovered")

local channels = captured:GetWindowChannelMap(1)
assert(channels.general == "General - Stormwind City", "zone-specific General channel was not normalized")
assert(channels.trade == "Trade - City", "zone-specific Trade channel was not normalized")

captured:Update(core)
assert(not find_channel(1, "General - Stormwind City"), "General was not suppressed from the selected window")
assert(not find_channel(1, "World"), "World was not suppressed from the selected window")
assert(find_channel(1, "Trade - City"), "an unselected channel was suppressed")
assert(find_channel(3, "World"), "an unselected chat window was changed")
assert(table.getn(removes) == 2, "suppression removed an unexpected number of channels")
assert(settings.restoreChannels["1"].general == "General - Stormwind City", "exact General assignment was not recorded")
assert(settings.restoreChannels["1"].world == "World", "World assignment was not recorded")
assert(not settings.restoreChannels["1"].lookingforgroup, "an absent channel was recorded for restoration")

captured:Update(core)
assert(table.getn(removes) == 2, "repeated suppression removed channels twice")

inInstance = false
captured:Update(core)
assert(find_channel(1, "General - Stormwind City"), "General was not restored outside the raid")
assert(find_channel(1, "World"), "World was not restored outside the raid")
assert(table.getn(adds) == 2, "restoration added an unexpected number of channels")
assert(next(settings.restoreChannels) == nil, "restoration ledger was not cleared")

captured:Update(core)
assert(table.getn(adds) == 2, "repeated restoration added channels twice")

inInstance = true
instanceType = "party"
settings.suppressInDungeons = false
captured:Update(core)
assert(find_channel(1, "World"), "disabled dungeon scope still suppressed a channel")

settings.suppressInDungeons = true
captured:Update(core)
assert(not find_channel(1, "World"), "enabled dungeon scope did not suppress a channel")
captured:Restore(core)

instanceType = "pvp"
settings.suppressInBattlegrounds = false
captured:Update(core)
assert(find_channel(1, "World"), "disabled battleground scope still suppressed a channel")

settings.suppressInBattlegrounds = true
captured:Update(core)
assert(not find_channel(1, "World"), "battleground scope did not suppress a channel")
captured:Restore(core)

instanceType = "arena"
captured:Update(core)
assert(find_channel(1, "World"), "arena was treated as a battleground")

local worldPosition = find_channel(1, "World")
table.remove(memberships[1], worldPosition)
settings.restoreChannels = { ["1"] = { world = "World" } }
inInstance = false
captured:Update(core)
assert(find_channel(1, "World"), "persisted reload ledger was not restored")
assert(next(settings.restoreChannels) == nil, "persisted reload ledger was not cleared")

inInstance = true
instanceType = "raid"
captured:OnEnable(core)
assert(registered.PLAYER_ENTERING_WORLD and registered.ZONE_CHANGED_NEW_AREA, "instance transition events were not registered")
assert(eventFrame.OnEvent, "event handler was not installed")
assert(not find_channel(1, "World"), "OnEnable did not apply suppression")

captured:OnDisable(core)
assert(unregistered.PLAYER_ENTERING_WORLD and unregistered.ZONE_CHANGED_NEW_AREA, "instance transition events were not unregistered")
assert(find_channel(1, "World"), "OnDisable did not restore suppressed channels")

print("InstanceChannelMute tests passed")
