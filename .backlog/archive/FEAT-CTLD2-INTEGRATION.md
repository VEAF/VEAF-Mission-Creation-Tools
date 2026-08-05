# FEAT-CTLD2-INTEGRATION — replace the bundled CTLD v1 with CTLD 2

**Status:** ✅ done — merged 2026-08-01 (PR #646), all six tickets, against CTLD 2.0.0-rc3.

Opened 2026-08-01. Design settled in a grilling session; every decision below was taken with David
and is not open for re-litigation by the implementer.

## Why

VMCT bundles an *adapted* concatenation of the ciribob CTLD v1 monolith
(`src/scripts/community/CTLD.lua`, 428 KB). [VEAF/CTLD](https://github.com/VEAF/CTLD) is its complete
OOP rewrite — `2.0.0-rc2` at the time of writing — with its own build, its own configuration model,
its own authoring tool and 1 100+ tests. VMCT switches to it.

Two things make this more than a file swap.

**The v1 configuration channel was half broken anyway.** [veaf.lua:4673](../../src/scripts/veaf/veaf.lua)
replaces `ctld.initialize` with a VEAF wrapper carrying ~170 lines of hardcoded configuration, and
the generated block sets `ctld.<key>` *before* calling it — so every key the wrapper also sets
(`slingLoad`, `crateWaitTime`, `hoverTime`, `unitLoadLimits`, `aircraftTypeTable`, `unitActions`…)
is silently overwritten. A mission maker writing `slingLoad: false` in `mission.yaml` has never had
any effect, with no message. Moving configuration out is not a loss of a single source of truth; it
replaces a channel that half worked with one that works and is validated.

**CTLD 2 auto-initialises on load** (`CTLD_bootstrap.lua`, unless `ctld.dontInitialize = true` is set
first) and reads a **complete YAML snapshot** from `ctld.configUser`, posted by a MISSION START
trigger *before* `CTLD.lua`. There is no merge: a missing *setting* falls back to the CTLD default
(and is named in the startup report), a missing *list* is genuinely removed.

## Decisions

1. **Hard switch.** One engine bundled, no `version:` selector. A dual engine would mean writing the
   four VEAF bridges twice and carrying two configuration surfaces.
2. **Configuration leaves `mission.yaml`.** `CTLD:` keeps only its on/off flag; `settings:` is
   removed and rejected by `validate` with a message pointing at the new file. No secondary channel —
   that is what produced the silent overwrite above.
3. **`ctld-config.yaml` sits next to `mission.yaml`**, is the mission's CTLD configuration, and is
   **injected by the VMCT build only**. A mission maker edits it with `ctld-tools.exe`; they never
   use that tool's own "inject into .miz" button in a VMCT context — the build would overwrite it.
4. **The default is read from the vendored engine**, never committed as a frozen snapshot: scaffolding
   extracts `ctld.configDefault` out of `CTLD.lua`. A committed 1000-line copy would silently deprive
   new missions of every crate, troop and aircraft type a later CTLD adds — the "missing list =
   removed" rule.
   **Settled during implementation:** the VEAF patch this decision assumed turned out to be *empty*.
   Of the eight settings hardcoded in `veaf.lua`, three already matched the CTLD 2 default,
   `crateWaitTime` no longer exists in the engine, `slingLoad` was an inconclusive experiment
   (dropped), and the three hover distances are aligned on CTLD's values. Same call for the
   per-aircraft capacities, which diverged on four types. The seeded file is the default catalogue
   verbatim, and the patch mechanism was not built.
5. **VEAF controls initialisation** (option *ii* of three): the injected trigger sets `configUser`
   **and** `dontInitialize = true`; `veaf.lua` overrides the logger, then calls `ctld.initialize()`.
   Letting it auto-start would put CTLD's whole init — including the startup report that names bad
   configuration — outside the VEAF log channel.
6. **The `logistic #001..020` / `pickzone #001..020` reserved names are dropped.** They existed
   because v1 had no discovery; CTLD 2 discovers `LGZ_` / `TRZ_` prefixed zones at boot. Verified: no
   VMCT code produces or expects those names.
7. **Log levels stay VEAF's**, by code, not by config: CTLD 2 has no log level at all
   (`ctld.utils.log` labels the text and sends everything to `env.info`). One override of
   `ctld.utils.log` replaces today's seven.
8. **New APIs, not the legacy wrappers** — `legacy_api.lua` logs a `DEPRECATED` line on every call.

## What CTLD 2 owes us

Four gaps found while auditing the bridges, filed in the CTLD repo as `FEAT-VMCT-INTEGRATION`
(+ `FIX-SHIP-ZONE-ANCHOR-PARITY`): logistic zone discovery by unit type, ship troop-zone discovery,
a public beacon API for a caller that is not a pilot, and — found while comparing the catalogues —
**`capabilitiesByType` entries for aircraft VMCT has configured for years and CTLD 2 does not
know**: Ka-50, Ka-50_3, the four SA342 variants and the Yak-52.

**All four shipped** (CTLD PRs #79, #80, #86). The aircraft lot settled the question this PRD
originally got wrong: an aircraft with no entry does **not** lose the CTLD menu — the root menu,
Check Cargo, RECON and JTAC status are ungated, and only the transport half depends on the entry.
So the four Gazelles and the Yak-52 gained one (one soldier, no crates, as v1 declared) and the
**Ka-50 deliberately did not**: v1 let it sling crates and carry troops by *absence* from its
tables, not by decision, and an all-false entry would advertise a transport that is not one.

## Definition of done

- A VMCT mission with `CTLD: true` runs CTLD 2, configured by its `ctld-config.yaml`, with the
  startup report in the VEAF log.
- No `ctld.*` assignment is emitted by `lua_config_generator` any more, and
  `veaf.ctld_initialize_replacement` is gone.
- The four VEAF modules that talk to CTLD use the v2 manager APIs.
- `mission.yaml` carrying `CTLD: {settings: …}` fails `validate` with an actionable message.
- Documentation updated in FR **and** EN, `poetry run docs-check` green.

## Out of scope

- **CTLD scene plugins** ([`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins), e.g. the Metal
  FARP). Verified: the v1 copy VMCT bundles contains no Metal FARP, so no VMCT mission loses
  anything. Bundling plugins is its own lot if ever wanted.
- Foothold, which ships its own CTLD as a `custom_scripts` entry and stays incompatible with the
  VEAF one — the `foothold` conversion profile is unchanged.

---

## 01 — vendor the CTLD 2 artifact and rewrite its drift-watch entry

**Status:** ✅ done — vendored at 2.0.0-rc3, which carries every API this lot calls. Re-vendor the stable when it is cut; the watch will say so on its own, since `/releases/latest` starts resolving the moment a non-prerelease exists and the pin will then differ.

No dependency. Do this first: ticket 02 reads the default catalogue out of the vendored file.

### What changes

- Replace `src/scripts/community/CTLD.lua` with the `CTLD.lua` asset of the target VEAF/CTLD release
  (1.1 MB, single file, i18n dictionaries already merged in by its build). Verbatim — no VEAF edit
  of any kind, that is the point of the rewrite.
- Rewrite the `ctld` entry in [vendored.yaml](../../../vendored.yaml):
  - `source: https://github.com/VEAF/CTLD`
  - **drop `upstream`** and the `ciribob/DCS-CTLD` watch. CTLD 2 is a rewrite, not a fork: "did the
    origin ship something to port?" no longer has an answer. Say so in a comment — the file's header
    documents the two-watch convention for forks, and a reader will ask.
  - `vendoring: verbatim` (was `adapted`)
  - `manual_steps`: "re-download the `CTLD.lua` asset from the matching VEAF/CTLD release."
  - `watch:` a single `{ kind: github-release, repo: VEAF/CTLD, pinned: <tag> }`
- Update `pinned` to the human-readable shipped version.

### Watch out

`vendored_check_cli.latest_release()` calls `/repos/{repo}/releases/latest`, which the GitHub API
resolves to the latest **non-prerelease**. While VEAF/CTLD has only `-rc` tags it returns 404 →
`None` → "unresolved": no false positive, but no watch either. That is acceptable and self-correcting
once 2.0.0 ships — do **not** work around it by switching to `/releases` and taking the first entry,
which would make every rc a drift alert.

### Acceptance

- `poetry run check-vendored` runs clean and reports the `ctld` entry as unresolved (not as drift)
  while the target is a pre-release.
- No occurrence of `ciribob` remains in the `ctld` entry.

### Tests

- The vendored-drift unit tests cover an entry with a single watch and no `upstream`; add the case
  if the current suite assumes two watches for a non-`verbatim` entry.

---

## 02 — the VEAF configuration patch, and generating `ctld-config.yaml` at build time

**Status:** ✅ done — the patch turned out empty; see the PRD's decision 4.

Depends on 01.

### What changes

**A versioned VEAF patch.** A short YAML file in the repo holding *only* VEAF's deviations from the
CTLD defaults — the settings hardcoded in [veaf.lua:4536-4587](../../../src/scripts/veaf/veaf.lua)
today. Never a full snapshot (see PRD decision 4).

| Hardcoded today | Where it goes in the CTLD 2 catalogue |
|---|---|
| `addPlayerAircraftByType`, `loadCrateFromMenu`, `slingLoad`, `crateWaitTime` | same names, `mm_facing` |
| `minimumHoverHeight` 5, `maximumHoverHeight` 15, `maxDistanceFromCrate` 8, `hoverTime` 10 | same names |
| `unitLoadLimits` (10 types), `internalCargoLimits` (2) | **reprojected** into `capabilitiesByType.<type>` |
| `aircraftTypeTable` (13 types) | **the presence of a `capabilitiesByType` entry** is what makes a type a transport |
| `unitActions` (6 types) | `cratesEnabled` / `troopsEnabled` per type |
| the 20 `logistic #NNN` / `pickzone #NNN` reserved names | **dropped** (PRD decision 6) |

Once the CTLD-side ticket 01 lands, the patch also carries `logisticUnitTypes` — the carrier and FARP
types `autoInitializeAllLogistic()` scans for today. **Five types, not six:** `FARP Ammo Storage` is
the *display* name of the object whose type id is `FARP Ammo Dump Coating` (DCS sets
`swapped_names = true` on it), and `getTypeName()` returns the type id — so that entry has never
matched anything in any VEAF mission. Do not carry it over.

Reprojection is the real work here: v1 spread one aircraft's capabilities over four tables keyed by
type; v2 has one record per type. Diff the result against the CTLD default per type — several VEAF
values may already *be* the default, in which case they leave the patch.

**Generation at build.** Read `ctld.configDefault` (a long-bracket string, `CTLD.lua:2786`) out of
the vendored artifact, parse it, apply the patch, write a complete snapshot. Decide and record how:
depend on the `ctld-tools` package from the CTLD repo, or re-implement the load/patch/dump (~200
lines with `ruamel.yaml`, which VMCT already uses). Prefer the dependency if it can be consumed
without publishing to PyPI; the catalogue must not be duplicated either way.

**Where the generated file goes.** The mission folder gets a `ctld-config.yaml` when scaffolded, and
`prepare` / the build regenerate it *only if absent* — never overwrite a mission maker's edits.
A mission whose file is absent gets no `configUser` at all and CTLD runs on its own defaults.

### Open decision to record in the ticket's outcome

Whether VMCT forces `i18n_lang` in the generated file from the mission's language. Recommended yes,
**at generation only** — so it is a default the mission maker can then change, not a value the build
re-imposes on every run.

### Acceptance

- The generated snapshot is complete (parses, carries `configVersion`, every list present).
- Every VEAF value from the table above is reflected, verified key by key against the generated file.
- Regenerating after a CTLD version bump produces a snapshot carrying the new catalogue entries.
- An existing `ctld-config.yaml` is never overwritten.

### Tests

- unit: patch application over a miniature default catalogue (settings, per-type reprojection).
- unit: extraction of `ctld.configDefault` from a fixture `CTLD.lua`, including a `]]` inside the
  YAML (the long bracket level is not guaranteed to be `[[`).
- unit: absent file → generated; present file → untouched.

---

## 03 — inject the config trigger, retire `settings:`

**Status:** ✅ done

Depends on 02.

### What changes

**Injection.** A MISSION START trigger, ordered **before** the one loading `CTLD.lua`, containing:

```lua
ctld = ctld or {}
ctld.dontInitialize = true      -- VEAF calls ctld.initialize() itself (PRD decision 5)
ctld.configUser = [==[ …the mission's ctld-config.yaml, verbatim… ]==]
```

Pick the long-bracket level defensively: the YAML can contain `]]`. Only inject when the CTLD module
is enabled **and** the mission carries a `ctld-config.yaml`; when the file is absent, still inject
`dontInitialize` alone — VEAF owns the init either way.

**`lua_config_generator`.** Delete the CTLD block
([lua_config_generator.py:1380-1388](../../../src/python/veaf-tools/veaf_libs/lua_config_generator.py)):
no more `ctld.<key> = value`, no more `ctld.initialize()`. The `external_modules["ctld"]` internal
representation keeps only `enabled`. CSAR and Skynet are untouched — they still use that channel.

**`mission.yaml`.** `CTLD:` becomes a plain boolean. Remove the
`# extended: CTLD -> { enabled: true, settings: … }` comment from
[src/defaults/mission-folder/mission.yaml](../../../src/defaults/mission-folder/mission.yaml) — the
defaults-lockstep rule of `CLAUDE.md` §9.7 — and replace it with a pointer to `ctld-config.yaml`.

**`validate`.** A `CTLD:` entry carrying `settings:` is an **error**, not a warning and not a silent
ignore: "CTLD 2 is configured in `ctld-config.yaml` (edit it with ctld-tools) — `settings:` is no
longer read." A warning would reproduce exactly the silent-overwrite failure this lot removes.
Both message strings go in `locales/fr.json` and `locales/en.json`.

### Acceptance

- A built `.miz` shows, in order: the config trigger, then `CTLD.lua`, then the rest.
- A `ctld-config.yaml` containing `]]` round-trips intact.
- `CTLD: {enabled: true, settings: {hoverPickup: true}}` fails `validate` with the new message.
- `CTLD: true` alone builds and runs.

### Tests

- unit: trigger ordering in the produced `.miz` (the existing MISSION START injection tests cover the
  index-shift machinery — reuse it, do not re-invent).
- unit: bracket-level escalation on a payload containing `]]`.
- unit: `lua_config_generator` emits nothing CTLD-related, and still emits CSAR/Skynet.
- unit: the `validate` rule, FR and EN.

---

## 04 — retire `veaf.ctld_initialize_replacement`, route the logs, own the init

**Status:** ✅ done

Depends on 03.

### What changes

Delete [veaf.lua:4490-4674](../../../src/scripts/veaf/veaf.lua) — the whole "changes to CTLD" block,
~185 lines — and put back, in its place:

```lua
if ctld and veaf.isEnabled("ctld") then
  -- one override replaces the seven of v1 (ctld.p, Id, logger, logError/Info/Debug/Trace):
  -- CTLD 2 routes all 241 of its log calls through ctld.utils.log.
  local _l = veaf.loggers.new("CTLD", ...)
  ctld.utils.log = function(level, fmt, ...) --[[ map level → VEAF method, then delegate ]] end
  ctld.initialize()
end
```

Three details that will bite otherwise:

- **Level names do not map 1:1** — CTLD emits `INFO` / `WARN` / `ERROR` / `DEBUG`, VEAF's logger has
  `warn` where CTLD says `WARN`. Write the mapping table explicitly and default unknown levels to
  `info` rather than indexing nil.
- **The override must be in place before `ctld.initialize()`**, or the startup report — the whole
  reason for taking control of the init (PRD decision 5) — is written before the logger exists.
- **`configurationCallback` disappears.** No caller replaces it: mission-specific configuration now
  lives in `ctld-config.yaml`.

The `veaf.ctld_initialize` / `veaf.ctld_initialized` globals go with the block. Grep for them first
— a mission script in the wild may reference them, in which case the removal is worth a line in the
migration guide (ticket 06).

Also fix the two stale help messages in
[veafTransportMission.lua:715](../../../src/scripts/veaf/veafTransportMission.lua), which tell the
user to call `ctld.autoInitializeAllHumanTransports` / `autoInitializeAllLogistic` — both gone.

### Acceptance

- CTLD initialises once, after the VEAF logger is in place, and its startup report appears in the
  VEAF log channel.
- `CTLD: false` → CTLD is neither bundled nor initialised, and nothing errors.
- No reference to `ctld_initialize_replacement` remains.

### Tests

- Lua (`poetry run test-lua`): the log override maps each level, unknown level → `info`.
- Lua: `initialize()` is called exactly once, after the override.
- The CTLD mock in `test/lua/dcs_mocks.lua` needs updating to the v2 surface — it currently models v1
  globals.

---

## 05 — port the four VEAF modules to the v2 manager APIs

**Status:** ✅ done — ported against CTLD `develop`, now vendored as 2.0.0-rc3, so the scaffold assertion on `logisticUnitTypes` / `troopZoneShipTypes` runs for real.

Depends on 04 **and** on the CTLD-side lots `FEAT-VMCT-INTEGRATION` + `FIX-SHIP-ZONE-ANCHOR-PARITY`
shipping in a rc3. Do not start before: the beacon API does not exist yet.

### The bridges, one by one

| Site | v1 | v2 |
|---|---|---|
| [veafSpawnAircraft.lua:289](../../../src/scripts/veaf/veafSpawnAircraft.lua) | `ctld.JTACAutoLase(g, code, false, "all", nil, radio)` | `CTLDJTACManager.getInstance():autoLase(…)` — same signature |
| [veafSpawnAircraft.lua:223](../../../src/scripts/veaf/veafSpawnAircraft.lua), `:669` | `ctld.cleanupJTAC(g)` | `CTLDJTACManager.getInstance():stopAutoLase(g)` |
| [veafGrass.lua:1000](../../../src/scripts/veaf/veafGrass.lua) | `builtFOBS` + `logisticUnits` inserts | `CTLDZoneManager.getInstance():registerFOBAsLogistic(name, point, radius, coalition)` |
| [veafSpawnGround.lua:186](../../../src/scripts/veaf/veafSpawnGround.lua) | same, plus beacon + `fobBeacons` | `registerFOBAsLogistic` + the new beacon API |
| [veafSpawnEffects.lua:32](../../../src/scripts/veaf/veafSpawnEffects.lua) | `logisticUnits` insert | `registerFOBAsLogistic` |
| [veafGrass.lua:1302](../../../src/scripts/veaf/veafGrass.lua) | `spawnRadioBeaconUnit` + `createRadioBeacon` | `CTLDBeaconManager.getInstance():createAtPoint(point, coalition, country, opts)` |

Use the **v2 APIs, never `legacy_api.lua`** (PRD decision 8): each wrapper logs a `DEPRECATED` line
on every call, and `JTACAutoLase` is called on every JTAC spawn.

Three v1 state tables have no equivalent and must go, not be re-created VEAF-side:

- `ctld.builtFOBS` — `CTLDFOBManager` owns FOB state (`getFOBsForCoalition`, `listFOBs`).
- `ctld.fobBeacons` / `ctld.beaconCount` — the beacon returned by `createAtPoint` carries its own
  `vhf` / `uhf` / `fm`; read them from it where VMCT displays frequencies, and let the manager own
  the numbering. **Check every VEAF read of `fobBeacons`** before deleting it — the FOB beacon
  frequencies are shown to pilots somewhere.

Pair each `registerFOBAsLogistic` with `unregisterLogistic` where VEAF destroys the FOB. v1 leaked
these entries; v2 gives us the means not to, and a stale logistic zone on a destroyed FOB is a
gameplay bug.

### Acceptance

- A FARP built in game is a working logistic point, carries its beacon, and its frequencies are
  displayed as before.
- Destroying it removes the logistic zone.
- A spawned JTAC lases and stops lasing.
- No `DEPRECATED` line from CTLD in the log of a normal mission.

### Tests

- Lua per bridge, against an updated v2 CTLD mock.
- Live DCS check (this is spawn-and-beacon behaviour; the unit tests cannot see it) — hand the list
  of four scenarios to David rather than driving his session.

---

## 06 — documentation: the new CTLD mode of operation

**Status:** ✅ done

Can proceed alongside 02→04; finish it once 05 has settled the runtime behaviour.

### What changes

The mission maker's mental model changes on three points, and all three are currently documented the
old way:

1. **Configuration lives in `ctld-config.yaml`, edited with `ctld-tools.exe`** — not in
   `mission.yaml`. Say plainly that the tool opens in a browser on a double-click, that the build
   injects the file, and that its own "inject into .miz" button must **not** be used on a VMCT
   mission (the next build would overwrite it).
2. **Zones are named by prefix** — `LGZ_` (logistic), `TRZ_` (troops), `WPZ_`, `EXZ_`, `AIZ_` —
   discovered at boot. The reserved names `logistic #001..020` and `pickzone #001..020` are gone.
   Note the shift for anyone migrating: `logistic #001` designated a **unit or static** and the zone
   followed the object; `LGZ_` is an **editor zone**, and following a moving object now means
   attaching the zone to a unit in the ME (Moving Zone).
3. **What VEAF sets for you** — the values from the VEAF patch (ticket 02), and the fact that they
   are the *starting point* of a mission's config, not a floor: editing `ctld-config.yaml` can undo
   them.

Pages to touch: the CTLD sections of `doc/mission-maker/GUIDE.md`, `doc/MISSION_YAML_REFERENCE.md`
(the `CTLD:` entry loses `settings:`), `doc/TOOLS_REFERENCE.md`, `doc/LUA_API_REFERENCE.md` (the
`veaf.ctld_*` functions are gone), and the migration guide. Each in **FR and EN**, with explicit
English anchors on any section linked from elsewhere.

### Acceptance

- `poetry run docs-check` green.
- No page still shows `CTLD: { settings: … }` or the reserved zone names.
- A reader who has never used CTLD 2 can go from a blank mission folder to a configured mission
  without reading the CTLD repo's own documentation — link to it, don't duplicate it.

### Out of scope

CTLD's own documentation (gameplay, crates, JTAC…) lives at veaf.github.io/CTLD and stays there.
VMCT documents the *integration*, not the script.
