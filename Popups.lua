-- GoldReaper Addon
-- Module: Popups
-- Handles the Info and Support popup windows.

local addon = GoldReaper
addon.Popups = {}
local Popups = addon.Popups

-- Constants for the popup windows
local INFO_WINDOW_WIDTH = 500
local INFO_WINDOW_HEIGHT = 400
local SUPPORT_WINDOW_WIDTH = 420
local SUPPORT_WINDOW_HEIGHT = 320 -- Increased height for logo
local PATREON_LOGO_PATH = "Interface\\AddOns\\GoldReaper\\Media\\PatreonLogo.tga"

-- Color constants for text formatting
local COLORS = {
    SECTION_TITLE = "|cFFD4AF37", -- Yellow
    HIGHLIGHT = "|cFFFFFFFF",     -- White
    SUB_HIGHLIGHT = "|cFFFF8000",   -- Orange
    RESET = "|r"
}

local function CT(color, text)
    return color .. text .. COLORS.RESET
end

-- Creates the main info window for the addon
function Popups:CreateInfoWindow()
    if Popups.InfoWindow then return end
    local iw = CreateFrame("Frame", "GoldReaperInfoWindow", UIParent, "BasicFrameTemplateWithInset")
    Popups.InfoWindow = iw
    iw:SetSize(INFO_WINDOW_WIDTH, INFO_WINDOW_HEIGHT)
    iw:SetFrameStrata("DIALOG")
    iw:SetFrameLevel(addon.MainWindow.frame and (addon.MainWindow.frame:GetFrameLevel() or 5) + 5 or 10)
    iw.TitleText:SetText("GoldReaper Info")
    iw:SetMovable(true)
    iw:EnableMouse(true) -- FIX: Enabled mouse input to allow dragging.
    iw:RegisterForDrag("LeftButton")
    iw:SetScript("OnDragStart", function(self) self:StartMoving() end)
    iw:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    iw:SetClampedToScreen(true)
    iw.CloseButton:SetScript("OnClick", function() Popups:HideInfoWindow() end)

    local scroll = CreateFrame("ScrollFrame", "GoldReaperInfoScrollFrame", iw, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -30)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)

    local child = CreateFrame("Frame", "GoldReaperInfoScrollChild", scroll)
    child:SetWidth(INFO_WINDOW_WIDTH - 50)
    scroll:SetScrollChild(child)

    local fs = child:CreateFontString("GoldReaperInfoFontString", "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 10, -10)
    fs:SetWidth(child:GetWidth() - 20)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    
    local textParts = {
        CT(COLORS.SECTION_TITLE, "Welcome to GoldReaper!") .. "\n",
        "This addon is a lightweight tool designed to track your farming efficiency by recording kills, coin drops, and the vendor value of looted items for every farm spot you visit.\n\n",
        CT(COLORS.SECTION_TITLE, "How It Works") .. "\n",
        "GoldReaper automatically detects when you enter a new subzone and begins tracking your activity. It records:\n",
        "  • " .. CT(COLORS.HIGHLIGHT, "Kills:") .. " Every time you defeat an enemy.\n",
        "  • " .. CT(COLORS.HIGHLIGHT, "Coin:") .. " All gold, silver, and copper looted.\n",
        "  • " .. CT(COLORS.HIGHLIGHT, "Loot Value:") .. " The total vendor sell price of all items you loot.\n\n",
        CT(COLORS.SECTION_TITLE, "The Main Window (Codex)") .. "\n",
        "You can open the main window (your Codex) by typing " .. CT(COLORS.SUB_HIGHLIGHT, "/goldreaper") .. ", " .. CT(COLORS.SUB_HIGHLIGHT, "/gr") .. ", or by clicking the minimap icon.\n",
        "  • " .. CT(COLORS.HIGHLIGHT, "Sorting:") .. " Click the buttons on the left sidebar to sort your farm spots by name, kills, or total value.\n",
        "  • " .. CT(COLORS.HIGHLIGHT, "Details View:") .. " Click the '?' button on any row to see a detailed breakdown of that farm spot, including which mobs you've killed and their last known coordinates.\n",
        "  • " .. CT(COLORS.HIGHLIGHT, "Map Pin:") .. " In the details view, click 'Show on Map' to place a pin on your world map at the last recorded kill location for that mob.\n\n",
        CT(COLORS.SECTION_TITLE, "Data Management") .. "\n",
        "  • " .. CT(COLORS.HIGHLIGHT, "Delete Codex:") .. " This button will permanently wipe all of your saved farming data.\n\n",
        CT(COLORS.SECTION_TITLE, "Feedback & Support") .. "\n",
        "If you encounter any bugs or have suggestions, please reach out. Your support helps keep the project going!\n\n",
        -- FIX: Added creator credit line.
        CT(COLORS.SECTION_TITLE, "Creator") .. "\n",
        "GoldReaper was created by Clint Seewald (CS&A-Software)."
    }
    
    fs:SetText(table.concat(textParts, ""))
    
    C_Timer.After(0.05, function()
        if fs and child and scroll then
            local fsHeight = fs:GetHeight()
            local scrollFrameHeight = scroll:GetHeight()
            child:SetHeight(math.max(scrollFrameHeight - 10, fsHeight + 20))
        end
    end)

    iw:Hide()
end

function Popups:ShowInfoWindow()
    if not Popups.InfoWindow then Popups:CreateInfoWindow() end
    if not Popups.InfoWindow then return end
    Popups.InfoWindow:ClearAllPoints()
    Popups.InfoWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    Popups.InfoWindow:Show()
    Popups.InfoWindow:Raise()
end

function Popups:HideInfoWindow()
    if Popups.InfoWindow and Popups.InfoWindow:IsShown() then Popups.InfoWindow:Hide() end
end

function Popups:ToggleInfoWindow()
    if not Popups.InfoWindow or not Popups.InfoWindow:IsShown() then Popups:ShowInfoWindow() else Popups:HideInfoWindow() end
end

-- Creates the support/Patreon window
function Popups:CreateSupportWindow()
    if Popups.SupportWindow then return end
    local sw = CreateFrame("Frame", "GoldReaperSupportWindow", UIParent, "BasicFrameTemplateWithInset")
    Popups.SupportWindow = sw
    sw:SetSize(SUPPORT_WINDOW_WIDTH, SUPPORT_WINDOW_HEIGHT)
    sw:SetFrameStrata("DIALOG")
    sw:SetFrameLevel(addon.MainWindow.frame and (addon.MainWindow.frame:GetFrameLevel() or 5) + 5 or 10)
    -- FIX: Changed window title.
    sw.TitleText:SetText("Community & Bug Reports")
    sw:SetMovable(true)
    sw:EnableMouse(true) -- FIX: Enabled mouse input to allow dragging.
    sw:RegisterForDrag("LeftButton")
    sw:SetScript("OnDragStart", function(self) self:StartMoving() end)
    sw:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    sw:SetClampedToScreen(true)
    sw.CloseButton:SetScript("OnClick", function() Popups:HideSupportWindow() end)

    local logo = sw:CreateTexture(nil, "ARTWORK")
    logo:SetSize(256, 64) 
    logo:SetTexture(PATREON_LOGO_PATH)
    logo:SetPoint("TOP", sw, "TOP", 0, -40)

    local messageFS = sw:CreateFontString("GoldReaperSupportMessageFS", "ARTWORK", "GameFontNormal")
    messageFS:SetPoint("TOP", logo, "BOTTOM", 0, -15)
    messageFS:SetWidth(sw:GetWidth() - 40)
    messageFS:SetJustifyH("CENTER")
    messageFS:SetJustifyV("TOP")
    messageFS:SetTextColor(1, 0.82, 0) -- Gold color
    -- FIX: Updated the text to reflect the new purpose of the window.
    messageFS:SetText("Join the community to chat, get help, and report bugs! Signing up is free, and your feedback is crucial for improving the addon. If you wish to support development, donations are gratefully accepted as an option.")

    local linkBox = CreateFrame("EditBox", "GoldReaperSupportLinkBox", sw, "InputBoxTemplate")
    linkBox:SetPoint("TOP", messageFS, "BOTTOM", 0, -15)
    linkBox:SetSize(sw:GetWidth() - 60, 30)
    linkBox:SetText("https://www.patreon.com/csasoftware")
    linkBox:SetAutoFocus(false)
    linkBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    linkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    local instructionLabel = sw:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    instructionLabel:SetPoint("TOP", linkBox, "BOTTOM", 0, -5)
    instructionLabel:SetTextColor(1, 1, 1)
    instructionLabel:SetText("Press Ctrl+C to copy the URL.")

    sw:Hide()
end

function Popups:ShowSupportWindow()
    if not Popups.SupportWindow then Popups:CreateSupportWindow() end
    if not Popups.SupportWindow then return end
    Popups.SupportWindow:ClearAllPoints()
    Popups.SupportWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    Popups.SupportWindow:Show()
    Popups.SupportWindow:Raise()
end

function Popups:HideSupportWindow()
    if Popups.SupportWindow and Popups.SupportWindow:IsShown() then Popups.SupportWindow:Hide() end
end

function Popups:ToggleSupportWindow()
    if not Popups.SupportWindow or not Popups.SupportWindow:IsShown() then Popups:ShowSupportWindow() else Popups:HideSupportWindow() end
end

-- FIX: Renamed from OnInitialize to CreatePopups
function Popups:CreatePopups()
    Popups:CreateInfoWindow()
    Popups:CreateSupportWindow()
end
