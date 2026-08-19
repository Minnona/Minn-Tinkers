MinnTinkers = {}

if not table.getn then
    table.getn = function(values) return #values end
end

dofile("UI.lua")

local universalPanel = { name = "Universal" }
local chatPanel = { name = "Chat" }
local pvpPanel = { name = "PvP" }
local opened = {}

InterfaceOptionsFrame_OpenToCategory = function(panel)
    table.insert(opened, panel)
end

MinnTinkers.db = {}
MinnTinkers.optionsPanel = { name = "Minn Tinkers" }
MinnTinkers.optionsCategoryPanels = {
    Universal = universalPanel,
    Chat = chatPanel,
    PvP = pvpPanel
}
MinnTinkers.defaultOptionsPanel = universalPanel

MinnTinkers:RememberOptionsCategory("PvP")
assert(MinnTinkers.db.lastOptionsCategory == "PvP", "last options category was not remembered")
MinnTinkers:OpenOptions()
assert(table.getn(opened) == 2 and opened[1] == pvpPanel and opened[2] == pvpPanel, "saved PvP category was not reopened")

opened = {}
MinnTinkers:RememberOptionsCategory("Chat")
MinnTinkers:OpenOptions()
assert(MinnTinkers.db.lastOptionsCategory == "Chat", "Chat options category was not remembered")
assert(table.getn(opened) == 2 and opened[1] == chatPanel and opened[2] == chatPanel, "saved Chat category was not reopened")

opened = {}
MinnTinkers.db.lastOptionsCategory = "RemovedCategory"
MinnTinkers:OpenOptions()
assert(table.getn(opened) == 2 and opened[1] == universalPanel and opened[2] == universalPanel, "missing category did not fall back to Universal")
assert(MinnTinkers.db.lastOptionsCategory == "Universal", "Universal fallback was not saved")

MinnTinkers:RememberOptionsCategory("MissingCategory")
assert(MinnTinkers.db.lastOptionsCategory == "Universal", "invalid category replaced the saved category")

print("Options navigation tests passed")
