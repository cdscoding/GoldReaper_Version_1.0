-- GoldReaper Addon
-- Module: DataTracker
-- Handles all event listening and data collection for kills and loot.

local addon = GoldReaper
addon.DataTracker = {}
local DataTracker = addon.DataTracker

-- Initialize as nil to clearly represent when no loot session is active.
local currentLootSession = nil
local watchedNameplates = {}
local eventFrame
local pendingLootSession = nil
local lootProcessTimer = nil

-- This function is called from CentralHub.lua during addon initialization.
function DataTracker:OnInitialize()
    eventFrame = CreateFrame("Frame")
    
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("LOOT_OPENED")
    eventFrame:RegisterEvent("LOOT_CLOSED")
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

-- When a loot window is opened, start a new loot session.
function DataTracker:OnLootOpened(isFromItem)
    if GetNumLootItems() == 0 and not IsFishingLoot() then return end

    -- Start a new session.
    currentLootSession = {
        coin = 0,
        lootValue = 0,
        tsmValues = nil
    }
    
    local totalVendorValue = 0
    local tsmValues = {}

    for i = 1, GetNumLootItems() do
        local itemLink = GetLootSlotLink(i)
        if itemLink then
            local _, _, quantity = GetLootSlotInfo(i)
            quantity = quantity or 1
            
            local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
            if sellPrice and sellPrice > 0 then
                totalVendorValue = totalVendorValue + (sellPrice * quantity)
            end

            if addon.tsmIsAvailable then
                -- FIX: Extract item ID and convert to TSM format
                local itemId = itemLink:match("item:(%d+)")
                if itemId then
                    local tsmItemString = "i:" .. itemId
                    local dbRegionSaleAvg = addon:GetTSMItemValue(tsmItemString, "DBRegionSaleAvg")
                    if dbRegionSaleAvg and dbRegionSaleAvg > 0 then
                        tsmValues.DBRegionSaleAvg = (tsmValues.DBRegionSaleAvg or 0) + (dbRegionSaleAvg * quantity)
                    end
                end
            end
        end
    end
    currentLootSession.lootValue = totalVendorValue
    if next(tsmValues) then
        currentLootSession.tsmValues = tsmValues
    end
end

-- When money is looted, add it to our session total.
function DataTracker:OnMoneyLooted(message)
    local targetSession = pendingLootSession or currentLootSession
    
    if not targetSession then
        pendingLootSession = { coin = 0, lootValue = 0 }
        targetSession = pendingLootSession
        
        if lootProcessTimer then lootProcessTimer:Cancel() end
        lootProcessTimer = C_Timer.After(0.5, function()
            DataTracker:ProcessPendingLoot()
        end)
    end

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
        targetSession.coin = (targetSession.coin or 0) + totalCopper
    end
end

-- Modified OnLootClosed - now delays processing to wait for money messages
function DataTracker:OnLootClosed()
    if not currentLootSession then return end
    
    pendingLootSession = {
        coin = currentLootSession.coin or 0,
        lootValue = currentLootSession.lootValue or 0,
        tsmValues = currentLootSession.tsmValues
    }
    
    currentLootSession = nil
    
    if lootProcessTimer then lootProcessTimer:Cancel() end
    
    lootProcessTimer = C_Timer.After(0.5, function()
        DataTracker:ProcessPendingLoot()
    end)
end

-- New function to process the pending loot after delay
function DataTracker:ProcessPendingLoot()
    if not pendingLootSession then return end
    
    if pendingLootSession.coin == 0 and pendingLootSession.lootValue == 0 and not pendingLootSession.tsmValues then
        pendingLootSession = nil
        return
    end

    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then
        pendingLootSession = nil
        return
    end

    local zoneName = GetSubZoneText()
    if zoneName == "" then zoneName = GetZoneText() end
    
    local lootData = {
        zoneKey = uiMapID .. "::" .. zoneName,
        zoneName = zoneName,
        coin = pendingLootSession.coin,
        lootValue = pendingLootSession.lootValue,
        tsmValues = pendingLootSession.tsmValues
    }
    
    addon:ProcessLootEvent(lootData)

    pendingLootSession = nil
    lootProcessTimer = nil
end

-- The main event handler for this module.
function DataTracker.OnEvent(self, event, ...)
    local unitId = ...
    
    if event == "NAME_PLATE_UNIT_ADDED" then
        DataTracker:OnNamePlateUnitAdded(unitId)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        DataTracker:OnNamePlateUnitRemoved(unitId)
    elseif event == "UNIT_HEALTH" then
        if watchedNameplates[unitId] then
            DataTracker:OnUnitHealth(unitId)
        end
    elseif event == "LOOT_OPENED" then
        DataTracker:OnLootOpened(...)
    elseif event == "LOOT_CLOSED" then
        DataTracker:OnLootClosed(...)
    elseif event == "CHAT_MSG_MONEY" then
        DataTracker:OnMoneyLooted(...)
    end
end
