# Adopting a Foothold mission onto the v6 toolchain (the "moulinette")

> **Foothold** is a community mission (by *Lekaa*) that ships new versions several
> times a month. This guide describes the **moulinette**: a reproducible procedure
> any VEAF member can re-run on each new upstream version to produce the VEAF
> `.miz` (Modern **and** Cold-War) from a single mission folder.
>
> Architecture: **generic code, author-specific knowledge as data** (see
> [ADR 0007](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0007-third-party-mission-adoption.md))
> and **untouched upstream config + lexically-validated partial override** (see
> [ADR 0008](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0008-foothold-config-override.md)).
> The per-command detail lives in [CONVERT_OTHER](CONVERT_OTHER.en.md) and the
> [mission.yaml reference](../MISSION_YAML_REFERENCE.en.md).

## Prerequisites

- An up-to-date `veaf-tools` (or `veaf-tools.exe`).
- The Foothold release archive for the target map (e.g. Caucasus) — see below.
- The **`foothold`** conversion profile (shipped with the tools).

### Where the upstream comes from

Foothold is published on GitHub: **[leka1986/Lekas-Foothold](https://github.com/leka1986/Lekas-Foothold)**,
*Releases* tab. A release ships one `.zip` per map (Caucasus, Persian Gulf, Sinai, Syria,
Cold War Germany, Kola, Iraq, Afghanistan, WWII Normandy), each holding:

| File | What we do with it |
|---|---|
| `Foothold_<map>_<version>.miz` | **this is the moulinette's input** |
| `Foothold Config Manager <version>.exe` | ignored — see [the warning](#external-config) |
| `Foothold_Manual_v<x>.pdf` | upstream documentation, worth reading |
| `Getting Started.url` | video shortcut |

Pass the `.zip` straight to `convert-other`: it adopts the `.miz` inside and ignores the
rest. No need to unzip by hand.

> **All nine maps at once.** A release ships one archive per map. From a clone of this
> repository, [`tools/Convert-FootholdBatch.ps1`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/tools/Convert-FootholdBatch.ps1)
> adopts them all in one pass, picking the right profile for each (it looks inside the archive,
> not at its name):
>
> ```powershell
> .\tools\Convert-FootholdBatch.ps1 -InputFolder <zip-folder> -OutputFolder <missions-folder> -Validate
> ```
>
> On later releases add `-Update`: the scripts are refreshed and every tuned `mission.yaml` is
> preserved. Budget roughly a minute per mission.
>
> Your mission folders need not be named after the archives: the script matches each archive
> to the folder **of the same map** (it reads the theatre on both sides), so
> `Foothold_CA_4.7.0_Multi_Language….zip` does refresh `VEAF-Foothold-Caucasus`. It prints
> the folder it picked, and why, for each mission.

### Which profile for which map

| Map | Profile |
|---|---|
| Caucasus, Persian Gulf, Sinai, Syria, Cold War Germany, Kola, Iraq, Afghanistan | `foothold` |
| **WWII Normandy** | `foothold-ww2` |

Normandy is a different family, hence its own profile: its config file is called
`Foothold Config WW2.lua`, it has **no** `Era` global (WWII has no era switch) and no
`StartNormal`, and the mission **ships no Foothold CTLD** — so the VEAF CTLD is not
incompatible there (it stays OFF by default, but you may enable it).

Adopt Normandy with the `foothold` profile and `validate` stops you: the `config_override`
would target `Foothold Config.lua`, absent from this mission, and the override would then be
loaded **last** — after the setup script has already read the settings — so it would have no
effect at all.

## Overview

```
release .zip   ──(1) convert-other --profile foothold──►  v6 mission folder
                                                          │
                              (2) tune mission.yaml ◄──────┘
                                                          │
                          (3) validate  ──►  (4) build  ──►  <base>_MODERN.miz
                                                              <base>_COLD_WAR.miz
                                                          │
                                          (5) DCS test ◄────┘

New Lekaa version ──► convert-other --update ──► (re)validate ──► build
```

## 1. Initialise (adopt)

```bash
veaf-tools convert other Foothold_CA_4.4.1_Multi_Language_Coldwar-Modern-Vietnam.zip <mission-folder> --profile foothold
```

`convert-other` extracts the `.miz` (out of the archive when needed), detects the scripts
loaded by its native triggers (in order), and generates a `mission.yaml` with:

- an **ordered `custom_scripts:`** block (Moose, zoneCommander, Foothold Config,
  setup, Foothold CTLD, Splash, AIEN, EWRS… — the original load order), **delays
  included**: Lekaa does not load everything at once — 5 scripts arrive 3 seconds after the
  first ones, and AIEN 12 seconds later. `convert-other` reads those delays out of the source
  triggers and writes `delay_seconds:` on the scripts concerned, reproducing the staging
  (see [`delay_seconds`](../MISSION_YAML_REFERENCE.en.md#custom-scripts));
- a **`strip_native_triggers:`** list of the native loader triggers (the build
  removes them so nothing is loaded twice);
- the profile's **VEAF modules** (RADIO, SPAWN, WEATHER, SHORTCUTS, SECURITY,
  REMOTE);
- a `conversion_profile: foothold` marker (build/validate reject an incompatible
  module — Foothold ships its own CTLD, so the VEAF CTLD stays OFF);
- a commented **`config_override:`** scaffold targeting `Foothold Config.lua`.

### Why the staging matters {#staging}

This is not fidelity for its own sake. **AIEN inventories ground groups exactly once**, at load
time (its own comment: "launched once at mission start and collect everything relevant that is
already there"). Foothold, meanwhile, creates part of its groups afterwards, from scheduled tasks
starting at around 2 seconds.

Loading AIEN at time zero therefore hands it a world those tasks have not populated yet — and the
symptom is **silent**: no log error, just ground AI that never manages the groups Foothold created.
That is what Lekaa's 12 seconds are for, and why a detected `delay_seconds:` should not be removed
casually.

## 2. Tune `mission.yaml`

Three adjustments, all **config-only** (the upstream scripts are never touched):

### a. VEAF community scripts (already turned off by the profile)

Foothold ships **its own** libraries (Moose, its own CTLD, AIEN, EWRS, Splash…)
as `custom_scripts`. The VEAF community scripts must therefore stay OFF — otherwise,
for example, VEAF's AIEN clobbers Foothold's and the mission crashes. The `foothold`
profile **already scaffolds** these disables **inside the `modules:` block** (not in
a separate `community_scripts:` block, which is *ignored* once `modules:` exists) —
nothing to do, just confirm they are present:

```yaml
modules:
  # … VEAF modules …
  # ── Community scripts OFF ──
  stts: false
  ctld: false
  aien: false
  csar: false
  hercules: false
  skynet: false
  tum: false
```

> MiST is not in the list: it is no longer injected by default. The VEAF scripts stopped
> calling it, and so did every community script shipped here, which saves 336 KB in every
> mission. If one of your own scripts calls `mist.`, the build notices and injects it for
> you, naming the file that asked for it.

### b. Partial override of the Foothold config

Uncomment the `config_override:` block and put in **only** the globals you change
(the rest of `Foothold Config.lua` stays untouched and updates by itself on the
next version). `validate` checks two things:

- each key is **validated lexically** against the injected code — a typo or an upstream rename
  fails `validate` and the build;
- the `target` must **name one of the mission's scripts**. Otherwise the override would be
  loaded last, after the setup script has already read the settings, and would have no effect
  — a silent failure, now blocked.

```yaml
config_override:
  target: "Foothold Config.lua"
  values:
    Era: Modern          # default; overridden per variant below
    AutoRestart: false
    FootholdLocale: FR   # language of Foothold's on-screen messages
```

`FootholdLocale` (upstream config V1.0.9) accepts `EN`, `DE`, `FR`, `ES`, `RU`, `PT-BR`,
`TR`, `IT`, `zh-CN`, `zh-TW`. It does not force the players' radio-menu language, which each
of them still sets in game.

### ⚠️ The Config Manager's external config (do not install it) {#external-config}

Since config V1.0.9, `Foothold Config.lua` **looks for an external config file** and, if it
finds one, applies it on top of the values embedded in the `.miz`:

```
<Saved Games>\DCS…\Missions\Saves\Foothold Config.lua
```

This is the **Foothold Config Manager**'s channel (the executable shipped in the archive):
its *Import MIZ Config* button installs that file. What follows from it:

- **our `config_override` still wins**: the generated `veaf-config-override.lua` is loaded
  *after* the config script, so it reassigns the globals last —
  [ADR 0008](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0008-foothold-config-override.md)
  still holds;
- **but** such a file dropped into a server's `Saved Games` **silently** changes every
  Foothold mission on that instance, ours included, for every setting we do not explicitly
  override;
- Foothold also nags on screen (`FOOTHOLD_CONFIG_EXTERNAL_OUTDATED`) when that external file
  is older than the embedded config.

> **So: do not install the Config Manager's external config on a VEAF server.** A VEAF
> mission's configuration lives in its `mission.yaml`, versioned with the mission folder and
> validated at build time — which a file in `Saved Games` is not. The Config Manager stays
> useful offline, to *explore* the available settings and see what each option does.

### c. Modern / Cold-War variants

Foothold's era is driven by the `Era` global, which accepts four values — `"Modern"`,
`"Coldwar"`, `"Gulfwar"` (the Cold-War era's name on the Iraq map) and `"Vietnam"`. It is a
pure **config difference**, so we emit several `.miz` in a single build via
[`build_variants:`](../MISSION_YAML_REFERENCE.en.md):

```yaml
mission:
  name: VEAF-Foothold-Caucasus

build_variants:
  - MODERN
  - COLD_WAR

profiles:
  MODERN:
    mission:
      era: MODERN
    config_override:
      values:
        Era: Modern
  COLD_WAR:
    mission:
      era: COLD_WAR
    config_override:
      values:
        Era: Coldwar
```

The same shape gives a Vietnam variant if we want one (`Era: Vietnam`): recent Lekaa missions
ship the period's aircraft and loadouts, selected by `Era`. On the Iraq map, the Cold-War era
is called `Gulfwar`.

## 3. Validate

```bash
veaf-tools mission validate <mission-folder>
```

Checks the syntax, module semantics, `custom_scripts` existence, profile
incompatibilities, and that **every `config_override` key segment exists** in the
injected Foothold code.

## 4. Build both variants

```bash
veaf-tools mission build <mission-folder>
```

A single build produces **two** `.miz`: `…_MODERN.miz` and `…_COLD_WAR.miz`. Each
variant: untouched upstream config → small `veaf-config-override.lua` reassigning
`Era` (loaded between config and setup) → native triggers stripped →
`custom_scripts` loaded in declaration order → VEAF spawns/data injected.

> For `--profile <X>` alone (a single variant, unsuffixed) or build options, see
> the [mission.yaml reference](../MISSION_YAML_REFERENCE.en.md).

## 5. Test in DCS

Open each `.miz` in DCS and confirm **iso-functional** behaviour (VEAF F10 radio
menu present, Foothold engine running, equipment consistent with the era). This is
the final validation step before publishing the mission folder.

## Updating (new Lekaa version)

When Foothold ships a new release, download the new archive and re-import it **into the same
folder**:

```bash
veaf-tools convert other <new_release.zip> <mission-folder> --profile foothold --update
```

`--update` refreshes the third-party scripts and mission base, **preserves your
tuned `mission.yaml`**, and normalises versioned names (`Moose_<date>.lua` → `Moose.lua`,
`Splash_Damage_<version>_leka.lua` → `Splash_Damage.lua`).

It also **reconciles `delay_seconds:` with the new release's staging** and **deletes the
scripts Lekaa no longer ships** — as with the 4.7.0 Syria setup rename
(`footholdSyriaSetup.lua` → `footholdSyriaSetupv2.lua`), where the old file stayed on disk
and got embedded instead of the new one. Its `custom_scripts:` entry stays, so **`validate`
fails** until you remove it: that is the signal, not a defect.

The report (`convert-other-report.md`) lists all of it: scripts added, updated, deleted,
and every delay written. Review it, add any new script to `custom_scripts:`, then
re-validate and rebuild. See [CONVERT_OTHER](CONVERT_OTHER.en.md).

> A **new upstream script** is not added to `custom_scripts:` for you: its position in the
> load order is a decision only a human can make.

> `convert-other-state.yaml` appears in the mission folder: it is the list of scripts the
> upstream release loads, and it is what tells a script Lekaa dropped from one you added
> yourself. **Commit it with the mission.**
