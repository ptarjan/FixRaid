--- Marking panel with SecureActionButtons for applying raid target marks.
-- Shows after sorting completes, presenting clickable buttons for each tank.
-- Required because SetRaidTarget() is protected in Patch 12.0+.
local A, L = unpack(select(2, ...))
local M = A:NewModule("markingPanel", "AceEvent-3.0")
A.markingPanel = M
M.private = {
  container = false,
  rows = {},
  mtRows = {},
  pendingCombat = false,
  appliedMarks = {},  -- tracks tanks already marked via panel clicks
  appliedMTs = {},    -- tracks tanks already set as main tank via panel clicks
}
local R = M.private

local MAX_ROWS = 8
local ROW_HEIGHT = 28
local PANEL_WIDTH = 260
local TITLE_HEIGHT = 24
local PADDING = 10

local format, ipairs, min, tinsert, wipe = format, ipairs, min, tinsert, wipe
local CreateFrame, GetNumGroupMembers, InCombatLockdown, UnitClass, UnitName = CreateFrame, GetNumGroupMembers, InCombatLockdown, UnitClass, UnitName

local function getMarkIconTexture(markIndex)
  return format("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d", markIndex)
end

local function createContainer()
  local f = CreateFrame("Frame", "FixRaidMarkingPanel", UIParent, "BackdropTemplate")
  f:SetSize(PANEL_WIDTH, TITLE_HEIGHT + PADDING * 2)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  f:SetBackdropColor(0, 0, 0, 0.9)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:Hide()

  -- Title text.
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
  title:SetText("Mark Tanks")

  -- Draggable.
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  -- Close button.
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() M:HidePanel() end)

  -- Escape key support.
  tinsert(UISpecialFrames, "FixRaidMarkingPanel")

  return f
end

local function createRow(parent, index)
  local btn = CreateFrame("Button", "FixRaidMarkBtn"..index, parent, "SecureActionButtonTemplate")
  btn:SetSize(PANEL_WIDTH - PADDING * 2, ROW_HEIGHT)
  btn:SetAttribute("type", "raidtarget")
  btn:SetAttribute("action", "set")
  btn:SetAttribute("unit", "raid1")
  btn:SetAttribute("marker", 1)

  -- Highlight texture for hover.
  local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 0.1)

  -- Raid target icon on the left.
  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", btn, "LEFT", 4, 0)
  btn.markIcon = icon

  -- Tank name text.
  local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  nameText:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
  nameText:SetJustifyH("LEFT")
  btn.nameText = nameText

  btn:RegisterForClicks("AnyUp", "AnyDown")

  -- Hide row after clicking and auto-close panel when all rows are done.
  btn:SetScript("PostClick", function(self)
    -- Remember this tank+mark so the panel won't re-show for them.
    local name = UnitName(self:GetAttribute("unit"))
    local marker = self:GetAttribute("marker")
    if name and marker then
      R.appliedMarks[name..":"..marker] = true
    end
    if not InCombatLockdown() then
      self:Hide()
    end
    -- Check if any rows are still visible.
    local anyVisible = false
    for i = 1, MAX_ROWS do
      if R.rows[i] and R.rows[i]:IsShown() then
        anyVisible = true
        break
      end
    end
    if not anyVisible then
      M:HidePanel()
    end
  end)

  btn:Hide()

  return btn
end

local function createMTRow(parent, index)
  local btn = CreateFrame("Button", "FixRaidMTBtn"..index, parent, "SecureActionButtonTemplate")
  btn:SetSize(PANEL_WIDTH - PADDING * 2, ROW_HEIGHT)
  btn:SetAttribute("type", "macro")
  btn:SetAttribute("macrotext", "")

  local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 0.1)

  -- Shield icon on the left.
  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", btn, "LEFT", 4, 0)
  icon:SetAtlas("groupfinder-icon-role-large-tank")
  btn.mtIcon = icon

  -- Tank name text.
  local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  nameText:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
  nameText:SetJustifyH("LEFT")
  btn.nameText = nameText

  btn:RegisterForClicks("AnyUp", "AnyDown")

  btn:SetScript("PostClick", function(self)
    R.appliedMTs[self.mtName] = true
    if not InCombatLockdown() then
      self:Hide()
    end
    local anyVisible = false
    for i = 1, MAX_ROWS do
      if (R.rows[i] and R.rows[i]:IsShown()) or (R.mtRows[i] and R.mtRows[i]:IsShown()) then
        anyVisible = true
        break
      end
    end
    if not anyVisible then
      M:HidePanel()
    end
  end)

  btn:Hide()
  return btn
end

function M:OnEnable()
  M:RegisterMessage("FIXGROUPS_SORT_COMPLETE")
  M:RegisterEvent("PLAYER_REGEN_ENABLED")
  pcall(M.RegisterEvent, M, "PLAYER_REGEN_LOST")
  M:RegisterEvent("PLAYER_ENTERING_WORLD")
  M:RegisterEvent("ROLE_CHANGED_INFORM")

  -- Pre-create container and rows.
  R.container = createContainer()
  for i = 1, MAX_ROWS do
    R.rows[i] = createRow(R.container, i)
    R.mtRows[i] = createMTRow(R.container, i)
  end
end

function M:FIXGROUPS_SORT_COMPLETE()
  local pendingMarks = A.options.tankMark and A.marker:GetPendingMarks() or {}
  local pendingMTs = A.marker:GetPendingMainTanks() or {}
  if (not pendingMarks or #pendingMarks == 0) and #pendingMTs == 0 then
    return
  end
  if InCombatLockdown() then
    R.pendingCombat = true
    return
  end
  M:ShowPanel(pendingMarks, pendingMTs)
end

function M:PLAYER_REGEN_LOST()
  -- Can't Hide() secure frames in combat, so make invisible instead
  if R.container and R.container:IsShown() then
    R.hiddenForCombat = true
    R.container:SetAlpha(0)
    R.container:EnableMouse(false)
  end
end

function M:PLAYER_REGEN_ENABLED()
  if R.hiddenForCombat then
    R.hiddenForCombat = false
    M:HidePanel()
  end
  if R.pendingCombat then
    R.pendingCombat = false
    M:FIXGROUPS_SORT_COMPLETE()
  end
end

function M:PLAYER_ENTERING_WORLD()
  wipe(R.appliedMarks)
  wipe(R.appliedMTs)
end

function M:ROLE_CHANGED_INFORM()
  wipe(R.appliedMarks)
  wipe(R.appliedMTs)
end

function M:ResolveTankUnitIDs(tankData)
  local resolved = {}
  for _, tank in ipairs(tankData) do
    local unitID
    for j = 1, GetNumGroupMembers() do
      local name = UnitName("raid"..j)
      if name and (name == tank.name or A.util:NameAndRealm(name) == tank.name or A.util:StripRealm(tank.name) == name) then
        unitID = "raid"..j
        break
      end
    end
    if unitID then
      local _, class = UnitClass(unitID)
      tinsert(resolved, {
        name = tank.name,
        unitID = unitID,
        markIcon = tank.markIcon,
        class = class,
      })
    end
  end
  return resolved
end

function M:ShowPanel(tankData, mtData)
  if InCombatLockdown() then
    R.pendingCombat = true
    return
  end

  local resolved = M:ResolveTankUnitIDs(tankData or {})

  -- Filter out tanks already marked (via panel clicks or already correct in-game).
  local filtered = {}
  for _, data in ipairs(resolved) do
    local currentMark = GetRaidTargetIndex(data.unitID)
    local alreadyCorrect = currentMark ~= nil and not (issecretvalue and issecretvalue(currentMark)) and currentMark == data.markIcon
    if not alreadyCorrect and not R.appliedMarks[data.name..":"..data.markIcon] then
      tinsert(filtered, data)
    end
  end

  -- Filter out tanks already set as main tank via panel clicks.
  local filteredMTs = {}
  for _, data in ipairs(mtData or {}) do
    if not R.appliedMTs[data.name] then
      -- Resolve unitID (may have shifted after sort)
      local unitID
      for j = 1, GetNumGroupMembers() do
        local n = UnitName("raid"..j)
        if n and (n == data.name or A.util:StripRealm(data.name) == n) then
          unitID = "raid"..j
          break
        end
      end
      if unitID then
        local _, class = UnitClass(unitID)
        tinsert(filteredMTs, {name=data.name, unitID=unitID, class=class})
      end
    end
  end

  if #filtered == 0 and #filteredMTs == 0 then
    return
  end

  local numMarkRows = min(#filtered, MAX_ROWS)
  local totalRows = 0

  -- Update mark rows.
  for i = 1, numMarkRows do
    local row = R.rows[i]
    local data = filtered[i]

    row:SetAttribute("unit", data.unitID)
    row:SetAttribute("marker", data.markIcon)

    row.markIcon:SetTexture(getMarkIconTexture(data.markIcon))

    local colorStr = A.util:ClassColor(data.class)
    local displayName = A.util:StripRealm(data.name)
    row.nameText:SetText("|c"..colorStr..displayName.."|r")

    row:SetPoint("TOPLEFT", R.container, "TOPLEFT", PADDING, -(TITLE_HEIGHT + PADDING + totalRows * ROW_HEIGHT))
    row:Show()
    totalRows = totalRows + 1
  end

  -- Hide unused mark rows.
  for i = numMarkRows + 1, MAX_ROWS do
    R.rows[i]:Hide()
  end

  -- Update main tank rows.
  local numMTRows = min(#filteredMTs, MAX_ROWS)
  for i = 1, numMTRows do
    local row = R.mtRows[i]
    local data = filteredMTs[i]

    row.mtName = data.name
    row:SetAttribute("macrotext", "/maintank "..data.name)

    local colorStr = A.util:ClassColor(data.class)
    local displayName = A.util:StripRealm(data.name)
    row.nameText:SetText("Set MT: |c"..colorStr..displayName.."|r")

    row:SetPoint("TOPLEFT", R.container, "TOPLEFT", PADDING, -(TITLE_HEIGHT + PADDING + totalRows * ROW_HEIGHT))
    row:Show()
    totalRows = totalRows + 1
  end

  -- Hide unused MT rows.
  for i = numMTRows + 1, MAX_ROWS do
    R.mtRows[i]:Hide()
  end

  -- Resize container to fit all rows.
  R.container:SetSize(PANEL_WIDTH, TITLE_HEIGHT + PADDING * 2 + totalRows * ROW_HEIGHT)
  R.container:Show()

end

function M:HidePanel()
  if R.container then
    R.container:SetAlpha(1)
    R.container:EnableMouse(true)
    R.container:Hide()
  end
end

function M:ForceShowPanel()
  if InCombatLockdown() then
    A.console:Print("Cannot show marking panel during combat.")
    return
  end
  A.marker:FixRaid(false)
  wipe(R.appliedMarks)
  wipe(R.appliedMTs)
  local pendingMarks = A.marker:GetPendingMarks()
  local pendingMTs = A.marker:GetPendingMainTanks() or {}
  if (#pendingMarks == 0) and (#pendingMTs == 0) then
    A.console:Print("No tanks to mark or set as main tank.")
    return
  end
  M:ShowPanel(pendingMarks, pendingMTs)
end
