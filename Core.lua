local ADDON_NAME = ...

local MT = CreateFrame("Frame")
_G.MinnTinkers = MT

MT.addonName = ADDON_NAME or "MinnTinkers"
MT.displayName = "Minn Tinkers"
MT.version = "0.1.16"
MT.modules = {}
MT.moduleOrder = {}
MT.globalDB = nil
MT.db = nil
MT.ready = false
MT.profileDefaultVersion = 4

local function CopyDefaults(dst, src)
    if type(src) ~= "table" then return dst end
    if type(dst) ~= "table" then dst = {} end

    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = CopyDefaults(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end

    return dst
end

function MT:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Minn Tinkers:|r " .. tostring(message))
end


local function NormalizeText(text)
    text = tostring(text or "")
    text = string.lower(text)
    text = string.gsub(text, "[%s%p_%-]+", "")
    return text
end

local function MatchesName(value, expected)
    if not expected or expected == "" then return true end
    if not value or value == "" then return false end

    local v = NormalizeText(value)
    local e = NormalizeText(expected)

    if v == e then return true end
    if string.find(v, e, 1, true) or string.find(e, v, 1, true) then return true end

    return false
end

function MT:NameMatches(value, expected)
    return MatchesName(value, expected)
end

function MT:GetPlayerClassInfo()
    local localizedClass, englishClass = nil, nil

    if UnitClass then
        localizedClass, englishClass = UnitClass("player")
    end

    return tostring(localizedClass or "Unknown"), tostring(englishClass or localizedClass or "Unknown")
end

function MT:GetCharacterProfileText()
    local className = self:GetPlayerClassInfo()
    return tostring(className or "Unknown")
end

function MT:CharacterMatchesRule(rule)
    if type(rule) ~= "table" then
        return true, nil
    end

    local className, classToken = self:GetPlayerClassInfo()

    if rule.class and not (MatchesName(className, rule.class) or MatchesName(classToken, rule.class)) then
        return false, "class mismatch"
    end

    return true, nil
end

function MT:GetRuleText(rule)
    if type(rule) ~= "table" then return "Any character" end
    return tostring(rule.class or "Any class")
end

function MT:IsModuleAllowedForCharacter(key)
    local module = self.modules[key]
    if not module or not module.characterRule then
        return true, nil
    end

    return self:CharacterMatchesRule(module.characterRule)
end

function MT:ModuleAllowedForCharacter(key, manual)
    local module = self.modules[key]
    if not module then return false end

    local allowed, reason = self:IsModuleAllowedForCharacter(key)
    if allowed then return true end

    if manual then
        self:Print(tostring(module.name or key) .. " is for " .. self:GetRuleText(module.characterRule) .. " characters. Current class: " .. self:GetCharacterProfileText() .. ".")
    end

    return false, reason
end

function MT:PrintCharacterProfile()
    self:Print("Current class: " .. self:GetCharacterProfileText() .. ".")

    for _, key in ipairs(self.moduleOrder) do
        local module = self.modules[key]
        if module and module.characterRule then
            local allowed, reason = self:IsModuleAllowedForCharacter(key)
            self:Print(tostring(module.name or key) .. ": " .. (allowed and "allowed" or "blocked") .. " - " .. self:GetRuleText(module.characterRule) .. (reason and (" (" .. tostring(reason) .. ")") or ""))
        end
    end
end

function MT:RegisterModule(key, module)
    if not key or type(module) ~= "table" then return end

    if self.modules[key] then
        self:Print("Duplicate module ignored: " .. tostring(key))
        return
    end

    module.key = key
    module.enabled = false

    self.modules[key] = module
    table.insert(self.moduleOrder, key)
end

function MT:GetModuleDB(key)
    if not self.db then return nil end
    if not self.db.modules then self.db.modules = {} end
    if not self.db.modules[key] then self.db.modules[key] = {} end
    return self.db.modules[key]
end

function MT:InitDB()
    if type(MinnTinkersDB) ~= "table" then
        MinnTinkersDB = {}
    end

    if type(MinnTinkersCharDB) ~= "table" then
        MinnTinkersCharDB = {}
    end

    MinnTinkersDB.version = self.version
    MinnTinkersCharDB.modules = MinnTinkersCharDB.modules or {}

    local playerName = UnitName and UnitName("player") or "Unknown"
    local realmName = GetRealmName and GetRealmName() or "UnknownRealm"
    MinnTinkersCharDB.character = tostring(playerName or "Unknown") .. " - " .. tostring(realmName or "UnknownRealm")
    MinnTinkersCharDB.version = self.version

    self.globalDB = MinnTinkersDB
    self.db = MinnTinkersCharDB

    local previousProfileDefaultVersion = tonumber(self.db.profileDefaultVersion or 0) or 0

    for _, key in ipairs(self.moduleOrder) do
        local module = self.modules[key]
        local defaults = module.defaults or { enabled = false }
        local existed = type(self.db.modules[key]) == "table"

        self.db.modules[key] = CopyDefaults(self.db.modules[key], defaults)

        if self.db.modules[key].enabled == nil then
            self.db.modules[key].enabled = false
        end

        -- Class-restricted modules are reset once into sane per-character defaults.
        -- This keeps class tools on their intended characters.
        if module.characterRule and (not existed or previousProfileDefaultVersion < self.profileDefaultVersion) then
            local allowed = self:IsModuleAllowedForCharacter(key)
            self.db.modules[key].enabled = (defaults.enabled ~= false) and allowed and true or false
        end
    end

    self.db.profileDefaultVersion = self.profileDefaultVersion
end

function MT:IsModuleEnabled(key)
    local db = self:GetModuleDB(key)
    return db and db.enabled and true or false
end

function MT:EnableModule(key)
    local module = self.modules[key]
    if not module or module.enabled then return end

    local ok, err = true, nil

    if module.OnEnable then
        ok, err = pcall(module.OnEnable, module, self)
    end

    if ok then
        module.enabled = true
    else
        self:Print("Could not enable " .. tostring(module.name or key) .. ": " .. tostring(err))
    end
end

function MT:DisableModule(key)
    local module = self.modules[key]
    if not module or not module.enabled then return end

    local ok, err = true, nil

    if module.OnDisable then
        ok, err = pcall(module.OnDisable, module, self)
    end

    module.enabled = false

    if not ok then
        self:Print("Error disabling " .. tostring(module.name or key) .. ": " .. tostring(err))
    end
end

function MT:SetModuleEnabled(key, enabled)
    local module = self.modules[key]
    local db = self:GetModuleDB(key)

    if not module or not db then return end

    enabled = enabled and true or false

    if enabled and module.characterRule and not self:ModuleAllowedForCharacter(key, true) then
        db.enabled = false
        if self.RefreshOptions then
            self:RefreshOptions()
        end
        return
    end

    db.enabled = enabled

    if enabled then
        self:EnableModule(key)
    else
        self:DisableModule(key)
    end

    if self.RefreshOptions then
        self:RefreshOptions()
    end
end

function MT:GetModuleKey(input)
    if not input or input == "" then return nil end

    input = string.lower(tostring(input))

    for key, module in pairs(self.modules) do
        if string.lower(key) == input then
            return key
        end

        if module.name and string.lower(module.name) == input then
            return key
        end
    end

    return nil
end

function MT:ListModules()
    self:Print("Modules:")

    for _, key in ipairs(self.moduleOrder) do
        local module = self.modules[key]
        local enabled = self:IsModuleEnabled(key)
        self:Print(key .. " - " .. (enabled and "|cff00ff00ON|r" or "|cffff3333OFF|r") .. " - " .. tostring(module.name or key))
    end
end

function MT:ApplySavedModuleStates()
    for _, key in ipairs(self.moduleOrder) do
        if self:IsModuleEnabled(key) then
            self:EnableModule(key)
        end
    end
end

function MT:Trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

function MT:ShowHelp()
    self:Print("Commands:")
    self:Print("/minn - open settings")
    self:Print("/minn list - list modules")
    self:Print("/minn sell - sell grey items at merchant")
    self:Print("/minn gossip - try safe gossip skip on the current NPC")
    self:Print("/minn rolls - print smart dungeon roll status")
    self:Print("/minn rolls pause 60 - pause smart dungeon rolls for 60 seconds")
    self:Print("/minn rolls resume - resume smart dungeon rolls")
    self:Print("/minn mark - mark tank with Star and healer with Moon")
    self:Print("/minn healer - alias for /minn mark")
    self:Print("/minn roles - print RDF/LFG roles for current party")
    self:Print("/minn profile - print detected class and class modules")
    self:Print("/minn on AutoSellGrey")
    self:Print("/minn off AutoSellGrey")
    self:Print("/minn toggle AutoMarkRoles")
    self:Print("/minn pact - show the Vengeful Pact button")
    self:Print("/minn pactid 803882 - change configured pact spell ID")
    self:Print("/minn intuition - show the Man'ari Intuition button")
    self:Print("/minn intuitionname Man'ari Intuition - change configured Man'ari Intuition spell name")
    self:Print("/minn intuitionthreshold 5 - show button when buff has 5 minutes or less")
    self:Print("/minn poison - show the Envenomed Weapons button")
    self:Print("/minn poisonname Envenomed Weapons - change configured poison buff spell name")
    self:Print("/minn poisonthreshold 5 - show poison button when buff has 5 minutes or less")
end

SLASH_MINNTINKERS1 = "/minn"
SLASH_MINNTINKERS2 = "/minntinkers"

SlashCmdList["MINNTINKERS"] = function(message)
    message = MT:Trim(message)

    local command, rest = string.match(message, "^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    rest = MT:Trim(rest)

    if command == "" or command == "options" or command == "config" or command == "settings" then
        if MT.OpenOptions then
            MT:OpenOptions()
        else
            MT:Print("Settings UI is not available.")
        end
        return
    end

    if command == "help" then
        MT:ShowHelp()
        return
    end

    if command == "profile" or command == "char" or command == "class" then
        MT:PrintCharacterProfile()
        return
    end

    if command == "list" then
        MT:ListModules()
        return
    end

    if command == "on" or command == "off" or command == "toggle" then
        local key = MT:GetModuleKey(rest)

        if not key then
            MT:Print("Unknown module: " .. tostring(rest))
            MT:ListModules()
            return
        end

        if command == "on" then
            MT:SetModuleEnabled(key, true)
            MT:Print(key .. " enabled.")
        elseif command == "off" then
            MT:SetModuleEnabled(key, false)
            MT:Print(key .. " disabled.")
        else
            local enabled = not MT:IsModuleEnabled(key)
            MT:SetModuleEnabled(key, enabled)
            MT:Print(key .. " " .. (enabled and "enabled." or "disabled."))
        end

        return
    end

    if command == "sell" then
        local module = MT.modules.AutoSellGrey
        if module and module.SellGreyItems then
            module:SellGreyItems(MT, true)
        end
        return
    end

    if command == "gossip" or command == "skipgossip" then
        local module = MT.modules.AutoSkipGossip
        if module and module.TrySkip then
            module:TrySkip(MT, true)
        else
            MT:Print("AutoSkipGossip module is not available.")
        end
        return
    end

    if command == "rolls" or command == "lootrolls" or command == "smartrolls" then
        local module = MT.modules.SmartDungeonRolls
        if not module then
            MT:Print("Smart Dungeon Rolls module is not available.")
            return
        end

        local subcommand, subrest = string.match(rest or "", "^(%S*)%s*(.-)$")
        subcommand = string.lower(subcommand or "")
        subrest = MT:Trim(subrest)

        if subcommand == "on" then
            MT:SetModuleEnabled("SmartDungeonRolls", true)
            MT:Print("SmartDungeonRolls enabled.")
        elseif subcommand == "off" then
            MT:SetModuleEnabled("SmartDungeonRolls", false)
            MT:Print("SmartDungeonRolls disabled.")
        elseif subcommand == "pause" then
            module:SetPaused(MT, tonumber(subrest) or 60)
        elseif subcommand == "resume" or subcommand == "unpause" then
            module:Resume(MT)
        elseif subcommand == "" or subcommand == "status" then
            module:PrintStatus(MT)
        else
            MT:Print("Usage: /minn rolls, /minn rolls on, /minn rolls off, /minn rolls pause 60, /minn rolls resume")
        end
        return
    end

    if command == "rollpause" then
        local module = MT.modules.SmartDungeonRolls
        if module then
            module:SetPaused(MT, tonumber(rest) or 60)
        else
            MT:Print("Smart Dungeon Rolls module is not available.")
        end
        return
    end

    if command == "rollresume" or command == "rollunpause" then
        local module = MT.modules.SmartDungeonRolls
        if module then
            module:Resume(MT)
        else
            MT:Print("Smart Dungeon Rolls module is not available.")
        end
        return
    end

    if command == "mark" or command == "healer" or command == "tank" then
        local module = MT.modules.AutoMarkRoles
        if module and module.MarkRoles then
            module:MarkRoles(MT, true)
        else
            MT:Print("AutoMarkRoles module is not available.")
        end
        return
    end

    if command == "roles" then
        local module = MT.modules.AutoMarkRoles
        if module and module.PrintRoles then
            module:PrintRoles(MT)
        else
            MT:Print("AutoMarkRoles module is not available.")
        end
        return
    end

    if command == "pact" then
        local module = MT.modules.VengefulPact
        if module and module.ShowPactButton then
            module:ShowPactButton(MT, true)
        else
            MT:Print("Vengeful Pact module is not available.")
        end
        return
    end

    if command == "pactid" then
        local spellID = tonumber(rest)
        local module = MT.modules.VengefulPact

        if not spellID or spellID <= 0 then
            MT:Print("Usage: /minn pactid 803882")
            return
        end

        if module then
            local db = MT:GetModuleDB("VengefulPact")
            db.spellID = spellID

            if GetSpellInfo then
                local spellName = GetSpellInfo(spellID)
                if spellName and spellName ~= "" then
                    db.spellName = spellName
                end
            end

            MT:Print("Vengeful Pact spell ID set to " .. tostring(spellID) .. ".")

            if module.ShowPactButton then
                module:ShowPactButton(MT, true)
            end
        else
            MT:Print("Vengeful Pact module is not available.")
        end
        return
    end


    if command == "intuition" or command == "manari" then
        local module = MT.modules.ManariIntuition
        if module and module.ShowBuffButton then
            module:ShowBuffButton(MT, true)
        else
            MT:Print("Man'ari Intuition module is not available.")
        end
        return
    end

    if command == "intuitionname" or command == "manariname" then
        local module = MT.modules.ManariIntuition

        if rest == "" then
            MT:Print("Usage: /minn intuitionname Man'ari Intuition")
            return
        end

        if module then
            local db = MT:GetModuleDB("ManariIntuition")
            db.spellName = rest
            MT:Print("Man'ari Intuition spell name set to " .. tostring(rest) .. ".")

            if module.ShowBuffButton then
                module:ShowBuffButton(MT, true)
            end
        else
            MT:Print("Man'ari Intuition module is not available.")
        end
        return
    end

    if command == "intuitionid" or command == "manariid" then
        MT:Print("Man'ari Intuition now uses spell name, not spell ID. Use: /minn intuitionname Man'ari Intuition")
        return
    end

    if command == "intuitionthreshold" or command == "manarithreshold" then
        local minutes = tonumber(rest)
        local module = MT.modules.ManariIntuition

        if not minutes or minutes < 0 then
            MT:Print("Usage: /minn intuitionthreshold 5")
            return
        end

        if module then
            local db = MT:GetModuleDB("ManariIntuition")
            db.refreshThreshold = math.floor(minutes * 60)
            MT:Print("Man'ari Intuition refresh threshold set to " .. tostring(minutes) .. " minute" .. (minutes == 1 and "." or "s."))

            if module.ShowBuffButton then
                module:ShowBuffButton(MT, true)
            end
        else
            MT:Print("Man'ari Intuition module is not available.")
        end
        return
    end

    if command == "poison" or command == "envenomed" or command == "envenom" then
        local module = MT.modules.EnvenomedWeapons
        if module and module.ShowBuffButton then
            module:ShowBuffButton(MT, true)
        else
            MT:Print("Envenomed Weapons module is not available.")
        end
        return
    end

    if command == "poisonname" or command == "envenomedname" then
        local module = MT.modules.EnvenomedWeapons

        if rest == "" then
            MT:Print("Usage: /minn poisonname Envenomed Weapons")
            return
        end

        if module then
            local db = MT:GetModuleDB("EnvenomedWeapons")
            db.spellName = rest
            MT:Print("Envenomed Weapons spell name set to " .. tostring(rest) .. ".")

            if module.ShowBuffButton then
                module:ShowBuffButton(MT, true)
            end
        else
            MT:Print("Envenomed Weapons module is not available.")
        end
        return
    end

    if command == "poisonthreshold" or command == "envenomedthreshold" then
        local minutes = tonumber(rest)
        local module = MT.modules.EnvenomedWeapons

        if not minutes or minutes < 0 then
            MT:Print("Usage: /minn poisonthreshold 5")
            return
        end

        if module then
            local db = MT:GetModuleDB("EnvenomedWeapons")
            db.refreshThreshold = math.floor(minutes * 60)
            MT:Print("Envenomed Weapons refresh threshold set to " .. tostring(minutes) .. " minute" .. (minutes == 1 and "." or "s."))

            if module.ShowBuffButton then
                module:ShowBuffButton(MT, true)
            end
        else
            MT:Print("Envenomed Weapons module is not available.")
        end
        return
    end

    MT:ShowHelp()
end

MT:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == self.addonName then
        self:UnregisterEvent("ADDON_LOADED")
        self:InitDB()

        if self.BuildOptions then
            self:BuildOptions()
        end

        self:ApplySavedModuleStates()
        self.ready = true

        self:Print("Loaded. Type /minn for settings.")
        return
    end
end)

MT:RegisterEvent("ADDON_LOADED")
