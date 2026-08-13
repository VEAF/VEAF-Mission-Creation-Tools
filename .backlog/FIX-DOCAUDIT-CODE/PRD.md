# FIX-DOCAUDIT-CODE — the code bugs the documentation audit surfaced

Status: ✅ done — 2026-08-13, all six tickets

Origin: the 2026-08-13 five-pass documentation audit. Cross-checking pages against code found
defects in the **code** — including one that inverts a decision David took, and two blind spots in
the `docs-check` gate itself, proven by the defects that survived it.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Tier names: the dispatchers refuse the decided vocabulary](tickets/01-tier-names.md) | ✅ |
| 02 | [`_transport` demands the password from everyone](tickets/02-transport-markid.md) | ✅ |
| 03 | [Small dead ends: fog constant, stale CLI help](tickets/03-small-dead-ends.md) | ✅ |
| 04 | [Harden the two `docs-check` blind spots](tickets/04-docs-check-blind-spots.md) | ✅ |
| 05 | [The generated mission.yaml repeats the security lie](tickets/05-generated-yaml-comment.md) | ✅ |
| 06 | [The radio-specs generator writes engine types as aircraft names](tickets/06-radio-specs-display-name.md) | ✅ |

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

## What measurement changed, and the decisions taken alone

Recorded so a reviewer can overturn them rather than discover them.

- **Ticket 06's two proposed fixes were both wrong**, and one would have made the page worse.
  "Anchor at column 0" finds nothing at all — a datamine dump is one table indented by a tab —
  and `username` holds the DCS id, so preferring it produces exactly the "repeats the DCS id"
  symptom the ticket complains about. The field that works is `DisplayName`, measured present in
  all 170 unit files at the pinned ref. Ticket 01's `ADMIN ≡ L9` example was backwards too:
  `ADMIN` is the tightest tier and maps to `L0`.
- **Ticket 06's scope was wider than written.** The defect was described as a generated-page bug;
  `dcs-radio-specs.yaml` — the artifact the presets injector actually loads — carried the same 48
  wrong names.
- **VEAF's own 24 handler declarations were migrated to the new tier names** (ticket 01), which the
  ticket did not ask for. Left alone, our own modules would raise the deprecation notice that
  exists to warn a *mission maker*, making the signal unusable. The player-facing "give the L1
  password" messages are untouched: they name the configured password, not the tier.
- **Ticket 04's option rule is enabled for the updater only.** The mission-maker guide names 4 of
  the main CLI's 59 long options, because it is a guide and not a reference: pointing the rule
  there would report 110 defects on a page that is not the right place to fix them. The full CLI
  reference is `DOC-AUDIT-FIXES` ticket 04, and enabling the rule for it is one tuple entry —
  which is the "land with or before" this ticket asked for.

## Left armed, and stated rather than fixed

`radio_specs_updater.OUTPUT_MD` points at the **French** page, so `update-dcs-data --radio`
replaces hand-written French prose with a generated English page. This lot worked around it by
merging only the changed column, as ticket 06 instructed. The trap fires again at the next pin
bump. Fixing it properly means teaching the generator to emit both languages, or to write only the
table — a lot of its own, not a line of this one.

## Still parked, unchanged

The two observations above the Definition of Done both need a DCS session and neither was touched:
the three `USAGE_ForAll` secured commands that `veafRadio._proxyMethod` may refuse outright, and
`FARP_T` missing from the types `buildFarpsUnits` accepts.
