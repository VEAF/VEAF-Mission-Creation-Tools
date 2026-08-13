# DCS reference data generators

Some build tools need DCS database facts that are not in a mission file — the
numeric **country id** for a country name, the valid **radio frequency ranges**
for an aircraft, the list of known **unit types**. These facts are generated
into committed artifacts so the build never needs a DCS installation.

## Sourcing strategies

There are **two** ways for DCS data to enter the repository, and they are not
interchangeable:

| Source | How | Needs DCS? | Examples |
|--------|-----|-----------|----------|
| **Community datamine** | clone `Quaggles/dcs-lua-datamine` at a pinned ref | no | country table, **units database**, radio specs |
| **In-DCS export** | capture a dump in-game (dcs-bridge `world.getAirbases()`, or `dcsDataExport.lua`), commit the dump | yes (DCS running) | airdrome name→id table, weapons |
| **DCS install files** | read files from a local DCS install (`--dcs-path`) | install only (not running) | airfield ATC frequencies, cockpit controls |

The datamine path is reproducible and CI-checkable; it is the default for all the
data VEAF needs at build/runtime. The in-DCS export now only covers data the
datamine does not expose (airbases, weapons) and is a rare manual step.

## The `update-dcs-data` command

Datamine-sourced artifacts are regenerated with:

```bash
veaf-build update-dcs-data            # every pure artifact (countries + units)
veaf-build update-dcs-data --countries
veaf-build update-dcs-data --units    # regenerates dcsUnits.yaml AND dcsUnits.lua
veaf-build update-dcs-data --radio
veaf-build update-dcs-data --airdromes    # merges the committed runtime dumps
```

`--radio`, `--airdromes`, `--airfield-freqs` and `--cockpit-controls` are excluded from
the no-flag / `--all` run: radio has manual overlays, airdromes merges committed runtime
dumps, and the last two need a local DCS install path (`--dcs-path`).

The datamine is cloned at a **pinned** ref
(`veaf_build.dcs_data.datamine.DATAMINE_REF`), so generation is reproducible:
re-running on the same ref yields a byte-identical artifact, and CI can detect a
committed artifact that drifts from the generator. To pick up newer DCS data,
bump `DATAMINE_REF`, re-run the command, and commit the diff.

### Pure vs. hybrid artifacts

- **`dcs-countries.yaml`** is a **pure** artifact — 100 % generator output. Never
  edit it by hand; CI fails if it drifts from the generator.
- **`dcsUnits.yaml`** and the rendered **`dcsUnits.lua`** are **pure** artifacts
  too (see [The units database](#the-units-database)). Both are CI-guarded; edit
  the generator, not the files.
- **`dcs-radio-specs.yaml` / `dcs-radio-specs.md`** are **hybrid**: a generated
  base plus **manual overlays** the generator does not reproduce — the
  `dcs_rejects_on_load` flags (aircraft that crash DCS on load with an
  out-of-range preset) and a hand-written bilingual "critical aircraft" doc
  section. Because of this, `--all` **skips** radio (with a warning), and
  `--radio` regenerates but warns that the overlays must be re-applied
  afterwards.

`update-radio-specs` remains as a compatibility alias for `--radio`.

## The country table

`src/python/veaf-tools/veaf_libs/data/dcs-countries.yaml` maps every DCS country
to its numeric id, matched by canonical name, Mission Editor display name
(e.g. `CJTF Blue`) and short code. It is read at design time by
`veaf_libs.dcs_countries.country_id_for_name()` — notably by the aircraft
injector, which must stamp a valid `country.id` on any country it synthesizes,
otherwise the DCS Mission Editor crashes on load
(`me_mission.lua` → `fixCountriesNames` → nil-index).

## The units database

The DCS unit database is generated from the datamine in **two stages**:

```text
_G/db/Units/**          (datamine, pinned ref)
   │  veaf_build.dcs_data.units   →  parse + derive
   ▼
dcsUnits.yaml           (committed canonical source, veaf_libs/data/)
   │  veaf_build.dcs_data.units_lua  →  render
   ▼
dcsUnits.lua            (committed runtime table, src/scripts/veaf/)
   │  loaded in DCS
   ▼
veafUnits / veafSkynetIadsHelper   (runtime consumers)
```

`veaf-build update-dcs-data --units` runs both stages.

### Derived `kind`

Each unit gets a single **`kind`** — `air` / `naval` / `infantry` / `vehicle` /
`static` — derived from the DCS `attribute` flags, in priority order:

| Priority | Signal (attribute) | kind |
|---|---|---|
| 1 | `Air` | `air` |
| 2 | `Naval` or `Ships` | `naval` |
| 3 | `Infantry` | `infantry` |
| 4 | `Ground vehicles` / `Vehicles` / `GroundUnits` / `RailwayUnits` | `vehicle` |
| 5 | *(none of the above)* | `static` |

`kind` replaces the four mutually-exclusive booleans the old in-DCS export wrote
(`naval`/`air`/`infantry`/`vehicle`). `RailwayUnits`/`GroundUnits` catch rail
stock (locomotives, wagons), which the old export classified as vehicles.

### YAML and Lua schema

`dcsUnits.yaml` is the source of truth:

```yaml
units:
- type: "1L13 EWR"          # DCS type id (database key)
  name: EWR 1L13            # display name
  kind: vehicle
  category: Air Defence     # DCS display category (planes/ships/helicopters derived from the folder)
  description: EWR 1L13
  attributes: [EWR, "Air Defence vehicles", ...]
naval_statics:              # offshore statics DCS places on water (curated list)
- offshore WindTurbine
```

`dcsUnits.lua` renders that into the lean runtime table — keyed by `type`, with a
single `kind` and an `attribute` map (Skynet keys on `SAM SR` / `EWR`):

```lua
dcsUnits.NavalStatics = { ["offshore WindTurbine"] = true, ... }
dcsUnits.DcsUnitsDatabase = {
  ["1L13 EWR"] = {
    type = "1L13 EWR", name = "EWR 1L13", kind = "vehicle",
    category = "Air Defence", description = "EWR 1L13",
    attribute = { ["EWR"] = true, ... },
  },
}
```

The runtime reads `type`, `name`, `description`, `category`, `kind` and
`attribute`; `veafUnits.processUnit` turns `kind` back into the
`naval`/`air`/`infantry`/`vehicle`/`static` flags the rest of the code expects.
The Lua file is **excluded from `stylua`** (`.styluaignore`) because its
formatting is deterministic generator output.

### Carried-over units and naval statics

Two things the datamine does not provide are handled explicitly in
`veaf_build/dcs_data/units.py`:

- **`CARRIED_UNITS`** — units present in the old export but absent from the
  datamine (currently `Container_20ft` / `Container_40ft`). Carried verbatim so
  the migration never loses a unit.
- **`NAVAL_STATICS`** — the short offshore-static list (`Oil platform`, …). The
  datamine has no reliable flag for these (`isPutToWater` is false even for the
  offshore wind turbine), so the list is curated here.

When DCS ships a unit the datamine lacks, or a new offshore static, add it to the
relevant constant.

## The airdrome table

`src/python/veaf-tools/veaf_libs/data/airdromes.yaml` maps, **per theatre**, an
airfield display name to its numeric **airdrome id** — the same id a mission's
`warehouses` uses as `airports[<id>]`. It lets build tools (the Dynamic-Slot
warehouse wiring) accept airfield *names* instead of raw ids.

It is **runtime-dependent**: the only source for the *exact* name `Airbase.getByName`
/ a QRA `airport_link` expects is DCS itself (`Airbase:getName()`). Terrain files carry
*beacon*/*ATC* callsigns that differ from the real name (e.g. `Abu_Ad_Duhur` instead of
`Abu al-Duhur`) — hence `Beacons.lua` is dropped. Each theatre is captured once in-game
with the **VEAF dcs-bridge** (`world.getAirbases()`, category `AIRDROME` — everything,
airfields **and** terrain helipads, all valid `Airbase` objects with a warehouse) and
the dump committed under `veaf_build/dcs_data/airdrome_dumps/<Theatre>.tsv`
(`<id><TAB><name>`). `--airdromes` merges the available dumps into the YAML (a dumped
theatre is regenerated, a theatre with no dump is preserved — migrated lot-by-lot). It is
**not CI-guarded** (depends on a running DCS):

```bash
veaf-build update-dcs-data --airdromes
```

**Capturing a dump (delegable, no source or Python).** Two `veaf-tools` commands (so
in the shipped executable, usable by a non-dev) produce the rich
`airbase_dumps/<theatre>.json` dump (`{id, name, lat, lon, coalition}` per airbase):

```bash
# 1. inject the bridge into any mission on the target theatre
veaf-tools dcs inject-bridge myMission.miz
# 2. launch myMission.miz in DCS + start dcs-serve, then capture
veaf-tools dcs capture-map --api-key <dcs-serve superuser token> --out-dir <folder>
```

On the dev side, `veaf-build update-dcs-data --airdromes` then merges the committed
`.json` under `veaf_build/dcs_data/airbase_dumps/` into the YAML (name→id projection).
Full procedure for helpers: [capture-airbases](capture-airbases.en.md). See the
[VEAF-dcs-bridge repo](https://github.com/VEAF/VEAF-dcs-bridge) for `dcs-serve`.

`veaf_libs.dcs_airdromes.airdrome_id_for_name(theatre, name)` reads it. Coverage: **all 14 DCS theatres** are dumped (810 airbases). Residual caveat:
the table only covers **already-dumped** theatres; an un-dumped theatre yields no
entries — callers fall back to ids. Resolution is case-insensitive.

## Parking spots {#parking}

`parking/<theatre>.json` lists, **per theatre**, the spots an aircraft can park on. Kept separate
from the airbase dumps rather than merged into them: the 15 theatres already captured need no
redoing, and the airbase capture stays the useful half if the second one fails.

Captured in game with the **VEAF dcs-bridge**, `Airbase:getParking(false)` per airbase:

```bash
veaf-tools dcs capture-map --parking
```

**A parked aircraft carries two distinct numbers, and confusing them puts the aircraft somewhere
else**: `parking` and `parking_id`, which are 28 and 24 on the same F-14A in this repository's own
fixtures. They are the runtime's `Term_Index` and `Term_Index_0`. That pair is what turned
`add_air_group` on a ramp into a data capture (ticket 08) and then a write (ticket 09) rather than
one task: no data shipped here carried those numbers — the 15 airbase dumps hold only
`{id, name, lat, lon, coalition}`.

The dump keeps **every** key each spot carries, flattened one level and kept as strings: the API
schema shipped here declares four fields where a mission file already proves there are more, so the
shape comes from the runtime rather than from the schema. A test pins that an unknown future field
survives the read. A theatre reporting no spots is data, not a failure.

Not guarded by CI, like the other runtime-dependent tables. The operator's procedure is in
[Capture a map's airbases](capture-airbases.en.md).

## The airfield-frequency table

`src/python/veaf-tools/veaf_libs/data/airfield-frequencies.yaml` maps, **per theatre**,
an airfield name to its **ATC frequencies** (`uhf`, `vhf`, `fm`, in MHz). It lets
`convert-v5` replace hardcoded preset frequencies with readable aliases (e.g. `Gudauta`).

Like the airdrome table it is **install-dependent** (source:
`Mods/terrains/<Theatre>/Radio.lua`, the `frequency` block — `UHF`→`uhf`,
`VHF_HI`→`vhf`, `VHF_LOW`→`fm`, HF dropped) and **not CI-guarded**:

```bash
veaf-build update-dcs-data --airfield-freqs --dcs-path "C:/Program Files/Eagle Dynamics/DCS World"
```

It only covers **installed** theatres.

## The cockpit-control indexes {#cockpit-controls}

`src/python/veaf-tools/veaf_libs/data/cockpit-controls/<type>.yaml` describes, for one
aircraft, each of its **clickable controls**: the animation argument to read, the hint DCS
shows on mouse-over, the named positions, the value window, and whether the control has a
**readable** position. This is what the guided-checklist resolver reads to turn an
instructor's `throttle sur idle` into technical fields, without anyone opening a DCS
install.

Source: `Mods/aircraft/<Module>/Cockpit/Scripts/clickabledata.lua` (or `Cockpit/` for
Heatblur), plus `clickable_defs.lua` for the value window and `draw_args.lua` when the
module names its arguments. **Install-dependent**, so **not CI-guarded**:

```bash
veaf-build update-dcs-data --cockpit-controls --dcs-path "C:/Program Files/Eagle Dynamics/DCS World"
```

`--aircraft F-16C` restricts generation to one module. A module the install does not have
is skipped; the number of elements the parser could not read is **printed**, never
swallowed.

### What the index says, and what it does not

Three traps, all measured on real cockpits:

- **`positions` is in hint order, not value order.** The F-16C's `MAIN PWR Switch, MAIN
  PWR/BATT/OFF` runs +1 / 0 / -1 in that order, while `DIGITAL BACKUP, OFF/BACKUP` runs
  0 / 1. Inferring a value from a rank is wrong half the time, silently.
- **Naming positions in the hint is a recent ED habit, not a rule.** Across the cockpits
  indexed here: F-16C 127 controls out of 284, AH-64D 123 of 478, A-10C 8 of 470, F-14B
  **none** (Heatblur writes `Hydraulic Transfer Pump Switch`, with no positions). A
  resolver that assumes named positions only works on ED aircraft.
- **`readable: false` is not a gap in the index.** A button has no position, and a
  spring-loaded switch is back at neutral before anything can poll it; a step on one of
  those has to be pilot-confirmed.

Every module has its own dialect, and each was found by indexing a real cockpit: the
AH-64D, a two-seater, names the crew station before the hint (`mpd_button(CREW.PLT,
_("..."), ...)`) and uses single quotes; the A-10C's UFC keypad passes an empty hint;
Heatblur names its arguments (`cockpit_args.HYD_ISOLATION_Switch`) instead of writing them
out. The F-14B(U) has no cockpit of its own: its `clickabledata.lua` is two lines of
`dofile` pointing at the F-14B's, so both aircraft share one index.
