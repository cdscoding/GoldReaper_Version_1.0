-- GoldReaper Addon
-- Module: MainWindow
-- Handles the main user interface window.

local addon = GoldReaper
addon.MainWindow = {}
local MainWindow = addon.MainWindow

local scrollFrame
local detailsFrame -- New frame for the details window
local displayData = {} 
local columnDefinitions = {}
local sortButtons = {}
local activeMapPinButton -- Keep track of the active map button
local customMapPin -- The custom pin for the world map
local tsmIsAvailable -- This will be set in OnInitialize

local currentSort = { key = "name", order = "asc" }
local ROW_HEIGHT = 20
local EVEN_ROW_COLOR = { r = 0.15, g = 0.15, b = 0.15, a = 0.5 }
local ODD_ROW_COLOR = { r = 0.25, g = 0.25, b = 0.25, a = 0.5 }
local DIVIDER_COLOR = { r = 0.4, g = 0.4, b = 0.4, a = 0.6 }
local SIDEBAR_BG_COLOR = { r = 0.13, g = 0.12, b = 0.11, a = 0.8 }
local SIDEBAR_BORDER_COLOR = { r = 0.13, g = 0.12, b = 0.11, a = 1.0 }

local function FormatMoney(amountInCopper)
    if not amountInCopper or amountInCopper == 0 then return "" end
    return C_CurrencyInfo.GetCoinTextureString(amountInCopper)
end

function MainWindow:UpdateDisplay()
    if not MainWindow.frame or not MainWindow.frame:IsShown() then return end
    displayData = addon:GetFarmSpotData()

    table.sort(displayData, function(a, b)
        local valA, valB = a[currentSort.key], b[currentSort.key]
        
        if type(valA) == "string" then
            valA = valA:lower()
            valB = valB:lower()
        end

        if currentSort.order == "asc" then
            return (valA or 0) < (valB or 0)
        else -- "desc"
            return (valA or 0) > (valB or 0)
        end
    end)

    local sortButtonIndex = 1
    for i, colDef in ipairs(columnDefinitions) do
        if colDef.dataIndex and sortButtons[sortButtonIndex] then
            local button, buttonText = sortButtons[sortButtonIndex], colDef.name
            if colDef.dataIndex == currentSort.key then
                buttonText = buttonText .. (currentSort.order == "asc" and " (Asc)" or " (Desc)")
            end
            button:SetText(buttonText)
            sortButtonIndex = sortButtonIndex + 1
        end
    end
    local searchText = _G["GoldReaperSearchBox"]:GetText():lower()
    local filteredData = {}
    if searchText == "" then
        filteredData = displayData
    else
        for _, rowData in ipairs(displayData) do
            if rowData.name:lower():find(searchText, 1, true) then
                table.insert(filteredData, rowData)
            end
        end
    end
    MainWindow:UpdateList(filteredData)
end

function MainWindow:UpdateList(data)
    if not scrollFrame then return end
    if scrollFrame.ScrollChild then scrollFrame.ScrollChild:Hide() end
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame.ScrollChild = scrollChild

    local totalHeight = 0
    for i, rowData in ipairs(data) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth(), ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -totalHeight)
        local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(true)
        bg:SetColorTexture(i % 2 == 0 and EVEN_ROW_COLOR.r or ODD_ROW_COLOR.r, i % 2 == 0 and EVEN_ROW_COLOR.g or ODD_ROW_COLOR.g, i % 2 == 0 and EVEN_ROW_COLOR.b or ODD_ROW_COLOR.b, i % 2 == 0 and EVEN_ROW_COLOR.a or ODD_ROW_COLOR.a)

        local currentX = -10
        local nameCell
        for j, col in ipairs(columnDefinitions) do
            if col.dataIndex then -- This is a data cell
                local text = rowData[col.dataIndex]
                if col.format == "money" then text = FormatMoney(text) elseif col.format == "number" then text = tostring(text) end
                local cell = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                cell:SetTextColor(1, 1, 1)
                cell:SetPoint("CENTER", row, "LEFT", currentX + (col.width / 2) - 5, 0)
                cell:SetText(text)
                if j == 1 then nameCell = cell end
            else -- This is the action cell (Delete)
                local deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                deleteButton:SetSize(20, 20)
                deleteButton:SetText("X")
                deleteButton:SetPoint("CENTER", row, "LEFT", currentX + (col.width / 2) - 5, 0)
                deleteButton:SetScript("OnClick", function()
                    addon:DeleteFarmSpot(rowData.zoneKey)
                end)
            end
            currentX = currentX + col.width
        end

        local detailsButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        detailsButton:SetSize(20, 20)
        detailsButton:SetText("?")
        detailsButton:SetPoint("LEFT", nameCell, "RIGHT", 5, 0)
        detailsButton:SetScript("OnClick", function()
            local spotDetails = addon:GetFarmSpotDetails(rowData.zoneKey)
            if spotDetails then
                MainWindow:ShowDetails(spotDetails)
            end
        end)

        totalHeight = totalHeight + ROW_HEIGHT
    end
    scrollChild:SetHeight(totalHeight)
end

-- Function to show the custom map pin
function MainWindow:ShowCustomMapPin(uiMapID, x, y)
    if not customMapPin then return end

    customMapPin.targetMapID = uiMapID
    customMapPin.targetX = x / 100 
    customMapPin.targetY = y / 100 
    
    customMapPin.debugPrinted = nil
    
    customMapPin:GetScript("OnUpdate")(customMapPin)

    WorldMapFrame:SetMapID(uiMapID)
    if not WorldMapFrame:IsShown() then
        ToggleWorldMap()
    end
end

-- Function to hide the custom map pin
function MainWindow:HideCustomMapPin()
    if customMapPin then
        customMapPin.targetMapID = nil 
        customMapPin.debugPrinted = nil 
        customMapPin:Hide()
    end
end

-- Function to show the details window
function MainWindow:ShowDetails(spotData)
    if not detailsFrame then return end
    detailsFrame.TitleText:SetText("Details: " .. spotData.name)
    
    local scroll = detailsFrame.ScrollFrame
    if scroll.ScrollChild then scroll.ScrollChild:Hide() end
    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(scroll:GetWidth(), 1)
    scroll:SetScrollChild(scrollChild)
    scroll.ScrollChild = scrollChild

    -- Create Headers
    local headerFrame = CreateFrame("Frame", nil, scrollChild)
    headerFrame:SetSize(scrollChild:GetWidth(), 25)
    headerFrame:SetPoint("TOPLEFT")
    local victimHeader = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2"); victimHeader:SetPoint("LEFT", 10, 0); victimHeader:SetText("Victim")
    local coordsHeader = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2"); coordsHeader:SetPoint("LEFT", 220, 0); coordsHeader:SetText("Last Kill Coords")
    local killedHeader = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2"); killedHeader:SetPoint("LEFT", 350, 0); killedHeader:SetText("Killed")
    
    if detailsFrame.dividers then
        for _, div in ipairs(detailsFrame.dividers) do
            div:Hide()
        end
    end
    detailsFrame.dividers = {}

    local divider1 = scroll:CreateTexture(nil, "ARTWORK"); divider1:SetPoint("TOPLEFT", 210, 0); divider1:SetSize(1, scroll:GetHeight()); table.insert(detailsFrame.dividers, divider1)
    local divider2 = scroll:CreateTexture(nil, "ARTWORK"); divider2:SetPoint("TOPLEFT", 340, 0); divider2:SetSize(1, scroll:GetHeight()); table.insert(detailsFrame.dividers, divider2)
    local divider3 = scroll:CreateTexture(nil, "ARTWORK"); divider3:SetPoint("TOPLEFT", 410, 0); divider3:SetSize(1, scroll:GetHeight()); table.insert(detailsFrame.dividers, divider3)
    for _, div in ipairs(detailsFrame.dividers) do
        div:SetColorTexture(DIVIDER_COLOR.r, DIVIDER_COLOR.g, DIVIDER_COLOR.b, DIVIDER_COLOR.a)
    end

    local totalHeight = 25
    local mobs = {}
    for name, data in pairs(spotData.mobBreakdown) do table.insert(mobs, {name=name, data=data}) end
    table.sort(mobs, function(a,b) return a.name < b.name end)

    for i, mob in ipairs(mobs) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth(), ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -totalHeight)
        local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(true); bg:SetColorTexture(i % 2 == 0 and EVEN_ROW_COLOR.r or ODD_ROW_COLOR.r, i % 2 == 0 and EVEN_ROW_COLOR.g or ODD_ROW_COLOR.g, i % 2 == 0 and EVEN_ROW_COLOR.b or ODD_ROW_COLOR.b, i % 2 == 0 and EVEN_ROW_COLOR.a or ODD_ROW_COLOR.a)
        
        local killCount = 0
        if type(mob.data) == "table" then
            killCount = mob.data.count or 0
        elseif type(mob.data) == "number" then
            killCount = mob.data
        end

        local lastLocation = "N/A"
        if type(mob.data) == "table" then
            lastLocation = mob.data.lastLocation or "N/A"
        end

        local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); nameText:SetPoint("LEFT", 10, 0); nameText:SetText(mob.name)
        local coordsText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); coordsText:SetPoint("LEFT", 220, 0); coordsText:SetText(lastLocation)
        local killedText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); killedText:SetPoint("LEFT", 370, 0); killedText:SetText(tostring(killCount))

        local mapButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate"); mapButton:SetSize(100, 20); mapButton:SetPoint("LEFT", 420, 0); mapButton:SetText("Show on Map")
        mapButton:SetScript("OnClick", function(self)
            if activeMapPinButton and activeMapPinButton ~= self then
                activeMapPinButton:Enable()
                activeMapPinButton:SetText("Show on Map")
            end
            
            local uiMapID = tonumber(spotData.zoneKey:match("^(%d+)::"))
            local loc = lastLocation
            if uiMapID and loc and loc ~= "N/A" then
                local x, y = loc:match("([%d,%.]+), ([%d,%.]+)")
                x, y = tonumber(x), tonumber(y)
                if x and y then
                    MainWindow:ShowCustomMapPin(uiMapID, x, y)
                    
                    self:SetText("Showing...")
                    self:Disable()
                    activeMapPinButton = self
                else
                    print("GoldReaper Error: Could not parse coordinates from: " .. loc)
                end
            else
                print("GoldReaper Error: Missing data - MapID: " .. tostring(uiMapID) .. ", Location: " .. tostring(loc))
            end
        end)
        
        totalHeight = totalHeight + ROW_HEIGHT
    end

    scrollChild:SetHeight(totalHeight + 10)
    detailsFrame:Show()
end

function MainWindow:OnInitialize()
    -- Use the global flag set in CentralHub, which is now guaranteed to be correct.
    tsmIsAvailable = addon.tsmIsAvailable

    -- DIRECTIVE: Reduce TSM window width by 168px
    local windowWidth = tsmIsAvailable and 1282 or 1100
    MainWindow.frame = CreateFrame("Frame", "GoldReaperMainWindow", UIParent, "BasicFrameTemplate")
    MainWindow.frame.TitleText:SetText("GoldReaper - v1.0.1")
    -- DIRECTIVE: Reduce window height by 30px
    MainWindow.frame:SetSize(windowWidth, 570); MainWindow.frame:SetPoint("CENTER")
    MainWindow.frame:SetMovable(true); MainWindow.frame:EnableMouse(true); MainWindow.frame:RegisterForDrag("LeftButton"); MainWindow.frame:SetScript("OnDragStart", MainWindow.frame.StartMoving); MainWindow.frame:SetScript("OnDragStop", MainWindow.frame.StopMovingOrSizing)
    
    local sidebar = CreateFrame("Frame", nil, MainWindow.frame, "BackdropTemplate")
    -- DIRECTIVE: Reduce sidebar height by 30px
    sidebar:SetSize(200, 520); sidebar:SetPoint("TOPLEFT", 10, -30)
    sidebar:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    sidebar:SetBackdropColor(SIDEBAR_BG_COLOR.r, SIDEBAR_BG_COLOR.g, SIDEBAR_BG_COLOR.b, SIDEBAR_BG_COLOR.a); sidebar:SetBackdropBorderColor(SIDEBAR_BORDER_COLOR.r, SIDEBAR_BORDER_COLOR.g, SIDEBAR_BORDER_COLOR.b, SIDEBAR_BORDER_COLOR.a)

    local searchBox = CreateFrame("EditBox", "GoldReaperSearchBox", sidebar, "SearchBoxTemplate"); searchBox:SetSize(170, 25); searchBox:SetPoint("TOPLEFT", 15, -10); searchBox:SetAutoFocus(false); searchBox.Instructions:SetText("Search..."); searchBox:SetScript("OnTextChanged", MainWindow.UpdateDisplay); searchBox:SetScript("OnEditFocusGained", function(self) self.Instructions:Hide() end); searchBox:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then self.Instructions:Show() end end)
    
    local infoButton = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate"); infoButton:SetSize(180, 25); infoButton:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -5, -5); infoButton:SetText("GoldReaper Info"); infoButton:SetScript("OnClick", function() addon:ToggleInfoWindow() end)
    local supportButton = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate"); supportButton:SetSize(180, 25); supportButton:SetPoint("TOPLEFT", infoButton, "BOTTOMLEFT", 0, -5); supportButton:SetText("Support & Community"); supportButton:SetScript("OnClick", function() addon:ToggleSupportWindow() end)
    
    local toggleMinimapButton = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    toggleMinimapButton:SetSize(180, 25)
    toggleMinimapButton:SetPoint("TOPLEFT", supportButton, "BOTTOMLEFT", 0, -5)
    toggleMinimapButton:SetText("Toggle Minimap Button")
    toggleMinimapButton:SetScript("OnClick", function()
        addon:ToggleMinimapIcon()
    end)

    local deleteCodexButton = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate"); deleteCodexButton:SetSize(180, 25); deleteCodexButton:SetPoint("TOPLEFT", toggleMinimapButton, "BOTTOMLEFT", 0, -5); deleteCodexButton:SetText("Delete Codex"); deleteCodexButton:SetScript("OnClick", function() addon:RequestWipeConfirmation() end)
    
    local filtersTitle = sidebar:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2"); filtersTitle:SetPoint("TOPLEFT", deleteCodexButton, "BOTTOMLEFT", 0, -15); filtersTitle:SetText("Sort By")

    -- Define the columns, adding TSM ones conditionally.
    columnDefinitions = {
        { name = "Farm Spot",      width = 200, dataIndex = "name",       defaultSort = "asc" },
        { name = "Total Kills",    width = 100, dataIndex = "totalKills", defaultSort = "desc", format = "number" },
        { name = "Total Coin",     width = 168, dataIndex = "totalCoin",  defaultSort = "desc", format = "money" },
        { name = "Total Vendor",   width = 168, dataIndex = "totalLootValue", defaultSort = "desc", format = "money" },
        { name = "Total Coin & Vendor", width = 180, dataIndex = "totalValue", defaultSort = "desc", format = "money" },
    }

    if tsmIsAvailable then
        -- DIRECTIVE: Rename "TSM-DBRegionSaleAvg" to "DBRegionSaleAvg"
        table.insert(columnDefinitions, { name = "DBRegionSaleAvg", width = 168, dataIndex = "totalRegionSaleAvg", defaultSort = "desc", format = "money" })
    end

    table.insert(columnDefinitions, { name = "Delete",         width = 50,  dataIndex = nil })

    local lastButton
    for i, colDef in ipairs(columnDefinitions) do
        if colDef.dataIndex then
            local button = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
            button:SetSize(180, 25)
            if not lastButton then 
                button:SetPoint("TOPLEFT", filtersTitle, "BOTTOMLEFT", 0, -5) 
            else 
                button:SetPoint("TOPLEFT", lastButton, "BOTTOMLEFT", 0, -5) 
            end
            button:SetScript("OnClick", function(self) if currentSort.key == colDef.dataIndex then currentSort.order = (currentSort.order == "asc") and "desc" or "asc" else currentSort.key = colDef.dataIndex; currentSort.order = colDef.defaultSort end; MainWindow:UpdateDisplay() end)
            lastButton = button
            table.insert(sortButtons, button)
        end
    end

    local contentPanel = CreateFrame("Frame", nil, MainWindow.frame); contentPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0); contentPanel:SetPoint("BOTTOMRIGHT", MainWindow.frame, "BOTTOMRIGHT", -10, 10)
    local header = CreateFrame("Frame", nil, contentPanel); header:SetSize(0, 25); header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT")
    local currentX = -10
    for i, colDef in ipairs(columnDefinitions) do
        local h_text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2"); h_text:SetText(colDef.name); colDef.headerWidget = h_text
        h_text:SetPoint("CENTER", header, "LEFT", currentX + (colDef.width / 2) - 5, 0)
        currentX = currentX + colDef.width
    end

    scrollFrame = CreateFrame("ScrollFrame", "GoldReaperScrollFrame", contentPanel, "UIPanelScrollFrameTemplate"); scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0); scrollFrame:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -20, 0)
    
    local currentX_div = -10
    for i = 1, #columnDefinitions - 1 do
        currentX_div = currentX_div + columnDefinitions[i].width
        local divider = contentPanel:CreateTexture(nil, "ARTWORK")
        divider:SetSize(1, contentPanel:GetHeight())
        divider:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", currentX_div - 10, 0)
        divider:SetColorTexture(DIVIDER_COLOR.r, DIVIDER_COLOR.g, DIVIDER_COLOR.b, DIVIDER_COLOR.a)
    end
    
    detailsFrame = CreateFrame("Frame", "GoldReaperDetailsWindow", UIParent, "BasicFrameTemplate")
    detailsFrame:SetSize(600, 500); detailsFrame:SetPoint("CENTER"); detailsFrame:SetMovable(true); detailsFrame:EnableMouse(true); detailsFrame:RegisterForDrag("LeftButton"); detailsFrame:SetScript("OnDragStart", detailsFrame.StartMoving); detailsFrame:SetScript("OnDragStop", detailsFrame.StopMovingOrSizing); detailsFrame:SetFrameStrata("HIGH"); detailsFrame:Hide()
    detailsFrame.TitleText:SetText("Details")
    detailsFrame.CloseButton:SetScript("OnClick", function() 
        if activeMapPinButton then
            MainWindow:HideCustomMapPin()
            activeMapPinButton:Enable()
            activeMapPinButton:SetText("Show on Map")
            activeMapPinButton = nil
        end
        detailsFrame:Hide() 
    end)
    
    detailsFrame.ScrollFrame = CreateFrame("ScrollFrame", "GoldReaperDetailsScrollFrame", detailsFrame, "UIPanelScrollFrameTemplate"); detailsFrame.ScrollFrame:SetPoint("TOPLEFT", 8, -30); detailsFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    customMapPin = CreateFrame("Button", "GoldReaperCustomMapPin", WorldMapFrame)
    customMapPin:SetSize(16, 16)
    customMapPin:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)

    customMapPin.texture = customMapPin:CreateTexture(nil, "ARTWORK")
    customMapPin.texture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    customMapPin.texture:SetAllPoints()

    customMapPin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("GoldReaper Farm Location", 1, 1, 1)
        GameTooltip:Show()
    end)
    customMapPin:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    customMapPin:SetScript("OnUpdate", function(self)
        if not self.targetMapID then
            self:Hide()
            return
        end

        local currentMapID = WorldMapFrame:GetMapID()
        if not currentMapID or self.targetMapID ~= currentMapID then
            self:Hide()
            return
        end

        local scrollContainer = WorldMapFrame.ScrollContainer
        local mapCanvas = scrollContainer and scrollContainer.Child
        if not mapCanvas then
            self:Hide()
            return
        end

        local canvasScale = scrollContainer:GetCanvasScale()
        local canvasWidth = mapCanvas:GetWidth()
        local canvasHeight = mapCanvas:GetHeight()

        local scaledWidth = canvasWidth * canvasScale
        local scaledHeight = canvasHeight * canvasScale

        local pixelX = self.targetX * scaledWidth
        local pixelY = self.targetY * scaledHeight

        self:ClearAllPoints()
        self:SetPoint("CENTER", scrollContainer, "TOPLEFT", pixelX, -pixelY)
        self:Show()
    end)

    customMapPin:Hide()

    addon.Pictures:CreatePictures(MainWindow.frame, sidebar)

    MainWindow.frame:Hide()
    
    C_Timer.After(0, function()
        addon.Popups:CreatePopups()
    end)
end

function MainWindow:IsShown() return MainWindow.frame and MainWindow.frame:IsShown() end
function MainWindow:Show() if MainWindow.frame then MainWindow.frame:Show(); MainWindow:UpdateDisplay() end end
function MainWindow:Hide() 
    if MainWindow.frame then 
        MainWindow.frame:Hide()
        if detailsFrame then detailsFrame:Hide() end
        if addon.Popups then
            addon.Popups:HideInfoWindow()
            addon.Popups:HideSupportWindow()
        end
    end 
end
function MainWindow:Toggle() 
    if MainWindow.frame then 
        if MainWindow.frame:IsShown() then 
            MainWindow:Hide() 
        else 
            MainWindow:Show() 
        end 
    end 
end
