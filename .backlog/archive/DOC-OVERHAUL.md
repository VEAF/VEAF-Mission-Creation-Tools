# Lot DOC-OVERHAUL — Complete, detailed, bilingual, ELI5 documentation

Status: ✅ done

**Goal**: Make the documentation complete, detailed, accessible, fully bilingual (FR/EN parity), with ELI5 explanations for non-dev audiences (pilots, mission makers), mermaid diagrams, and screenshot placeholders. Blocks the next develop release.

**Branch**: `feature/doc-overhaul` → PR → `develop`

**Audit findings** (verified):
- FR systematically lags EN: LUA_API_REFERENCE −1077 lines, TOOLS_REFERENCE −346, pilot/GUIDE −103, veafAirWaves −131, veafCombatZone −103, others −20…−50
- Missing files: `veafInterpreter.md` (no FR → nav L105 404), `dcs-radio-specs.en.md` (no EN)
- Zero images/screenshots in 40 docs; mermaid only in developer docs
- Pilot guide not truly ELI5 (unexplained jargon: Lua framework, AWACS, IADS)
- Content errors: deprecated `enable:` examples, removed `convert` command listed, CSAR "not available" (false), dead URL in updater

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| DOC-001 | Create `veafInterpreter.md` (FR) — fixes broken FR nav. (`dcs-radio-specs` EN parity deferred to DOC-005: file is hand-maintained, not purely generated) | fix | 30 min | ✅ |
| DOC-002 | Isolated content errors done: remove `convert`, CSAR note (FR+EN), dead updater URL, debug-logging section, CHANGELOG consolidation. (`enable:`→`enabled:` + `lua_modules:`→`modules:` across ~20 files folded into per-file DOC-005 passes) | fix | 45 min | ✅ |
| DOC-003 | Pilot guide rewritten (FR+EN): deduplicated, accessible, `_auth` standardized, mermaid F10 menu, screenshot placeholders; READMEs reviewed (already clean) | feat | 2h | ✅ |
| DOC-004 | Mission-maker GUIDE + MIGRATION_GUIDE (FR+EN): build-pipeline + v5→v6 mermaid diagrams, `modules:` block example, broken `GUIDE.fr.md` links fixed | feat | 2h | ✅ |
| DOC-005a | Mechanical syntax sweeps (`enable:`→`enabled:` ×62, `lua_modules:`→`modules:` ×56) + MISSION_YAML_REFERENCE unified `modules:` rewrite (FR+EN) | feat | 1h30 | ✅ |
| DOC-005b | Script docs FR→EN parity: veafAirWaves, veafCombatZone, veafQraManager, veafShortcuts, veafWeather, veafRadio (all now delta ≤10) + broken `.fr.md` links fixed | feat | 2h30 | ✅ |
| DOC-005c | Big references in-section depth parity: LUA_API_REFERENCE (~1050 l. across 5 API sections) + TOOLS_REFERENCE (~346 l.) + dcs-radio-specs FR prose | feat | 5h | ✅ |
| DOC-006 | Produce DCS screenshot capture list for the user | chore | 30 min | ✅ |

**Estimated total: ~12h**

### DOC-005c handoff brief (cold-start ready)

The remaining work is **in-section depth parity** — same headings in FR and EN, but the
FR has shorter descriptions / fewer code examples. Approach: for each section, read the
EN version, then expand the FR to match (translate the missing prose, tables, and code
blocks). Code blocks/identifiers stay identical; only prose is translated.

**Files and gaps (FR lines behind EN):**

| File | Gap | Where the gap is |
|------|-----|------------------|
| `doc/LUA_API_REFERENCE.md` | ~1050 | Core Infrastructure (−190), Unit & Group Management (−388), Mission Systems (−284), Infrastructure & Services (−102), Communication & Control (−90). Other sections already at parity. |
| `doc/TOOLS_REFERENCE.md` | ~346 | All sections present (translated headings); depth is thinner throughout the updater/publish/architecture sections. |
| `doc/mission-maker/dcs-radio-specs.md` | prose only | The frequency table is language-neutral and fine; only the header prose + the hand-written "Critical aircraft" section need a FR pass. NOTE: this file is **hand-maintained** beyond what `veaf_build/radio_specs_updater.py` generates — do not regenerate, edit by hand. |

**Conventions already established this lot (keep consistent):**
- Tone: sober, vouvoiement, jargon explained at first use (no childish analogies).
- YAML syntax in examples: unified `modules:` block, `enabled:` (never `enable:`), community scripts as uppercase IDs inside `modules:`.
- Auth command is `_auth [PASSWORD]` (canonical `veafSecurity.Keyphrase`); never `-login`.
- Cross-doc links use `*.md` (NOT `*.fr.md` / `*.en.md`) — mkdocs-static-i18n resolves the language. Several `.fr.md` links were already fixed; watch for more.
- Screenshot placeholders live under `doc/assets/img/<area>/`.
- Per-doc commits, verify parity with `wc -l` after each file.

**After DOC-005c:** update CHANGELOG, open PR `feature/doc-overhaul` → `develop`,
then the user captures the screenshots listed in DOC-006 to drop into `doc/assets/img/`.
