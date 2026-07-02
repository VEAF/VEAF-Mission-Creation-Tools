# 01 — Remove stray dumpMissionsList call from MissileGuardian init

**Status:** ✅ done

Remove `veafMissileGuardian.dumpMissionsList(veaf.config.MISSION_EXPORT_PATH)`
from `veafMissileGuardian.initialize()` — the function does not exist in the
module and raised a runtime error that aborted `veaf-config.lua`, disabling the
central F10 marker dispatcher (and CTLD/CSAR init).

Add regression test `TestVeafMGInitialize:test_initialize_no_crash` in
`test/lua/test_veafMissileGuardian.lua` (loads `veafRadio.lua`, pcalls
`initialize()`, asserts success).
