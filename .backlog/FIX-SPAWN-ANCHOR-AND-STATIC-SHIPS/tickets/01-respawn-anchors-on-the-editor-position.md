# 01 — A respawn puts the group back where the editor drew it

Status: ✅ done

Type: fix

## The defect

`veafCombatZone.referencePositionOf` returns the **live** position of the record's unit 1, while
`VeafGroupSpawn._drawOrigin` subtracts that unit's **editor** position. The offset is therefore the
drift accumulated since mission start, and `_spawn` applies it to every unit of the group.

Measured: drift unit 1 by 100 m, all five units of `CMBT_ABU_MUSA_AIRPORT - AAA` land 100 m out.

FIX-TRIPACK-FIELD-REPORTS ticket 04 made both ends read the same **source**. This makes them read the
same **instant**.

## The fix

Return the anchor's editor position, which is the branch the function already has as its second
fallback. The live lookup is what `_drawOrigin` then undoes, so removing it makes the offset genuinely
zero — what the docstring and the CHANGELOG have been claiming.

David's call, 2026-09-07: a zone that respawns a group puts it back where it was drawn. A convoy that
had driven off returns to its start, which is the point of resetting a zone.

## Also in this ticket, because they are the same defect's paperwork

- The docstring's *"the offset is zero by construction and no divergence is possible"* and the
  CHANGELOG's *"l'offset est zéro par construction"* were false. They become true with this fix, so
  they stay — but the reasoning has to name the instant as well as the source.
- The `DCS-SESSION-TODO.md` item for ticket 04 asks for three numbers at `debug` level. Two are logged
  at `trace`, the third at no level at all. Either the item says `trace` and gains a logged offset, or
  it is dropped as unanswerable. It is the only open item of that ticket, so leaving it as-is spends a
  DCS session for nothing.

## Definition of done

- [x] A respawned group's units land on their editor positions, whatever the anchor's live position
- [x] Test with the anchor **deliberately drifted** — the case that exposed this; it must fail against
      today's code
- [x] The existing displacement suite still passes, including `#spawnradius=0` at exactly zero
- [x] The docstring and the CHANGELOG say what the code does
- [x] The DCS-session item is executable, or removed with the reason
- [x] `stylua --check` clean; `luacheck` via CI; Lua coverage floor per the ratchet
