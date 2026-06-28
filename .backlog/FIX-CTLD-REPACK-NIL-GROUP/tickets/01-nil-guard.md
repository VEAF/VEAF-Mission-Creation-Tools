# 01 — Nil-guard CTLD repack-radius scan + handoff analysis doc

Status: ✅ done

## Tasks

- [x] `ctld.getUnitsInRepackRadius`: guard `unitObject` / its group nil before `:getGroup():getID()`.
- [x] `ctld.isRepackableUnit`: return `nil` when `Unit.getByName` is nil.
- [x] Analysis doc for the CTLD rewrite (Fulgas):
      `docs/analysis/ctld-dynamic-slot-farp-menu-duplication.md` (mechanism, code excerpts,
      runtime log evidence, what to verify in the new version).
- [x] CHANGELOG; PATCH bump (6.7.8).
- [x] Produce a corrected `.miz` for Tripack (fix instead of the diagnostic wrapper).

## Definition of Done

- A dynamic-slot helicopter on a runtime FARP gets the CTLD F10 menu **once**, all
  options work, and no `getGroup/getTypeName (a nil value)` error in `dcs.log`.
