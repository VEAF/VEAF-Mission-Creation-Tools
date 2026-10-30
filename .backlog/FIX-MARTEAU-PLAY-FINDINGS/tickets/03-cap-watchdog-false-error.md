# 03 — A shot-down CAP is no error

Status: ✅ done

`veafSpawn.startCapWatchdog` logged `CAP group <name> has no position!` as an error when the group was left with no unit — a CAP shot down, the normal end of its watch (2026-10-29 21:16:49 UTC, right after the Khalkhalah QRA MiG-23s were shot down). `veaf.getAveragePosition` answers nil only for a group with no unit, so there is no other case left for the error: the line is now debug.

Done when: the existing Lua test asserts no error is logged.
