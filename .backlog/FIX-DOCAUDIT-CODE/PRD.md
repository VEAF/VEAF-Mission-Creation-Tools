# FIX-DOCAUDIT-CODE — the code bugs the documentation audit surfaced

Status: ⬜ ready

Origin: the 2026-08-13 five-pass documentation audit. Cross-checking pages against code found
defects in the **code** — including one that inverts a decision David took, and two blind spots in
the `docs-check` gate itself, proven by the defects that survived it.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Tier names: the dispatchers refuse the decided vocabulary](tickets/01-tier-names.md) | ⬜ |
| 02 | [`_transport` demands the password from everyone](tickets/02-transport-markid.md) | ⬜ |
| 03 | [Small dead ends: fog constant, stale CLI help](tickets/03-small-dead-ends.md) | ⬜ |
| 04 | [Harden the two `docs-check` blind spots](tickets/04-docs-check-blind-spots.md) | ⬜ |
| 05 | [The generated mission.yaml repeats the security lie](tickets/05-generated-yaml-comment.md) | ⬜ |

One branch, one PR. TDD throughout — each fix gets its failing test first.

## Sequencing note

Ticket 04 must land **before or with** `DOC-AUDIT-FIXES` 03/04: the hardened gate is what makes the
new CLI reference self-enforcing, and the anchor rule will catch the five dead anchors if the doc PR
has not fixed them yet (fine — CI red points at real defects).

## Observations parked here, not scoped (verify before acting)

- `veafCombatZone.lua:1423,1469` and `veafAssets.lua:58` register secured commands with
  `USAGE_ForAll`, but `veafRadio._proxyMethod` refuses a secured command with no `groupId`
  (`veafRadio.lua:291-295`) — worth a runtime probe: do those three entries work at all?
- `veafGrass.lua:241,1082,1200` omit `FARP_T` from the types `buildFarpsUnits` accepts (`:210`) —
  a `FARP_T` gets scenery but no warehouse fill. Needs a DCS check before calling it a bug.

## Definition of Done

- Lua: `test-lua` + stylua green; Python: full gate green, coverage ratchet respected.
- The doc claims that depended on these fixes become true (cross-check `DOC-AUDIT-FIXES` 01).
