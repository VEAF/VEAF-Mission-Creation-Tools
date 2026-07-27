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
> The per-command detail lives in [CONVERT_OTHER](CONVERT_OTHER.md) and the
> [mission.yaml reference](../MISSION_YAML_REFERENCE.md).

## Prerequisites

- An up-to-date `veaf-tools` (or `veaf-tools.exe`).
- The upstream Foothold `.miz` for the target map (e.g. Caucasus).
- The **`foothold`** conversion profile (shipped with the tools).

## Overview

```
upstream .miz  ──(1) convert-other --profile foothold──►  v6 mission folder
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
veaf-tools convert-other <Foothold_upstream.miz> <mission-folder> --profile foothold
```

`convert-other` extracts the `.miz`, detects the scripts loaded by its native
triggers (in order), and generates a `mission.yaml` with:

- an **ordered `custom_scripts:`** block (Moose, zoneCommander, Foothold Config,
  setup, Foothold CTLD, Splash, AIEN, EWRS… — the original load order);
- a **`strip_native_triggers:`** list of the native loader triggers (the build
  removes them so nothing is loaded twice);
- the profile's **VEAF modules** (RADIO, SPAWN, WEATHER, SHORTCUTS, SECURITY,
  REMOTE);
- a `conversion_profile: foothold` marker (build/validate reject an incompatible
  module — Foothold ships its own CTLD, so the VEAF CTLD stays OFF);
- a commented **`config_override:`** scaffold targeting `Foothold Config.lua`.

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

> MiST is not in the list: it is a mandatory VEAF dependency (always loaded).

### b. Partial override of the Foothold config

Uncomment the `config_override:` block and put in **only** the globals you change
(the rest of `Foothold Config.lua` stays untouched and updates by itself on the
next version). Each key is **validated lexically** against the injected code: a
typo fails `validate` and the build.

```yaml
config_override:
  target: "Foothold Config.lua"
  values:
    Era: Modern          # default; overridden per variant below
    AutoRestart: false
```

### c. Modern / Cold-War variants

Foothold's era is driven by the `Era` global (`"Modern"` or `"Coldwar"`) — a pure
**config difference**. So we emit both `.miz` in a single build via
[`build_variants:`](../MISSION_YAML_REFERENCE.md):

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

## 3. Validate

```bash
veaf-tools validate <mission-folder>
```

Checks the syntax, module semantics, `custom_scripts` existence, profile
incompatibilities, and that **every `config_override` key segment exists** in the
injected Foothold code.

## 4. Build both variants

```bash
veaf-tools build <mission-folder>
```

A single build produces **two** `.miz`: `…_MODERN.miz` and `…_COLD_WAR.miz`. Each
variant: untouched upstream config → small `veaf-config-override.lua` reassigning
`Era` (loaded between config and setup) → native triggers stripped →
`custom_scripts` loaded in declaration order → VEAF spawns/data injected.

> For `--profile <X>` alone (a single variant, unsuffixed) or build options, see
> the [mission.yaml reference](../MISSION_YAML_REFERENCE.md).

## 5. Test in DCS

Open each `.miz` in DCS and confirm **iso-functional** behaviour (VEAF F10 radio
menu present, Foothold engine running, equipment consistent with the era). This is
the final validation step before publishing the mission folder.

## Updating (new Lekaa version)

When Foothold ships a new version, re-import it **into the same folder**:

```bash
veaf-tools convert-other <new_upstream.miz> <mission-folder> --profile foothold --update
```

`--update` refreshes the third-party scripts and mission base, **preserves your
tuned `mission.yaml`**, normalises versioned names (`Moose_<date>.lua` →
`Moose.lua`), and **reports the scripts added / updated / removed** upstream.
Review the report, reconcile `custom_scripts:` / `strip_native_triggers:` if
needed, then re-validate and rebuild. See [CONVERT_OTHER](CONVERT_OTHER.md).
