---
Status: 🔄 in-progress
---

# 02 — The 30-second tick, and a class-A airfield that changes side

**Blocked by:** 01 — it reads the per-airfield state table and the registrations that ticket builds.

## What it delivers

A blue-from-the-start airfield captured in flight stops being a logistic point within half a minute —
its *Request Equipment* menu goes away — and comes back when it is retaken. Both coalitions are told,
in their own language, at the moment it changes. A field every blue aircraft has departed **keeps** its
logistics, which is what makes this rule and not "allied units within 2000 m" the answer to #1007.

## Where

- The loop goes on `veafScheduler.scheduleFunction(f, vars, t, rep, st)` (`veafScheduler.lua:129`,
  removal at `:159`), like every other periodic VEAF behaviour. Nothing in `veafTransportMission`
  polls today, and it must not start doing so on its own timer.
- The reversible pair CTLD already ships for exactly this: `deactivateLogisticZone` /
  `activateLogisticZone` (`CTLD_zone.lua:1296`, `:1310`) — documented *"simulates capture or temporary
  loss"* and *"Deactivated zones are ignored by all getters until reactivated"*, which is what
  `getLogisticZonesAtPoint` (`:1503-1511`) and therefore the menu obey.
- The messages: `trigger.action.outTextForCoalition` with text from `veaf.t()`, keys in the
  `transport.*` family of `veafI18n.lua`, following that file's own header (*"add a
  `["my.key"] = { fr = "...", en = "..." }` entry here, then call `veaf.t("my.key", ...)` at the
  message site"*). The nearest precedent is `veafSpawnGround.lua:223`, announcing `spawn.fob_built`.

## Do

- One recurring task, **30 s**, the interval read from settings and never written into the loop.
- Per tick, per registered airfield: read `DcsAirbase:getCoalition()` and compare it with the last
  known state. Act only on a **difference** — do not re-issue an activation for a zone already active.
- A class-A airfield whose coalition is no longer the one it was snapshot with is **deactivated**; when
  it comes back, **activated**. Never unregister and re-register: that would churn `_logisticZones` and
  produce a duplicate warning per tick.
- No unit presence is consulted for class A. The coalition is the whole test.
- An airfield that was class A, falls, and is retaken **leaves class A**: having been held by the other
  side, it re-enters through B and owes ticket 03's two minutes like any other capture. Record the
  transition in the state table so 03 does not have to guess.
- Announce every transition: to the coalition that **gains** the point, that it can now load there; to
  the one that **loses** it, that it can no longer. Two keys, both languages, and the airfield's display
  name as the argument so the message says which field. Fire on the transition only — a tick where
  nothing changed sends nothing and writes nothing.
- A coalition read that raises leaves the zone **as it was**, and says so in the log.
- The state table survives a module re-initialisation without re-snapshotting: an airfield already
  registered is not re-classified, or a field captured while nobody was looking would be recorded as
  blue-from-the-start and granted logistics it has not earned.
- Add `deactivateLogisticZone` and `activateLogisticZone` to the recording `CTLDZoneManager` mock
  (`dcs_mocks.lua:1027`); both are absent today.

## Watch out

- Every flip publishes `OnLogisticZoneUpdated`, which makes CTLD rebuild the player's *Request
  Equipment* menu (`CTLD_crate.lua:2628`). At 30 s that is invisible; a state comparison that misfires
  turns it into a menu rebuilding itself every half minute, which a pilot will report as lag.
- 30 s is generous on purpose — the class-A test is one `getCoalition()` per airfield per tick, and no
  spatial query at all. Do not "optimise" it into a per-frame check, and do not let 03's probe run for
  class A.
- A neutral airfield is a **loss**, not a third state to announce: the message goes to the side that
  held it, and the zone stays deactivated until somebody holds it again.
- `outTextForCoalition` takes a coalition side, so `-1`/all is not an option here: telling both sides
  means two calls, and the losing side must not receive the gaining side's wording.
- The Lua coverage floor (`--cov-fail-under 80.9`) counts the tick body: drive it by calling the tick
  function directly with an injected clock, never by sleeping.

## Done when

- In flight: capturing a blue-start airfield removes its menu within one tick and announces it to both
  sides; retaking it restores both; a field with no blue unit left anywhere near it keeps its logistics.
- A tick where nothing changed sends no message, writes no log line and calls no CTLD method.
- Lua tests assert, against the recording mocks: deactivate on coalition loss, activate on return, an
  A→B reclassification when a retaken field changes hands, no CTLD call when the coalition is
  unchanged, one message per side per transition, and a raising `getCoalition()` leaving the zone as it
  was.
