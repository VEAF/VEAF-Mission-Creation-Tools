# FEAT-ASSIST-FOLLOWUP — the three things the first checklist flight could not close

Status: ⬜ ready

## Why this lot exists

`FEAT-ASSIST-CHECKLISTS` shipped and was flown by David on 2026-08-01. It was archived on
2026-08-11 with **three items still open and nothing tracking them** — which is the only reason this
lot exists. An archive is not a backlog: nobody reads it looking for work.

None of the three is blocking. One is a cheap fix nobody has done; two need a human in a cockpit,
and one of those needs *two*.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Resource names should carry a content hash](tickets/01-resource-content-hash.md) | ⬜ |
| 02 | [Two pilots at once, and whether a highlight leaks](tickets/02-two-pilots-at-once.md) | 🧑 |
| 03 | [A pilot review of the F-16C slice](tickets/03-f16c-pilot-review.md) | 🧑 |

Ticket 01 is actionable now and does not depend on the other two. Tickets 02 and 03 are
**blocked on a resource David holds** — cockpit time, and for 02 a second pilot — so they are
`🧑 waiting-human` rather than ready, and an agent should not pick them up.

## What the parent lot already established

Worth having here so this lot is readable on its own:

- The engine reaches the cockpit primitives through `net.dostring_in("mission", …)`, because
  `a_cockpit_highlight` lives in the **trigger** environment. Consequence: the module needs a
  de-sanitised `MissionScripting.lua`.
- Switch **positions** cannot be read from a mission. `param:` reads a value the aircraft
  *publishes* instead. Four of the six F-16C steps are pilot-confirmed for that reason, not for want
  of a mechanism.
- Writing steps by hand was **never the bottleneck** — which is why the generator follow-up
  (`FEAT-ASSIST-AUTHORING`) was deprioritised and later paused.

## Out of scope

- **`c_cockpit_param_in_range`.** It exists in the mission environment and would let the engine ask a
  question instead of parsing a ~19 KB dump once per tick. Its signature was never probed, DCS having
  been closed by then. A real optimisation, but it is one — not an open defect — and nothing depends
  on it. Recorded here so it is not lost a second time.
- Anything from `FEAT-ASSIST-AUTHORING`, which is paused by David and tracked on its own.
