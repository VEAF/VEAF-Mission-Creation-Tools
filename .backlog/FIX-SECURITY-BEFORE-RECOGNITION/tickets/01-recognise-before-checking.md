# 01 — Recognise before checking

Status: ✅ done 2026-08-14 — the dispatcher recognises before it checks; the five handlers declare their keyphrase, and a handler without one keeps today's behaviour
Type: fix
Files: `src/scripts/veaf/veafCommands.lua`, the five modules that register a handler,
`src/scripts/veaf/veafTransportMission.lua`, `test/lua/`

## The change

`veafCommands.registerCommandHandler(fn, priority, security, keyphrase)` gains a fourth argument, and
`dispatchMarker` skips an entry whose keyphrase is absent from the marker text **before** calling
`isAllowed`. A handler registered without one keeps today's behaviour, so nothing breaks while the
five callers are updated.

The five, with the keyphrase each already declares:

| Module | Priority | Tier | Keyphrase |
|--------|----------|------|-----------|
| `veafNamedPoints` | 30 | `OPEN` | `_name point` |
| `veafSecurity` | 50 | `OPEN` | `_auth` |
| `veafMove` | 60 | `SENIOR_PILOT` | `_move` |
| `veafGroundAI` | 62 | `KNOWN_PILOT` | `_ground` |
| `veafRadio` | 70 | `SENIOR_PILOT` | `_radio` |

The two `OPEN` ones print nothing today, so they gain no user-visible change — but filtering them too
keeps the rule uniform, and a handler that never runs is cheaper than one that runs and declines.

## The third message

`veafTransportMission` is **not in the dispatcher**: it registers its own `veafMarkers` handler and
calls `checkSecurity_L1` directly. Filtering the dispatcher removes two of the three messages; the
third is that direct call, which is correct — it *is* a `_transport` marker and the pilot lacks the
tier. So one message, which is the intended outcome.

Do not migrate that module into the dispatcher here. It would be the right shape, but it changes when
its security runs and what consumes the event, which deserves its own ticket rather than riding along.

## TDD

- Failing first: a marker reading `RDV ici` with a verdict-false security stub must produce **no**
  security call at all. Today it produces one per tiered handler.
- A marker matching a handler's keyphrase still reaches `isAllowed` — the filter must not swallow the
  real case.
- A handler registered **without** a keyphrase is still evaluated, so the change is additive.
- Case: keyphrase matching follows what the modules do today — read one of them rather than assuming
  (`veafTransportMission` lowercases the text before `find`).

## Acceptance criteria

- [ ] Plain text on a marker triggers no security message.
- [ ] A refused `_transport` prints exactly one.
- [ ] The five handlers declare their keyphrase; a handler without one keeps working.
- [ ] `test-lua` + stylua green.
