-- GoldReaper Addon
-- Author: Clint Seewald (CS&A-Software)
-- Version: 0.0.90 Beta
-- Interface: 110200

-- Initialize the main addon table.
GoldReaper = {}
local addon = GoldReaper

-- This function will be called once the addon and its saved variables are fully loaded.
function addon:OnInitialize()
    -- Initialize the SavedVariables database.
    GoldReaperDB = GoldReaperDB or {}
    GoldReaperDB.farmSpots = GoldReaperDB.farmSpots or {}

    print("GoldReaper v0.0.90 Beta: Loaded")

    -- === DEBUGGING INSTRUCTIONS ===
    -- To find the conflict, comment out ONE of the following lines at a time by adding '--' to the beginning.
    -- After commenting out a line, save the file and type /reload in the game chat.
    -- If the error in AuctioneersLedger goes away, you've found the module causing the conflict.

    addon.DataTracker:OnInitialize()       -- Line to test #1
    addon.NotificationManager:OnInitialize() -- Line to test #2
    addon.MainWindow:OnInitialize()        -- Line to test #3 (This also loads Popups and Pictures)
    addon.DeleteCodexButton:OnInitialize() -- Line to test #4
    addon.MiniMapIcon:OnInitialize()       -- Line to test #5
end

-- New function to process kills as they happen.
function addon:ProcessKill(killData)
    if not killData or not killData.zoneKey then return end

    -- Get or create the farm spot.
    local farmSpot = GoldReaperDB.farmSpots[killData.zoneKey]
    if not farmSpot then
        farmSpot = {
            name = killData.zoneName,
            zoneKey = killData.zoneKey,
            totalKills = 0,
            totalCoin = 0,
            totalLootValue = 0,
            totalValue = 0,
            firstFarmed = GetTime(),
            mobBreakdown = {}
        }
        GoldReaperDB.farmSpots[killData.zoneKey] = farmSpot
    end

    farmSpot.totalKills = farmSpot.totalKills + 1
    farmSpot.lastFarmed = GetTime()

    local mobInfo = farmSpot.mobBreakdown[killData.name]

    if not mobInfo or type(mobInfo) ~= "table" then
        local oldCount = (type(mobInfo) == "number" and mobInfo) or 0
        mobInfo = { count = oldCount, lastLocation = "N/A" }
        farmSpot.mobBreakdown[killData.name] = mobInfo
    end
    
    mobInfo.count = mobInfo.count + 1
    mobInfo.lastLocation = killData.location
    
    if addon.MainWindow and addon.MainWindow.IsShown and addon.MainWindow:IsShown() then
        addon.MainWindow:UpdateDisplay()
    end
end


-- This function now ONLY processes loot value and coin. Kill counting is separate.
function addon:ProcessLootEvent(lootData)
    if not lootData or not lootData.zoneKey or (lootData.coin == 0 and lootData.lootValue == 0) then return end

    local farmSpot = GoldReaperDB.farmSpots[lootData.zoneKey]
    
    if not farmSpot then
        farmSpot = {
            name = lootData.zoneName,
            zoneKey = lootData.zoneKey,
            totalKills = 0,
            totalCoin = 0,
            totalLootValue = 0,
            totalValue = 0,
            firstFarmed = GetTime(),
            mobBreakdown = {}
        }
        GoldReaperDB.farmSpots[lootData.zoneKey] = farmSpot
    end

    farmSpot.totalCoin = farmSpot.totalCoin + lootData.coin
    farmSpot.totalLootValue = farmSpot.totalLootValue + lootData.lootValue
    farmSpot.totalValue = farmSpot.totalCoin + farmSpot.totalLootValue
    farmSpot.lastFarmed = GetTime()

    if addon.MainWindow and addon.MainWindow.IsShown and addon.MainWindow:IsShown() then
        addon.MainWindow:UpdateDisplay()
    end
end

-- Wipes all data from the codex.
function addon:WipeCodex()
    GoldReaperDB.farmSpots = {}
    print("GoldReaper: Your codex has been wiped clean.")
    if addon.MainWindow and addon.MainWindow.IsShown and addon.MainWindow:IsShown() then
        addon.MainWindow:UpdateDisplay()
    end
end

-- Deletes a single farm spot from the codex.
function addon:DeleteFarmSpot(zoneKey)
    if GoldReaperDB.farmSpots[zoneKey] then
        local spotName = GoldReaperDB.farmSpots[zoneKey].name
        GoldReaperDB.farmSpots[zoneKey] = nil
        print("GoldReaper: Farm spot '" .. spotName .. "' has been deleted.")
        if addon.MainWindow and addon.MainWindow.IsShown and addon.MainWindow:IsShown() then
            addon.MainWindow:UpdateDisplay()
        end
    end
end

function addon:RequestWipeConfirmation()
    if addon.DeleteCodexButton and addon.DeleteCodexButton.ShowConfirmationPopup then
        addon.DeleteCodexButton:ShowConfirmationPopup()
    end
end

-- Returns all farm spot data for the MainWindow.
function addon:GetFarmSpotData()
    local dataForDisplay = {}
    for key, spotData in pairs(GoldReaperDB.farmSpots) do
        table.insert(dataForDisplay, spotData)
    end
    return dataForDisplay
end

-- New function to get detailed breakdown for a specific farm spot.
function addon:GetFarmSpotDetails(zoneKey)
    return GoldReaperDB.farmSpots[zoneKey]
end

-- Central function to toggle the main window's visibility.
function addon:ToggleMainWindow()
    if addon.MainWindow and addon.MainWindow.Toggle then
        addon.MainWindow:Toggle()
    end
end

-- New function to toggle the minimap icon's visibility.
function addon:ToggleMinimapIcon()
    if addon.MiniMapIcon and addon.MiniMapIcon.ToggleIcon then
        addon.MiniMapIcon:ToggleIcon()
    end
end

-- New functions to toggle the popup windows
function addon:ToggleInfoWindow()
    if addon.Popups and addon.Popups.ToggleInfoWindow then
        addon.Popups:ToggleInfoWindow()
    end
end

function addon:ToggleSupportWindow()
    if addon.Popups and addon.Popups.ToggleSupportWindow then
        addon.Popups:ToggleSupportWindow()
    end
end

-- Create a frame to listen for the VARIABLES_LOADED event.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:SetScript("OnEvent", function(self, event)
    addon:OnInitialize()
    self:UnregisterEvent("VARIABLES_LOADED")
end)
