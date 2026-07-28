# FEAT-FOOTHOLD-RELEASE-INTAKE — adopt Lekaa's new release channel

Status: ✅ done

## Context

Lekaa changed how Foothold is distributed. It now lives in a public GitHub repository,
[leka1986/Lekas-Foothold](https://github.com/leka1986/Lekas-Foothold), with **releases**
(latest at the time of writing: `v4.4.1`, 2026-07-28). Each release asset is a **zip**
holding the `.miz`, the `Foothold Config Manager <version>.exe`, the manual PDF and a
YouTube shortcut — not a bare `.miz` as before. The repo also publishes the *sources*
(`Common Scripts/`, `Setup files/`, `Missions/`) and Lekaa's own tooling
(`MizBatchUpdater.exe`, `MizFileReplacer.exe`).

The moulinette was re-run end to end against `Foothold_CA_4.4.1` to find out whether the
change breaks it. **It does not.** The `.miz` internals are unchanged in shape (native
`a_do_script_file` loader triggers), so the generic detection in `convert-other` still
works:

| Step | Result on 4.4.1 |
|---|---|
| `convert-other --profile foothold` | 12 scripts detected in load order, 4 loader triggers, `Moose_2026-06-14.lua` → `Moose.lua` |
| `validate` | passes, no findings |
| `build` | 12 scripts injected, native loaders stripped (0 `ScriptLoader` left in the built `mission`), `warehouses`/`options` preserved |

Loader detection was also checked against **all 10 maps**. The trigger comments vary wildly
per map (`ScriptLoader 1`, `Loader 2`, `Mission Scrips`, `Starter 1`, `LOAD ONCE`, `Scripts`,
`add scripts`…), which is exactly what the generic detection is for. Duplicate comments
(Persian Gulf carries three identical ones) are all removed, because
`strip_native_load_triggers` glob-matches every trigrule rather than the first hit — the
scaffold's label de-duplication is cosmetic only.

The `foothold` profile's `config_override` keys all still exist in the new
`Foothold Config.lua` (V1.0.9): `Era` (l. 181), `StartNormal` (398), `AutoRestart` (402),
`CapDifficulty` (522).

So this lot is **not a repair**. It closes the gaps the new upstream exposes, and the
ergonomics of the new release channel.

## What the new upstream exposes

1. **Versioned name not normalised.** The profile normalises `Moose_*.lua` only, but
   upstream also ships `Splash_Damage_3.4.1_leka.lua`. Stable from `v4.1.7` to `v4.4.1`, yet
   plainly version-stamped: the next bump makes `--update` report an add + a remove and
   forces a hand-edit of `custom_scripts:`.

2. **`.miz` is inside a zip.** Every moulinette run now starts with a manual unzip. Nothing
   in the toolchain knows about the release archive.

3. **New external-config mechanism** (this is the Config Manager's channel).
   `Foothold Config.lua` now tries `loadfile(lfs.writedir() .. "Missions\\Saves\\<config>")`
   and, if that file exists, overlays it on the in-`.miz` defaults, warning on screen when
   tracked names are missing (`FOOTHOLD_CONFIG_EXTERNAL_OUTDATED`). Our
   `veaf-config-override.lua` runs *after* the config script, so [ADR 0008](../../docs/adr/0008-foothold-config-override.md)
   still holds and our override still wins — but on a server where someone dropped that file
   into `Saved Games`, the mission's config silently changes underneath. Undocumented today.

4. **`Era` gained values.** `"Modern"`, `"Coldwar"`, `"Gulfwar"` (the Iraq Cold-War name) and
   `"Vietnam"`; our doc only knows the first two. New global `FootholdLocale` accepts `"FR"`
   among ten locales — directly relevant to a VEAF mission.

5. **Normandy WW2 is a different family.** Config target is `Foothold Config WW2.lua`, which
   has **no `Era`** and **no `StartNormal`**; the mission ships **no Foothold CTLD**, so the
   profile's `incompatible_modules: [CTLD]` is wrong there — the VEAF CTLD would be usable.
   Adopting Normandy with `--profile foothold` produces a scaffold that fails `validate`.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Profile: normalise `Splash_Damage_*`, scaffold `FootholdLocale`](tickets/01-profile-name-rules-and-locale.md) | ✅ |
| 02 | [`convert-other` accepts a release `.zip`](tickets/02-convert-other-accepts-zip.md) | ✅ |
| 03 | [Document the new release channel, external config and `Era` values](tickets/03-doc-release-channel.md) | ✅ |
| 04 | [`foothold-ww2` profile for Normandy](tickets/04-foothold-ww2-profile.md) | ✅ |

## Out of scope

- **Sourcing scripts from the repo instead of the `.miz`.** The repo now publishes
  `Common Scripts/` and `Setup files/`, so we *could* fetch scripts individually. We will
  not: the `.miz` is what carries the mission itself (zones, groups, warehouses), and
  adopting the released `.miz` keeps us on exactly the artefact players run. Noted here
  because it will look tempting again.
- **Using Lekaa's `MizBatchUpdater.exe` / `MizFileReplacer.exe`.** They solve his packaging
  problem, not our adoption problem.
- **Adopting the Config Manager as the VEAF config channel.** `config_override` in
  `mission.yaml` stays the VEAF way — it is versioned with the mission folder and validated
  at build time, which a `Saved Games` file is not.
