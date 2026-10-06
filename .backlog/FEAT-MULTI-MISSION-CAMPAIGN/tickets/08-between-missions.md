# 08 — Between missions: merge the state file, the enemy's turn, victory

Status: ✅ done

## Merge

`veaf-tools campaign apply <campaign folder> <state file>`: validates the state file against the campaign (version, zone list, mission number), merges it into the campaign state, and keeps the before/after pair in the mission's sub-folder.
Applying the same file twice is refused; a state file from another campaign is refused.

## The enemy's turn (fixed rules, deterministic)

David, 2026-10-06: the bookkeeping is done by fixed rules, the intent by Claude.
The rules, applied to both sides after the merge:

- logistics zones feed their side's reserve (ticket 06);
- a damaged garrison is repaired from the reserve, a limited number of groups per mission;
- a neutral zone next to an owned zone is retaken by its neighbour if the other side has nothing there (the counter-attack that happens between missions);
- the numbers are settings in `campaign.yaml` with shipped defaults.

Claude's part — where the enemy puts its effort, what it reinforces, what the next mission asks of the players — is not in the tools: it is decided when building the next mission (ticket 09) and written in its briefing.

## Victory

The campaign's objectives (ticket 01) are evaluated after each merge; met → won, announced in the next briefing; mission count reached without them → the campaign says so, and David decides whether to extend it.

## Done when

Worker/manager/models, typed, tested first: merge, double apply refused, foreign file refused, each rule, objectives met and not met; `pyproject` ratchets respected.
