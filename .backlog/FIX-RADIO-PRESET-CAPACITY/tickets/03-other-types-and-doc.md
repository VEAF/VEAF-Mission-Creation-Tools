# 03 — Other types, known limitation, doc

Status: ✅ done

## Done when

- The module files of the types `dcs-radio-layouts.yaml` lists are searched for a documented preset count; a capacity is declared only where one is documented (PRD D4), and the PRD's Outcome lists what was looked at and what was found.
- `known-limitations.yaml` gets a `kind: dcs` entry, dated: the OH-58D client crash at spawn with 32 FM presets, 21 working, the exact limit unknown; with `fixed_in` set to the coming release for the tool side. `docs/agents/dcs-runtime-traps.md` regenerated.
- The presets doc page (fr and en) says a radio has a capacity, that a longer list is truncated with a warning, and gives the OH-58D FM example; `docs-check` passes.
- `CHANGELOG.md` entry under `[Unreleased]`, appended at the end.
