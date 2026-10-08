# 05 — CTLD crates and troops at the blue airfields

Status: ⬜ ready
Type: fix

## Found

David, 2026-10-08: "pas moyen de faire spawner des caisses CTLD ni de prendre des troupes (batumi et kobuleti)", in a CH-47F, and "le chinook était dans la zone verte".

What CTLD registered at the mission's start (`dcs.log`, 19:23:21 UTC):

| zone kind | registered |
|---|---|
| troop pickup | the Stennis **only** (`troopZoneShipTypes - 1 ship(s) registered`, `ready - troop:1 logistic:1`) |
| logistic (crates) | the Stennis, then `AB_Batumi`, `AB_Senaki-Kolkhi`, `AB_Kobuleti`, each `FOB logistic zone … r=250m` (`initializeAllLogisticInCTLD: 3 airdrome(s) registered`) |

Every CH-47F entered as `transport=true vehicles=false`.

Hypotheses, none checked yet:

- **Troops**: no troop pickup zone exists on any airfield, so troops can be taken only from the carrier.
- **Crates**: the Chinook was inside "the green zone", which rules out the plain answer that 250 m around the airbase point misses the stands — unless the green zone the players saw is not the 250 m logistic zone (the campaign draws its own zone circles, 2 000 m). Which drawing is green is the first thing to settle.
- `AB_Senaki-Kolkhi` is a **red** airfield registered as a logistic zone: check whether a logistic zone is bound to a side, and what an airfield that changes hands does to it.

## To do

- Read `CTLDZoneManager` and `initializeAllLogisticInCTLD` (`veafTransportMission`), and how `FEAT-CTLD-AIRBASE-LOGISTICS` meant an airfield to become a logistic zone (`airbase_logistics_radius`).
- Give the blue airfields a troop pickup zone and a logistic zone that the stands and the helicopter spots fall into, for the side that holds the field — following ownership changes in a campaign.
- What only DCS can settle goes into the lot's test mission: a CH-47F on a Batumi stand asking for a crate and for troops.

## Done when

At Batumi and Kobuleti, a CH-47F on a stand or a helicopter spot can spawn a crate and take troops; at Senaki, held by red, a blue helicopter cannot.
