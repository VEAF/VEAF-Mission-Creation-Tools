# CHORE-ACTION-DETAIL-AT-DEBUG — the running commentary of an action belongs at debug

Status: ⬜ ready

David, 2026-09-01, reading a `dcs.log` from the release-gate session: *"les messages du type
`findClearBearing` ou `FARP escort` doivent être en debug pas en info. C'est valable pour tous les
messages de ce genre (détail d'une action, pour le debugging) partout dans le code."*

## The rule

**`info` is for what a mission maker needs to know without asking.** A module loading, a version, a
mission-wide setting, something refused, something that will not work. It is read by someone who did
not go looking for it.

**`debug` is for the running commentary of one action.** "bearing 25 used at 1.054x", "found 3
candidates", "lead vehicle in range, setting route". It is read by someone who turned the level up
because they are chasing something.

The test: *would a mission maker who is not debugging want this line?* If the answer is no, it is
debug.

## The size of it

Measured across `src/scripts/veaf/`:

| Level | Call sites |
|---|---|
| error | 108 |
| warning | 112 |
| **info** | **203** |
| debug | 567 |
| trace | 1358 |

A keyword sort of the 203 puts roughly **100 on the wrong side** — the split is indicative, not
authoritative, and re-reading each one is part of the work. The heaviest files are `veaf.lua` (40),
`veafMove.lua` (15), `veafGrass.lua` (12), `veafSpawnAircraft.lua` (11).

Samples that make the case:

```lua
veaf.loggers.get(veaf.Id):info("Checking if patrol is within " .. maxDist .. "m of it's start point...")
veaf.loggers.get(veaf.Id):info("Lead vehicle in range, setting route !")
veaf.loggers.get(veaf.Id):info("Found a programmed ICLS task for carrier group " .. carrierGroupName)
```

## ⚠ One line was deliberately raised to info this morning, and R6 depends on it

`FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND` (#883) moved
`findClearBearing: no usable point in Disposition's cloud, walking the bearings instead` from debug
**to** info, on the grounds that the 2026-08-28 in-game run could not tell *why* a group had moved
because the line was invisible at the default level.

That argument was about **the in-game check**, not about everyday logging — and the check
(`DCS-SESSION-TODO.md` item **R6**) has not been run yet. So either:

- the session mission carries `global_log_level: debug` and R6 reads it there — the right answer, and
  it costs one line of `mission.yaml`; or
- R6 is run before this lot lands.

Whichever, **R6 must not silently become unverifiable.** Recording it here so the next reader does
not undo a decision without seeing the one it replaces.

## Definition of done

- [ ] Every `:info(` in `src/scripts/veaf/` re-read against the rule above and moved to debug when it
      is action detail — **enumerated, not sampled**
- [ ] The rule written down where the next contributor will meet it, not only in this PRD
- [ ] Nothing a mission maker acts on is demoted: refusals, deprecations, "this will not work"
      messages and mission-wide settings stay at info
- [ ] The community scripts (`src/scripts/community/`) are **out of scope** — they are vendored
- [ ] `poetry run test-lua`, `stylua --check src/scripts/veaf/ test/lua/`, `luacheck` clean
- [ ] `DCS-SESSION-TODO.md` R6 updated to say how to see the line it needs

## Sequencing

**After the three lots in flight land** — `FIX-GENERATOR-UNESCAPED-STRINGS`,
`FIX-GETGROUPDATA-SKIPS-NEUTRALS` and `FIX-CLONE-KEEPS-UNIT-NAMES`. This one touches nearly every Lua
file for one line each; running it beside them would produce conflicts in every file and make three
real fixes hard to read for a change that carries no behaviour.
