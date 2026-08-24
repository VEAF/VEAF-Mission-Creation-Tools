# FEAT-QRA-AIRBASE-LINK — a QRA does not know which airbase it flies from

Status: ✅ done

Origin: [#88](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/88), 2022.

## The gap

`veafQraCore.lua` has no `setBase`, and `S_EVENT_BASE_CAPTURED` appears nowhere in the runtime —
grepped. A QRA therefore keeps launching after its airfield has changed hands, which is the case the
issue opens with.

#88 bundles four asks. The airbase link is the one with a clear trigger and a clear rule; the others
(a QRA dictionary, `stop()`, cleaning up groups that landed) are smaller and can ride along.

## Scope

`VeafQRA:setBase(airportName)` plus an `S_EVENT_BASE_CAPTURED` subscriber that stops the QRA when its
base changes coalition. `veafEventHandler` already dispatches DCS events, so this is a subscriber
rather than new plumbing.

One interaction worth knowing: an airfield's coalition lives in `warehouses`, but the **runtime reads
it from DCS**, so the event is the source of truth rather than the mission table.

## Already delivered — established 2026-08-24, nothing built

This PRD is wrong on its central claim, and reading `veafQraCore.lua` through says so on four counts.
Recorded here rather than quietly closed, because the same wrong premise would come back.

**"`veafQraCore.lua` has no `setBase`".** It has `setAirportLink(airport_name)`
(`veafQraCore.lua:468`), which validates the name against `Airbase.getByName` before storing it. And it
is wired end to end: the generator emits `:setAirportLink("…")` from a QRA's `airport_link` key
(`lua_config_generator.py:910`), and `mission_validator` refuses an unknown airfield name at build time.

**"A QRA therefore keeps launching after its airfield has changed hands".** It does not.
`VeafQRACore:check()` calls `checkAirport()` whenever `airportLink` is set (`:702-704`), and
`checkAirport` asks `veaf.getAirbaseForCoalition(self.airportLink, self.coalition)` — which returns nil
for an airfield that is **no longer of the QRA's coalition**, which is exactly what a capture is. The QRA
then goes to `STATUS_NOAIRBASE`, announces `messageAirbaseDown` and fires its `onAirbaseDown` callback.

### The three smaller asks of #88, each measured

| Ask | State |
|---|---|
| a QRA dictionary | **done** — `veafQraManager.qras` (`:76`), registered at `:1145`, looked up at `:1150` |
| `stop()` | **done** — `:1105`, and it despawns the spawned groups rather than only changing state |
| cleaning up groups that landed | **done** — a landed aircraft is never counted (`:740`, `if unit:isExist() and unit:inAir()`), and `stop()` destroys the spawned groups |

### The one real gap, and why it is not worth a lot

`S_EVENT_BASE_CAPTURED` is indeed not subscribed anywhere. So the reaction is **polled** rather than
immediate — but `veafQraManager.WATCHDOG_DELAY = 5` (`:51`), so the poll is every **five seconds**.

An event subscriber would turn a ≤5 s reaction into an instant one. For a QRA that is not a difference
anybody can observe: nothing launches inside five seconds of a capture that would not have launched
anyway, and a QRA's own `delayBeforeActivating` is longer than the poll. Building it would be work for
its own sake, and it would add an event subscription to a module that already reaches the same state by a
path that is tested.

**If a case ever appears where five seconds matters**, the subscriber is a few lines on top of
`veafEventHandler` and `checkAirport` — which is why this is recorded rather than filed as a follow-up
lot nobody needs.

## Definition of done

- [x] A QRA declares its base and stops when that base is captured — `setAirportLink` +
      `checkAirport`, both shipped long before this lot was written
- [x] The three smaller asks of #88 each done, or explicitly deferred here — all three **done**, with
      the line references above
- [x] Lua tests driven by a mocked capture event — **not written, deliberately**: there is no capture
      event in the path. The behaviour comes from `getAirbaseForCoalition` returning nil, which the
      existing airbase tests already cover, and a test built around an event the code does not listen to
      would assert a mechanism that does not exist
