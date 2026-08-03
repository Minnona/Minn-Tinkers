local MT = MinnTinkers

local ICON_TEXTURE = "Interface\\Icons\\Spell_Shaman_Hex"
local DEFAULT_ANGLE = 225
local DEFAULT_RADIUS = 80

local module = {
    name = "Minimap button",
    desc = "Adds a draggable frog minimap button for quickly opening Minn Tinkers settings.",
    category = "Universal",
    defaults = {
        enabled = true,
        lockButton = false,
        minimapAngle = DEFAULT_ANGLE,
        minimapRadius = DEFAULT_RADIUS
    }
}

local function atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

function module:GetDB(core)
    local db = core:GetModuleDB(self.key)
    if db then
        if db.minimapAngle == nil then db.minimapAngle = DEFAULT_ANGLE end
        if db.minimapRadius == nil then db.minimapRadius = DEFAULT_RADIUS end
        db.minimapRadius = tonumber(db.minimapRadius) or DEFAULT_RADIUS
        if db.minimapRadius < 65 then db.minimapRadius = 65 end
        if db.minimapRadius > 95 then db.minimapRadius = 95 end
    end
    return db
end

function module:UpdatePosition(core)
    if not self.button or not Minimap then return end

    local db = self:GetDB(core) or {}
    local angle = tonumber(db.minimapAngle) or DEFAULT_ANGLE
    local radius = tonumber(db.minimapRadius) or DEFAULT_RADIUS
    local radians = angle * math.pi / 180

    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

function module:UpdateDrag(core)
    if not self.dragging or not self.button or not Minimap or not GetCursorPosition then return end

    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale() or 1
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then return end

    local db = self:GetDB(core)
    if not db then return end

    db.minimapAngle = math.deg(atan2(cursorY - centerY, cursorX - centerX))
    self:UpdatePosition(core)
end

function module:StartDrag(core)
    local db = self:GetDB(core)
    if not db or db.lockButton then return end
    if not self.button then return end

    self.dragging = true
    self.button:SetScript("OnUpdate", function()
        module:UpdateDrag(core)
    end)
end

function module:StopDrag()
    self.dragging = false
    if self.button then
        self.button:SetScript("OnUpdate", nil)
    end
end

function module:SetTooltip(core)
    if not self.button then return end

    self.button:SetScript("OnEnter", function(button)
        local db = module:GetDB(core) or {}
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Minn Tinkers")
        GameTooltip:AddLine("Left-click: open settings", 0.8, 0.8, 0.8)
        if db.lockButton then
            GameTooltip:AddLine("Right-click: unlock button", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("Drag: move button", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Right-click: lock button", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)

    self.button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function module:CreateButton(core)
    if self.button or not Minimap then return end

    local button = CreateFrame("Button", "MinnTinkersMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -7, 6)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(54)
    border:SetHeight(54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.border = border

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            local db = module:GetDB(core)
            if db then
                db.lockButton = not db.lockButton
                core:Print("Minimap button " .. (db.lockButton and "locked." or "unlocked."))
                if core.RefreshOptions then core:RefreshOptions() end
            end
            return
        end

        if core.OpenOptions then
            core:OpenOptions()
        end
    end)

    button:SetScript("OnDragStart", function()
        module:StartDrag(core)
    end)

    button:SetScript("OnDragStop", function()
        module:StopDrag()
    end)

    self.button = button
    self:SetTooltip(core)
    self:UpdatePosition(core)
end

function module:Show(core)
    self:CreateButton(core)
    if self.button then
        self:UpdatePosition(core)
        self.button:Show()
    end
end

function module:Hide()
    self:StopDrag()
    if self.button then
        self.button:Hide()
    end
end

function module:ResetPosition(core)
    local db = self:GetDB(core)
    if not db then return end

    db.minimapAngle = DEFAULT_ANGLE
    db.minimapRadius = DEFAULT_RADIUS
    self:UpdatePosition(core)
    if core.RefreshOptions then core:RefreshOptions() end
end

function module:OnEnable(core)
    self:Show(core)
end

function module:OnDisable()
    self:Hide()
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}
    local controls = core.optionControls[self.key]
    local db = self:GetDB(core)

    controls.lockButton = core:CreateCheckbox(
        panel,
        "MinnTinkers_MinimapButton_Lock",
        "Lock minimap button position",
        "Lock minimap button position",
        "Prevents dragging the minimap button by accident. Right-clicking the button also toggles this.",
        42,
        y,
        db.lockButton,
        function(checked)
            core:GetModuleDB(module.key).lockButton = checked
        end
    )
    y = y - 34

    controls.resetPosition = core:CreateOptionButton(panel, "MinnTinkers_MinimapButton_Reset", "Reset minimap position", 42, y, 170, 24, function()
        module:ResetPosition(core)
    end)
    y = y - 34

    local helpText = core:CreateText(panel, "Uses the built-in frog-style Hex icon. Left-click opens settings; drag moves it; right-click locks/unlocks it.", 42, y, 520, "GameFontDisableSmall")
    y = y - math.ceil((helpText:GetStringHeight() or 24) + 12)

    return y
end

function module:RefreshOptions(core)
    local controls = core.optionControls[self.key]
    local db = self:GetDB(core)
    if not controls or not db then return end

    if controls.lockButton then controls.lockButton:SetChecked(db.lockButton and true or false) end
    self:UpdatePosition(core)
end

MT:RegisterModule("MinimapButton", module)
