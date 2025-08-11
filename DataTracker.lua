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
    
    -- FIX: Added 'not UnitIsPlayer(unitId)' to exclude players from being tracked.
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
        lootValue = 0
    }
    
    -- Calculate total value of items in the loot window immediately.
    local totalValue = 0
    for i = 1, GetNumLootItems() do
        local itemLink = GetLootSlotLink(i)
        if itemLink then
            local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
            if sellPrice and sellPrice > 0 then
                local _, _, quantity = GetLootSlotInfo(i)
                if quantity and quantity > 0 then
                    totalValue = totalValue + (sellPrice * quantity)
                end
            end
        end
    end
    currentLootSession.lootValue = totalValue
end

-- When money is looted, add it to our session total.
function DataTracker:OnMoneyLooted(message)
    local targetSession = pendingLootSession or currentLootSession
    
    -- If no session exists, it's a "late" money message that arrived after
    -- the loot window closed and its processing timer already fired.
    -- We create a new pending session to catch this coin and schedule it.
    if not targetSession then
        pendingLootSession = { coin = 0, lootValue = 0 }
        targetSession = pendingLootSession
        
        -- Schedule this new session to be processed after a short delay.
        if lootProcessTimer then lootProcessTimer:Cancel() end
        lootProcessTimer = C_Timer.After(0.5, function()
            DataTracker:ProcessPendingLoot()
        end)
    end

    local totalCopper = 0
    
    -- Match gold (handles comma separators)
    local goldMatch = message:match("([%d,]+)%s+[Gg]old")
    if goldMatch then
        local goldStr = goldMatch:gsub(",", "")
        local gold = tonumber(goldStr) or 0
        totalCopper = totalCopper + (gold * 10000)
    end
    
    -- Match silver (handles comma separators)  
    local silverMatch = message:match("([%d,]+)%s+[Ss]ilver")
    if silverMatch then
        local silverStr = silverMatch:gsub(",", "")
        local silver = tonumber(silverStr) or 0
        totalCopper = totalCopper + (silver * 100)
    end
    
    -- Match copper (handles comma separators)
    local copperMatch = message:match("([%d,]+)%s+[Cc]opper")
    if copperMatch then
        local copperStr = copperMatch:gsub(",", "")
        local copper = tonumber(copperStr) or 0
        totalCopper = totalCopper + copper
    end

    -- Add to whichever session is active
    if totalCopper > 0 then
        targetSession.coin = (targetSession.coin or 0) + totalCopper
    end
end

-- Modified OnLootClosed - now delays processing to wait for money messages
function DataTracker:OnLootClosed()
    -- If there's no active loot session, there's nothing to do.
    if not currentLootSession then
        return
    end
    
    -- Store the session data but don't process it immediately
    pendingLootSession = {
        coin = currentLootSession.coin or 0,
        lootValue = currentLootSession.lootValue or 0
    }
    
    -- Clear the current session by setting it to nil, indicating no loot window is open.
    currentLootSession = nil
    
    -- Cancel any existing timer to ensure we use the latest loot data
    if lootProcessTimer then
        lootProcessTimer:Cancel()
    end
    
    -- Set a short delay to allow money messages to come in
    lootProcessTimer = C_Timer.After(0.5, function()
        DataTracker:ProcessPendingLoot()
    end)
end

-- New function to process the pending loot after delay
function DataTracker:ProcessPendingLoot()
    if not pendingLootSession then
        return
    end
    
    -- Only process if there was value
    if pendingLootSession.coin == 0 and pendingLootSession.lootValue == 0 then
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
        lootValue = pendingLootSession.lootValue
    }
    
    -- Send the completed data to the CentralHub for processing
    addon:ProcessLootEvent(lootData)

    -- Clear the pending session
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
