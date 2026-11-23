# 04 — `validate` and `build` check the syntax of `custom_scripts`

Status: ✅ done

Issue: [#1303](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1303).

`check_lua_syntax` runs on `veaf-config.lua` only (`lua_config_generator.py:2626`).
A syntax error in a `custom_scripts` file goes into the `.miz` unseen, and shows up as a script that silently does not load in DCS.

- Call `check_lua_syntax` on every file listed in `custom_scripts`, in `mission validate` and in `mission build`.
- A syntax error is a blocking error naming the file and the line, as for `veaf-config.lua`.

Tests: a mission whose `custom_scripts` lists a file with a syntax error → `validate` and `build` fail and name it; a valid file → unchanged.

Done when: the tests pass and the `custom_scripts` section of `doc/MISSION_YAML_REFERENCE.md` (FR and EN) says the files are checked.
