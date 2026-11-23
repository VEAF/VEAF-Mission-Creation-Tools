# 02 — CAS and SEAD flights in the shop

Status: 🔄 in-progress
Type: feature

## Asked

David, 2026-11-19: Foothold's AI attack flights the shop lacks, the CAS and the SEAD.

## To do

- Two shop items on the player side, each with a selector of enemy zones (`zones = "enemy"`, as the BARCAP):
  - **CAS flight**: the player side's `dynamic.air.<side>.cas` template (A-10C on the Oronte campaign), taking off from the nearest friendly airfield it may take off from (`canTakeOffFrom`, with the runway length rule of FIX-CAMPAIGN-SECOND-SERVER-FLIGHT ticket 01), attacking the zone's garrison;
  - **SEAD flight**: the side's `sead` template, against the zone's air defence; Foothold's "push on command" (the flight holds until the buyer says go) is a reco, not a must — say in the ticket whether it is done.
- Built on the red side's existing sorties (`veafCampaignOps` CAS and SEAD, their follow-up and `[CAMPAIGN FLIGHT]` log lines), not a second implementation.
- One flight of each kind in the air at a time per side (Foothold's rule); the shop says so when one is up.
- Prices: CAS 500, SEAD 600 credits (PRD), in `veafCampaignEconomy` prices.
- Docs FR/EN, the player document's shop list, CHANGELOG, tests (TDD).

## Done when

A pilot buys a SEAD on Aleppo, the flight takes off from Hatay or Gaziantep and engages Aleppo's air defence; a second SEAD is refused while it flies; with tests, and the in-game check written.

## Done (2026-11-20)

- Two shop items, `cas` (500) and `sead` (600), with the enemy zones as targets.
- Built on the enemy AI's strike: `veafCampaignOps.spawnStrike` (taken out of `launchStrike`, which now calls it) spawns the `campaign_strike` role with the side's `dynamic.air.<side>.cas` or `sead` aircraft, from `nearestOwnZone(side, zone, true, role)` — the airfield `canTakeOffFrom` accepts, its runway length rule included, a SEAD allowed under an enemy defence. Its flight is followed and logged like the AI's (`[CAMPAIGN FLIGHT]`).
- One flight of each kind in the air at a time for the players' side (`flightsUp`), refused with "a flight of that kind is already in the air"; the other kind is not held back.
- **Push on command: not done.** The SEAD leaves at once; Foothold's "push on command" would need a radio command to raise the strike's hold flag, which the purchase does not give today.

## In-game check

1. F10 → Other → VEAF → Campaign → Shop → SEAD flight → Aleppo.
2. The message says "SEAD flight: leaving Hatay for Aleppo" (or Gaziantep); the aircraft of `dynamic.air.blue.sead` (two F/A-18C by default) take off from that field.
3. They fire HARMs at Aleppo's air defence (`[CAMPAIGN FLIGHT]` lines in `dcs.log`).
4. Buy a second SEAD while they fly: refused, balance unchanged; a CAS flight is still accepted.
