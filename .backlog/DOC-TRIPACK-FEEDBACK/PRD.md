# DOC-TRIPACK-FEEDBACK

Status: ✅ done

Documentation-only lot from Tripack's feedback. No code changes, no PR — direct
commits on `develop-v6` (chore/doc policy). Two independent doc gaps.

## Problem

1. **Carrier ops — Pedro & S3B-Tanker undocumented.** `veafCarrierOperations.lua`
   auto-manages a rescue helicopter and an emergency recovery tanker: at runtime it
   looks up, by name, a group `<carrier group name> Pedro` (rescue helo — SH-60B,
   250 ft, 1 nm to starboard, riding along the carrier) and a group
   `<carrier group name> S3B-Tanker` (8000 ft, 10 nm aft, 4 nm to starboard,
   refueling on BRC), respawns them when destroyed and lays their routes. The
   mission-maker doc [`veafCarrierOperations.md`](../../doc/mission-maker/scripts/veafCarrierOperations.md)
   says **nothing** about this, so nobody knows to place the two groups or how to
   name them.

2. **QRA-in-YAML — done, but a stale doc reference misleads.** Triggering a QRA from
   `mission.yaml` is **already implemented**: [`veafQraManager.md`](../../doc/mission-maker/scripts/veafQraManager.md)
   documents `modules.QRA` (`silence_all` + `definitions:`) as the recommended
   YAML-first path. But line 249 (FR) still says `mission.yaml → qra:` — the old
   top-level `qra:` block removed by [ADR 0001](../../docs/adr/0001-modules-single-source-of-truth.md).
   The stale renvoi makes readers doubt the YAML path exists.

## Decision (validated by David)

- Feedback #1 and #3 are pure documentation; keep them in this doc lot.
- Feedback #2 (GUIDE-MM pipeline discoverability) does **not** live here — it moves
  into `FEAT-PRESETS-KNEEBOARD-TOGGLE` so the new pipeline section documents the
  kneeboards toggle in the same GUIDE passage.
- No behaviour change, no ADR. The `Preset kneeboard` glossary term was added to
  `CONTEXT.md` during the grill session (belongs to the feature lot's domain).

## Scope

- **Ticket 01** — document the Pedro / S3B-Tanker naming convention and auto-behaviour
  in `veafCarrierOperations.md` (+ `.en.md`).
- **Ticket 02** — fix the stale `qra:` reference and reinforce the YAML-first framing
  in `veafQraManager.md` (+ `.en.md`).

## Out of scope

- Any Lua/Python change. Carrier ops and QRA behaviour are unchanged and correct.
- The GUIDE-MM pipeline section (retour #2) → `FEAT-PRESETS-KNEEBOARD-TOGGLE`.
