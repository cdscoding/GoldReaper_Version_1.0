-- GoldReaper Addon
-- Module: DeleteCodexButton
-- Handles the confirmation dialog for deleting all saved data.

local addon = GoldReaper
addon.DeleteCodexButton = {}
local DeleteCodexButton = addon.DeleteCodexButton

-- This function is called from CentralHub.lua during addon initialization.
function DeleteCodexButton:OnInitialize()
    -- Define the structure of our confirmation popup.
    StaticPopupDialogs["GOLDREAPER_DELETE_CODEX_CONFIRM"] = {
        text = "Are you sure you want to delete your entire GoldReaper codex? This action cannot be undone.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            -- If the user clicks "Yes", call the function in CentralHub to wipe the data.
            addon:WipeCodex()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Prevents overlapping with other popups
    }
end

-- This function is called by the button in MainWindow.lua to show the popup.
function DeleteCodexButton:ShowConfirmationPopup()
    StaticPopup_Show("GOLDREAPER_DELETE_CODEX_CONFIRM")
end
