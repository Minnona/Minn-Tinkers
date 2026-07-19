local MT = MinnTinkers

local OPTION_CATEGORIES = {
    Universal = {
        key = "Universal",
        label = "Universal",
        desc = "Shared tools that make sense on every character."
    },
    Felsworn = {
        key = "Felsworn",
        label = "Felsworn",
        desc = "Felsworn tools."
    },
    Venomancer = {
        key = "Venomancer",
        label = "Venomancer",
        desc = "Venomancer tools."
    },
    Debug = {
        key = "Debug",
        label = "Debug",
        desc = "Class checks and troubleshooting commands."
    }
}

local OPTION_ORDER = { "Universal", "Felsworn", "Venomancer", "Debug" }

local function SetTooltip(owner, title, text)
    if not owner then return end

    owner:SetScript("OnEnter", function(self)
        if not title and not text then return end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title then GameTooltip:SetText(title, 1, 1, 1) end
        if text and text ~= "" then GameTooltip:AddLine(text, nil, nil, nil, true) end
        GameTooltip:Show()
    end)

    owner:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function SetControlEnabled(control, enabled)
    if not control then return end

    if enabled then
        if control.Enable then control:Enable() end
        if control.SetAlpha then control:SetAlpha(1) end
    else
        if control.Disable then control:Disable() end
        if control.SetAlpha then control:SetAlpha(0.45) end
    end
end

function MT:CreateCheckbox(parent, name, label, tooltipTitle, tooltipText, x, y, checked, onClick)
    local checkbox = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox:SetChecked(checked and true or false)

    local text = _G[checkbox:GetName() .. "Text"]
    if text then
        text:SetText(label or "")
        text:SetWidth(540)
        text:SetJustifyH("LEFT")
    end

    checkbox:SetScript("OnClick", function(self)
        if onClick then
            onClick(self:GetChecked() and true or false)
        end
    end)

    SetTooltip(checkbox, tooltipTitle, tooltipText)

    if self.SkinCheckBox then
        self:SkinCheckBox(checkbox)
    end

    return checkbox
end

function MT:CreateText(parent, text, x, y, width, fontObject)
    local fs = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width or 540)
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end

function MT:CreateOptionButton(parent, name, label, x, y, width, height, onClick)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetWidth(width or 160)
    button:SetHeight(height or 24)
    button:SetText(label or "Button")
    button:SetScript("OnClick", function()
        if onClick then onClick() end
    end)

    if self.SkinButton then
        self:SkinButton(button)
    end

    return button
end

function MT:GetModuleCategory(key, module)
    if module and module.category and module.category ~= "" then
        return module.category
    end

    if key == "VengefulPact" or key == "ManariIntuition" then
        return "Felsworn"
    end

    if key == "EnvenomedWeapons" then
        return "Venomancer"
    end

    return "Universal"
end

function MT:BuildModulePage(page, category)
    local y = -12
    local info = OPTION_CATEGORIES[category]

    if info then
        self:CreateText(page, info.label, 12, y, 520, "GameFontNormalLarge")
        y = y - 26
        self:CreateText(page, info.desc or "", 12, y, 520, "GameFontHighlightSmall")
        y = y - 36
    end

    local addedAny = false

    for _, key in ipairs(self.moduleOrder) do
        local module = self.modules[key]

        if module and self:GetModuleCategory(key, module) == category then
            addedAny = true
            local moduleDB = self:GetModuleDB(key)
            local allowed = self:IsModuleAllowedForCharacter(key)

            local checkbox = self:CreateCheckbox(
                page,
                "MinnTinkers_Module_" .. key,
                module.name or key,
                module.name or key,
                module.desc or "",
                16,
                y,
                moduleDB and moduleDB.enabled,
                function(checked)
                    MT:SetModuleEnabled(key, checked)
                end
            )

            self.optionControls[key] = self.optionControls[key] or {}
            self.optionControls[key].enabled = checkbox

            y = y - 30

            if module.BuildOptions then
                local newY = module:BuildOptions(self, page, y)
                if type(newY) == "number" then
                    y = newY
                end
            end

            y = y - 14
        end
    end

    if not addedAny then
        self:CreateText(page, "No tools in this section yet.", 16, y, 520, "GameFontDisableSmall")
        y = y - 30
    end

    page:SetHeight(math.abs(y) + 40)
end

function MT:BuildDebugPage(page)
    local y = -12

    self:CreateText(page, "Debug", 12, y, 520, "GameFontNormalLarge")
    y = y - 26

    self:CreateText(page, "Use this page when a class tool or RDF role marker does not behave correctly.", 12, y, 520, "GameFontHighlightSmall")
    y = y - 38

    self.debugLabels = {}

    self.debugLabels.character = self:CreateText(page, "Character: ...", 16, y, 520, "GameFontHighlightSmall")
    y = y - 20

    self.debugLabels.class = self:CreateText(page, "Class: ...", 16, y, 520, "GameFontHighlightSmall")
    y = y - 20

    y = y - 8

    self.debugLabels.modules = {}
    for _, key in ipairs(self.moduleOrder) do
        local module = self.modules[key]
        if module and module.characterRule then
            self.debugLabels.modules[key] = self:CreateText(page, tostring(module.name or key) .. ": ...", 16, y, 520, "GameFontHighlightSmall")
            y = y - 20
        end
    end

    y = y - 12

    self:CreateOptionButton(page, "MinnTinkers_Debug_Profile", "Print profile", 16, y, 120, 24, function()
        MT:PrintCharacterProfile()
    end)

    self:CreateOptionButton(page, "MinnTinkers_Debug_Roles", "Print roles", 146, y, 120, 24, function()
        local module = MT.modules.AutoMarkRoles
        if module and module.PrintRoles then
            module:PrintRoles(MT)
        else
            MT:Print("AutoMarkRoles module is not available.")
        end
    end)

    y = y - 34

    self:CreateOptionButton(page, "MinnTinkers_Debug_List", "List modules", 16, y, 120, 24, function()
        MT:ListModules()
    end)

    self:CreateOptionButton(page, "MinnTinkers_Debug_Mark", "Mark roles", 146, y, 120, 24, function()
        local module = MT.modules.AutoMarkRoles
        if module and module.MarkRoles then
            module:MarkRoles(MT, true)
        else
            MT:Print("AutoMarkRoles module is not available.")
        end
    end)

    y = y - 44

    self:CreateText(page, "Commands: /minn profile, /minn roles, /minn mark, /minn list", 16, y, 520, "GameFontDisableSmall")
    y = y - 30

    page:SetHeight(math.abs(y) + 40)
end

function MT:BuildParentPanel(panel)
    local y = -16

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText("Minn Tinkers")
    y = y - 32

    self:CreateText(panel, "Personal quality-of-life tools. Settings are saved separately per character.", 16, y, 560, "GameFontHighlightSmall")
    y = y - 34

    self:CreateText(panel, "Use the native AddOns list on the left and expand Minn Tinkers with the + button.", 16, y, 560, "GameFontHighlightSmall")
    y = y - 42

    self:CreateText(panel, "Sections:", 16, y, 560, "GameFontNormal")
    y = y - 24

    self:CreateText(panel, "Universal - auto-sell and tank/healer role markers", 28, y, 560, "GameFontHighlightSmall")
    y = y - 20
    self:CreateText(panel, "Felsworn - Vengeful Pact and Man'ari Intuition", 28, y, 560, "GameFontHighlightSmall")
    y = y - 20
    self:CreateText(panel, "Venomancer - Envenomed Weapons", 28, y, 560, "GameFontHighlightSmall")
    y = y - 20
    self:CreateText(panel, "Debug - class and role tests", 28, y, 560, "GameFontHighlightSmall")
end

function MT:BuildOptionsCategory(key)
    local info = OPTION_CATEGORIES[key]
    if not info then return nil end

    local panel = CreateFrame("Frame", "MinnTinkersOptionsPanel_" .. key, InterfaceOptionsFramePanelContainer)
    panel.name = info.label
    panel.parent = "Minn Tinkers"

    if self.SkinPanel then
        self:SkinPanel(panel)
    end

    local scrollFrame = CreateFrame("ScrollFrame", "MinnTinkersOptionsScrollFrame_" .. key, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 18)

    local page = CreateFrame("Frame", "MinnTinkersOptionsPage_" .. key, scrollFrame)
    page:SetWidth(600)
    page:SetHeight(1)
    scrollFrame:SetScrollChild(page)

    if key == "Debug" then
        self:BuildDebugPage(page)
    else
        self:BuildModulePage(page, key)
    end

    InterfaceOptions_AddCategory(panel)
    return panel
end

function MT:BuildOptions()
    local panel = CreateFrame("Frame", "MinnTinkersOptionsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "Minn Tinkers"

    if self.SkinPanel then
        self:SkinPanel(panel)
    end

    self.optionsPanel = panel
    self.optionsCategoryPanels = {}
    self.optionControls = {}

    self:BuildParentPanel(panel)
    InterfaceOptions_AddCategory(panel)

    for _, key in ipairs(OPTION_ORDER) do
        self.optionsCategoryPanels[key] = self:BuildOptionsCategory(key)
    end

    self.defaultOptionsPanel = self.optionsCategoryPanels.Universal or panel
    self:RefreshOptions()
end

function MT:RefreshDebugPage()
    if not self.debugLabels then return end

    local playerName = UnitName and UnitName("player") or "Unknown"
    local realmName = GetRealmName and GetRealmName() or "UnknownRealm"
    local className, classToken = self:GetPlayerClassInfo()
    if self.debugLabels.character then
        self.debugLabels.character:SetText("Character: " .. tostring(playerName or "Unknown") .. " - " .. tostring(realmName or "UnknownRealm"))
    end

    if self.debugLabels.class then
        self.debugLabels.class:SetText("Class: " .. tostring(className or "Unknown") .. " / " .. tostring(classToken or "Unknown"))
    end

    if self.debugLabels.modules then
        for key, label in pairs(self.debugLabels.modules) do
            local module = self.modules[key]
            local allowed, reason = self:IsModuleAllowedForCharacter(key)
            if module and label then
                label:SetText(tostring(module.name or key) .. ": " .. (allowed and "allowed" or "blocked") .. " - " .. self:GetRuleText(module.characterRule) .. (reason and (" (" .. tostring(reason) .. ")") or ""))
            end
        end
    end
end

function MT:RefreshOptions()
    if not self.optionControls or not self.db then return end

    for key, controls in pairs(self.optionControls) do
        local moduleDB = self:GetModuleDB(key)
        local module = self.modules[key]
        local allowed = true

        if module and module.characterRule then
            allowed = self:IsModuleAllowedForCharacter(key)
        end

        if controls.enabled then
            controls.enabled:SetChecked(moduleDB and moduleDB.enabled and true or false)
            SetControlEnabled(controls.enabled, allowed)
        end
    end

    for _, key in ipairs(self.moduleOrder) do
        local module = self.modules[key]
        if module and module.RefreshOptions then
            module:RefreshOptions(self)
        end
    end

    for key, controls in pairs(self.optionControls) do
        local module = self.modules[key]
        local allowed = true

        if module and module.characterRule then
            allowed = self:IsModuleAllowedForCharacter(key)
        end

        for controlName, control in pairs(controls) do
            if controlName ~= "enabled" then
                SetControlEnabled(control, allowed)
            end
        end
    end

    self:RefreshDebugPage()
end

function MT:OpenOptions()
    if not self.optionsPanel then return end

    local panel = self.defaultOptionsPanel or self.optionsPanel
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end
