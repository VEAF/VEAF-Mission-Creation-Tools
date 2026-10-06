# 05 — Claude writes the brief, and rewrites it after each mission

Status: ⬜ ready

The prose file of ticket 03 is Claude's to write: when the campaign starts, from the scenario agreed with the mission maker; after each mission, from the debriefing (`campaign_apply` returns it) and the new strategic situation.

What the instructions given to Claude must say — each line is a correction David made on the prototype:

- Write a **military situation brief**: political, economic and military situation; mission and intent; objectives political, military and economic; concept of operations by phase; rules of engagement.
- **No game mechanics in the narrative.** Garrisons drawn from a reserve, a capture clock, a circle to hold: those belong to the annex the tools generate. Say what a staff officer would say.
- **The enemy stays mysterious**: intelligence of uneven quality, never a figure, except a fixed site once confirmed (ticket 02).
- **Plausible, not real-world claims**: the scenario is fiction set on real ground; places come from `geocode` / `list_airfields`, never from memory.
- After a mission: rewrite the mission page and the concept's progress from the debriefing; keep the rest, unless the situation changed it.
- The **DCS briefing** of the mission: add to the factual block `campaign next` writes there, never replace it.

Where they go — the MCP actions' descriptions, a campaign prompt in `.prompts/` like the objective-mission one, or the `veaf-mission-authoring` skill — is decided in the ticket.

## Done when

The instructions are written where Claude reads them, in FR and EN if a prompt; a campaign started from them produces a prose file `campaign validate` accepts, and a second mission rewrites only what changed.
