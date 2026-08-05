# DOC-TRIPACK-FEEDBACK

Status: ✅ done

Documentation-only lot from Tripack's feedback. No code changes, no PR — direct
commits on `develop` (chore/doc policy). Two independent doc gaps.

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

---

## 01 — Document auto-generated Pedro & S3B-Tanker (carrier ops)

Status: ✅ done

### Context

`veafCarrierOperations.lua` (l.113–115, 341–520) auto-manages, per registered
carrier, two named support groups it looks up by name:

- `<carrier group name> Pedro` — rescue helicopter (SH-60B), positioned 250 ft high,
  1 nm to the starboard side, riding along at the carrier's speed/heading.
- `<carrier group name> S3B-Tanker` — emergency recovery tanker, 8000 ft, 10 nm aft
  and 4 nm to starboard, refueling on BRC.

Both are respawned when destroyed and their routes are (re)laid by the module. If the
group is absent, the module logs a warning (`No Pedro group named …` /
`No Tanker group named …`). Naming is the only wiring — no script call, no `mission.yaml`.

### Tasks

- [x] Add a section (e.g. "Pedro et ravitailleur S3B" / "Pedro and S3B recovery tanker")
      to `doc/mission-maker/scripts/veafCarrierOperations.md` and `.en.md` explaining:
      the exact naming convention (`<carrier unit name> Pedro`,
      `<carrier unit name> S3B-Tanker`), that groups are auto-detected, respawned and
      routed, the placement expectations (helo type / tanker), and the warning logged
      when a group is missing.
- [x] Cross-link from the module's "Activation" / "Voir aussi" as appropriate.

### Definition of Done

- FR and EN docs describe the naming convention and behaviour; markdown-lint clean.
- No source file touched.

---

## 02 — QRA-in-YAML: fix stale reference + reinforce YAML-first

Status: ✅ done

### Context

Triggering a QRA from `mission.yaml` is already supported and documented:
`doc/mission-maker/scripts/veafQraManager.md` has "Via `mission.yaml` (recommandé)"
and a full `modules.QRA` config section (`silence_all` + `definitions:`). The only
defect is a leftover reference to the removed top-level `qra:` block:

- `veafQraManager.md:249` — "…(ou via `mission.yaml` → `qra:` pour l'approche YAML
  recommandée)". The `qra:` top-level key no longer exists (ADR 0001); it is now
  `modules.QRA`.
- Check `.en.md` for the equivalent line.

### Tasks

- [x] Replace the stale `mission.yaml → qra:` renvoi with `modules.QRA` in
      `veafQraManager.md` (l.249) and its `.en.md` equivalent.
- [x] Sweep both files for any other `qra:` top-level mention outside the correct
      `modules:\n  QRA:` YAML blocks (l.55/108 are correct — do not touch). Only the
      l.249/250 renvoi matched; now fixed.
- [x] Optionally tighten the "YAML-first recommandé" wording so it is unambiguous that
      no Lua is required for a QRA.

### Definition of Done

- No remaining reference to a top-level `qra:` block; markdown-lint clean.
- No source file touched.
