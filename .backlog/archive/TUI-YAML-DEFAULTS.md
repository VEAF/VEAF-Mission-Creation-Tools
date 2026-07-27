# Lot TUI-YAML-DEFAULTS — TUI defaults aware of an existing mission.yaml

Status: ✅ done

**Goal**: When `veaf-tools` is launched in TUI mode, the proposed argument defaults are currently static (`mission.miz`, `.`, …) or the last saved value. They ignore a `mission.yaml` present in the working directory. The wizard should detect an existing `mission.yaml` and derive smarter defaults from it — at least for the mission name prompt.

**Branch**: `feat/tui-yaml-defaults` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TUI-YAML-DEFAULTS-001 | When a `mission.yaml` exists in the working directory, the TUI derives the default for the `mission_name_or_file` prompt from its `mission.name` field instead of the static `mission.miz`. The `mission:` block already exists in the schema (`mission.name` → `veaf.config.MISSION_NAME`, emitted by `convert-v5` and read by `lua_config_generator`); reuse it as the source of truth. | `veaf_libs/tui.py`, `test/python/` | feat | ✅ |
| TUI-YAML-DEFAULTS-002 | Establish the default-resolution precedence and make it explicit: last saved preference > value derived from `mission.yaml` (`mission.name`) > static fallback (decide whether a saved preference should override a detected `mission.yaml` or the reverse). Cover with unit tests. | `veaf_libs/tui.py`, `veaf_libs/preferences.py`, `test/python/` | feat | ✅ |
| TUI-YAML-DEFAULTS-003 | Extend the `mission.yaml`-aware defaults to the other relevant prompts where it makes sense (e.g. `mission_folder`, `mission.export_path`, presets/template file paths) once the mechanism from -001/-002 is in place. | `veaf_libs/tui.py`, `test/python/` | feat | ✅ |

> Note: the `mission:` identity block already exists in the `mission.yaml` schema (`name`, `era`, `export_path`, `language`). `mission.name` (e.g. `Training-Syrie`) is the runtime mission name; it is the natural source for the mission-name prompt default. No new schema key is required.

> Resolution: precedence is **last saved preference > `mission.yaml` (`mission.name`) > static fallback** — a saved value the user explicitly typed last run wins over the detected file. Implemented as two pure helpers in `veaf_libs/tui.py` (`_mission_yaml_defaults`, `_resolve_prompt_default`) wired into `run_wizard`. For -003, `mission.name` is the only `mission.yaml` field that maps to an existing prompt (the other prompts — `mission_folder`, presets/template paths — have no `mission.yaml` source); the mechanism is generic (keyed by prompt name) so future fields are a one-line addition.
