# 01 — ATO: dynamic slots say so, with the flights' callsigns

Status: ✅ done

The ATO of a dynamic-slot base listed every type the base offers (61 on Ramat David, six slides for two bases). A new optional `flights` parameter names the package's flights (callsign, base, aircraft, count, task); a base offering dynamic slots shows one line, "dynamic slot", then those flights with their pilot boxes. Without `flights` the base's line and one row of pilot boxes, never the types.

Done when: the behaviour is covered by a test, and the action's documentation says it.

## Result

`PackageFlight` and the `flights` parameter; `_ato_page` lists them under their base (`Ninja — 2 × F-16C — SEAD (slot dyn)`, pilot boxes as many as `count`), those of no base offering slots under "any base" with a warning. `mission_reader.slot_flights` and `SlotFlight` are gone. Measured on Marteau du Golan: the ATO is one slide, it was six. Tests: `TestDynamicSlotAto`, `test_the_flights_on_dynamic_slots_reach_the_ato`.
