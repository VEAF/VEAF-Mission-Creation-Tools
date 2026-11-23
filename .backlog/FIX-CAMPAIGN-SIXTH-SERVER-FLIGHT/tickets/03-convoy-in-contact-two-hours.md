# 03 — A convoy does not sit two hours "in contact"

Status: 🧑 waiting-human — the flight check
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

## Done (2026-11-23)

**The cause, read in the Campagne server's `dcs.log` (2026-11-22, 19:36 to 22:01 UTC).**
The convoy left Aleppo at 19:36 (`retired after 125 min`) and drove in normally to 1.3 km of Menagh at 95 min (21:11).
There it went round the same loop three times:

1. `engage`: `contact with 1 enemies` (21:02, 21:26, 21:40): the garrison seen.
2. The garrison out of sight, `pressOn` every quiet minute: `11 enemies still alive out of sight, closing in again`.
3. Each push `moved nothing` (the 25 s check), three in a row: `3 pushes moved nothing, driving on` (21:12, 21:36, 21:47). **The futile-push rule did work.**
4. `resume`: the armed group drove **back** to fetch its unarmed vehicles left behind (`turning back`, 1.3 → 4.3 km at 21:21), then on toward the zone apart (`the unarmed vehicles did not rejoin, driving on apart`, 21:22).
5. Back in front of the zone, the same garrison seen again **as a new contact**: `resume` empties `threats`, and the enemies pressed on in vain were never marked unreachable — `pressOn` handed `pushMovesSomething` an empty list, so only enemies *in sight* at a `closeIn` were given up on. Back to 1.

At 125 min (21:41:45) the timeout fired as planned; "in contact" was the `lastSighting` of the engage at 21:40:58, step 5 of the third round.
Then a player attacked it (`an assault under air attack drives on`, 21:48 to 21:51): real contact, then `a player near`, as designed.
It was retired at 22:01:35, 20 minutes late: not two hours in contact, but 50 minutes going round in front of the zone (95 to 145 min) without ever driving in.

**Fixed**: `pressOn` hands the enemies it pushed onto to `pushMovesSomething`, which marks them unreachable when the pushes moved nothing, as it already did for those in sight.
After the drive on, the garrison it could not reach no longer starts a fight by being seen (a shot from it still does), so the convoy drives on into the zone on its route's last leg, and its `lastSighting` is no longer renewed: it is retired on time unless it really fires or is fired at, or a player is near.

- Test: `test_an_enemy_pressed_on_in_vain_starts_no_new_fight_by_being_seen` (three press-ons out of sight moving nothing → drive on; back in sight, no fight and no new contact; a hit is a fight again), red before the fix.
- Not changed: the armed group fetching its trucks behind it after a drive on (step 4), the merge FEAT-CONVOY-UNDER-FIRE chose; step 5 was what turned it into a loop.
- Not measured: why DCS did not follow the assault's pushes into the zone at 1.3 km. That needs DCS.
