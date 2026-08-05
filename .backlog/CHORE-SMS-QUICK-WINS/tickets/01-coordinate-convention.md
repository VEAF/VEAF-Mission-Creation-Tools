# 01 — Write the DCS coordinate convention down

Status: ⬜ ready
Type: docs
Files: `CLAUDE.md` or `docs/agents/` (pick one, not both)

## The trap

DCS uses `x`, `y` and `z` to mean **different things in two places**:

| Where | Shape |
|---|---|
| The mission table (a `.miz`, what the tooling edits) | `{ x = north, y = east }` |
| The runtime scripting API (a vec3, what Lua sees) | `{ x = north, y = altitude, z = east }` |

Both abbreviate to "x/y/z". Get them confused and a group lands a hundred kilometres away, or at an
altitude of 400 000 metres, with no error anywhere.

`resolve_coordinates` hides this inside the MCP, which is why it has not bitten recently. **An agent
writing Lua walks straight into it** — and agents writing Lua is now a normal thing here.

Verified absent on 2026-08-05 from `CLAUDE.md`, `CONTEXT.md` and everything under `docs/agents/`.
dcs-sms puts it at the top of their `AGENTS.md`, with the reason. Cost: one paragraph.

## Tasks

- [ ] Write the two shapes and, crucially, **why the confusion is invisible** — no error, just a wrong
      position. A convention with no consequence attached gets skimmed.
- [ ] Say where the conversion happens in this codebase, so a reader knows what already handles it:
      `veaf.placePointOnLand` normalises a vec2 into a vec3 by moving `y` to `z`, and
      `resolve_coordinates` covers the MCP path. Name them rather than restating the rule abstractly.
- [ ] One home only. `docs/agents/` is the natural place given the audience is agents, with a pointer
      from `CLAUDE.md` if that reads better — but not the same paragraph maintained twice, which is how
      two documents come to disagree.

## Acceptance criteria

- [ ] A reader who has never touched DCS can tell which shape they are holding.
- [ ] `docs-check` clean if it lands under a checked path.
- [ ] No duplicated statement of the rule in two files.
