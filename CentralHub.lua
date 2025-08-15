-- GoldReaper Addon
-- Author: Clint Seewald (CS&A-Software)
-- Version: 1.0
-- Interface: 110200

-- Initialize the main addon table.
GoldReaper = {}
local addon = GoldReaper

-- Flag to track if we've already initialized
local isInitialized = false

-- This function initializes all the addon's modules. It's called on PLAYER_ENTERING_WORLD.
function addon:InitializeModules()
    if isInitialized then return end
    
    addon.DataTracker:OnInitialize()
    addon.NotificationManager:OnInitialize()
    addon.MainWindow:OnInitialize()
    addon.DeleteCodexButton:OnInitialize()
    addon.MiniMapIcon:OnInitialize()
    print("GoldReaper v1.0.1: Modules Initialized")
    
    isInitialized = true
end

-- This function is called first when the addon's saved variables are loaded.
function addon:OnVariablesLoaded()
    -- Initialize the SavedVariables database.
    GoldReaperDB = GoldReaperDB or {}
    GoldReaperDB.farmSpots = GoldReaperDB.farmSpots or {}
    -- Initialize settings table and the new option for the zone reaper notification.
    GoldReaperDB.settings = GoldReaperDB.settings or {}
    if GoldReaperDB.settings.showZoneReaper == nil then
        GoldReaperDB.settings.showZoneReaper = true -- Default to enabled
    end
    -- Set a default value for the TSM flag. It will be properly checked later.
    addon.tsmIsAvailable = false
end

-- Comprehensive TSM detection function
local function CheckTSMAvailability()
    -- Modern TSM uses TSM_API global instead of TSM
    if TSM_API then
        -- Check for the GetCustomPriceValue function (modern TSM)
        if TSM_API.GetCustomPriceValue then
            return true
        end
        
        -- Check for other TSM_API functions
        if TSM_API.GetItemValue then
            return true
        end
    end
    
    -- Check legacy TSM global
    if TSM and TSM.GetItemValue then 
        return true
    end
    
    -- Check if TradeSkillMasterDB exists (another indicator TSM is loaded)
    if TradeSkillMasterDB then
        return false  -- TSM is there but API isn't ready yet
    end
    
    return false
end

-- Function to check TSM and initialize if ready
local function AttemptTSMDetectionAndInit()
    addon.tsmIsAvailable = CheckTSMAvailability()
    
    if addon.tsmIsAvailable then
        print("|cff00ff00GoldReaper:|r TSM detected. Auction value columns will be enabled.")
    else
        print("|cffffd100GoldReaper:|r TSM not detected. Running in standard mode.")
    end
    
    -- Initialize modules if we haven't already
    addon:InitializeModules()
end

-- Create a frame to listen for addon loading events.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "VARIABLES_LOADED" then
        addon:OnVariablesLoaded()
        self:UnregisterEvent("VARIABLES_LOADED")
        
    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "TradeSkillMaster" then
            print("GoldReaper: TSM addon just loaded, checking availability...")
            -- Small delay to ensure TSM is fully initialized
            C_Timer.After(0.5, function()
                AttemptTSMDetectionAndInit()
            end)
        elseif addonName == "GoldReaper" then
            -- Our addon just loaded, try initial TSM detection
            AttemptTSMDetectionAndInit()
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Fallback check with delay in case TSM wasn't detected earlier
        C_Timer.After(2, function()
            if not isInitialized then
                print("GoldReaper: Performing delayed TSM check and initialization...")
                AttemptTSMDetectionAndInit()
            elseif not addon.tsmIsAvailable then
                -- Re-check TSM availability even if we're already initialized
                local wasAvailable = addon.tsmIsAvailable
                addon.tsmIsAvailable = CheckTSMAvailability()
                
                if addon.tsmIsAvailable and not wasAvailable then
                    print("|cff00ff00GoldReaper:|r TSM now detected! DBRegionSaleAvg column enabled.")
                    -- Refresh the main window if it's open
                    if addon.MainWindow and addon.MainWindow.IsShown and addon.MainWindow:IsShown() then
                        addon.MainWindow:UpdateDisplay()
                    end
                end
            end
        end)
        
        -- Unregister the event so this only runs once per login.
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

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
            totalRegionSaleAvg = 0,
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
    if not lootData or not lootData.zoneKey or (lootData.coin == 0 and lootData.lootValue == 0 and not lootData.tsmValues) then return end

    local farmSpot = GoldReaperDB.farmSpots[lootData.zoneKey]
    
    if not farmSpot then
        farmSpot = {
            name = lootData.zoneName,
            zoneKey = lootData.zoneKey,
            totalKills = 0,
            totalCoin = 0,
            totalLootValue = 0,
            totalRegionSaleAvg = 0,
            totalValue = 0,
            firstFarmed = GetTime(),
            mobBreakdown = {}
        }
        GoldReaperDB.farmSpots[lootData.zoneKey] = farmSpot
    end

    farmSpot.totalCoin = farmSpot.totalCoin + lootData.coin
    farmSpot.totalLootValue = farmSpot.totalLootValue + lootData.lootValue
    
    if lootData.tsmValues then
        farmSpot.totalRegionSaleAvg = (farmSpot.totalRegionSaleAvg or 0) + (lootData.tsmValues.DBRegionSaleAvg or 0)
    end

    -- totalValue now ALWAYS represents Coin + Vendor value, matching the new column name.
    farmSpot.totalValue = farmSpot.totalCoin + farmSpot.totalLootValue
    
    farmSpot.lastFarmed = GetTime()

    if addon.MainWindow and addon.MainWindow.IsShown and addon.MainWindow:IsShown() then
        addon.MainWindow:UpdateDisplay()
    end
end

-- Helper function to get TSM item value using the correct API
function addon:GetTSMItemValue(itemLink, priceSource)
    if not addon.tsmIsAvailable or not itemLink then
        return nil
    end
    
    -- Try modern TSM_API first
    if TSM_API then
        if TSM_API.GetCustomPriceValue then
            return TSM_API.GetCustomPriceValue(priceSource or "DBMarket", itemLink)
        elseif TSM_API.GetItemValue then
            return TSM_API.GetItemValue(itemLink, priceSource or "DBMarket")
        end
    end
    
    -- Fallback to legacy TSM
    if TSM and TSM.GetItemValue then
        return TSM.GetItemValue(itemLink, priceSource or "DBMarket")
    end
    
    return nil
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
        spotData.totalRegionSaleAvg = spotData.totalRegionSaleAvg or 0
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

-- New function to toggle the zone reaper picture notification.
function addon:TogglePictureNotification()
    GoldReaperDB.settings.showZoneReaper = not GoldReaperDB.settings.showZoneReaper
    if GoldReaperDB.settings.showZoneReaper then
        print("GoldReaper: Zone Reaper notification enabled.")
    else
        print("GoldReaper: Zone Reaper notification disabled.")
    end
    
    -- Refresh the info window if it's currently open to reflect the new status.
    if addon.Popups and addon.Popups.InfoWindow and addon.Popups.InfoWindow:IsShown() then
        addon.Popups:UpdateInfoWindowText()
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
