# 04 — smoke-test over the bridge only

Status: 🔄 in progress

Every check rides the bridge: it runs in the mission scripting state, which has DCS's own globals (`Disposition`, `missionCommands`, `coalition`) as well as `veaf`.
The hook probe, `--probe-only`, and the unattended `--full` lifecycle (`dcs_lifecycle.py`: launch DCS, `net.load_mission`, `exitProcess`) go: David launches DCS and loads the mission himself, and `net.load_mission` does nothing in single player.

Done when: `dcs_smoke` has no hook path left and its tests pass.
