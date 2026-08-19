# DOC-AUDIT-FIXES — the 2026-08-13 documentation audit, acted on

Status: ✅ done — 2026-08-13, all four tickets

Origin: a five-pass parallel audit of `doc/` (2026-08-13): FR/EN structural parity, Lua script
pages vs `src/scripts/veaf/`, CLI/YAML references vs the Python code, prose proofreading, and a
gap hunt against the CHANGELOG. ~150 distinct defects. The surgical lists live **in the tickets**,
because the audit session's context is the only other place they exist.

## What the audit established

The `docs-check` gate keeps links, anchors, nav and translation *existence* healthy — none of that
was broken. What rotted is everything the gate cannot see: **content**. Three families:

1. **Active lies** — pages stating the opposite of the code. The worst cluster is security: the
   pilot guide still promises the 10-minute session `REVIEW-SECURITY-LAYER` deleted, and 11
   references to `/secu login` survive across the script pages. Others: `veafSanctuary` documents
   its `coalition` field **inverted**, `veafAirWaves` misdescribes its altitude gates, every
   command example on `veafInterpreter.md` **aborts** when typed (unknown keys are fatal since the
   parser refactor), and `MISSION_YAML_REFERENCE` says security is off by default when the runtime
   default is on.
2. **Broken form** — a rendering defect repeated ~40× in `LUA_API_REFERENCE`, a reference table
   whose "Aircraft" column holds engine types on 72 of 88 rows, 5 dead anchors the gate
   structurally cannot catch, 4 links that escape `docs_dir`, ~50 typos/franglais items.
3. **Holes** — the new security model has no pilot-facing page, checklists are invisible from the
   pilot docs, `kneeboard_only` and `--parking` are documented nowhere, and the CLI has no real
   reference (David's call: full command documentation is wanted **in addition to** `--help`).

## David's arbitrations (2026-08-13)

- **a** — tier names: **fix the code**, not the doc. The dispatchers still only accept `L0/L1/L9/MM`;
  the decided model (new names canonical, old ones deprecated aliases) is what the doc already
  describes. → `FIX-DOCAUDIT-CODE`.
- **b** — `doc/ROADMAP.md` becomes a **thin pointer** to the root `ROADMAP.md` (both languages).
  Rewriting it as a copy recreates the drift just measured.
- **c** — **write the full CLI reference**: all 25 `veaf-tools` commands with their options. Doc in
  addition to `--help`, his words. Ticket 04.
- **d** — the five undocumented Lua modules get **their own lot** (`DOC-MODULE-PAGES`), not a line
  here.
- **e** — purge the "this page used to say the wrong thing until <date>" self-narration from
  reference pages; provenance lives in git and the CHANGELOG.
- **f** — normalise the AI catalogue's per-language anchors to the repo convention (identical
  English slugs in both languages).

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Active lies — security cluster + factual inversions | ✅ |
| 02 | Broken form — rendering, dead anchors, prose | ✅ |
| 03 | Holes and structure — new sections, ROADMAP pointer, anchors | ✅ |
| 04 | The full CLI reference — 25 commands, options included | ✅ |

Delivery: **two PRs** — 01+02 (corrections), then 03+04 (new content) — so each review is one kind
of reading.

## Out of scope

- The code bugs the audit surfaced (tier-name dispatchers, `_transport` markId, the fog constant,
  `cli.py`'s stale help, the two `docs-check` blind spots) → `FIX-DOCAUDIT-CODE`.
- Pages for the five undocumented modules → `DOC-MODULE-PAGES`.

## Definition of Done

- `poetry run docs-check` green; the backlog gate green.
- Every fix lands in **both languages in the same commit** — a fix in one language is itself a
  defect (three were found).
- No new hand-written shipped version anywhere (the deploy stamps).

## What ticket 03 and 04 measured against the code

Four of ticket 03's items were wrong, and each is recorded here rather than quietly fixed:

- **`era` is not "written back into mission.yaml".** `write_config_lua` fills the inferred value
  into the in-memory mapping that generates `veaf-config.lua`, so it is recomputed at every build
  and the file is never touched. Documented as such, with "set the key to pin it".
- **`warehouses.yaml` was already in the Category A table.** What was actually missing there is
  `spawn-groups.yaml`. Both files were missing from the folder tree.
- **The FR "Per-type kneeboards" section exists.** The ticket asked to port the English one for want
  of a counterpart; the French page is the longer of the two.
- **Repointing the "référence complète" links was 14 sites across 7 files, not 4.** Enumerated
  rather than sampled.

Ticket 04's own count held: 25 commands, and 120 option entries per language.

## Decisions taken while writing, open to review

- **The two pilot-visible nav entries point at whole pages, not anchors**, because
  `mkdocs build --strict` aborts on a nav target carrying one — measured, not assumed. The
  discoverability the ticket asked for is delivered by naming the entries after the *feature*
  ("Guided checklists (veafAssist)"), which also keeps the module name for whoever searches it.
- **`doc/ROADMAP` lost its content rather than gaining a correction.** It claimed `master` carried
  v5.103.3, four weeks after `master` moved to v6, and listed a shipped command as an idea. It is now
  a pointer plus the three long-term axes, per David's arbitration b.
- **`AI_ASSISTANT_CATALOG`'s 32 French anchors were rewritten to the English slugs** (65
  occurrences with their same-page links). The two pages now expose an identical anchor set, which is
  the repo convention and what makes a cross-page link work from either language.
- **Three sections gained explicit anchors** (`modules:`, `community_scripts:`, `build_variants:`)
  plus the third-party modules section, so the rebuilt index does not depend on a derived slug. The
  gate's new rule A caught the four inbound links that broke as a result — which is the rule paying
  for itself on the first page that needed it.

## Still open, and named

The option-coverage rule now covers the main CLI, which was `FIX-DOCAUDIT-CODE` 04's stated debt.
Nothing from this lot is deferred.

---

## 01 — Active lies: the security cluster, and every page stating the opposite of the code

Status: ✅ done 2026-08-13 — every item applied in both languages, with two of this ticket's own claims disproved by measurement (see Discrepancies)
Type: fix
Files: ~35 pages ×2 languages under `doc/`, plus `src/defaults/mission-folder/mission.yaml` (one comment)

Every item below was verified against the code by the 2026-08-13 audit, with the evidence cited.
Fix FR and EN together. Where the doc describes the **decided** security model that the code has not
caught up with (tier names), leave the doc as is — `FIX-DOCAUDIT-CODE` 01 makes it true.

### A. Security — the pilot-facing lies

- [x] `doc/pilot/GUIDE.md:299-302` (+ EN same lines) — delete the promise *"l'authentification reste
      valide pendant 10 minutes"* and rewrite §Sécurité on the real model: password checked per
      command for an unlisted pilot; a listed pilot's own level decides; an F10 menu **group acts at
      the level of its lowest-graded occupant** (DCS cannot tell who clicked); `_auth elevate`
      raises the group to the requester's level for 2 minutes (`veafSecurity.lua:581-591,624-627`,
      `ELEVATION_DURATION_SECONDS` at `:891`).
- [x] `doc/pilot/GUIDE.md:283-287` tier table (+ EN) — add `OPEN` and the `MM` (Mission Master)
      gate: password-only, no identity, no tier or login ever opens it.
- [x] `doc/pilot/GUIDE.md:340-341` FAQ (+ EN) — "mes commandes ne fonctionnent pas" must mention the
      lowest-occupant rule and `elevate`, not only `_auth`.
- [x] `doc/pilot/README.md:27` (+ EN) — the "S'authentifier" row: no session any more; name `elevate`.
- [x] `doc/mission-maker/scripts/veafSecurity.md:100` (+ EN `:101`) — delete *"l'accès est accordé
      pour `authDuration` minutes"*: `checkSecurity_L0/L1/L9` no longer consult
      `veafSecurity.authenticated` (`veafSecurity.lua:814-839`).
- [x] `veafSecurity.md:114` (+ EN) — elevation requires the **explicit verb**: `_auth elevate` or
      `/secu elevate`; a plain `_auth <password>` elevates nothing (`veafSecurity.lua:576,624-627`).
- [x] `veafSecurity.md:92-98` (+ EN) — document the `_auth logout` and `_auth elevate` verbs.
- [x] `veafSecurity.md:154` (+ EN `:155`) and the prose at `:49` — **`veafSpawn.defaultSecurity` does
      not exist** anywhere in `src/` or `test/`; spawn security is a per-command literal
      (`veafSpawnCore.lua:161`, asserted against `veafSpawn.SECURITY_CHECKS` `:137-152`). Remove.
- [x] `veafSecurity.md:~115` + `veafServerHook.md:11` (+ EN) — `/login` and `/secu login` are
      documented as chat commands; the hook dispatches only `send/code/restart/restartnow/halt/
      haltnow/pause` (`VEAF-Server-hook.lua:489-551`). The real routes: the `_auth` marker, the
      hidden `-login` alias (`veafShortcuts.lua:1061`), the niod `login` callback
      (`veafRemote.lua:151`).
- [x] `veafServerHook.md:81` (+ EN `:80`) — `/secu login|logout|elevate` need level ≥ 10
      (`veafSecurity.lua:531-544`), not level 1; add `/pause` at level 10
      (`VEAF-Server-hook.lua:551-563`); reframe the grid off "déverrouiller les commandes".
- [x] `veafSecurity.md:109-110` (+ EN) — soften "rien ne change pour un pilote listé": `_transport`
      still demands the password from everyone (code bug, `FIX-DOCAUDIT-CODE` 02); say so until
      fixed.
- [x] The 11 stale `/secu login` session references, each replaced by the group-level model
      (`veafRadio.lua:271-309,569-582`): `veafRadio.md:229,355` · `veafCombatZone.md:331,400` ·
      `veafCarrierOperations.md:118` ("mot de passe requis" — an F10 entry has no password path) ·
      `veafCasMission.md:55,84` ("token de sécurité `/secu`") · `veafShortcuts.md:46` (comment:
      bypasses the per-command level check, not a session) · `README.md:36,100` (+ EN each).

### B. Factual inversions in script pages

- [x] `veafSanctuary.md:28,56,70` (+ EN) — `coalition` is the **protected** coalition, not the one
      destroyed (`veafSanctuary.lua:442-515,575,592`; its own builder table at `:101` is right).
- [x] `veafSanctuary.md:59,72-73` (+ EN) — `delay_instant`/`delay_spawn` defaults are **-1 =
      disabled**, not 0 (`veafSanctuary.lua:51,54`); `delay_instant` is seconds-in-zone before the
      kill; `:121-122` — no instant kill by default, and zones are not only editor trigger zones
      (polygon/radius APIs on the same page).
- [x] `veafAirWaves.md:59-60,103-104` (+ EN) — `min/max_altitude_ft` gate **player detection**, not
      AI removal (`veafAirWaves.lua:832-843`); `:106` — `minimum_life_percent` is a percentage vs
      `100*life/life0`, default 0 (`:169,719-723`); add `setMinimumLifeForAiInPercent` (`:628`) to
      the builder table.
- [x] `veafAssets.md:46,61` (+ EN) — `jtac` is the **laser code**, not a boolean
      (`veafAssets.lua:168,203` → `autoLase(groupName, laserCode, …)`).
- [x] `veafAssets.md:9,16,140` (+ EN) — drop the carrier-management claim and the
      `veafCarrierOperations` dependency: no reference in `veafAssets.lua`; `:122` already says so.
- [x] `veafAssets.md:128-132` (FR) — real root menu `ASSETS`, real English labels (`Respawn …`,
      `Get info on …`, `Dispose of …`), and a submenu only exists when `disposable`/`information`
      is set (`veafAssets.lua:30,44-68`). EN keeps the labels; FR must too.
- [x] `veafWeather.md:160-163` (+ EN) — these are **remote** commands (`/weather`, `/atc`, `/atis`,
      `veafWeather.lua:1829-1831`), not `_weather` marker commands (no handler registered;
      `Keyphrase` is dead). Document `/atis`; port EN's `veafRemote` prerequisite note (`.en:157`)
      to FR.
- [x] `veafCasMission.md:136-141` (+ EN) — add `spacing` (1-5), `password`, `disperse` (bare
      `disperse` = 15 s default since the refactor, `veafCasMission.lua:403,521-531`); state code
      defaults `size 1 / defense 1 / armor 1` (`:478-480`); `:147` — the CAS MISSION submenu exists
      from `initialize()` with a HELP entry (`:1226-1230`).
- [x] `veafInterpreter.md` (+ EN) — **every example is invalid and now aborts** (unknown keys are
      fatal: `veafSpawnParser.lua:564`, `veafSpawnCore.lua:231-235`). `-spawn sa-11` → no `-spawn`
      alias exists, use `-sa11`/`-sa10`/`-sa6`; `laserCode 1688` → `laser`; `-convoy from A to B` →
      `dest`/`destination`; `-arty, rounds 10` → no `rounds` key (`shells`), and `-arty` expands to
      an M-109 group. Rewrite all examples with verified syntax; `:21` — the unit is destroyed
      **only when the command succeeds** (`veafInterpreter.lua:85-96`).
- [x] `veafSpawn.md:122` (+ EN) — convoy `size` is not "0-5 véhicules": unbounded `_num`, default
      **10** (`veafSpawnParser.lua:180,306`), the `-convoy` alias randomises 6..15
      (`veafShortcuts.lua:1260`).
- [x] `veafGrass.md:28,49` (+ EN) — the code tests the **unit** name for `FARP ` (`veafGrass.lua:
      197,211`), not the group name.
- [x] `veafTransportMission.md:35,54` (+ EN) — `blocade` parses but generates **nothing** (empty
      `-- TODO`, `veafTransportMission.lua:418-422`). Say it plainly.
- [x] Module IDs: `veafNamedPoints.md:3` `NAMED POINTS` → `NAMEDPOINTS`; `veafTransportMission.md:3`
      `TRANSPORT` → `TRANSPORTMISSION`; `veafGrass.md:3` and `veafAirbases.md:3` `—` → `GRASS`,
      `AIRBASES` (each registered; + EN each).
- [x] The 14 FR + 14 EN page headers carrying retired per-module `**Version:** 1.x.x` lines — remove
      (single `veaf.BuildVersion` stamp since `FEAT-LUA-BUILD-STAMP`; only `veafAssist.Version`
      survives in code).
- [x] `README.md:30,32,34` (+ EN) — F10 claims: no `Generate` entry (CAS is marker-driven);
      `MISSIONS` belongs to veafCombatMission and **veafAirWaves has no menu**
      (`veafAirWaves.md:119` is right); carrier root is `CARRIER OPS`, label `Start carrier air
      operations for 45 minutes` (`veafCarrierOperations.lua:26,859`).
- [x] `veafAssist.md:26-33` (+ EN) — `Confirm this step` / `Skip this step` sit at the **top level**
      of the VEAF menu, not inside `Assistance` (`veafAssist.lua:724-752`).
- [x] `enable` → `enabled` in the field tables of `veafAssets.md:53`, `veafSanctuary.md:65`,
      `veafCarrierOperations.md:47` (+ EN each) — the reader keys on `enabled`
      (`lua_config_generator.py:93,297-298,322,1253`).

### C. Reference pages — the YAML/CLI lies

- [x] `MISSION_YAML_REFERENCE.md:189,202` (+ EN) — **security is ON by default**
      (`veaf.SecurityDisabled = false`, `veaf.lua:29`; no `security:` block emits nothing,
      `lua_config_generator.py:1405-1409`). Also fix the same wrong comment in
      `src/defaults/mission-folder/mission.yaml` (`disabled: true # … (default)`).
- [x] `MISSION_YAML_REFERENCE.md:352,361-370` (+ EN) — `MIST` cannot be disabled: mandatory, an
      explicit disable is overridden with a warning (`lua_config_generator.py:260`,
      `mission_builder_worker.py:795-804`).
- [x] `MISSION_YAML_REFERENCE.md:32` (+ EN) — stale sentence declaring `qra:`/`assets:`/`shortcuts:`
      top-level sections; `:233` says `qra:` no longer exists; QRA lives under `modules.QRA`.
- [x] `MISSION_YAML_REFERENCE.md:382-405` (+ EN) — add the 6 missing module IDs of 32: `GROUNDAI`,
      `REMOTE`, `AIRBASES`, `TRANSPORTMISSION`, `SKYNET_MONITOR`, `I18N` (four are ON in the
      shipped default).
- [x] `MISSION_YAML_REFERENCE.md:562` + `PIPELINE_REFERENCE.md:65` (+ EN) — kneeboard output path is
      `KNEEBOARD/<type>/IMAGES/presets[-<coalition>].png` (`presets_manager.py:2200`), as
      `PIPELINE_REFERENCE.md:209` already says.
- [x] `PIPELINE_REFERENCE.md:250` (+ EN) — 87 → **100** aircraft in the shipped radio specs.
- [x] `PIPELINE_REFERENCE.md:430,451` (+ EN) — inside `mission build`, weather variants land in
      `missions/<Base>_<name>.miz` (`build.py:405-413`); the bare `<name>.miz` form is
      `inject-weather` standalone only.
- [x] `TOOLS_REFERENCE.md:317-327,809-810` (+ EN) — `--prerelease` with `6.0.1` is **rejected** by
      the code: a semver pre-release (`6.9.21-rc1`) is required (`veaf_build/cli.py:270-274`); the
      `published-latest` claim only holds for a `-`-suffixed version.
- [x] `TOOLS_REFERENCE.md:96,491-508` (+ EN) — the updater moves only the two exe files
      (`veaf-tools-updater.py:660-694`); `buildDemoMission.cmd` & co and `src/build-scripts/` do not
      exist. `:294` — token order is `--token` → config → env (`cli.py:76-80`), as `:237` says.
- [x] ~~`FOOTHOLD.md:135-141` — the lowercase example is silently ignored~~ — **this ticket item was
      WRONG, and so was the audit finding behind it.** Measured 2026-08-13: module-ID matching is
      **case-insensitive** (`mission_builder_worker.py:568-571` lowercases both sides,
      `yaml_validator.py:157` compares `key.upper()`), and the foothold conversion profile scaffolds
      lowercase itself (`convert-profiles/foothold.yaml:36-43`). The FOOTHOLD example is **correct**
      and was left untouched. `MISSION_YAML_REFERENCE` was the liar, twice — "IDs en majuscules" (the
      case is irrelevant) and "un identifiant inconnu déclenche un avertissement et est ignoré" (it is
      an **aborting error**: `logger.error` → `typer.Abort`, a mechanism this repository has already
      been bitten by once). Both corrected instead. `:38` "dix cartes" → nine: done.
- [x] `MIGRATION_GUIDE.md:333-335` (+ EN) — three mutually incompatible statements about duplicate
      v5 triggers; keep the true one (`:118`: removed automatically). `:266` —
      `veafDynamicConfig.lua` is dynamic **script-loading** config, not Dynamic Slots.
- [x] `LUA_API_REFERENCE.md:169` (+ EN `:168`) — default language is `en`, not `fr`
      (`MISSION_YAML_REFERENCE.md:144`, `TOOLS_REFERENCE.md:179` agree).
- [x] `mission-editing-mcp.md:726,730` (+ EN `:706,710`) — trim "zones non circulaires" from the
      out-of-scope list (today's `edit_zone` writes polygons, same page `:251-289`); EN `:708`
      `SI/ALORS` → IF/THEN; tag the six new sections with their wave/lot like every sibling group.
- [x] `index.md:82,84` (+ EN) — `--version 6.0.5` in the quick start → a placeholder
      (`<version>`), not a hand-written stale number; same for `developer/GUIDE.md:378,561-562`
      (6.1.0), per the page's own rule at `:535-537`.
- [x] `veafQraManager.md:287` (FR) — port EN's `active_at_start: false` route (the field is real,
      `lua_config_generator.py:907-910`).
- [x] Ticket e (David): purge the self-narration blocks — `MISSION_YAML_REFERENCE.md:208`,
      `mission-maker/GUIDE.md:294`, `LUA_API_REFERENCE.md:76-86`, `ALIASES.md:212-214` — keep the
      *current* fact, drop the "this page used to say…" story and internal ticket IDs.

### D. Developer pages (from the same audit, same nature)

- [x] `TESTING.md:265-266,272` (+ EN) — stylua action `@v5`, scope includes `test/lua/`, Lua ratchet
      `--cov-fail-under 72`; `:103` — 36 files; `:144-179` — add `test_veafAssist.lua` and
      `test_veafServerHook.lua`, refresh the per-suite counts (346/184/138/107/17 measured);
      `:185-192` — 7 of the 8 "uncovered modules" no longer exist; `:19` — "tous les modules" vs
      its own uncovered table.
- [x] `developer/GUIDE.md:502` + `developer/README.md:88-89` (+ EN) — pre-commit commands must match
      CI: stylua over `src/scripts/veaf/ test/lua/`, ruff over the three trees + `ruff format
      --check`, mypy over `src/python/veaf-tools`; `GUIDE.md:496-507` — the job table: add
      `Lua Coverage` as blocking, note `dcs-mock-coverage` is `continue-on-error`; `:515-524` —
      docs-check runs three passes, not one; `:626` — release branches carry no `v`
      (`release/6.13.0`); `:66` — `openspec/` does not exist (→ `.backlog/`); `:63-64` — the tree
      must show `test/python/`.
- [x] `developer/mission-editing-mcp.md:733` (+ EN `:716`) — the archived lot path
      (`.backlog/archive/FEAT-MCP-MISSION-EDITOR.md`).
- [x] `developer/README.md:98` (+ EN) — TESTING.md is Lua-only; say where the Python side lives
      (`GUIDE.md:342-368`).

### Acceptance criteria

- [ ] Every A–D item fixed in both languages; `docs-check` green.
- [ ] No claim replaced by another unverified claim: each rewrite cites what the audit measured, or
      re-reads the code line given.
- [ ] `CHANGELOG.md` entry; version bump ×3 manifests.

### Discrepancies found while applying — the ticket was wrong, the code decided

- **The FOOTHOLD item was false**, see the struck-through item above. Two lies were found in
  `MISSION_YAML_REFERENCE` instead, and fixed. Worth keeping as a reminder that an audit finding is a
  hypothesis until the line is re-read: this one travelled from a subagent's report into a ticket
  before anyone re-checked it.
- **`elevate` is not gated at level ≥ 10.** The ticket said `/secu login|logout|elevate` all need
  level 10; `veafSecurity.lua:539-542` caps `elevate` at the **requester's own** level instead of
  gating it, so the server-hook grid keeps it at the relay level. Documented as the code behaves.
- **The language fallback is not one value.** The tools resolve to `en` as a final fallback, but
  `veaf.lua:138` falls back to `fr` outside a build — phrased as "the tools' resolved language at
  build time, final fallback `en`" rather than picking one and being wrong half the time.
- **One code defect surfaced, out of scope here**: `lua_config_generator.py:201` still writes the
  misleading `disabled: true # … (default)` comment into every **generated** mission.yaml. The
  shipped default was fixed in this ticket; the generator is `FIX-DOCAUDIT-CODE` 05.

### The two rewrites the main session kept

The pilot-guide security section and the `veafInterpreter` examples were done in the main session and
their facts re-read at the source: `_auth elevate` is a real marker verb (`veafSecurity.lua:624-627`),
`ELEVATION_DURATION_SECONDS = 120` (`:891`), elevation rises to the requester's own level
(`handleElevationRequest`, `:677-697`), `password` is a real spawn key (`veafSpawnParser.lua:100`).

For the interpreter, one further defect turned up that the audit had not seen: **`smoke` is
conditional on `cargo` and is a flag, not a colour** (`veafSpawnParser.lua:174-179`,
`_flag("cargoSmoke")`) — so the documented `-jtac, laserCode 1688, smoke red` was wrong twice over,
and `smoke red` was dropped rather than merely renamed. Likewise `rounds` has no `shells` equivalent
for a gun battery: `shells` drives `spawnBomb`/`spawnSmoke` (`veafSpawnEffects.lua:248,282`) while
`-arty` expands to a plain M-109 group spawn, so the round count was removed rather than translated.

---

## 02 — Broken form: rendering, dead anchors, escaped links, prose

Status: ✅ done 2026-08-13 — applied; three of the audit's counts were wrong in both directions (see Corrections), and four items are deferred with their reasons
Type: fix
Files: ~20 pages ×2 languages under `doc/`

Form defects only — nothing here changes a claim. Every anchor below was verified against the real
slugifier (`pymdownx.slugs.slugify(case=lower)` + `attr_list`); `docs-check` structurally cannot see
them because `anchors_of()` registers both the explicit anchor **and** the heading-derived slug
(hardening → `FIX-DOCAUDIT-CODE` 04).

### A. Rendering-breaking

- [x] `LUA_API_REFERENCE.md:3-5` and ~40 further `**Key:** value` line runs (+ 42 in EN) — consecutive
      lines with no blank line collapse into one `<p>`; the browser shows them run-on. Convert each
      block to a list or add hard breaks; fix the generator if these blocks are generated
      (`veaf_build/` — check before hand-editing).
- [x] ~~`dcs-radio-specs.md:106` region, 72 of 88 rows~~ — **moved to `FIX-DOCAUDIT-CODE` 06**: the
      page is *generated* (`radio_specs_updater.py:35`), and the cause is one regex —
      `parse_display_name` searches `^\s*type\s*=` with `MULTILINE`, so it matches the **indented**
      `type` inside the engine block, which is where `TurboFan` comes from. Its own comment says
      "top level of the file". Hand-editing the page would be undone by the next
      `update-dcs-data --radio`.
- [x] `AI_ASSISTANT_INSTALL.md:52` (+ EN `:49`) — corrupted path
      `extensionseaf-mission-editor` → `extensions\veaf-mission-editor`.
- [x] `MIGRATION_GUIDE.md:79` (FR) — trailing `\\` in a Copy-Item command.
- [x] Dead anchors — **seven**, not five: `TESTING.md:9` `#couverture` → `#coverage` · `pilot/GUIDE.md:12`
      `#les-commandes-par-marqueur` → `#marker-commands` · `pilot/GUIDE.md:9` off-by-one slug
      (`#quest-ce-que-veaf-mct-` with trailing hyphen — give the heading an explicit anchor
      instead) · `MISSION_YAML_REFERENCE.md:717` + `.en.md:731` `#custom_scripts` →
      `#custom-scripts`.
- [x] Links escaping `docs_dir` — **six**, not four: `CONVERT_OTHER.md:50` (+ EN) ADR 0007 → the
      absolute GitHub URL like every other ADR link · `mission-maker/GUIDE.md:690` (+ EN `:691`)
      `tools/klogg/veaf.conf` → GitHub URL.
- [x] `PIPELINE_REFERENCE.md` (+ EN) — steps ordered 1,2,3,**6**,4,5 against the page's own "dans
      cet ordre"; renumber or move the section; give steps 4-5 explicit `{#…}` anchors like their
      siblings.
- [x] `TOOLS_REFERENCE.md:853-869` (+ EN) — the page signs off ("Bonnes publications ! 🚀") and then
      continues; move the farewell to the end; delete the duplicated language-detection section
      (`:859-869` repeats `:171-193` verbatim); rebuild the ToC (4 of ~20 sections, wrong order) —
      or drop the manual ToC entirely (mkdocs renders one).

### B. Meaning-blurring prose (not factual, just wrong-reading)

- [x] `mission-maker/GUIDE.md:684` — "éditez `veaf-config.lua` — c'est un fichier généré, donc vos
      modifications seront écrasées" — the advice destroys itself; rewrite as the warning it is.
- [x] `MIGRATION_GUIDE.md:126-132` — "n'existent plus ou ont été renommées" introducing rows marked
      "inchangé"; reframe the section.
- [x] `PIPELINE_REFERENCE.md:339` (FR) — garbled sentence ("en restreint un seul"); EN has the
      meaning.
- [x] `MISSION_YAML_REFERENCE.md:150` — misplaced "au contraire".
- [x] `pilot/GUIDE.md:50` vs `:62,:193` — "TOUTES les fonctions sous F10 → VEAF" vs CARRIER OPS
      hanging off F10 directly (+ EN).
- [ ] **Deferred to ticket 04** (it becomes true only when the CLI reference exists): `index.md:42` — TOOLS_REFERENCE mislabelled as the `veaf-tools.exe` reference (becomes true
      only after ticket 04; fix the label with it) — plus `mission-maker/GUIDE.md:697`,
      `MIGRATION_GUIDE.md:378`.
- [x] Module count said four ways (33+/30+/17+/34) — one number, counted, everywhere; same for the
      aircraft count (ticket 01 fixes it to 100).

### C. Typos, franglais, consistency (the audit's itemised 30 + 12)

- [x] FR grammar: "une 2e radio" (`PIPELINE_REFERENCE.md:108,120`) · stray tutoiement
      (`mission-maker/GUIDE.md:359`) · "faire verrouiller **par** les administrateurs"
      (`GUIDE.md:294`, dies anyway with ticket 01's purge) · "une fois qu'elles sont toutes
      détruites" (`pilot/GUIDE.md:223`) · "Ils portent" (`ALIASES.md:210`) · `<nom-préréglage>`
      accent (`PIPELINE_REFERENCE.md:143`) · "spawnables" plural (`MIGRATION_GUIDE.md:268`) ·
      em-dash+comma (`GUIDE.md:570`) · colon-promising-list (`pilot/GUIDE.md:277`) · missing full
      stop (`CONVERT_OTHER.md:11`).
- [x] Franglais: "stabilotées"/"stabilo" → surlignées (`PIPELINE_REFERENCE.md:190,203`) ·
      "droppant" (`:215`) · "misroutait" (`:339`) · "committée" (`:543`) · commiter/committer
      unified (`TOOLS_REFERENCE.md ×6`) · "aliases" → alias (`MIGRATION_GUIDE.md:229,292`) ·
      "plancher de cliquet" → plancher à cliquet / seuil plancher (`TESTING.md:273`) · "slash
      commands" (`AI_ASSISTANT_INSTALL.md:22`) · carrier/tankers/Actifs vs
      porte-avions/ravitailleurs/Ressources unified (`mission-maker/GUIDE.md:37-38,488`) ·
      "insurgée" (`ALIASES.md:45`).
- [x] Typography/wording: "Linux–macOS" en-dash (`TOOLS_REFERENCE.md:178,866` + EN) · "protège
      enfin" without object (`ROADMAP.md:44` — dies with ticket 03's pointer) · "ligne par ligne"
      vs per-file (`TESTING.md:64`) · duplicated parenthetical (`ALIASES.md:103`) · verbless tanker
      row (`ALIASES.md:158`) · FW-190A8 vs D9 example mismatch (`dcs-radio-specs.md:69,76`).
- [x] EN: guillemets (`TOOLS_REFERENCE.en.md:75`) · ASCII hyphens as dashes (`:1,7,8,43`) · "makes
      missions alive" → brings to life (`pilot/GUIDE.en.md:25`) · BrE/AmE left as-is (not worth the
      churn) unless touching the line anyway.
- [x] The ~12 minor items: EN shell comments on FR page (`TOOLS_REFERENCE.md:528-638`) · v6.3.0
      before v6.3.3 (`ROADMAP.md` — dies with ticket 03) · duplicate `### Prérequis` anchors
      (`TESTING.md:46,74` + EN) · localised map-name mix (`FOOTHOLD.md:25-26`) · two Klogg menu
      paths (`GUIDE.md:690` vs `MIGRATION_GUIDE.md:365`) · catalogue/catalog
      (`mission-maker/README.en.md:61,73`) · Véhicule vs Escouade for `-sa15`/`-sa22`
      (`pilot/GUIDE.md:100-101` vs `ALIASES.md:39,42`) · `size [1-5]` vs table starting at 0
      (`pilot/GUIDE.md:264,271`) · `mission build mission .` (`MIGRATION_GUIDE.md:205,246` + EN) ·
      duplicated intro sentences (`index.md:3,5`).

### Acceptance criteria

- [x] `docs-check` green; a manual `mkdocs build` (or the CI docs job) renders LUA_API_REFERENCE's
      header blocks as separate lines.
- [x] The seven dead anchors resolve on the rendered site (explicit anchors added where slugs were
      fragile).
- [x] CHANGELOG entry (shared with ticket 01's PR); version bump with it.

### Corrections to the audit's own counts — enumerated instead of sampled

Three counts in this ticket came from a sampling pass and were wrong. Each was re-derived with a
script over the whole tree, and the scripts are worth rebuilding if this is ever done again (the
permanent versions are `FIX-DOCAUDIT-CODE` 04).

- **Dead same-page anchors: seven, not five.** `developer/GUIDE.md` had **four** in its own table of
  contents (`#environnement-de-développement`, `#scripts-lua-runtime`, `#outils-python`,
  `#mode-développeur`, all pointing at headings that carry English explicit anchors), plus
  `veafRadio.md:107`, `pilot/GUIDE.md:12` and `TESTING.md:9`.
- **Links escaping `docs_dir`: six, not four.** `developer/smoke-harness` carried three per language.
- **Two false positives were nearly "fixed" into breakage**, and both are worth remembering:
  - A hand-rolled slugifier that *collapsed* whitespace runs reported 13 phantom dead anchors. The
    repo's (and pymdownx's) is a plain `.replace(" ", "-")`, so `Unit & Group Management` really is
    `unit--group-management`, two dashes and all. **Import `docs_check.slugify`; never reimplement it.**
  - A blanket `../../ → GitHub URL` conversion broke **55 valid links**: from
    `doc/mission-maker/scripts/`, `../../` lands in `doc/`, which is *inside* `docs_dir`. Only pages
    at depth 2 escape. Reverted with `git checkout` on that directory — and `docs-check` was green
    both before and after the breakage, because it does not verify external URLs.
- `ALIASES.md:210` "Ils portent" **never existed** (`git log -S` finds nothing); the line reads
  "Elles portent" and agrees with its antecedent. Audit misreport.

### Deferred, with reasons rather than silence

- **`index.md:42` + `GUIDE.md:697` + `MIGRATION_GUIDE.md:378`** — the "référence CLI complète" links.
  They are only wrong until ticket 04 writes that reference; fixing the label now would point readers
  at a page that still does not have the content. → ticket 04.
- **`FOOTHOLD.md:25-26` localised/unlocalised map-name mix** — the same mix exists at `:54-55,:57,:63`
  and `:232` ("carte Irak", "La Normandie est une autre famille"), so this is a page-wide naming
  decision rather than a typo. Needs David's call: translate every DCS map name in FR prose, or keep
  the English product names throughout.
- **EN shell comments inside FR code blocks** (`TOOLS_REFERENCE.md:528-638`, ~11 of them) — left as
  is. They are inside `bash` fences a reader copies verbatim, and translating a comment inside a
  copied command is churn with no reader gain.
- **BrE/AmE inconsistency across EN pages** — not worth a sweep; fixed only where a line was being
  touched anyway.

### Found while fixing, beyond the ticket

- **`MIGRATION_GUIDE`'s security row was false**, not merely awkwardly framed: it told a maker to
  rename `veaf.SecurityDisabled` to `veafSecurity.SecurityDisabled`, but the runtime honours **both**
  spellings on purpose (`veafSecurity.lua:117-128` — and that docstring records that "nothing in the
  repository assigns it" was evidence of nothing for a *config* field, which is how three years of
  fail-safe breakage went unnoticed). Corrected in both languages.
- **`veafCombatZone`'s "Constantes du module" section sat in a different place in each language** —
  FR before "Fonctionnement", EN after the `#command` subsection. FR moved onto EN's order, so the
  two pages now read in the same sequence.
- **`PIPELINE_REFERENCE` steps 4 and 5 had no explicit anchors** while 1, 2, 3 and 6 did; added, so
  every step can be deep-linked. The step-6 block was *moved* rather than renumbered, because its
  number already agreed with the execution order in `build.py:295-405` — only its position on the
  page disagreed.

---

## 03 — Holes and structure: what no user can currently discover

Status: ✅ done 2026-08-13 — A, B and C applied in both languages; four of the ticket's items were contradicted by measurement (see the PRD)
Type: feat
Files: `doc/pilot/`, `doc/mission-maker/`, `doc/developer/`, `doc/ROADMAP.*`, `mkdocs.yml`

The gap hunt ranked these by user impact. Items 1-3 are behaviour a pilot hits in game **today**
with either no documentation or the old model's documentation (ticket 01 removes the lies; this
ticket writes the replacements' missing halves).

### A. Pilot-facing gaps

- [ ] `doc/pilot/GUIDE.md` §Sécurité (+ EN) — beyond ticket 01's corrections, the section needs the
      full new-model narrative: per-command password for unlisted pilots, lowest-occupant rule with
      a worked example (instructor + student), `_auth elevate` with its 2-minute cap, the tier
      table incl. `OPEN` and `MM`. One section, pilot vocabulary, no implementation jargon.
- [ ] Guided checklists: the pilot F10 tree (`pilot/GUIDE.md:52-63` mermaid) and the feature table
      (`pilot/README.md:20-27`) must show the `Assistance` submenu and link the pilot section of
      `veafAssist.md` (`#for-pilots` anchor exists). A pilot who saw it in game currently has no
      path to it.
- [ ] Coalition-scoped menus (`FEAT-COMBATZONE-MENU-COALITION`, changes existing missions):
      one paragraph in `pilot/GUIDE.md` §Zones de combat — you only see your side's zones;
      `radio_menu_coalition: ALL` restores the old behaviour (maker-side pointer).
- [ ] `kneeboard_only` FC3 types (PR #690/#691): a subsection in
      `mission-maker/dcs-radio-specs.md` + `developer/radio-preset-projection.md` — ten FC3 types
      get a kneeboard and deliberately no `Radio` table; the pilot's "why are my presets empty?"
      and the maker's "why no Radio?" both answered. Port EN's `## Per-type kneeboards (ADR 0012)`
      section to FR (`radio-preset-projection.en.md:125`, no FR counterpart).
- [ ] `capture-map --parking` (`FEAT-MCP-MUTATION-ACTIONS` 08): document the flag, the
      `parking/<theatre>.json` output and the `parking` vs `parking_id` pair in
      `developer/capture-airbases.md` + `developer/dcs-data.md` (+ the GUIDE command table row).

### B. Reference gaps (from the CLI/YAML audit)

- [ ] `MISSION_YAML_REFERENCE.md` — cross-reference the four top-level keys parsed but documented
      elsewhere: `dcs_bridge`, `strip_native_triggers`, `conversion_profile`, `config_override`
      (one row each, linking the owning page).
- [ ] `era` auto-detection (`era_detector.py:130-150`, written back into mission.yaml when absent):
      document in the `era` row.
- [ ] `PIPELINE_REFERENCE.md` — add `warehouses` to the `pipeline:` fields table (`:41-48`), the
      root-level `warehouses.yaml` location, and the `enabled` / `presets.kneeboards` sub-fields to
      the step table.
- [ ] `MISSION_YAML_REFERENCE.md` Category A table + folder tree — add `spawn-groups.yaml` and
      `src/warehouses.yaml`.
- [ ] `TOOLS_REFERENCE.md` — add `build-standalone` and `build-kit` to the veaf-build list; complete
      `update-dcs-data`'s eight missing options.
- [ ] `src/defaults/mission-folder/mission.yaml` — add a commented `delay_seconds:` example to the
      `custom_scripts:` block (defaults-lockstep rule: the shipped default is where a maker copies
      from, and the feature is invisible there).
- [ ] Unify the FR/EN index taxonomies of `MISSION_YAML_REFERENCE` (FR 3-tier vs EN 6-domain; pick
      the EN domains, port to FR, add the 5 entries FR lacks, drop EN's duplicate QRA row, add the
      4 sections both omit).

### C. Structure (David's arbitrations b, e, f)

- [ ] **b** — `doc/ROADMAP.md` + `.en.md` → thin pointer: two paragraphs, a link to the root
      [`ROADMAP.md`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/ROADMAP.md),
      and the three vision axes. Kill the fossil content (wrong master claim, dead version numbers,
      EN older than FR). Keep the page in nav (inbound links exist).
- [ ] **f** — normalise `AI_ASSISTANT_CATALOG.md` FR anchors to the EN slugs (repo convention:
      identical anchors, heading text translated). ~30 anchors + their same-page index links.
- [ ] Nav (`mkdocs.yml`): a pilot-visible entry for checklists ("Checklists guidées" /
      "Guided checklists" → the veafAssist pilot anchor or a small dedicated page) and one for
      security ("Sécurité & permissions"), so the two biggest behaviour features are findable by
      name rather than as the 4th and 19th alphabetical Lua module.
- [ ] README (scripts dir): link `veafAssist.md` (only page with no README entry) and `veafRadio.md`
      (named as plain text at `:15`).

### Acceptance criteria

- [ ] Every new section in both languages, nav entries with `nav_translations`.
- [ ] `docs-check` green (it will now enforce `--parking` if `FIX-DOCAUDIT-CODE` 04 lands first —
      sequence the code lot's gate hardening **before** or **with** this PR).
- [ ] CHANGELOG entry; version bump ×3 manifests (shared with ticket 04's PR).

---

## 04 — The full CLI reference: 25 commands, options included

Status: ✅ done 2026-08-13 — `doc/CLI_REFERENCE.{md,en.md}`, 25 commands and 120 option entries per language, enumerated from the typer signatures and now gate-enforced
Type: feat
Files: a new `doc/CLI_REFERENCE.md` + `.en.md` (or a rebuilt TOOLS_REFERENCE §), `mkdocs.yml`,
cross-links from GUIDE / index / MIGRATION_GUIDE

David's call (2026-08-13, arbitration c): full command documentation is wanted **in addition to**
`--help`. Today `TOOLS_REFERENCE` covers 3 commands of 25 while three pages link to it as the
"référence complète"; the only honest inventory is the GUIDE's one-line-per-command table.

### Shape

- One page, both languages, one `###` section per command, grouped as `command_tree.py` groups them
  (`mission` / `convert` / `content` / `cockpit` / `dcs` + the 4 root commands), with the grouped
  spelling (`veaf-tools convert v5`) primary and the legacy flat alias noted once.
- Per command: one-sentence purpose (from the i18n help key, rewritten for prose), the arguments and
  options table (name, type, default, envvar where one exists), one realistic example, and a link to
  the owning long-form page (GUIDE section, PIPELINE_REFERENCE step, developer page) where one
  exists — this page is the *reference*, not the tutorial.
- Source of truth: `src/python/veaf-tools/veaf_tools/commands/*.py` typer signatures — enumerate,
  do not sample. The audit already extracted several inventories (capture-map's 6 options,
  update-dcs-data's 14, the updater's 8) — re-verify at writing time rather than trusting.

### Consistency obligations

- Retitle/redirect: `index.md:42`, `mission-maker/GUIDE.md:384,697`, `MIGRATION_GUIDE.md:378` point
  their "référence CLI" promises at this page; `TOOLS_REFERENCE` keeps the updater +
  `veaf-build` + release content under an honest title (ticket 02 already fixes its internal form).
- The `docs-check` CLI-coverage rule keys on command names — after `FIX-DOCAUDIT-CODE` 04 it will
  also key on option names. Land this with or after the gate hardening and it becomes
  self-enforcing for the next command someone adds.

### Acceptance criteria

- [ ] All 25 commands present, options enumerated from the typer signatures, both languages, in nav.
- [ ] The three "référence complète" links point here; `docs-check` green.
- [ ] CHANGELOG entry; version bump (shared with ticket 03's PR).
