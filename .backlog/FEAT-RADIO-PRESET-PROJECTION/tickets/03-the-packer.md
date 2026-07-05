# FEAT-RADIO-PRESET-PROJECTION-03 — the packer (projection)

Status: ⬜ ready
Type: feat
Phase: 1
Files: `presets_injector/` (new packer module), `test/python/presets_injector/`

## What to build

The packer: given the parsed `channel_lists` (per coalition), the `Radio layout`
(or band-based default), and the specs, produce a `PresetDefinition` per
(coalition, type). Apply the layout primitives in order:

1. resolve each physical radio's role → take that role's channel list;
2. reserved head slots (default fill = list's last entry);
3. channel-0 rotation (last entry to head);
4. radio fusion (concatenate the mapped lists into one physical radio);
5. trailing hardcoded specials (freq + mod);
6. per-channel modulation;
7. truncate to slot capacity when set (recorded for reporting).

Output must be a `PresetDefinition` so the existing injector / band validation /
kneeboard generation are reused unchanged (generator overlay, ADR 0010).

## Acceptance criteria

- [ ] Standard 1:1 aircraft: role lists map straight onto physical radios.
- [ ] Mi-24P: channel-0 rotation reproduced.
- [ ] OH-58D: reserved "M"/"C" head slots filled; `fm_secondary` default applied.
- [ ] AJS-37: two V/UHF lists fused into one radio, leading dummy + hardcoded
      specials + modulations preserved.
- [ ] Warbirds: single radio packed on `primary_2`.
- [ ] Over-capacity list truncated + recorded (validate verbose / build silent).
- [ ] Output is a `PresetDefinition`; downstream injection untouched.
- [ ] Unit tests (prior art: `test_presets_fidelity.py`).

## Blocked by

Tickets 01 (channel_lists) and 02 (layout).
