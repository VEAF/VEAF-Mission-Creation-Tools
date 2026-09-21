# 04 — The view draws one shape set per group

Status: ✅ done

What David was looking at when he found the defect: a mat of grey strokes with the demonstration
underneath it.

## What to change

`spotterViewScope` and `paintSpotterView` walk groups. One circle, one square and one set of links per
group, anchored on the median.

The colour rule David settled on 2026-09-21 is unchanged by this lot and must survive it:

| shape | grey | blue | orange | red |
|---|---|---|---|---|
| square | has not been told | was told | — | element of a live battery |
| circle | spotter, nothing seen | — | spotter with a contact in sight | live battery's envelope |

A dark battery draws **no** envelope. Plus a red cross on each held contact, a grey dashed line for a
link, and a solid red line for one that carried an alert.

Two consequences of drawing per group, both of which simplify the code:

- A battery's **square** and its **envelope** now come from the same node, so the `liveSiteUnits` set
  that maps a site's unit names onto "red square" collapses into a plain "is this node a live site".
- The `SpotterViewMaxShapes` truncation warning should stop firing on the walkthrough mission. Check
  it still fires when it should: a warning that can no longer happen is a warning nobody will trust.

## Tests

- An 11-unit group draws **one** circle and **one** square, not eleven.
- Every cell of the colour table above, as the existing view suite already asserts them.
- The truncation warning still fires on a graph built to exceed the budget.

## Definition of done

- [x] One shape set per group: an 11-vehicle convoy draws **one** circle and **one** square.
- [x] The colour rule preserved, its assertions re-expressed in groups.
- [x] The truncation warning proved still reachable —
      `test_the_shape_budget_stops_the_drawing_and_says_so` still passes.
- [x] `poetry run test-lua` green, `stylua` clean.

The `liveSiteUnits` set that maps a site's unit names onto "red square" did **not** collapse away as
this ticket predicted. It is still built from the site's units, because that is what makes the
lookup answer for a node; the envelope loop now reuses it instead of walking the IADS a second time.

`_spotterPoint` split in two, which is the rename that stops the confusion recurring:
`_contactPoint(unitName)` for an aircraft, and the group median for a node.
