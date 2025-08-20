-- GoldReaper Addon
-- Module: DataTracker
-- Handles all event listening and data collection for kills and loot.

local addon = GoldReaper
addon.DataTracker = {}
local DataTracker = addon.DataTracker

-- Watched units for kill tracking
local watchedNameplates = {}
local eventFrame

-- This function is called from CentralHub.lua during addon initialization.
function DataTracker:OnInitialize()
    eventFrame = CreateFrame("Frame")
    
    -- Events for tracking kills
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    
    -- Events for tracking loot (changed from LOOT_OPENED/CLOSED for reliability)
    eventFrame:RegisterEvent("CHAT_MSG_LOOT")
    eventFrame:RegisterEvent("CHAT_MSG_MONEY")

    eventFrame:SetScript("OnEvent", DataTracker.OnEvent)
end

-- When a nameplate appears, start watching its health if it's an enemy.
function DataTracker:OnNamePlateUnitAdded(unitId)
    if not unitId or watchedNameplates[unitId] then return end
    
    if UnitCanAttack("player", unitId) and not UnitIsPlayer(unitId) then
        watchedNameplates[unitId] = true
    end
end

-- When a nameplate disappears, stop watching it.
function DataTracker:OnNamePlateUnitRemoved(unitId)
    if not unitId or not watchedNameplates[unitId] then return end
    watchedNameplates[unitId] = nil
end

-- When a watched unit's health changes, check if it died.
function DataTracker:OnUnitHealth(unitId)
    if UnitHealth(unitId) <= 0 then
        local creatureType = UnitCreatureType(unitId)
        if creatureType == "Critter" then
            return -- Do nothing for critters
        end

        local guid = UnitGUID(unitId)
        local name = UnitName(unitId)
        
        if guid and name then
            local uiMapID = C_Map.GetBestMapForUnit("player")
            if not uiMapID then return end -- Safety check

            local zoneName = GetSubZoneText()
            if zoneName == "" then zoneName = GetZoneText() end

            local coords = C_Map.GetPlayerMapPosition(uiMapID, "player")
            local locationString = "N/A"
            if coords then
                locationString = string.format("%.1f, %.1f", coords.x * 100, coords.y * 100)
            end

            -- Package the data and send it to the CentralHub for immediate processing.
            local killData = {
                name = name,
                zoneKey = uiMapID .. "::" .. zoneName,
                zoneName = zoneName,
                location = locationString
            }
            addon:ProcessKill(killData)
            
            -- Remove the unit from the watch list to prevent counting it again.
            DataTracker:OnNamePlateUnitRemoved(unitId)
        end
    end
end

-- When an item is looted, process its value from the chat log message.
function DataTracker:OnLootReceived(message)
    -- First, try to get the item link directly. This works for most items.
    local itemLink = string.match(message, "(|c%x+|Hitem:%d+:.-|h%[.-%]|h|r)")

    -- If no link is found (common for gray/junk items), fall back to parsing the name.
    if not itemLink then
        local itemName = string.match(message, "%[(.-)%]")
        if itemName then
            -- Use the item name to get its link, which contains all the necessary data.
            _, itemLink = GetItemInfo(itemName)
        end
    end

    -- If we still don't have a link after both attempts, we can't process it.
    if not itemLink then return end

    -- The quantity can also be parsed from the message string (e.g., "...x5.")
    local quantity = tonumber(string.match(message, "x(%d+)")) or 1

    local totalVendorValue = 0
    local tsmValues = {}

    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
    if sellPrice and sellPrice > 0 then
        totalVendorValue = totalVendorValue + (sellPrice * quantity)
    end

    if addon.tsmIsAvailable then
        local itemId = itemLink:match("item:(%d+)")
        if itemId then
            local tsmItemString = "i:" .. itemId
            local dbRegionSaleAvg = addon:GetTSMItemValue(tsmItemString, "DBRegionSaleAvg")
            if dbRegionSaleAvg and dbRegionSaleAvg > 0 then
                tsmValues.DBRegionSaleAvg = (tsmValues.DBRegionSaleAvg or 0) + (dbRegionSaleAvg * quantity)
            end
        end
    end

    -- If the item has no value, don't record anything.
    if totalVendorValue == 0 and not next(tsmValues) then
        return
    end

    -- Get current location info
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then return end

    local zoneName = GetSubZoneText()
    if zoneName == "" then zoneName = GetZoneText() end

    -- Package the data for this single loot event and send it for processing.
    local lootData = {
        zoneKey = uiMapID .. "::" .. zoneName,
        zoneName = zoneName,
        coin = 0,
        lootValue = totalVendorValue,
        tsmValues = next(tsmValues) and tsmValues or nil
    }
    
    addon:ProcessLootEvent(lootData)
end

-- When money is looted, process it from the chat log message.
function DataTracker:OnMoneyLooted(message)
    -- Simplified to process money immediately without session management.
    local totalCopper = 0
    local goldMatch = message:match("([%d,]+)%s+[Gg]old")
    if goldMatch then 
        local cleanGold = goldMatch:gsub(",", "")
        totalCopper = totalCopper + (tonumber(cleanGold) * 10000) 
    end
    local silverMatch = message:match("([%d,]+)%s+[Ss]ilver")
    if silverMatch then 
        local cleanSilver = silverMatch:gsub(",", "")
        totalCopper = totalCopper + (tonumber(cleanSilver) * 100) 
    end
    local copperMatch = message:match("([%d,]+)%s+[Cc]opper")
    if copperMatch then 
        local cleanCopper = copperMatch:gsub(",", "")
        totalCopper = totalCopper + tonumber(cleanCopper) 
    end

    if totalCopper > 0 then
        local uiMapID = C_Map.GetBestMapForUnit("player")
        if not uiMapID then return end

        local zoneName = GetSubZoneText()
        if zoneName == "" then zoneName = GetZoneText() end
        
        local lootData = {
            zoneKey = uiMapID .. "::" .. zoneName,
            zoneName = zoneName,
            coin = totalCopper,
            lootValue = 0,
            tsmValues = nil
        }
        
        addon:ProcessLootEvent(lootData)
    end
end

-- The main event handler for this module.
function DataTracker.OnEvent(self, event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        DataTracker:OnNamePlateUnitAdded(...)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        DataTracker:OnNamePlateUnitRemoved(...)
    elseif event == "UNIT_HEALTH" then
        local unitId = ...
        if watchedNameplates[unitId] then
            DataTracker:OnUnitHealth(unitId)
        end
    elseif event == "CHAT_MSG_LOOT" then
        -- The first argument is the message string.
        DataTracker:OnLootReceived(...)
    elseif event == "CHAT_MSG_MONEY" then
        DataTracker:OnMoneyLooted(...)
    end
end
