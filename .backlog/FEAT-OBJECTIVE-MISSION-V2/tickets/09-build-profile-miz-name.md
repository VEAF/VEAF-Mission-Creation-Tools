# 09 — build --profile writes its own .miz

Status: ⬜ ready

`veaf-tools build --profile LOCAL_TEST` wrote the same name as the plain build: one overwrote the other. An explicit profile now suffixes the `.miz` as a build variant does (`<name>_LOCAL_TEST.miz`); `build_mission` says so.

Done when: covered by a test, and the documentation says it.
