# 02 — Unit setters

Status: ⬜ ready
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

## Tasks

- [ ] Action implemented, addressing unit by group name + unit name.
- [ ] Loadout takes a validated shape, not an arbitrary dict; a bad pylon index is an error, not a
      silently dropped key.
- [ ] Heading converts degrees → radians, with a test pinning the direction of the conversion.
- [ ] Unknown skill rejected naming the four valid values; unknown livery warns and proceeds.
- [ ] Result carries the previous values.
- [ ] Backup-before-write, as the existing editor-parity actions do.
- [ ] Mission-maker catalogue doc updated **in this ticket** — an action absent from the catalogue is
      invisible to the agent that needs it.

## Acceptance criteria

- [ ] Round trip: mutate a real `.miz`, reopen it in the DCS Mission Editor, no complaint. Not
      optional — `FIX-MAPRESOURCE-KEY` is what a plausible-looking write that the editor rejects
      costs.
- [ ] Tests: each field, plus the rejection paths, plus "group not found" and "unit not found in
      group" naming what was looked for.
- [ ] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.
