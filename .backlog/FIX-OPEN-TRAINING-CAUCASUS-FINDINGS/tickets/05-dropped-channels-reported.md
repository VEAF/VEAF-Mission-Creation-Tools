# 05 — A channel the presets injector drops is reported

Status: ⬜ ready

Files: `presets_injector/presets_manager.py`, `presets_injector/presets_injector_worker.py`, the validator, translations, tests.

## What happened

Found recompiling the Syria Open Training v6 in 6.29.0 on 2026-10-10.
Its `src/presets.yaml` put three UHF-only channels on the blue `primary_2` list: S-3B Stennis 295.0, S-3B Roosevelt 296.0, Darkstar 1 283.0.
`primary_2` resolves to VHF (`freq_alias.py` `_ROLE_BAND`, `presets_manager.py` `ROLE_BANDS`), so `_build_role_list` skipped the three channels: no aircraft of the built `.miz` carried those frequencies, and channels 12-14 of radio 2 were empty.
The skipped names are collected (`parse_channel_lists` returns them, `PresetsManager.channel_lists_dropped` keeps them, line 1795 on `develop` 0d4c436a), but nothing reads that attribute: `mission validate` and `mission build` were silent, and the mission's README advertised the three channels to the pilots for eight days.
The 6.29 support-gap check (`_find_support_gaps`, #1111) is what finally showed it, and only because the three channels happened to be an AWACS and two tankers; a dropped airfield or flight channel would still go unseen.

The mission was fixed by hand: the three frequencies moved to `primary_1`, three airfields to `primary_2` with their VHF tower frequency.

## Done when

- `mission build` prints one warning per dropped channel, naming the coalition, the list, the channel key and its name, and the band it lacks; the presets validation report lists them too.
- `mission validate` gives the same warning without building.
- Tests: a UHF-only channel on `primary_2` gives the warning; a channel carrying both bands gives none.
