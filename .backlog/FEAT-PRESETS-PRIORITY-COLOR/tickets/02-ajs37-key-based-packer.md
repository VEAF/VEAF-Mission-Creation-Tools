# 02 — AJS-37 key-based packer + `{priority}` specials

Status: ✅ done
Depends on: 01

> Note: `test_presets_fidelity.py` / the Tripack fixture test the **convert-v5
> faithful copy** (out of scope, Q9a) — left untouched. The ADR 0003 break
> applies only to the **packer** path (`test_radio_preset_ajs37.py`,
> `test_radio_preset_full_layout_fidelity.py`), rewritten here.

## Scope

Rewrite the AJS-37 handling in the packer + `dcs-radio-layouts.yaml`:

- Key-based affine mapping into DCS Group 100–139: `primary_1` key K → Group
  100+K; `primary_2` key K → Group 120+K; `primary_2` key 20 → Group 100.
- Gaps preserved (sparse `channels` dict); keys > 20 dropped + `WARNING`.
- Specials at absolute DCS slots 41–47: S1/2/3 = priorities 1–3, E/F/G = hardcoded
  current fixture values (`33`/FM, `34`/FM, `127.5`/AM), H = priority 4.
- Extend `trailing_specials` to accept `{priority: N}` alongside `{freq, mod}`.
  Priority resolution: scan the coalition plan, band from role (primary_1→UHF,
  primary_2→VHF), AM modulation; hardcoded freq used verbatim; missing → empty
  slot; duplicate value → first + `WARNING`.
- Retire the old `fuse` + `leading_dummy` AJS-37 entry.

## Acceptance

- AJS-37 with `primary_1` keys 1–20 + `primary_2` keys 1–20: slot 1 = p2[20],
  slots 2–21 = p1[1..20], slots 22–40 = p2[1..19], slots 41–47 as above.
- Gappy plan (shipped-default sizes) leaves the right Groups empty and still lands
  specials at 41–47.
- Priorities 1–4 present → S1/2/3 + H filled from them (AM); absent → empty.

## Tests

- Rewrite `test_radio_preset_ajs37.py` to the new mapping.
- Rewrite the AJS-37 half of `test_presets_fidelity.py` and the `radioSettings.lua`
  fixture expectations (ADR 0003 iso-functionality intentionally dropped here).
