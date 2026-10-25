# 03 — `~` in a mission path

Status: ✅ done

`describe_mission_config` with `mission_path: "~/Documents/VEAF/Missions/VEAF_Caucasus_FireAtAdler"` failed with `FileNotFoundError: [Errno 2] No such file or directory: '~\\Documents\\…'`.
No action of `veaf_mission_mcp` expands `~`.

Expand `~` once, where the actions resolve their path parameters (`mission_path`, `mission_yaml_path`, `target_folder`, `miz_path`…), not action by action.

Done when: every path parameter accepts `~`, with a test on the shared resolution and one action through it.

## Result

Fix: `ActionCatalog.run_action` expands a leading `~` in every top-level parameter whose name ends in `path`, `folder` or `target`, before anything else reads it.
Test: `test_a_tilde_in_a_path_is_expanded`, four parameter names, and a text parameter left alone.
