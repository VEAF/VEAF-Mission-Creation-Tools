# 01 — Make the two scaffolds agree

Status: ⬜ ready

Type: fix · Files: `src/python/veaf-tools/veaf_libs/mission_template.py`,
`src/defaults/mission-folder/mission.yaml`

## The two sides

`render_modules_block` (`mission_template.py:247`) walks the catalogue and skips anything that is
neither infrastructure nor in the requested tier:

```python
include = module.kind in (INFRA, SECURITY) or module.id in enabled
if not include:
    continue
```

For a community script that is **opt-out**, being skipped means being *enabled* — the build reads
the absence as "use the default", and the default is on.

The shipped `src/defaults/mission-folder/mission.yaml` does the opposite, listing all five at
`false` (lines 203-208).

## What to do

Recommended: emit the opt-out community scripts as `<ID>: false` when the tier does not include
them, so a generated `mission.yaml` says what it means and matches the shipped default. Keep the
existing comments those lines carry in the default file — they are the only place a mission maker
learns that CTLD is configured in a separate file.

Whatever you choose, say why in the PR, and check the other tiers (`standard`, `full`) rather than
fixing `minimal` alone.

## The test that would have caught it

Compare the two scaffolds **against each other**: for every opt-out community script, the module
state a `prepare --template <tier>` mission ends up with must equal the state the shipped default
gives. The drift survived because each side was tested alone and both were self-consistent.

## Definition of done

- [ ] The two scaffolds agree, for every tier
- [ ] A test compares them side by side, for all five opt-out scripts
- [ ] `prepare --template minimal` then `build` no longer reports a community script the mission
      never named — check it end to end, that is the symptom that started this
- [ ] `CLAUDE.md` §9.7 asks for the shipped default to stay aligned with generated output; make
      sure that still holds after your change
- [ ] Docs describing what a template emits match the new behaviour

## Note

Existing missions are unaffected: they carry their own `mission.yaml`. Only new scaffolds change.
Say so in the PR — this reads like a behaviour change and is not one.
