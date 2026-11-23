# FIX-CAMPAIGN-SIXTH-SERVER-FLIGHT — what the 22/11 evening on the Campagne server showed

Status: 🧑 waiting-human — ticket 04 (campaign data, the control session at the next deploy), ticket 05's measure in DCS, the flight checks

The persistent campaign "Bouclier de l'Oronte" (Northern Syria, `foothold2_server`), flown on 2026-11-22 in the evening. David's seven remarks, read in the server's `dcs.log` and the code on 2026-11-23. Six are this repository's; the seventh, the Fat Cow, belongs to `VEAF/CTLD` (below).

## Read (2026-11-23)

1. **The map shows how long a capture has run, not how long it has left.** `campaign.map_label_capture` and `campaign.situation.capture` (`veafI18n.lua` around line 2028) print `capture.seconds`, the time held so far (`veafCampaign.lua` lines 1787, 1904, 3299); the capture ends at `veafCampaign.captureSeconds(byHelicopter)` (line 1744).
2. **Minakh repaired, then destroyed at once (21:30 UTC).** The log: `the blue supply reaches [Menagh]`, `group [Menagh garrison] reinforced, 5 of 6 dead unit(s) back` at 21:26:35, while the red assault convoy `Aleppo - Menagh assault` stood 1.1 to 4.3 km from the zone and kept firing; the next delivery waited (`the zone lost a unit 60 s ago, under fire`) at 21:31. The only gate is `network.under_fire_seconds` since the zone's last loss (`veafCampaignLogistics.arriveDeliveries`, line 415): a lull of a few minutes lets a repair through under the enemy's guns.
3. **That convoy stayed two hours at Minakh's gates.** `followConvoyProgress` logged it between 1.1 and 4.3 km from Menagh from 95 to 125 min, `convoy Mule: the order given … 25 s ago moved nothing` again and again, then `red convoy … to retire (not arrived after 125 min) stays: in contact` (`veafCampaign.lua` around line 2435). FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT (#1326) and FIX-GROUNDAI-CLOSE-IN-REACHABLE (#1328) were deployed on 2026-11-22 at 10:43 UTC: this is after them.
4. **WP2 is called "Menagh"; it should be "Minakh".** The zone is named `Menagh` in the campaign's `campaign.yaml` (`{ name: Menagh, at: { airfield: Minakh } … }`); DCS calls the airfield Minakh. The name comes from the campaign's data, not from the code.
5. **Several radio menus have "Page suivante" in F9, and another entry in F10.** A defect of VEAF's radio menus (`veafRadio`), not of the campaign: David, 2026-11-23, moved to its own lot, [FIX-RADIO-NEXT-PAGE-IN-F10](../FIX-RADIO-NEXT-PAGE-IN-F10/PRD.md).
6. **The AWACS says nothing, even when asked.** Every call to it fails in DCS's speech: `Error in wMessage::buildSpeech() … Callname -1 not found for AWACS Magic-1` (picture, bogey dope, "clean"), on 2026-11-21 from 22:00 UTC and on 2026-11-22. The AWACS bought back in the shop is respawned by `veafAssets.respawn` → `VeafGroupSpawn:new():forGroup(name):withRoute(…):respawn()` (`veafAssets.lua` line 171, `veafDcsSpawner.lua` line 914); its callsign does not survive.
7. **The infantry of enemy zones is scattered and hard to find.** `veafCampaign.composeGarrison` places every group, infantry sections included, at its own random point anywhere in the zone's radius, 2 to 3 km (`placeGarrisonGroup`, `veaf.findPointInZone(center, radius)`, line 550).

## Not this repository

**A Fat Cow took off again from where its FARP had been set up (`CTLD Fat Cow 1`) and hovered until it fell, out of fuel.** The Fat Cow runtime lives in `VEAF/CTLD` (`CTLDFatCowManager`); its log line that evening: `CTLDFatCowManager: cow 'Fat Cow Hatay_AH-64D BLK.II_26 #1-1' is no longer in the world, with no event: forgotten` (21:16:55 UTC). The same family as `FIX-FAT-COW-AI-LANDING` (in progress) in that repository's backlog. To be filed there, not here.

## Decided

David, 2026-11-23: "fais les lots". One lot for the campaign's points (the radio menus went to their own lot), the recommendations of each ticket as the default, one branch and one pull request into `develop` (the integration branch `feature/dynamic-campaign` was merged and deleted on 2026-11-23). Ticket 04 is campaign data, done by the control session at the next deploy, no code.

| # | Ticket |
|---|---|
| 01 | [The capture shows the time left](tickets/01-capture-time-left.md) |
| 02 | [No repair with the enemy at the gates](tickets/02-no-repair-under-the-enemy.md) |
| 03 | [A convoy does not sit two hours "in contact"](tickets/03-convoy-in-contact-two-hours.md) |
| 04 | [Menagh becomes Minakh](tickets/04-menagh-becomes-minakh.md) |
| 05 | [A respawned AWACS keeps its callsign](tickets/05-awacs-keeps-its-callsign.md) |
| 06 | [A zone's infantry grouped near its centre](tickets/06-infantry-grouped.md) |
