# FEAT-DCS-EDITOR-LUA-LAYOUT — a built mission written like the Mission Editor writes it, and your own steps after the build

Status: ✅ done (#1251)

Origin: two points Flogas raised on 2026-11-09, relayed by David the same day, who chose 1a and 2a.

1. A mission built by VMCT v6 does not look like one the Mission Editor saved. The `mission` file reads `coalition = {` with two-space indentation where the editor writes `["coalition"] = ` then `{` on its own line, with tabs and `-- end of ["coalition"]`. DCS reads both, but tools outside VEAF that read a mission's text expect the editor's layout.
2. In v5 the mission maker owned `build.cmd` and added steps to it; in v6 there is no script to add to. The steps Flogas wants: inject or change non-VEAF triggers depending on a release or a test build.

## Measured

The editor's layout, read on a mission it saved on 2026-11-09: LF line endings, a tab per level, every key in brackets (`["name"]`, `[1]`), `["key"] = ` followed by `{` on the next line for a non-empty table, `["key"] = {},` for an empty one, `}, -- end of ["key"]` after each table, `} -- end of mission` to close, and `mapResource = {}` on one line when empty. Floats carry 14 significant digits; a whole number is written without a decimal part. Same layout in `options`, `warehouses`, `dictionary` and `mapResource`.

## Decided

- **One serializer for every member VEAF writes** (`mission_tools.dcs_lua.serialize_member`), replacing the ten `luadata.serialize` calls that wrote `mission`, `options`, `warehouses`, `dictionary` and `mapResource` into a `.miz` or a mission folder.
- **The key order stays VEAF's** (`luadata`'s sort): the editor writes hash order, which changes from one save to the next, so no tool can rely on it, and a fixed order keeps a mission folder's diffs readable.
- **Floats keep Python's exact form** rather than the editor's 14 digits: rounding would change the values VEAF writes, for no tool's benefit. A whole number loses its `.0`, as in the editor.
- **No build hook**: a mission maker's own steps go in a script of their own that runs the build with a profile and then works on the `.miz` it wrote. A hook in `mission.yaml` would run a command written in a mission file, which a mission fetched from elsewhere should not do.

## Tickets

- [01 — The mission members in the Mission Editor's layout](tickets/01-editor-lua-layout.md)
- [02 — Your own steps after the build, documented](tickets/02-post-build-steps-doc.md)
