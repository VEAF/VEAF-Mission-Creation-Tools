# 04 — The Lua files in your mission folder

Status: ✅ done

Type: docs · Files: `doc/mission-maker/build-messages/lua-files.md` + `.en.md`

## What it is

The family born of a real report: Tripack, 2026-09-03, building `Snowfox_20260903.miz`
(`FIX-EXTRACT-GENERATED-ARTIFACTS`). The build finds a `.lua` in `src/scripts/` it did not expect
and says so — and the reader cannot tell from the message whether they broke something.

Messages: `builder.unexpected_lua_file`, `builder.generated_artifact_in_sources`,
`builder.generated_artifact_spawn_data_hint`, `builder.custom_loader_hint`,
`builder.custom_lua_included`, `builder.mist_injected_for_custom_scripts`,
`validate.custom_script_missing`.

## What it has to carry, beyond the message text

- **The three kinds of Lua file** the build distinguishes in `src/scripts/`: the ones it expects,
  the ones you declared in `custom_scripts:`, and the ones it generated itself. Each message maps
  to one of the three, and the right action differs.
- **Where a generated artifact comes from** — an extraction of an already-built mission handing the
  build its own output back — and why declaring it in `custom_scripts:` is the one thing not to do.
- **The v5 residue case.** A script that loads other scripts is a v5 loader; v6 wants
  `custom_scripts:` instead.
- **What it is not.** None of these stop the build, and none of them mean a file was lost.

## Definition of done

- [x] Both languages, in the `nav` with `nav_translations`
- [x] One explicit anchor per message, derived from its locale key
- [x] The list of expected file names matches `_EXPECTED_SCRIPTS` and `GENERATED_LUA_ARTIFACTS`
- [x] Links to the existing custom-scripts card rather than re-teaching it
- [x] `poetry run docs-check` passes
