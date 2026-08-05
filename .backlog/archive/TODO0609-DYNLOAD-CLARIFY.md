# Lot TODO0609-DYNLOAD-CLARIFY — Clarify dynamic script loading

Status: ✅ done

**Goal**: Understand and document the two dynamic-loading files — `VeafDynamicLoader.lua` (loads VEAF scripts) and `veafDynamicConfig.lua` (loads mission scripts) — determine whether one is obsolete, and clarify the overall static-vs-dynamic loading of VEAF scripts (including how `convert-v5` handles legacy v5 dynamic-loading triggers). Covers todo-2026.06.09 item 2.

**Branch**: `chore/dynload-clarify` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DYNLOAD-CLARIFY-001 (spike) | Trace and document both files' roles and the static/dynamic loading flow; identify any obsolete artifact and propose its removal; document the conversion behaviour for legacy dynamic-loading triggers. Deliverable: doc update + cleanup tickets if needed. | `src/defaults/mission-folder/src/scripts/veafDynamicConfig.lua`, `src/scripts/VeafDynamicLoader.lua`, `mission_builder/mission_builder_worker.py`, `doc/` | spike | ✅ |

**Spike result (DYNLOAD-CLARIFY-001)** — see [ADR 0004](../../docs/adr/0004-dynamic-script-loading.md):

- **Neither file is obsolete.** They are two layers of the same dynamic-loading mechanism: `VeafDynamicLoader.lua` (`src/scripts/`) loads the **VEAF framework** modules (`src/scripts/veaf/*.lua`) from `VEAF_DYNAMIC_SCRIPTSPATH`; `veafDynamicConfig.lua` (mission scaffold) loads the **mission's** scripts from `VEAF_DYNAMIC_MISSIONPATH`. Both are referenced by the build's injected triggers (3 and 5 respectively).
- **Loading flow**: the build injects six paired triggers (set-path ×2, dynamic/static for VEAF scripts, dynamic/static for mission scripts). Dynamic mode `loadfile`s from disk (dev/test, live iteration); static mode `a_do_script_file`s scripts embedded as `.miz` map resources (distribution) and bypasses both loader files.
- **No cleanup tickets** for these two files.
- **Deferred**: whether a legacy v5 mission's own VEAF loading triggers are removed during `build --migrate-from-v5` (the build prepends its six triggers and shifts existing ones up without inspecting them) is owned by **TODO0609-TRIGGERS-VERIFY**, not this spike.
