# 05 — No automatic BULLSEYE on a flight plan without waypoints

Status: ✅ done
Type: fix (or doc — decide in the plan)
Files: `src/python/veaf-tools/waypoints_injector/waypoints_injector_worker.py`, GUIDE, tests

## What happens

`if flight_plan and flight_plan.waypoints:` — a plan that is found but declares no waypoint falls
into the `else` branch: no BULLSEYE, and it is counted and logged as « sans plan de vol », which is
false.

A plan with `waypoints: {}` is the natural way to ask for "just the bullseye" — the shipped Caucasus
v6 has exactly that, and so did GermanyCW-v6 until the workaround. GUIDE #automatic-bullseye:
« chaque plan de vol reçoit en plus un waypoint BULLSEYE ».

## Measured

GermanyCW-v6 with two empty blue plans: 0 of 64 blue templates injected, « 128 groupes sans plan ».
With a declared BULLSEYE waypoint: 64 injected, 64 without a plan (the red templates, correctly).

## Options

a. inject the bullseye on an empty plan — reco: it is what the file and the GUIDE say
b. keep the rule, fix the log (« plan sans waypoint ») and the GUIDE

**Decided 2026-09-24 (David): option a.** A plan found with no waypoint still gets the BULLSEYE; the
log tells "no flight plan" apart from "plan without waypoints". Tests cover the three cases: no
plan, empty plan, plan with waypoints.

## Done when

- The chosen behaviour is tested, and the log count names the real reason

## Outcome (PR 1)

- Option a. Bench with `waypoints: {}` plans (the workaround removed): 64 BULLSEYE waypoints added.
