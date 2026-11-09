# 01 — Developer page: the hotload recipe

Status: ✅ done

A new page `doc/developer/hotload.md` and `hotload.en.md`, in the `nav` with its `nav_translations` entry, linked from the `custom_scripts` section of the `mission.yaml` reference.

## Done when

- The page holds the boot script `hotload-boot.lua`, which does nothing when dcs-hotload is absent or `io`/`lfs` are locked, and its `custom_scripts` block.
- It states the load order: `veaf-config.lua` → `mission-script.lua` → `custom_scripts`, so the VEAF modules are loaded when the boot script runs.
- It gives the per-mission variant, the root built from the mission's `sortie`.
- It warns that unlocking `io`/`lfs` in `MissionScripting.lua` applies to the whole DCS install.
- It states the two reservations: the F10 root holds ten entries and hotload takes one; VEAF modules are not reloaded with hotload.
- It says the recipe has not been tested in game yet.
- The boot script, extracted from the page, runs under `C:\jeux\DCS World\bin\luae.exe` against a mocked `lfs`/`env` with hotload present, absent, failing, and with `lfs` locked.
- `poetry run docs-check`, the support bot's page index and `test_backlog_status_consistency` pass.
