# 01 — Never assign a comm role to a radio-compass (ADF)

Status: ⬜ ready
Type: fix

## Why

See the [PRD](../PRD.md), gap 1. `_assign_roles_by_position` classifies each physical radio from
its frequency ranges; a radio whose ranges all sit **below the V/UHF floor** is an ADF or an HF
set, not a comm radio, but it currently attracts the FM role and receives a full channel list.

Four types affected today (`Ka-50`, `Ka-50_3`, `MiG-29 Fulcrum`, `Yak-52`), none with an explicit
layout entry — so the fix belongs in the **default classification**, not in per-type data.

## Tasks

- [ ] In the default role assignment, exclude any radio whose every range sits below a comm floor
      (2 MHz separates an ADF from the 20 MHz FM bottom cleanly; `FIX-DYNSLOT-RADIO-UNITS` already
      reasons about a VHF floor — reuse its constant if there is one).
- [ ] Such a radio gets **no role**: no channels projected, no kneeboard column.
- [ ] Unit test per affected type: the `Ka-50`'s `ARK-22` and the `MiG-29 Fulcrum`'s `ARK-19` get
      no channel list, while radio 1 keeps its role.
- [ ] Check the radio-count guard (the packer cross-checks the layout's radio count against the
      specs) does not now report these types as drift.
- [ ] Rebuild a Foothold mission and confirm `MiG-29 Fulcrum` leaves the out-of-range report.
- [ ] CHANGELOG + version bump.

## Notes

Do **not** fix this with four layout entries. The classification is what is wrong, and an
airframe added by a future DCS patch with an ADF would hit it again.
