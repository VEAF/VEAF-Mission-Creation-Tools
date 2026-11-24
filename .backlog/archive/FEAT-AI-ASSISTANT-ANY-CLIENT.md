# FEAT-AI-ASSISTANT-ANY-CLIENT — using VMCT with Claude, Gemini or another AI

Status: ✅ done — shipped in #1110 · archived 2026-11-24

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

- [01 — Serve the authoring guide over MCP](FEAT-AI-ASSISTANT-ANY-CLIENT.md)
- [02 — Install page: any AI](FEAT-AI-ASSISTANT-ANY-CLIENT.md)
- [03 — Tutorial box](FEAT-AI-ASSISTANT-ANY-CLIENT.md)

## Tickets, in full

## 01 — Serve the authoring guide over MCP

Status: ✅ done

Type: feature

`describe_authoring_guide` returns the plugin's `SKILL.md` verbatim; `_veaf_tools_extra_data` bundles it under `veaf_mission_mcp/data`; the server's `instructions` ask the client to read it first unless the skill is loaded.

## 02 — Install page: any AI

Status: ✅ done

Type: docs

`AI_ASSISTANT_INSTALL` opens on a table of the four cases (Claude Code, Gemini CLI, another MCP client, a chat AI without MCP) and gains a section for each of the last two: installing `veaf-tools` in a fixed folder, the `mcpServers` block with its doubled backslashes, Claude Desktop's config file, the opening request for the guide, and what a chat AI can still do.

## 03 — Tutorial box

Status: ✅ done

Type: docs

A box under the tutorial's introduction: an AI can walk the path for you, the tutorial still explains what it does, and the install page says how to wire it.
