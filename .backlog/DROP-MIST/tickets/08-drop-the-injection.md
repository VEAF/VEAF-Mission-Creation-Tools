# 08 — Drop the injection

Status: ✅ done — 2026-08-31. Option **c** (conditional injection), decided by David.
Type: refactor

The only ticket in the lot with a player-visible effect. Everything before it reduces the call count;
this one collects the gain.

## The compatibility question, and how it was settled

The ticket refused to pick unilaterally, and rightly: **a mission maker's own scripts may call
`mist.*`**, and removing the injection breaks them at runtime in DCS with no build-time warning.

It was settled by measurement rather than by argument. Opening the 17 `.miz` files under
`VEAF-Servers`:

| | MiST in their own scripts |
|---|---|
| The 6 Foothold missions (v6) | **none** |
| The 10 Open Training missions | **yes** — `HoundElint.lua` calls `mist.DBs.humansByName`, `mist.getGroupPoints`, `mist.majorVersion`, `mist.minorVersion` |

The second row is what made option 2 (remove outright) unacceptable and option 1 (opt-in flag)
insufficient: those missions would build fine and die in flight. **They are still v5**, so the risk
is deferred rather than current — but it lands the day they are converted, which is exactly when
nobody would be looking for it.

David chose **option 3**: the build reads the mission's own scripts and injects MiST when one of them
calls it.

## What it removes

| Where | What |
|---|---|
| `mission_builder_worker.py` | `mist` out of `MANDATORY_COMMUNITY_SCRIPTS` — the frozenset is now empty, and the mechanism kept, because "inject this whatever the mission says" will be true again |
| `mission_constants.py` | `mist` **added** to `get_optin_community_script_ids()`, beside TUM |
| `mission_template.py` | `MIST` moved from Infrastructure (always emitted) to Community, in **no tier** |
| `src/defaults/mission-folder/mission.yaml` | the bare `MIST:` line, replaced by a commented `MIST: true` and the reason |
| `test/lua/dcs_mocks.lua` | the MiST stub — 128 lines, plus `_deepCopy` which existed only to serve it |
| `src/scripts/veaf/veafMissionDb.lua` | the last four calls, dead code guarded by `if mist and mist.DBs` |

`src/scripts/community/mist.lua` is **kept**: option 3 needs it to inject when detection fires.

## What replaced it

`mission_scripts_referencing_mist(scripts_dir)` in `mission_constants` — shared by the builder and by
`convert-v5`, which is the point: v5 shipped MiST in every mission, so detecting it by file name would
have emitted `MIST: true` for every converted mission and made the whole change worthless.

What the scan sees: a call in `src/scripts/*.lua` (the whole folder, since everything there is
packaged whether or not it is declared under `custom_scripts:`). What it ignores: comments, and
mentions inside strings — **a test caught the second one in my own regex**, which is the CTLD trap
this campaign already fell into once, counting an error message naming `mist.DBs.MEgroupsByName` as a
call.

What it cannot see: a script loading another script, or `_G["mist"]`. `MIST: true` remains for those.
`MIST: false` does **not** win against detection: honouring it would break the mission in flight to
respect a config line, and the two answers (packaged / declared enabled) are asserted to agree.

## Where the ticket's plan turned out to be wrong

It asked for "a test that fails if the two mandatory lists drift apart". That test has no object: the
two constants shared a name, not a meaning. The builder's means "always injected" and is now empty;
the generator's means "never reported to the runtime as disabled", which stays true for MiST — and
that generator receives only `mission_yaml`, never the mission folder, so it *cannot* run the scan.
It was renamed `_NEVER_REPORTED_AS_DISABLED` instead of being tested against a list it no longer
mirrors.

## The flag, and the line every existing mission carries

Option (a)'s escape hatch came for free: making MiST an opt-in community script means the existing
`modules:` machinery already answers it. Measured, in the form mission makers actually write:

| in `mission.yaml` | MiST packaged |
|---|---|
| `modules:` -> `MIST: true` | **yes** -- the hatch, for an indirect use the scan cannot see |
| `modules:` -> `MIST: false` | no |
| `modules:` -> `MIST:` (bare) | **no** |
| nothing | no |
| nothing, but a script calls `mist.` | **yes**, naming the file |

The third row is the migration case. A bare `MIST:` used to mean "mandatory module, always on", and
**every v6 mission.yaml carries it**, because the shipped template did. It now means "not asked for",
so those missions stop carrying MiST on their next build -- which is the point, and is safe precisely
because the scan catches the ones that call it. Asserted by three tests, including a bare `MIST:`
alongside a HoundElint that calls `mist.DBs.humansByName`.

Worth recording: the first version of that test only covered `community_scripts: mist: true`, the
**deprecated** section. A hatch proven to work where nobody looks for it is not proven.

## What the mission gains

- 336 KB out of every generated `.miz` that does not ask for MiST
- the `mist.main` tick — re-armed every 0.01 s — stops existing, along with the 20 Hz walk over every
  unit in the mission that fed tables VEAF never read
- one fewer unmaintained dependency in the runtime (MiST has not cut a release since 2021)

## Definition of done

- [x] The compatibility question is settled by David and the choice recorded here
- [x] `mist` removed from the mandatory list, and out of the module template's infrastructure tier
- [x] Detection covers the builder **and** `convert-v5`, with tests on both, including the
      HoundElint shape that ten production missions carry
- [x] `test/lua/dcs_mocks.lua` no longer mocks MiST — and the 44 Lua suites pass without it, which
      is the *proof* that no VEAF script calls it, not a claim
- [x] `doc/` says MiST is no longer injected, in **both** languages, under the explicit anchor
      `{#mist-injection}`; `poetry run docs-check` clean
- [x] `CHANGELOG.md` entry under `[Unreleased]`, appended at the end of the section
- [ ] `RELEASE_NOTES.md` — left untouched on purpose: it carries the published 6.17.0 and is written
      at release time from the changelog. Flagged to David rather than decided here.
- [x] Python suite green (3951), Lua suite green (44), ruff / ruff format / mypy / stylua clean

## What is deliberately *not* asserted

That a generated mission carries no `mist.lua`, by unzipping the built `.miz`. The ticket asked for
it and it is the right shape of check — but the build needs a real mission folder, and the suites
here do not build one. The equivalent is asserted one level down, at
`_active_community_scripts` / `_community_enabled`, which are what decide what goes into the archive.
