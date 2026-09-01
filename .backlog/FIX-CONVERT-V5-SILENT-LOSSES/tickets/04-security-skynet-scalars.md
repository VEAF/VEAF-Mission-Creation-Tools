# 04 — Carry the fourteen dropped scalars

Status: ✅ done — shipped 2026-08-17 (PR #757); in-game acceptance tracked on the PRD

Issue: [#725](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/725) (option 1) ·
Type: feat · Files: `mission_builder/config_migrator.py`, `veaf_libs/lua_config_generator.py`

David's call 2026-08-17: **report *and* implement** — ticket 02 makes every loss visible, this
ticket carries all fourteen keys rather than a chosen subset.

## The fourteen

**Security** — `veafSecurity.PASSWORD_L1`, `veafSecurity.password_L1`, `veafSecurity.authenticated`,
`veafCarrierOperations.DisableSecurity`.
**IADS** — `veafSkynet.DelayForStartup` (150 in Sharko's missions), `veafSkynet.DynamicSpawn`,
`veafSkynet.PointDefenceMode`.
**The rest** — `veafRadio.RadioMenuName` (`"BFR"`, player-visible), `veafRadio.radioMenu.title`,
`veafCombatZone.HideZoneNameFromGroupNames`, `veafSpawn.HideRadioMenu`,
`veaf.DEFAULT_GROUND_SPEED_KPH` (25), `veaf.DO_NOT_EXPORT_JSON_FILES`, `veaf.config.ww2`.

## Passwords: the destination exists, and porting them naively re-opens a security hole

Verified 2026-08-17, and it corrects the first draft of this ticket.

`mission.yaml` **already carries mission passwords**: `security.password_hashes:`, documented at
`lua_config_generator.py:202` as *"add SHA-1 hashes to restrict access"*, emitted at `:1432-1434`.
`veaf-pilots.txt` holds no password at all — it identifies pilots by UCID and level, and is where
the ADMIN tier comes from. So there is no question of where a hash goes: `security.password_hashes`,
same as `password_MM` already does through `security.password_mm_hashes`.

Two things make the extraction non-obvious:

- **`veafSecurity.lua:156-159` ships `PASSWORD_L0`/`PASSWORD_L1` hashes common to every mission, in
  a public repository.** `SECREV-2 / VMR-040` closed that: when a mission declares its own hashes,
  the generator writes `password_L0 = {}` / `password_L1 = {}` / `password_L9 = {}` **before**
  adding them, so the well-known password stops opening the mission. An extractor that copies a v5
  `PASSWORD_L1` into `password_hashes:` without checking its value will happily carry the **shipped
  public hash** into the mission's own list — and re-open exactly what VMR-040 closed. The two
  framework hashes must be recognised and **skipped**, not migrated.
- **Reassigning `veafSecurity.PASSWORD_L1` alone did nothing in v5.** `password_L1[PASSWORD_L1] =
  true` runs at module load, before the mission config executes, so a later reassignment of the
  constant never reached the table. What actually set a mission password is the pair
  `password_L1 = {}` then `password_L1["<hash>"] = true` — which is why Sharko measured *both* keys
  as lost. **Extract that pattern**, not the constant: a regex on
  `veafSecurity\.password_L1\s*\[\s*"([^"]+)"\s*\]`, mirroring `_PASSWORD_MM_RE`
  (`config_migrator.py:1789`), which has done this for `password_MM` all along.

`veafSecurity.authenticated` is runtime state, not configuration (`veafSecurity.lua:162` sets it at
load and `initialize()` sets it again). It gets no schema key — report it through ticket 02's
declared-loss list, and say so there rather than letting it fall in the gap.

## IADS

`_SKYNET_INIT_RE` (`config_migrator.py:743`) matches only the **call**
`veafSkynet.initialize(bool, bool, bool, bool)`. `DelayForStartup`, `DynamicSpawn` and
`PointDefenceMode` have no YAML key at all, so a mission that tuned its IADS loses the tuning with
no symptom that points back at the conversion.

## One gain to preserve

Sharko noticed between his two runs that `veaf.SecurityDisabled` now reaches `mission.yaml`, as a
side effect of `fix(security): honour the retired SecurityDisabled spelling` in 6.14.0. Pin it with
a test so this ticket cannot undo it.

## Tests

- Each of the fourteen keys converts to a `mission.yaml` entry and generates Lua that applies it —
  except `veafSecurity.authenticated`, asserted to appear in ticket 02's declared-loss output
- **A v5 config carrying the shipped `PASSWORD_L1` hash (`bdc82f5e…`) produces no
  `password_hashes:` entry** — the regression test for the VMR-040 hole. Same for `PASSWORD_L0`
  (`47c7808d…`)
- A v5 config carrying a *custom* hash in `password_L1["…"]` produces it in `password_hashes:`, and
  the generated Lua clears the tables before adding it
- `veaf.SecurityDisabled` keeps surviving
- Between this ticket and 02, the fourteen are all accounted for — a test enumerating them and
  asserting each is either carried or reported, so none falls in the gap
