local MT = MinnTinkers

local MAX_CHAT_WINDOWS = tonumber(NUM_CHAT_WINDOWS) or 10

local module = {
    name = "Instance channel suppression",
    desc = "Temporarily hides selected numbered channels from selected chat windows inside dungeons, raids, and battlegrounds.",
    category = "Chat",
    defaults = {
        enabled = false,
        suppressInDungeons = true,
        suppressInRaids = true,
        suppressInBattlegrounds = true,
        selectedFrames = {},
        selectedChannels = {},
        restoreChannels = {}
    }
}

local function trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function lower(text)
    return string.lower(tostring(text or ""))
end

local function channel_key(name)
    name = trim(name)
    local base = string.match(name, "^(.-)%s+%-%s+.+$")
    if base and base ~= "" then name = base end
    return lower(name)
end

local function safe_register(frame, event)
    if frame and event then pcall(frame.RegisterEvent, frame, event) end
end

local function safe_unregister(frame, event)
    if frame and event then pcall(frame.UnregisterEvent, frame, event) end
end

local function table_empty(values)
    if type(values) ~= "table" then return true end
    for _ in pairs(values) do return false end
    return true
end

function module:GetDB(core)
    local db = core and core:GetModuleDB(self.key) or nil
    if not db then return nil end
    if type(db.selectedFrames) ~= "table" then db.selectedFrames = {} end
    if type(db.selectedChannels) ~= "table" then db.selectedChannels = {} end
    if type(db.restoreChannels) ~= "table" then db.restoreChannels = {} end
    return db
end

function module:GetChatFrame(index)
    return _G["ChatFrame" .. tostring(index)]
end

function module:GetWindowLimit()
    if FCF_GetNumActiveChatFrames then
        local ok, count = pcall(FCF_GetNumActiveChatFrames)
        count = ok and tonumber(count) or nil
        if count and count > 0 then return math.min(count, MAX_CHAT_WINDOWS) end
    end
    return MAX_CHAT_WINDOWS
end

function module:GetWindowName(index)
    local name = ""
    local tab = _G["ChatFrame" .. tostring(index) .. "Tab"]
    if tab and tab.GetText then name = trim(tab:GetText()) end

    if name == "" and GetChatWindowInfo then name = trim(GetChatWindowInfo(index)) end
    return name
end

function module:GetWindowLabel(index)
    local name = self:GetWindowName(index)
    if name == "" then name = "Chat " .. tostring(index) end
    return name .. " (window " .. tostring(index) .. ")"
end

function module:GetWindowChannelMap(index)
    local channels = {}
    local frame = self:GetChatFrame(index)

    if frame and type(frame.channelList) == "table" then
        for _, value in pairs(frame.channelList) do
            local name = trim(value)
            local key = channel_key(name)
            if key ~= "" then channels[key] = name end
        end
    end

    if not GetChatWindowChannels then return channels end

    local values = { GetChatWindowChannels(index) }
    local position = 1
    while position <= table.getn(values) do
        local name = trim(values[position])
        local key = channel_key(name)
        if key ~= "" then channels[key] = name end

        if type(values[position + 1]) == "number" then position = position + 2
        else position = position + 1 end
    end
    return channels
end

function module:DiscoverWindows(core)
    local db = self:GetDB(core) or self.defaults
    local windows = {}

    for index = 1, self:GetWindowLimit() do
        local frame = self:GetChatFrame(index)
        local name = self:GetWindowName(index)
        if frame and (name ~= "" or db.selectedFrames[tostring(index)]) then
            table.insert(windows, { index = index, label = self:GetWindowLabel(index) })
        end
    end

    return windows
end

function module:DiscoverChannels(core)
    local db = self:GetDB(core) or self.defaults
    local found = {}

    if GetChannelList then
        local joined = { GetChannelList() }
        local position = 1
        while position <= table.getn(joined) do
            local name = nil
            if type(joined[position]) == "number" and type(joined[position + 1]) == "string" then
                name = joined[position + 1]
                position = position + 2
            else
                name = joined[position]
                position = position + 1
            end

            name = trim(name)
            local key = channel_key(name)
            if key ~= "" then found[key] = name end
        end
    end

    for index = 1, self:GetWindowLimit() do
        for key, name in pairs(self:GetWindowChannelMap(index)) do
            found[key] = name
        end
    end

    for key, value in pairs(db.selectedChannels or {}) do
        if value then
            local name = type(value) == "string" and trim(value) or trim(key)
            if name ~= "" and not found[key] then found[key] = name end
        end
    end

    local channels = {}
    for key, name in pairs(found) do table.insert(channels, { key = key, name = name }) end
    table.sort(channels, function(a, b) return lower(a.name) < lower(b.name) end)
    return channels
end

function module:IsSuppressionActive(core)
    local db = self:GetDB(core)
    if not db or not IsInInstance then return false end

    local inInstance, instanceType = IsInInstance()
    if not inInstance then return false end
    if instanceType == "party" then return db.suppressInDungeons ~= false end
    if instanceType == "raid" then return db.suppressInRaids ~= false end
    if instanceType == "pvp" then return db.suppressInBattlegrounds ~= false end
    return false
end

function module:Suppress(core)
    local db = self:GetDB(core)
    if not db or not ChatFrame_RemoveChannel then return end

    for frameKey, selected in pairs(db.selectedFrames) do
        local index = tonumber(frameKey)
        local frame = selected and index and self:GetChatFrame(index) or nil
        if frame then
            local current = self:GetWindowChannelMap(index)
            local restore = db.restoreChannels[tostring(index)]
            if type(restore) ~= "table" then
                restore = {}
                db.restoreChannels[tostring(index)] = restore
            end

            for key, channelName in pairs(db.selectedChannels) do
                if channelName and current[key] and not restore[key] then
                    local name = current[key]
                    local ok = pcall(ChatFrame_RemoveChannel, frame, name)
                    if ok then restore[key] = name end
                end
            end

            if table_empty(restore) then db.restoreChannels[tostring(index)] = nil end
        end
    end
end

function module:Restore(core)
    local db = self:GetDB(core)
    if not db or not ChatFrame_AddChannel then return end

    for frameKey, channels in pairs(db.restoreChannels) do
        local frame = self:GetChatFrame(tonumber(frameKey))
        if frame and type(channels) == "table" then
            for key, name in pairs(channels) do
                local ok = pcall(ChatFrame_AddChannel, frame, name)
                if ok then channels[key] = nil end
            end
            if table_empty(channels) then db.restoreChannels[frameKey] = nil end
        end
    end
end

function module:Update(core)
    if self:IsSuppressionActive(core) then self:Suppress(core)
    else self:Restore(core) end
end

function module:Reconfigure(core)
    self:Restore(core)
    if self.enabled then self:Update(core) end
end

local EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA"
}

function module:OnEnable(core)
    self:GetDB(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function() module:Update(core) end)
    end
    for _, event in ipairs(EVENTS) do safe_register(self.frame, event) end
    self:Update(core)
end

function module:OnDisable(core)
    if self.frame then
        for _, event in ipairs(EVENTS) do safe_unregister(self.frame, event) end
    end
    self:Restore(core)
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}
    local controls = core.optionControls[self.key]
    local db = self:GetDB(core)

    controls.suppressInRaids = core:CreateCheckbox(
        panel,
        "MinnTinkers_InstanceChannelMute_Raids",
        "Suppress selected channels in raids",
        "Suppress in raids",
        "Temporarily removes the selected numbered channels from the selected chat windows while inside a raid instance.",
        42,
        y,
        db.suppressInRaids,
        function(checked)
            core:GetModuleDB(module.key).suppressInRaids = checked
            module:Reconfigure(core)
        end
    )
    y = y - 28

    controls.suppressInDungeons = core:CreateCheckbox(
        panel,
        "MinnTinkers_InstanceChannelMute_Dungeons",
        "Suppress selected channels in dungeons",
        "Suppress in dungeons",
        "Temporarily removes the selected numbered channels from the selected chat windows while inside a party instance.",
        42,
        y,
        db.suppressInDungeons,
        function(checked)
            core:GetModuleDB(module.key).suppressInDungeons = checked
            module:Reconfigure(core)
        end
    )
    y = y - 28

    controls.suppressInBattlegrounds = core:CreateCheckbox(
        panel,
        "MinnTinkers_InstanceChannelMute_Battlegrounds",
        "Suppress selected channels in battlegrounds",
        "Suppress in battlegrounds",
        "Temporarily removes the selected numbered channels from the selected chat windows while inside a battleground. Arenas are not affected.",
        42,
        y,
        db.suppressInBattlegrounds,
        function(checked)
            core:GetModuleDB(module.key).suppressInBattlegrounds = checked
            module:Reconfigure(core)
        end
    )
    y = y - 38

    core:CreateText(panel, "Mute channels in these chat windows", 42, y, 520, "GameFontNormal")
    y = y - 26

    self.windowControls = {}
    local windows = self:DiscoverWindows(core)
    for _, window in ipairs(windows) do
        local index = window.index
        local control = core:CreateCheckbox(
            panel,
            "MinnTinkers_InstanceChannelMute_Window" .. tostring(index),
            window.label,
            window.label,
            "Choose this chat window as a suppression target. Its non-channel message groups remain unchanged.",
            42,
            y,
            db.selectedFrames[tostring(index)],
            function(checked)
                local settings = module:GetDB(core)
                settings.selectedFrames[tostring(index)] = checked and true or nil
                module:Reconfigure(core)
            end
        )
        self.windowControls[tostring(index)] = control
        y = y - 28
    end

    if table.getn(windows) == 0 then
        core:CreateText(panel, "No configured chat windows were found.", 42, y, 520, "GameFontDisableSmall")
        y = y - 26
    end

    y = y - 8
    core:CreateText(panel, "Channels to mute", 42, y, 520, "GameFontNormal")
    y = y - 26

    self.channelControls = {}
    local channels = self:DiscoverChannels(core)
    for index, channel in ipairs(channels) do
        local key = channel.key
        local name = channel.name
        local control = core:CreateCheckbox(
            panel,
            "MinnTinkers_InstanceChannelMute_Channel" .. tostring(index),
            name,
            name,
            "Hide this numbered channel only from the selected chat windows while suppression is active. You remain joined to it.",
            42,
            y,
            db.selectedChannels[key],
            function(checked)
                local settings = module:GetDB(core)
                settings.selectedChannels[key] = checked and name or nil
                module:Reconfigure(core)
            end
        )
        self.channelControls[key] = control
        y = y - 28
    end

    if table.getn(channels) == 0 then
        core:CreateText(panel, "No channels to mute were found. Join or display a channel, then /reload.", 42, y, 520, "GameFontDisableSmall")
        y = y - 26
    end

    return y
end

function module:RefreshOptions(core)
    local controls = core.optionControls[self.key]
    local db = self:GetDB(core)
    if not controls or not db then return end

    if controls.suppressInRaids then controls.suppressInRaids:SetChecked(db.suppressInRaids and true or false) end
    if controls.suppressInDungeons then controls.suppressInDungeons:SetChecked(db.suppressInDungeons and true or false) end
    if controls.suppressInBattlegrounds then controls.suppressInBattlegrounds:SetChecked(db.suppressInBattlegrounds and true or false) end

    for key, control in pairs(self.windowControls or {}) do
        control:SetChecked(db.selectedFrames[key] and true or false)
    end
    for key, control in pairs(self.channelControls or {}) do
        control:SetChecked(db.selectedChannels[key] and true or false)
    end
end

MT:RegisterModule("InstanceChannelMute", module)
