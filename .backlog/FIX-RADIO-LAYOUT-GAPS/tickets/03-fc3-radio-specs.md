# 03 — Cover Flaming Cliffs aircraft in the radio specs

Status: ⬜ ready
Type: fix

## Why

See the [PRD](../PRD.md), gap 3. `dcs-radio-specs.yaml` holds 87 types and **not one FC3
aircraft**. The packer projects onto physical radios read from that file, so `Su-27`, `Su-25T`,
`Su-25`, `Su-33`, `MiG-29A`, `MiG-29S`, `MiG-29G`, `J-11A`, `A-10A`, `F-15C` — and `F-14BU` —
receive **no presets at all** under the preset-plan model.

They are playable and VEAF missions put player slots on them. Measured on `Foothold_AF_2.4.1`:
converting to the plan model made **7 types lose their kneeboard plate** (F-14BU, J-11A,
MiG-29A/G/S, Su-25T, Su-27) until a legacy override layer was added back purely for them. Close
this gap and that layer disappears.

## Tasks

- [ ] Determine whether the pinned `dcs-lua-datamine` exposes FC3 radio definitions at all, or
      whether `veaf_build/radio_specs_updater.py` filters them out (e.g. on a flag separating
      full-fidelity modules).
- [ ] If the datamine has them: fix the generator, regenerate, confirm the 11 types appear.
- [ ] If it does not: add them as **hand-maintained entries** sourced from the aircraft manuals.
      The FC3 Russian fleet is mostly one `R-862` V/UHF plus an `ARK` ADF — which makes
      [ticket 01](01-adf-not-a-comm-radio.md) a prerequisite, or they all inherit the ADF bug.
- [ ] Document which entries are hand-maintained so the next regeneration does not silently drop
      them (the file is generated — a hand edit is at risk by default).
- [ ] Once covered: drop the corresponding overrides from `tools/foothold/presets.yaml` and
      rebuild.
- [ ] CHANGELOG + version bump.

## Verify

The acceptance test is the Foothold file **shrinking**: every type removed from its
`presets_assignments` must keep its kneeboard plate, with the same channels as the legacy override
produced.
