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
| 01 | [`security`: set passwords at L1, not just L9](tickets/01-security-l1-passwords.md) | ✅ |
| 02 | [RADIO: expose `create_menus`](tickets/02-radio-create-menus.md) | ✅ |
| 03 | [Apply to the ten Foothold missions](tickets/03-apply-to-foothold.md) | ✅ |
| 04 | [`_ICAO_<code>` in the mission file name (server real weather)](tickets/04-icao-mission-naming.md) | ✅ |

## Note on the hash algorithm

The v5 hashes are **SHA-1** (40 hex chars — confirmed: `sha1("veaf_foothold_2026")` is exactly
the `2a4efd…` in his file). `mission.yaml` documents **SHA-256**. The stored hashes are therefore
not portable and must be regenerated; the runtime comparison is a plain table lookup, so
whichever algorithm the mission-maker uses must match what `veafSecurity` receives. **Checked: the Lua hashes with SHA-1**
(`veafSecurity._checkPassword` → `sha1.hex(password)`), so the documentation was wrong, not the
data. David's v5 hashes are reused verbatim, and the reference page is corrected.
