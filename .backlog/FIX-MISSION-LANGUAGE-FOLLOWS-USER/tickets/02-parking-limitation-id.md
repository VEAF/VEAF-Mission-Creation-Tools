# 02 — The parking limitation says what it concerns

Status: ✅ done

Same test, 2026-10-22: offering the maps, the AI wrote of GermanyCW "pas de places de parking pour les slots dynamiques".
Wrong: DCS places dynamic-slot players itself, with no capture; the parking capture only serves the ramp and runway starts of the flights the tools place (`add_air_group`, a QRA on the ground).
The AI had only the short listing of `describe_known_limitations`, which gives each entry's id, and the id read `no-parking-data-outside-three-theatres` — wrong besides, six theatres ship a capture.

The entry is now `ai-ground-start-needs-a-parking-capture`, its title says dynamic slots are not concerned, and its symptom records the old id.

Done when: `test_the_parking_limitation_says_dynamic_slots_are_not_concerned` fails on the old entry and passes on the new one (both measured).
