# FIX-CTLD-RC9-LOAD-GATE — CTLD rc8 kills every radio menu; vendor rc9 and gate the loading

Status: 🔄 in-progress

Reported by **Tripack** on the VEAF Discord, 2026-09-12, against VEAF Tools 6.22.0 —
[#957](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/957).

## What a mission maker sees

A mission built with 6.22.0 boots, is playable, and has **no F10 radio menu at all** — neither
CTLD's nor VEAF's. The only clue is one line in `dcs.log`:

```
ERROR SCRIPTING (Main): Mission script error: CTLD configuration is not loaded —
call ctld.initialize() before reading any CTLD setting or using a CTLD manager.
[string "l10n/DEFAULT/CTLD.lua"]:172 → 5802 'log' → 7810 '_init' → 7799 'getInstance' → 23078 main chunk
```

## Root cause, and why the blast radius is the whole framework

The vendored `CTLD.lua` (`2.0.0-rc8`, synced yesterday by
[#955](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/955)) **does not load**. It raises
inside its own main chunk: the five scene files self-register at load time, `CTLDSceneManager:_init`
logs as they do, and `ctld.utils.log` read a config setting before `ctld.initialize()` — which rc8's
new `getSetting` guard refuses. Full analysis and the upstream fix:
[VEAF/CTLD#144](https://github.com/VEAF/CTLD/pull/144).

Why it takes VEAF down with it is ours, not CTLD's. `_emit_trig_action_string`
([mission_builder_worker.py:385](../../src/python/veaf-tools/mission_builder/mission_builder_worker.py#L385))
emits the whole "VEAF scripts loading - static" trigger as **one concatenated Lua chunk**
(`a_do_script_file(k1);a_do_script_file(k2);…`), and CTLD sits third in the community list, ahead of
the VEAF framework. One raise aborts the chunk, so `veaf-scripts.lua` and `mission-script.lua` never
run. CTLD is opt-out, so it is on in every mission that has not said otherwise.

## Why nothing caught it here

`CHORE-VENDORED-DRIFT-618` verified rc8 with `assert(loadfile(...))` — **parse**, not run — and said
so plainly in its own PRD. This lot is what that honesty was pointing at: a syntax check cannot see
a main chunk that raises, and the VEAF Lua suite has no equivalent of `test_csar_init.lua` for CTLD.

That file is worth re-reading: it exists because two CSAR defects *"could not be seen from the tests
— one of them shipped and broke every mission until it was found in game."* Same shape, same cost,
a different community script.

## What changes

1. **Vendor CTLD `2.0.0-rc9`** — the upstream fix, released for this. Bump `pinned:` and the watch
   tag in `vendored.yaml`.
2. **A load gate**: `test/lua/test_community_scripts_load.lua` loads each vendored community script
   under Lua 5.1 with `dcs_mocks.lua` and fails if the main chunk raises. Measured against all seven
   before writing it — six load clean as-is, TUM is a documented exception (below).

## TUM is excluded, and here is exactly why

`TheUniversalMission.lua` raises on load with the mocks alone:

```
TheUniversalMission.lua:29967 'getTerritoryCenter' ← 29777 'create' ← 31486 ← 31490 main chunk
```

That is **not** a defect to fix. TUM auto-initializes unless told otherwise, and it requires
BLUFOR/REDFOR territory zones each owning an airbase — the contract that made it opt-in here in the
first place (`get_optin_community_script_ids`, DROP-MIST ticket 08). With no zones, `initialize()`
legitimately fails. It is `TUM: false` in the shipped `mission.yaml`, so no mission runs it unless it
asked for it and provided the zones.

Giving TUM a fixture with territory zones and airbases so it can be gated too is real work and its
own lot. It is listed in the test as an explicit, reasoned exclusion rather than silently skipped —
the point being that a reader can tell the difference between "not covered" and "covered and green".

## Definition of done

- `vendored.yaml` pins CTLD at `2.0.0-rc9`, watch tag `published-v2.0.0-rc9`;
  `poetry run check-vendored` reports 0 drifted; `test_vendored_pins_match_the_files.py` green.
- The new load gate is **red** against the vendored rc8 and **green** against rc9 — both observed,
  not assumed.
- `poetry run test-lua` green; Python quality gate green.
- `CHANGELOG.md` `[Unreleased]` entry appended at the end of the section.
- Released as **6.22.1**: 6.22.0 is published and every CTLD mission built with it is broken.

## Out of scope

- Changing how VEAF emits its loading trigger. Concatenating the script loads into one chunk is why
  one community script can take the framework down, and making each load independent (so a failing
  community script degrades instead of cascading) is a real improvement — but it changes the shipped
  trigger structure of every mission, which is not something to do inside a hotfix. Worth its own
  lot; raised for David.
- A fixture that lets TUM be gated (see above).
- Anything about the `getSetting` guard itself. It is correct and it found a real defect.
