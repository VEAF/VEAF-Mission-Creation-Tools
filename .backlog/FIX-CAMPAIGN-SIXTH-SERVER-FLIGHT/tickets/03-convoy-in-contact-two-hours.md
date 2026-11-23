# 03 — A convoy does not sit two hours "in contact"

Status: ⬜ ready
Type: fix

## Read

On 2026-11-22 evening, after #1326 and #1328 were deployed, the red convoy `Aleppo - Menagh assault` stayed 1.1 to 4.3 km from Menagh from 95 to 125 min, `convoy Mule: the order given to Aleppo - Menagh assault 25 s ago moved nothing` every 27 s in bursts, then `to retire (not arrived after 125 min) stays: in contact` (`veafCampaign.lua` around line 2435). FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT meant a convoy whose pushes move nothing to drive on after `FUTILE_PUSHES` (3, `veafGroundAI.lua` line 861) and one that does not arrive to be retired on time.

**Checked (2026-11-23), at David's question: the convoy routing changes were already running that evening.** The log line `convoy Mule: the order given to … 25 s ago moved nothing`, printed that evening, exists only since commit 8aa7c4de (#1328, "check 25 s after an order that the convoy moved"); #1326 (108295a2) and #1331 (dce774e6) are older still, and the mission deployed on 2026-11-22 at 10:43 UTC was built after #1331's merge. So this is not fixed by them; nothing about convoys has changed since.

## To do

- First, read the whole log of that convoy (the Campagne server's `dcs.log`, 2026-11-22 19:30 to 21:45 UTC: `Aleppo - Menagh assault`, `convoy Mule`, `followConvoyProgress`, `recordFailure`) and say which rule kept it: what "in contact" was based on at 21:41, and why the futile-push count did not end it (it did move, 0.4 to 2.5 km per 5 min, back and forth).
- Then fix that cause, with a failing test first. The aim stays the one of FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT: a convoy that does not take the zone either drives in or is retired on time; moving back and forth in front of it is not contact.
- Docs: CHANGELOG entry.

## Done when

The cause is written in this ticket, and a convoy like this one is retired on time; with tests.

## Flight check

On the Campagne server: no convoy logged "stays: in contact" past its time while it shuttles in front of a zone.
