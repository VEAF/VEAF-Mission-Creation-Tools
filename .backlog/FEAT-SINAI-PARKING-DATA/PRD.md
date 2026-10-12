# FEAT-SINAI-PARKING-DATA — parking data for Sinai

Status: ✅ done

Asked by David on 2026-10-12, while building the Sinai Open Training v6.
Sinai shipped no parking capture, so `add_air_group` refused every ramp and runway start there and `create_qra` put its interceptors in the air (`no-parking-data-outside-three-theatres`).

Captured in DCS on 2026-10-12 with `veaf-tools dcs capture-map --parking` on the empty survey mission of `terrain-sweep SinaiMap`: 3 614 stands on 56 airfields.
The raw dump goes to `veaf_build/dcs_data/airbase_dumps/parking/SinaiMap.json`, slimmed by `veaf_build.dcs_data.parking.slim_dump` into `src/python/veaf-tools/veaf_libs/data/parking/SinaiMap.json`.

Checked: the Sinai Open Training v6 placed its four QRA (16 groups) on the runway and a client A-10C II on stand 13 of Cairo West through the MCP, and its test mission loaded in DCS.

Also: the known limitation and the parking reach in `dynamic-slots` and `PIPELINE_REFERENCE` (FR and EN) now name Sinai; the build's dynamic-slot warehouses filter Sinai airfields by their parking from now on.
