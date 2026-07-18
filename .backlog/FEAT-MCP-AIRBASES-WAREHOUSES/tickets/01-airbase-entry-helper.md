# 01 — Lazy airbase-entry helper

Status: ⬜ ready

## Goal

A pure helper that, given a loaded mission and an airfield **name**, returns (creating it lazily if
absent) the `warehouses.airports[<id>]` entry to edit — resolving the name to a numeric airdrome id
via the folder's theatre.

## Details

- Resolve `name` → id with `veaf_libs.dcs_airdromes.airdrome_id_for_name(theatre, name)`, theatre
  taken from `DcsMission.theatre_content`.
- `warehouses.airports` keys are the airdrome ids (as strings in the exploded table); create a minimal
  entry when missing (lazy) so a blank mission (`airports = {}`) works.
- Raise a clear error for an unknown airfield name / missing theatre.

## Tests

- Known name → resolves to the expected id and returns the (new) entry.
- Existing entry is returned/edited in place, not duplicated.
- Unknown name → clear error.
