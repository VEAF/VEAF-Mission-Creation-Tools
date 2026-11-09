# 01 — The mission members in the Mission Editor's layout

Status: 🔄 in-progress

`mission_tools.dcs_lua.serialize_member(content, name)` writes a member the way the editor does, and every place that wrote `mission`, `options`, `warehouses`, `dictionary` or `mapResource` calls it: `write_miz`, `write_mission_folder`, the blank mission, the mission briefing, `add_sound`, `add_startup_script_trigger` and the briefing picture.

The `-- end of [key]` comment carries the key with its line breaks escaped: a key holding a newline would otherwise end the comment and turn the rest of the key into code DCS runs (found by the security review of the diff, 2026-11-09).

Done when: `test_dcs_lua.py` pins the layout on a nested table, an empty table, an empty member, the scalars, numeric keys and a key holding a line break, and reads every repository mission back unchanged; the tests that read the old text follow; DCS's own Lua 5.1 (`bin\luae.exe`) loads a mission written this way.
