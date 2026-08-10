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
- [x] Seeing `MiG-29 Fulcrum` leave the out-of-range report — **done 2026-08-10**, on a real
      mission rather than a Foothold folder. It did not need one: `Operation-Bluestorm-V2_Part_1`
      carries 55 `MiG-29 Fulcrum` player slots, and the local missions hold slots for all four
      affected types (835 Ka-50, 504 Ka-50_3, 437 Yak-52). Looking for the *aircraft* instead of
      the *mission* is what unblocked it.
- [x] CHANGELOG + version bump.

## Notes

Do **not** fix this with four layout entries. The classification is what is wrong, and an
airframe added by a future DCS patch with an ADF would hit it again.

## Verified end to end, 2026-08-10

`inject-presets` over `Operation-Bluestorm-V2_Part_1_20251216.miz` (302 aircraft groups) with the
shipped default plan:

```
out-of-range report mentions:
  Ka-50            no
  Ka-50_3          no
  MiG-29 Fulcrum   no
  Yak-52           no

radios the MiG-29 Fulcrum's preset ended up with: 1 -> ['radio_1']
```

One radio, not two: the R-862 V/UHF got the channel list and the ARK-19 got nothing. The specs
confirm why — ARK-22 `0.15–1.75`, ARK-19 `0.15–1.2995`, ARK-15M `0.1–1.795`, all under the 2.0 MHz
comm floor.

### And it caught a docstring the fix had made false

`pack_preset_for_type` still claimed that "single-radio HF/ADF sets, e.g. the MiG-15bis **or
Yak-52**, still get an `fm_substitute` guess". Measured per radio:

| | ranges | band |
|---|---|---|
| MiG-15bis RSI-6K | 3.75–5.0 | `None` — **still guessed**, docstring right |
| Yak-52 ARK-15M | 0.1–1.795 | `non_comm` — **no role**, docstring wrong |

The HF half was still true, which is exactly why the sentence survived the change. Corrected, with
the two cases separated.
