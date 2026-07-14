local MT = MinnTinkers

MT.skin = MT.skin or {}

local function HideTexture(texture)
    if texture and texture.Hide then
        texture:Hide()
    end
end

local function SetFontObject(fontString, fontObject)
    if fontString and fontObject then
        pcall(fontString.SetFontObject, fontString, fontObject)
    end
end

local function ClearButtonTexture(button, getterName, setterName)
    if not button then return end

    if getterName and button[getterName] then
        local texture = button[getterName](button)
        HideTexture(texture)
        if texture and texture.SetTexture then
            texture:SetTexture(nil)
        end
    end

    if setterName and button[setterName] then
        pcall(button[setterName], button, "")
    end
end

local function HideNamedButtonRegions(button)
    if not button or not button.GetName then return end

    local name = button:GetName()
    if not name then return end

    local suffixes = {
        "Left", "Middle", "Right",
        "TopLeft", "TopMiddle", "TopRight",
        "MiddleLeft", "MiddleMiddle", "MiddleRight",
        "BottomLeft", "BottomMiddle", "BottomRight",
        "Border", "Background", "Flash", "Highlight", "Pushed", "Disabled"
    }

    for _, suffix in ipairs(suffixes) do
        HideTexture(_G[name .. suffix])
    end
end

function MT:EnsureButtonFontString(button)
    if not button then return nil end

    local text = button.GetFontString and button:GetFontString()
    if text then return text end

    text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")

    if button.SetFontString then
        button:SetFontString(text)
    end

    return text
end

function MT:StripBlizzardButtonSkin(button)
    if not button then return end

    ClearButtonTexture(button, "GetNormalTexture", "SetNormalTexture")
    ClearButtonTexture(button, "GetPushedTexture", "SetPushedTexture")
    ClearButtonTexture(button, "GetHighlightTexture", "SetHighlightTexture")
    ClearButtonTexture(button, "GetDisabledTexture", "SetDisabledTexture")
    ClearButtonTexture(button, "GetCheckedTexture", "SetCheckedTexture")

    HideNamedButtonRegions(button)
end

function MT:IsElvUILoaded()
    if _G.ElvUI or _G.E then
        return true
    end

    if IsAddOnLoaded then
        local loaded = IsAddOnLoaded("ElvUI")
        if loaded then return true end
    end

    return false
end

function MT:GetSkinColors()
    return {
        bg = { 0.06, 0.06, 0.06, 0.92 },
        bgSoft = { 0.09, 0.09, 0.09, 0.88 },
        border = { 0.22, 0.22, 0.22, 1 },
        borderHover = { 0.95, 0.78, 0.25, 1 },
        text = { 0.88, 0.88, 0.88, 1 },
        muted = { 0.65, 0.65, 0.65, 1 },
        accent = { 0.33, 0.75, 1.0, 1 },
        alert = { 1.0, 0.82, 0.16, 1 }
    }
end

function MT:SetBackdrop(frame, bgColor, borderColor)
    if not frame or not frame.SetBackdrop then return end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })

    if bgColor then
        frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    end

    if borderColor then
        frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    end
end

function MT:SkinFrame(frame)
    if not frame then return end
    local colors = self:GetSkinColors()
    self:SetBackdrop(frame, colors.bg, colors.border)
end

function MT:SkinPanel(panel)
    if not panel then return end
    local colors = self:GetSkinColors()
    self:SetBackdrop(panel, colors.bg, colors.border)
end

function MT:SkinButton(button)
    if not button then return end
    local colors = self:GetSkinColors()

    self:StripBlizzardButtonSkin(button)
    self:SetBackdrop(button, colors.bgSoft, colors.border)

    local text = self:EnsureButtonFontString(button)
    if text then
        SetFontObject(text, GameFontHighlightSmall)
        text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
    end

    button:SetScript("OnEnter", function(self)
        if GameTooltip and self.minnTooltipTitle then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.minnTooltipTitle, 1, 1, 1)
            if self.minnTooltipText and self.minnTooltipText ~= "" then
                GameTooltip:AddLine(self.minnTooltipText, nil, nil, nil, true)
            end
            GameTooltip:Show()
        end
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(colors.borderHover[1], colors.borderHover[2], colors.borderHover[3], colors.borderHover[4])
        end
    end)

    button:SetScript("OnLeave", function(self)
        if GameTooltip then GameTooltip:Hide() end
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(colors.border[1], colors.border[2], colors.border[3], colors.border[4])
        end
    end)
end

function MT:SkinCheckBox(checkbox)
    if not checkbox then return end

    local colors = self:GetSkinColors()
    local name = checkbox:GetName()

    HideTexture(name and _G[name .. "Middle"])
    HideTexture(name and _G[name .. "Left"])
    HideTexture(name and _G[name .. "Right"])

    local text = name and _G[name .. "Text"]
    if text then
        SetFontObject(text, GameFontHighlightSmall)
        text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
    end
end

function MT:SkinEditBox(editBox)
    if not editBox then return end
    local colors = self:GetSkinColors()

    HideTexture(editBox.Left)
    HideTexture(editBox.Middle)
    HideTexture(editBox.Right)

    self:SetBackdrop(editBox, colors.bgSoft, colors.border)
    if editBox.SetTextColor then
        editBox:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
    end
end

function MT:SkinSpellButton(button, spellName)
    if not button then return end
    local colors = self:GetSkinColors()

    self:SkinButton(button)

    if not button.minnIcon then
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(24)
        icon:SetHeight(24)
        icon:SetPoint("LEFT", button, "LEFT", 4, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.minnIcon = icon
    end

    local texture = nil
    if spellName and GetSpellTexture then
        texture = GetSpellTexture(spellName)
    end

    if texture then
        button.minnIcon:SetTexture(texture)
        button.minnIcon:Show()
    else
        button.minnIcon:Hide()
    end

    local text = button.GetFontString and button:GetFontString()
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", button, "LEFT", 34, 0)
        text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        text:SetJustifyH("LEFT")
        text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
    end

    if button.SetBackdropBorderColor then
        button:SetBackdropBorderColor(colors.alert[1], colors.alert[2], colors.alert[3], colors.alert[4])
    end
end
