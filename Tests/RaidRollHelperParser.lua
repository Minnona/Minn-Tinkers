local captured

MinnTinkers = {
    RegisterModule = function(_, _, module)
        captured = module
    end
}

dofile("Modules/RaidRollHelper.lua")

local core = {
    GetModuleDB = function()
        return { maxCopies = 10 }
    end
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

print("RaidRollHelper parser tests passed: " .. tostring(#accepted + #rejected))
