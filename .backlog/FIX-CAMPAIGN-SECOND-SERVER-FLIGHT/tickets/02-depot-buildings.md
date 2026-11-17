# 02 — A depot is a set of buildings to destroy

Status: ⬜ ready
Type: feature

## Found

At Saraqib (depot, WP 18) the players destroyed a Shilka and lorries; they were back about two minutes later.
The log: the depot ordered deliveries **from itself, "there in 0 s"** (21:24:31, 21:26:31, 21:31:31, 21:33:31, 21:37:01), each followed ten seconds later by "group [Saraqib garrison] reinforced".
`veafCampaignLogistics.supplyDelays` refills the depot's store to `depot_store` every time a working factory reaches it (Al-Safira reached it through Aleppo and Abu al-Duhur), so the store never runs out: a depot was invulnerable while its factory worked.
A depot has no statics today, only a garrison (`spawnStructures` is the factory's).

## Decided — David, 2026-11-17

Recorded in `FEAT-DYNAMIC-CAMPAIGN` (row "A depot has buildings to destroy"):
- a depot is a set of **statics, its buildings**, as a factory is; while they stand it is a depot (it stores, it shortens the hops, it may supply itself);
- **its buildings destroyed, it can no longer supply itself and is played as an ordinary node**;
- it may rebuild its depot after a **long** delay, long enough for the players to destroy the whole garrison and capture the zone.

## To do

- The depot's buildings, placed and recorded as a factory's are (`structures`, `spawnStructure`, losses kept in the state), with a shape that exists in DCS (`doc/developer/dcs-data.md` on `shape_name`).
- `supplyDelays` and the self-delivery skip a depot whose buildings are down; the rebuild delay as a setting under `dynamic.network`, its default written with its reason (reco: 45 minutes, the convoy timeout, until an evening measures better).
- The briefing, the F10 map and the theatre dossier show a depot's buildings as they show a factory's.
- The mission-maker doc (`CAMPAIGN.md` and `.en.md`) says what a depot is and how to take one.

## Done when

Destroying a depot's buildings stops its self-supply and its store at once, and it is a depot again only after the delay; tests cover both, and the next evening's check is written.
