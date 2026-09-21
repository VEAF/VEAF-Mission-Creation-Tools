# 04 — The view draws one shape set per group

Status: ⬜ ready

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

- [ ] One shape set per group.
- [ ] The colour rule preserved, its existing assertions re-expressed in groups.
- [ ] The truncation warning proved still reachable.
- [ ] `poetry run test-lua` green, `stylua` clean.
