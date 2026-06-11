# DCS reference data generators

Some build tools need DCS database facts that are not in a mission file — the
numeric **country id** for a country name, the valid **radio frequency ranges**
for an aircraft, the list of known **unit types**. These facts are generated
into committed artifacts so the build never needs a DCS installation.

## Sourcing strategies

There are **two** ways DCS data enters the repository, and they are not
interchangeable:

| Source | How | Needs DCS? | Examples |
|--------|-----|-----------|----------|
| **Community datamine** | clone `Quaggles/dcs-lua-datamine` at a pinned ref | no | country table, radio specs |
| **In-DCS export** | run `src/scripts/veaf/dcsDataExport.lua` from the Mission Editor, commit the dump | yes | `dcsUnits.lua` (unit database) |

The datamine path is reproducible and CI-checkable; the in-DCS export is a
manual step performed when DCS adds units.

## The `update-dcs-data` command

Datamine-sourced artifacts are regenerated with:

```bash
veaf-build update-dcs-data            # everything safe to regenerate (countries)
veaf-build update-dcs-data --countries
veaf-build update-dcs-data --radio
```

The datamine is cloned at a **pinned** ref
(`veaf_build.dcs_data.datamine.DATAMINE_REF`), so generation is reproducible:
re-running on the same ref yields a byte-identical artifact, and CI can detect a
committed artifact that drifts from the generator. To pick up newer DCS data,
bump `DATAMINE_REF`, re-run the command, and commit the diff.

### Pure vs. hybrid artifacts

- **`dcs-countries.yaml`** is a **pure** artifact — 100 % generator output. Never
  edit it by hand; CI fails if it drifts from the generator.
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
