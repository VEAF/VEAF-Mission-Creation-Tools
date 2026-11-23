# 01 — Skynet set-up warnings off the players' screens

Status: ⬜ ready

Issue: [#1296](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1296).

Skynet prints its set-up warnings ("WARNING: ..." for a missing group, among others) to every player for 4 s, through `trigger.action.outText`.
On a PvE server, a red site's name lands on the blue players' screens.

- New key `SKYNET.setup_warnings_on_screen`, default `false`.
- The VEAF helper that creates the IADS sets `iads:getDebugSettings()`'s logger `debugOutput.warnings` (or the equivalent field of the created logger) to the key's value right after the creation, before any site is added.
- The warnings stay in `dcs.log` whatever the key.
- Do not edit `skynet-iads-compiled.lua`: it is a build artefact of VEAF/Skynet-IADS. If the field cannot be reached from the helper, the change goes upstream and this ticket waits for it.

Tests: a Lua test with the Skynet mocks — key absent → a set-up warning reaches no `outText`; key `true` → it does; in both cases it reaches the log.

Done when: the tests pass, the key is in `doc/MISSION_YAML_REFERENCE.md` (FR and EN) and in the default `mission.yaml` comment of the SKYNET block (§9 item 7 lockstep), and the CHANGELOG says the default changed.
