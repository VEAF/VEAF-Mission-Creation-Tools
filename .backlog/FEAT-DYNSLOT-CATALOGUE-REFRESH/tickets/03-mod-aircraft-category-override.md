# 03 — A mod aircraft is filed by the DCS table, not by its category

Status: ✅ done
Type: fix

## The defect

`FIX-DYNSLOT-TEMPLATE-CATEGORY` fixed the general case: DCS files a dynamic-slot template under the
`helicopter` table whatever the aircraft is, so `aircraft_category_for_group` now routes by the
unit's **real** category, read from `dcsUnits.yaml`. When the type is not in `dcsUnits.yaml` it falls
back to the DCS table it was found in — and that fallback is where mod aircraft land.

`dcsUnits.yaml` is generated from the `dcs-lua-datamine` pin and carries stock content only. Measured:

| type | in `dcsUnits.yaml` | shipped bucket |
|------|--------------------|----------------|
| `A-4E-C` | absent | `helicopters:` ❌ |
| `Bronco-OV-10A` | absent | `helicopters:` ❌ |
| `T-45` | absent | — (arrives with ticket 05) |

So the shipped catalogue files a Skyhawk and a Bronco as helicopters, in both coalitions, and
`test_dynslot_defaults_category.py` cannot catch it — its check `continue`s on a type
`dcsUnits.yaml` does not know. Reaper's extract has all three under `airplanes:`, because his mission
happens to hold them in the `plane` table, which is luck rather than a fix.

Consequences beyond tidiness: the injector puts an `airplanes:` template into `country["plane"]` and a
`helicopters:` one into `country["helicopter"]`, and the warehouses step stocks airfields from the
template's bucket. A Skyhawk filed as a helicopter is offered on helicopter pads.

The file says `DO NOT EDIT BY HAND — CI fails if this file drifts from the generator output`, so the
three types cannot simply be added to it.

## What to do

A small curated override, consulted by `aircraft_category_for_group` **before** the fallback: a
mapping of mod type ids to their real category, seeded with `A-4E-C`, `Bronco-OV-10A` and `T-45`.
Keep it next to the categorizer with a comment saying it exists because `dcsUnits.yaml` is stock-only
and must not be hand-edited, and that an entry becomes dead the day a type enters the datamine —
harmless, since the override and the datamine would then agree.

Then move the four misfiled templates in the shipped catalogue: `A-4E-C Template`,
`A-4E-C Template Red`, `OV-10A Template`, `OV-10A Template Red`, from `helicopters:` to `airplanes:`,
content unchanged.

## Definition of Done

- `aircraft_category_for_group({"units": [{"type": "A-4E-C"}]}, fallback="helicopters")` returns
  `"airplanes"`.
- The override is consulted after `dcsUnits.yaml`, not before it: a type present in the datamine wins,
  so the override can never contradict the generated truth.
- `test_dynslot_defaults_category.py` builds its expected bucket through the same path as the code
  (datamine **then** override), so the shipped catalogue is now enforced for these types instead of
  skipped — it must fail before the four templates are moved.
- The four templates sit under `airplanes:` in the shipped catalogue.
