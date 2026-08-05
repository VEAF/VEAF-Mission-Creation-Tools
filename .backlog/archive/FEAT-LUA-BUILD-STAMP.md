# Lot FEAT-LUA-BUILD-STAMP — single build stamp in the DCS log instead of per-module versions

Status: ✅ done
Branch: feature/lua-build-stamp → PR #543 → merged into develop

## Problem Statement

The DCS runtime log shows a constellation of hand-maintained per-module Lua versions
(`VEAF-QRA 1.2.5`, `VEAF 1.57.0`, … 33 of them) that **do not map to any release** and
that nobody can rely on: the #299 QRA fix (PR #538) shipped **without bumping**
`veafQraManager.Version`, so `1.2.5` is identical before and after the fix. Given only
a tester's log we **cannot tell which code is actually running** — exactly the blind
spot that bit us while triaging Tripack's QRA report.

## Solution

Log a **single build stamp** — the veaf-tools package version **plus the git commit
short SHA** that built the mission — `6.7.x+<sha>`. The SHA is what disambiguates the
dev builds testers run *between* releases (where the package version alone is constant).

- The SHA is captured when the **veaf-tools binary is packaged** (`veaf-build`), not at
  mission-build time: testers build their `.miz` with the standalone binary, with no git
  repo around it.
- The mission build injects the stamp into the framework load sequence as a Lua global
  (`VEAF_BUILD_VERSION`), read by `veaf.lua` into `veaf.BuildVersion`.
- Per-module `.Version` constants are **removed** (32 hand-maintained SemVers; `dcsUnits`
  keeps its auto-generated `datamine-<ref>` provenance line, which is accurate, not stale);
  each module keeps a numberless "loaded" log line (load order stays visible for runtime
  debugging); the build stamp is logged once by `veaf.lua`.
- Fallback `"dev"` when the stamp is absent (hand-copied scripts, Lua unit tests).

## User Stories

1. As a maintainer triaging a tester's log, I want one stamp `6.7.x+<sha>` so I can tell
   immediately whether a given fix-commit is in their build.

## Implementation Decisions

- Stamp format: `<package version>+<git short sha>` (compact), e.g. `6.7.3+5815cbab`.
  Falls back to the bare version when no SHA, and to `"dev"` at runtime when no stamp.
- SHA captured in `veaf_build/worker.py` (binary packaging) → `__commit__` in `_version.py`.
- Stamp resolved by a single helper `veaf_libs/build_stamp.py` (`get_build_stamp()`),
  reused by the mission builder. Runtime fallback to `git rev-parse` for editable installs.
- Injection point: a `VEAF_BUILD_VERSION = "<stamp>"` `LuaAction` prepended to the
  framework-load triggers in `_build_veaf_trigger_specs` (single source of truth for both
  trig and trigrules forms; works in DEV and PROD load modes; no new script/mapResource/dict).
- Per-module log line transform is mechanical (31 identical call sites).

## Out of Scope

- The QRA bug itself (FIX-DYNSLOT-TEMPLATE-CATEGORY-002 still waits on a clean repro);
  this lot makes that repro *diagnosable* but does not change QRA logic.

## Testing Decisions

- Python: `worker` writes `__commit__`; `get_build_stamp()` resolves version+sha and
  falls back correctly; the generated VEAF triggers contain a `VEAF_BUILD_VERSION` action.
- Lua: `getVersionInfo()` with no arg returns the numberless "loaded" form;
  `veaf.BuildVersion` falls back to `"dev"` when `VEAF_BUILD_VERSION` is absent.

---

## FEAT-LUA-BUILD-STAMP-001 — emit a single build stamp, retire per-module versions

Status: ✅ done
Type: feat
Files: `veaf_build/worker.py`, `veaf_libs/build_stamp.py`, `mission_builder_worker.py`,
`src/scripts/veaf/*.lua` (veaf.lua + 32 modules), tests, docs, CHANGELOG

### What to build

1. `veaf_build/worker.py`: capture `git rev-parse --short HEAD` at binary packaging and
   write `__commit__` into the generated `_version.py` (stub gets `__commit__ = ""`).
2. `veaf_libs/build_stamp.py`: `get_build_stamp()` → `"<version>+<sha>"` (or bare version
   when no sha); resolves sha from `_version.__commit__`, else runtime `git`, else "".
3. `mission_builder_worker._build_veaf_trigger_specs`: prepend
   `VEAF_BUILD_VERSION = "<stamp>"` to the dynamic and static framework-load triggers.
4. `veaf.lua`: `veaf.BuildVersion = VEAF_BUILD_VERSION or "dev"`; log it once at load;
   `getVersionInfo()` with no arg returns the numberless "loaded" form.
5. Remove the 33 `*.Version` constants; rewrite the 31 uniform per-module log lines to the
   numberless form.

### Acceptance criteria

- [ ] Binary build writes `__commit__`; editable install resolves sha via git, else "dev"
- [ ] Generated VEAF triggers carry a `VEAF_BUILD_VERSION` action (trig + trigrules)
- [ ] `veaf.lua` logs `6.7.x+<sha>` once; modules log a numberless "loaded" line
- [ ] `veaf.BuildVersion` falls back to `"dev"` when the global is absent
- [ ] Python + Lua tests green; ruff/mypy/stylua clean; CHANGELOG + version bump
