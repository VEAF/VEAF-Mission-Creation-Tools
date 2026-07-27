# Lot 11 — I18N: Internationalisation (EN + FR)

Status: ✅ done

**Goal**: Auto-detect the user's language (OS locale or `--lang` flag) and deliver the full experience in that language: CLI output, generated file comments, and documentation. Ship EN and FR as first-class citizens.
**Branch**: `feature/i18n` → PR → `develop`
**Depends on**: Lot 10 (generated-file comment strings stabilised)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| I18N-001 | i18n infrastructure: OS locale auto-detection + `--lang` CLI override, translation catalog loader (`veaf_libs/i18n.py`), `t()` helper | feat | 60 min | — | ✅ |
| I18N-002 | Translate all user-visible CLI messages (typer help strings, Rich output, logger messages) — EN catalog first, FR translation | feat | 120 min | I18N-001 | ✅ |
| I18N-003 | Translate comments in generated files (`veaf-config.lua`, `mission.yaml` template, `mission-script.lua` stub, `generate-config` output) | feat | 60 min | I18N-001, Lot 10 | ✅ |
| I18N-004 | Translate `MISSION_MAKER_GUIDE.md` → `doc/fr/MISSION_MAKER_GUIDE.md` (FR version maintained alongside EN) | chore | 90 min | — | ✅ |
| I18N-005 | `convert-v5` report output in detected language (scan table headers, action descriptions, warning messages) | feat | 45 min | I18N-002 | ✅ |
| I18N-006 | `mission.yaml` `language:` field → emit `veaf.config.language` in Lua; translate `generate-config` YAML template comments | feat | 45 min | I18N-001, I18N-003 | ✅ |
| I18N-007 | Full bilingual doc structure: FR translations of all doc guides (`pilot/fr/GUIDE.md`, `developer/fr/GUIDE.md`, `mission-maker/fr/scripts/*.md`), bilingual README headers, `--lang --help` pre-parse fix | chore | 120 min | I18N-004 | ✅ |

**Raw total: 540 min → estimated (×1.15): ~621 min (~10h21)**

<details>
<summary>Ticket details</summary>

**I18N-001 — Infrastructure**
`veaf_libs/i18n.py`:
- At startup, detect language: read `--lang` CLI option (passed as a global typer callback) → fall back to `locale.getdefaultlocale()[0]` (e.g. `"fr_FR"` → `"fr"`) → fall back to `"en"`.
- Load the matching catalog from `veaf_libs/locales/<lang>.json` (plain dict of `key → string`). Fall back to `en.json` if the requested locale has no catalog.
- Expose `t(key: str, **kwargs) -> str`: looks up the key, formats with `kwargs` via `str.format_map`. Missing key returns the key itself (never crashes).
- Ship `veaf_libs/locales/en.json` (authoritative) and `veaf_libs/locales/fr.json` (FR translation).
- PyInstaller spec: include `veaf_libs/locales/` as data files.

**I18N-002 — CLI messages**
Convert all hard-coded user-visible strings in `veaf-tools.py`, `mission_builder/`, `weather_injector/`, `aircrafts_injector/`, `waypoints_injector/` etc. to `t("key")` calls. Strings that are internal log messages (debug/trace) stay as-is — only INFO/WARNING/ERROR messages visible in normal use are translated.
Catalog keys follow the pattern `<module>.<context>.<id>`, e.g. `build.start`, `convert_v5.no_mission_yaml`, `weather.clearsky_applied`.

**I18N-003 — Generated file comments**
`lua_config_generator.py` and `generate-config` command currently emit English inline comments. Extract these strings into the catalog. At generation time, call `t(key)` to emit comments in the active language.
Scope: section headers and field description comments in `veaf-config.lua`; every `# …` comment line in the `mission.yaml` template output.

**I18N-004 — FR documentation**
Create `doc/fr/MISSION_MAKER_GUIDE.md` as a full FR translation of `doc/MISSION_MAKER_GUIDE.md`. Maintain both files — a note at the top of each links to the other language. No automated sync: manual update on structural changes.

**I18N-006 — mission.yaml `language:` field + Lua emit**
Add `language: en|fr` (optional) to `mission.yaml`. `generate_config_lua()` emits `veaf.config.language = "fr"` when set so the Lua runtime can read it. Also translate every `#` comment line in the `generate_mission_yaml()` YAML template output using `t()`.

</details>
