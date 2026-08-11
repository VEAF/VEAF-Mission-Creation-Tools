# FEAT-ASSIST-FOLLOWUP — the three things the first checklist flight could not close

Status: 🔄 in-progress — ticket 01 delivered; 02 and 03 need cockpit time, 04 is deferred on purpose

## Why this lot exists

`FEAT-ASSIST-CHECKLISTS` shipped and was flown by David on 2026-08-01. It was archived on
2026-08-11 with **three items still open and nothing tracking them** — which is the only reason this
lot exists. An archive is not a backlog: nobody reads it looking for work.

None of the three is blocking. One is a cheap fix nobody has done; two need a human in a cockpit,
and one of those needs *two*.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Resource names should carry a content hash](tickets/01-resource-content-hash.md) | ✅ |
| 02 | [Two pilots at once, and whether a highlight leaks](tickets/02-two-pilots-at-once.md) | 🧑 |
| 03 | [A pilot review of the F-16C slice](tickets/03-f16c-pilot-review.md) | 🧑 |
| 04 | [Probe `c_cockpit_param_in_range`, then decide](tickets/04-cockpit-param-in-range-probe.md) | ⬜ |

The four are independent of each other, and only one is worth doing now:

- **01 is done** (2026-08-11). One flight still has to confirm it, since no unit test can see DCS's
  cache — change a label, rebuild, fly **without restarting DCS**.
- **02 and 03 are `🧑 waiting-human`**, blocked on a resource David holds: cockpit time, and for 02 a
  second pilot. An agent should not pick them up.
- **04 is ready but deliberately deferred.** It is an optimisation whose first step is finding out
  whether the function exists at all. It is `⬜` rather than `🧑` because the probe can be written
  without DCS, but the ticket says plainly when it becomes worth running — not now.

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

- Nothing, now that `c_cockpit_param_in_range` has [ticket 04](tickets/04-cockpit-param-in-range-probe.md).
  It was going to sit in this section as a note; a note in a PRD's out-of-scope list is how it got
  lost the first time. It is a **deliberately deferred** ticket rather than an urgent one: the
  existing per-loop cache already absorbs most of the cost, and the ticket says when it becomes worth
  doing instead of implying it should be done now.
- Anything from `FEAT-ASSIST-AUTHORING`, which is paused by David and tracked on its own.
