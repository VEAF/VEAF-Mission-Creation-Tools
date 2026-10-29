# 06 — Kneeboard flight cards without the radio plan

Status: ✅ done

The flight card pages keep the points, headings, distances and highest ground, and drop the radio blocks: the presets are already in the cockpits.

Done when: the behaviour is covered by a test, and the action's documentation says it.

## Result

`flight_card_blocks` takes no radio plan any more. Test: `test_the_flight_card_gives_heading_and_distance_and_no_radio_plan`.
