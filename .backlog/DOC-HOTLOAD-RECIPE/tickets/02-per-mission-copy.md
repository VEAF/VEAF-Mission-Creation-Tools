# 02 — Rewrite the page for one copy per mission, fix the profile example

Status: ✅ done

Rewrite `doc/developer/hotload.md` and `hotload.en.md` to follow dcs-hotload's own model, as its author Flogas proposed on 2026-11-11: one copy of hotload in the mission folder, booted by the `custom_scripts` boot script from `VEAF_DYNAMIC_MISSIONPATH`, with no VMCT code.
And fix the `FgDebug.lua` example of `doc/MISSION_YAML_REFERENCE.md` (+ `.en.md`), which claimed a script declared only in a profile stays out of the default build.

## Done when

- Install: the release zip extracted into the mission folder, `dcs-hotload\` next to `mission.yaml`, and `user-f10\` (and the mailbox folders) created in it.
- Unlock: `hotload-setup.py unlock --dcs`, with the install-wide security warning kept.
- `status`: what it reports on a VMCT mission (`--miz <name>_<date>.miz`, the build dates its output in the mission folder), and that it cannot see our boot script, measured on a built `.miz`; `patch-miz` is not to be run.
- The boot script builds the copy's path from `VEAF_DYNAMIC_MISSIONPATH`, with or without a trailing `/` or `\`, sets `Hotload.root` to it, loads `dcs-hotload.lua`, and leaves nothing on screen when it fails: a `HOTLOAD: not booted:` line in `dcs.log`, as hotload's own trigger guard writes. The page says hotload runs in a dynamic build only, with nothing to remove from a static one. The `PER_MISSION` toggle and its section are gone.
- Load order, the no-reload rule for VEAF modules and the ten-entry F10 root are kept.
- The boot script, extracted from each page, runs under `C:\jeux\DCS World\bin\luae.exe` with the real `dcs-hotload.lua` 3.1.0: variable ending with `/`, `\` or neither, variable nil or empty, no `dcs-hotload\` folder, `io`/`lfs` locked in a static and a dynamic build, a raising `dcs-hotload.lua`, and no `user-f10\`; the "what was checked" table gives those cases.
- The `FgDebug.lua` example declares it in the base with `generate_load_trigger: false` and in the profile without; a real build of a test mission shows it loaded with `--profile DEV` only, in both the static triggers and the generated `veafDynamicConfig.lua`.
- `poetry run docs-check` and `test_backlog_status_consistency` pass.
