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
| **DCS install files** | read terrain files from a local DCS install (`--dcs-path`) | install only (not running) | airfield ATC frequencies |

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

`--radio`, `--airdromes` and `--airfield-freqs` are excluded from the no-flag /
`--all` run: radio has manual overlays, airdromes merges committed runtime dumps, and
airfield-freqs needs a local DCS install path (`--dcs-path`).

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
veaf-tools inject-bridge myMission.miz
# 2. launch myMission.miz in DCS + start dcs-serve, then capture
veaf-tools capture-map --api-key <dcs-serve superuser token> --out-dir <folder>
```

On the dev side, `veaf-build update-dcs-data --airdromes` then merges the committed
`.json` under `veaf_build/dcs_data/airbase_dumps/` into the YAML (name→id projection).
Full procedure for helpers: [capture-airbases](capture-airbases.en.md). See the
[VEAF-dcs-bridge repo](https://github.com/VEAF/VEAF-dcs-bridge) for `dcs-serve`.

`veaf_libs.dcs_airdromes.airdrome_id_for_name(theatre, name)` reads it. Coverage: **all 14 DCS theatres** are dumped (810 airbases). Residual caveat:
the table only covers **already-dumped** theatres; an un-dumped theatre yields no
entries — callers fall back to ids. Resolution is case-insensitive.

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
