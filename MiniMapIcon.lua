-- GoldReaper Addon
-- Module: MiniMapIcon
-- Handles the creation and interaction of the minimap icon.

local addon = GoldReaper
addon.MiniMapIcon = {}
local MiniMapIcon = addon.MiniMapIcon
local dataObject
local LibDBIcon -- Declare the library variable here to make it accessible to the whole file

-- This function is called from CentralHub.lua after VARIABLES_LOADED has fired.
function MiniMapIcon:OnInitialize()
    local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
    LibDBIcon = LibStub:GetLibrary("LibDBIcon-1.0") -- Assign the library to our upvalue

    if not LibDBIcon then
        print("|cffff0000GoldReaper Error:|r LibDBIcon-1.0 is not loaded.")
        return
    end

    dataObject = LDB:NewDataObject("GoldReaper", {
        type = "launcher",
        text = "GoldReaper",
        icon = "Interface\\Icons\\inv_misc_bone_humanskull_02",
        tooltiptext = "Click to open GoldReaper.",
        
        OnClick = function(self, button)
            if button == "LeftButton" then
                addon:ToggleMainWindow()
            elseif button == "RightButton" and IsControlKeyDown() then
                addon:TogglePictureNotification()
            elseif button == "RightButton" and IsShiftKeyDown() then
                LibDBIcon:Hide("GoldReaper")
                print("GoldReaper minimap icon hidden. You can re-enable it from the main window.")
            end
        end,
        
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("GoldReaper")
            tooltip:AddLine("Left-click to open the Codex.")
            tooltip:AddLine("Shift + Right-click to hide this button.", 0.5, 0.5, 0.5)
            tooltip:AddLine("Ctrl + Right-click to toggle the Zone Reaper.", 0.5, 0.5, 0.5)
        end
    })

    LibDBIcon:Register("GoldReaper", dataObject, GoldReaperDB)
end

-- New function to toggle the icon's visibility
function MiniMapIcon:ToggleIcon()
    if not LibDBIcon then return end -- Add a safety check
    
    if not GoldReaperDB then GoldReaperDB = {} end
    GoldReaperDB.hide = not GoldReaperDB.hide
    if GoldReaperDB.hide then
        LibDBIcon:Hide("GoldReaper")
        print("GoldReaper minimap icon hidden.")
    else
        LibDBIcon:Show("GoldReaper")
        print("GoldReaper minimap icon shown.")
    end
end
