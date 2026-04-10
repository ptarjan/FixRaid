--- Handle setting target marker icons on players, giving tanks assist,
-- setting main tanks, and changing master looter.
local A, L = unpack(select(2, ...))
local M = A:NewModule("marker")
A.marker = M
M.private = {
  tmp1 = {},
  tmp2 = {},
  tmp3 = {},
  pendingMarks = {},
  pendingMainTanks = {},
  warnedMarking = false,
}
local R = M.private

local min, sort, tinsert, wipe = min, sort, tinsert, wipe
local GetNumGroupMembers, GetRaidRosterInfo, IsInInstance, IsInRaid, PromoteToAssistant, UnitExists, UnitGroupRolesAssigned, UnitName = GetNumGroupMembers, GetRaidRosterInfo, IsInInstance, IsInRaid, PromoteToAssistant, UnitExists, UnitGroupRolesAssigned, UnitName

local function warnMarkingUnavailable()
  if not R.warnedMarking then
    R.warnedMarking = true
    A.console:Print("Automatic raid target marking is unavailable in Patch 12.0 due to Blizzard API changes. Please mark targets manually.")
  end
end

function M:FixParty()
  if IsInRaid() then
    return
  end
  -- Raid target marking is protected in 12.0+.
  warnMarkingUnavailable()
end

function M:FixRaid(isRequestFromAssist)
  if not A.util:IsLeaderOrAssist() or not IsInRaid() then
    return
  end

  local marks = wipe(R.tmp1)
  local unsetTanks = wipe(R.tmp2)
  local setNonTanks = wipe(R.tmp3)
  local name, rank, subgroup, rank, online, raidRole, unitID, unitRole
  local firstSitting = A.util:GetFirstSittingGroup()
  if issecretvalue and issecretvalue(firstSitting) then firstSitting = 9 end
  for i = 1, GetNumGroupMembers() do
    name, rank, subgroup, _, _, _, _, online, _, raidRole = GetRaidRosterInfo(i)
    if issecretvalue and issecretvalue(subgroup) then subgroup = 1 end
    if issecretvalue and issecretvalue(rank) then rank = 0 end
    if subgroup >= 1 and subgroup < firstSitting then
      name = name or "Unknown"
      unitID = "raid"..i
      unitRole = UnitGroupRolesAssigned(unitID)
      if IsInRaid() and A.util:IsLeader() and A.options.tankAssist and unitRole == "TANK" and (not rank or rank < 1) then
        PromoteToAssistant(unitID)
      end
      if unitRole == "TANK" then
        tinsert(marks, {key=name, unitID=unitID})
        if raidRole ~= "MAINTANK" then
          tinsert(unsetTanks, {name=name, unitID=unitID})
        end
      elseif raidRole == "MAINTANK" then
        tinsert(setNonTanks, {name=name, unitID=unitID})
      end
    end
  end

  if isRequestFromAssist then
    return
  end

  -- Populate pending marks for the marking panel.
  -- Always populate regardless of tankMark option; the automatic trigger
  -- in FIXGROUPS_SORT_COMPLETE checks tankMark, but /fr mark should work
  -- even when the option is off.
  wipe(R.pendingMarks)
  for i, m in ipairs(marks) do
    local icon = A.options.tankMarkIcons[i]
    if icon and icon >= 1 and icon <= 8 then
      tinsert(R.pendingMarks, {name=m.key, markIcon=icon})
    end
  end

  -- Marking is handled by the marking panel after sorting completes.

  -- Populate pending main tank assignments for the marking panel.
  wipe(R.pendingMainTanks)
  if A.options.tankMainTankAlways or (A.options.tankMainTankPRN and IsInInstance()) then
    for _, t in ipairs(unsetTanks) do
      tinsert(R.pendingMainTanks, {name=t.name, unitID=t.unitID})
    end
  end
end

function M:GetPendingMarks()
  return R.pendingMarks
end

function M:GetPendingMainTanks()
  return R.pendingMainTanks
end
