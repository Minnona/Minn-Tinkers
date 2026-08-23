local captured

MinnTinkers = {
    RegisterModule = function(_, _, module)
        captured = module
    end
}

dofile("Modules/RaidRollHelper.lua")

local settings = { enabled = true, maxCopies = 10 }
local core = {
    GetModuleDB = function() return settings end
}

local item = "|cffffffff|Hitem:123:0:0:0:0:0:0:0|h[Test Item]|h|r"

local accepted = {
    { item, 1 },
    { "roll " .. item, 1 },
    { item .. " roll", 1 },
    { "2 " .. item, 2 },
    { item .. " x2 roll", 2 },
    { "roll " .. item .. " x2", 2 },
    { "roll " .. item .. " ms", 1 },
    { "MS roll " .. item, 1 },
    { "please roll on " .. item .. " for MS", 1 },
    { "roll " .. item .. " MS/OS", 1 },
    { "roll 1-100 MS " .. item, 1 },
    { "roll 1 - 99 OS " .. item, 1 },
    { "/roll 100 for " .. item, 1 },
    { "roll 100 " .. item, 1 },
    { "100 " .. item .. " roll", 1 },
    { "roll " .. item .. " x3 MS", 3 },
    { item .. " 3x, roll MS", 3 },
    { "3 rolls for " .. item, 3 },
    { "roll " .. item .. " MS > OS", 1 }
}

local rejected = {
    "MS " .. item,
    "please " .. item,
    "anyone need " .. item,
    "do not roll " .. item .. " MS",
    "roll " .. item .. " someday",
    "roll 11 " .. item,
    "roll x11 " .. item,
    "100 " .. item,
    "roll " .. item .. " 2 3",
    "roll " .. item .. " " .. item
}

for index, test in ipairs(accepted) do
    local link, copies, reason = captured:ParseStartText(core, test[1])
    assert(link == item, "accepted case " .. tostring(index) .. " did not return its item: " .. tostring(reason))
    assert(copies == test[2], "accepted case " .. tostring(index) .. " returned " .. tostring(copies) .. " copies")
end

for index, text in ipairs(rejected) do
    local link = captured:ParseStartText(core, text)
    assert(link == nil, "rejected case " .. tostring(index) .. " was accepted")
end

local starts = 0
local startedEvent
captured.IsTrustedAnnouncer = function() return true, "raid leader" end
captured.StartRoll = function(_, _, link, copies)
    starts = starts + 1
    startedEvent = { link = link, copies = copies }
    return true
end

captured:OnIncomingChat(core, "CHAT_MSG_RAID_LEADER", "roll " .. item .. " MS", "Thefist")
assert(starts == 1, "raid leader /raid message did not reach roll activation")
assert(startedEvent.link == item and startedEvent.copies == 1, "raid leader start was parsed incorrectly")

captured:OnIncomingChat(core, "CHAT_MSG_PARTY_LEADER", "roll " .. item, "Thefist")
assert(starts == 1, "unsupported leader channel reached raid roll activation")

local registered = {}
local unregistered = {}
local testFrame = {}
function testFrame:SetScript() end
function testFrame:RegisterEvent(event) registered[event] = true end
function testFrame:UnregisterEvent(event) unregistered[event] = true end

CreateFrame = function() return testFrame end
hooksecurefunc = nil
SendChatMessage = nil
captured.frame = nil
captured:OnEnable(core)
assert(registered.CHAT_MSG_RAID_LEADER, "raid leader chat event was not registered")
captured:OnDisable(core)
assert(unregistered.CHAT_MSG_RAID_LEADER, "raid leader chat event was not unregistered")

local printed = {}
local logCore = {
    Print = function(_, message) table.insert(printed, message) end
}
captured.active = {
    item = item,
    rolls = {
        { player = "Lowroller", roll = 17, category = "MS" },
        { player = "Zed", roll = 88, category = "OS" },
        { player = "Alpha", roll = 88, category = "MS" },
        { player = "Toproller", roll = 100, category = "MS" }
    },
    ignored = {}
}
captured:PrintLog(logCore)
assert(string.find(printed[2], "Toproller - 100 MS", 1, true), "roll log did not print the highest roll first")
assert(string.find(printed[3], "Alpha - 88 MS", 1, true), "roll log tie order was not deterministic")
assert(string.find(printed[4], "Zed - 88 OS", 1, true), "roll log omitted the second tied roll")
assert(string.find(printed[5], "Lowroller - 17 MS", 1, true), "roll log did not print the lowest roll last")
assert(captured.active.rolls[1].player == "Lowroller", "printing the roll log mutated the live roll order")

print("RaidRollHelper parser tests passed: " .. tostring(#accepted + #rejected))
