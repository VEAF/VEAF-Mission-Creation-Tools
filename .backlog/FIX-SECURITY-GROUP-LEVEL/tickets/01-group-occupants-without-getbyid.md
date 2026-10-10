# 01 — Find a group's human occupants without `Group.getByID`

Status: ⬜ ready

- `veafSecurity.getGroupOccupantUnitNames(groupId)` scans the players instead: `coalition.getPlayers(side)` for each coalition, keeping the units whose `getGroup():getID()` is `groupId`.
  These are exactly the "slots with a human in them" the function means, so the AI-wingman rule in its comment still holds by construction.
- Search the Lua tree for any other call to an API DCS does not have in the same guarded shape (`X.getByID and X.getByID(...)`): a guard on a function that never exists is a permanent `nil`.
- Tests in `test_veafSecurity.lua`, against the mocks, with **no** `Group.getByID` defined:
  - a level-99 pilot alone in a group → the group is level 99, and a `+` command through `veafRadio._proxyMethod` runs;
  - a level-99 and an unlisted pilot in the same group → the lowest wins;
  - a pilot in **another** group with the same unit count → not counted;
  - no human in the group → 0, refused.
  The first case fails on today's code: that is the regression test.
