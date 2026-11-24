# FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT — a convoy that cannot close in is never retired

Status: ✅ done — merged in #1326 (2026-11-22), on `develop` with #1336 (2026-11-23), shipped in 6.39.0

Flight check: on the Campagne server, a convoy that cannot reach its enemy drives on after 3 pushes that move nothing instead of staying "in contact" (ticket 01's in-game check).

Found while watching "Bouclier de l'Oronte" on the Campagne server, 2026-11-21; David asked for the lot the same night.

## Measured (Campagne server, 2026-11-21, UTC)

- 20:22: red assault convoy [Aleppo - Menagh assault] (veafGroundAI name "Mule") leaves Aleppo, 51 km of road, retired after 125 min.
- 20:46: "convoy Mule: contact with 1 enemies"; then every minute "11 enemies still alive out of sight, closing in again" (`pressOn`).
- From 22:00 to the end of the evening: "1.3 km from [Menagh] … standing still (0.0 km in 5 min)", and every two minutes "no fire exchanged for 120 s, closing in on an enemy 956 m away" (`closeIn`), 956 then 957 m: the push never moved it.
- 22:28: "red convoy [Aleppo - Menagh assault] to [Menagh] to retire (not arrived after 125 min) stays: in contact".
- 2026-11-20: the same picture 12 km from Kilis ([Afrin - Kilis assault], standing still from 21:45, kept to the end; that evening the reason was "a player near").

## Cause (read in the code)

- `veafCampaign.convoyMayLeave` (`veafCampaign.lua` around line 2262) keeps a convoy while `max(lastContact, lastFireExchanged)` is younger than `retire_quiet_seconds`.
- `ConvoyUnitHandler:pressOn` sets `lastContact = now` (`veafGroundAI.lua` around line 1997) and `ConvoyUnitHandler:closeIn` sets `lastFireExchanged = now` (around line 2043) at every push, whether or not the convoy moves.
- A convoy that DCS cannot drive onto its enemy (terrain, a river, an enemy it cannot path to) therefore renews its own contact every one or two minutes and is never retired: it keeps a place of the convoy cap (FEAT-CAMPAIGN-CONVOYS-FOLLOW-STRIKERS) and stands still for the rest of the campaign.

## Decided

David, 2026-11-21: fix it.

The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [A push that moves nothing is not a contact](tickets/01-a-push-is-not-a-contact.md) |
