# FIX-GROUNDAI-SILENT-REFUSALS — six marker commands that do nothing and say nothing

Status: ✅ done

Found in game on 2026-08-24. David wrote
`_ground order, name arty-1, order aim; target 37TFH7355147565` and reported: *"ça ne fait rien (et rien
dans le log)"*.

## The defect

`veafGroundAI.executeCommand` dispatches six verbs, and every one of them is shaped like this:

```lua
local handler = veafGroundAI.get(handlerName)
if handler then
  ...
  return true
end
```

**No `else`.** A command addressed to an autopilot that does not exist does nothing, silently, and its only
trace is a `trace`-level log line — invisible at the default level. `unset`, `start`, `stop`, `clear`,
`status` and `order` all behave this way.

What actually happened to David: reloading the mission discarded the `arty-1` he had created earlier with
`_ground set`, and the next order vanished without a word. Nothing told him the name was unknown, so
nothing distinguished "the autopilot is gone" from "the coordinates are wrong" from "the module is broken".

`ArtilleryUnitHandler:orderTextAnalysis` has the same shape one level down: an order text that does not
parse at all returns `nil` in silence. (A *typo* inside a parseable order is announced —
`veaf.reportUnknownParameters` handles that — so only total garbage is silent.)

## Why it is worth a lot of its own

`_ground set` is the only one of the seven verbs that cannot fail this way, because it creates the handler
when it is missing. So the module's own most common workflow — set, then order — has a cliff in it: the
first command works, and after a reload the second one is a no-op that looks like a broken mission.

This is the same defect as `FIX-SPAWN-BYPASSSECURITY-AS-SILENT` and the artillery correction refusals, in a
third place: **a refusal the player cannot see is worse than an error**. He retries, changes the wrong
variable, and concludes the feature does not work.

## Scope

1. One lookup that complains, used by the six verbs.
2. The message names the autopilot asked for **and** how to create one, because "unknown" without "here is
   what to do" sends the pilot back to the documentation mid-flight.
3. An unparseable order text announces itself too.

## Definition of done

- [x] Each of the six verbs announces an unknown autopilot name — one `veafGroundAI.getOrComplain`, used
      by all six. `set` keeps the silent `get`, deliberately: creating what is missing is that verb's job
- [x] The message names the autopilot and the command that would create it
- [x] An unreadable order text is announced rather than dropped
- [x] Tests per verb, since the six sites are separate code — 13 tests
- [x] Documented on the veafGroundAI page, both languages — a `{#silent-refusals}` table saying what each
      message means and what to do about it

## A third silence, found by a failing test

`_ground unset` refused to be fixed by the six-verb change, and the test said why: `set` and `unset`
without a `groupname` take the nearest allied group within **250 m**, and finding none returned `nil` from
`markTextAnalysis` — one level *above* the verb dispatch, so the command never reached the code being
fixed. That is what a marker dropped a hundred metres too far from the battery looked like: nothing at all.
It is announced now too.

### Mutations

| Mutation | Result |
|---|---|
| back to the silent `get` in all six verbs | 6 tests fail |
| the lookup stops complaining | 6 tests fail |
| the 250 m miss silent again | 3 tests fail |
| an unreadable order silent again | 2 tests fail |
| it answers a *silent* battery too | 1 test fails |
| it complains about a **known** autopilot | 1 test fails |

One killed nothing at first: making the unreadable order silent again passed everything, because the
message had been written without a test. Same shape as the day's other misses — the code was there, the
assertion was not.
