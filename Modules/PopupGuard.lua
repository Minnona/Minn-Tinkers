local MT = MinnTinkers

local module = {
    name = "Popup Guard",
    desc = "Prevents Escape from accidentally cancelling useful invite, summon, resurrect, and queue popups.",
    category = "Universal",
    defaults = {
        enabled = true,
        protectGroupInvites = true,
        protectSummons = true,
        protectResurrects = true,
        protectLFG = true,
        protectBattlegrounds = true,
        protectReadyChecks = false,
        printPopupIDs = false
    }
}

local POPUP_GROUPS = {
    protectGroupInvites = {
        "PARTY_INVITE",
        "PARTY_INVITE_XREALM",
        "RAID_INVITE"
    },
    protectSummons = {
        "CONFIRM_SUMMON",
        "CONFIRM_SUMMON_SCENARIO",
        "CONFIRM_SUMMON_STARTING_AREA"
    },
    protectResurrects = {
        "RESURRECT",
        "RESURRECT_NO_TIMER",
        "RESURRECT_NO_SICKNESS",
        "RESURRECT_NO_SICKNESS_NO_TIMER"
    },
    protectLFG = {
        "LFG_INVITE",
        "LFG_OFFER_CONTINUE",
        "LFG_PROPOSAL",
        "LFG_PROPOSAL_SHOW",
        "LFD_INVITE",
        "LFD_OFFER_CONTINUE",
        "CONFIRM_LFG_READY_CHECK",
        "CONFIRM_LFG_ROLE"
    },
    protectBattlegrounds = {
        "CONFIRM_BATTLEFIELD_ENTRY",
        "CONFIRM_WORLD_PVP_QUEUE",
        "BATTLEFIELD_QUEUE_READY"
    },
    protectReadyChecks = {
        "READY_CHECK",
        "CONFIRM_READY_CHECK"
    }
}

local OPTION_LABELS = {
    protectGroupInvites = "Protect group invites",
    protectSummons = "Protect summons",
    protectResurrects = "Protect resurrection popups",
    protectLFG = "Protect dungeon/LFG invites",
    protectBattlegrounds = "Protect battleground queue popups",
    protectReadyChecks = "Protect ready-check style popups"
}

local OPTION_TOOLTIPS = {
    protectGroupInvites = "Prevents Escape from declining protected party/raid invite popups.",
    protectSummons = "Prevents Escape from cancelling protected summon confirmations.",
    protectResurrects = "Prevents Escape from cancelling protected resurrection confirmations.",
    protectLFG = "Prevents Escape from declining protected dungeon/LFG invite or proposal popups when they use StaticPopup.",
    protectBattlegrounds = "Prevents Escape from declining protected battleground/world PvP queue popups.",
    protectReadyChecks = "Attempts to protect ready-check style StaticPopup dialogs if the client uses them. Disabled by default.",
}

local function build_all_ids()
    local ids = {}
    for _, list in pairs(POPUP_GROUPS) do
        for _, which in ipairs(list) do ids[which] = true end
    end
    return ids
end

local ALL_POPUP_IDS = build_all_ids()

function module:GetDB(core)
    return core:GetModuleDB(self.key)
end

function module:SaveOriginal(which, dialog)
    if not which or not dialog then return end

    self.originalKnown = self.originalKnown or {}
    self.originalHideOnEscape = self.originalHideOnEscape or {}

    if not self.originalKnown[which] then
        self.originalKnown[which] = true
        self.originalHideOnEscape[which] = dialog.hideOnEscape
    end
end

function module:RestorePopup(which)
    if not StaticPopupDialogs or not which then return end
    if not self.originalKnown or not self.originalKnown[which] then return end

    local dialog = StaticPopupDialogs[which]
    if dialog then
        dialog.hideOnEscape = self.originalHideOnEscape and self.originalHideOnEscape[which] or nil
    end
end

function module:RestoreAll()
    if not StaticPopupDialogs or not self.originalKnown then return end

    for which in pairs(self.originalKnown) do
        self:RestorePopup(which)
    end
end

function module:IsPopupSelected(db, which)
    if not db or not which then return false end

    for settingKey, list in pairs(POPUP_GROUPS) do
        if db[settingKey] then
            for _, id in ipairs(list) do
                if id == which then return true end
            end
        end
    end

    return false
end

function module:Apply(core)
    if not StaticPopupDialogs then return end

    local db = self:GetDB(core)
    local enabled = db and db.enabled

    for which in pairs(ALL_POPUP_IDS) do
        local dialog = StaticPopupDialogs[which]
        if dialog then
            self:SaveOriginal(which, dialog)

            if enabled and self:IsPopupSelected(db, which) then
                -- StaticPopup_EscapePressed checks this field before Escape hides/cancels the popup.
                dialog.hideOnEscape = nil
            else
                self:RestorePopup(which)
            end
        end
    end
end

function module:OnStaticPopupShow(core, which)
    local db = self:GetDB(core)
    if not db or not db.enabled then return end

    self:Apply(core)

    if db.printPopupIDs and which then
        local suffix = ""
        if self:IsPopupSelected(db, which) then suffix = " |cff00ff00guarded|r" end
        core:Print("Popup shown: " .. tostring(which) .. suffix)
    end
end

function module:OnEnable(core)
    self:Apply(core)

    if not self.hooked and hooksecurefunc and StaticPopup_Show then
        self.hooked = true
        hooksecurefunc("StaticPopup_Show", function(which)
            if module.enabled then module:OnStaticPopupShow(core, which) end
        end)
    end
end

function module:OnDisable(core)
    self:RestoreAll()
end

local function create_option_checkbox(core, panel, y, settingKey, db)
    local control = core:CreateCheckbox(
        panel,
        "MinnTinkers_PopupGuard_" .. settingKey,
        OPTION_LABELS[settingKey] or settingKey,
        OPTION_LABELS[settingKey] or settingKey,
        OPTION_TOOLTIPS[settingKey] or "",
        42,
        y,
        db[settingKey],
        function(checked)
            core:GetModuleDB(module.key)[settingKey] = checked
            module:Apply(core)
        end
    )

    return control
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}
    local controls = core.optionControls[self.key]
    local db = self:GetDB(core)

    local order = {
        "protectGroupInvites",
        "protectSummons",
        "protectResurrects",
        "protectLFG",
        "protectBattlegrounds",
        "protectReadyChecks"
    }

    for _, settingKey in ipairs(order) do
        controls[settingKey] = create_option_checkbox(core, panel, y, settingKey, db)
        y = y - 28
    end

    controls.printPopupIDs = core:CreateCheckbox(
        panel,
        "MinnTinkers_PopupGuard_PrintPopupIDs",
        "Print popup IDs for debugging",
        "Print popup IDs for debugging",
        "Prints StaticPopup IDs as they appear, useful when Ascension uses a custom popup name.",
        42,
        y,
        db.printPopupIDs,
        function(checked)
            core:GetModuleDB(module.key).printPopupIDs = checked
        end
    )
    y = y - 34

    local helpText = core:CreateText(panel, "Popup Guard only changes allowlisted StaticPopup dialogs. It does not globally block Escape and does not auto-accept anything.", 42, y, 520, "GameFontDisableSmall")
    y = y - math.ceil((helpText:GetStringHeight() or 24) + 12)

    return y
end

function module:RefreshOptions(core)
    local controls = core.optionControls[self.key]
    local db = self:GetDB(core)
    if not controls or not db then return end

    for settingKey in pairs(OPTION_LABELS) do
        if controls[settingKey] then controls[settingKey]:SetChecked(db[settingKey] and true or false) end
    end

    if controls.printPopupIDs then controls.printPopupIDs:SetChecked(db.printPopupIDs and true or false) end
end

MT:RegisterModule("PopupGuard", module)
