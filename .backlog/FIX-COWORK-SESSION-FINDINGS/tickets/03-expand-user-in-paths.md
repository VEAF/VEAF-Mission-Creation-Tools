# 03 — `~` in a mission path

Status: ⬜ ready

`describe_mission_config` with `mission_path: "~/Documents/VEAF/Missions/VEAF_Caucasus_FireAtAdler"` failed with `FileNotFoundError: [Errno 2] No such file or directory: '~\\Documents\\…'`.
No action of `veaf_mission_mcp` expands `~`.

Expand `~` once, where the actions resolve their path parameters (`mission_path`, `mission_yaml_path`, `target_folder`, `miz_path`…), not action by action.

Done when: every path parameter accepts `~`, with a test on the shared resolution and one action through it.
