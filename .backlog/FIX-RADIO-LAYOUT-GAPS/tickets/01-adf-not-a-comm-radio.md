# 01 — Never assign a comm role to a radio-compass (ADF)

Status: ✅ done
Type: fix

## Why

See the [PRD](../PRD.md), gap 1. `_assign_roles_by_position` classifies each physical radio from
its frequency ranges; a radio whose ranges all sit **below the V/UHF floor** is an ADF or an HF
set, not a comm radio, but it currently attracts the FM role and receives a full channel list.

Four types affected today (`Ka-50`, `Ka-50_3`, `MiG-29 Fulcrum`, `Yak-52`), none with an explicit
layout entry — so the fix belongs in the **default classification**, not in per-type data.

## Tasks

- [x] `_classify_radio` returns a new `"non_comm"` band when **every** range sits below
      `_COMM_FLOOR_MHZ = 2.0`. No existing constant fitted: `FIX-DYNSLOT-RADIO-UNITS` reasons about
      a *primary frequency* against a VHF floor, which is a different question from classifying a
      whole radio, so reusing it would have coupled two unrelated rules.
- [x] Such a radio gets **no role**. The change turned out to be one branch: the role groups are
      built by filtering on `band is None`, and `"non_comm"` is not `None`, so these radios fall
      out of every group by construction rather than by a second exclusion rule.
- [x] 9 tests, written first and confirmed failing. Real ranges from `dcs-radio-specs.yaml` for
      the ARK-22, ARK-19 and ARK-15M, plus **two guard tests** that a genuine FM set still attracts
      the FM role and a V/UHF radio is untouched — the risk of this fix is over-reach, not under.
- [x] No drift reported: the full `presets_injector` suite (252 tests) is green, including the
      radio-count cross-check.
- [ ] Rebuilding a Foothold mission to see `MiG-29 Fulcrum` leave the out-of-range report — not
      done, it needs a Foothold mission folder that is not in this repository. The unit tests
      assert the behaviour the report reflects.
- [x] CHANGELOG + version bump.

## Notes

Do **not** fix this with four layout entries. The classification is what is wrong, and an
airframe added by a future DCS patch with an ADF would hit it again.
