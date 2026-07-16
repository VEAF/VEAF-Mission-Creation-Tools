# FEAT-MCP-MISSION-EDITOR-017 — `veaf-mission-authoring` Claude skill (the "how to reason")

Status: ✅ done
Type: docs
Files: `plugin/skills/veaf-mission-authoring/SKILL.md`, `plugin/README.md`, `doc/developer/`

## What to build

The prose half of the wave-5 "brain": a Claude skill teaching the LLM **how to reason** when
authoring a VEAF mission — the judgement the structured oracle actions (ticket 016) can't encode:

- Naming rules in practice, and when to reach for `#command`/aliases vs literal units.
- Combat-zone group model (geometry-based, coalition-agnostic, placed active) **vs** QRA group
  model (referenced by exact name, coalition-significant, **Late Activation**).
- When to ask the user vs decide autonomously (the user gives intent, not names).
- Always call the oracle actions (016) as the source of truth for unit types / conventions /
  module schemas — the skill points at them rather than restating volatile data.

## Acceptance criteria

- [x] Skill loads and references the ticket-016 actions as the authoritative data source.
- [x] Covers the combat-zone-vs-QRA distinction and the "intent not names" principle with
      worked examples ("create a CZ with two armor groups", "a QRA with Mirage 2000s").
- [x] No duplication of the volatile DCS/VEAF lists (those stay in the oracle actions).

## Note

Delivery vehicle is the **Claude plugin** (MCP server = hands/eyes + this skill = brain). Placement
decided (David): the skill is **versioned in veaf-tools** under `plugin/skills/`, next to the MCP
server, and bundled/referenced by the separate `bfr-claude-plugins` packaging (out of scope here).

## Blocked by

FEAT-MCP-MISSION-EDITOR-016 (the skill points at the oracle actions).
