# 01 — Join the reference database and the dumps on the airdrome id, and capture GermanyCW again

Status: ✅ done
Type: feature
Files: `veaf_build/dcs_data/airdromes.py`, `veaf_build/dcs_data/airbase_dumps/GermanyCW.json`, `veaf_build/dcs_data/airbase_dumps/parking/GermanyCW.json`, `veaf_libs/data/{airdromes.yaml,airdrome-positions.yaml,parking/GermanyCW.json,known-limitations.yaml}`, `doc/developer/{dcs-data,capture-airbases}{,.en}.md`, `test/python/veaf_build/test_dcs_data_airdromes.py`, `test/python/veaf_libs/test_parking_captures_2026_10_22.py`

`_union_sources` keeps the reference's records and adds a dump's records whose id the reference lacks; `generate` uses it for both the table and the positions.
Tests: a dump adds the ids the reference lacks, with its own positions; a dump never adds a second name for an id the reference knows; the recaptured GermanyCW holds 247 airfields and 8 028 stands, and Stuttgart (138, new in DCS 2.9.32) resolves and has stands.
