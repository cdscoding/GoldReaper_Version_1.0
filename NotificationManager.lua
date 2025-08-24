-- GoldReaper Addon
-- Module: NotificationManager
-- Handles displaying messages when entering/discovering farm spots.

local addon = GoldReaper
addon.NotificationManager = {}
local NotificationManager = addon.NotificationManager

-- This function is called from CentralHub.lua during addon initialization.
function NotificationManager:OnInitialize()
    -- Zone notification functionality has been disabled as per directive.
end
