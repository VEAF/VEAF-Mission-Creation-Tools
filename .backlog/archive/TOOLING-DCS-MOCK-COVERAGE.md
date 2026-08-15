# Lot TOOLING-DCS-MOCK-COVERAGE — audit DCS-mock coverage against a vendored API schema

Status: ✅ done (merged in PR #522)
Branch: `feature/dcs-mock-coverage` (one branch + one PR for the lot)

## Problem Statement

`test/lua/dcs_mocks.lua` (the DCS API stubs the Lua test suite runs against) is maintained
**by hand, reactively**: a missing mock is discovered only when a test blows up on
`attempt to call a nil value`. Nothing checks, ahead of time, that every DCS function our
runtime scripts actually call is mocked. A silently missing mock is a latent test gap.

A machine-readable description of the DCS scripting API now exists —
[`dcs-world-schema`](https://github.com/YoloWingPixie/dcs-world-schema) (YAML/JSON, MIT) —
which we can use as the reference set of DCS functions.

## Solution

Vendor the schema (pinned) and add an audit command that cross-references three sets — the
schema's DCS functions, the DCS calls actually made by `src/scripts/veaf/*.lua`, and what
`dcs_mocks.lua` defines — to report **DCS calls used by VEAF but not mocked** (the gap we
find too late today). Wire it into CI as a **non-blocking warning**.

Secondary benefit: the vendored schema doubles as a **DCS API reference** for upcoming
direct-DCS work (e.g. `veaf-dcs-bridge` / AI-GAMEMASTER), where knowing a function exists
and what it returns beats guessing.

## User Stories

1. As a contributor, I want to be told which DCS functions my scripts call that aren't
   mocked, **before** a test fails, so I can add the stub up front.
2. As a maintainer, I want a CI signal (non-blocking) flagging new mock gaps as they appear.

## Implementation Decisions

- **Presence, not signatures.** Report whether a DCS function is mocked, not whether the
  arg count/return matches. Our mocks are *behavioural* (registries, log capture) and the
  schema is *incomplete* (`params: []` on undocumented funcs like `Disposition`/cargo), so
  a signature check would be mostly false positives.
- **Filter extracted calls to schema-known DCS namespaces** (`land`, `world`, `coalition`,
  `Unit`, `Group`, `timer`, …) so VEAF/mist calls don't pollute the report.
- **Vendored schema, pinned.** `dcs-world-api-schema.json` (v0.3.5) under
  `src/python/veaf-tools/veaf_libs/data/dcs-schema/`, with the upstream MIT `LICENSE` and a
  `NOTICE` (tag, URL, fetch date) alongside. Updating it = an explicit bump commit.
- **CI as warning first** (non-blocking); a ratchet can come later.
- Report also surfaces **calls not in the schema** (typo, or genuinely undocumented like
  `Disposition`) and, optionally, **mocks never called** (cleanup) — informational.

## Testing Decisions

- The audit command is unit-tested with fixtures (a mini schema + mini mock + a sample Lua
  call site); no network, the vendored JSON is read from disk.

## Out of Scope

- **Signature/arg checking** (presence only — see above).
- **Generating mocks from the schema** — mocks are behavioural; a generator would clobber
  that logic. (At most, a future *fallback* auto-stub layer under the manual mocks.)
- **Drift-watch of the vendored schema** → handled by VENDORED-DRIFT-WATCH (it adds the
  schema as a manifest entry).
- **EmmyLua/LuaLS wiring** — captured as the optional follow-up ticket TDM-004, not
  required for this lot's core value.

---

## TDM-001 — vendor the DCS API schema (pinned)

Status: ✅ done
Type: chore
Files: `src/python/veaf-tools/veaf_libs/data/dcs-schema/` (json + LICENSE + NOTICE)

### What to build

Commit a frozen copy of `dcs-world-api-schema.json` from `dcs-world-schema` release
**v0.3.5**, with the upstream **MIT `LICENSE`** and a `NOTICE` recording the tag, source
URL, and fetch date.

### Acceptance criteria

- [x] `dcs-world-api-schema.json` (v0.3.5) committed under `veaf_libs/data/dcs-schema/`
- [x] Upstream MIT `LICENSE` + a `NOTICE` (tag / URL / fetch date) alongside
- [x] Packaged like the other `veaf_libs/data/` assets (same dir; this is a `poetry run` dev/CI tool, not bundled in the exe — consistent with `dcsUnits.yaml`, also absent from the `.spec`)

### Blocked by

—

---

## TDM-002 — `audit-dcs-mocks` coverage command

Status: ✅ done
Type: feature
Files: logic in `src/python/veaf-tools/veaf_libs/dcs_mock_audit.py` (typed + coverage-gated), thin CLI in `veaf_build/dcs_mock_audit_cli.py` (`poetry run audit-dcs-mocks`), tests under `test/python/`

### What to build

A command that builds three sets and reports the gap:
- **schema** — DCS functions parsed from the vendored `dcs-world-api-schema.json`;
- **used** — DCS calls extracted by regex from `src/scripts/veaf/*.lua`, filtered to the
  schema-known DCS namespaces (so VEAF/mist calls are excluded);
- **mocked** — functions defined in `test/lua/dcs_mocks.lua`.

Output (presence only): **used ∧ in-schema ∧ not-mocked** (the real gap), plus
informational **used ∧ not-in-schema** (typo / undocumented) and **mocked ∧ never-used**
(cleanup). Human table + machine-readable output for CI. Non-zero exit when the gap is
non-empty (CI decides whether to fail — see TDM-003).

### Acceptance criteria

- [x] Report lists DCS calls used by VEAF but not mocked
- [x] Calls filtered to schema-known DCS namespaces (no VEAF/mist false positives)
- [x] Presence only — no signature/arg comparison
- [x] Unit tests with fixtures (mini schema + mini mock + sample call site), no network

### Blocked by

TDM-001

---

## TDM-003 — CI mock-coverage job (non-blocking warning)

Status: ✅ done
Type: feature (CI)
Files: `.github/workflows/` (Lua CI or a dedicated job)

### What to build

Run `audit-dcs-mocks` in CI and surface the report as a **non-blocking warning** (the job
informs, it does not fail the build). A ratchet (fail on *new* gaps) is a later option,
not part of this ticket.

### Acceptance criteria

- [x] CI runs `audit-dcs-mocks` and publishes the gap report (`.github/workflows/dcs-mock-coverage.yml`)
- [x] Job is non-blocking (`continue-on-error: true`)
- [x] Report is visible in the run summary (`--format markdown >> $GITHUB_STEP_SUMMARY`)

### Blocked by

TDM-002

---

## TDM-004 — (optional follow-up) EmmyLua/LuaLS wiring for contributors

Status: ✅ done (delivered with the lot at David's request, though optional)
Type: feature (DX)
Files: vendored `dcs-world-api.lua` + `.luarc.json`

### What to build

For contributors who want IDE help **while writing** VEAF Lua: vendor the EmmyLua artifact
`dcs-world-api.lua` (same release as TDM-001) and add a `.luarc.json` pointing LuaLS at it,
for autocomplete + signature diagnostics in VSCode.

Not interesting for every maintainer (David: "pas pour moi, mais utile à d'autres") — hence
**optional**. The Selene artifact (`dcs-world-selene.yml`) is intentionally **not** adopted
(we already run luacheck + stylua; no third linter in CI).

### Acceptance criteria

- [x] `dcs-world-api.lua` vendored (same pinned release v0.3.5 as TDM-001)
- [x] `.luarc.json` wires LuaLS to it; documented in the developer README (FR/EN)
- [x] No CI impact (IDE-only; luacheck/stylua unchanged)

### Blocked by

TDM-001
