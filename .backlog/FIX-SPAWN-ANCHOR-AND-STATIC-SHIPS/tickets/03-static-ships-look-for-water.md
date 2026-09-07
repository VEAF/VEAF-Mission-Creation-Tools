# 03 — A ship placed as scenery looks for water

Status: ✅ done

Type: fix

## The defect

Ticket 02 narrows the spawn-point search to water when the zone element's category is `ship`. That
category is the **mission-table section** the group was read from, so a ship placed as a *static
object* lives under `static` and keeps the land-only search: it is dragged onto dry land exactly as
before the fix.

And the silent half: the spawner's own terrain check resolves `static` to `ANY_TERRAIN`, which accepts
`LAND`, so the hull is created on the quay with **no error at all**. The group case failed loudly,
which is the only reason the defect was ever found.

## The data is already there

A static unit carries its own DCS sub-type. Measured on Tripack's mission:

| `category` on the static unit | count |
|---|---|
| `Heliports` | 55 |
| `Fortifications` | 48 |
| `Cargos` | 1 |
| `Helicopters` | 1 |

A static ship would be `Ships`. What hides it is `veafMissionDb.unitRecord`, which writes
`category = context.category` — the section name, `"static"` — over the unit's own sub-type.

So: carry the static's sub-type in the record under its own key, and let the surface decision read it.
Do not overload `category`, which every existing caller reads as the section.

Nobody is affected today — 103 statics in Tripack's mission, no ship — so this is prevention, and it
should not cost more than the data it already has.

## Definition of done

- [x] A static whose sub-type is `Ships`, in a combat zone with a spawn radius, searches on water
- [x] ~~Its terrain validation accepts water and refuses dry land~~ — **dropped deliberately, see
      below.** Fixing the *search* is enough: the hull is never offered the quay, so the validation has
      nothing left to refuse. Verified: the whole suite passes without touching it.
- [x] Every other static — `Fortifications`, `Heliports`, `Cargos` — is unchanged, asserted
- [x] The static's sub-type reaches the record without overloading `category`
- [x] `stylua --check` clean; `luacheck` via CI; Lua coverage floor per the ratchet

## One half of this ticket was written and then removed

The first implementation also handed the water surfaces to the spawn's own terrain check, so that the
validation would refuse dry land instead of accepting any surface. It worked, and it was taken back
out on re-reading the diff.

The defect needs two steps: the search drags the hull onto the quay, *then* the check accepts it. Fix
the first and the second has nothing to do — the suite proves it, passing unchanged with the
validation left alone.

And tightening the validation carries a risk the search fix does not: a mission maker who has
**deliberately** put a `Ships` static on land — a wreck aground on a beach, a hulk in a scrapyard —
would have had it refused outright, which is the very symptom this lot exists to remove, inverted.
Smaller change, no new way to fail.
