local MT = MinnTinkers

local ROLL_PASS = 0
local ROLL_NEED = 1
local ROLL_GREED = 2
local ROLL_DISENCHANT = 3

local module = {
    name = "Smart dungeon rolls",
    desc = "Automatically handles safe dungeon loot rolls: DE green/blue equipment, need usable recipes, and greed/pass lockboxes by your settings.",
    category = "Universal",
    defaults = {
        enabled = true,
        useInDungeons = true,
        useInRaids = false,
        greenBlueMode = "de", -- de, greed, pass, manual
        noDisenchantFallback = "greed", -- greed, pass, manual
        purpleMode = "manual", -- manual, de_unusable, greed_unusable, pass_unusable
        needUsableRecipes = true,
        recipeFallback = "greed", -- greed, pass, manual
        lockboxMode = "greed", -- greed, pass, need_lockpicking, manual
        otherMode = "manual", -- manual, greed, pass
        printDecisions = false,
        pausedUntil = 0
    }
}

local PROFESSION_NAMES = {
    "Alchemy",
    "Blacksmithing",
    "Enchanting",
    "Engineering",
    "Herbalism",
    "Inscription",
    "Jewelcrafting",
    "Leatherworking",
    "Mining",
    "Skinning",
    "Tailoring",
    "Cooking",
    "First Aid",
    "Fishing"
}

local RECIPE_PREFIXES = {
    "Pattern:",
    "Plans:",
    "Schematic:",
    "Formula:",
    "Recipe:",
    "Design:",
    "Manual:",
    "Book:"
}

local LOCKBOX_WORDS = {
    "lockbox",
    "junkbox",
    "strongbox"
}

local function SafeRegisterEvent(frame, event)
    if not frame or not event then return end
    pcall(frame.RegisterEvent, frame, event)
end

local function SafeUnregisterEvent(frame, event)
    if not frame or not event then return end
    pcall(frame.UnregisterEvent, frame, event)
end

local function Lower(text)
    return string.lower(tostring(text or ""))
end

local function Trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function ModeLabel(mode, labels)
    return labels[mode] or tostring(mode or "unknown")
end

local function RollLabel(rollType)
    if rollType == ROLL_PASS then return "Pass" end
    if rollType == ROLL_NEED then return "Need" end
    if rollType == ROLL_GREED then return "Greed" end
    if rollType == ROLL_DISENCHANT then return "Disenchant" end
    return "Manual"
end

function module:GetDB(core)
    return core:GetModuleDB(self.key)
end

function module:IsPaused(core)
    local db = self:GetDB(core)
    if not db then return false end

    local untilTime = tonumber(db.pausedUntil) or 0
    return untilTime > 0 and GetTime and GetTime() < untilTime
end

function module:SetPaused(core, seconds)
    local db = self:GetDB(core)
    if not db then return end

    seconds = tonumber(seconds) or 60
    if seconds < 1 then seconds = 60 end

    db.pausedUntil = (GetTime and GetTime() or 0) + seconds
    core:Print("Smart dungeon rolls paused for " .. tostring(math.floor(seconds)) .. " seconds.")
end

function module:Resume(core)
    local db = self:GetDB(core)
    if not db then return end

    db.pausedUntil = 0
    core:Print("Smart dungeon rolls resumed.")
end

function module:PrintStatus(core)
    local db = self:GetDB(core)
    if not db then return end

    local paused = self:IsPaused(core)
    local remaining = 0
    if paused then
        remaining = math.ceil((tonumber(db.pausedUntil) or 0) - GetTime())
    end

    core:Print("Smart dungeon rolls: " .. (db.enabled and "ON" or "OFF") .. (paused and (", paused " .. tostring(remaining) .. "s") or ", not paused") .. ".")
    core:Print("Green/Blue: " .. self:GetGreenBlueLabel(db) .. "; Purple: " .. self:GetPurpleLabel(db) .. "; Recipes: " .. self:GetRecipeLabel(db) .. "; Lockboxes: " .. self:GetLockboxLabel(db) .. ".")
end

function module:ShouldRoll(core)
    local db = self:GetDB(core)
    if not db or not db.enabled then return false, "disabled" end

    if self:IsPaused(core) then
        return false, "paused"
    end

    local inInstance, instanceType = IsInInstance()

    if not inInstance then
        return false, "not in instance"
    end

    if instanceType == "party" and db.useInDungeons then
        return true
    end

    if instanceType == "raid" and db.useInRaids then
        return true
    end

    return false, "instance type disabled"
end

function module:GetTooltip()
    if self.tooltip then return self.tooltip end

    local tooltip = CreateFrame("GameTooltip", "MinnTinkersSmartRollTooltip", UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    self.tooltip = tooltip
    return tooltip
end

function module:ReadTooltipLines(link)
    local lines = {}
    if not link then return lines end

    local tooltip = self:GetTooltip()
    tooltip:ClearLines()
    tooltip:SetHyperlink(link)

    local name = tooltip:GetName()
    for i = 1, tooltip:NumLines() do
        local left = _G[name .. "TextLeft" .. i]
        local text = left and left:GetText()
        if text and text ~= "" then
            table.insert(lines, text)
        end
    end

    tooltip:Hide()
    return lines
end

function module:GetProfessions()
    local result = {}

    if GetProfessions and GetProfessionInfo then
        local indices = { GetProfessions() }

        for _, index in pairs(indices) do
            if index then
                local name, _, rank = GetProfessionInfo(index)
                if name and name ~= "" then
                    result[name] = tonumber(rank) or 0
                end
            end
        end
    end

    if not next(result) and GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank = GetSkillLineInfo(i)
            if name and not isHeader then
                for _, professionName in ipairs(PROFESSION_NAMES) do
                    if Lower(name) == Lower(professionName) then
                        result[name] = tonumber(rank) or 0
                    end
                end
            end
        end
    end

    return result
end

function module:GetLockpickingSkill()
    if not GetNumSkillLines or not GetSkillLineInfo then return nil end

    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank = GetSkillLineInfo(i)
        if name and not isHeader and Lower(name) == "lockpicking" then
            return tonumber(rank) or 0
        end
    end

    return nil
end

function module:IsRecipeItem(name, itemType)
    if itemType and Lower(itemType) == "recipe" then
        return true
    end

    name = tostring(name or "")
    for _, prefix in ipairs(RECIPE_PREFIXES) do
        if string.find(name, prefix, 1, true) == 1 then
            return true
        end
    end

    return false
end

function module:IsLockbox(name, itemType, itemSubType)
    local haystack = Lower(tostring(name or "") .. " " .. tostring(itemType or "") .. " " .. tostring(itemSubType or ""))

    for _, word in ipairs(LOCKBOX_WORDS) do
        if string.find(haystack, word, 1, true) then
            return true
        end
    end

    return false
end

function module:IsEquipment(link, itemType, equipLoc)
    if equipLoc and equipLoc ~= "" then return true end

    if IsEquippableItem and link and IsEquippableItem(link) then
        return true
    end

    local t = Lower(itemType)
    return t == "armor" or t == "weapon"
end

function module:ScanRecipe(link)
    local info = {
        isKnown = false,
        profession = nil,
        requiredSkill = nil,
        reason = "no profession requirement found"
    }

    local lines = self:ReadTooltipLines(link)

    for _, line in ipairs(lines) do
        local lower = Lower(line)

        if string.find(lower, "already known", 1, true) or string.find(lower, "you already know", 1, true) then
            info.isKnown = true
        end

        local reqText, reqSkill = string.match(line, "Requires%s+(.+)%s+%((%d+)%)")
        if reqText and reqSkill then
            reqText = Trim(reqText)
            reqSkill = tonumber(reqSkill) or 0

            for _, professionName in ipairs(PROFESSION_NAMES) do
                if string.find(Lower(reqText), Lower(professionName), 1, true) then
                    info.profession = professionName
                    info.requiredSkill = reqSkill
                    info.reason = "requires " .. professionName .. " " .. tostring(reqSkill)
                    return info
                end
            end
        end
    end

    return info
end

function module:CanUseRecipe(core, link)
    local info = self:ScanRecipe(link)

    if info.isKnown then
        return false, "already known"
    end

    if not info.profession then
        return false, info.reason or "no profession match"
    end

    local professions = self:GetProfessions()
    local playerSkill = nil

    for name, rank in pairs(professions) do
        if core.NameMatches and core:NameMatches(name, info.profession) then
            playerSkill = tonumber(rank) or 0
            break
        end
    end

    if not playerSkill then
        return false, "missing " .. tostring(info.profession)
    end

    if info.requiredSkill and playerSkill < info.requiredSkill then
        return false, tostring(info.profession) .. " too low: " .. tostring(playerSkill) .. "/" .. tostring(info.requiredSkill)
    end

    return true, tostring(info.profession) .. " " .. tostring(playerSkill) .. " OK"
end

function module:GetRollInfo(rollID)
    local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant = GetLootRollItemInfo(rollID)
    local link = GetLootRollItemLink and GetLootRollItemLink(rollID)

    if not name or name == "" then return nil end

    local itemName, itemLink, itemQuality, itemLevel, reqLevel, itemType, itemSubType, maxStack, equipLoc = GetItemInfo(link or name)

    return {
        rollID = rollID,
        texture = texture,
        name = itemName or name,
        count = count,
        quality = tonumber(itemQuality or quality) or tonumber(quality) or 0,
        bindOnPickUp = bindOnPickUp and true or false,
        canNeed = canNeed and true or false,
        canGreed = canGreed and true or false,
        canDisenchant = canDisenchant and true or false,
        link = itemLink or link,
        itemType = itemType,
        itemSubType = itemSubType,
        equipLoc = equipLoc
    }
end

function module:RollFromMode(info, mode)
    if mode == "manual" then
        return nil, "manual"
    end

    if mode == "pass" then
        return ROLL_PASS, "pass fallback"
    end

    if mode == "greed" then
        if info.canGreed then
            return ROLL_GREED, "greed available"
        end
        return nil, "greed unavailable"
    end

    return nil, "unknown fallback"
end

function module:DecideRecipe(core, info, db)
    if db.needUsableRecipes and info.canNeed then
        local usable, reason = self:CanUseRecipe(core, info.link)
        if usable then
            return ROLL_NEED, "usable recipe: " .. tostring(reason)
        end
        return self:RollFromMode(info, db.recipeFallback or "greed")
    end

    return self:RollFromMode(info, db.recipeFallback or "greed")
end

function module:DecideLockbox(core, info, db)
    local mode = db.lockboxMode or "greed"

    if mode == "need_lockpicking" then
        local skill = self:GetLockpickingSkill()
        if skill and skill > 0 and info.canNeed then
            return ROLL_NEED, "lockpicking detected: " .. tostring(skill)
        end

        if info.canGreed then
            return ROLL_GREED, "no usable lockpicking need; greed fallback"
        end

        return nil, "no lockpicking need and greed unavailable"
    end

    return self:RollFromMode(info, mode)
end

function module:DecideGreenBlueEquipment(core, info, db)
    local mode = db.greenBlueMode or "de"

    if mode == "de" then
        if info.canDisenchant then
            return ROLL_DISENCHANT, "green/blue equipment; disenchant available"
        end
        return self:RollFromMode(info, db.noDisenchantFallback or "greed")
    end

    return self:RollFromMode(info, mode)
end

function module:DecidePurpleEquipment(core, info, db)
    local mode = db.purpleMode or "manual"

    if mode == "manual" then
        return nil, "purple manual"
    end

    -- Treat active Need as "potentially usable" and leave it to the player.
    if info.canNeed then
        return nil, "purple may be usable; manual"
    end

    if mode == "de_unusable" then
        if info.canDisenchant then
            return ROLL_DISENCHANT, "unusable purple; disenchant available"
        end
        return self:RollFromMode(info, db.noDisenchantFallback or "greed")
    end

    if mode == "greed_unusable" then
        return self:RollFromMode(info, "greed")
    end

    if mode == "pass_unusable" then
        return self:RollFromMode(info, "pass")
    end

    return nil, "unknown purple mode"
end

function module:DecideRoll(core, info)
    local db = self:GetDB(core)
    if not db then return nil, "missing db" end

    if not info or not info.name then
        return nil, "missing item info"
    end

    if self:IsRecipeItem(info.name, info.itemType) then
        return self:DecideRecipe(core, info, db)
    end

    if self:IsLockbox(info.name, info.itemType, info.itemSubType) then
        return self:DecideLockbox(core, info, db)
    end

    local isEquipment = self:IsEquipment(info.link, info.itemType, info.equipLoc)

    if isEquipment and (info.quality == 2 or info.quality == 3) then
        return self:DecideGreenBlueEquipment(core, info, db)
    end

    if isEquipment and info.quality == 4 then
        return self:DecidePurpleEquipment(core, info, db)
    end

    return self:RollFromMode(info, db.otherMode or "manual")
end

function module:PrintDecision(core, info, rollType, reason)
    local db = self:GetDB(core)
    if not db or not db.printDecisions then return end

    local itemText = info and (info.link or info.name) or "unknown item"
    local action = RollLabel(rollType)
    core:Print("Roll: " .. tostring(action) .. " on " .. tostring(itemText) .. " (" .. tostring(reason or "no reason") .. ").")
end

function module:DoRoll(core, rollID)
    local shouldRoll, disabledReason = self:ShouldRoll(core)
    if not shouldRoll then
        return true, disabledReason
    end

    local info = self:GetRollInfo(rollID)
    if not info or not info.link then
        return false, "waiting for item info"
    end

    local rollType, reason = self:DecideRoll(core, info)

    if rollType == nil then
        self:PrintDecision(core, info, nil, reason or "manual")
        return true, reason or "manual"
    end

    if rollType == ROLL_NEED and not info.canNeed then
        self:PrintDecision(core, info, nil, "need unavailable")
        return true, "need unavailable"
    end

    if rollType == ROLL_GREED and not info.canGreed then
        self:PrintDecision(core, info, nil, "greed unavailable")
        return true, "greed unavailable"
    end

    if rollType == ROLL_DISENCHANT and not info.canDisenchant then
        self:PrintDecision(core, info, nil, "disenchant unavailable")
        return true, "disenchant unavailable"
    end

    self:PrintDecision(core, info, rollType, reason)

    local ok, err = pcall(RollOnLoot, rollID, rollType)
    if not ok then
        if self:GetDB(core).printDecisions then
            core:Print("Roll failed on " .. tostring(info.link or info.name) .. ": " .. tostring(err))
        end
    end

    return true, reason
end

function module:QueueRoll(core, rollID)
    if not rollID then return end
    self.pending = self.pending or {}
    self.pending[rollID] = {
        attempts = 0,
        nextCheck = (GetTime and GetTime() or 0) + 0.15
    }
end

function module:OnUpdate(core)
    if not self.pending then return end

    local now = GetTime and GetTime() or 0
    local hasPending = false

    for rollID, item in pairs(self.pending) do
        if item.nextCheck <= now then
            item.attempts = item.attempts + 1
            local done = self:DoRoll(core, rollID)

            if done or item.attempts >= 10 then
                self.pending[rollID] = nil
            else
                item.nextCheck = now + 0.35
                hasPending = true
            end
        else
            hasPending = true
        end
    end

    if not hasPending and self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end
end

function module:OnEnable(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event, rollID)
            if event == "START_LOOT_ROLL" then
                module:QueueRoll(core, rollID)
                module.frame:SetScript("OnUpdate", function()
                    module:OnUpdate(core)
                end)
            end
        end)
    end

    SafeRegisterEvent(self.frame, "START_LOOT_ROLL")
end

function module:OnDisable(core)
    if self.frame then
        SafeUnregisterEvent(self.frame, "START_LOOT_ROLL")
        self.frame:SetScript("OnUpdate", nil)
    end
    self.pending = nil
end

function module:GetGreenBlueLabel(db)
    if db.greenBlueMode == "de" then
        return "DE if possible, else " .. ModeLabel(db.noDisenchantFallback or "greed", { greed = "Greed", pass = "Pass", manual = "Manual" })
    end

    return ModeLabel(db.greenBlueMode or "de", { greed = "Greed", pass = "Pass", manual = "Manual", de = "DE if possible" })
end

function module:GetPurpleLabel(db)
    return ModeLabel(db.purpleMode or "manual", {
        manual = "Manual",
        de_unusable = "DE unusable",
        greed_unusable = "Greed unusable",
        pass_unusable = "Pass unusable"
    })
end

function module:GetRecipeLabel(db)
    return (db.needUsableRecipes and "Need usable" or "Do not need") .. ", else " .. ModeLabel(db.recipeFallback or "greed", { greed = "Greed", pass = "Pass", manual = "Manual" })
end

function module:GetLockboxLabel(db)
    return ModeLabel(db.lockboxMode or "greed", {
        greed = "Greed",
        pass = "Pass",
        manual = "Manual",
        need_lockpicking = "Need if lockpicking"
    })
end

function module:GetOtherLabel(db)
    return ModeLabel(db.otherMode or "manual", { manual = "Manual", greed = "Greed", pass = "Pass" })
end

function module:CycleValue(core, field, values)
    local db = self:GetDB(core)
    if not db then return end

    local current = db[field]
    local index = 1

    for i, value in ipairs(values) do
        if value == current then
            index = i
            break
        end
    end

    index = index + 1
    if index > table.getn(values) then index = 1 end

    db[field] = values[index]
    if core.RefreshOptions then core:RefreshOptions() end
end

function module:SetButtonText(button, text)
    if not button then return end
    button:SetText(text or "")
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}
    local controls = core.optionControls[self.key]
    local db = self:GetDB(core)

    local dungeons = core:CreateCheckbox(
        panel,
        "MinnTinkers_SmartRolls_Dungeons",
        "Enable in 5-man dungeons",
        "Enable in 5-man dungeons",
        "Automatically handles eligible loot rolls in party dungeons.",
        42,
        y,
        db.useInDungeons,
        function(checked)
            core:GetModuleDB(module.key).useInDungeons = checked
        end
    )
    controls.useInDungeons = dungeons
    y = y - 28

    local raids = core:CreateCheckbox(
        panel,
        "MinnTinkers_SmartRolls_Raids",
        "Also enable in raids",
        "Also enable in raids",
        "Disabled by default. Enable only if you trust the rules for your raid groups.",
        42,
        y,
        db.useInRaids,
        function(checked)
            core:GetModuleDB(module.key).useInRaids = checked
        end
    )
    controls.useInRaids = raids
    y = y - 34

    core:CreateText(panel, "Equipment", 42, y, 500, "GameFontNormal")
    y = y - 24

    local greenBlueButton = core:CreateOptionButton(panel, "MinnTinkers_SmartRolls_GreenBlue", "", 42, y, 450, 24, function()
        module:CycleValue(core, "greenBlueMode", { "de", "greed", "pass", "manual" })
    end)
    controls.greenBlueMode = greenBlueButton
    y = y - 30

    local fallbackButton = core:CreateOptionButton(panel, "MinnTinkers_SmartRolls_NoDEFallback", "", 62, y, 430, 24, function()
        module:CycleValue(core, "noDisenchantFallback", { "greed", "pass", "manual" })
    end)
    controls.noDisenchantFallback = fallbackButton
    y = y - 30

    local purpleButton = core:CreateOptionButton(panel, "MinnTinkers_SmartRolls_Purple", "", 42, y, 450, 24, function()
        module:CycleValue(core, "purpleMode", { "manual", "de_unusable", "greed_unusable", "pass_unusable" })
    end)
    controls.purpleMode = purpleButton
    y = y - 38

    core:CreateText(panel, "Recipes", 42, y, 500, "GameFontNormal")
    y = y - 24

    local needRecipes = core:CreateCheckbox(
        panel,
        "MinnTinkers_SmartRolls_NeedRecipes",
        "Need usable profession recipes",
        "Need usable profession recipes",
        "Needs recipes only when they match your professions, your skill is high enough, it is not already known, and Need is available.",
        42,
        y,
        db.needUsableRecipes,
        function(checked)
            core:GetModuleDB(module.key).needUsableRecipes = checked
        end
    )
    controls.needUsableRecipes = needRecipes
    y = y - 30

    local recipeFallback = core:CreateOptionButton(panel, "MinnTinkers_SmartRolls_RecipeFallback", "", 42, y, 450, 24, function()
        module:CycleValue(core, "recipeFallback", { "greed", "pass", "manual" })
    end)
    controls.recipeFallback = recipeFallback
    y = y - 38

    core:CreateText(panel, "Lockboxes and other drops", 42, y, 500, "GameFontNormal")
    y = y - 24

    local lockboxButton = core:CreateOptionButton(panel, "MinnTinkers_SmartRolls_Lockboxes", "", 42, y, 450, 24, function()
        module:CycleValue(core, "lockboxMode", { "greed", "pass", "need_lockpicking", "manual" })
    end)
    controls.lockboxMode = lockboxButton
    y = y - 30

    local otherButton = core:CreateOptionButton(panel, "MinnTinkers_SmartRolls_Other", "", 42, y, 450, 24, function()
        module:CycleValue(core, "otherMode", { "manual", "greed", "pass" })
    end)
    controls.otherMode = otherButton
    y = y - 36

    local debug = core:CreateCheckbox(
        panel,
        "MinnTinkers_SmartRolls_Debug",
        "Print roll decisions",
        "Print roll decisions",
        "Prints what the addon did and why. Useful while testing, spammy long-term.",
        42,
        y,
        db.printDecisions,
        function(checked)
            core:GetModuleDB(module.key).printDecisions = checked
        end
    )
    controls.printDecisions = debug
    y = y - 30

    core:CreateText(panel, "Commands: /minn rolls, /minn rolls pause 60, /minn rolls resume", 42, y, 500, "GameFontDisableSmall")
    y = y - 30

    return y
end

function module:RefreshOptions(core)
    local controls = core.optionControls[self.key]
    local db = self:GetDB(core)
    if not controls or not db then return end

    if controls.useInDungeons then controls.useInDungeons:SetChecked(db.useInDungeons and true or false) end
    if controls.useInRaids then controls.useInRaids:SetChecked(db.useInRaids and true or false) end
    if controls.needUsableRecipes then controls.needUsableRecipes:SetChecked(db.needUsableRecipes and true or false) end
    if controls.printDecisions then controls.printDecisions:SetChecked(db.printDecisions and true or false) end

    self:SetButtonText(controls.greenBlueMode, "Green/Blue equipment: " .. self:GetGreenBlueLabel(db))
    self:SetButtonText(controls.noDisenchantFallback, "If no Disenchant: " .. ModeLabel(db.noDisenchantFallback or "greed", { greed = "Greed", pass = "Pass", manual = "Manual" }))
    self:SetButtonText(controls.purpleMode, "Purple equipment: " .. self:GetPurpleLabel(db))
    self:SetButtonText(controls.recipeFallback, "Unusable/known recipes: " .. ModeLabel(db.recipeFallback or "greed", { greed = "Greed", pass = "Pass", manual = "Manual" }))
    self:SetButtonText(controls.lockboxMode, "Lockboxes: " .. self:GetLockboxLabel(db))
    self:SetButtonText(controls.otherMode, "Other drops: " .. self:GetOtherLabel(db))
end

MT:RegisterModule("SmartDungeonRolls", module)
