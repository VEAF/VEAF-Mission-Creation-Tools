# 04 — Assault convoys: the campaign attacks and counter-attacks in flight

Status: ✅ done on the mocks — `veafCampaign` (rule, menu, reserve, absorption, state), `campaign apply` (losses, return to reserve), the briefing; the column on a real road and its capture left to R46

David, 2026-10-08: "est-ce que des convois sont envoyés pour prendre d'assaut les zones à capturer ? ou est-ce que les joueurs doivent se débrouiller avec CTLD ?" — answer: no convoy, `veafCampaign.lua` holds no movement at all; a zone is taken only by ground presence the players bring (CTLD, a landed helicopter, a marker spawn), and the only automatic move is the counter-attack rule **between** missions. "oui, ajoute-le au lot".

During the flight, the campaign sends assault convoys along the roads between connected zones:

- **Red counter-attacks**: from a red zone towards a neighbouring neutral or blue zone, when the rules say so (a zone just lost, a neutral zone bordered by red); a convoy that reaches a neutral zone and holds it captures it, as any ground unit does.
- **Blue assaults**, optional: from a blue zone towards a neutral or red one, on the players' call (radio menu) or by rule — the players escort them rather than carrying every soldier by helicopter.
- **Paid from the reserve**: a convoy is the side's ground units, drawn from its reserve like a garrison, and its losses are campaign losses (state file, debriefing). Ground units stay the campaign's books ([PRD](../PRD.md), "Decided before writing"); what the opposition level of ticket 02 may change is how often red attacks, not what it costs.
- **Built on the convoy that exists**: `veafSpawn.spawnConvoy` with an itinerary along the connection, and the convoy behaviour of [`FEAT-CONVOY-UNDER-FIRE`](../../FEAT-CONVOY-UNDER-FIRE/PRD.md) (watching ahead, splitting, calling for help).
- **Said to the players**: a convoy leaving is reported (radio message, F10 map drawing of its axis) as intelligence would, and the mission briefing mentions an expected counter-attack without its strength.

## Done when

Lua tests: a red convoy leaves for a neutral neighbour when the rule says so, along the connection; its units come out of the reserve and its dead are recorded as losses; arriving, it captures a neutral zone; a blue assault from the menu. Python: the state file and the debriefing carry a convoy's losses. Checked in game on a test campaign before a squadron flies it (DCS-SESSION-TODO).
