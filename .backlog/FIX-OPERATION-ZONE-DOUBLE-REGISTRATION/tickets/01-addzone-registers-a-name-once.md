# 01 — AddZone registers a name once

Status: 🔄 in progress

## Done when

- An operation's `addTaskingOrder` on a zone already added leaves one entry in `zonesList` (`test_addTaskingOrder_does_not_register_a_registered_zone_again`).
- A zone the configuration did not add is still registered by the operation that references it (`test_addTaskingOrder_registers_a_zone_the_config_did_not_add`).
- A second zone object under a taken name is refused and the first one kept (`test_AddZone_keeps_the_first_zone_registered_under_a_name`).
- The known limitation `operation-registers-its-zones-twice` carries `fixed_in: "6.34.0"`.
- In game, on "Marteau du Golan": the mission-check inventory lists each member of OpMarteauGolan once (to check by Zip).
