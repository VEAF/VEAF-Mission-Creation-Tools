# 04 — A QRA takes off from the ground by default

Status: ⬜ ready
Type: feat

Depends on: 03 — a garrison unit on the runway would keep the QRA on the ground.

## Found

David, 2026-10-08: "est-ce que ça serait possible que la QRA décolle vraiment de la piste ? plutôt que de spawner direct en l'air ?", then, decided: "QRA au sol, par défaut".

In mission 1 the three `QRA Senaki` groups (MiG-29, Su-27, MiG-29S) are air starts: one `Turning Point` at 4 572 m.
No new runtime code is needed for a ground start: `veafQraManager` keeps a group's take-off as placed and then climbs it to 27 000 ft for its patrol (`veafQraManager.md`, *what a scrambled group does*), and the MCP's `add_air_group` already offers `runway`, `parking-hot` and `parking-cold`.

## To do

- Make a ground start (`runway`) the default wherever a QRA group is designed: the `veaf-mission-authoring` skill and the MCP guidance that tell Claude how to build a QRA, the campaign mission design rules, and the QRA doc page (FR + EN). An air start only when asked.
- If the MCP has a QRA-specific path that defaults to `air`, change that default; otherwise say it in the guidance.
- Say in the doc what the ground start costs: the minutes to get airborne, to be measured once in game, not estimated; a field hit below `airbaseMinLifePercent` keeps the QRA down (`NOAIRBASE`), which in a campaign is a feature.
- Mission 2 of *Kolkhida* gets its QRA on Senaki's runway.

## Done when

A QRA designed through the MCP without saying how it starts is placed on its airfield's runway, and the doc says so.
