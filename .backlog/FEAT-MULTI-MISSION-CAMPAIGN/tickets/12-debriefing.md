# 12 — The debriefing written by `campaign apply`

Status: ✅ done

David, 2026-10-06, on trying the loop: is there a debriefing, as there is a briefing? Answer "a+b".

- **a**: `campaign apply` writes `missions/mission-NN/debriefing.fr.txt` and `.en.txt`: ground changing hands, each side's losses zone by zone and type by type (the players' side first), scenery destroyed, what the turn did, the objectives.
- **b**: the MCP action `campaign_apply` returns it, and its description asks Claude to tell it as the story of the evening, keeping to its facts.

The `losses` change now carries the side charged and the unit types: the same garrison loses the units alive before and dead after; a garrison gone or replaced (the zone changed hands) lost every unit it started with; a garrison drawn in flight lost its dead units.

## Done when

Tests cover the losses of each case, the debriefing in both languages, a quiet mission, the players' side first, the files written by `apply` and returned by the MCP action.
