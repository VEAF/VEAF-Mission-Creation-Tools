# Lot VENDORED-DRIFT-WATCH — scheduled drift-watch for all vendored artifacts

Status: ✅ done (merged in PR #524)
Branch: `feature/vendored-drift-watch` (one branch + one PR for the lot)

## Problem Statement

We vendor (commit a frozen copy of) several third-party artifacts: community Lua scripts
(mist, CTLD, CSAR, AIEN, TUM, Skynet, Hercules, STTS), the Python `luadata` library,
community sounds, and soon `dcs-world-api-schema.json` (TOOLING-DCS-MOCK-COVERAGE). Nothing
tells us when an upstream ships a newer version, so a pinned copy silently rots.

Worse, the provenance is **not obvious**. `mist` is a VEAF-maintained version with local
patches (an upstream PR unmerged for years) — there the VEAF fork **is** our source. But
for the others (`DCS-CTLD`, `DCS-CSAR`, `AIEN`, `the-universal-mission-for-dcs-world`) the
existence of a VEAF fork does **not** mean we vendor from it: VEAF often forks a repo only
to open a PR upstream, while the vendored copy may come straight from upstream, verbatim.
The real source — and whether the copy carries local changes — can only be established by
**comparing content**, not by the presence of a fork. For a forked/patched artifact,
updating is **not a drop-in copy** but a re-apply/rebase of VEAF changes — knowledge that
lives nowhere in the repo today.

## Solution

A single source-of-truth **manifest** of every vendored artifact, a **`check-vendored`**
command, and a **scheduled GitHub workflow** that opens/updates **one issue** when any pin
drifts from upstream. **Notify only — never auto-update** (auto-update is the
COMMUNITY-AUTOUPDATE vision, out of scope). The manifest also records, per artifact, the
**vendoring mode** and the **manual steps** required to update it.

## User Stories

1. As a maintainer, I want a GitHub issue when an upstream of a vendored artifact has a
   newer version, so a stale copy never goes unnoticed.
2. As a maintainer, I want each entry to state whether updating is a plain copy or a
   fork-rebase / patch-reapply, with the steps, so I know the real work before bumping.

## Implementation Decisions

- **Manifest `vendored.yaml`** is the single source of truth for pins. Per entry: `id`,
  `source` (where we vendor from), `upstream` (reference origin, for forks), `pinned`
  (version/commit), `vendoring` (mode), `manual_steps` (required for non-verbatim), `path`,
  `watch[]` (`{kind, repo, ref, role}`).
- **Vendoring modes**: `verbatim` (plain copy) · `adapted` (VEAF patches re-applied in
  place) · `fork` (maintained in a VEAF repo — watch BOTH our fork and the upstream) ·
  `compiled` (built artifact from upstream, e.g. Skynet).
- **`watch.kind`**: `github-release` (compare latest tag) · `github-file` (compare the
  file's last commit on a ref) · `manual` (no automatable source → the issue just reminds
  to check by hand).
- **Notify, not auto-update**: the workflow opens/updates ONE recap issue listing drifts +
  the `manual` entries to re-check, each with its `manual_steps`.
- **No artifact download**: comparisons use the GitHub API (tag/commit) via the workflow
  `GITHUB_TOKEN`.
- **Provenance is established by content comparison** (VDW-001), never assumed from a VEAF
  fork existing — a fork is often only a contribution fork. The `source` / `vendoring`
  mode of each entry is the diff's verdict (vendored file vs upstream vs any VEAF fork).
- For confirmed forks, watch the VEAF `source` (did our copy fall behind our own fork?) AND
  the `upstream` (did the original ship something to port?).

## Testing Decisions

- `check-vendored` unit-tested with a fixture manifest and **mocked** GitHub API responses
  (no network in tests).
- The workflow validated by a manual `workflow_dispatch` dry-run before relying on the cron.

## Out of Scope

- Auto-update / auto-bump PRs (→ COMMUNITY-AUTOUPDATE vision).
- Vendoring `dcs-world-api-schema.json` itself (→ TOOLING-DCS-MOCK-COVERAGE); this lot only
  *watches* it.
- Actually rebasing any fork (this lot *detects* drift; the rebase is per-bump manual work).

---

## VDW-001 — audit each vendored artifact's real provenance (by content diff)

Status: ✅ done
Type: chore (investigation)
Files: — (produces the data for VDW-002)

### What to build

For every vendored artifact, establish its **real** source and divergence by **comparing
content** — never by assuming a VEAF fork is the source (a fork is often only a
contribution fork).

Artifacts to cover: `mist`, `CTLD`, `CSAR`, `AIEN`, `TheUniversalMission` (TUM), `Skynet`,
`Hercules_Cargo`, `DCS-SimpleTextToSpeech`, the Python `luadata` lib, the community sounds
(`CSAR.ogg`, `beacon*.ogg`, `radiobeep.ogg`), and `dcs-world-api-schema.json` (watched only).

For each: diff the vendored file against (a) the plausible upstream and (b) any VEAF fork,
then record:
- `source` (where we actually vendor from) and `upstream` (reference origin),
- `vendoring` mode: `verbatim` | `adapted` | `fork` | `compiled`,
- `pinned` version/commit currently shipped,
- `manual_steps` to update (re-apply patches / rebase fork / recompile), for non-verbatim.

### Acceptance criteria

- [x] Provenance table for all artifacts, each backed by a content comparison (not by fork existence) — captured directly in `vendored.yaml`
- [x] Vendoring mode + source/upstream + pinned version recorded per artifact
- [x] `manual_steps` drafted for every non-`verbatim` artifact

### Blocked by

—

---

## VDW-002 — `vendored.yaml` manifest (single source of truth for pins)

Status: ✅ done
Type: feature
Files: `vendored.yaml` (repo root)

### What to build

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

### Acceptance criteria

- [x] `vendored.yaml` covers every artifact from VDW-001 (11 entries)
- [x] Each non-`verbatim` entry has `manual_steps`
- [x] Schema documented (header comment in `vendored.yaml` + developer README, FR/EN)

### Blocked by

VDW-001

---

## VDW-003 — `check-vendored` command

Status: ✅ done
Type: feature
Files: logic in `src/python/veaf-tools/veaf_libs/vendored_check.py` (typed + coverage-gated), thin CLI in `veaf_build/vendored_check_cli.py` (`poetry run check-vendored`), tests under `test/python/`

### What to build

A command that reads `vendored.yaml`, and for each entry applies its `watch.kind`:
- `github-release` → compare latest release tag vs `pinned`;
- `github-file` → compare the file's last commit on `ref` vs `pinned`;
- `manual` → no comparison, flagged as "re-check by hand".

Compares via the **GitHub API only** (no artifact download). Prints a report (drifted /
up-to-date / manual) and exits non-zero when any drift is found. Reusable by the VDW-004
workflow (machine-readable output, e.g. JSON, alongside the human table).

### Acceptance criteria

- [x] `poetry run check-vendored` reports drift / up-to-date / manual per artifact
- [x] Non-zero exit on any actionable finding (drift or unresolved watch)
- [x] Unit tests with a fixture manifest and **mocked** API responses (no network in tests)
- [x] No artifact is downloaded (tag/commit comparison only, via the GitHub API)

### Blocked by

VDW-002

---

## VDW-004 — scheduled workflow that opens/updates a drift issue

Status: ✅ done
Type: feature (CI)
Files: `.github/workflows/vendored-drift-watch.yml`

### What to build

A GitHub Actions workflow, `on: schedule:` (weekly cron) + `workflow_dispatch` (manual
dry-run), that runs `check-vendored` and, when drift is found, **opens or updates one
recap issue** listing:
- every drifted artifact (current pin → latest upstream), and
- every `manual` artifact to re-check by hand,
each with its `manual_steps` so the maintainer sees the real update work.

Notify only — **no auto-update / no auto-bump PR** (that is the COMMUNITY-AUTOUPDATE
vision). Idempotent: update the existing open issue rather than spawning a new one each run.

### Acceptance criteria

- [x] Weekly cron + manual `workflow_dispatch` (`.github/workflows/vendored-drift-watch.yml`)
- [x] One recap issue opened/updated on drift, listing drifts + `manual` reminders + `manual_steps`
- [x] No new issue when one is already open (matched by the `vendored-drift` label, edited in place)
- [ ] Validated by a manual dispatch dry-run — **blocked**: GitHub runs `schedule` /
      `workflow_dispatch` only from the **default branch**, which here is `master`,
      not `develop`. The workflow (and its cron) activates once `develop` is
      released to `master`. Until then the underlying `check-vendored` is validated
      directly (`poetry run check-vendored` flags the real TUM drift) and the
      issue-body rendering is unit-tested; only the `gh issue` create/update glue
      awaits the first run on `master`.

### Note (GitHub default-branch caveat)

This whole watch only fires once the workflow file reaches `master` (the repo's
GitHub default branch). It does **not** run from `develop`. No code change needed
— it activates with the next v6 release to `master`.

### Blocked by

VDW-003
