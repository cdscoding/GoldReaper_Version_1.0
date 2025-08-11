-- GoldReaper Addon
-- Module: Pictures
-- Handles decorative images on the main window.

local addon = GoldReaper
addon.Pictures = {}
local Pictures = addon.Pictures

-- === Configuration Constants ===
-- Adjust these values to change the position, size, and appearance of the images.

-- GoldReaper Background Image (GoldReaper.tga)
local GR_BACKGROUND_CONFIG = {
    -- Texture path within the addon folder
    texture = "Interface\\AddOns\\GoldReaper\\Media\\GoldReaper.tga",
    -- Dimensions of the image
    width = 300,
    height = 406,
    -- Alpha (transparency), from 0.0 (invisible) to 1.0 (opaque)
    alpha = 1,
    -- Anchor point on the image itself
    anchorPoint = "CENTER",
    -- The anchor point on the relative UI element (the main window)
    relativePoint = "TOP",
    -- Pixel offset from the anchor point
    xOffset = 0,
    yOffset = -40,
}

-- GoldReaper Logo Image (GoldReaperLogo.tga)
local GR_LOGO_CONFIG = {
    texture = "Interface\\AddOns\\GoldReaper\\Media\\GoldReaperLogo.tga",
    width = 80,
    height = 86,
    -- FIX: Set to OVERLAY to ensure it appears on top of other elements within its parent frame.
    strata = "OVERLAY",
    level = 1, -- This sub-level is relative to the OVERLAY layer.
    alpha = 1.0,
    anchorPoint = "TOPRIGHT",
    relativePoint = "TOPRIGHT",
    -- FIX: Adjusted offsets to position the logo inside the top-right of the sidebar.
    xOffset = -60,
    yOffset = -346,
}
-- === End Configuration ===

-- FIX: The function now accepts the main frame and the sidebar frame as arguments.
function Pictures:CreatePictures(mainFrame, sidebar)
    if not mainFrame or not sidebar then return end
    
    -- Create GoldReaper Background Image (Parented to the main window)
    -- This is now in its own frame to control layering and positioning.
    local bgFrame = CreateFrame("Frame", "GoldReaperBackgroundFrame", mainFrame)
    bgFrame:SetFrameLevel(0) -- Set a low frame level to ensure it's behind other child frames.
    bgFrame:SetSize(GR_BACKGROUND_CONFIG.width, GR_BACKGROUND_CONFIG.height)
    bgFrame:SetPoint(GR_BACKGROUND_CONFIG.anchorPoint, mainFrame, GR_BACKGROUND_CONFIG.relativePoint, GR_BACKGROUND_CONFIG.xOffset, GR_BACKGROUND_CONFIG.yOffset)

    local bg = bgFrame:CreateTexture("GoldReaperBackgroundTexture", "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetTexture(GR_BACKGROUND_CONFIG.texture)
    bg:SetAlpha(GR_BACKGROUND_CONFIG.alpha)

    -- Create GoldReaper Logo Image (Parented to the sidebar)
    -- FIX: Changed the parent from mainFrame to sidebar to solve the layering problem.
    local logo = sidebar:CreateTexture("GoldReaperLogoTexture", GR_LOGO_CONFIG.strata)
    logo:SetTexture(GR_LOGO_CONFIG.texture)
    logo:SetSize(GR_LOGO_CONFIG.width, GR_LOGO_CONFIG.height)
    logo:SetPoint(GR_LOGO_CONFIG.anchorPoint, sidebar, GR_LOGO_CONFIG.relativePoint, GR_LOGO_CONFIG.xOffset, GR_LOGO_CONFIG.yOffset)
    logo:SetAlpha(GR_LOGO_CONFIG.alpha)
    logo:SetDrawLayer(GR_LOGO_CONFIG.strata, GR_LOGO_CONFIG.level)
end
