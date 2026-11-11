# 02 — The eight OTs follow it

Status: ✅ done

## Done when

- Each OT's `src/presets.yaml` (`D:\dev\_VEAF\VEAF-Open-Training-Mission-*-v6`) has its `channel_lists` rewritten to PRD D1–D5; channel definitions (`channels_collection`), `fm_supplement` and the CH-47's `radio_fm_30` are not touched.
- Each diff is shown to David before the rebuild, with what was left out of each radio.
- Rebuilt (weather variants of `missions\` included where the OT has them), checked in the built `.miz`: on a blue A-10C, every airfield of the plan is on the VHF radio and every flight and asset kept is on the UHF radio, no Guard.
- No commit, no push, no deploy without David's go; deploy with `VEAF-Servers\tools\Publish-OT.ps1`, never `Update-ServerMission.ps1`.
