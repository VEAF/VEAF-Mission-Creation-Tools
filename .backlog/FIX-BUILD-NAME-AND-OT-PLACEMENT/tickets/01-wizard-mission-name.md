# 01 — The wizard proposes the folder's own mission name

Status: ✅ done

## Done when

- A test reproduces the report: a saved preference holding another mission's name, a folder whose `mission.yaml` says `mission.name: X`, and the `build` prompt is pre-filled with `X` (fails before the fix).
- `_resolve_prompt_default` follows PRD D1; its docstring states the new precedence; the keys concerned are listed in the PR.
- The mission folder prompt is checked per PRD D2, fixed and tested if it has the same defect.
- `CHANGELOG.md` entry under `[Unreleased]`; the wizard's doc page (fr, en) corrected if it states the old precedence.
