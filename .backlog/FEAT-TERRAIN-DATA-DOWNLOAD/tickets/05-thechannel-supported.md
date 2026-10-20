# 05 — TheChannel can be swept

Status: ✅ done

`terrain-sweep TheChannel` answered "Unsupported theatre": TheChannel had no entry in `theatre-defaults.yaml`, so no survey mission could be written, and VEAF/dcs-maps has no calibration mission for it.
Added as Falklands was (2026-10-13): map centre in the middle of its 12 airfields' extent (`airdrome-positions.yaml`, converted with the theatre's projection), bullseyes at the origin.
The survey mission loaded and the sweep covered the extent DCS gave, `-130000,-115000,75000,130000`.
