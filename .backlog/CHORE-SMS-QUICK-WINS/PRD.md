# CHORE-SMS-QUICK-WINS — three small things the dcs-sms study found

Status: 🔄 in-progress — 01 and 03 done; 02 delivered but waiting on a Gemini CLI round trip

Origin: [`docs/exploration/DCS-SMS-EXPLOIT.md`](../../docs/exploration/DCS-SMS-EXPLOIT.md) §5.
All three verified still absent on 2026-08-05.

## Why they are grouped

They share nothing except size and origin. Grouped so three cheap things ship together instead of
each waiting for a lot of its own; ticket 01 alone is a paragraph and has been outstanding since the
study.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Write the DCS coordinate convention down](tickets/01-coordinate-convention.md) | ✅ |
| 02 | [Ship the authoring skill to Gemini too](tickets/02-authoring-skill-gemini.md) | 🧑 |
| 03 | [A `dev_condition` test hatch for assistance steps](tickets/03-dev-condition-hatch.md) | ✅ |

## Ticket 03 is not blocked by the paused authoring lot

Worth stating because it looks like it should be. `FEAT-ASSIST-AUTHORING` is ⏸ paused — that lot is
the **authoring** side: the resolver, the instructor format, the cockpit indexes.
`FEAT-ASSIST-CHECKLISTS`, the **engine** and the YAML format, is ✅ done. A `dev_condition` is an
engine-and-format feature, so it belongs to the finished lot's territory and can proceed while
authoring stays parked.

## Definition of Done

- Each ticket is independently shippable; none blocks another, and the lot can close with any subset
  done as long as the rest is honestly reflected in its status.
- Docs in both languages where user-facing (`docs-check` refuses an untranslated page).
- CHANGELOG entry per ticket that changes behaviour; ticket 01 is documentation only and needs none.

## Outcome — 2026-08-11

All three shipped in one branch, as the lot intended.

**01** put the coordinate convention in `docs/agents/dcs-coordinates.md`, and verifying it rather than
restating it turned up something the ticket did not know: the runtime is **not internally consistent
either** — `land.getHeight` takes a vec2 whose `y` is the easting while the vec3 it comes from uses `y`
for altitude, three lines apart in `veaf.getLandHeight`. So the page tells a reader to reason from the
called function's signature, not from which side of the fence they are on.

**02** found that the adaptation is not deep at all: Gemini CLI reads skills from
`<root>/skills/<name>/SKILL.md`, the same layout and the same `SKILL.md` format as Claude Code. One
directory now carries both manifests and the guidance exists once. It is 🧑 rather than ✅ for one honest
reason — **Gemini CLI is not installed on this machine** (measured: no `commands/`, `skills/` or
`extensions/` under `~/.gemini`, and `gemini` is not on `PATH`), so the acceptance criterion "tested
rather than assumed" is the one thing not met. Three commands close it; they are in the ticket.

**03** delivered the `dev_condition` hatch, and took the decision the ticket had left open: warn loudly,
never refuse, no strict flag — because refusing would make the feature unusable, and the guard that
actually protects a pilot is the on-screen notice, not a flag the forgetful author has to remember.

Version 6.13.89, and the lot's own contribution to the quality ratchet: `test_plugin_version.py` grew
from one test to four and now covers **both** agent manifests.
