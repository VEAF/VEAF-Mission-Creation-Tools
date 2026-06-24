# Lot TODO0609-AIRCRAFT-INJECT — Split aircraft-group injection (spawnable vs dynamic-slot template)

Status: ✅ done

**Goal**: Restore the historically-distinct handling of two separate uses of injected aircraft groups that was half-lost in the Python rewrite: **(B) spawnable aircraft groups** cloned at runtime by `veafSpawn` (name prefix `veafSpawn-`) and **(C) dynamic-slot templates** consumed natively by DCS (`dynSpawnTemplate == true`). Two separate, independently-configurable pipeline steps; reliable flag/prefix-based sorting. Source: `HANDOFF-aircraft-groups-injection.md`. This is the analysis behind todo-2026.06.09 item 12 (the defaults files are legitimate and kept; `spawnables.yaml` "doesn't serve" because no step injects it — a pipeline bug).

**Frozen decisions** (see `CONTEXT.md` and `docs/adr/0002-aircraft-group-injection-sort-criteria.md`): two distinct features sharing one extract/inject tool; sort by `dynSpawnTemplate` flag (priority) then `veafSpawn-` prefix, else ignore; **drop the legacy `.*[tT]emplate.*` name sort** (root cause of the historical misrouting bug).

**Branch**: `feat/aircraft-inject` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| AIRCRAFT-INJECT-001 | Replace the single `aircraft_groups` pipeline step with two: `spawnable_aircrafts` (→ `src/spawnables.yaml`) and `dynamic_slot_templates` (→ `src/dynamic-slot-templates.yaml`), each independently configurable (`true/false` or `{enabled, file, mode}`). Hard break: old step + `aircraft-templates.yaml`/`templates.yaml` names dropped (legacy-file warning kept). | `veaf_tools/commands/build.py`, `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ |
| AIRCRAFT-INJECT-002 | Keep both default files in `src/defaults/mission-folder/src/` — `spawnables.yaml` (B) and `dynamic-slot-templates.yaml` (C, renamed from `templates.yaml`); update the defaults mapping + tests. Removed the now-dead `lua_module` defaults-copy branch. | `src/defaults/mission-folder/src/`, `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ |
| AIRCRAFT-INJECT-003 | Flag/prefix sort in the extractor via shared `classify_aircraft_group` (route each group to B or C, ignore the rest); one pass emits both files by default, `--kind` restricts. Helicopters indentation bug was already fixed by SECREV-002 (no double-fix needed). | `aircrafts_injector/aircrafts_injector_worker.py`, `test/python/` | fix | ✅ |
| AIRCRAFT-INJECT-004 | Two injection steps, each injecting its file as-is (no name regex); `add`/`replace` mode per step. | `aircrafts_injector/aircrafts_injector_worker.py`, `veaf_tools/commands/build.py`, `test/python/` | feat | ✅ |
| AIRCRAFT-INJECT-005 | `convert-v5`: produces **both** v6 files from the v5 `settings.lua`, applying the same flag/prefix sort; updated `V5_PIPELINE_CANDIDATES` / `V6_PIPELINE_CANDIDATES`. | `mission_builder/v5_pipeline_converters.py`, `mission_builder/v5_converter.py`, `test/python/` | feat | ✅ |
| AIRCRAFT-INJECT-006 | Cleanup: fixed the dead `.vscode/launch.json` reference; realigned `doc/mission-maker/scripts/veafSpawn.md` (+ `.en`), `doc/MISSION_YAML_REFERENCE*.md`, `doc/PIPELINE_REFERENCE*.md` on the real schema + the B/C distinction. | `.vscode/launch.json`, `doc/` | chore | ✅ |

**Open questions — settled with David (2026-06-11)**: (1) (C) file → **`dynamic-slot-templates.yaml`**; (2) step names → **`spawnable_aircrafts`** + **`dynamic_slot_templates`**; (3) **hard break** (old step/names dropped, ADR 0001 precedent); (4) extraction → **one pass writes both files by default**, `--kind spawnable|dynamic-template` restricts to one; (5) warehouse wiring → **separate lot DYNSLOT-WAREHOUSE** (handoff §5, deferred).

**Field feedback integrated** (IMC-Day 2026-06-10, tested on 6.4.0 — `tests-mct6-imcday(3).md` §8):
- The orphan warning (FIX-AIRCRAFT-ORPHAN) flagged `aircraft-templates.yaml` while the step actually consumed `templates.yaml` — the split removes that mismatch; pre-v6 names now emit a clear "ignored, use the new files" migration message (param-ized by file). Residual `aircraft-templates.yaml` references purged from `build.py` message, `lua_config_generator` comment, TUI, and the injector/extractor READMEs.
- Deleted defaults silently reappeared: confirmed `complete_src_folder_with_defaults` logs `builder.copied_from_defaults` on every recopy, and skips when the step is disabled (regression test added).
- `spawnables.yaml` was copied but injected by no step (the lot's root motivation): the `spawnable_aircrafts` step now consumes it — acceptance test asserts `resolve_pipeline_step_file` wires `src/spawnables.yaml`.
- Fixed a TUI regression introduced mid-lot: `extract-aircraft-groups` no longer passes the removed `--output-yaml` (now `--kind`); `inject-aircraft-groups` defaults to `src/spawnables.yaml`.
