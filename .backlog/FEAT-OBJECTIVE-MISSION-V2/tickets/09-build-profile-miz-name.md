# 09 — build --profile writes its own .miz

Status: ✅ done

`veaf-tools build --profile LOCAL_TEST` wrote the same name as the plain build: one overwrote the other. An explicit profile now suffixes the `.miz` as a build variant does (`<name>_LOCAL_TEST.miz`); `build_mission` says so.

Done when: covered by a test, and the documentation says it.

## Result

`_build_plan` suffixes an explicit profile; `find_built_mission` passes over a profile's archive while the plain one exists. Tests in `test_build_pipeline.py`, `test_campaign_mission_picture.py`.
