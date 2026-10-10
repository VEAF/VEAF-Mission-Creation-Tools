# 05 — CTLD crates and troops at the blue airfields

Status: 🧑 waiting-human
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

## Read (2026-10-09)

- **Troops, cause found**: VEAF registers each held airfield with `registerFOBAsLogistic` only, never `registerFOBAsTroopZone`, which CTLD offers.
- **Crates, not explained**: the green circle is the 250 m logistic zone itself (`drawLogisticCircle`), so a Chinook inside it should have had *Request Equipment*.

## Decided (David, 2026-10-09)

**The zone is not enlarged**: why crates fail inside it is found first, in game with the fiddle hook (`p2-escort-ctld.lua`, `p3-players.lua`).

## Measured in game (2026-10-09, `Kolkhida-DIAG-R47.miz`, fiddle hook)

- A CH-47F player slot on Batumi stand 6 (the zone's own centre) was seated by DCS 244 m from it: inside the 250 m zone, but only just. `getLogisticZonesAtPoint` counts it in; *Request Equipment* shows.
- **Crates, cause found**: picking one does nothing. `CTLDCrateManager:spawnCrate` returns nil because, given no country, CTLD creates the static under `country.id.USA` (blue) or `RUSSIA` (red), hardcoded at six sites. A campaign's coalitions hold only CJTF Blue / CJTF Red: `coalition.getCountryCoalition(country.id.USA)` = 0, `coalition.addStaticObject` raises, and CTLD swallows it. The same static under `CJTF_BLUE` exists.
- Every stand of Batumi and Senaki is on `RUNWAY` surface (ticket 03).

## Decided (David, 2026-10-09)

**Fixed at the source, in VEAF/CTLD** (option b): CTLD takes the requesting unit's country, and says so when a creation fails. No workaround in VMCT. This ticket then takes the fixed CTLD release through `vendored.yaml`; the troop pickup zones at the airfields stay this ticket's own fix.

## Left (2026-10-09)

The troop pickup zones are in.
Left: the VEAF/CTLD release that takes the unit's country, vendored through `vendored.yaml`, then `R47` item 1.

## Seen in game (2026-10-10, CTLD rc13)

Troops board and a crate appears at Batumi (stand 6) and at Kobuleti (a ground start 40 m from the logistic centre): the fix of VEAF/CTLD#256, vendored in #1116, works. The crate stands 20 m off, not against the hull: the campaign's `ctld-config.yaml` predates rc13's per-type `crateSpawnSector` / `crateSpawnDistance`, to be completed before mission 2. A client CH-47F on Kobuleti stand 24 was seated 1.2 km out of the circle by DCS (`known-limitations.yaml`); David keeps the 250 m zone, pilots taxi into it. Left: a blue helicopter on Senaki (red) offered neither.
