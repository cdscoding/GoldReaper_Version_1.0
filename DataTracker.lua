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

-- Helper function to process items that needed delayed cache lookup
function DataTracker:ProcessDelayedItem(message, itemLink, quantity)
    local totalVendorValue = 0
    local tsmValues = {}

    -- Get item info for vendor price and rarity
    local itemName, _, itemRarity, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
    
    if sellPrice and sellPrice > 0 then
        totalVendorValue = totalVendorValue + (sellPrice * quantity)
    end

    -- TSM Integration
    local dbRegionSaleAvg = 0
    if addon.tsmIsAvailable then
        local itemId = itemLink:match("item:(%d+)")
        if itemId and addon.GetTSMItemValue then
            local tsmItemString = "i:" .. itemId
            local tsmValue = addon:GetTSMItemValue(tsmItemString, "DBRegionSaleAvg")
            if tsmValue and tsmValue > 0 then
                tsmValues.DBRegionSaleAvg = tsmValue * quantity
                dbRegionSaleAvg = tsmValue -- Store per-item value
            end
        end
    end

    -- If the item has value, record it
    if totalVendorValue > 0 or next(tsmValues) then
        local uiMapID = C_Map.GetBestMapForUnit("player")
        if uiMapID then
            local zoneName = GetSubZoneText()
            if zoneName == "" then zoneName = GetZoneText() end

            local itemData = {
                itemLink = itemLink,
                name = itemName,
                quantity = quantity,
                vendorPrice = sellPrice or 0,
                tsmPrice = dbRegionSaleAvg
            }

            local lootData = {
                zoneKey = uiMapID .. "::" .. zoneName,
                zoneName = zoneName,
                coin = 0,
                lootValue = totalVendorValue,
                tsmValues = next(tsmValues) and tsmValues or nil,
                item = itemData
            }
            
            addon:ProcessLootEvent(lootData)
        end
    end
end

-- When an item is looted, process its value from the chat log message.
function DataTracker:OnLootReceived(message)
    -- First, try multiple patterns to get the item link directly
    local itemLink = string.match(message, "(|c%x+|Hitem:%d+:.-|h%[.-%]|h|r)")
    
    -- If the first pattern failed, try a more permissive pattern
    if not itemLink then
        itemLink = string.match(message, "(|c.-|h%[.-%]|h|r)")
    end
    
    -- Try an even more aggressive pattern for complex enchanted items
    if not itemLink then
        itemLink = string.match(message, "(|c.-|Hitem:.-|h%[.-%]|h|r)")
    end
    
    -- If no link is found with pattern matching, try parsing the raw message
    if not itemLink then
        -- Try to find any hyperlink in the message
        local linkStart = string.find(message, "|H")
        local linkEnd = string.find(message, "|h", linkStart)
        if linkStart and linkEnd then
            -- Extract the full hyperlink structure
            local fullLinkEnd = string.find(message, "|r", linkEnd)
            if fullLinkEnd then
                itemLink = string.sub(message, linkStart - 2, fullLinkEnd + 1) -- Include color codes
            end
        end
    end

    -- If still no link is found (common for gray/junk items), fall back to parsing the name.
    if not itemLink then
        local itemName = string.match(message, "%[(.-)%]")
        if itemName then
            -- Use the item name to get its link, which contains all the necessary data.
            _, itemLink = GetItemInfo(itemName)
            
            -- If GetItemInfo returns nil, the item might not be cached yet
            if not itemLink then
                -- Store the quantity for delayed processing
                local currentQuantity = quantity
                -- Try with a brief delay for cache population
                C_Timer.After(0.2, function()
                    local _, delayedLink = GetItemInfo(itemName)
                    if delayedLink then
                        -- Reprocess with the found link
                        DataTracker:ProcessDelayedItem(message, delayedLink, currentQuantity)
                    else
                        -- Try one more time with a longer delay
                        C_Timer.After(0.5, function()
                            local _, finalLink = GetItemInfo(itemName)
                            if finalLink then
                                DataTracker:ProcessDelayedItem(message, finalLink, currentQuantity)
                            end
                        end)
                    end
                end)
                return -- Exit early, delayed processing will handle it
            end
        end
    end

    -- If we still don't have a link after both attempts, we can't process it.
    if not itemLink then 
        return 
    end

    -- The quantity can also be parsed from the message string (e.g., "...x5.")
    local quantity = tonumber(string.match(message, "x(%d+)")) or 1

    local totalVendorValue = 0
    local tsmValues = {}

    -- Get item info for vendor price and rarity
    local itemName, _, itemRarity, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
    
    if sellPrice and sellPrice > 0 then
        totalVendorValue = totalVendorValue + (sellPrice * quantity)
    end

    -- TSM Integration with debug logging
    local dbRegionSaleAvg = 0 -- For individual item tracking
    if addon.tsmIsAvailable then
        local itemId = itemLink:match("item:(%d+)")
        
        if itemId then
            local tsmItemString = "i:" .. itemId
            
            -- Check if GetTSMItemValue function exists
            if addon.GetTSMItemValue then
                local tsmValue = addon:GetTSMItemValue(tsmItemString, "DBRegionSaleAvg")
                if tsmValue and tsmValue > 0 then
                    tsmValues.DBRegionSaleAvg = (tsmValues.DBRegionSaleAvg or 0) + (tsmValue * quantity)
                    dbRegionSaleAvg = tsmValue -- Store per-item value
                end
            end
        end
    end

    -- If the item has no value, don't record anything.
    if totalVendorValue == 0 and not next(tsmValues) then
        return
    end

    -- Get current location info
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then 
        return 
    end

    local zoneName = GetSubZoneText()
    if zoneName == "" then zoneName = GetZoneText() end

    -- Package the data for this single loot event and send it for processing.
    local itemData = {
        itemLink = itemLink,
        name = itemName,
        quantity = quantity,
        vendorPrice = sellPrice or 0,
        tsmPrice = dbRegionSaleAvg
    }
    
    local lootData = {
        zoneKey = uiMapID .. "::" .. zoneName,
        zoneName = zoneName,
        coin = 0,
        lootValue = totalVendorValue,
        tsmValues = next(tsmValues) and tsmValues or nil,
        item = itemData
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
        if not uiMapID then 
            return 
        end

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
