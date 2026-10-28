# D1 — A spawned group's zone, even with nothing after its marker

Status: ✅ done

`veaf_libs/dcs_recon.py` `zone_of` cut a group name at ` [r] ` with a trailing space only: `Sasa [r]` (no name after the marker) was its own zone, `briefing_sidecar` wrote it, and the briefing dropped the photos of Sa'sa' and Kiswah ("zone 'Sasa [r]' is no objective").

Done when: covered by a test, and the documentation says it.
