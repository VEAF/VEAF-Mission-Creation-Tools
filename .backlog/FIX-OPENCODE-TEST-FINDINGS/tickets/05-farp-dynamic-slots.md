# 05 — The FARP's dynamic slots

Status: ⬜ ready

`add_farp` placed "FARP Azaz" (blue, Turkey, `farp_type: FARP`); `src/warehouses.yaml` named it under `farps:`; every build said "configured 10 airports, 0 ships/FARPs" and later "Ship/FARP '1' not found in the mission (farps); skipping it".
The mission's warehouses table held the FARP under `warehouses` (id 1, `dynamicSpawn = false`, no aircraft), not under `farps`.

Investigate on a clean folder: `add_farp`, then a `farps:` entry in `warehouses.yaml`, then build — does the FARP get its template links?
Fix whichever side is wrong (`add_farp`'s warehouse entry, or the build's lookup); a non-defect is written down here with its measurement.
