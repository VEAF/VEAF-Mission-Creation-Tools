# 03 — Five more maps ship their parking

Status: ✅ done

Asked by David after ticket 02, 2026-10-22: the maps he owns with no parking capture got one, for 6.31.3.

One blank mission per map (`scaffold_mission` minimal, `dcs_bridge` enabled, built), loaded in DCS by David one after the other; `veaf-tools capture-map --parking` run against each through `dcs-serve`; the dumps slimmed by `veaf-build update-dcs-data --parking`.

| Map | Airfields with stands | Stands |
|---|---|---|
| Afghanistan | 26 of 29 | 1 435 |
| GermanyCW | 227 | 7 035 |
| MarianaIslands | 8 | 282 |
| MarianaIslandsWWII | 11 | 534 |
| TheChannel | 12 | 616 |

Measured after the slimming: `add_air_group` with `start: parking-cold` places a flight on a stand on each of the five (Ramstein, Manston, Bagram, Andersen AFB, Agana).
Iraq, Kola and Nevada remain without a capture: nobody who captures owns them.

Done when: `test_parking_captures_2026_10_22.py` holds the counts above, the limitation `ai-ground-start-needs-a-parking-capture` names the three maps left, and the pages that listed the parking maps (`PIPELINE_REFERENCE`, `concepts/dynamic-slots`, both languages) are up to date.
