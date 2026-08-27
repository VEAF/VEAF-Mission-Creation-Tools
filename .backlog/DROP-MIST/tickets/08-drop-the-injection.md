# 08 — Drop the injection

Status: ⬜ ready — last, by construction
Type: refactor

The only ticket in the lot with a player-visible effect. Everything before it reduces the call count;
this one collects the gain.

## What it removes

| Where | What |
|---|---|
| [`mission_builder_worker.py:468`](../../../src/python/veaf-tools/mission_builder/mission_builder_worker.py) | `mist` out of `MANDATORY_COMMUNITY_SCRIPTS` |
| [`lua_config_generator.py:270`](../../../src/python/veaf-tools/veaf_libs/lua_config_generator.py) | the same frozenset, second copy |
| [`mission_constants.py:31`](../../../src/python/veaf-tools/mission_tools/mission_constants.py) | the `{"id": "mist", "path": "src/scripts/community/mist.lua"}` entry |
| `src/scripts/community/mist.lua` | deleted — 340 KB, 9 813 lines |
| `test/lua/dcs_mocks.lua` | the MiST mock, and the MiST references in the ~10 test files that carry them |

Two copies of the mandatory list is itself worth a note: they must be changed together, and a test
should fail if they drift. Check whether one can simply read the other.

## What the mission gains

- 340 KB out of every generated `.miz`
- the `mist.main` tick — re-armed every 0.01 s — stops existing, along with the 20 Hz walk over every
  unit in the mission that fed tables VEAF never read
- one fewer unmaintained dependency in the runtime

## The compatibility question this ticket must answer, not assume

**A mission maker's own scripts may call `mist.*`.** VEAF injects MiST into every mission today, so any
custom script loaded alongside ours has been able to rely on it for years. Removing the injection
silently breaks those missions, and they will fail at runtime in DCS with no build-time warning — the
exact shape of defect this repository has spent the last month closing.

Options to put to David rather than pick unilaterally:

1. **`modules.MIST.enabled: true` as an opt-in** — the mission maker who needs it asks for it. Keeps
   the file in the repository as an optional community script, which is what `mission_constants.py`
   already models for the others.
2. **Remove it outright** and announce it as a breaking change in `RELEASE_NOTES.md`, with the version
   bumped accordingly.
3. **Inject it only when a custom script references it** — a build-time grep. Cheap to implement, and
   it makes the common case free without breaking anyone.

Option 3 is the one worth measuring first: `validate` already reads custom scripts, so the hook may
exist. Option 1 is the safe default if it does not.

## Definition of done

- [ ] The compatibility question is settled by David and the choice recorded here
- [ ] `mist` removed from both mandatory lists, and a test fails if the two lists drift apart
- [ ] A generated mission carries no `mist.lua` — asserted by **unzipping the built `.miz`**, not by
      reading the yaml
- [ ] `src/scripts/community/mist.lua` deleted
- [ ] `test/lua/dcs_mocks.lua` no longer mocks MiST; the Lua suite passes and the coverage ratchet is
      raised
- [ ] `doc/` says MiST is no longer injected, in **both** languages, with the `nav` and
      `nav_translations` entries if a page is added; `poetry run docs-check` clean
- [ ] `RELEASE_NOTES.md` leads with the change if option 2 or 3 is chosen
- [ ] `CHANGELOG.md` entry under `[Unreleased]`, appended at the end of the section
