# 04 — Carrier deck lights follow VEAF air operations

Status: ✅ done

## Done when

- `veafCarrierOperations` sets the carrier's lights to RECOVERY (2) when it starts air operations and to AUTO (-1) when it stops, through `a_set_carrier_illumination_mode` in the trigger environment.
- When the trigger environment cannot be reached, operations run as before and one warning is logged.
- Lua tests on the mocks; `veafCarrierOperations` page FR/EN.
- What the deck looks like in game is ticket 06.
