# 01 — Integer channel keys in channel_lists

Status: ✅ done
Type: fix

## Tasks (TDD)

- [ ] `_build_channel_lists_for_coalition`: use integer channel numbers as keys
      (`role_channels[ch_num]`) instead of `f"{ch_num:02d}"` strings.
- [ ] Regression test: a converted `channel_lists` role has **int** keys, matching the
      `radios_collection` override keys (no `'01'` vs `12` mix, no PyYAML octal quoting).

## Definition of Done

- Generated `presets.yaml` channel keys are all ints; `ruff`/`mypy`/`pytest` green.
