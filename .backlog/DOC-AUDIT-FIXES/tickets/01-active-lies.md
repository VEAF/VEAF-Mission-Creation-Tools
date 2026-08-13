# 01 — Active lies: the security cluster, and every page stating the opposite of the code

Status: ⬜ ready
Type: fix
Files: ~35 pages ×2 languages under `doc/`, plus `src/defaults/mission-folder/mission.yaml` (one comment)

Every item below was verified against the code by the 2026-08-13 audit, with the evidence cited.
Fix FR and EN together. Where the doc describes the **decided** security model that the code has not
caught up with (tier names), leave the doc as is — `FIX-DOCAUDIT-CODE` 01 makes it true.

## A. Security — the pilot-facing lies

- [ ] `doc/pilot/GUIDE.md:299-302` (+ EN same lines) — delete the promise *"l'authentification reste
      valide pendant 10 minutes"* and rewrite §Sécurité on the real model: password checked per
      command for an unlisted pilot; a listed pilot's own level decides; an F10 menu **group acts at
      the level of its lowest-graded occupant** (DCS cannot tell who clicked); `_auth elevate`
      raises the group to the requester's level for 2 minutes (`veafSecurity.lua:581-591,624-627`,
      `ELEVATION_DURATION_SECONDS` at `:891`).
- [ ] `doc/pilot/GUIDE.md:283-287` tier table (+ EN) — add `OPEN` and the `MM` (Mission Master)
      gate: password-only, no identity, no tier or login ever opens it.
- [ ] `doc/pilot/GUIDE.md:340-341` FAQ (+ EN) — "mes commandes ne fonctionnent pas" must mention the
      lowest-occupant rule and `elevate`, not only `_auth`.
- [ ] `doc/pilot/README.md:27` (+ EN) — the "S'authentifier" row: no session any more; name `elevate`.
- [ ] `doc/mission-maker/scripts/veafSecurity.md:100` (+ EN `:101`) — delete *"l'accès est accordé
      pour `authDuration` minutes"*: `checkSecurity_L0/L1/L9` no longer consult
      `veafSecurity.authenticated` (`veafSecurity.lua:814-839`).
- [ ] `veafSecurity.md:114` (+ EN) — elevation requires the **explicit verb**: `_auth elevate` or
      `/secu elevate`; a plain `_auth <password>` elevates nothing (`veafSecurity.lua:576,624-627`).
- [ ] `veafSecurity.md:92-98` (+ EN) — document the `_auth logout` and `_auth elevate` verbs.
- [ ] `veafSecurity.md:154` (+ EN `:155`) and the prose at `:49` — **`veafSpawn.defaultSecurity` does
      not exist** anywhere in `src/` or `test/`; spawn security is a per-command literal
      (`veafSpawnCore.lua:161`, asserted against `veafSpawn.SECURITY_CHECKS` `:137-152`). Remove.
- [ ] `veafSecurity.md:~115` + `veafServerHook.md:11` (+ EN) — `/login` and `/secu login` are
      documented as chat commands; the hook dispatches only `send/code/restart/restartnow/halt/
      haltnow/pause` (`VEAF-Server-hook.lua:489-551`). The real routes: the `_auth` marker, the
      hidden `-login` alias (`veafShortcuts.lua:1061`), the niod `login` callback
      (`veafRemote.lua:151`).
- [ ] `veafServerHook.md:81` (+ EN `:80`) — `/secu login|logout|elevate` need level ≥ 10
      (`veafSecurity.lua:531-544`), not level 1; add `/pause` at level 10
      (`VEAF-Server-hook.lua:551-563`); reframe the grid off "déverrouiller les commandes".
- [ ] `veafSecurity.md:109-110` (+ EN) — soften "rien ne change pour un pilote listé": `_transport`
      still demands the password from everyone (code bug, `FIX-DOCAUDIT-CODE` 02); say so until
      fixed.
- [ ] The 11 stale `/secu login` session references, each replaced by the group-level model
      (`veafRadio.lua:271-309,569-582`): `veafRadio.md:229,355` · `veafCombatZone.md:331,400` ·
      `veafCarrierOperations.md:118` ("mot de passe requis" — an F10 entry has no password path) ·
      `veafCasMission.md:55,84` ("token de sécurité `/secu`") · `veafShortcuts.md:46` (comment:
      bypasses the per-command level check, not a session) · `README.md:36,100` (+ EN each).

## B. Factual inversions in script pages

- [ ] `veafSanctuary.md:28,56,70` (+ EN) — `coalition` is the **protected** coalition, not the one
      destroyed (`veafSanctuary.lua:442-515,575,592`; its own builder table at `:101` is right).
- [ ] `veafSanctuary.md:59,72-73` (+ EN) — `delay_instant`/`delay_spawn` defaults are **-1 =
      disabled**, not 0 (`veafSanctuary.lua:51,54`); `delay_instant` is seconds-in-zone before the
      kill; `:121-122` — no instant kill by default, and zones are not only editor trigger zones
      (polygon/radius APIs on the same page).
- [ ] `veafAirWaves.md:59-60,103-104` (+ EN) — `min/max_altitude_ft` gate **player detection**, not
      AI removal (`veafAirWaves.lua:832-843`); `:106` — `minimum_life_percent` is a percentage vs
      `100*life/life0`, default 0 (`:169,719-723`); add `setMinimumLifeForAiInPercent` (`:628`) to
      the builder table.
- [ ] `veafAssets.md:46,61` (+ EN) — `jtac` is the **laser code**, not a boolean
      (`veafAssets.lua:168,203` → `autoLase(groupName, laserCode, …)`).
- [ ] `veafAssets.md:9,16,140` (+ EN) — drop the carrier-management claim and the
      `veafCarrierOperations` dependency: no reference in `veafAssets.lua`; `:122` already says so.
- [ ] `veafAssets.md:128-132` (FR) — real root menu `ASSETS`, real English labels (`Respawn …`,
      `Get info on …`, `Dispose of …`), and a submenu only exists when `disposable`/`information`
      is set (`veafAssets.lua:30,44-68`). EN keeps the labels; FR must too.
- [ ] `veafWeather.md:160-163` (+ EN) — these are **remote** commands (`/weather`, `/atc`, `/atis`,
      `veafWeather.lua:1829-1831`), not `_weather` marker commands (no handler registered;
      `Keyphrase` is dead). Document `/atis`; port EN's `veafRemote` prerequisite note (`.en:157`)
      to FR.
- [ ] `veafCasMission.md:136-141` (+ EN) — add `spacing` (1-5), `password`, `disperse` (bare
      `disperse` = 15 s default since the refactor, `veafCasMission.lua:403,521-531`); state code
      defaults `size 1 / defense 1 / armor 1` (`:478-480`); `:147` — the CAS MISSION submenu exists
      from `initialize()` with a HELP entry (`:1226-1230`).
- [ ] `veafInterpreter.md` (+ EN) — **every example is invalid and now aborts** (unknown keys are
      fatal: `veafSpawnParser.lua:564`, `veafSpawnCore.lua:231-235`). `-spawn sa-11` → no `-spawn`
      alias exists, use `-sa11`/`-sa10`/`-sa6`; `laserCode 1688` → `laser`; `-convoy from A to B` →
      `dest`/`destination`; `-arty, rounds 10` → no `rounds` key (`shells`), and `-arty` expands to
      an M-109 group. Rewrite all examples with verified syntax; `:21` — the unit is destroyed
      **only when the command succeeds** (`veafInterpreter.lua:85-96`).
- [ ] `veafSpawn.md:122` (+ EN) — convoy `size` is not "0-5 véhicules": unbounded `_num`, default
      **10** (`veafSpawnParser.lua:180,306`), the `-convoy` alias randomises 6..15
      (`veafShortcuts.lua:1260`).
- [ ] `veafGrass.md:28,49` (+ EN) — the code tests the **unit** name for `FARP ` (`veafGrass.lua:
      197,211`), not the group name.
- [ ] `veafTransportMission.md:35,54` (+ EN) — `blocade` parses but generates **nothing** (empty
      `-- TODO`, `veafTransportMission.lua:418-422`). Say it plainly.
- [ ] Module IDs: `veafNamedPoints.md:3` `NAMED POINTS` → `NAMEDPOINTS`; `veafTransportMission.md:3`
      `TRANSPORT` → `TRANSPORTMISSION`; `veafGrass.md:3` and `veafAirbases.md:3` `—` → `GRASS`,
      `AIRBASES` (each registered; + EN each).
- [ ] The 14 FR + 14 EN page headers carrying retired per-module `**Version:** 1.x.x` lines — remove
      (single `veaf.BuildVersion` stamp since `FEAT-LUA-BUILD-STAMP`; only `veafAssist.Version`
      survives in code).
- [ ] `README.md:30,32,34` (+ EN) — F10 claims: no `Generate` entry (CAS is marker-driven);
      `MISSIONS` belongs to veafCombatMission and **veafAirWaves has no menu**
      (`veafAirWaves.md:119` is right); carrier root is `CARRIER OPS`, label `Start carrier air
      operations for 45 minutes` (`veafCarrierOperations.lua:26,859`).
- [ ] `veafAssist.md:26-33` (+ EN) — `Confirm this step` / `Skip this step` sit at the **top level**
      of the VEAF menu, not inside `Assistance` (`veafAssist.lua:724-752`).
- [ ] `enable` → `enabled` in the field tables of `veafAssets.md:53`, `veafSanctuary.md:65`,
      `veafCarrierOperations.md:47` (+ EN each) — the reader keys on `enabled`
      (`lua_config_generator.py:93,297-298,322,1253`).

## C. Reference pages — the YAML/CLI lies

- [ ] `MISSION_YAML_REFERENCE.md:189,202` (+ EN) — **security is ON by default**
      (`veaf.SecurityDisabled = false`, `veaf.lua:29`; no `security:` block emits nothing,
      `lua_config_generator.py:1405-1409`). Also fix the same wrong comment in
      `src/defaults/mission-folder/mission.yaml` (`disabled: true # … (default)`).
- [ ] `MISSION_YAML_REFERENCE.md:352,361-370` (+ EN) — `MIST` cannot be disabled: mandatory, an
      explicit disable is overridden with a warning (`lua_config_generator.py:260`,
      `mission_builder_worker.py:795-804`).
- [ ] `MISSION_YAML_REFERENCE.md:32` (+ EN) — stale sentence declaring `qra:`/`assets:`/`shortcuts:`
      top-level sections; `:233` says `qra:` no longer exists; QRA lives under `modules.QRA`.
- [ ] `MISSION_YAML_REFERENCE.md:382-405` (+ EN) — add the 6 missing module IDs of 32: `GROUNDAI`,
      `REMOTE`, `AIRBASES`, `TRANSPORTMISSION`, `SKYNET_MONITOR`, `I18N` (four are ON in the
      shipped default).
- [ ] `MISSION_YAML_REFERENCE.md:562` + `PIPELINE_REFERENCE.md:65` (+ EN) — kneeboard output path is
      `KNEEBOARD/<type>/IMAGES/presets[-<coalition>].png` (`presets_manager.py:2200`), as
      `PIPELINE_REFERENCE.md:209` already says.
- [ ] `PIPELINE_REFERENCE.md:250` (+ EN) — 87 → **100** aircraft in the shipped radio specs.
- [ ] `PIPELINE_REFERENCE.md:430,451` (+ EN) — inside `mission build`, weather variants land in
      `missions/<Base>_<name>.miz` (`build.py:405-413`); the bare `<name>.miz` form is
      `inject-weather` standalone only.
- [ ] `TOOLS_REFERENCE.md:317-327,809-810` (+ EN) — `--prerelease` with `6.0.1` is **rejected** by
      the code: a semver pre-release (`6.9.21-rc1`) is required (`veaf_build/cli.py:270-274`); the
      `published-latest` claim only holds for a `-`-suffixed version.
- [ ] `TOOLS_REFERENCE.md:96,491-508` (+ EN) — the updater moves only the two exe files
      (`veaf-tools-updater.py:660-694`); `buildDemoMission.cmd` & co and `src/build-scripts/` do not
      exist. `:294` — token order is `--token` → config → env (`cli.py:76-80`), as `:237` says.
- [ ] `FOOTHOLD.md:135-141` (+ EN) — the lowercase `stts:/ctld:/aien:` example is **silently
      ignored** by the build (IDs are uppercase, unknown ones dropped with a warning,
      `MISSION_YAML_REFERENCE.md:352,372`); `:38` — "dix cartes" → nine (its own list and profile
      table).
- [ ] `MIGRATION_GUIDE.md:333-335` (+ EN) — three mutually incompatible statements about duplicate
      v5 triggers; keep the true one (`:118`: removed automatically). `:266` —
      `veafDynamicConfig.lua` is dynamic **script-loading** config, not Dynamic Slots.
- [ ] `LUA_API_REFERENCE.md:169` (+ EN `:168`) — default language is `en`, not `fr`
      (`MISSION_YAML_REFERENCE.md:144`, `TOOLS_REFERENCE.md:179` agree).
- [ ] `mission-editing-mcp.md:726,730` (+ EN `:706,710`) — trim "zones non circulaires" from the
      out-of-scope list (today's `edit_zone` writes polygons, same page `:251-289`); EN `:708`
      `SI/ALORS` → IF/THEN; tag the six new sections with their wave/lot like every sibling group.
- [ ] `index.md:82,84` (+ EN) — `--version 6.0.5` in the quick start → a placeholder
      (`<version>`), not a hand-written stale number; same for `developer/GUIDE.md:378,561-562`
      (6.1.0), per the page's own rule at `:535-537`.
- [ ] `veafQraManager.md:287` (FR) — port EN's `active_at_start: false` route (the field is real,
      `lua_config_generator.py:907-910`).
- [ ] Ticket e (David): purge the self-narration blocks — `MISSION_YAML_REFERENCE.md:208`,
      `mission-maker/GUIDE.md:294`, `LUA_API_REFERENCE.md:76-86`, `ALIASES.md:212-214` — keep the
      *current* fact, drop the "this page used to say…" story and internal ticket IDs.

## D. Developer pages (from the same audit, same nature)

- [ ] `TESTING.md:265-266,272` (+ EN) — stylua action `@v5`, scope includes `test/lua/`, Lua ratchet
      `--cov-fail-under 72`; `:103` — 36 files; `:144-179` — add `test_veafAssist.lua` and
      `test_veafServerHook.lua`, refresh the per-suite counts (346/184/138/107/17 measured);
      `:185-192` — 7 of the 8 "uncovered modules" no longer exist; `:19` — "tous les modules" vs
      its own uncovered table.
- [ ] `developer/GUIDE.md:502` + `developer/README.md:88-89` (+ EN) — pre-commit commands must match
      CI: stylua over `src/scripts/veaf/ test/lua/`, ruff over the three trees + `ruff format
      --check`, mypy over `src/python/veaf-tools`; `GUIDE.md:496-507` — the job table: add
      `Lua Coverage` as blocking, note `dcs-mock-coverage` is `continue-on-error`; `:515-524` —
      docs-check runs three passes, not one; `:626` — release branches carry no `v`
      (`release/6.13.0`); `:66` — `openspec/` does not exist (→ `.backlog/`); `:63-64` — the tree
      must show `test/python/`.
- [ ] `developer/mission-editing-mcp.md:733` (+ EN `:716`) — the archived lot path
      (`.backlog/archive/FEAT-MCP-MISSION-EDITOR.md`).
- [ ] `developer/README.md:98` (+ EN) — TESTING.md is Lua-only; say where the Python side lives
      (`GUIDE.md:342-368`).

## Acceptance criteria

- [ ] Every A–D item fixed in both languages; `docs-check` green.
- [ ] No claim replaced by another unverified claim: each rewrite cites what the audit measured, or
      re-reads the code line given.
- [ ] `CHANGELOG.md` entry; version bump ×3 manifests.
