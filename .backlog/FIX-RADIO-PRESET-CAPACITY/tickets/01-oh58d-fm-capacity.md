# 01 — The OH-58D FM radios declare their capacity

Status: ✅ done

## Done when

- `OH58D` radios 3 and 4 in `dcs-radio-layouts.yaml` carry `capacity: 21` (PRD D2), with a comment giving its source: the module file that documents it, or the 2026-11-10 measurement (21 works, 32 crashes).
- A test injects a 30-entry `fm_supplement` into an OH58D unit and a dynamic-slot template, and asserts on the **built** radio table that `Radio[3]` and `Radio[4]` hold 21 channels, the `C` and `M` head slots in place.
- The UHF/VHF radios (1, 2) and the other aircraft's radios are byte-for-byte unchanged (test).
