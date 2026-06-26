# FEAT-EXPORT-BFR-PARSER-005 — parity gate (round-trip, sparse case)

Status: ⬜ ready
Type: test
Files: `test/python/`

## What to build

A non-regression test proving the exported object reproduces, table-for-table (array-ness +
key types), what the plugin's `load()` produces today — the validation criterion #1.

Must include the **sparse table** case: a group/zone deleted in the editor leaves `{[2]=,[5]=}`,
which must export as a JSON object with string keys (and, per the contract, the plugin decoder
coerces them back to integer keys).

## Acceptance criteria

- [ ] Contiguous numerically-indexed tables export as arrays.
- [ ] Sparse table exports as object with string keys; documented as decoder-coerced on the plugin side.
- [ ] Test reads from a real mission fixture (or a crafted sparse fixture).
- [ ] Coverage gate bumped.

## Blocked by

FEAT-EXPORT-BFR-PARSER-002.
