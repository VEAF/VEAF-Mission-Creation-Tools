# 06 — The Viggen's channel 1

Status: ✅ done

The assistant's report: "On the Viggen, the build puts Lion on channel 2, not channel 1, because of how it lays out the Viggen's radio."
It put the flight's frequency at `primary_1: 01` in `src/presets.yaml`; `inspect_built_mission` shows the AJS37 with one radio and 14 channels.
Not measured yet.

Measure: build the shipped default presets with an AJS-37 template and read which channel of its radio carries `primary_1: 01`, against `presets_injector/data/dcs-radio-layouts.yaml` and the AJS-37 packer (ADR 0012).

Done when: either channel 1 of the plan lands on the Viggen's first selectable channel, with a test, or the measurement shows why it cannot and the guide and `describe_aircraft_radio` say which channel the flight gets.

## Result

Measured in `dcs-radio-layouts.yaml`: by design (ADR 0012) the AJS-37 follows the pilot convention "channel N = Group 10N", so `primary_1` channel 1 is slot 2 (Group 101) and slot 1 holds `primary_2` channel 20 (Group 100). The build is right.
What misleads is the briefing, which numbers by slot: recorded as the known limitation `briefing-channels-are-dcs-slots`, also cited by the objective prompt.
