# 02 — A shorter catalogue, limitations listing, file slice and build log

Status: ✅ done

- `list_catalog` summaries cut at 100 characters (14 102 → about 10 000); `full=true` pages by `offset` under the ceiling.
- `describe_known_limitations` without `id`: the ids grouped by area (13 008 → about 4 700); `id`/`ids` unchanged.
- `read_mission_file` stops at 8 000 characters as well as at its line count; `last_line` says where to go on.
- `build_mission` returns its counters, warnings and the end of its log; the whole log is written to the mission folder.
