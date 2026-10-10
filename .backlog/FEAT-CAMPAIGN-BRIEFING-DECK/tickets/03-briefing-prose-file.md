# 03 — The prose, in a file of the campaign folder

Status: ✅ done

The written half of the brief lives in a file of the campaign folder (for instance `briefing.yaml`), next to `campaign.yaml`, so it survives from one mission to the next and the deck can be regenerated at will.

Its sections follow the pages of the PRD: operation name and subtitle; political situation; economic situation; enemy's most probable course of action; mission statement; intent (purpose, main effect, method, end state); objectives (political, military, economic); concept of operations (one phase per mission, points of attention); rules of engagement (targeting, civilians and infrastructure, self-defence); the coming mission's title and tasks.

- `campaign validate` checks it: known sections, one phase per mission at most, the mission page present for the coming mission.
- Each zone may carry a **display name** in `campaign.yaml` ("Dépôt de Khobi"), used by the deck and the map; the campaign name stays the key.
- A missing file is not an error: the deck is then the generated half only, and says the prose is to be written.

## Done when

Tests parse a complete file and report each defect by section; the display name reaches the deck and the map.
