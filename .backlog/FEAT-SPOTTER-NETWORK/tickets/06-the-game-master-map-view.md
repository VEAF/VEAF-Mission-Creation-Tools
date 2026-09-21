# 06 — The game master map view

Status: ⬜ ready

**Separate on purpose, by David's decision: it can slip without holding the mechanism.** Tickets 01
to 05 ship a working feature without it. If the lot has to be cut short, this is the piece that goes.

Show the network on the F10 map for a game master: the spotters, the radio links, the live alerts
and the sites currently holding one. The status page of ticket 05 answers "why did this happen" in
the log after the fact; this answers "what is happening" while it happens.

## The coalescing guard is the whole difficulty

This is where redrawing genuinely comes in bursts. Every alert, every cancellation and every graph
pass is a reason to redraw, and a combat zone spawning changes hundreds of markers at once. Without
coalescing, ticket 02's "a spawn triggers nothing" property is undone here.

The pattern is `veafRadio.refreshRadioMenu`'s (`veafRadio.lua:613`):

```lua
if not veafSkynet.spotterRedrawScheduled then
  veafSkynet.spotterRedrawScheduled =
    veaf.scheduleFunction(veafSkynet._redrawSpotterView, {}, timer.getTime() + 1)
end
```

with `_redrawSpotterView` clearing the flag **as its first act**. A hundred calls in a row then
produce one redraw.

### Read the original before copying it

`veafRadio._refreshRadioMenu` does **not** clear its flag first — it clears it inside
`if not veafRadio.dontCreateMenus then` (`veafRadio.lua:630-632`). When menus are disabled the flag
stays set forever and the guard never re-arms. It is harmless there, because with menus off there is
nothing the guard was protecting. It would **not** be harmless here: any early return in
`_redrawSpotterView` — no game master connected, nothing to draw, the feature switched off — would
leave the flag latched and kill every later redraw for the rest of the mission.

So: clear the flag first, unconditionally, before any test that can return early. **A coalescing
guard that never re-arms is worse than none**, because the first redraw makes it look as though it
works.

## Scope

**Checked while implementing, 2026-09-21, and it changes what this ticket can deliver.** DCS offers
`markToAll`, `markToCoalition` and `markToGroup` — nothing narrower — and a game master has **no
group**, which is also why no `USAGE_ForGroup` radio command reaches one. There is therefore **no way
to draw for a game master alone.**

So the view is a **coalition** view, and every pilot of that coalition sees it too. On a red network
that hands red pilots a live tracker of blue aircraft: a real balance change, not a debug aid.
Shipped off, and the documentation says so in as many words.

**Settled with David, 2026-09-21.** The view is kept, and it gets its own `mission.yaml` setting,
`spotter_view`, with three values:

| Value | Effect |
|---|---|
| `"off"` | nothing is drawn (default) |
| `"on"` | drawn from the start of the mission |
| `"radio"` | a *Show / Hide the spotter view* switch in the F10 menu, per coalition; the view starts **off** |

Two things the `radio` mode has to get right, and both are asserted:

- **The submenu is scoped to its coalition**, so red pilots never see the blue network's switch.
- **The toggle carries no group restriction.** A game master has no group, so a `USAGE_ForGroup`
  command never reaches one (#128) — and a game master is exactly who this menu is for. Leaving the
  usage unset means `USAGE_ForAll`, which is the one that works.

**And the YAML trap**: `mission.yaml` is read with `yaml.safe_load`, which is YAML 1.1, so a bare
`on` arrives as `True` and a bare `off` as `False` — measured, not assumed. Both are accepted and
mapped to the mode they plainly mean, because refusing them would refuse the spelling anyone writes
first; the documentation quotes them anyway, since `"on"` survives a move to YAML 1.2 and a bare `on`
would then change meaning under the mission's feet.

- Toggleable. Nobody wants several hundred markers on permanently.
- Marked **only where the alert was raised**, not at every unit holding it: every unit of the pocket
  holds the same contact, and a marker on each is a wall of markers all saying one thing.
- Drawing goes through the helpers already in `veaf.lua` / `veafGeo.lua`
  (`trigger.action.markToCoalition`, `circleToAll`, `lineToAll`, `removeMark`) rather than fresh
  calls into `trigger.action`.

## Tests

- **A hundred redraw requests in a row schedule exactly one redraw.**
- **The flag is cleared, so a later request still works** — this is the assertion that catches the
  `veafRadio` shape above, and a test that only counts the first burst will pass on the broken
  version.
- The flag is cleared even when the redraw returns early with nothing to draw.
- Markers created on a previous pass are removed, not stacked: draw twice and assert the count does
  not double.
- Toggling the view off removes what it drew.

## Definition of done

- The map view written, behind its toggle, with a coalescing guard that re-arms.
- The tests above.
- Documentation in `doc/mission-maker/scripts/veafSkynetIadsHelper.md` and `.en.md`, both languages,
  saying who sees it and how to turn it on.
- `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean, `poetry run
  docs-check` after touching `doc/`, Lua coverage floor bumped.
- `CHANGELOG.md` updated under `[Unreleased]`, appended at the end of the section.
