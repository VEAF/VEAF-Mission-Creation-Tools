# FIX-COMBATZONE-SILENT-EXCLUSION — the zone drops groups without a word, and loses a stated count

Status: ✅ done · archived 2026-09-28

Origin: two defects found around `DOC-COMBATZONE-PREFIX-RULE` (PR #866) and
`FIX-COMBATZONE-SPAWNCHANCE` (PR #859). David's call, 2026-08-31: **keep the prefix rule, fix its
silence.**

## 1. A group in the zone with the wrong name is dropped silently

`findUnitsInCombatZone` (`veafCombatZone.lua:1974`) keeps a group only when its name starts with
the trigger zone's name. Everything else in the circle is discarded with nothing above `trace` —
so a mission maker who names a group wrongly sees the zone activate, sees nothing spawn, and finds
an empty log.

**The rule stays.** Its history and its purpose were established before this lot: it appeared with
quad-based zones (`beff4ca5`, 2024-02-15, "added quad-based Combat Zones") — a hand-drawn polygon
can cover a valley, and geometry stopped being able to express membership. It carries three things
a trigger zone cannot: overlapping zones would each claim a group in the intersection; a zone
normally contains things that are not its garrison (a FARP, a passing convoy, a QRA group); and
**completion** — a zone is done when everything it holds is dead, so adopting a foreign group that
never dies means never completing, invisibly.

What changes is only the silence.

## 2. A stated `#spawncount` is lost depending on element order

`addZoneElement` (`veafCombatZone.lua:1020`) takes `elementGroup.spawnCount` from the **first**
element that creates the group. Written on any later element of the same `#spawngroup`, it is
dropped.

Pre-existing — before #859 the first element's default `1` won just the same — but it matters more
now: `#spawncount` decides whether the forced draw applies at all, so losing it silently changes
how many groups spawn, not just the bookkeeping.

## Definition of done

- [x] At zone build-up, a log line (level `info`) names the groups found inside the zone but
      excluded for their name — one line per zone, and nothing at all when there are none
- [x] The message says what to do: the group must be **prefixed with the zone name**
- [x] A `#spawncount` written on any element of a group is honoured, wherever it sits in the order
- [x] Conflicting counts within one group are resolved predictably, and the choice is stated in the
      log rather than silently taken
- [x] Tests drive `activate()` through the DCS mocks — the seeded-RNG harness from #859 lives in
      `test/lua/veaf_test_random.lua`

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Say which groups the zone ignored](FIX-COMBATZONE-SILENT-EXCLUSION.md) | fix |
| 02 | [Honour a spawn count wherever it is written](FIX-COMBATZONE-SILENT-EXCLUSION.md) | fix |

## Out of scope

- Changing the prefix rule itself, or making it optional. Decided: it stays.

---

## Tickets, in full

## 01 — Say which groups the zone ignored

Status: ✅ done

Type: fix · File: `src/scripts/veaf/veafCombatZone.lua`

### The change

`findUnitsInCombatZone` walks every unit inside the trigger zone and keeps those whose group name
starts with the zone name. Collect the ones it drops, and report them once per zone at `info`.

Requirements that matter more than the wording:

- **One line per zone, not per unit.** A zone can hold dozens of units of a handful of groups.
- **Nothing at all when nothing is excluded** — a message every mission prints is a message nobody
  reads.
- The text must say *why* and *what to do*: the group name has to start with the zone name.
- Group names, not unit names: that is what the maker has to rename.

Both languages, through the i18n catalogue like the rest of the module.

### Definition of done

- [x] A zone containing a wrongly-named group logs it at `info`, naming the group and the zone
- [x] A zone whose groups are all correctly named logs nothing
- [x] Several excluded groups produce one line, not one line each
- [x] Tests assert what `activate()` (or the build-up path) actually logged, through the mocks
- [x] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean

---

## 02 — Honour a spawn count wherever it is written

Status: ✅ done

Type: fix · File: `src/scripts/veaf/veafCombatZone.lua`

### The defect

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

### Decide the conflict rule

Two elements of one group may both carry a count. Pick a rule, apply it, and **log it** rather than
resolving it in silence — the first-wins behaviour is exactly what this ticket exists to end.
Taking the highest, or the last written, are both defensible; say which and why in the PR.

#### The rule chosen

**The highest stated count wins**, and a real disagreement is logged at `info` naming the spawn
group, both values and the one kept. Two elements stating the *same* number are not a disagreement
and produce nothing.

Why the highest rather than the last written: the defect *is* order-dependence, and "the last one
written" only moves it — the order elements are added in is editor order, which the mission maker
never chose, so the two arrangements of the same mission would still disagree. Taking the highest is
order-independent, and a `#spawncount` is a guarantee ("2 of these 4, granted"), so the larger of two
promises is the one that keeps both.

### Definition of done

- [x] A `#spawncount` on any element of a group is honoured
- [x] A group with no stated count anywhere keeps `nil` — #859 depends on that distinction
- [x] Conflicting counts resolve predictably and say so in the log
- [x] Tests cover: count on the first element, on a later one, on several, and on none
- [x] `poetry run test-lua` green, `stylua --check` clean

---
