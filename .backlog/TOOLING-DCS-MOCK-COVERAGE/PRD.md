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
