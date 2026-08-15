# 01 — Write the DCS coordinate convention down

Status: ✅ done
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

- [x] Write the two shapes and, crucially, **why the confusion is invisible** — no error, just a wrong
      position. A convention with no consequence attached gets skimmed.
- [x] Say where the conversion happens in this codebase, so a reader knows what already handles it:
      `veaf.placePointOnLand` normalises a vec2 into a vec3 by moving `y` to `z`, and
      `resolve_coordinates` covers the MCP path. Name them rather than restating the rule abstractly.
- [x] One home only. `docs/agents/` is the natural place given the audience is agents, with a pointer
      from `CLAUDE.md` if that reads better — but not the same paragraph maintained twice, which is how
      two documents come to disagree.

## Acceptance criteria

- [x] A reader who has never touched DCS can tell which shape they are holding.
- [x] `docs-check` clean if it lands under a checked path.
- [x] No duplicated statement of the rule in two files.

## Delivered — 2026-08-11

[`docs/agents/dcs-coordinates.md`](../../../docs/agents/dcs-coordinates.md), pointed at from `CLAUDE.md`
twice — once in the `Agent skills` index, once in the Lua routing rules where an agent about to write
Lua actually passes. The rule itself is stated in one place; the two entries are links, not copies.

The page names what already handles it, as the ticket asked: `veaf.placePointOnLand` (accepts either
shape, returns a vec3 at ground height), `veaf.getLandHeight` (does the vec3 → vec2 narrowing so callers
never build a `land.*` argument), `resolve_coordinates` for the MCP path, and
`veaf_libs.coordinates.xy_to_latlon` whose docstring already said "northing-like".

**One thing the ticket did not know**, found while verifying rather than restating: the runtime is not
internally consistent either. `land.getHeight` takes a **vec2** whose `y` is the easting — the
mission-table meaning — while the vec3 it is derived from uses `y` for altitude, three lines apart in
`veaf.getLandHeight` (`veaf.lua:947`). So "in game it is always a vec3" is false, and the page says to
reason from the called function's signature rather than from which side of the fence you are on.

Documentation only — no CHANGELOG entry, and `docs/` is outside `docs_dir: doc`, so no translation or
nav entry is required. `docs-check` clean.
