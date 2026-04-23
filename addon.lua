local addonName, addonTable = ...
local A = LibStub("AceAddon-3.0"):NewAddon(addonName)
A.NAME = addonName
A.VERSION_RELEASED = C_AddOns.GetAddOnMetadata(A.NAME, "Version")
A.VERSION_PACKAGED = gsub(C_AddOns.GetAddOnMetadata(A.NAME, "X-Curse-Packaged-Version") or A.VERSION_RELEASED, "^v", "")
A.AUTHOR = C_AddOns.GetAddOnMetadata(A.NAME, "Author")
A.DEBUG = 0 -- 0=off 1=on 2=verbose
A.DEBUG_MODULES = "*"  -- use comma-separated module names to filter
A.L = LibStub("AceLocale-3.0"):GetLocale(A.NAME)
addonTable[1] = A
addonTable[2] = A.L
_G[A.NAME] = A

-- Warn if another FixRaid-like addon is also loaded (e.g., the original denalb
-- version alongside this fork). Two copies fight over the same slash commands,
-- frames, and saved variables, which produces confusing errors.
local conflictFrame = CreateFrame("Frame")
conflictFrame:RegisterEvent("PLAYER_LOGIN")
conflictFrame:SetScript("OnEvent", function()
  local conflicts = {}
  for i = 1, C_AddOns.GetNumAddOns() do
    local name, title = C_AddOns.GetAddOnInfo(i)
    if name and name ~= addonName and C_AddOns.IsAddOnLoaded(name) then
      local titleLower = title and strlower(title) or ""
      local nameLower = strlower(name)
      if strfind(nameLower, "fixraid") or strfind(titleLower, "fixraid") or strfind(titleLower, "fix raid") then
        tinsert(conflicts, name)
      end
    end
  end
  if #conflicts > 0 then
    print("|cffff5555FixRaid:|r another FixRaid addon is also loaded ("..table.concat(conflicts, ", ")..").")
    print("|cffff5555FixRaid:|r two copies will conflict. Disable or delete the other one, then /reload.")
  end
end)
