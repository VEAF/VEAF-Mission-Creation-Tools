# FIX-CTLD-RC9-LOAD-GATE — CTLD rc8 kills every radio menu; vendor rc9 and gate the loading

Status: ✅ done · archived 2026-09-28

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

All of the above is met. Shipped in **6.22.1** (2026-09-12), PR #958 + release PR #959; upstream
VEAF/CTLD#144 released as `2.0.0-rc9`. Issue #957 answered and closed.

The one item that is **not** claimed: nobody has flown a mission built from this. The gate proves the
file loads outside DCS — which is the failure that was reported — and CTLD's CI proves the same on
every build, but an in-game check is still worth doing when convenient.

## Out of scope

- Changing how VEAF emits its loading trigger. Concatenating the script loads into one chunk is why
  one community script can take the framework down, and making each load independent (so a failing
  community script degrades instead of cascading) is a real improvement — but it changes the shipped
  trigger structure of every mission, which is not something to do inside a hotfix. Worth its own
  lot; raised for David.
- A fixture that lets TUM be gated (see above).
- Anything about the `getSetting` guard itself. It is correct and it found a real defect.

---

## Tickets, in full

## 01 — vendor CTLD rc9 and gate the community-script load

Status: ✅ done

See the PRD for the root cause and why the whole VEAF framework goes down with CTLD.

### What changes

1. **`src/scripts/community/CTLD.lua`** — replace with the `CTLD.lua` asset from the
   [`published-v2.0.0-rc9`](https://github.com/VEAF/CTLD/releases/tag/published-v2.0.0-rc9) release.
   Verbatim vendoring: download the asset, do not hand-edit, do not rebuild locally.
2. **`vendored.yaml`**, `ctld` entry: `pinned: "2.0.0-rc9"` and the watch's
   `pinned: "published-v2.0.0-rc9"`.
3. **`test/lua/test_community_scripts_load.lua`** — new. Loads each vendored community script with
   `dcs_mocks.lua` and fails if the main chunk raises.
4. **`CHANGELOG.md`** `[Unreleased]`, appended at the **end** of the section.

### Watch out

- **Do not rebuild `CTLD.lua` from the CTLD sources.** The manifest says `vendoring: verbatim`, and
  `test_vendored_pins_match_the_files.py` compares `ctld.VERSION` in the file against `pinned:` — a
  locally built file can carry the right version and still differ from the published asset.
- **One test per script, not a loop.** A loop stops at the first raise and the report names the
  loop; seven named tests name the culprit.
- **TUM stays out, explicitly.** It raises on load without territory zones, which is its documented
  contract and the reason it is opt-in. Written into the test file as a reasoned exclusion with the
  measured traceback — never a silent skip. See the PRD.
- The scripts load into **one** Lua state, in one process (`veaf_build/lua_tests.py` runs each
  `test_*.lua` in its own subprocess, so there is no bleed into the other suites). That is the
  faithful shape: a mission loads them all into one state too.
- Do not bump the version anywhere (`pyproject.toml`, the two plugin manifests) — §9.5.

### Acceptance

- The new test is **red** against the currently vendored rc8, with the production traceback in the
  failure message, and **green** after the rc9 file is dropped in. Both observed.
- `poetry run test-lua` green.
- `poetry run check-vendored` reports 0 drifted; `test_vendored_pins_match_the_files.py` green.
- Python quality gate green (`ruff check` + `ruff format --check` + `mypy`).
- A mission built from this branch with CTLD enabled shows the VEAF radio menu again — **needs
  DCS**, see below.

### Tests

`test/lua/test_community_scripts_load.lua`, as above. Already verified red against rc8:

```
Ran 7 tests in 0.038 seconds, 6 successes, 1 failure
  TestCommunityScriptsLoad.test_ctld_loads — CTLD.lua must load without raising:
    CTLD configuration is not loaded — call ctld.initialize() before …
```

Note the other six pass against the current pins, so the gate is measuring something real from day
one rather than being green by construction.

### Needs DCS

The end-to-end confirmation — build a mission, fly it, see the F10 menu — cannot be done from a
workstation without the game. The Lua gate proves the file loads outside DCS, which is exactly the
failure that was reported, and CTLD's own CI now proves the same on every build. Worth one in-game
check when convenient; not a blocker for shipping 6.22.1, since 6.22.0 is broken for everyone right
now and this restores the rc7 behaviour plus the upstream fix.

---
