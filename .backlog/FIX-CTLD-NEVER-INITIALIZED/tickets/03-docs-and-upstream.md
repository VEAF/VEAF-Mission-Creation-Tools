# 03 — Documentation, stale comments, and the upstream report

Status: ✅ done 2026-08-16 — docs, stale comments and ADR corrected; upstream filed as VEAF/CTLD#125
Type: docs
Files: `docs/adr/0016-ctld2-sidecar-configuration.md`, `src/python/veaf-tools/veaf_libs/lua_config_generator.py`,
`src/python/veaf-tools/mission_builder/config_migrator.py`, `doc/` CTLD pages, `CHANGELOG.md`

## The stale claims to correct

Two comments in the code state, as fact, something that was never true after
FEAT-CTLD2-INTEGRATION. Both were read during this investigation and both sent it the wrong way for
a while, so they get corrected with the fix, not later:

- `lua_config_generator.py:1578` — *"started by `veaf.lua`"*. `veaf.lua` **registers** CTLD; the
  generated file is what starts it. Replace the comment with a pointer to the emitted block.
- `config_migrator.py:490` — *"`veaf.initialize()` in veaf-config.lua calls all module init
  functions"*. The generated file never calls `veaf.initialize()`. The migrator's behaviour (dropping
  a duplicate init call) is right; only its stated reason is wrong.

ADR 0016 says *"`veaf.lua` installs the log routing and then calls `ctld.initialize()`"*. True of the
function, silent on what calls the function — add the missing link so the ADR describes the whole
chain.

## Documentation

The CTLD pages in `doc/` (both languages) get the rebuild instruction: a mission built with
veaf-tools ≤ 6.14.0 has no CTLD start-up call and must be rebuilt, or carry the one-line workaround
in its `mission-script.lua`.

## Upstream

Report to [VEAF/CTLD](https://github.com/VEAF/CTLD): `CTLDZoneManager:_scheduleSmoke` reads
`ctld.gs("smokeRefreshInterval")` and does arithmetic on it with no check, so any call reaching a
manager before `ctld.initialize()` dies on `CTLD.lua:9109` with a message naming neither CTLD nor the
missing initialisation. A guard in `getInstance()` — or a default interval — turns a stack trace into
a diagnosis. Include the log excerpt from the PRD.

## Done when

`poetry run docs-check` passes, no comment in the repo still claims `veaf.initialize()` starts the
generated modules, and the upstream issue is filed (link recorded here).

Filed as **[VEAF/CTLD#125](https://github.com/VEAF/CTLD/issues/125)**. It argues for a guard in
`getInstance()` rather than a default for `smokeRefreshInterval`: a default would let a wholly
unconfigured engine run on implicit values, which is worse than a refusal naming
`ctld.initialize()`. It also notes that `_scheduleSmoke` is merely the **first** setting read on that
path — every `ctld.gs(...)` consumer has the same exposure, so the entry point is the useful place to
fix it.
