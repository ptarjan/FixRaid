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
  for i = 1, GetNumGroupMembers() do
    name, rank, subgroup, _, _, _, _, online, _, raidRole = GetRaidRosterInfo(i)
    if subgroup >= 1 and subgroup < A.util:GetFirstSittingGroup() then
      name = name or "Unknown"
      unitID = "raid"..i
      unitRole = UnitGroupRolesAssigned(unitID)
      if IsInRaid() and A.util:IsLeader() and A.options.tankAssist and unitRole == "TANK" and (not rank or rank < 1) then
        PromoteToAssistant(unitID)
      end
      if unitRole == "TANK" then
        tinsert(marks, {key=name, unitID=unitID})
        if raidRole ~= "MAINTANK" then
          -- Can't call protected func: SetPartyAssignment("MAINTANK", unitID)
          tinsert(unsetTanks, A.util:UnitNameWithColor(unitID))
        end
      elseif raidRole == "MAINTANK" then
        -- Can't call protected func: SetPartyAssignment(nil, unitID)
        tinsert(setNonTanks, A.util:UnitNameWithColor(unitID))
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

  if A.options.tankMainTankAlways or (A.options.tankMainTankPRN and IsInInstance()) then
    local bad
    if #unsetTanks > 0 then
      bad = true
      if #unsetTanks == 1 then
        A.console:Printf(L["marker.print.needSetMainTank.singular"], A.util:LocaleTableConcat(unsetTanks))
      else
        A.console:Printf(L["marker.print.needSetMainTank.plural"], A.util:LocaleTableConcat(unsetTanks))
      end
    end
    if #setNonTanks > 0 then
      bad = true
      if #setNonTanks == 1 then
        A.console:Printf(L["marker.print.needClearMainTank.singular"], A.util:LocaleTableConcat(setNonTanks))
      else
        A.console:Printf(L["marker.print.needClearMainTank.plural"], A.util:LocaleTableConcat(setNonTanks))
      end
    end
    if bad then
      if A.options.openRaidTabPRN then
        A.console:Print(L["marker.print.useRaidTab"])
        A.utilGui:OpenRaidTab()
        return
      end
      A.console:Printf(L["marker.print.openRaidTab"], A.util:Highlight(A.util:GetBindingKey("TOGGLESOCIAL", "O")))
    end
  end
end

function M:GetPendingMarks()
  return R.pendingMarks
end
