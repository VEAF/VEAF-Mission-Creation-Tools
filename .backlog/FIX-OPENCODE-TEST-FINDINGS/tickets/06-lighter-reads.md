# 06 — Lighter reads

Status: ⬜ ready

The reads that weigh most in the export (PRD, finding 6) stay in the AI's context to the end, and are sent back on every one of its turns.

- `describe_known_limitations` with an `area` returns full entries: 46k characters for three areas. Give it the short form by default, and the full text by id.
- `list_airfields` returns 37k for Syria: return name, id, coalition and position by default, the rest on request.
- `describe_action`: the guide tells the AI to describe an action just before using it, not in batches up front.
- `describe_mission_prompt` (36–44k): measure which parts an AI needs at which step; split only if a part is clearly needed late.

Done when: each change has a test asserting the size it stays under on a real theatre or the shipped data.
