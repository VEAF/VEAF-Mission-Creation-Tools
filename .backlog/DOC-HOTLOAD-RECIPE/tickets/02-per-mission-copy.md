# 02 — Rewrite the page for one copy per mission

Status: ✅ done

Rewrite `doc/developer/hotload.md` and `hotload.en.md` to follow dcs-hotload's own model, as its author Flogas proposed on 2026-11-11: one copy of hotload in the mission folder, booted by the `custom_scripts` boot script, with no VMCT code.

## Done when

- Install: the release zip extracted into the mission folder, `dcs-hotload\` next to `mission.yaml`, and `user-f10\` (and the mailbox folders) created in it.
- Unlock: `hotload-setup.py unlock --dcs`, with the install-wide security warning kept.
- `status`: what it reports on a VMCT mission (`--miz build\...`), and that it cannot see our boot script, measured on a built `.miz`; `patch-miz` is not to be run.
- The boot script holds one hard-coded path to the mission's `dcs-hotload` folder, sets `Hotload.root` to it, loads `dcs-hotload.lua`, and leaves nothing on screen when it fails: a `HOTLOAD: not booted:` line in `dcs.log`, as hotload's own trigger guard writes. The `PER_MISSION` toggle and its section are gone.
- The page says the developer's path ends up in the built `.miz`, harmless elsewhere, and how to leave it out of a shared copy.
- Load order, the no-reload rule for VEAF modules and the ten-entry F10 root are kept.
- The boot script, extracted from each page, runs under `C:\jeux\DCS World\bin\luae.exe` with the real `dcs-hotload.lua` 3.1.0 present, absent, path emptied, `io`/`lfs` locked with and without the folder, a raising `dcs-hotload.lua`, and no `user-f10\`; the "what was checked" table gives those cases.
- `poetry run docs-check` and `test_backlog_status_consistency` pass.
