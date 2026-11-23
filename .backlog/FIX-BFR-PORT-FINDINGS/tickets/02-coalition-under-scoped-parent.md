# 02 — A node's coalition holds under a per-group parent

Status: ⬜ ready

Issue: [#1298](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1298).

`addSubMenuForGroups(title, perPilotParent, nil, coalition.side.BLUE)` is rendered for a red group too: under a parent rendered per group or per pilot, `_buildSubtree` only asks `groupFilter`.

- In `_buildSubtree`, when the audience is a group (`scope` set), skip a node whose `coalitionSide` is set and differs from that group's coalition.
- Same rule for commands carrying a coalition under such a parent.
- A node without `coalitionSide` behaves as today.

Tests: two human groups, one blue and one red; a per-pilot root; under it a blue-only submenu → `missionCommands.addSubMenuForGroup` is called for the blue group only. The same with a `groupFilter` and no coalition → unchanged.

Done when: the tests pass and `doc/mission-maker/scripts/veafRadio.md` (FR and EN) says that a coalition holds at any depth.
