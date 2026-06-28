# 01 — Nil-guard CTLD repack-radius scan + handoff analysis doc

Status: ✅ done

## Tasks

- [x] `ctld.getUnitsInRepackRadius`: guard `unitObject` / its group nil before `:getGroup():getID()`.
- [x] `ctld.isRepackableUnit`: return `nil` when `Unit.getByName` is nil.
- [x] Standalone analysis delivered for the CTLD rewrite (handed off, not committed).
- [x] CHANGELOG; PATCH bump.
- [x] Produce a corrected `.miz` for Tripack (fix instead of the diagnostic wrapper).

## Definition of Done

- A dynamic-slot helicopter on a runtime FARP gets the CTLD F10 menu **once**, all
  options work, and no `getGroup/getTypeName (a nil value)` error in `dcs.log`.
