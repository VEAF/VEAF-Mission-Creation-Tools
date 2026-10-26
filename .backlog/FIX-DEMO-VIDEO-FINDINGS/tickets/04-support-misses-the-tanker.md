# 04 — Support: only the AWACS, the tanker forgotten

Status: ✅ done

The AI: "Deck's Support line and tactical map only pick up the AWACS (builder limitation); the tanker is in the mission and correct", and "`inspect_built_mission` "support" lists only Overlord; the Enfield tanker is correctly present in the .miz (Tanker task, TACAN 63Y, 262 MHz, orbit, unlimited fuel)".
Its own script then wrote both on the ATO page ("Overlord 1-1 - AWACS, E-3A: 255.0 MHz - Enfield - Tanker, KC-135: 262.0 MHz (TACAN 63Y)").

Two readers miss the same group, so the cause is probably one shared reading of "support": a tanker recognised by something the AI's group did not carry (its callsign family, see ticket 01; its name; the task on the group rather than the route), or a reader that keeps the first support group only.

Measure on a clean mission with an AWACS and a tanker added through the actions: what `inspect_built_mission`, the deck's Support line and its tactical map report.

Done when: both report the tanker, with a test on each; the shared cause is named in this ticket.

## Result

Measured: same root cause as ticket 01. Every reader of support (`mission_picture.read_mission_picture`, `inspect_built._SUPPORT_TASKS`, the presets injector) keys on the group task `Refueling`; the AI's tanker carried `Tanker`, so the deck's Support line, its map and `inspect_built_mission` all missed it while the `.miz` held the tanker. With the task canonicalised at creation (ticket 01) the readers see it; the fixture's tanker (`Arco`, task `Refueling`) is listed by the deck and the inspection.
