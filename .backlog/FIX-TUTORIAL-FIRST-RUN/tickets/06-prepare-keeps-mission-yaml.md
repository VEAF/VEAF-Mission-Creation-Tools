# 06 — `prepare --template` asks before rewriting `mission.yaml`

Status: ✅ done

Type: fix

## The problem

`prepare` protects every existing file behind a four-way menu — replace this / keep this / replace
all / keep all ([`helpers.py:238`](../../../src/python/veaf-tools/veaf_tools/helpers.py)) — and then
walks straight past its own answer:

```python
if enabled_modules is not None:
    (p_mission_folder / "mission.yaml").write_text(generate_mission_yaml(enabled_modules), ...)
```

([`prepare.py:281`](../../../src/python/veaf-tools/veaf_tools/commands/prepare.py)) —
`enabled_modules` is set whenever `--template` is passed, and the write is unconditional. "Keep all"
does not save `mission.yaml`.

This is the most valuable file in the folder and the one a mission maker edits by hand: module
configuration, security block, build settings. Paluche lost his edits to it while trying to restore
an unrelated file, and only found out because he had to redo them.

## The fix

The template write goes through the same decision as every other existing file: on an existing
`mission.yaml`, ask (or honour a remembered "replace all" / "keep all", or `--force`). A fresh
folder is unaffected — there is nothing to lose and nothing to ask.

The prompt must say what is at stake; `mission.yaml` is not `spawnables.yaml`. It is also the one
file where the answer decides whether `--template` did anything at all, so a kept file deserves a
line saying the template was **not** applied.

## Definition of done

- [x] `prepare --template` on a folder with an existing `mission.yaml` does not overwrite it silently
- [x] `--force` still replaces, non-interactive runs still keep (the existing contract of
      `_ask_replace`)
- [x] Declining leaves the file byte-for-byte untouched, and the run says the template was not
      applied
- [x] A fresh folder still gets its generated `mission.yaml` with no prompt
- [x] Unit tests for all four paths
- [x] `--cov-fail-under` bumped per the ratchet policy
- [x] Python gate clean
