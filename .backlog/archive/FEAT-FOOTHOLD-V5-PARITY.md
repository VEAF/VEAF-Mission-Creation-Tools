# FEAT-FOOTHOLD-V5-PARITY — two mission.yaml gaps the v5 Foothold relied on

Status: ✅ done

## Context

David asked whether the new v6 Foothold Caucasus misses anything the previous hand-maintained
version did (`d:\dev\_VEAF\VEAF-Foothold-Caucasus`, v3.6.0 — original Lekaa `.miz` + his own
`VEAF_common.lua` + VEAF injection + radio presets).

Comparing his `VEAF_common.lua` line by line against the generated `veaf-config.lua`, most of it
is covered: MiST + veaf-scripts, `veafSpawn` / `veafWeather` / `veafShortcuts` / `veafRemote`
initialisation, the era, the twelve Foothold scripts in order, the radio presets, and the DCS
`options` (identical — `easyCommunication: false`, `optionsView: onlyallies`,
`unrestrictedSATNAV`, `userMarks`, verified inside the built `.miz`).

Three things were missing. One is pure configuration and needs no code:
`veaf.silenceAtcOnAllAirbases()` → `mission.silence_atc_on_all_airbases: true`, which exists
already.

The other two **cannot be expressed in `mission.yaml` at all**, which is what this lot fixes.

## Gap 1 — a password can only be set at level L9, the weakest

His file set the same password twice, and that was not redundancy:

```lua
veafSecurity.password_L9["2a4efd…"] = true
veafSecurity.password_L1["2a4efd…"] = true
```

`security.password_hashes` in `mission.yaml` emits **`password_L9` only**
(`lua_config_generator`), and the levels are ordered `L0 = 90 > L1 = 10 > L9 = 1` — L9 being
"the lowest possible security", as the v5 `missionConfig.lua` comments put it. A password at L9
therefore opens **only** L9 gates:

| Gate | Used by | Accepts a password at |
|---|---|---|
| `checkSecurity_L9` | `veafCasMission`, `veafSpawnCore:139`, `veafRemote` admin | L9, L1 or L0 |
| `checkSecurity_L1` | `veafSpawnCore:142` (the sensitive spawns), `veafTransportMission` | **L1 or L0** |
| `checkPassword_L1` | **marker authentication** (`veafSecurity:462`), `veafRemote:166/215` | **L1 or L0** |

So a mission configured through `mission.yaml` today cannot authenticate a marker, run a
transport mission, or use the sensitive spawns — whatever password it declares. There is no
`password_l1_hashes` key.

## Gap 2 — the radio menus cannot be suppressed

His file called `veafRadio.initialize(true, true)`: `skipHelpMenus` **and** `dontCreateMenus`.
The generator emits `veafRadio.initialize(true)`, because the RADIO module exposes only
`help_menus`. With `dontCreateMenus` unset, `veafRadio._refreshRadioMenu` builds the whole VEAF
F10 menu.

That combination — no menu, password-protected markers — was the mission's security posture: a
regular player had no route to the VEAF commands. The v6 mission as it stands is **more
permissive than the v5 one**: menu open to everyone, and (per gap 1) no working password.

David's decision: **keep the menu hidden**, and restore the passwords.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | `security`: set passwords at L1, not just L9 | ✅ |
| 02 | RADIO: expose `create_menus` | ✅ |
| 03 | Apply to the ten Foothold missions | ✅ |
| 04 | `_ICAO_<code>` in the mission file name (server real weather) | ✅ |

## Note on the hash algorithm

The v5 hashes are **SHA-1** (40 hex chars — confirmed: `sha1("veaf_foothold_2026")` is exactly
the `2a4efd…` in his file). `mission.yaml` documents **SHA-256**. The stored hashes are therefore
not portable and must be regenerated; the runtime comparison is a plain table lookup, so
whichever algorithm the mission-maker uses must match what `veafSecurity` receives. **Checked: the Lua hashes with SHA-1**
(`veafSecurity._checkPassword` → `sha1.hex(password)`), so the documentation was wrong, not the
data. David's v5 hashes are reused verbatim, and the reference page is corrected.

---

## 01 — `security`: set passwords at L1, not just L9

Status: ✅ done
Type: fix

### Why

See the PRD, gap 1. `security.password_hashes` emitted `veafSecurity.password_L9`
only, and L9 is the weakest level: the gates that matter — marker authentication
(`checkPassword_L1`), the sensitive spawns (`veafSpawnCore:142`), transport missions — accept
**L1 or L0 only**. A mission configured through `mission.yaml` therefore had a password that
could not authenticate a marker, whatever it was set to.

The hand-written v5 missions set both levels for exactly this reason.

### Also: the documented hash algorithm was wrong

`MISSION_YAML_REFERENCE` said **SHA-256** and gave `e3b0c442…` as the example — which is the
SHA-256 of the empty string. But `veafSecurity._checkPassword` computes `sha1.hex(password)`.
So every hash produced by following the documentation could never match, and the mission looked
protected while being wide open. Confirmed the other way round too: `sha1("veaf_foothold_2026")`
is exactly the `2a4efd…` in David's v5 file.

### Tasks

- [x] Emit `password_L1` **and** `password_L9` for each `password_hashes` entry.
- [x] Leave `password_mm_hashes` in its own `password_MM` table (no level cascade — it is
      checked by `checkPassword_MM` alone).
- [x] Tests: both levels emitted; MM stays out of the cascade.
- [x] Fix the algorithm in `MISSION_YAML_REFERENCE` (FR + EN): SHA-1, with a working example, a
      warning that the page used to say SHA-256, and commands to generate one.
- [x] Document that `password_hashes` reaches L1 and L9.

---

## 02 — RADIO: expose `create_menus`

Status: ✅ done
Type: feat

### Why

See the PRD, gap 2. `veafRadio.initialize` takes
`(skipHelpMenus, dontCreateMenus)`, but the RADIO module exposed only `help_menus`, so a mission
could not suppress the VEAF F10 menu. The v5 Foothold called `initialize(true, true)`: no menu,
commands reachable only through password-protected map markers.

### Design

`init.create_menus: false` → `dontCreateMenus = true`. The YAML says what the mission-maker
wants; the negation happens on the way out, because the Lua parameter is phrased negatively.

The key is **optional**, not defaulted: `_MODULE_INIT_PARAMS` entries whose default is `None`
are omitted from the call unless declared. A mission that never mentions `create_menus`
therefore generates the exact same `veafRadio.initialize(true)` as before — adding the key
changes nothing for anyone else.

### Tasks

- [x] `create_menus` in `_MODULE_INIT_PARAMS`, with the optional-when-`None` mechanism.
- [x] `_NEGATED_INIT_KEYS` for the YAML→Lua negation.
- [x] Tests: `false` → `initialize(true, true)`; `true` → `initialize(true, false)`; omitted →
      `initialize(true)` unchanged (regression guard).
- [x] Document the RADIO `init:` fields in `MISSION_YAML_REFERENCE` (FR + EN), including why
      hiding the menu goes with `security:`.
- [x] mypy: renamed the loop variable — reusing `yaml_key` clashed with a later loop in the same
      scope that assigns `None` to it, which mypy caught.

---

## 03 — Apply the v5 posture to the ten Foothold missions

Status: ✅ done
Type: chore

### What was applied

Per David's decision — **menu hidden, passwords restored**:

| Setting | Value |
|---|---|
| `mission.silence_atc_on_all_airbases` | `true` (the v5 `VEAF_common.lua` last line) |
| `security.password_hashes` | SHA-1 of `veaf_foothold_2026` |
| `security.password_mm_hashes` | SHA-1 of `veaf_foothold_gamemaster` |
| `modules.SECURITY` | `true` (was commented out) |
| `modules.RADIO.init.create_menus` | `false` |

Verified on all ten by generating the config Lua through the real pipeline
(`_normalize_mission_yaml` → `generate_config_lua`): `veafRadio.initialize(true, true)`,
`password_L1` + `password_L9`, `password_MM`, `veaf.silenceAtcOnAllAirbases()`,
`veaf.SecurityDisabled = false`. All ten validate.

### Two incidents worth recording

**The sync script corrupted eight files.** `Get-Content`/`Set-Content` without an explicit
encoding do not round-trip UTF-8 on Windows PowerShell 5.1: eight `mission.yaml` came back with
18 `U+009D` characters each, in the em-dash and box-drawing comments of the `modules:` block. No
functional data was touched, but the files no longer parsed as YAML. Both scripts now read and
write through `[System.IO.File]::ReadAllLines/WriteAllLines` with an explicit UTF-8 encoding, and
the eight files were repaired by re-injecting the clean block from the reference.

**Normandy needed hand work, as designed.** The sync skips it (different conversion profile), and
its `modules:` block must stay its own — the `foothold-ww2` profile leaves the VEAF CTLD
available, so copying Caucasus's block would have wrongly disabled it. `security:` and
`create_menus` were applied surgically instead.

### Tasks

- [x] Apply the five settings to the Caucasus reference, validate.
- [x] Add `security` to the sync script's default key set.
- [x] Propagate to the eight other `foothold` missions.
- [x] Apply `silence_atc_on_all_airbases` per mission (it sits in `mission:` beside the name).
- [x] Hand-apply `security` + `create_menus` to Normandy without touching its module set.
- [x] Fix the UTF-8 round-trip in both PowerShell scripts; repair the eight damaged files.
- [x] Re-verify the generated Lua and `validate` on all ten.

---

## 04 — `_ICAO_<code>` in the mission file name (server-side real weather)

Status: ✅ done
Type: docs

### Why

David noticed the built `.miz` had lost the `ICAO` part of its name. It is not cosmetic: the
**RealWeather extension of DCSServerBot** reads `_ICAO_<code>` from the mission's **file name**
and fetches that airfield's live METAR at mission start. Losing the marker silently loses live
weather on the servers.

Working examples he gave:

```
VEAF_OpenTraining_Falklands_ICAO_SFAL_20250522.miz
VEAF_OpenTraining_Caucasus_ICAO_URSS_20251216.miz
MA_Foothold_GCW_V4.2.0_Modern_ICAO_EDFH.miz
```

Note `URSS` is **Sochi-Adler's ICAO code**, not "the USSR" — a wrong assumption made earlier in
the analysis and corrected by looking at the three examples side by side (`SFAL`, `EDFH`, `URSS`
are all four-letter codes).

This is a **different mechanism** from `veaf-tools`' own `airport_icao` in `versions.yaml`, which
fetches a METAR at **build** time and freezes it into the `.miz`. The server-side one re-evaluates
at every mission start, which is what a permanent server wants.

### Choosing a code: existing is not enough, it must be *fresh*

Two conditions: an airfield **on the theatre**, with a **live METAR station**. Checked every
candidate against NOAA rather than assuming, and the check paid off — the observation day is the
first two digits of the `DDHHMMZ` group:

| Theatre | Code | Airfield | Observation (day 28) |
|---|---|---|---|
| Caucasus | `URSS` | Sochi-Adler | 28 ✅ |
| Germany CW | `EDFH` | Frankfurt-Hahn | 28 ✅ |
| Persian Gulf | `OMDB` | Dubai | 28 ✅ |
| Syria | `OSDI` | Damascus | 28 ✅ (David's pick over Larnaca — on the map) |
| Sinai + Sinai North | `HECA` | Cairo | 28 ✅ |
| Iraq | `ORBI` | Baghdad | 28 ✅ |
| Kola | `ULMM` | Murmansk | 28 ✅ |
| Normandy | `LFRK` | Caen-Carpiquet | 28 ✅ |
| Afghanistan | `OAIX` | Bagram | 27 — **1 day behind**, least bad of the theatre |

Normandy was solved with David's suggestion: look through the theatre's airfield list
(`airdromes.yaml`, 90 entries) for one that still exists today. Heathrow, Orly, Jersey, Beauvais,
Deauville and Carpiquet all qualify; **Carpiquet** wins because it sits in the middle of the
combat area *and* reports.

Afghanistan is the interesting case: all 29 airfields were tested and **none** is fresh — Kabul a
month behind, Herat 16 days, Bagram a day, and Maymana/Shindand/Bost/Farah/Zaranj/Ghazni have no
station at all (404).

Two answers were defensible: omit the marker (authored weather stands), or take the least bad and
know it. **David chose `OAIX` (Bagram)** — a day-old real weather beats a frozen one for his use.
Re-checked before applying: still one day behind. The documentation now presents both options
instead of prescribing the omission.

### Tasks

- [x] Apply `VEAF_Foothold_<Theatre>_ICAO_<code>` to all ten, Afghanistan included (`OAIX`).
- [x] Verify the produced file names carry `_ICAO_<code>_<date>.miz`, matching David's examples.
- [x] Re-validate the ten.
- [x] Document the convention in `MISSION_YAML_REFERENCE` (FR + EN): that the file name is an
      interface, the `_ICAO_` marker, the `.miz`-suffix trick for a date-less fixed name, and the
      one-line freshness check with the day-of-observation rule.
- [x] Re-take the mission.yaml backup.

### Notes

The naming convention was documented **nowhere** — it lived in the head of whoever set up the
servers. That is the real fix here; the nine names are just today's application of it.
