# VDW-002 — `vendored.yaml` manifest (single source of truth for pins)

Status: ✅ done
Type: feature
Files: `vendored.yaml` (repo root)

## What to build

Create the manifest that lists every vendored artifact, populated from VDW-001. Per entry:

```yaml
- id: mist
  source:   https://github.com/VEAF/MissionScriptingTools
  upstream: https://github.com/mrSkortch/MissionScriptingTools
  pinned: "v4.5.x (commit …)"
  vendoring: fork              # verbatim | adapted | fork | compiled
  path: src/scripts/community/mist.lua
  manual_steps: "Rebase VEAF patches; watch upstream for changes to port."
  watch:
    - { kind: github-file, repo: VEAF/MissionScriptingTools, ref: master }
    - { kind: github-file, repo: mrSkortch/MissionScriptingTools, ref: master, role: upstream-ref }
```

`watch.kind` ∈ `github-release` | `github-file` | `manual`. `manual` entries have no
automatable source and are only re-surfaced as reminders.

## Acceptance criteria

- [x] `vendored.yaml` covers every artifact from VDW-001 (11 entries)
- [x] Each non-`verbatim` entry has `manual_steps`
- [x] Schema documented (header comment in `vendored.yaml` + developer README, FR/EN)

## Blocked by

VDW-001
