# Lot FEAT-EXPORT-MISSION — safe `.miz` export (JSON / YAML / Markdown) for interop & the BFR plugin

Status: ✅ done

**Context**: Dup (Bullseye Francophone) built a Claude plugin — `dcs-mission-tools` ([bfr-claude-plugins](https://github.com/Bullseye-Francophone/bfr-claude-plugins)) — that lints/explains DCS missions built on the VEAF template. To read the `.miz` it **bundles and runs `lua54.exe`** (a Lua 5.4 interpreter) over the `mission` file. A `.miz` is an **unsigned ZIP**, and its `mission` file is *data* (`mission = {…}`) — but a forged `.miz` can embed arbitrary Lua (`os.execute`, `io`, `require`) that `lua54.exe` would **execute** → **RCE** when analyzing an untrusted mission. This is exactly the SECREV-001 class of bug we removed from veaf-tools (dropped `lupa`, switched to the pure-Python `luadata` state-machine parser — see `luadata/serializer/unserialize.py:433`, "replaces `lua.execute` which would run arbitrary code").

**Goal**: A new `veaf-tools export` command that reads a `.miz` with our **pure-Python** parser (`miz_tools` already loads `mission` / `dictionary` / `mapResource` / `theatre` via `luadata.unserialize`, **never executing Lua**) and writes it in interoperable formats — giving the plugin (and anyone) a safe drop-in alternative to `lua54.exe`. Default **JSON** (machine pivot, Claude-native, faithful array/dict mapping); also **YAML** (readable); also **Markdown** (human-friendly summary). Align the JSON schema with the plugin's "project object" (`mission`, `dictionary`, `mapResource`, `l10nFiles`, `scriptFiles`/`scriptText`, `communityScripts`) so it's a drop-in. **Coordinate the schema with Dup before coding** (send him the risk write-up + proposed schema).

**Security invariant (the whole point)**: the export path must **never** execute Lua — only `luadata` parsing. A test should assert no `lua`/`subprocess`/`exec` is involved.

**Branch**: `feature/export-mission` → PR → `develop-v6`.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-EXPORT-MISSION-001 | `veaf-tools export <miz> [output] --format json` (default): parse the `.miz` with `luadata` (no Lua exec) and emit one JSON object `{mission, dictionary, mapResource, theatre, …}` aligned with the plugin's project schema. `--compact`/`--indent`. Add the command to the TUI (`CommandSpec`, per FIX-TUI-MISSING-COMMANDS guard). pytest on a small real `.miz`. | `veaf_tools/commands/export.py`, `mission_tools/`, `veaf_libs/tui.py`, `test/python/` | feat | ✅ (#516) |
| FEAT-EXPORT-MISSION-002 | `--format yaml`: same structured content emitted as YAML (PyYAML, already a dep). Round-trip/shape test. | `veaf_tools/commands/export.py`, `test/python/` | feat | ✅ (#516) |
| FEAT-EXPORT-MISSION-003 | `--format markdown`: a human-friendly mission summary (identity/weather/time, order of battle per coalition, trigger zones, user vs VEAF triggers, loaded scripts, kneeboards) — overlaps the plugin's `map-mission` view. Pure formatting over the parsed dict. | `veaf_tools/commands/export.py`, `test/python/` | feat | ✅ (#516) |
| FEAT-EXPORT-MISSION-004 | Security guard test: the export path performs **no** Lua execution (no `lua54`/`subprocess`/`exec`/`eval`), only `luadata` parsing. Document the safety guarantee in `doc/`. | `test/python/`, `doc/` | test | ✅ (#516) |
