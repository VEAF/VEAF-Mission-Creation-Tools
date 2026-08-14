# FIX-SECURITY-BEFORE-RECOGNITION — annotating the map asks you for a password

Status: ✅ done — 2026-08-14

Origin: David, in game on 2026-08-14, testing the `_transport` fix: *"quand je fais `_transport` en
pilote L1 ça me bloque mais ça affiche trois fois le message"*. The refusal itself was the expected
result; the **three** messages are a second, older defect his session exposed.

## The measurement

`veafCommands.dispatchMarker` (`veafCommands.lua:175`):

```lua
for _, entry in ipairs(veafCommands.commandHandlers) do
    if veafCommands.isAllowed(entry, event, false) and entry.fn(...) then
```

**The security check runs before the handler says whether it recognises the command.** So every
registered handler whose tier the pilot lacks prints a refusal, for a command it would never have
handled.

Three messages for `_transport`, exactly: `veafRadio` (priority 70, `SENIOR_PILOT`), `veafMove` (60,
`SENIOR_PILOT`), and `veafTransportMission`'s own direct call — that module has its own
`onEventMarkChange` and is not in the dispatcher at all.

## The case that matters more than `_transport`

`veafMarkers.onEvent` forwards **every marker carrying text**, and the loop only stops when a handler
*consumes* the event. No dispatcher handler recognises `_transport`, so the loop runs to the end and
evaluates every tier.

Which means a pilot who is not `SENIOR_PILOT` and writes **"RDV ici"** on a marker gets two
*"give the L1 password"* messages. For annotating the map. That is the everyday face of this bug, and
it predates the work of 2026-08-13 — the dispatcher comes from `SECREV-2`.

Worth stating for scope: a command that *is* recognised behaves correctly, because the loop stops at
the first handler that consumes the event. So `_spawn` by a `KNOWN_PILOT` prints nothing spurious.
The bug is confined to text no dispatcher handler claims — which is most text a pilot ever types.

## The fix, at the cause

The dispatcher does not know which keyphrase each handler answers to, while **every module does**:
`veafMove.Keyphrase = "_move"`, `veafRadio.Keyphrase = "_radio"`,
`veafGroundAI.MarkerKeyphrase = "_ground"`, `veafNamedPoints.Keyphrase = "_name point"`,
`veafSecurity.Keyphrase = "_auth"`.

So `registerCommandHandler` takes the keyphrase, and the dispatcher skips a handler whose keyphrase is
absent from the text **before** testing anything. Deduplicating the messages instead would leave the
log full of security failures for commands nobody attempted.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Recognise before checking](tickets/01-recognise-before-checking.md) | ✅ |

## Definition of Done

- A marker reading "RDV ici", placed by a pilot with no tier, produces **no** security message.
- `_transport` refused prints its message **once**.
- A recognised command still works, and a refused one still refuses — both pinned.
- `test-lua` + stylua green.

## What the fix measures

Four tests count **security calls** rather than messages — the message is the symptom, the call is the
defect:

- a marker reading `RDV ici` produces **zero** security calls, where it produced one per tiered handler;
- a marker matching a keyphrase still reaches `isAllowed` exactly once, so the filter does not swallow
  the real case;
- matching is case-insensitive, mirroring `text:lower():find(Keyphrase)` as the modules do it;
- a handler registered with no keyphrase is still checked, which is what makes the change additive.

`veafTransportMission`'s own direct call stays: it *is* a `_transport` marker and the pilot lacks the
tier, so one message is the intended outcome. Migrating that module into the dispatcher would change
when its security runs and what consumes the event — its own ticket, not a passenger on this one.
