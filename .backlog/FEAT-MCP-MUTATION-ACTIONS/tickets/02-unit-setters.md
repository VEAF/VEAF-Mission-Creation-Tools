# 02 — Unit setters

Status: ✅ done 2026-08-12 — shipped as `set_unit_properties`, with two of this ticket's own claims corrected by measurement
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/`, mission-maker catalogue doc, `test/python/`

Depends on: 01 for the final field list; the use case below is already committed.

## The use case

> *"Change this flight's loadout to the CAS one."*

Named in the exploration note as one of the three things that ought to be possible and is not.
dcs-sms exposes 17 unit verbs; this ticket is the subset with a VEAF sentence behind it.

## Behaviour

One action mutating a named unit inside a named group, addressing it the way a mission maker does —
by name, never by index:

- **loadout** — the pylons table. The hard case, and the one worth getting right: a loadout is a
  per-airframe structure, so the action needs either a named preset or a validated pylon map, not a
  free-form dict the agent can get wrong silently.
- **skill** — the four DCS values, rejected if not one of them.
- **livery** — a string DCS does not validate; a wrong value shows a default skin with no error, so
  warn when it is not in the known set for that type rather than fail.
- **heading** — degrees in, radians out, since the mission table stores radians and this is exactly
  the trap `resolve_coordinates` hides elsewhere.
- **callsign / onboard number** — plain fields, cheap, and asked for often.

Read-before-write: the action reports the previous value in its result. An agent that cannot see
what it changed cannot tell the mission maker what it did.

## What measurement changed, against what this ticket assumed

Two of the field descriptions above were wrong, and both were caught by reading real missions rather
than by reasoning:

- **`skill` has seven values, not "the four DCS values".** `Average`, `Good`, `High`, `Excellent` and
  `Random` are AI levels — `Random` is a real one, DCS picks at mission start. `Client` and `Player`
  are **not skills at all**: they are human slots. Writing an AI level over a `Client` *deletes a
  multiplayer slot*, and writing `Client` over an AI unit *creates one* — which is the bug
  `FIX-TEMPLATE-SLOTS-VISIBLE` was opened for. Both directions are refused naming the reason, which
  is more than the ticket asked for and less dangerous than what it described.
- **`callsign` is not a "plain field, cheap".** An aircraft carries
  `{1: family, 2: flight, 3: number, name: "Colt11"}`, where `name` is the family's word followed by
  the two indices (`{1:1, 2:1, 3:2}` reads `Enfield12`, `{1:4, 2:1, 3:1}` reads `Colt11`). Writing
  `name` alone desynchronises the radio call from the editor's display. So the action edits the
  indices and **rebuilds** `name` from the word already there; changing the *family* needs DCS's
  family→word table, which this repository does not ship, and is refused unless the caller passes the
  resulting `name` too. A ground unit's callsign really is a bare number, and stays one.

And one limit the ticket asked for that **cannot** be delivered as written: "a validated pylon map".
The *shape* is validated (a station is an integer ≥ 1, and a bad key is an error rather than a
dropped key, as required) but a **CLSID cannot be checked against the airframe** — no per-type weapon
table ships with veaf-tools. DCS drops an impossible weapon silently, so the action returns that limit
as a warning instead of implying it by saying nothing. Same for the livery, as the ticket foresaw.

## Tasks

- [x] Action implemented, addressing unit by group name + unit name — by **exact** name, not a
      fragment: `describe_units` filters on one, but an edit landing on whichever group matched first
      is not recoverable.
- [x] Loadout takes a validated shape, not an arbitrary dict; a bad pylon index is an error, not a
      silently dropped key. `replace` / `merge` modes, and an empty CLSID empties a station.
- [x] Heading converts degrees → radians, with a test pinning the direction of the conversion (and
      normalising −90 onto 270).
- [x] Unknown skill rejected naming the valid values; unknown livery warns and proceeds.
- [x] Result carries the previous values, per field.
- [x] Backup-before-write, as the existing editor-parity actions do.
- [x] Mission-maker catalogue doc updated **in this ticket**, plus the developer reference — the
      `docs-check` gate turns out to enforce that second one, which is better than remembering it.

## Acceptance criteria

- [ ] 🧑 Round trip: mutate a real `.miz`, reopen it in the DCS Mission Editor, no complaint. **Not
      doable on the workstation this was written on** (no DCS installed, no `.miz` outside the
      repository's fixtures), so it is David's to do. The cheap half is covered: every test re-reads
      the written archive, so a write that no longer parses fails here.
- [x] Tests: each field, plus the rejection paths, plus "group not found" and "unit not found in
      group" naming what was looked for — 49 cases.
- [x] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.
