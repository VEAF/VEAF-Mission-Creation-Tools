# 02 — A depot is a set of buildings to destroy

Status: ✅ done
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

## Done

- A depot draws and records its buildings as a factory does (`structures`, losses in the save): `network.depot_buildings` (3) among `network.depot_types` (`Warehouse`, `Fuel tank`, `Tank`, three types the DCS database and the spawner's shape table both know). `veafCampaign.staticCategory` gives each static its mission-table category from the DCS database: a warehouse is `Warehouses`, a workshop `Fortifications` — they were all spawned `Fortifications` before.
- `VeafCampaignZone:isWorkingDepot`: a depot works while one of its buildings stands. Its buildings all down, its store is emptied at once and it is an ordinary node: no source of its own, no half hop, no refill from a factory (`hopSeconds`, `supplyDelays`).
- `followDepot`: the time down is counted at each beat and saved (`depot_down_seconds`), so a restart neither rebuilds it nor starts the count again; after `network.depot_rebuild_seconds` (2,700 s, the convoy timeout, the reco) every building comes back at once for the side holding the zone. A delivery never rebuilds a depot's building (`repairStructure` is the factory's).
- The F10 map label counts them, "dépôt 2/3"; both sides are told when a depot's buildings are all destroyed; the theatre dossier's depot line says its buildings destroyed, it stops.
- Doc: the depot kind lives in `PERSISTENT_CAMPAIGN.md` / `.en.md` (`CAMPAIGN.md` covers the episodic campaign, whose `logistics` kind is another thing): what a depot is, how to take one, the settings.
- Tests: the buildings drawn and their category; a depot with its buildings down is an ordinary node, its store emptied, no delivery rebuilds it; rebuilt only after the delay, the delay saved.
- The Oronte save has no depot buildings yet: they are drawn at the next load (Saraqib, Kilis).

## In-game check

Saraqib and Kilis show "dépôt 3/3" on the F10 map. Destroy Saraqib's three buildings: `depot [Saraqib]: its buildings destroyed, an ordinary node for 2700 s`, then no `red supply for [Saraqib] from [Saraqib] … there in 0 s` any more; a destroyed Shilka at Saraqib stays destroyed until a delivery comes from Al-Safira through the network (its hop delay).
