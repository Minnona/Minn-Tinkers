local MT = MinnTinkers

local module = {
    name = "Auto-sell grey items",
    desc = "Automatically sells poor-quality grey items when you open a merchant window.",
    category = "Universal",
    defaults = {
        enabled = true,
        printSummary = true
    }
}

local function FormatMoney(copper)
    copper = tonumber(copper) or 0

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper - gold * 10000) / 100)
    local copperOnly = copper - gold * 10000 - silver * 100

    local parts = {}

    if gold > 0 then
        table.insert(parts, gold .. "g")
    end

    if silver > 0 or gold > 0 then
        table.insert(parts, silver .. "s")
    end

    table.insert(parts, copperOnly .. "c")

    return table.concat(parts, " ")
end

function module:SellGreyItems(core, manual)
    if not MerchantFrame or not MerchantFrame:IsShown() then
        if manual then
            core:Print("Open a merchant first, then use /minn sell.")
        end
        return
    end

    local total = 0
    local soldCount = 0
    local maxBag = NUM_BAG_SLOTS or 4

    for bag = 0, maxBag do
        local slots = GetContainerNumSlots(bag) or 0

        for slot = slots, 1, -1 do
            local link = GetContainerItemLink(bag, slot)

            if link then
                local texture, count, locked = GetContainerItemInfo(bag, slot)
                local _, _, quality, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)

                count = count or 1
                vendorPrice = vendorPrice or 0

                if not locked and quality == 0 and vendorPrice > 0 then
                    UseContainerItem(bag, slot)
                    total = total + vendorPrice * count
                    soldCount = soldCount + count
                end
            end
        end
    end

    local db = core:GetModuleDB(self.key)

    if db and db.printSummary and total > 0 then
        core:Print("Sold " .. soldCount .. " grey item" .. (soldCount == 1 and "" or "s") .. " for " .. FormatMoney(total) .. ".")
    elseif manual and total == 0 then
        core:Print("No sellable grey items found.")
    end
end

function module:OnEnable(core)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function()
            self:SellGreyItems(core, false)
        end)
    end

    self.frame:RegisterEvent("MERCHANT_SHOW")
end

function module:OnDisable(core)
    if self.frame then
        self.frame:UnregisterEvent("MERCHANT_SHOW")
    end
end

function module:BuildOptions(core, panel, y)
    core.optionControls[self.key] = core.optionControls[self.key] or {}

    local checkbox = core:CreateCheckbox(
        panel,
        "MinnTinkers_AutoSellGrey_PrintSummary",
        "Print sale summary",
        "Print sale summary",
        "Shows one chat message with the total money gained after grey items are sold.",
        42,
        y,
        core:GetModuleDB(self.key).printSummary,
        function(checked)
            core:GetModuleDB(module.key).printSummary = checked
        end
    )

    core.optionControls[self.key].printSummary = checkbox

    return y - 30
end

function module:RefreshOptions(core)
    local controls = core.optionControls[self.key]
    local db = core:GetModuleDB(self.key)

    if controls and controls.printSummary and db then
        controls.printSummary:SetChecked(db.printSummary and true or false)
    end
end

MT:RegisterModule("AutoSellGrey", module)
