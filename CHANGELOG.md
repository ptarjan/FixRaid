# Changelog

## 1.1.9
- Fix the marking panel closing itself after the last raid-mark click while "Set MT" buttons were still waiting to be clicked
- Fix Escape not closing the marking panel (regression in 1.1.8)
- The main FixRaid window (/fr) and the /choose window now also close with Escape

## 1.1.8
- Fix errors that could stop the addon working in raids where WoW 12.0 hides player or instance info (subgroups, ranks, difficulty, damage meter names and totals)
- Fix `/fr tmrhs` always failing with an error
- Fix `/fr split` quietly ignoring damage/healing data and splitting by role instead
- Fix an error when using `/fr meter` in Mythic or LFR raids that aren't full
- Fix the damage meter sort claiming it had Details! data when there was none
- Right-clicking the data broker icon now closes the FixRaid window when it's already open (it used to do nothing)
- Fix an error when closing the marking panel with X or Escape during combat
- Fix a garbled chat message when another officer cancels or takes over your sort
- Fix `/choose` errors when the roll result message can't be read
- The "give tanks assist" option no longer causes a blocked-action error — WoW 12.0 stops addons from promoting assistants, so FixRaid now reminds you once to promote manually
- Fix Blizzard's Group Finder repeatedly erroring while FixRaid is loaded (the applicant list broke whenever a system chat message appeared)
- Fix achievement links in whispers failing after shift-clicking the group comp display; if no chat box is open, the comp now prints to your chat window instead of opening one
- Update for WoW 12.0.7

## 1.1.7
- Warn in chat if another FixRaid copy is also loaded (conflict between this fork and the original)

## 1.1.6
- Update for WoW 12.0.5

## 1.1.5
- Fix automatic CurseForge publishing

## 1.1.3
- Main tank buttons in marking panel — click to assign main tanks
- Mark buttons hidden when tank already has the correct raid target
- Marking panel auto-hides during combat

## 1.1.2
- Fix various errors from WoW 12.x changes

## 1.1.1
- Fix marking panel error after sorting

## 1.1.0
- Clickable marking panel for tank marking (replaces broken SetRaidTarget)
- /fr mark command to open the marking panel manually
- Evoker support
- Blizzard built-in damage meter integration
