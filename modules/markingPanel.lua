--- Marking panel with SecureActionButtons for applying raid target marks.
-- Shows after sorting completes, presenting clickable buttons for each tank.
-- Required because SetRaidTarget() is protected in Patch 12.0+.
local A, L = unpack(select(2, ...))
local M = A:NewModule("markingPanel", "AceEvent-3.0")
A.markingPanel = M
M.private = {
  container = false,
  rows = {},
  pendingCombat = false,
  appliedMarks = {},  -- tracks tanks already marked via panel clicks
}
local R = M.private

local MAX_ROWS = 8
local ROW_HEIGHT = 28
local PANEL_WIDTH = 260
local TITLE_HEIGHT = 24
local PADDING = 10

local format, ipairs, min, tinsert, wipe = format, ipairs, min, tinsert, wipe
local C_Timer, CreateFrame, GetNumGroupMembers, InCombatLockdown, UnitClass, UnitName = C_Timer, CreateFrame, GetNumGroupMembers, InCombatLockdown, UnitClass, UnitName

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

function M:OnEnable()
  M:RegisterMessage("FIXGROUPS_SORT_COMPLETE")
  M:RegisterEvent("PLAYER_REGEN_ENABLED")
  M:RegisterEvent("PLAYER_ENTERING_WORLD")
  M:RegisterEvent("ROLE_CHANGED_INFORM")

  -- Pre-create container and rows.
  R.container = createContainer()
  for i = 1, MAX_ROWS do
    R.rows[i] = createRow(R.container, i)
  end
end

function M:FIXGROUPS_SORT_COMPLETE()
  if not A.options.tankMark then
    return
  end
  local pendingMarks = A.marker:GetPendingMarks()
  if not pendingMarks or #pendingMarks == 0 then
    return
  end
  if InCombatLockdown() then
    R.pendingCombat = true
    return
  end
  -- Defer to a clean execution context to break taint propagated from
  -- SetRaidSubgroup() calls during the sort process.
  C_Timer.After(0, function()
    if InCombatLockdown() then
      R.pendingCombat = true
      return
    end
    M:ShowPanel(pendingMarks)
  end)
end

function M:PLAYER_REGEN_ENABLED()
  if R.pendingCombat then
    R.pendingCombat = false
    M:FIXGROUPS_SORT_COMPLETE()
  end
end

function M:PLAYER_ENTERING_WORLD()
  wipe(R.appliedMarks)
end

function M:ROLE_CHANGED_INFORM()
  wipe(R.appliedMarks)
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

function M:ShowPanel(tankData)
  if InCombatLockdown() then
    R.pendingCombat = true
    return
  end

  local resolved = M:ResolveTankUnitIDs(tankData)

  -- Filter out tanks already marked via panel clicks.
  local filtered = {}
  for _, data in ipairs(resolved) do
    if not R.appliedMarks[data.name..":"..data.markIcon] then
      tinsert(filtered, data)
    end
  end
  if #filtered == 0 then
    return
  end

  local numRows = min(#filtered, MAX_ROWS)

  -- Update each row.
  for i = 1, numRows do
    local row = R.rows[i]
    local data = filtered[i]

    row:SetAttribute("unit", data.unitID)
    row:SetAttribute("marker", data.markIcon)

    -- Set raid target icon.
    row.markIcon:SetTexture(getMarkIconTexture(data.markIcon))

    -- Set class-colored name.
    local colorStr = A.util:ClassColor(data.class)
    local displayName = A.util:StripRealm(data.name)
    row.nameText:SetText("|c"..colorStr..displayName.."|r")

    row:SetPoint("TOPLEFT", R.container, "TOPLEFT", PADDING, -(TITLE_HEIGHT + PADDING + (i - 1) * ROW_HEIGHT))
    row:Show()
  end

  -- Hide unused rows.
  for i = numRows + 1, MAX_ROWS do
    R.rows[i]:Hide()
  end

  -- Resize container to fit rows.
  R.container:SetSize(PANEL_WIDTH, TITLE_HEIGHT + PADDING * 2 + numRows * ROW_HEIGHT)
  R.container:Show()

end

function M:HidePanel()
  if R.container then
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
  local pendingMarks = A.marker:GetPendingMarks()
  if not pendingMarks or #pendingMarks == 0 then
    A.console:Print("No tanks to mark.")
    return
  end
  M:ShowPanel(pendingMarks)
end
