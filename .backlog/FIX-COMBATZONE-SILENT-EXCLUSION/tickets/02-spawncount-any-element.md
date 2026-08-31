# 02 — Honour a spawn count wherever it is written

Status: ⬜ ready

Type: fix · File: `src/scripts/veaf/veafCombatZone.lua`

## The defect

```lua
if not self.elementGroups[element:getSpawnGroup()] then
  local elementGroup = {}
  elementGroup.spawnGroup = element:getSpawnGroup()
  elementGroup.spawnCount = element:getSpawnCount()   -- line 1020: the first element wins
```

Only the element that *creates* the group contributes its `#spawncount`. Writing
`#spawncount=2` on the second unit of a `#spawngroup` has no effect, and nothing says so.

Since #859, `spawnCount` is `nil` when unstated and that nil decides whether the forced draw
applies — so a lost count now changes how many groups spawn.

## Decide the conflict rule

Two elements of one group may both carry a count. Pick a rule, apply it, and **log it** rather than
resolving it in silence — the first-wins behaviour is exactly what this ticket exists to end.
Taking the highest, or the last written, are both defensible; say which and why in the PR.

## Definition of done

- [ ] A `#spawncount` on any element of a group is honoured
- [ ] A group with no stated count anywhere keeps `nil` — #859 depends on that distinction
- [ ] Conflicting counts resolve predictably and say so in the log
- [ ] Tests cover: count on the first element, on a later one, on several, and on none
- [ ] `poetry run test-lua` green, `stylua --check` clean
