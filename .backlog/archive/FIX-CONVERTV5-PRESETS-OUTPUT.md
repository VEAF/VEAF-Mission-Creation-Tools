# Lot FIX-CONVERTV5-PRESETS-OUTPUT — cleaner convert-v5 presets.yaml (with David)

Status: ✅ done
Branch: fix/convertv5-presets-output → PR → develop

## Problem Statement

David tested a real converted `presets.yaml` (`D:\dev\_VEAF\tmp\test-tripack\src\presets.yaml`)
and spotted two output-quality issues in the file convert-v5 generates:

1. **Inconsistent channel keys.** `channel_lists` uses zero-padded **strings**
   (`'01'`..`'20'`, from `_build_channel_lists_for_coalition`'s `f"{ch_num:02d}"`),
   with PyYAML quoting them inconsistently (`'01'` quoted but `08`/`09` not — `08`
   isn't a valid octal); the `radios_collection` overrides use **ints** (`1`..`20`,
   from `convert_presets`). Same file, `'12'` vs `12`.
2. **No comments.** `_yaml_dump` writes a bare `yaml.dump` — the generated file has
   no header, unlike the richly-commented shipped default; nothing explains
   `channel_lists` / `channels_collection` / the `presets.v5.yaml` sibling.

## Solution

1. **Uniform integer channel keys** (David's choice): `1..20` everywhere
   (`channel_lists` + radios), no quotes, no octal trap. Fix the string-padding in
   `_build_channel_lists_for_coalition`.
2. **Header comments** on the generated presets files: `_yaml_dump` gains an optional
   header; the plan (`presets.yaml`) gets a block explaining `channel_lists`
   (packer-projected plan), `channels_collection` (alias resolution) and the faithful
   `presets.v5.yaml` sibling; the faithful copy gets a short "raw reference, not
   loaded" header. (Inline per-channel comments aren't possible via PyYAML.)

## Scope

- **Ticket 01** — integer channel keys in `channel_lists`; regression test that keys
  are ints and consistent with the override radios.
- **Ticket 02** — header comments for the generated presets files (plan + faithful),
  via an optional `_yaml_dump` header.

## Out of scope

- Inline per-channel comments (PyYAML can't).
- Changing the aliasing / plan model (FEAT-CONVERTV5-FREQ-ALIASING).

---

## 01 — Integer channel keys in channel_lists

Status: ✅ done
Type: fix

### Tasks (TDD)

- [ ] `_build_channel_lists_for_coalition`: use integer channel numbers as keys
      (`role_channels[ch_num]`) instead of `f"{ch_num:02d}"` strings.
- [ ] Regression test: a converted `channel_lists` role has **int** keys, matching the
      `radios_collection` override keys (no `'01'` vs `12` mix, no PyYAML octal quoting).

### Definition of Done

- Generated `presets.yaml` channel keys are all ints; `ruff`/`mypy`/`pytest` green.

---

## 02 — Header comments on generated presets files

Status: ✅ done
Type: fix

### Tasks

- [ ] `_yaml_dump` gains an optional `header: str | None` (comment block written
      before the YAML body), without changing its other callers.
- [ ] Plan (`presets.yaml`) header: explain `channel_lists` (packer-projected plan),
      `channels_collection` (alias resolution), and the faithful `presets.v5.yaml`
      sibling; "generated — do not edit by hand" note.
- [ ] Faithful (`presets.v5.yaml`) header: short "raw iso-functional copy, reference /
      rollback, NOT loaded by the build".
- [ ] Localize the headers (FR/EN via `t()`), consistent with other generated files.

### Definition of Done

- Both generated files carry a clear header; Markdown and YAML still parse; tests green.
