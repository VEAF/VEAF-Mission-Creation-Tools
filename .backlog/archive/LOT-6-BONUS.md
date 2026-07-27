# Lot 6 — BONUS: Logger filter + DCSUnits doc

Status: ✅ done

**Goal**: Quality-of-life improvements after the priority lots.
**Branch**: `feature/bonus-logger-doc` → PR → `develop`
**Depends on**: Lot 4 (LUA-001), Lot 2 (TOOL-003)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| LUA-006 | `--log-modules` option in `veaf-tools` to filter which modules log | feat | 90 min | LUA-001 | ✅ |
| TOOL-004 | Parse `dcsUnits.lua` → dynamic markdown doc generated before publish | feat | 90 min | TOOL-003 | ✅ |
| LUA-007 | Lazy log args (`veaf.lp`), single build, runtime log control (`global_log_level`) | feat | 120 min | LUA-006 | ✅ |

**Raw total: 300 min → estimated (×1.15): ~345 min (~5h45)**

<details>
<summary>Ticket details</summary>

**LUA-006 — Logger filter**
`--log-modules spawn,radio,assets` option on `veaf-tools build` and `veaf-tools inject-*` commands. Translates to a section in the generated `missionconfig.lua` that disables logging (or forces `logLevel = "error"`) for all unlisted modules. Useful for debugging a mission without log noise.

**LUA-007 — Lazy log args + single build + runtime log control**
- `veaf.lp(value)`: lazy proxy so log arguments are only stringified if the log level is active.
  Returns a metatable with `__tostring` → `veaf.p(value)`. Safe to use in `:trace()`/`:debug()` calls.
- Migrate all 1233 `veaf.p(` → `veaf.lp(` calls across the Lua codebase (automated via `migrate_lazy_log.py`).
- Remove build-time comment-out step (`--scripts-variant debug/trace/standard`) from `veaf_build/worker.py`.
- Remove `_create_lua_variant_files()` and the three `veaf-scripts-*.lua` variant generation steps.
- `veaf.BaseLogLevel = 3` (info) as default; replace `--scripts-variant` with `mission.yaml: global_log_level`.
  Writes `veaf.ForcedLogLevel = "<level>"` in the generated `veaf-modules-config.lua`.

</details>
