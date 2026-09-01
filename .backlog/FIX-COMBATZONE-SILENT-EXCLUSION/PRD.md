# FIX-COMBATZONE-SILENT-EXCLUSION — the zone drops groups without a word, and loses a stated count

Status: ✅ done

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
| 01 | [Say which groups the zone ignored](tickets/01-report-excluded-groups.md) | fix |
| 02 | [Honour a spawn count wherever it is written](tickets/02-spawncount-any-element.md) | fix |

## Out of scope

- Changing the prefix rule itself, or making it optional. Decided: it stays.
