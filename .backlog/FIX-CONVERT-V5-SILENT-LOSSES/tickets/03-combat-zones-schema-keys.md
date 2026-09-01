# 03 — Carry the missing `combat_zones:` keys

Status: ✅ done — shipped 2026-08-17 (PR #757); in-game acceptance tracked on the PRD

Issue: [#723](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/723) · Type: feat ·
Files: `mission_builder/config_migrator.py` (`_parse_combat_zone`),
`veaf_libs/lua_config_generator.py` (`_emit_combat_zone_def`), `src/defaults/mission-folder/mission.yaml`

## The gap, verified here 2026-08-17

Six `VeafCombatZone` setters the runtime supports have **no key** in the `combat_zones:` schema —
each of them scores **0 occurrences** in `config_migrator.py`, against 5 for the control
`setBriefing`:

| Setter | Zones using it (Sharko's corpus) | Framework default |
|--------|----------------------------------|-------------------|
| `setCompletable` | 82 | `true` |
| `setShowUnitsList` | 1135 | `true` |
| `setShowZonePositionInfo` | 1135 | `true` |
| `setEnableUserActivation` | 1135 | `true` |
| `setEnableSmokeAndFlare` | 1135 | `true` |
| `disableRadioMenu` | 171 | menu enabled |

All of them are used to turn a feature **off**, and every default is `true` — so losing one does not
fall back to something neutral, it **inverts the behaviour**.

## Start with `completable`, because half of it already exists

`lua_config_generator.py:656` already emits it:

```python
if zone_def.get("completable", True) is False:
```

and `setCompletable` appears nowhere in the migrator. So the round-trip is **asymmetric**: a
hand-written `mission.yaml` can express it, a converted one never will. Closing that costs the
extraction side only — the emitter is written, tested and shipped (it came from
`FEAT-ACTIVATION-CONTROLS`).

It is also the one with real consequences. Without `completable: false`, `isCompletable()` lets
`scheduleWatchdogFunction()` arm; a zone that spawns no RED unit is deactivated at the first
watchdog tick (~60 s after activation), broadcasts "all enemies destroyed" and calls
`activateNextChainedZone()`. On 82 narrative or support zones that is a **campaign progression
break**. `disableRadioMenu` is the second worst: 171 zones that were hidden on purpose reappear in
the F10 menu, wearing the placeholder names their authors gave them *because* nobody was meant to
see them.

## What to do

Extraction in `_parse_combat_zone`, emission in `_emit_combat_zone_def` for the five that have no
emitter yet, and the keys documented on the combat-zone reference page **in both languages**.

Per the defaults-lockstep rule (`CLAUDE.md` §9.7), if the generated `mission.yaml` shape changes,
`src/defaults/mission-folder/mission.yaml` moves in the same lot.

Name the YAML keys after what they do, not after the Lua setter: the reader of a `mission.yaml` is a
mission maker, not someone who has read `veafCombatZone.lua`. Follow whatever `completable` set as
precedent rather than inventing a second convention.

## Tests

- Each setter, in a real builder chain, produces its key — and **removing the setter removes the
  key**, which is the shape of assertion Sharko's harness uses and the only one that catches an
  extractor keying on the wrong thing
- Round-trip: a v5 chain with `setCompletable(false)` converts to `completable: false` and generates
  Lua that turns it off — the asymmetry closed on both sides at once
- A zone with none of them keeps generating exactly what it generates today (the defaults are
  `true`, so an emitted `true` would be noise in every existing mission)
