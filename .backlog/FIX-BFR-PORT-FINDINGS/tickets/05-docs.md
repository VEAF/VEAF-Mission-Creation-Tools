# 05 — Docs: load order, root-menu handles, mission.yaml keys, report path

Status: ✅ done

Issues: [#1297](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1297), [#1299](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1299), [#1305](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1305), [#1306](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1306).

Documentation only, FR and EN for each page.

- **Load order (#1297)** — `doc/mission-maker/custom-script-layer.md`: `veaf-config.lua` runs before `custom_scripts`, so a module it starts is up before the layer. To configure a module from the layer first, set its `initialized_by_mission` and call its `initialize(true, false)` from the layer — Sharko's recipe, with the carrier module as the example.
- **Root-menu handles (#1299, #1305)** — same page, or `veafRadio.md`: every module keeps the menu it adds at the root in a variable (`veaf.ctldRootPath`, `veafCarrierOperations.rootPath`, `veafWeather.rootPath`…). `veafRadio.delSubmenu(<handle>)` then `veafRadio.refreshRadioMenu()` removes that menu in every language; a title does not, once translated. Remove it after the module has built it (the CTLD menu is built at `ctld_initialize`). List the handles, read from the code.
- **mission.yaml keys (#1306)** — `doc/MISSION_YAML_REFERENCE.md`: document `last_line_of_defence`, `welcomeBrief` and `radio_menu_coalition`, read from the code that consumes them.
- **Report path (#1306)** — `doc/CLI_REFERENCE.md:316`: the conversion report is written in `backup_v5/convert-v5-report.md` (`convert_v5.py:245`), not in the mission folder.
- **CTLD facts in `custom-script-layer.md` (#1306)** — "rc13 / 47 events" is stale. If the CTLD 2.1.0 vendoring lot has not already rewritten these rows, align them with the vendored CTLD (version, event list, a JTAC row, a FOB counted as a logistic zone).

Done when: `poetry run docs-check` passes, and the support bot's page index is refreshed if a page title changed.
