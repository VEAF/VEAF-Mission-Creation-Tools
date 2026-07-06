# 02 — QRA-in-YAML: fix stale reference + reinforce YAML-first

Status: ✅ done

## Context

Triggering a QRA from `mission.yaml` is already supported and documented:
`doc/mission-maker/scripts/veafQraManager.md` has "Via `mission.yaml` (recommandé)"
and a full `modules.QRA` config section (`silence_all` + `definitions:`). The only
defect is a leftover reference to the removed top-level `qra:` block:

- `veafQraManager.md:249` — "…(ou via `mission.yaml` → `qra:` pour l'approche YAML
  recommandée)". The `qra:` top-level key no longer exists (ADR 0001); it is now
  `modules.QRA`.
- Check `.en.md` for the equivalent line.

## Tasks

- [x] Replace the stale `mission.yaml → qra:` renvoi with `modules.QRA` in
      `veafQraManager.md` (l.249) and its `.en.md` equivalent.
- [x] Sweep both files for any other `qra:` top-level mention outside the correct
      `modules:\n  QRA:` YAML blocks (l.55/108 are correct — do not touch). Only the
      l.249/250 renvoi matched; now fixed.
- [x] Optionally tighten the "YAML-first recommandé" wording so it is unambiguous that
      no Lua is required for a QRA.

## Definition of Done

- No remaining reference to a top-level `qra:` block; markdown-lint clean.
- No source file touched.
