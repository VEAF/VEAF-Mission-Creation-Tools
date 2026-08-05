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
   Adopting Normandy with `--profile foothold` produced a mission that **validated cleanly and
   built**, with an override silently loaded too late to have any effect (see ticket 05 — this
   PRD first claimed it failed `validate`, which was wrong).

## Two defects found while testing this lot

Exercising tickets 01-04 **through the packaged executable** instead of `poetry` surfaced two
pre-existing defects, both fixed here (ticket 05):

- **`--profile` never worked in the shipped binary.** The conversion profiles were never
  bundled by PyInstaller, so `veaf-tools.exe convert-other … --profile foothold` died with
  *unknown conversion profile*. The documented moulinette was unusable for any VEAF member
  not running from the sources. (`veaf-tools.spec` lists them, but the build ignores that
  file.)
- **`config_override.target` was never validated.** A target naming no injected script makes
  the build append the override **last** — after the setup script has read the globals — so it
  loads and does nothing. Now an error.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Profile: normalise `Splash_Damage_*`, scaffold `FootholdLocale`](tickets/01-profile-name-rules-and-locale.md) | ✅ |
| 02 | [`convert-other` accepts a release `.zip`](tickets/02-convert-other-accepts-zip.md) | ✅ |
| 03 | [Document the new release channel, external config and `Era` values](tickets/03-doc-release-channel.md) | ✅ |
| 04 | [`foothold-ww2` profile for Normandy](tickets/04-foothold-ww2-profile.md) | ✅ |
| 05 | [Bundle the profiles, and validate `config_override.target`](tickets/05-validate-config-override-target.md) | ✅ |

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

---

## 01 — Profile: normalise `Splash_Damage_*`, scaffold `FootholdLocale`

Status: ✅ done
Type: feat

### Why

`src/python/veaf-tools/veaf_libs/data/convert-profiles/foothold.yaml` normalises
`Moose_*.lua` only. Upstream 4.4.1 also ships `Splash_Damage_3.4.1_leka.lua`: a
version-stamped name that will churn, and every churn breaks the `custom_scripts:` path on
`convert-other --update` (reported as one add + one remove, fixed by hand).

Separately, the new `Foothold Config.lua` exposes `FootholdLocale` (ten locales, `"FR"`
included). A VEAF Foothold wants French on-screen text, so it belongs in the commented
`config_override` scaffold the profile emits — the point of that scaffold being to surface
the handful of settings a mission-maker actually changes.

### Tasks

- [x] Add a `name_normalization` rule `Splash_Damage_*.lua` → `Splash_Damage.lua`.
- [x] Add `FootholdLocale: FR` to `config_override.defaults` (the block is emitted
      commented out, so this is a suggestion, not a forced value).
- [x] Unit test: `ConversionProfile.normalize_script_name` maps
      `Splash_Damage_3.4.1_leka.lua` → `Splash_Damage.lua` and leaves `Zeus.lua` alone.
- [x] Unit test: `build_scaffold_yaml` with the `foothold` profile emits `FootholdLocale`
      in the commented `config_override` block.
- [x] Re-run the moulinette on `Foothold_CA_4.4.1` and confirm `custom_scripts:` now lists
      `src/scripts/Splash_Damage.lua`.
- [x] CHANGELOG + version bump (`pyproject.toml` + `plugin/.claude-plugin/plugin.json`).

### Verify

Both keys must survive `validate`: `FootholdLocale` is lexically checked against the
injected `Foothold Config.lua`, and it is there at line 391 of the 4.4.1 config.

### Notes

Do **not** normalise the per-map setup script (`MA_Setup_CA.lua`, `footholdSyriaSetup.lua`,
`kola_setup.lua`, `AF_SETUP.lua`, …). Those names differ per *map*, not per *version*, and
each mission folder adopts exactly one map — a rule collapsing them to one name would buy
nothing and hide which map a folder holds.

---

## 02 — `convert-other` accepts a release `.zip`

Status: ✅ done
Type: feat

### Why

Lekaa's release assets are zips (`Foothold_CA_4.4.1_….zip`) bundling the `.miz` with the
Config Manager executable, the manual and a shortcut. Today `convert-other` requires the
`.miz`, so every adoption *and* every `--update` starts with a manual unzip into a temp
folder — a step that is easy to get wrong (grabbing the previous version's `.miz`) and adds
nothing.

Since the moulinette is meant to be re-run by any VEAF member on each upstream version
(see `doc/mission-maker/FOOTHOLD.md`), the input should be the artefact they downloaded.

### Behaviour

`convert-other <archive.zip> <folder> [--profile …] [--update]`:

- extract to a temp directory, locate the `.miz` members, and adopt the single one found;
- **more than one `.miz`** → fail with a message listing them (no guessing which mission the
  user meant);
- **no `.miz`** → fail with a clear message;
- ignore everything else in the archive (`.exe`, `.pdf`, `.url`) — we never run the
  Config Manager, and nothing outside the `.miz` belongs in a mission folder;
- clean the temp directory afterwards, on success and on failure;
- a `.miz` argument keeps working exactly as today.

### Tasks

- [x] Extract the input resolution out of `veaf_tools/commands/convert_other.py` into a
      small helper (a context manager yielding the `.miz` path) so both the command and the
      tests use one code path.
- [x] Accept `.zip` in the command; keep `.miz` untouched.
- [x] i18n strings (FR + EN) for the two failure cases and for an action line stating which
      `.miz` was picked out of the archive.
- [x] Unit tests: single-`.miz` zip adopts; multi-`.miz` zip fails with both names listed;
      `.miz`-free zip fails; a plain `.miz` path still works; the temp dir is gone
      afterwards in every case.
- [x] End-to-end check against the real
      `Foothold_CA_4.4.1_Multi_Language_Coldwar-Modern-Vietnam.zip`.
- [x] Update `doc/mission-maker/CONVERT_OTHER.md` + `.en.md` (the argument accepts both).
- [x] CHANGELOG + version bump.

### Notes

Windows path length is a live constraint here (see the archived `FIX-LONG-FILENAMES-WINDOWS`
lot) and Foothold's asset names are long. Extract to a **short** temp path rather than one
derived from the archive name.

Fetching the release straight from GitHub (`--from-release`) is deliberately left out: it
adds a network dependency and an auth surface to a command that has neither, and the
download is one click. Revisit only if the manual download turns out to be the friction.

---

## 03 — Document the new release channel, external config and `Era` values

Status: ✅ done
Type: docs

### Why

`doc/mission-maker/FOOTHOLD.md` (+ `.en.md`) describes the moulinette against the old
distribution ("the upstream Foothold `.miz` for the target map") and an `Era` global with two
values. Three things it now gets wrong or omits, one of which is an operational trap.

### What to write

#### a. Where the upstream comes from

Point at [leka1986/Lekas-Foothold](https://github.com/leka1986/Lekas-Foothold) releases, and
say the asset is a **zip** containing the `.miz` plus the Config Manager, the manual and a
shortcut. State that `convert-other` takes either the zip or the `.miz` (depends on ticket
02 — if 02 ships later, document the manual unzip and revisit).

#### b. The external config channel (the trap)

`Foothold Config.lua` V1.0.9 loads `<Saved Games>/Missions/Saves/Foothold Config.lua` when
that file exists and overlays it on the `.miz` defaults, nagging on screen when tracked
settings are missing. That file is what the **Foothold Config Manager** installs.

State plainly, in the mission-maker doc **and** wherever we document server deployment:

- our `config_override` still wins, because `veaf-config-override.lua` is loaded *after* the
  config script — [ADR 0008](../../docs/adr/0008-foothold-config-override.md) is intact;
- but a `Foothold Config.lua` sitting in a server's `Saved Games\Missions\Saves\` silently
  changes every Foothold mission on that instance, VEAF ones included;
- so: **do not install the Config Manager's external config on a VEAF server**. Config lives
  in `mission.yaml`, versioned with the mission folder and validated at build time.

#### c. `Era` and `FootholdLocale`

`Era` accepts `"Modern"`, `"Coldwar"`, `"Gulfwar"` (the Iraq Cold-War name) and `"Vietnam"`.
Document all four, and that a `VIETNAM` `build_variants` entry is available the same way
`MODERN` / `COLD_WAR` are. Document `FootholdLocale` (`"FR"` among ten locales) as the
setting that drives Foothold's on-screen language.

### Tasks

- [x] Rewrite the prerequisites + step 1 of `FOOTHOLD.md` / `FOOTHOLD.en.md` for the release
      channel.
- [x] Add the external-config section (mission-maker view + the server-side warning).
- [x] Update the Modern/Cold-War section for the four `Era` values and `FootholdLocale`.
- [x] Note in `CONVERT_OTHER.md` / `.en.md` that a Foothold upstream now arrives zipped.
- [x] Check whether the deployment/ops doc needs the same warning; add it there if so.
- [x] CHANGELOG entry (docs-only, no version bump unless another ticket in the lot bumps).

### Verify

Keep the FR and EN pages in step — same sections, same anchors, English anchors on both
(per the anchor convention from `DOC-GUIDE-ANCHORS`).

---

## 04 — `foothold-ww2` profile for Normandy

Status: ✅ done
Type: feat

### Why

`WWII_Normandy_Foothold_5.2.2` (by *sevenfifty777*) is a Foothold, but not the same family.
Adopting it with `--profile foothold` yields a scaffold pointing at a config file the mission
does not have, plus one wrong incompatibility.

> **Correction.** This ticket first claimed the wrong profile "fails `validate`". It did not:
> it validated cleanly, built, and produced an override loaded too late to do anything. That
> silent failure is fixed in [ticket 05](05-validate-config-override-target.md), which makes
> an unresolvable `config_override.target` an error — so the claim is true *now*, because of
> 05, not because it ever was.

Measured against the shipped 5.2.2 `.miz`:

| | `foothold` profile says | Normandy actually is |
|---|---|---|
| config target | `Foothold Config.lua` | **`Foothold Config WW2.lua`** |
| `Era` | scaffolded (Modern/Coldwar) | **absent** — WW2 has no era switch |
| `StartNormal` | in the scaffold defaults | **absent** |
| `AutoRestart`, `CapDifficulty`, `FootholdLocale` | in the scaffold | present (l. 147, 209, 140) |
| Foothold CTLD | ships its own → VEAF `CTLD` incompatible | **ships none** → VEAF CTLD is usable |

Its loaded scripts: `Moose_2026-06-14.lua`, `Foothold_Localization.lua`,
`Foothold Config WW2.lua`, `zoneCommander.lua`, `Normandy_Zone_Setup.lua`,
`WelcomeMessage.lua`, `zeus_Full_v2.1.lua`, `EWRS.lua`, `Splash_Damage_3.4.1_leka.lua`,
`AIEN.lua` — no `Foothold CTLD.lua`, no `Foothold_CTLD_Red.lua`.

### Behaviour

A second bundled profile `foothold-ww2.yaml`:

- `config_override.target: "Foothold Config WW2.lua"`, defaults limited to keys that exist
  there (`AutoRestart`, `CapDifficulty`, `FootholdLocale`) — **no `Era`, no `StartNormal`**;
- `incompatible_modules:` empty — nothing forbids the VEAF CTLD on this mission;
- same `disabled_community_scripts` as `foothold` **minus `ctld`**: it ships Moose, AIEN,
  EWRS and Splash, so those stay off, but VEAF's CTLD may be enabled;
- same `name_normalization` rules (`Moose_*`, `Splash_Damage_*` from ticket 01);
- `modules:` as `foothold`, and whether `CTLD: true` becomes a default here is a judgement
  call — start with it **off** (adopting must not silently add a subsystem), and say in the
  profile comment that it is available.

### Tasks

- [x] Write `veaf_libs/data/convert-profiles/foothold-ww2.yaml` with the above, commented in
      the same style as `foothold.yaml` (data only, no code change expected).
- [x] Unit test: the profile loads, target is the WW2 config, `incompatible_modules` is
      empty, `ctld` is not in `disabled_community_scripts`.
- [x] Adopt `WWII_Normandy_Foothold_5.2.2` with it and run `validate` — must pass with the
      `config_override` block uncommented (every key lexically present in the WW2 config).
- [x] Build it and check the native loaders are stripped and the 10 scripts injected.
- [x] Document the profile in `FOOTHOLD.md` / `.en.md`: which profile for which map, and why
      Normandy needs its own (no era switch, no Foothold CTLD).
- [x] CHANGELOG + version bump.

### Notes

Do **not** try to make one profile cover both by making `Era` optional. The two missions
differ in what settings exist at all; a profile is meant to be the author-specific data for
one family, and forcing them together would put a conditional in generic code — which
[ADR 0007](../../docs/adr/0007-third-party-mission-adoption.md) exists to prevent.

`Foothold Config WW2.lua` carries the same external-config block as the modern config
(`Saved Games\Missions\Saves\Foothold Config WW2.lua`), so the ticket 03 warning applies
here too. It does **not** self-load from `l10n/DEFAULT` — no recursion risk.

Only worth doing if VEAF actually intends to run a Normandy Foothold. If not, park at
🚫 wontfix rather than half-shipping a profile nobody exercises.

---

## 05 — Bundle the conversion profiles, and validate `config_override.target`

Status: ✅ done
Type: fix

Two defects found by exercising tickets 01-04 **through the packaged executable** rather than
through `poetry`. Both predate this lot; both make the documented moulinette misbehave.

### a. `--profile` was broken in the shipped binary

```
FileNotFoundError: unknown conversion profile: foothold
[PYI-19868:ERROR] Failed to execute script 'veaf-tools'
```

`veaf-tools.exe convert-other … --profile foothold` died on every run. The conversion
profiles were **never** bundled into the executable: `git log -S "convert-profiles" --
veaf_build/worker.py` returns nothing.

The trap is that [`veaf-tools.spec`](../../veaf-tools.spec) *does* list
`veaf_libs\data\convert-profiles` — but that file is a leftover the build does not use. The
build passes `--add-data` from `BuildAndReleaseWorker._veaf_tools_extra_data`, and the
directory was missing there. Same family as `FIX-VEAF-BUILD-RADIO-LAYOUT-DATA` and the
`dcsUnits.yaml` bundling of `FIX-MCP-SCAFFOLD-THEATRE-HINT`.

Consequence: the moulinette documented in `FOOTHOLD.md` was unusable for any VEAF member
using the executable — only someone running from the sources could execute it. Which is
presumably why nobody reported it: it had only ever been run from this repo.

- [x] Bundle the whole `convert-profiles` directory (like `veaf_libs/locales`), so a new
      profile needs no build change.
- [x] Regression guard in `test_build_standalone.py`, on the pattern of the three already
      there; it also asserts both `foothold` and `foothold-ww2` are in the shipped directory.
- [x] Rebuild the executable and confirm `--profile foothold` and `--profile foothold-ww2`
      both work in the binary.

**Left alone deliberately**: `veaf-tools.spec` still lies about what ships. Deleting it or
making it authoritative is a tooling decision, not a detail — worth its own chore.

### b. `config_override.target` was never validated

Ticket 04 (and this lot's PRD) claimed that adopting Normandy with the modern `foothold`
profile "produces a scaffold that fails `validate`". **That was wrong** — it validated
cleanly. Verified by adopting `WWII_Normandy_Foothold_5.2.2` with `--profile foothold`,
uncommenting `config_override`, and running `validate`: `✓ no problem detected`.

Two reasons it passed:

1. `_check_config_override` only validated the `values` **key segments**, never the `target`.
2. The segments are searched across the **whole** `src/scripts/*.lua` corpus, so
   `StartNormal` is found in the engine scripts even though the WW2 *config* does not define
   it.

And the real behaviour is worse than a failed validation. `_position_config_override` states:
"When the target is not in the list, the override is appended so it still loads." Confirmed in
a built `.miz` — resource keys with the wrong profile:

| key | script |
|---|---|
| 11004 | `Foothold Config WW2.lua` |
| 11006 | `Normandy_Zone_Setup.lua` (reads the settings) |
| **11012** | **`veaf-config-override.lua`** ← last |

So the override was built, embedded, loaded — and had **no effect**, silently. With the right
profile the override sits at 11005, between the config and the setup script.

- [x] `validate` errors when `config_override.target` matches no script in `src/scripts/`
      (matched on basename, like the build's own positioning). No target → no check, since
      loading in collection order is a deliberate choice.
- [x] Message (FR + EN) states the *consequence* — loaded last, after the setup script, hence
      ineffective — and points at the matching conversion profile.
- [x] Four tests: missing target errors; basename matching (a `target` carrying a directory
      still resolves); no target is not flagged; the known-good case stays clean.
- [x] Correct the claim in the PRD, ticket 04, `FOOTHOLD.md`/`.en.md`, the CHANGELOG and the
      PR body: it did **not** fail validate before — it passed and produced a dud override.

### Why this belongs in this lot

Ticket 04 exists to stop someone adopting Normandy with the wrong profile. Without (b) the
protection was cosmetic: the wrong profile produced a mission that built, loaded, and quietly
ignored its configuration. Fixing the root cause is what makes ticket 04 worth anything, and
(a) is what makes any of it reachable from the shipped binary.
