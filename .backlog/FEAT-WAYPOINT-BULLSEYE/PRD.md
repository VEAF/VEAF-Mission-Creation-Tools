# FEAT-WAYPOINT-BULLSEYE — inject the bullseye as a waypoint automatically

Status: ✅ done

Origin: [#175](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/175), 2023.

## The gap

The ask is small: a named point called `BULLSEYE` should be injected as a waypoint without the mission
maker listing it.

`BULLSEYE` appears in `waypoints_injector_README.py` — as an **example** of a named point in the
documentation — and nowhere in `waypoints_injector_worker.py`. So the injector will happily inject a
bullseye you declare, and does nothing on its own.

## Scope

Inject the theatre's bullseye per coalition, unless the mission already declares a waypoint of that
name. Two things to settle by reading rather than guessing:

- **Where the bullseye comes from.** A `.miz` carries `coalition.<side>.bullseye` in the mission
  table, so it need not be computed — but check which side's bullseye a given flight should get.
  `FIX-CASMISSION-BLUE-BULLSEYE` (issue #304, closed) was exactly a bug about using the wrong one.
- **Whether it should be on by default.** An extra waypoint in every flight plan is a visible change
  for every mission that rebuilds. Opt-in is the safe default; opt-out is what the issue implies.
  Decide and record it.

## The open questions, settled — 2026-08-24

### Where the bullseye comes from, and which side's

`mission.coalition.<blue|red|neutrals>.bullseye = { x = <northing>, y = <easting> }` — two components, in
**mission-table** coordinates, the same convention a route point's `x`/`y` uses. So it copies straight
into a waypoint with no conversion.

The rule `FIX-CASMISSION-BLUE-BULLSEYE` (#304) established, and the one to reuse: **RED gets red,
everything else gets blue.** A two-way branch, not three — `veafCasMission.lua:1120-1124` and
`veafCombatZone.lua:1391-1397`. That is the right rule here too, because the **`neutrals` bullseye is
garbage in real missions**: `{0, 0}` in the Syria smoke-test mission, `{100, 100}` in the demo mission.
A three-way branch would hand a neutral flight a steerpoint at the map origin.

### How the injector works, and the fact this PRD was missing

It runs as **a normal `mission build` step**, auto-enabled whenever `src/waypoints.yaml` exists
(`veaf_tools/commands/build.py:312-320`, presence-driven like every other pipeline step). The standalone
`inject-waypoints` command is the same worker by hand. So this feature ships to every rebuild.

It only touches groups with a `human_pilot` (`waypoints_injector_worker.py:96`), and `Group.coalition` is
already a populated field, so the side is known without a lookup.

Two ordering facts that shape the feature:

- the waypoints step runs **before** the aircraft-group injection steps (`build.py:349-350`), so in the
  built smoke-test mission **105 human groups exist and exactly one carries a BULLSEYE** — the base
  mission's own slot. An automatic bullseye would miss almost every slot of a dynamic-slot mission unless
  the step moves after aircraft injection.
- de-duplication exists but **replaces** rather than defers (`waypoints_injector_worker.py:135-142`). So
  the DoD's "not given a second one" is satisfied by accident while its intent — the mission maker's own
  declaration wins — needs an explicit "already declared?" check.

### And a defect found while establishing the above

**The shipped template injects a bullseye that is nowhere near any bullseye.**
`src/defaults/mission-folder/src/waypoints.yaml` declares `BULLSEYE` at the fixed example coordinates
`x: 75869, y: 48674`, and that file is copied into every mission folder `mission prepare` creates. Three
of the four mission folders in this repository ship it verbatim.

Measured, not inferred, on the built `SmokeTest_noon.miz` (Syria): the mission contains exactly **one**
waypoint named `BULLSEYE`, at `75869 / 48674`, while the mission's own blue bullseye is at
`-379712 / -111473` — **483 km away**. Red is 216 km away. A pilot flying it gets a steerpoint labelled
BULLSEYE pointing at open country.

So the status quo is not "no bullseye" but "a wrong bullseye", which settles the on-by-default question
below, and is worth fixing on its own without waiting for this lot:
[`FIX-DEFAULT-WAYPOINTS-BOGUS-BULLSEYE`](../FIX-DEFAULT-WAYPOINTS-BOGUS-BULLSEYE/PRD.md).

### On by default: yes, scoped to missions that already inject waypoints

The precedent in this codebase is consistent: **behaviour sub-flags default on**
(`pipeline.presets.kneeboards`, `mission.hide_names_from_spawned_groups`), while **whole pipeline steps
are opt-in by the existence of their config file**. Following it exactly: add
`pipeline.waypoints.bullseye`, defaulting `true`, read with the existing sub-flag helper. Every mission
that already opted into waypoint injection gets a correct, mission-sourced bullseye — fixing three wrong
ones in this repository — and no mission that opted out is touched by the route-rewrite path, which has
its own history (it force-locks `ETA_locked` on point 1, the "your flight is delayed to start" bug).

### One more thing found, worth its own line

`get_flight_plan_for` (`waypoints_manager.py:211-218`) returns the **first insertion-order plan whose
criteria are compatible**, not the most specific — its own docstring claims an
`aircraft_type > category > coalition > all` priority that is not implemented. Consequence in the shipped
template: a blue `F-16C_50` gets `all_blue_planes`, so `f16_flight_plan`
(`src/defaults/mission-folder/src/waypoints.yaml:71`) is **dead config**. Not this lot's job, but it will
bite whoever tries to give one aircraft type its own bullseye.

## Delivered — 2026-08-24

Every flight plan now also receives a `BULLSEYE` waypoint at the **mission's own** bullseye, appended so
existing point numbers do not move.

**The coalition rule is #304's, reused rather than reinvented**: RED gets red, everything else gets blue.
A two-way branch, and the reason matters — the real `neutrals` bullseye is `{0, 0}` in the Syria
smoke-test mission and `{100, 100}` in the demo mission, so a three-way branch would send a neutral
flight to the map origin.

**The mission maker's declaration always wins.** A flight plan already naming `BULLSEYE` keeps its own
coordinates, and nothing is added. That guard is not decoration: `_inject_waypoints_into_group` *replaces*
a same-named waypoint in place, so appending ours unconditionally would have overwritten his — satisfying
this lot's "not given a second one" while doing the opposite of what it means.

### On by default, and scoped

`pipeline.waypoints.bullseye`, default `true`, read with the existing sub-flag helper — byte-for-byte the
shape of `pipeline.presets.kneeboards`. That follows the codebase's own precedent rather than a
preference: behaviour sub-flags default on, whole pipeline steps are opt-in by the existence of their
config file. So a mission with no `waypoints.yaml` is untouched, and one that already injects waypoints
gains a correct bullseye.

A group no flight plan matches receives nothing: the bullseye rides along with a plan, it does not create
one. A mission maker who assigned no plan to a group asked for it to be left alone.

### Measured on the artefact, not on constructed objects

Ran the injector over the built `SmokeTest_noon.miz` and read the produced mission back:

| | |
|---|---|
| human slots | 105 |
| with the correct **blue** bullseye | 53 |
| with the correct **red** bullseye | 52 |
| wrong | **0** |
| missing | **0** |

That is the check that matters, because the failure mode here is *using the wrong side's bullseye* — #304
exactly — and a unit test with invented coordinates would not notice.

This only works because [`FIX-WAYPOINTS-STEP-TOO-EARLY`](../FIX-WAYPOINTS-STEP-TOO-EARLY/PRD.md) shipped
first: at the old step position the same feature would have reached 1 slot in 105 while satisfying this
lot's definition of done. That is why it was made a prerequisite rather than a footnote.

### Tests

12, and four mutations run against them: forcing blue for everyone kills 2, making the coalition
comparison case-sensitive kills 1, dropping the already-declared guard kills 1, ignoring the flag kills 1.

One fixture defect worth recording, since it cost the first run: the constructed `Group` did not set
`human_pilot`, and `process_groups` skips anything else — so six assertions failed on a group that was
never processed. The artefact measurement had already passed, which is what said the fixture was wrong
rather than the code.

### Documented

`GUIDE.md` / `.en.md` under `{#automatic-bullseye}` — the coalition rule and why it is two-way, the
declaration-wins guarantee, how to switch it off, and what is *not* touched.
`MISSION_YAML_REFERENCE` gained the `pipeline.waypoints.bullseye` mapping beside its `presets` twin.

## Definition of done

- [x] A flight gets a `BULLSEYE` waypoint without declaring one — 105 of 105 human slots
- [x] The correct coalition's bullseye, with a test per side — and measured on the built mission: 53 blue,
      52 red, 0 wrong
- [x] A mission that declares its own `BULLSEYE` is not given a second one — and, more to the point, not
      **overwritten**, which is what the injector would otherwise do
- [x] The on-by-default question answered here, not left to the implementation — on, scoped to missions
      that already inject waypoints, following `pipeline.presets.kneeboards`
- [x] Documented, both languages
