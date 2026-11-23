# 03 — `VEAF_DYNAMIC_MISSIONPATH` is the mission folder

Status: ✅ done

Issue: [#1302](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1302).

`mission_builder_worker.py:2175` sets `mission_path = output_mission.parent`: the folder the `.miz` is written to, not the mission folder.
A dynamic-loading build whose output goes elsewhere (`build/`, a server folder) points its scripts at the wrong place.

- Use the mission folder (`mission_folder`) for `VEAF_DYNAMIC_MISSIONPATH`.
- Check the other dynamic paths written next to it use the same base.

Tests: a dynamic build with an output path outside the mission folder → the generated value is the mission folder.

Done when: the test passes and the page that documents dynamic loading says which folder the variable holds.
