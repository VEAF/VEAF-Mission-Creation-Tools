# 19 — V1.5: documentation, example, test mission, self-check

Status: 🔄 in-progress

## What

- `doc/mission-maker/PERSISTENT_CAMPAIGN.md` and `.en.md`: zone kinds, resources and production, the supply network, paid spawns, demolition, warehouses, bombers, territory, every new setting with its default.
- The example persistent campaign gains a factory and a depot per side.
- The admin self-check (`veafCampaign.selfChecks`) gets one verdict per new mechanism: resources and production of both sides, the network (deliveries ordered and arrived, zones cut off), factories (buildings standing), paid spawns (charged, refused), demolition, warehouse moves, bombers, territory cells drawn.
- The V1 test mission (`D:\dev\_VEAF\tmp\dynamic-campaign-test`) gets a factory and a depot per side, rebuilt with the V1.5 scripts; David is given each menu path and what to look at.
- `CHANGELOG.md`, `known-limitations.yaml` for what stays unmeasured (warehouse counts of an unlimited warehouse, the bomber's drop, the sappers' blast).

## Done when

`docs-check`, the Python and Lua gates green; the test mission builds; the in-game list handed to David.
