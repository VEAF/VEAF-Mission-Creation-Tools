# 01 — A group's profile, and its median point

Status: ⬜ ready

The two new primitives the rest of the lot is built on, delivered **without changing a single
caller**, so this ticket lands green on its own and the behaviour change happens in ticket 02.

## What to build

### `veafSkynet.spotterGroupMedianPoint(dcsGroup)`

The median of the group's **live** units — `veaf.isUnitAlive`, which tests `isExist()` *and*
`isActive()`, because a late-activated unit answers `isExist()` true and would drag the median to a
place nothing is standing (`docs/agents/dcs-runtime-traps.md`).

Returns a runtime vec3, or nil when the group has no live unit left. **Runtime convention**: `x`
northing, `y` **altitude**, `z` easting — read `docs/agents/dcs-coordinates.md` before touching this.

Median, not centroid, and say which in the code: David asked for a *point médian*. Take the
component-wise median of the live units' positions, which is what a human means by "where the convoy
is" and, unlike a mean, does not get dragged by one straggler. With an even count, the lower of the
two middles — an arbitrary but stated tie-break, so the value is reproducible.

### `getSpotterProfile` accepts a group

- **Sight range: the range of the unit that sees furthest.** David's call, 2026-09-21.
  `matchSpotterUnitRow` stays per unit — it is a type lookup, and it is what this is computed from.
- **Speed class: the fastest of its units**, since the class only decides how often the node's edges
  are recomputed.
- A group whose every unit is blind gets range 0 and is not a spotter, exactly as a blind unit is not
  one today. Half the obvious air-defence vehicles are blind (`SAM elements`, range 0, wins over
  `MANPADS` in the table walk) — so a group mixing an `SA-18 Igla-S manpad` with a `ZSU-23-4 Shilka`
  must come out at **10 000 m**, not 0.

Keep the unit-taking form working for now, or give the group form its own name; ticket 02 is what
moves the callers.

## Tests

- The median of three units in a line is the middle one; of four, the stated tie-break.
- One straggler 10 km from a parked convoy does not move the median to the middle of nowhere — the
  test that says median rather than mean.
- A group with one dead unit medians over the survivors; with none alive, nil.
- A late-activated unit is excluded from the median.
- Mixed group (Igla 10 km + Shilka 0) → 10 000 m. **Both directions**: an all-Shilka group → 0.
- Speed class of a mixed group is the fastest.

## Definition of done

- [ ] Both primitives, with docstrings naming the coordinate convention.
- [ ] The tests above, each able to fail.
- [ ] No caller changed, `poetry run test-lua` green, `stylua` clean.
