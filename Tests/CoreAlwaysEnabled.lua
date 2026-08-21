local eventFrame = {}

function eventFrame:SetScript(scriptName, handler)
    self[scriptName] = handler
end

function eventFrame:RegisterEvent(event)
    self.registeredEvent = event
end

CreateFrame = function()
    return eventFrame
end

DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
UnitName = function() return "Testchar" end
GetRealmName = function() return "Testrealm" end

dofile("Core.lua")

local enableCount = 0
MinnTinkers:RegisterModule("Always", {
    name = "Always",
    alwaysEnabled = true,
    defaults = { enabled = true },
    OnEnable = function() enableCount = enableCount + 1 end
})
MinnTinkers:RegisterModule("Optional", {
    name = "Optional",
    defaults = { enabled = false }
})

MinnTinkersDB = {}
MinnTinkersCharDB = {
    modules = {
        Always = { enabled = false },
        Optional = { enabled = false }
    }
}

MinnTinkers:InitDB()
assert(MinnTinkersCharDB.modules.Always.enabled == true, "always-on saved state was not repaired")
assert(MinnTinkers:IsModuleEnabled("Always"), "always-on module was reported disabled")
assert(not MinnTinkers:IsModuleEnabled("Optional"), "optional module was unexpectedly enabled")

MinnTinkers:ApplySavedModuleStates()
assert(enableCount == 1, "always-on module was not enabled during saved-state application")

MinnTinkers:SetModuleEnabled("Always", false)
assert(MinnTinkersCharDB.modules.Always.enabled == true, "always-on module accepted a disable request")
assert(MinnTinkers.modules.Always.enabled == true, "always-on runtime module was disabled")
assert(enableCount == 1, "enabled always-on module was initialized twice")

print("Always-enabled module tests passed")
