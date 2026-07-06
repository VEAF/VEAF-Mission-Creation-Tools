# FEAT-CONVERTV5-PLAN-PRESETS-03 — tests

Status: ✅ done
Type: test

## What to build

- Redirect the existing `TestTripackPresetsFidelity` assertions to read
  `presets.v5.yaml` (the faithful file still carries the dedicated overrides).
- New plan-file tests (real Tripack fixture):
  - `presets.yaml` contains `channel_lists` for both coalitions.
  - `presets.yaml` has no dedicated warbird/jet override (reducible overrides dropped).
  - The packer, fed the plan's `channel_lists`, projects a warbird (e.g. Bf-109K-4)
    onto its VHF radio (proves the crystallisation is exploited).
- Synthetic test: an aircraft the packer projects to nothing keeps its override in the
  plan file (irreducible guard).

## Acceptance criteria

- [ ] Existing fidelity suite passes against `presets.v5.yaml`.
- [ ] New plan tests pass.
- [ ] `--cov-fail-under` bumped so the gate stays within ~2 pts of measured coverage.
