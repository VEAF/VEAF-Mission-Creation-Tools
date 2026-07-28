# Pipeline Reference

This page documents the optional **build pipeline** steps that `veaf-tools build` can run after generating `veaf-config.lua`. Each step injects data into the `.miz` file from a separate YAML configuration file.

---

## Overview

The pipeline runs the following optional steps, in this order:

| Step | Config file | What it does |
|------|-------------|--------------|
| `presets` | `src/presets.yaml` | Injects radio frequency presets into human-piloted aircraft groups |
| `waypoints` | `src/waypoints.yaml` or `waypoints.yaml` | Injects waypoint templates into human-piloted aircraft groups |
| `spawnable_aircrafts` | `src/spawnables.yaml` | Injects **spawnable** aircraft groups (`veafSpawn-` prefix, cloned by `veafSpawn`) |
| `dynamic_slot_templates` | `src/dynamic-slot-templates.yaml` | Injects **dynamic-slot templates** (`dynSpawnTemplate = true`, consumed by DCS) |
| `warehouses` | `src/warehouses.yaml` | Wires the warehouses for Dynamic Slots |
| `spawn_data` | `src/spawn-groups.yaml` *(optional)* | Injects the spawn database (`_spawn unit`/`_spawn group`); **always on** (framework data is embedded) |
| `weather` | `src/versions.yaml` or `versions.yaml` | Creates multiple mission variants with different weather and time |

Each step is **auto-detected**: it runs if its default config file exists. You can override this behaviour in `mission.yaml`. **Exception**: `spawn_data` always runs (even with no mission file) to embed the framework spawn database; `src/spawn-groups.yaml` only extends it.

---

## Controlling the Pipeline (`mission.yaml`)

```yaml
pipeline:
  presets: false                        # skip even if src/presets.yaml exists
  waypoints: true                       # auto-detect: runs only if the config file exists
  spawnable_aircrafts:
    file: src/my-spawnables.yaml        # non-default file path
    mode: replace                       # add (default) | replace
  dynamic_slot_templates: false         # skip dynamic-slot-template injection
  spawn_data: false                     # disable spawn-database injection (framework included)
  weather: false                        # skip weather variants
```

### `pipeline:` fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `presets` | bool \| object | auto | No | `true`/unset = auto-detect (run if file exists), `false` = always skip, object = custom options |
| `waypoints` | bool \| object | auto | No | `true`/unset = auto-detect (run if file exists), `false` = always skip, object = custom options |
| `spawnable_aircrafts` | bool \| object | auto | No | `true`/unset = auto-detect (run if file exists), `false` = always skip, object = custom options |
| `dynamic_slot_templates` | bool \| object | auto | No | `true`/unset = auto-detect (run if file exists), `false` = always skip, object = custom options |
| `spawn_data` | bool \| object | always | No | `true`/unset = **always runs** (framework data embedded), `false` = disable entirely, object `{file: …}` = non-default mission file |
| `weather` | bool \| object | auto | No | `true`/unset = auto-detect (run if file exists), `false` = always skip, object = custom options |

When set to an object, the following sub-fields apply:

| Sub-field | Type | Default | Description |
|-----------|------|---------|-------------|
| `file` | string | *(see step defaults)* | Path to the config file, relative to the mission folder |
| `mode` | `add` \| `replace` | `add` | *(group-injection steps only)* `add` keeps existing groups; `replace` updates same-named groups |

**Auto-detection** (when not set or `true`): the step runs only if its default file is found. Absence of the file silently skips the step.

---

## Step 1 — Radio Presets (`presets.yaml`) {#pipeline-step-1-presets}

Injects radio frequency presets into every aircraft group that has at least one human pilot (Client/Player skill). Also generates kneeboard PNG images for each preset.

> **Disabling kneeboards**: the step's mapping form accepts a `kneeboards` sub-flag (default `true`). Setting `pipeline: { presets: { enabled: true, kneeboards: false } }` keeps the radio frequency injection but generates no kneeboard PNG plates (`KNEEBOARD/IMAGES/presets-*.png`).

### Default file location

```
<mission-folder>/src/presets.yaml
```

### Two authoring formats {#two-authoring-formats}

Since [ADR 0010](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0010-per-type-radio-preset-projection.md), `presets.yaml` accepts two layers, which coexist:

- **`channel_lists`** (recommended): the mission-maker declares their channel lists once per coalition, by functional **Radio role** (primary UHF, primary VHF, FM…), and the build automatically projects each list onto every aircraft type's physical radios, honouring that type's hardware quirks (channel 0, reserved slots, hardcoded special channels, radio fusion — AJS-37, OH-58D, Mi-24P…). One frequency change propagates to the whole fleet. These per-type projection rules are documented on the developer side: [Per-type radio-preset projection](developer/radio-preset-projection.en.md).
- **`radios_collection` / `presets_collection` / `presets_assignments`** (legacy): the mission-maker defines each preset's content radio by radio, then explicitly assigns it per aircraft type. This format remains fully supported and now serves as the **manual override mechanism**: an explicit assignment in `presets_assignments` for a given type always wins over the `channel_lists` automatic projection — including the special value `none` (no injection at all).

In both cases, `channels_collection` (the frequencies) stays the shared source for both formats.

> **`convert-v5` names frequencies automatically.** When converting a v5 mission, hardcoded frequencies are replaced with **names** in `presets.yaml` — the theatre's airfields (`Gudauta`, `Batumi`…) and VEAF call-signs (`Guard`, `Archer`, `Texaco-1`…) — and the matching `channels_collection` is inserted to resolve them. A frequency with no known name is left as a raw number. The faithful copy `presets.v5.yaml` keeps the raw frequencies.

### Schema — `channel_lists` (recommended model)

```yaml
# ── Channel definitions (shared by both formats) ───────────────────────────
channels_collection:
  <set-name>:                           # logical group of channels (e.g. airports-caucasus)
    <channel-name>:                     # individual channel identifier
      title: "Batumi / 16X"            # human-readable label
      freqs:
        uhf: 260                        # UHF frequency (MHz)
        vhf: 131                        # VHF-AM frequency (MHz)
        fm: 40.4                        # FM frequency (MHz)

# ── Channel lists by radio role ─────────────────────────────────────────────
channel_lists:
  <coalition>:                          # blue | red
    primary_1:                          # 1st V/UHF radio (uhf band)
      01: Guard
      02: Batumi
    primary_2:                          # 2nd V/UHF radio (vhf band); also the warbirds' single radio
      01: Guard
      02: Batumi
    fm_supplement:                      # FM as a 3rd radio, atop two primaries (e.g. A-10C)
      01: 30
    fm_substitute:                      # FM as the 2nd radio, replacing a 2nd primary (e.g. helicopters)
      01: 30
    fm_secondary:                       # a 2nd supplemental FM radio (e.g. OH-58D); defaults to a copy of fm_supplement
      01: 31
```

**Radio roles** (fixed vocabulary):

| Role | Band | Usage |
| --- | --- | --- |
| `primary_1` | uhf | 1st V/UHF radio |
| `primary_2` | vhf | 2nd V/UHF radio; the warbirds' single radio |
| `fm_substitute` | fm | FM replacing a 2nd primary radio (helicopters with a single primary radio) |
| `fm_supplement` | fm | FM atop two primary radios (attack aircraft, e.g. A-10C) |
| `fm_secondary` | fm | a 2nd supplemental FM radio (e.g. OH-58D); defaults to a copy of `fm_supplement` if not declared |

The build automatically assigns each aircraft type's physical radios to the role they match (deduced from their hardware frequency ranges), then projects that role's declared channel list onto it. A channel lacking a frequency for the role's band is silently dropped (reported under `validate`).

### Schema — legacy format (manual override)

```yaml
# ── Radio definitions ──────────────────────────────────────────────────────
radios_collection:
  <set-name>:                           # logical group of radios (e.g. blue_radios)
    <radio-name>:                       # identifier referenced in presets_collection
      title: "UHF"                      # label shown on kneeboard
      type: uhf                         # uhf | vhf | fm
      channels:
        01: Guard                       # channel number → channel-name (from channels_collection)
        02: Batumi
        10: Stennis

# ── Preset definitions ────────────────────────────────────────────────────
presets_collection:
  <set-name>:                           # logical group of presets (e.g. blue_presets)
    <preset-name>:                      # identifier referenced in presets_assignments
      title: "Blue coalition - UHF/VHF/FM"
      radios:
        radio_1: <radio-name>           # slot → radio-name (from radios_collection)
        radio_2: <radio-name>
        radio_3: <radio-name>

# ── Assignment rules (manual override of channel_lists) ────────────────────
presets_assignments:
  <coalition>:                          # blue | red
    <category>:                         # plane | helicopter
      all: <preset-name>               # default preset for all aircraft of this type
      <aircraft-type>: <preset-name>   # override for a specific DCS type (e.g. A-10C_2) or a regex pattern (e.g. A[-]10C.*)
      <aircraft-type>: none             # disables all injection for this type (no channel_lists equivalent)
```

### Minimal example

```yaml
channels_collection:
  common:
    Guard:
      title: Guard
      freqs:
        uhf: 243.0
        vhf: 121.5

channel_lists:
  blue:
    primary_1:
      01: Guard
```

### Channel value

A channel can be defined in three ways, in `channel_lists` as well as `radios_collection`:

- a **channel name** (alias resolved from `channels_collection`): `01: Guard`;
- a direct **frequency** (MHz): `01: 243.0`;
- an **object**: `01: { freq: 243.0, mod: 1 }`, where `mod` is the modulation (`0` = AM, `1` = FM). The `mod` field is optional; when absent, DCS uses its default.

### Channel priority and colour (kneeboards)

On a plan entry (object form), two optional attributes enrich the kneeboard
([ADR 0012](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0012-channel-priority-colour-and-ajs37-packing.md)):

- **`priority: <n>`** — highlights the channel on **every** kneeboard (a `Pn`
  marker + orange Name/Freq cells). On the **AJS-37 (Viggen)** only, priorities
  1 to 4 additionally fill the FR22 Special 1/2/3 and FR24 H shortcut buttons.
  Declare it **in `channel_lists`** (one entry per priority value).
- **`color: <colour>`** — colours the **CH** cell to group channels visually.
  Value: a colour name (`green`, `blue`…) or `#RRGGBBAA`. Accepted in
  `channel_lists` **and** in `channels_collection` (the plan entry wins over the
  channel definition).

```yaml
channel_lists:
  blue:
    primary_1:
      01: { channel: Guard, priority: 4, color: red }   # Pn + highlight; on the Viggen → FR24 H
      02: { channel: Texaco-1, priority: 1 }             # on the Viggen → FR22 Special 1
      03: { channel: Batumi, color: "#2E7D32" }          # visual grouping (CH cell)
```

Kneeboards are generated **one per injected aircraft type**, in that type's DCS
folder (`KNEEBOARD/<type>/IMAGES/`).

### v5 conversion: two files (`convert-v5`)

Since [ADR 0010](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0010-per-type-radio-preset-projection.md), `convert-v5` emits **two** preset files:

- **`presets.yaml` — simplified plan (default, loaded by the build)**: `channel_lists` alone (plus the rare overrides the packer cannot project at all). The build projects the crystallisation onto every aircraft automatically — warbirds included (VHF/FM-capable radios), dropping out-of-band channels. This is the file that fully exploits the preset-plan model.
- **`presets.v5.yaml` — faithful copy (reference / rollback, NOT loaded by the build)**: the complete iso-functional conversion (`channel_lists` + a dedicated `{coalition}_{aircraft}` preset per bespoke layout, reproducing the exact channel → frequency map and `mod`, see ADR 0003).

**Caution**: the plan may make some frequencies **diverge** from the original v5 mission — warbirds move to the coalition channels, and jets' fused/modulated radios (F-14, AV8B…) are projected at best effort (partially) until a dedicated `dcs-radio-layouts.yaml` entry exists for their type. `convert-v5` warns which aircraft are projected at best effort. **Review and edit `presets.yaml`**; when in doubt, the exact v5 reproduction stays in `presets.v5.yaml` (copy it over `presets.yaml` to restore iso-functional behaviour).

### Frequency validation

At injection time, every frequency assigned to an aircraft is checked against the hardware specs of that aircraft's radios.

**Default behaviour (normal build):**

- **Critical aircraft** (`dcs_rejects_on_load: true` in the specs): if a frequency is out of range, a `WARNING` is emitted in the log. These are the aircraft for which DCS raises an error when the mission loads.
- **Other aircraft**: validation is silent — DCS stores the frequencies but ignores them for out-of-range radios without crashing.

**Automatic report:**

After each preset injection, a file `presets-validation-report.md` is automatically created in the mission folder if at least one aircraft (critical or not) has out-of-range frequencies. The file lists all issues with the invalid values and a YAML snippet to disable them temporarily. If no issues are found, the file is deleted.

```
<mission-folder>/presets-validation-report.md
```

**Temporarily disabling injection for an aircraft:**

While fixing the presets, you can disable injection for a specific aircraft type by assigning it the value `none` in `presets_assignments`:

```yaml
presets_assignments:
  blue:
    plane:
      MiG-19P: none   # DCS rejects standard frequencies — fix pending
```

Once the presets are corrected, remove the `none` line to re-enable injection.

Specs cover 87 player-flyable aircraft and are sourced from [dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine). If an aircraft is not in the database the check is silently skipped.

> **See also**: [`doc/mission-maker/dcs-radio-specs.md`](mission-maker/dcs-radio-specs.md) — full reference table of valid frequency ranges and list of critical aircraft.  
> To regenerate after a DCS update: `poetry run update-radio-specs`

---

## Step 2 — Waypoints (`waypoints.yaml`) {#pipeline-step-2-waypoints}

Injects waypoint templates into human-piloted aircraft groups. Only groups with at least one Client/Player unit are modified.

### Default file location

```
<mission-folder>/src/waypoints.yaml

Also accepted: waypoints.yaml  (mission root)
```

### Schema

```yaml
# ── Waypoint definitions ───────────────────────────────────────────────────
waypoints:
  <WAYPOINT_NAME>:
    type: "Turning Point"               # DCS waypoint type
    action: "Turning Point"             # DCS waypoint action
    alt: 6096                           # Altitude in metres
    alt_type: "BARO"                    # BARO | RADIO
    speed: 200                          # Speed in m/s
    speed_type: "TAS"                   # TAS | IAS
    x: 75869                            # Mission X coordinate
    y: 48674                            # Mission Y coordinate
    name: "BULLSEYE"                    # Waypoint label (optional)
    ETA: 364.89                         # Estimated time of arrival in seconds (optional)
    ETA_locked: false                   # Lock ETA (optional)

# ── Flight plan assignments ────────────────────────────────────────────────
settings:
  <PLAN_NAME>:
    category: "plane"                   # plane | helicopter (optional filter)
    coalition: "blue"                   # blue | red (optional filter)
    type: "F-16C_50"                    # DCS aircraft type (optional filter)
    country: "USA"                      # Country name (optional filter)
    waypoints:
      <WAYPOINT_NAME>: "<WAYPOINT_NAME>"  # map waypoint definition to slot
```

### Matching priority

Flight plans are matched to groups using this priority order:
1. Aircraft type (`type`)
2. Aircraft category (`category`)
3. Coalition (`coalition`)
4. Country (`country`)
5. All other groups (no filters = wildcard)

### Minimal example

```yaml
waypoints:
  BULLSEYE:
    type: "Turning Point"
    action: "Turning Point"
    alt: 6096
    alt_type: "BARO"
    speed: 999
    speed_type: "TAS"
    x: 75869
    y: 48674
    name: "BULLSEYE"

settings:
  BLUE_PLANES:
    category: "plane"
    coalition: "blue"
    waypoints:
      BULLSEYE: "BULLSEYE"
```

---

## Step 3 — Aircraft Groups: spawnables (B) and dynamic-slot templates (C) {#pipeline-step-3-aircraft-groups}

Two **distinct uses** of injected aircraft groups, handled by two independent steps (see [ADR 0002](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0002-aircraft-group-injection-sort-criteria.md)):

- **(B) spawnable groups** (`src/spawnables.yaml`, step `spawnable_aircrafts`): real hidden groups cloned on demand in-game by `veafSpawn`. Marker: the `veafSpawn-` name prefix.
- **(C) dynamic-slot templates** (`src/dynamic-slot-templates.yaml`, step `dynamic_slot_templates`): groups used as a **model** for DCS Dynamic Slots, consumed natively by the engine. Marker: the DCS flag `dynSpawnTemplate = true`.

At extraction (`extract-aircraft-groups`), each group is routed to one of the two families by this criterion (the flag wins over the prefix); other groups are ignored. By default extraction writes **both** files; `--kind spawnable|dynamic-template` restricts it to one. The old `.*[tT]emplate.*` name sort is abandoned (it misrouted a spawnable named "… Template …").

### Default file locations

```
<mission-folder>/src/spawnables.yaml              # (B) spawnable_aircrafts
<mission-folder>/src/dynamic-slot-templates.yaml  # (C) dynamic_slot_templates
```

> **v6 hard break**: the old `src/aircraft-templates.yaml` / `src/templates.yaml` names and the `aircraft_groups` step are gone. `convert-v5` produces the two new files directly.

### Injection modes

| Mode | Behaviour |
|------|-----------|
| `add` *(default)* | Appends all groups from the file; existing groups are preserved |
| `replace` | Groups with the same name in the mission are updated; others are preserved |

### Schema

```yaml
airplanes:
  coalitions:
    <coalition>:                        # blue | red
      <Country Name>:                   # DCS country name (e.g. "France", "USA")
        <Group Name>:
          name: "Group Name"            # REQUIRED — must match the key
          type: "M-2000C"               # REQUIRED — primary DCS aircraft type
          units:                        # REQUIRED — at least one unit
            - type: "M-2000C"
              name: "Pilot-1"
            - type: "M-2000C"
              name: "Pilot-2"

helicopters:
  coalitions:
    <coalition>:
      <Country Name>:
        <Group Name>:
          name: "Group Name"
          type: "UH-1H"
          units:
            - type: "UH-1H"
              name: "Helo-1"
```

### Minimal example

```yaml
airplanes:
  coalitions:
    blue:
      France:
        Mirage-Flight:
          name: "Mirage-Flight"
          type: "M-2000C"
          units:
            - type: "M-2000C"
              name: "Mirage-1"
            - type: "M-2000C"
              name: "Mirage-2"
```

---

## Step 6 — Weather & Time Versions (`versions.yaml`) {#pipeline-step-6-versions}

Creates multiple `.miz` variants from a single base mission, each with a different time and/or weather configuration.

### Default file location

```
<mission-folder>/src/versions.yaml

Also accepted: versions.yaml  (mission root)
```

### Schema

```yaml
# ── Geographic position for solar calculations ─────────────────────────────
position:
  latitude: 33.5                        # Decimal degrees, -90 to 90
  longitude: 35.5                       # Decimal degrees, -180 to 180
  timezone: "Asia/Damascus"             # IANA timezone string

# ── Base date for all versions ─────────────────────────────────────────────
base_date: "2024-03-15"                 # ISO 8601 (YYYY-MM-DD)

# ── Mission variants ───────────────────────────────────────────────────────
versions:
  - name: dawn                          # REQUIRED — output filename (without .miz)
    time: "sunrise+30*60"               # Time expression (see below)
    date: "today"                       # Date expression (see below, optional)
    metar: "METAR OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018"  # optional

  - name: noon
    time: "12:00"
    weather:                            # manual weather (alternative to metar)
      temperature: 25.0                 # °C, range -50..50
      wind_speed: 8.0                   # m/s
      wind_direction: 270.0             # degrees (0=North)
      visibility: 9999                  # metres
      cloud_type: "clear"               # clear | few | scattered | broken | overcast
      cloud_height: 2000                # cloud base in metres
      fog_enabled: false                # enable fog effect
```

### `versions[]` fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Output filename (no `.miz`); e.g. `dawn` → `dawn.miz` |
| `time` | string | No | Time expression — see below |
| `date` | string | No | Date expression — see below |
| `metar` | string | No | Full METAR string — parsed for weather data |
| `weather` | object | No | Manual weather override (used when no `metar`) |

### Time expressions

| Format | Example | Meaning |
|--------|---------|---------|
| `HH:MM` | `14:30` | Absolute time (14:30 local) |
| `sunrise` | `sunrise` | Sunrise time (requires `position:`) |
| `sunset` | `sunset` | Sunset time (requires `position:`) |
| Expression | `sunrise+30*60` | Arithmetic — seconds offset |
| Seconds | `54000` | Raw seconds since midnight |

### Date expressions

| Format | Example | Meaning |
|--------|---------|---------|
| ISO 8601 | `2024-03-15` | Specific date |
| Keyword | `today`, `tomorrow`, `yesterday` | Relative to run date |
| Relative | `+1`, `-7` | Days from `base_date` |

### `weather` object fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `temperature` | number | — | Air temperature in °C |
| `wind_speed` | number | — | Wind speed in m/s |
| `wind_direction` | number | — | Wind direction in degrees (0 = North) |
| `visibility` | number | — | Visibility in metres |
| `cloud_type` | string | — | `clear` \| `few` \| `scattered` \| `broken` \| `overcast` |
| `cloud_height` | number | — | Cloud base altitude in metres |
| `fog_enabled` | boolean | `false` | Enable fog effect |

### Minimal example

```yaml
position:
  latitude: 42.3
  longitude: 43.4
  timezone: "Asia/Tbilisi"

base_date: "2024-06-01"

versions:
  - name: dawn
    time: "sunrise+20*60"
    metar: "METAR UGTB 010500Z 27010KT 9999 FEW030 18/10 Q1016"

  - name: afternoon
    time: "15:00"
    weather:
      temperature: 28.0
      wind_speed: 5.0
      wind_direction: 180.0
      cloud_type: "few"
      cloud_height: 2500
```

---

## Step 4 — Dynamic-Slot Warehouses (`warehouses.yaml`)

Configures DCS **Dynamic Slots** per coalition. It runs **after** aircraft
injection (so the `dynSpawnTemplate` groups already exist) and edits the
mission's `warehouses`: it enables `dynamicSpawn` on the selected airbases, sets
fuel / munitions and aircraft stock, and links each offered aircraft type to its
template group via `linkDynTempl`.

### Default file location

`src/warehouses.yaml` (auto-enabled when present; disable with `pipeline: { warehouses: false }`).

### Schema

```yaml
<coalition>:                 # blue | red | neutral. An undeclared coalition is left untouched.
  defaults:                  # applied to every selected airport
    fuel: unlimited          # optional -> unlimitedFuel
    weapons: unlimited       # optional -> unlimitedMunitions
    aircrafts:               # aircraft types offered as dynamic slots
      <DCS type>: { amount: unlimited | <int>, template: "<group name>" }
  airports:                  # optional. Absent -> ALL airports of this coalition get `defaults`.
    <name or id>: { }                       # defaults only
    <name or id>: { aircrafts: { ... } }    # defaults + per-airport override
```

- `template` references a template group by **name**; omit it to auto-match a
  template group of the same **aircraft type** (same coalition).
- Airports may be named only on installed theatres present in the committed
  airdrome table (`veaf-build update-dcs-data --airdromes`); otherwise use the
  numeric id (visible in the mission's `warehouses` as `airports[<id>]`).

### Minimal example

```yaml
blue:
  defaults:
    fuel: unlimited
    aircrafts:
      UH-1H: { amount: unlimited, template: "DST - UH-1H" }
  airports:
    Senaki-Kolkhi: {}
```

---

## Step 5 — Spawn Data (`spawn-groups.yaml`)

The `_spawn unit <alias>` and `_spawn group <alias>` marker commands rely on two Lua tables (`veafUnits.UnitsDatabase` and `veafUnits.GroupsDatabase`). Since v6 these are no longer hard-coded in `veafUnits.lua`: they come from YAML, are rendered to Lua, and **injected into the `.miz` at mission build** (DCS cannot parse YAML at runtime). See [ADR 0005](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0005-spawn-data-externalization.md).

### Always on

Unlike the other steps, `spawn_data` **always** runs (even with no mission file) because the framework spawn database must be embedded for `_spawn` to work. To disable it entirely:

```yaml
pipeline:
  spawn_data: false
```

### Extending the database (`src/spawn-groups.yaml`)

An optional `src/spawn-groups.yaml` lets a mission add or override units/groups. It is **merged over** the framework data:

- a brand-new alias is **appended**;
- an alias already present in the framework **replaces** that entry (override).

### Schema

```yaml
units:                              # -> _spawn unit <alias>
  - aliases: [myaaa]                # one or more case-insensitive aliases
    unitType: ZSU-23-4 Shilka       # a DCS unit type id

groups:                             # -> _spawn group <alias>
  - aliases: [mysam]
    disposition: {h: 3, w: 3}       # placement grid in cells (10m x 10m)
    units:
      - {type: ZSU-23-4 Shilka, cell: 1}
      - {type: Ural-375, random: true}                       # randomized within its cell
      - {type: Soldier M4, number: {min: 2, max: 4}, random: true}
    description: My custom SAM site
    groupName: MySAM
```

Group-unit fields: `type` (required), `cell` (preferred cell), `number` (count, or `{min, max}` random), `hdg` (heading), `size` (fixed cell size in m), `random` (randomize within the cell), `fitToUnit` (cell shrunk to the unit's exact footprint).

The framework database lives in `veaf_libs/data/veaf-units.yaml` (bundled with the tool).

---

## See Also

- [mission.yaml Reference](MISSION_YAML_REFERENCE.md) — top-level mission configuration
- [Mission Maker Guide](mission-maker/GUIDE.md) — complete workflow
