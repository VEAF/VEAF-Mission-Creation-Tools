# FEAT-EXPORT-BFR-PARSER-001 — JSON export contract spec (deliverable for Dup)

Status: 🧑 waiting-human
Type: docs
Files: `doc/developer/export-json-contract.md`, `doc/developer/export-json-contract.en.md`

## What to build

A frozen, documented contract for the `veaf-tools export --format json` output, so the BFR
plugin can decode it back to Lua tables that reproduce today's `load()` output table-for-table.

Must specify:

- Top-level shape: `{ schemaVersion, theatre, mission, dictionary, mapResource }`.
- Deterministic **array/object rule**: a Lua table is a JSON **array** iff its keys are exactly
  the contiguous integers `1..n` (n ≥ 1); everything else is a JSON **object** with string keys.
- **Empty** table handling and why it is parity-neutral after decoding.
- **Sparse** (`{[2]=,[5]=}`) and **mixed** (int + string keys) tables → JSON object.
- **JSON→Lua decoder requirements** (plugin side): coerce canonical integer-string keys back to
  Lua integer keys; arrays → 1..n sequences; empty array/object → empty Lua table.
- **Parity guarantee** and the **`schemaVersion` bump policy** (breaking change ⇒ bump).

## Acceptance criteria

- [ ] `doc/developer/export-json-contract.md` written, with worked examples (trigrules, sparse).
- [ ] `.en.md` mirror.
- [ ] Linked from the lot PRD; handed to Dup for validation before plugin work.

## Notes

This ticket is the **pivot**: the normalizer (002) and parity gate (005) implement and verify
exactly this contract. Validate the contract with Dup before coding 002–005.
