local MT = MinnTinkers

local module = {
    name = "Wardrobe Auto-Accept",
    desc = "Automatically accepts the wardrobe appearance collection confirmation after a recent Ctrl+Alt item click.",
    category = "Universal",
    defaults = {
        enabled = true,
        windowSeconds = 2.0,
        scanSeconds = 2.0,
        scanInterval = 0.05
    }
}

local REQUIRED_TEXT = {
    "collect the appearance of",
    "will become soulbound",
    "cannot be undone"
}

local function lower(text)
    return string.lower(tostring(text or ""))
end

local function now()
    return GetTime and GetTime() or 0
end

local function safe_call(fn, ...)
    if not fn then return false end
    return pcall(fn, ...)
end

function module:GetDB(core)
    return core:GetModuleDB(self.key)
end

function module:IsCtrlAltDown()
    return (IsControlKeyDown and IsControlKeyDown()) and (IsAltKeyDown and IsAltKeyDown())
end

function module:MarkRecentModifiedClick(core)
    local db = self:GetDB(core)
    if not db or not db.enabled then return end

    local windowSeconds = tonumber(db.windowSeconds) or 2.0
    if windowSeconds < 0.5 then windowSeconds = 0.5 end
    if windowSeconds > 10 then windowSeconds = 10 end

    self.recentModifiedClickUntil = now() + windowSeconds
    self:StartScanner(core)
end

function module:OnContainerClick(core)
    local db = self:GetDB(core)
    if not db or not db.enabled then return end

    if self:IsCtrlAltDown() then
        self:MarkRecentModifiedClick(core)
    end
end

function module:RecentlyModifiedClicked()
    local untilTime = tonumber(self.recentModifiedClickUntil) or 0
    return untilTime > 0 and now() <= untilTime
end

function module:GetPopupText(frame)
    if not frame then return "" end

    local parts = {}

    if frame.text and frame.text.GetText then
        local text = frame.text:GetText()
        if text and text ~= "" then table.insert(parts, text) end
    end

    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetText then
                local text = region:GetText()
                if text and text ~= "" then table.insert(parts, text) end
            end
        end
    end

    return table.concat(parts, "\n")
end

function module:PopupMatches(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then return false end

    local text = self:GetPopupText(frame)
    local haystack = lower(text)
    if haystack == "" then return false end

    for _, needle in ipairs(REQUIRED_TEXT) do
        if not string.find(haystack, needle, 1, true) then
            return false
        end
    end

    return true
end

function module:GetAcceptButton(frame)
    if not frame or not frame.GetName then return nil end

    local name = frame:GetName()
    local button = name and _G[name .. "Button1"] or nil
    if not button then return nil end

    local label = ""
    if button.GetText then label = lower(button:GetText()) end
    if label ~= "" and not string.find(label, "accept", 1, true) then
        return nil
    end

    return button
end

function module:AcceptMatchingPopup(core)
    local db = self:GetDB(core)
    if not db or not db.enabled then return false end

    -- Always require a recent Ctrl+Alt item click. This is the main safety guard.
    if not self:RecentlyModifiedClicked() then
        return false
    end

    for i = 1, 4 do
        local frame = _G["StaticPopup" .. tostring(i)]
        if self:PopupMatches(frame) then
            local button = self:GetAcceptButton(frame)
            if button and button.Click then
                local ok = pcall(button.Click, button)
                if ok then
                    self.recentModifiedClickUntil = nil
                    return true
                end
            end
        end
    end

    return false
end

function module:StopScanner()
    if self.scanFrame then
        self.scanFrame:SetScript("OnUpdate", nil)
    end

    self.scanStopAt = nil
    self.scanElapsed = 0
    self.nextScanAt = 0
end

function module:StartScanner(core)
    local db = self:GetDB(core)
    if not db or not db.enabled then return end

    if not self.scanFrame then
        self.scanFrame = CreateFrame("Frame")
    end

    local scanSeconds = tonumber(db.scanSeconds) or 2.0
    if scanSeconds < 0.25 then scanSeconds = 0.25 end
    if scanSeconds > 10 then scanSeconds = 10 end

    self.scanStopAt = now() + scanSeconds
    self.scanElapsed = 0
    self.nextScanAt = 0

    self.scanFrame:SetScript("OnUpdate", function(_, elapsed)
        module:OnUpdate(core, elapsed)
    end)
end

function module:OnUpdate(core, elapsed)
    local db = self:GetDB(core)
    if not db or not db.enabled then self:StopScanner() return end

    local current = now()
    if self.scanStopAt and current > self.scanStopAt then
        self:StopScanner()
        return
    end

    self.scanElapsed = (self.scanElapsed or 0) + (elapsed or 0)
    local interval = tonumber(db.scanInterval) or 0.05
    if interval < 0.02 then interval = 0.02 end
    if interval > 0.5 then interval = 0.5 end

    if self.scanElapsed < (self.nextScanAt or 0) then
        return
    end

    self.nextScanAt = self.scanElapsed + interval

    if self:AcceptMatchingPopup(core) then
        self:StopScanner()
    end
end

function module:InstallHooks(core)
    if self.hooksInstalled then return end
    self.hooksInstalled = true

    if hooksecurefunc then
        if ContainerFrameItemButton_OnModifiedClick then
            safe_call(hooksecurefunc, "ContainerFrameItemButton_OnModifiedClick", function()
                module:OnContainerClick(core)
            end)
        end

        if ContainerFrameItemButton_OnClick then
            safe_call(hooksecurefunc, "ContainerFrameItemButton_OnClick", function()
                module:OnContainerClick(core)
            end)
        end

        if StaticPopup_Show then
            safe_call(hooksecurefunc, "StaticPopup_Show", function()
                module:StartScanner(core)
            end)
        end
    end
end

function module:OnEnable(core)
    self:InstallHooks(core)
end

function module:OnDisable(core)
    self:StopScanner()
    self.recentModifiedClickUntil = nil
end

function module:BuildOptions(core, panel, y)
    return y
end

function module:RefreshOptions(core)
end

MT:RegisterModule("WardrobeAutoAccept", module)
