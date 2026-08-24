# FIX-WAYPOINTS-PLAN-PRIORITY — the flight-plan matching has no priority, and said it did

Status: ✅ done

Found on 2026-08-24 while scoping [`FEAT-WAYPOINT-BULLSEYE`](../FEAT-WAYPOINT-BULLSEYE/PRD.md).

## What the code does

`WaypointsManager.get_flight_plan_for` returns the **first** flight plan whose stated criteria all
match, treating the criteria a plan omits as wildcards. Declaration order decides; specificity does not
enter into it.

Its own docstring claimed otherwise — *"Tries to find a plan matching: aircraft_type > category >
coalition > all"* — and so did the shipped template's usage notes. Both are corrected as part of
`FIX-DEFAULT-WAYPOINTS-BOGUS-BULLSEYE`, so what is left here is the behaviour question, not the
description.

## Why it is not merely cosmetic

The shipped default template demonstrated the consequence and nobody noticed:

```yaml
settings:
  all_blue_planes:      # category: plane, coalition: blue
  f16_flight_plan:      # category: plane, coalition: blue, type: F-16C_50
```

A blue F-16C matches both, `all_blue_planes` is declared first, so `f16_flight_plan` is **dead
configuration** — shipped as an illustration of a feature that does not work. Any mission maker who
copies that shape to give one airframe its own plan gets the broad plan instead, silently.

## The decision this lot exists to take

Two defensible answers, and the choice is a product one rather than a technical one:

1. **Implement the priority the docstring promised.** Score each candidate plan by how many criteria it
   states, and take the most specific. Matches what a reader expects and makes `f16_flight_plan` work
   without anyone reordering anything. Changes the behaviour of every existing `waypoints.yaml` whose
   plans overlap — which is the risk, and it is not measurable from here: mission folders live outside
   this repository.
2. **Keep first-match-wins and make it loud.** Warn at build time when a plan can never be reached
   because an earlier one subsumes it. No behaviour change, and the mission maker learns about the
   ordering rule from a message rather than from a flight plan that is missing a waypoint.

Option 2 is the safe one and answers the actual complaint (silence). Option 1 is what the documentation
promised for years. Worth asking David rather than picking.

## Decided and delivered — 2026-08-24

**Option 1**: the priority the docstring promised is implemented. David's call, against a recommendation
of option 2 — recorded because the reasoning for 2 still holds and will matter if this ever bites: the
complaint was the *silence*, not the rule, and this changes behaviour for missions whose files nobody
here can see.

What makes option 1 defensible: the priority is what **both** descriptions promised for years, so a
mission maker who read either one already expects it. And a mission maker who had worked around the real
behaviour by ordering plans narrow-first sees nothing change — narrow-first is what specificity produces.

### How it works

`FlightPlanDefinition` gained `matches()` and a `specificity` property; `get_flight_plan_for` collects
every candidate and takes the highest specificity. Specificity is the count of criteria a plan states,
out of `aircraft_type`, `coalition`, `category`, `country`, listed once as `CRITERIA` so the matcher and
the score cannot drift apart.

`max()` keeps the first of equal maxima, so **declaration order still breaks a tie** — deliberately kept,
because the alternative is an outcome that depends on dictionary iteration and makes the same file build
differently for no visible reason.

All four criteria count equally. A plan naming a country is not a second-class citizen, and a test says
so, because "the ones that felt important" is exactly how a scoring rule acquires an undocumented
exception.

### Measured, not asserted

Asked the real matcher about the real shipped template, before and after:

| The aircraft | Before | After |
|---|---|---|
| blue F-16C_50 | `all_blue_planes` | **`f16_flight_plan`** |
| blue F/A-18C | `all_blue_planes` | `all_blue_planes` |
| red Mi-8 | `all_red_helicopters` | `all_red_helicopters` |
| neutral plane | `default_plan` | `default_plan` |

So one case changed, and it is the one that was broken. Sweeping every coalition × category with the
F-16C type before the change reached `f16_flight_plan` **never**; after, exactly `blue/plane`.

### Tests

13, in two classes. The first pins the rule on constructed plans — the same overlap asserted **twice, in
both declaration orders**, because "the answer no longer depends on the order" is the actual claim; plus
the catch-all losing to everything and still being used when nothing else matches, the tie, a plan
stating a *different* value never winning on specificity, and the score itself.

The second asks the matcher about the **shipped template**, including a sweep asserting no plan in it is
unreachable. A unit test on invented plans would not have caught `f16_flight_plan` being dead
configuration — it took asking the real matcher about the real file, which is how this was found at all.

Two mutations: returning the first candidate instead of the most specific fails the suite, and dropping
`country` from `CRITERIA` fails it too. Both verified on the **exit code** — `pytest -q` here prints no
"N failed" line, so grepping for one reports an empty result that reads like a pass.

### Descriptions, for the third time in one day

`#801` had just rewritten the template's usage notes and the docstring to describe first-compatible-wins,
because that was the truth. They now describe the priority. Worth stating plainly: the churn is the point
— each version said what the code did at the time, which is the property that was missing for years.

Documented for mission makers in `GUIDE.md` / `.en.md` under `{#flight-plan-matching}`, with the worked
example, the tie rule, and an explicit note on who is affected by the change and who is not. The folder
tree's description of `waypoints.yaml` as the bullseye's home was corrected too — stale since 6.15.41.

## Definition of done

- [x] The choice above taken and recorded here, with its reasoning — option 1, David's call
- [x] Whichever it is, a mission whose plans overlap gets a defined and documented outcome — most
      specific wins, declaration order breaks a tie only
- [x] `f16_flight_plan` in the shipped template either works or is removed — it **works**, and a test
      asserts no plan in the template is unreachable
- [x] Unit tests for the overlap case, both orders of declaration
- [x] Documented, both languages
