# 10 — describe_module knows the community modules

Status: ✅ done

`describe_module CTLD` answered unknown: only the VEAF Lua modules were looked up. The community scripts (CTLD, CSAR, AIEN, SKYNET, STTS, TUM, MIST) are known too, with their page.

Done when: covered by a test, and the documentation says it.

## Result

`kind: community` for CTLD, CSAR, AIEN, STTS, TUM, MIST (SKYNET is a VEAF module already). Tests in `test_oracle.py`.
