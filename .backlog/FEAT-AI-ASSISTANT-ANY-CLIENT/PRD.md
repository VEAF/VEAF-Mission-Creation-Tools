# FEAT-AI-ASSISTANT-ANY-CLIENT — using VMCT with Claude, Gemini or another AI

Status: ✅ done — shipped in #1110

Origin: David, 2026-10-09 — "a section in the docs, in the tutorial for instance, on what to do if I have Claude or another AI and want to use VMCT".

## What was missing

| Gap | Before | After |
|---|---|---|
| The tutorial never mentions the assistant before its last table | a reader with an AI walks the whole manual path first | a box under the introduction points to the install page |
| Only Claude Code and Gemini CLI are covered | another AI had no instructions at all | a table of the four cases, a section for another MCP client, one for a chat AI without MCP |
| A client without the plugin gets the tools, not the skill | `veaf-tools mcp` sent no instructions; the naming conventions only reached Claude Code and Gemini CLI | the `describe_authoring_guide` action serves the skill, and the server's MCP instructions ask the client to read it first |

## Decisions

- The skill exists once, `plugin/skills/veaf-mission-authoring/SKILL.md`. The build bundles it into the exe; the action reads that copy, or the repository's file in development.
- The server instructions point at the guide instead of carrying it: Claude Code puts a server's instructions in every session's prompt, where the plugin's skill already is, so 21 KB there would be paid twice on every session.
- Not every client honours server instructions, so the install page has the user open the conversation with the explicit request.

## Tickets

- [01 — Serve the authoring guide over MCP](tickets/01-serve-authoring-guide.md)
- [02 — Install page: any AI](tickets/02-install-page-any-ai.md)
- [03 — Tutorial box](tickets/03-tutorial-box.md)
