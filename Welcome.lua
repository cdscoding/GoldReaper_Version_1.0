-- GoldReaper Addon
-- Module: Welcome
-- Handles the Welcome window that appears on first login.

local addon = GoldReaper
addon.Welcome = {}
local Welcome = addon.Welcome

-- Constants for the popup window
local WELCOME_WINDOW_WIDTH = 420
local WELCOME_WINDOW_HEIGHT = 580 -- Increased height for tutorial text
local DISCORD_LOGO_PATH = "Interface\\AddOns\\GoldReaper\\Media\\DiscordLogo.tga"
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

-- This function is called from CentralHub.lua during addon initialization.
function Welcome:OnInitialize()
    -- This module creates its window on demand, so no initialization logic is needed here.
end

-- Creates the welcome window
function Welcome:CreateWindow()
    if Welcome.Window then return end
    local ww = CreateFrame("Frame", "GoldReaperWelcomeWindow", UIParent, "BasicFrameTemplateWithInset")
    Welcome.Window = ww
    ww:SetSize(WELCOME_WINDOW_WIDTH, WELCOME_WINDOW_HEIGHT)
    ww:SetFrameStrata("DIALOG")
    ww:SetFrameLevel(addon.MainWindow.frame and (addon.MainWindow.frame:GetFrameLevel() or 5) + 5 or 10)
    ww.TitleText:SetText("Welcome to GoldReaper!")
    ww:SetMovable(true)
    ww:EnableMouse(true)
    ww:RegisterForDrag("LeftButton")
    ww:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ww:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    ww:SetClampedToScreen(true)
    ww.CloseButton:SetScript("OnClick", function() Welcome:HideWindow() end)

    -- Tutorial Text
    local tutorialText = ww:CreateFontString("GoldReaperWelcomeTutorialFS", "ARTWORK", "GameFontNormal")
    tutorialText:SetPoint("TOPLEFT", 15, -40)
    tutorialText:SetWidth(ww:GetWidth() - 30)
    tutorialText:SetJustifyH("LEFT")
    tutorialText:SetJustifyV("TOP")
    local tutorialContent = {
        CT(COLORS.SECTION_TITLE, "Getting Started") .. "\n",
        "Tracking is fully automatic! Simply defeat enemies and loot them to populate your Codex.\n\n",
        "To open the main window, type " .. CT(COLORS.SUB_HIGHLIGHT, "/gr") .. " or " .. CT(COLORS.SUB_HIGHLIGHT, "/goldreaper") .. " in chat, or simply click the minimap icon."
    }
    tutorialText:SetText(table.concat(tutorialContent, ""))

    -- Discord Logo and Link (positioned below tutorial)
    local discordLogo = ww:CreateTexture(nil, "ARTWORK")
    discordLogo:SetSize(328, 108) 
    discordLogo:SetTexture(DISCORD_LOGO_PATH)
    discordLogo:SetPoint("TOP", tutorialText, "BOTTOM", 0, -20)

    local discordLinkBox = CreateFrame("EditBox", "GoldReaperWelcomeDiscordLinkBox", ww, "InputBoxTemplate")
    discordLinkBox:SetPoint("TOP", discordLogo, "BOTTOM", 0, -10)
    discordLinkBox:SetSize(ww:GetWidth() - 60, 30)
    discordLinkBox:SetText("https://discord.gg/5TfC7ey3Te")
    discordLinkBox:SetAutoFocus(false)
    discordLinkBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    discordLinkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    discordLinkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    local discordInstructionLabel = ww:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    discordInstructionLabel:SetPoint("TOP", discordLinkBox, "BOTTOM", 0, -5)
    discordInstructionLabel:SetTextColor(1, 1, 1)
    discordInstructionLabel:SetText("Press Ctrl+C to copy the URL.")

    -- Patreon Logo and Link
    local patreonLogo = ww:CreateTexture(nil, "ARTWORK")
    patreonLogo:SetSize(256, 64) 
    patreonLogo:SetTexture(PATREON_LOGO_PATH)
    patreonLogo:SetPoint("TOP", discordInstructionLabel, "BOTTOM", 0, -20)

    local messageFS = ww:CreateFontString("GoldReaperWelcomeSupportMessageFS", "ARTWORK", "GameFontNormal")
    messageFS:SetPoint("TOP", patreonLogo, "BOTTOM", 0, -15)
    messageFS:SetWidth(ww:GetWidth() - 40)
    messageFS:SetJustifyH("CENTER")
    messageFS:SetJustifyV("TOP")
    messageFS:SetTextColor(1, 0.82, 0) -- Gold color
    messageFS:SetText("Join the community to chat, get help, and report bugs! Signing up is free, and your feedback is crucial for improving the addon. If you wish to support development, donations are gratefully accepted as an option.")

    local patreonLinkBox = CreateFrame("EditBox", "GoldReaperWelcomePatreonLinkBox", ww, "InputBoxTemplate")
    patreonLinkBox:SetPoint("TOP", messageFS, "BOTTOM", 0, -15)
    patreonLinkBox:SetSize(ww:GetWidth() - 60, 30)
    patreonLinkBox:SetText("https://www.patreon.com/csasoftware")
    patreonLinkBox:SetAutoFocus(false)
    patreonLinkBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    patreonLinkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    patreonLinkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    local patreonInstructionLabel = ww:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    patreonInstructionLabel:SetPoint("TOP", patreonLinkBox, "BOTTOM", 0, -5)
    patreonInstructionLabel:SetTextColor(1, 1, 1)
    patreonInstructionLabel:SetText("Press Ctrl+C to copy the URL.")

    -- "Do not show again" Checkbox
    local dontShowCheck = CreateFrame("CheckButton", "GoldReaperDontShowWelcomeCheck", ww, "UICheckButtonTemplate")
    dontShowCheck:SetPoint("BOTTOMLEFT", 10, 10)
    _G[dontShowCheck:GetName() .. "Text"]:SetText("Do not show this again")
    
    dontShowCheck:SetScript("OnClick", function(self)
        GoldReaperDB.settings.showWelcomeWindow = not self:GetChecked()
    end)
    
    dontShowCheck:SetScript("OnShow", function(self)
        self:SetChecked(not GoldReaperDB.settings.showWelcomeWindow)
    end)

    ww:Hide()
end

function Welcome:ShowWindow()
    if not Welcome.Window then Welcome:CreateWindow() end
    if not Welcome.Window then return end
    Welcome.Window:ClearAllPoints()
    Welcome.Window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    Welcome.Window:Show()
    Welcome.Window:Raise()
end

function Welcome:HideWindow()
    if Welcome.Window and Welcome.Window:IsShown() then Welcome.Window:Hide() end
end

function Welcome:ToggleWindow()
    if not Welcome.Window or not Welcome.Window:IsShown() then Welcome:ShowWindow() else Welcome:HideWindow() end
end
