# 02 — CAS and SEAD flights in the shop

Status: ⬜ ready
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
