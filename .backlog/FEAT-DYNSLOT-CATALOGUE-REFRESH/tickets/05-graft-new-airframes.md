# 05 — Graft the 12 new airframes, blue and red

Status: ✅ done
Type: feat

## What arrives

Twelve airframes the shipped catalogue does not have, taken from Reaper's extract of 2026-09-21:

| coalition in the extract | type | his template | DCS name |
|---|---|---|---|
| blue | `C-130J-30` | `Template C130J-30` | C-130J-30 |
| blue | `F-100D` | `Template F-100D` | F-100D |
| blue | `F-14BU` | `Template F-14BU` | F-14B(U) |
| blue | `La-7` | `Template La-7` | La-7 |
| blue | `MB-339APAN` | `Template MB-339` | MB-339A/PAN |
| blue | `MiG-29 Fulcrum` | `Template Mig-29A Fulcrum` | MiG-29A Fulcrum |
| blue | `P-47D-40` | `Template P-47D-40` | P-47D-40 |
| blue | `P-51D-30-NA` | `Template P-51D-30` | P-51D-30-NA |
| blue | `T-45` | `Template T-45` | T-45 |
| red | `J-11A` | `Template J-11A Red` | J-11A |
| red | `MiG-29S` | `Template MiG-29S Red` | MiG-29S |
| red | `Su-33` | `Template Su-33 Red` | Su-33 |

Each one gets its mirror in the other coalition, so **24 templates** are added and the catalogue goes
from 104 to 128, 64 blue types against 64 red.

Only two carry a loadout in the extract: `MiG-29S` (7 pylons) and `Su-33` (12). The other ten are
bare, like most of the catalogue.

## Normalizing on the way in

Reaper's file follows his mission's conventions, not the catalogue's. Each grafted template is
rewritten to the shipped shape — ticket 04's test is what proves it, so nothing here needs to be
checked by reading the YAML:

| his | ours |
|-----|------|
| `Template M-2000C` | `M-2000C Template` / `… Template Red` |
| country `France`, `USA`, `Russia`, … | `CJTF Blue` / `CJTF Red` |
| `hidden: false`, no `lateActivation` | `hidden: true`, `lateActivation: true` |
| real `x` / `y` (two distinct areas, so two maps) | `0` / `0`, group and unit |
| `password: lG3jX1_GswM:…` | dropped — the injector sets its own |
| unit named like the group | `<group name> #01` |
| route point named like his group | named after ours |
| `groupId` 60–3899, `unitId` 223–7374 | allocated above the catalogue's current maxima (520 / 605) |

Kept as they are: `livery_id`, `callsign`, `payload`, `AddPropAircraft`, `task`, `frequency`,
`alt`. A red mirror keeps the blue template's livery — the catalogue already does that in places
(`Ka-50 Template Red` wears an Italian livery), and inventing liveries is not this lot's job.

`F-14BU` and `MiG-29 Fulcrum` carry a group-level `DTC` block (the module's data cartridge). It is
real configuration, so it is kept, and `DTC` is added to the validator's list of known group keys so
it stops being reported as an *unusual field*.

## Definition of Done

- 24 templates added; ticket 04's test passes, including the blue/red mirror equality and the id
  uniqueness.
- The mission maker's names are the DCS names, so a template is recognizable in the Mission Editor's
  warehouse dialog: `C-130J-30 Template`, `F-100D Template`, `F-14BU Template`, `La-7 Template`,
  `MB-339 Template`, `MiG-29 Fulcrum Template`, `P-47D-40 Template`, `P-51D-30 Template`,
  `T-45 Template`, `J-11A Template`, `Mig-29S Template`, `Su-33 Template`, each with its `… Red`.
  (`Mig-29S` keeps the lower-case spelling of its siblings `Mig-29A` / `Mig-29G` rather than
  introducing a second convention in the same family.)
- `DTC` no longer raises a validation *info*.
- The defaults lockstep (CLAUDE.md §9.7) does not apply: this changes no generated output, only the
  shipped catalogue, which **is** the default.
