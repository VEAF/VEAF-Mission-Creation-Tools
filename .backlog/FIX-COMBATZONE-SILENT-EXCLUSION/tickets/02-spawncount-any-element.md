# 02 — Honour a spawn count wherever it is written

Status: ✅ done

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

### The rule chosen

**The highest stated count wins**, and a real disagreement is logged at `info` naming the spawn
group, both values and the one kept. Two elements stating the *same* number are not a disagreement
and produce nothing.

Why the highest rather than the last written: the defect *is* order-dependence, and "the last one
written" only moves it — the order elements are added in is editor order, which the mission maker
never chose, so the two arrangements of the same mission would still disagree. Taking the highest is
order-independent, and a `#spawncount` is a guarantee ("2 of these 4, granted"), so the larger of two
promises is the one that keeps both.

## Definition of done

- [x] A `#spawncount` on any element of a group is honoured
- [x] A group with no stated count anywhere keeps `nil` — #859 depends on that distinction
- [x] Conflicting counts resolve predictably and say so in the log
- [x] Tests cover: count on the first element, on a later one, on several, and on none
- [x] `poetry run test-lua` green, `stylua --check` clean
