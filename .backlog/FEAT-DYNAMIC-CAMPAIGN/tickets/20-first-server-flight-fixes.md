# 20 — What the first server flight taught (2026-11-16)

Status: 🔄 in-progress — one branch (`fix/campaign-cap-follows-fighters`), one pull request into `feature/dynamic-campaign`

## Why

"Bouclier de l'Oronte" (Syria, persistent) flew on Privé 1 on 2026-11-16 with up to six players.
David asked for nothing to be fixed live, only noted: the notes, with UTC times and log evidence, are in `D:\dev\_VEAF\tmp\dynamic-syria\soiree-2026-11-16.md` (18 points, synthesis at the top).
This ticket carries all of them; the numbers below are the synthesis's.
The branch already holds the CAP sized on the fighters, the escort item (`c066c537`, `1051dbdb`) and the "(admin)" menus asking the admin level (`36b09682`, point 3).

## What

1. **A CSAR pilot is never an enemy, in every VEAF script.** One shared predicate, `veaf.isCombatant(object)`, false for a CSAR crew (the CSAR module's `woundedGroups` registry first, the `Downed Pilot #` / `Wounded Pilot #` names otherwise).
   Used by the campaign's capture and contest (`holdsGround`) and zone wake-up (`wakerPoints`), and by the convoy watch (`veafGroundAI.isLivingGroundUnitOf`, which every enemy search of `GROUNDAI` goes through).
   Combat zones count only their own elements and search no foreign unit: nothing to filter there.
   The VEAF CTLD build has no airbase occupation: the Minakh flip was DCS's native capture, point 15.
   `CSAR.lua:1150` (`_woundedLeader` nil after a `_destroy`): a group gone without a pickup is forgotten instead of indexed.
2. **Long-range SAMs are a zone property.** `long_range_sam: true` on a zone of `campaign.yaml`; the shipped `airfield` class no longer draws one.
   `campaign validate` refuses more than `long_range_sams.per_side` (2) per declared side and two closer than `long_range_sams.min_spacing` (120 km).
18. **The admin commands come last** in the Campaign menu (Counters, Self-check, Reset), after the shop and the rest.
4. **The AI's economy**: `resources.start` 500 → 1000, `factory.per_hour` 120 → 180, `resources.background_per_hour` 30 → 60; a zone taken by a helicopter alone gets a token garrison (what a helicopter carries), not its class's; a garrison its side cannot pay is token (checked by a test).
5. **Helicopter capture**: a zone held by landed helicopters only takes `helicopter_capture_seconds` (600 s) rather than `capture_seconds`; an enemy capture or resupply helicopter is announced to the other side when it leaves.
6. **The CAS strike** never targets a zone under a measured enemy air defence (the zone's own or a neighbour's); with none suitable, no CAS, said once.
7. **A convoy that never arrives frees its place**: ended after `convoy_timeout` (2,700 s), or as soon as its target is no longer to take (its side holds it); its units are removed and their price goes back to its side.
8. **Assault convoys in persistent mode**: only the sides of `dynamic.attacks` send the automatic ones toward neutral zones; no automatic convoy leaves toward a zone a convoy of the same side already drives to (the plan is checked again when it is due).
9. **Every campaign announcement says who speaks**: "Commandement bleu :" / "Commandement rouge :" for a side's own news, "Renseignement :" for what is learnt of the enemy.
10. **A convoy is announced when it leaves** in persistent mode (no `intel_seconds` delay).
11. **A waypoint per zone**: `campaign next` writes one navigation point per zone, the most strategic first (front zones, then airfields, factories, depots, by distance to the front) up to the module's limit; the number shows on the F10 label and in every text that names a zone ("Taftanaz (WP 7)").
12. **BULLSEYE on the ground** in every VEAF mission (0 m above ground, `RADIO`), where a pod or a weapon slaved to the steerpoint looks.
13. **Presets per theatre**: `prepare --theatre X` ships a plan with that theatre's airfields; the build warns on an airfield preset absent from the theatre.
14. **AWACS and tankers placed by the threat**: the campaign holds each `dynamic.support` asset at the first point out of every measured enemy air defence plus a margin, moves it closer when a SAM dies and away when one is measured, and tells its side.
15. **The campaign alone decides who owns an airfield**: DCS's automatic capture is turned off on every airbase of a persistent campaign.
16. **Credits in two parts**: `economy.landing_share` (50 %) of a gain is held until the pilot lands at a friendly airfield, FARP or carrier; lost on ejection, death or crash.
17. **The log**: a sortie refusal is said once per reason until it changes; no `nil` in `[CAMPAIGN FLIGHT]`; a wreck killing scenery is not a kill.
   The supply helicopters that landed back at Aleppo: see the findings below.

## Findings

- To be filled as the work goes.

## Done when

Lua and Python gates green, `docs-check` green, docs FR + EN, CHANGELOG, known limitations; the Syria campaign rebuilt (not deployed); the PR reviewed; the in-game list handed to David.
