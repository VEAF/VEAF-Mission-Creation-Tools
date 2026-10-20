# 06 — Lighter reads

Status: ✅ done

The reads that weigh most in the export (PRD, finding 6) stay in the AI's context to the end, and are sent back on every one of its turns.

- `describe_known_limitations` with an `area` returns full entries: 46k characters for three areas. Give it the short form by default, and the full text by id.
- `list_airfields` returns 37k for Syria: return name, id, coalition and position by default, the rest on request.
- `describe_action`: the guide tells the AI to describe an action just before using it, not in batches up front.
- `describe_mission_prompt` (36–44k): measure which parts an AI needs at which step; split only if a part is clearly needed late.

Done when: each change has a test asserting the size it stays under on a real theatre or the shipped data.

## Done (2026-10-20)

- `describe_known_limitations`: `area`, `kind`, `theatre` keep the listing short; the full text by `id`/`ids` or `full`. The three largest areas read short stay under 8 000 characters (test).
- `list_airfields`: name, id, whole-metre x/y (and coalition with a mission) by default; Syria 36 732 → 20 605 characters (test: under 22 000).
- `describe_action`: the guide says to describe an action just before using it, not in batches.
- `describe_mission_prompt`, measured: in the export the AI loaded **both** prompts before asking the kind (36k + 44k). The objective prompt's sections 4–9 (21k of 34k) serve only after approval: it now comes in two parts, `scenario` by default (about 13k, test under 15k) and `build`. The open-training prompt designs from its section 4 on: not split. The action says to load one prompt, the kind chosen.
