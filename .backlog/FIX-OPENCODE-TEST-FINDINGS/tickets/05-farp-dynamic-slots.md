# 05 — The FARP's dynamic slots

Status: ✅ done

`add_farp` placed "FARP Azaz" (blue, Turkey, `farp_type: FARP`); `src/warehouses.yaml` named it under `farps:`; every build said "configured 10 airports, 0 ships/FARPs" and later "Ship/FARP '1' not found in the mission (farps); skipping it".
The mission's warehouses table held the FARP under `warehouses` (id 1, `dynamicSpawn = false`, no aircraft), not under `farps`.

Investigate on a clean folder: `add_farp`, then a `farps:` entry in `warehouses.yaml`, then build — does the FARP get its template links?
Fix whichever side is wrong (`add_farp`'s warehouse entry, or the build's lookup); a non-defect is written down here with its measurement.

## Measured 2026-10-20 — a defect of the build, fixed

Reproduced on a clean folder through the actions only (the sequence of ticket 04): "configured 2 airports, 0 ships/FARPs", and in the built `.miz` the FARP's warehouse `dynamicSpawn = false` with no aircraft.
Not the AI's hand edits: `add_farp` writes the right entry, under `warehouses.warehouses[<unit id>]`, where DCS keeps ships and FARPs.

Cause: a lone FARP is unit 1, so that table is keyed `[1]`, and the Lua parser reads a table keyed `1..N` back as a **list**.
The build then looked for unit 1 in a list of dicts and found nothing — the same accident as FIX-WAREHOUSES-LIST-FORM, which normalised only the `airports` table at load.
`normalize_warehouses_airports` now normalises both tables; rebuilt with the fix, the FARP has `dynamicSpawn = true` and its helicopter templates linked.
