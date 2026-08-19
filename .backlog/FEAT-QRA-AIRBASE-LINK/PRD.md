# FEAT-QRA-AIRBASE-LINK — a QRA does not know which airbase it flies from

Status: ⬜ ready

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

## Definition of done

- [ ] A QRA declares its base and stops when that base is captured
- [ ] The three smaller asks of #88 each done, or explicitly deferred here
- [ ] Lua tests driven by a mocked capture event
