# Lot FIX-BUILD-BARE-NAME-PATH — `build` with a bare mission name produces a relative output path

Status: ✅ done

**Goal**: Running `build` with a bare mission name (instead of a `.miz` file or the default `mission.miz`) left the output mission as a path *relative to the current directory*. The weather step resolves a relative mission path against `versions.yaml`'s parent (`<folder>/src`), so it looked for `<folder>/src/<name>.miz` and aborted with `Base mission not found`. The bug surfaced through the TUI because the mission.yaml-aware default (lot TUI-YAML-DEFAULTS) now pre-fills the real mission name, taking this code path instead of the `== DEFAULT_MISSION_FILE` branch that anchored the path in the mission folder.

**Branch**: `fix/build-bare-name-path` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-BUILD-BARE-NAME-PATH-001 | Extract output-mission resolution into a testable `_resolve_output_mission` helper that anchors a bare-name `.miz` in the mission folder (absolute) and sanitizes the name, unifying the explicit-name and default+`mission.yaml` paths. Add unit tests covering: default+no yaml, default+yaml name, explicit bare name (regression), explicit `.miz`, unsafe-character sanitization. | `veaf_tools/commands/build.py`, `test/python/` | fix | ✅ |
