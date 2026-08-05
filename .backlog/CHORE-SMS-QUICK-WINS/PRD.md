# CHORE-SMS-QUICK-WINS — three small things the dcs-sms study found

Status: ⬜ ready

Origin: [`docs/exploration/DCS-SMS-EXPLOIT.md`](../../docs/exploration/DCS-SMS-EXPLOIT.md) §5.
All three verified still absent on 2026-08-05.

## Why they are grouped

They share nothing except size and origin. Grouped so three cheap things ship together instead of
each waiting for a lot of its own; ticket 01 alone is a paragraph and has been outstanding since the
study.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Write the DCS coordinate convention down](tickets/01-coordinate-convention.md) | ⬜ |
| 02 | [Ship the authoring skill to Gemini too](tickets/02-authoring-skill-gemini.md) | ⬜ |
| 03 | [A `dev_condition` test hatch for assistance steps](tickets/03-dev-condition-hatch.md) | ⬜ |

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
