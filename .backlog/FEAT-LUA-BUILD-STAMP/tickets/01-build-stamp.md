# FEAT-LUA-BUILD-STAMP-001 — emit a single build stamp, retire per-module versions

Status: ✅ done
Type: feat
Files: `veaf_build/worker.py`, `veaf_libs/build_stamp.py`, `mission_builder_worker.py`,
`src/scripts/veaf/*.lua` (veaf.lua + 32 modules), tests, docs, CHANGELOG

## What to build

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

## Acceptance criteria

- [ ] Binary build writes `__commit__`; editable install resolves sha via git, else "dev"
- [ ] Generated VEAF triggers carry a `VEAF_BUILD_VERSION` action (trig + trigrules)
- [ ] `veaf.lua` logs `6.7.x+<sha>` once; modules log a numberless "loaded" line
- [ ] `veaf.BuildVersion` falls back to `"dev"` when the global is absent
- [ ] Python + Lua tests green; ruff/mypy/stylua clean; CHANGELOG + version bump
