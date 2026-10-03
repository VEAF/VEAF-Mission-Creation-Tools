# 03 — the mission's own base channel is given beside the DCS tower

Status: ⬜ ready

David, 2026-10-01: when a mission's radio plan gives an airfield its own frequency, the ATIS and the
welcome brief give **both** — the DCS tower and the mission's channel.

## Done when

- The build writes, into the mission's scripts, a table airdrome id -> the `bases` channel of the
  mission's `src/presets.yaml` that matches it: alias, title, frequencies. The match is
  `airfield_channels_manager.match_existing` (DCS name, or its first word when no other field of the
  theatre shares it), so the build and `content airfield-channels` agree on which channel is which field.
- No table, or an empty one, when the mission has no `bases` collection — the welcome brief and the ATIS
  then say only the DCS tower, as in ticket 02.
- When the mission's channel has the same frequencies as the DCS tower, one line, not two.
- When it differs, the pilot reads both, the mission's named as their preset (`Base-Batumi`, its title),
  e.g. `Tower 260.000 UHF / 131.000 VHF — mission channel Base-Batumi: 270.300 UHF / 130.300 VHF`.
- Tested on the mocks (same, different, absent), and once in DCS on a copy of Open Training Caucasus v6
  before its base channels are corrected — the case the decision was made for.
