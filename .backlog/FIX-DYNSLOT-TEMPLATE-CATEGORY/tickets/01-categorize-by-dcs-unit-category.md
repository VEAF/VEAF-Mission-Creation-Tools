# FIX-DYNSLOT-TEMPLATE-CATEGORY-001 — categorize templates by DCS unit category

Status: ✅ done
Type: fix
Files: aircraft-groups extraction (`aircrafts_injector/` / `extract-aircraft-groups`), default templates, `test/python/`

## What to build

Make the aircraft-groups extraction categorize each group by DCS unit category
(airplane vs helicopter) when emitting `dynamic-slot-templates.yaml`; airplanes must
land under `airplanes:`, not `helicopters:`. Regenerate the shipped/test templates.
Repro: extract a mission containing an A-10C II dynamic-slot template, confirm it
appears under `airplanes:` and injects as an airplane group in the ME.

## Acceptance criteria

- [x] Extraction classifies each group by DCS unit category
- [x] Airplanes land under `airplanes:`, rotary under `helicopters:`
- [x] Shipped/test templates regenerated
- [x] Non-regression test asserts an airplane type lands under `airplanes:`

## Blocked by

None — can start immediately

## Notes

Done in #515.
