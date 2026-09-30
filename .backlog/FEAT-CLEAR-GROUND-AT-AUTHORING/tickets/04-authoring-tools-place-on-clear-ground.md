# 04 — the authoring tools place on clear ground, and say when they cannot

Status: ✅ done — 2026-09-28, verified in game; see the PRD, *What was built*
Type: feat

## What this builds

The rule this whole lot exists for, finally applied: **when the tools choose a position, they choose
a clear one.** The MCP actions that create ground groups consult the catalogue and place the group
where its worst-case footprint fits.

**And a position the mission maker drew stays where they drew it.** Unchanged since David's
arbitration of 2026-08-27, and this ticket must not weaken it. The test is *who chose the position*,
never whether the position is good.

## Out of coverage: place anyway, and say so (decision 4)

When nothing large enough is found — or the catalogue does not cover the area — the group goes where
it was asked to go, and the tool reports it plainly:

> no clear position for 15 vehicles within 1 km, placed as requested

That is ADR 0018: an undocumented dependency may improve quality, it must never be what refuses a
placement. A refusal turns a quality problem into a broken tool.

## Definition of done

- [x] A test: a group the tools place lands on a catalogued clear position — written **with** the
      code, not before it; it fails against the code without the placement
- [x] A position the mission maker declared is **never** moved — the existing arbitration tests stay
      green
- [x] Out of coverage and nothing-found both place as requested and report it in terms a mission
      maker can act on, naming the size asked for and the radius searched
- [x] Verified on a real authoring run: a mission built through `add_group` — the MCP action's own
      function, called directly rather than over the MCP transport — holds no group standing in a
      wood the catalogue could have avoided (8 of 8 clear in DCS, 2026-09-28)
- [x] Python tests green, and the docs updated wherever the behaviour is visible to a mission maker
