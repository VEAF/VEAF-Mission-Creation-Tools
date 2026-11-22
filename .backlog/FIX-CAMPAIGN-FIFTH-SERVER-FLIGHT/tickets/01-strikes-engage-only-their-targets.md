# 01 — Red strikes engage only their targets

Status: ⬜ ready
Type: fix

## To do

- First, a failing test: the route `veafAircraftSpawn.roles.campaign_strike` builds carries ROE `OPEN_FIRE` (`Option name 0 value 2`), not weapon free (`value 0`), at its first point and at the push point of a raid's SEAD.
- `veafCampaignOps.lua` line 992: `value = 2`. The SEAD's hold (`value 4`, weapons held until the push) stays as it is.
- The loadouts keep their R-60M: with `OPEN_FIRE` the AI fires only at the targets its tasks name (DCS documentation); the in-game check says whether that holds.
- Check that `OPEN_FIRE` still lets the `EngageTargetsInZone` task attack the zone's ground units (CAS) and air defences (SEAD). If the in-game check shows it does not, say so in the ticket and fall back to removing the air-to-air missiles from the shipped `cas` loadout.
- Add the measure to `known-limitations.yaml` (`kind: dcs`) if DCS behaves otherwise than its documentation, then regenerate `docs/agents/dcs-runtime-traps.md`.
- Docs: the campaign page if it describes what red's strikes attack; CHANGELOG entry.

## Done when

A red CAS or SEAD flight attacks the zone it was sent to and never an aircraft; with tests.

## In-game check

On the Campagne server or a test mission: a red CAS flight passes within 20 km of the AWACS or a player aircraft without firing at it, and still attacks its zone.
