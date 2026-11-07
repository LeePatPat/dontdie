local _, addon = ...
local Core = addon.Core

function addon:CreateUI()
    local panel = CreateFrame("Frame", "DontDieReminder", UIParent, "BackdropTemplate")
    panel:SetSize(360, 300)
    panel:SetPoint("CENTER", 0, 150)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2,
    })
    panel:SetBackdropColor(0.035, 0.055, 0.07, 0.97)
    panel:SetBackdropBorderColor(0.85, 0.65, 0.22, 1)

    local brand = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    brand:SetPoint("TOP", 0, -12)
    brand:SetText("DON'T DIE (AT YOUR DESK)")
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -34)
    title:SetWidth(328)
    local body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOP", 0, -64)
    body:SetWidth(328)
    local debt = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    debt:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -16)
    debt:SetWidth(328)
    debt:SetJustifyH("LEFT")
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOM", 0, 45)

    local function button(text, x, completed)
        local control = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        control:SetSize(130, 26)
        control:SetPoint("BOTTOM", x, 12)
        control:SetText(text)
        control:SetScript("OnClick", function() Core:Dismiss(completed) end)
        return control
    end
    local done = button("Done", -72, true)
    button("Skip", 72)
    panel:Hide()

    local previous
    function self:Refresh()
        local current, heading, text = Core:Current()
        if not current then
            panel:Hide()
            previous = nil
            return
        end
        title:SetText(heading)
        body:SetText(text)
        debt:SetText(Core:DebtText())
        hint:SetText(current == "flight" and "Reminder ends when you land." or
            (#Core.db.queue .. " pending | Drag to move"))
        done:SetShown(current ~= "flight")
        panel:Show()
        if previous ~= current then
            PlaySound(SOUNDKIT.RAID_WARNING, "Master")
        end
        previous = current
    end
end
