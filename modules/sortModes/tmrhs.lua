--- Tanks > Melee > Ranged > Healers > Support.
local A, L = unpack(select(2, ...))
local P = A.sortModes
local M = P:NewModule("tmrhs", "AceEvent-3.0")
P.tmrhs = M

-- Indexes correspond to A.group.ROLE constants (TMRHSU).
local ROLE_KEY = {1, 4, 2, 3, 3, 6}
local PADDING_PLAYER = {role=5, isDummy=true}

local format, sort, tinsert = format, sort, tinsert

-- The roster has no SUPPORT role yet (A.group.ROLE is TANK/HEALER/MELEE/
-- RANGED/UNKNOWN), so the support-distribution pass is skipped until one
-- exists — without it this mode sorts like tmrh. The previous code indexed
-- M.ROLE (nil on this module), which made /fr tmrhs error every time.
local SUPPORT = A.group.ROLE.SUPPORT

-- Helper function to get the count of SUPPORT players in each group
local function getSupportCountInGroups(groups, players)
  local supportCount = {}
  for i = 1, 8 do
    supportCount[i] = 0
  end
  if not SUPPORT then
    return supportCount
  end
  for _, playerIndex in ipairs(groups) do
    local player = players[playerIndex]
    if player.role == SUPPORT and player.group then
      supportCount[player.group] = supportCount[player.group] + 1
    end
  end

  return supportCount
end

-- Modified comparison function to distribute SUPPORT roles evenly
local function getDefaultCompareFunc(sortMode, keys, players)
  local ra, rb
  local supportCount = getSupportCountInGroups(keys, players)

  return function(a, b)
    ra, rb = ROLE_KEY[players[a].role or 5] or 4, ROLE_KEY[players[b].role or 5] or 4

    -- Prioritize SUPPORT roles in groups with fewer SUPPORT players
    if SUPPORT and (players[a].role == SUPPORT or players[b].role == SUPPORT) then
      local ga, gb = players[a].group, players[b].group
      if ga and gb and supportCount[ga] ~= supportCount[gb] then
        return supportCount[ga] < supportCount[gb]
      end
    end

    if ra == rb then
      return a < b
    end
    return ra < rb
  end
end

function M:OnEnable()
  A.sortModes:Register({
    key = "tmrhs",
    name = L["sorter.mode.tmrhs"],
    desc = format("%s:|n%s.", L["tooltip.right.fixRaid"], L["sorter.mode.tmrhs"]),
    getDefaultCompareFunc = getDefaultCompareFunc,
    onBeforeSort = function(sortMode, keys, players)
      if sortMode.isIncludingSitting then
        return
      end
      -- Insert dummy players for padding to keep the healers in the last group.
      local fixedSize = A.util:GetFixedInstanceSize()
      if fixedSize then
        local k
        while #keys < fixedSize do
          k = format("_pad%02d", #keys)
          tinsert(keys, k)
          players[k] = PADDING_PLAYER
        end
      end
    end,
    onSort = function(sortMode, keys, players)
      -- Sort using the modified comparison function
      sort(keys, getDefaultCompareFunc(sortMode, keys, players))
    end,
  })
end