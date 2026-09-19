# Routes and tables

Two small families sharing one property: they are about data **DCS itself** refuses or digests
badly. So you have no way to guess the rule from the editor — it is nowhere in the interface.

## No waypoint has a locked time {#validate-route-no-locked-time}

> group 'North-Patrol': no waypoint has a locked time — the DCS Mission Editor refuses to save this
> route. Lock the arrival time of the first waypoint.

**In the editor.** Every waypoint on a route carries two checkboxes that matter here: the **locked
arrival time** (the ETA) and the **locked speed**. The DCS editor requires at least one waypoint on
the route to have its time locked. Without that it shows a red box and refuses to save the mission:

> *Route has no waypoints with locked time!*

**The way out.** Lock the arrival time of the **first** waypoint. That is the safest choice: it
fixes the departure and leaves the rest to be computed.

**What it is not.** VMCT did not write this. Such routes arrive in your mission as they are — from
a copy-pasted waypoint, a reused template, or a third-party tool. The message is a warning, not an
error, precisely because DCS has already accepted the file: refusing to build it would be worse
than saying so.

## A locked speed caught between two locked times {#validate-route-contradictory-locks}

> group 'North-Patrol': waypoint 2 has a locked speed between waypoints with locked times — the DCS
> Mission Editor refuses to save this route. Clear ETA_locked on the waypoints after the first, or
> clear speed_locked on this one.

**In the editor.** The contradiction is simple to state: you are asking both to arrive at a precise
time and to fly at a precise speed, over the same leg. DCS cannot satisfy both, and says so — while
naming the **route** rather than the checkbox, which makes the original message hard to connect to
anything:

> *All waypoints (2-2) have locked speed and surrounded by waypoints 1 and 2 with locked time!*

**The two ways out, and what they cost:**

| Way out | Effect |
|---|---|
| Clear the locked time on the waypoints **after the first** | The route leaves on time, the rest follows freely |
| Clear the locked speed on the offending waypoint | Speed adjusts to hold the schedule |

**How it was found.** On 2026-08-22, `validate` declared a mission sound seconds before the DCS
editor refused to open it. The defect came from a hand-copied waypoint, not from a tool — but the
real problem was the **silence**: a mission that will not open costs a session, and the tool whose
job it is to say so said everything was fine.

**What it is not.** Nothing to do with fuel, unrealistic speed or distance: the contradiction is
formal, and it happens even on a perfectly flyable route.

## A mission table has a hole {#validate-holed-sequence}

> Mission table 'coalition.blue.country[1].plane.group' is numbered 1, 3, 4 instead of 1..3 — a
> hand edit or a third-party tool left a hole in it. The build closes it up, but it is worth
> checking that is what you meant.

At build time the same thing is announced more briefly:

> mission table renumbered: coalition.blue.country[1].plane.group

**What it means.** DCS's Lua tables are lists numbered `1, 2, 3…` with no gaps. Deleting an entry
by hand leaves `1, 3, 4`: Lua loads the file without complaint, but any reader walking the list
stops at the hole — or dies on it.

**Where it comes from.** A hand edit of `src/mission/mission`, or a third-party tool that removed a
group without renumbering.

**What the build does about it.** It closes the hole itself, and warns you rather than doing it
silently. Doing it silently has already cost dearly: on 2026-08-18, three holes broke three
unrelated subsystems under a message (`'int' object has no attribute 'get'`) that named none of
them.

**What you should check.** That the entry that disappeared was meant to. The build renumbers, it
does not resurrect anything: if you deleted a group by mistake, it is not coming back.

**What it is not.** Not a corrupt `.miz`, and not a blocker: the mission builds.

## Radio presets with no player aircraft {#validate-presets-no-aircraft}

> presets.yaml is configured but the mission has no player aircraft to apply radio presets to.

**In the editor.** Radio presets apply to aircraft with a unit at **Client** or **Player** skill —
the slots pilots sit in. Your mission has none, so the step has nothing to do.

**The ways out.** Open player slots in the editor, or turn the step off in `mission.yaml`:

```yaml
pipeline:
  presets: false
```

**What it is not.** Not an error in your `presets.yaml`, whose contents were not even examined. And
for a server-side mission or a template library, this is a perfectly normal situation.

## Waypoints with no aircraft groups {#validate-waypoints-no-aircraft}

> waypoints.yaml is configured but the mission has no aircraft groups to inject waypoints into.

The twin of the previous one, with a broader criterion: here any **group** of planes or helicopters
will do, player or AI. Having none means the mission holds nothing that flies.

**The ways out.** The same: place air groups, or turn `pipeline.waypoints` off.

## Going further {#more}

- [Build messages](README.en.md) — the other families
- [Radio presets](../concepts/radio-presets.en.md)
- [The build — pipeline steps](../concepts/build.en.md#pipeline-steps)
