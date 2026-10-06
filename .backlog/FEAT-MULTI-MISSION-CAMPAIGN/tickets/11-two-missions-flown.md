# 11 — Two missions flown end to end

Status: ⬜ ready

The acceptance of the lot is the loop itself, in game:

1. `campaign init` on the example campaign, mission 1 built by Claude, flown (solo is enough): destroy part of a garrison, a bridge and a logistics zone, capture a neutral zone with CTLD troops, make a SAM site fire.
2. The state file fetched and applied; the enemy's turn run.
3. Mission 2 built: the zone is ours, its airbase gives our slots, the bridge is down, the SAM site has its losses and its missile stock, the enemy's reserve is lower, the strategic briefing tells it.
4. Mission 2 flown long enough to see it, then the server killed mid-flight: the state file holds the last interval.

Each point read in game and recorded in the PRD with its date; what fails reopens its ticket.
