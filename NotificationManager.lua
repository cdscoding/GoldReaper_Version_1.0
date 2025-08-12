-- GoldReaper Addon
-- Module: NotificationManager
-- Handles displaying messages when entering/discovering farm spots.

local addon = GoldReaper
addon.NotificationManager = {}
local NotificationManager = addon.NotificationManager

local currentZoneKey = nil
local notificationFrame -- The frame for our visual alert

-- === Configuration Constants ===
local NOTIFICATION_CONFIG = {
    texture = "Interface\\AddOns\\GoldReaper\\Media\\GoldReaper.tga",
    width = 240,
    height = 324,
    fadeInTime = 0.3, -- Faster fade in to match zone text
    displayTime = 1.8, -- Much shorter display time to match default zone text
    fadeOutTime = 0.7, -- Slightly longer fade out
    yOffset = 230, -- Moved up 30 more pixels from 200 to 230
}
-- === End Configuration ===

-- Creates the frame for the zone notification.
function NotificationManager:CreateNotificationFrame()
    if notificationFrame then return end

    notificationFrame = CreateFrame("Frame", "GoldReaperNotificationFrame", UIParent)
    notificationFrame:SetSize(NOTIFICATION_CONFIG.width, NOTIFICATION_CONFIG.height)
    notificationFrame:SetPoint("CENTER", UIParent, "CENTER", 0, NOTIFICATION_CONFIG.yOffset)
    notificationFrame:SetFrameStrata("BACKGROUND") -- Behind the default zone notification
    notificationFrame:SetAlpha(0)
    notificationFrame:Hide()

    local bg = notificationFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(NOTIFICATION_CONFIG.texture)
    bg:SetSize(NOTIFICATION_CONFIG.width, NOTIFICATION_CONFIG.height)
    bg:SetPoint("CENTER", notificationFrame, "CENTER", 0, 0)
end

-- Shows the notification with just the reaper image behind the zone text.
function NotificationManager:ShowZoneNotification(zoneName)
    -- Check the user's setting before showing the notification.
    if not GoldReaperDB.settings.showZoneReaper then
        return
    end

    if not notificationFrame then
        self:CreateNotificationFrame()
    end

    if not notificationFrame then 
        return 
    end

    UIFrameFadeOut(notificationFrame, 0, notificationFrame:GetAlpha(), 0)

    notificationFrame:Show()
    UIFrameFadeIn(notificationFrame, NOTIFICATION_CONFIG.fadeInTime, 0, 1)

    C_Timer.After(NOTIFICATION_CONFIG.fadeInTime + NOTIFICATION_CONFIG.displayTime, function()
        if notificationFrame and notificationFrame:IsShown() then
            UIFrameFadeOut(notificationFrame, NOTIFICATION_CONFIG.fadeOutTime, 1, 0)
        end
    end)
end

-- This function is called from CentralHub.lua during addon initialization.
function NotificationManager:OnInitialize()
    -- FIX: Anchoring the event frame to the module's table to ensure it is not garbage collected.
    self.eventFrame = CreateFrame("Frame", "GoldReaperNotificationEventFrame")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("ZONE_CHANGED")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:SetScript("OnEvent", self.OnEvent)
end

-- This is the core logic that decides if a notification should be shown.
function NotificationManager:ProcessZoneChange()
    -- Get the current zone information
    local zoneName = GetSubZoneText()
    if zoneName == "" then zoneName = GetZoneText() end
    
    if not zoneName or zoneName == "" then
        return
    end
    
    -- Use just the zone name as the key since we want to trigger on ANY area change
    local newZoneKey = zoneName
    
    -- If the new zone is the same as the one we're already tracking, do nothing.
    if newZoneKey == currentZoneKey then
        return
    end

    -- A real zone change has happened. Update our state and show the notification.
    currentZoneKey = newZoneKey
    self:ShowZoneNotification(zoneName)
end

-- The main event handler for this module.
function NotificationManager.OnEvent(self, event, ...)
    if event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "PLAYER_ENTERING_WORLD" then
        -- We add a very short delay to ensure all game data (like subzone text) is updated before we check.
        C_Timer.After(0.2, function()
            -- We call the method on the main NotificationManager table.
            NotificationManager:ProcessZoneChange()
        end)
        
        if event == "PLAYER_ENTERING_WORLD" then
            -- 'self' in an OnEvent script refers to the frame that received the event.
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end
end
