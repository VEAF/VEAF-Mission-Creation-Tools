# 06 — The Viggen's channel 1

Status: ⬜ ready

The assistant's report: "On the Viggen, the build puts Lion on channel 2, not channel 1, because of how it lays out the Viggen's radio."
It put the flight's frequency at `primary_1: 01` in `src/presets.yaml`; `inspect_built_mission` shows the AJS37 with one radio and 14 channels.
Not measured yet.

Measure: build the shipped default presets with an AJS-37 template and read which channel of its radio carries `primary_1: 01`, against `presets_injector/data/dcs-radio-layouts.yaml` and the AJS-37 packer (ADR 0012).

Done when: either channel 1 of the plan lands on the Viggen's first selectable channel, with a test, or the measurement shows why it cannot and the guide and `describe_aircraft_radio` say which channel the flight gets.
