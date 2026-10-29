# 08 — Known limitation: an On Road route with no path

Status: ✅ done

Measured 2026-10-28 on Syria: a column ordered On Road across the Purple Line at Quneitra stood still 80 s with no message, and left once its first two points were Off Road. Entry in `known-limitations.yaml` (kind dcs), `dcs-runtime-traps.md` regenerated.

Done when: covered by a test, and the documentation says it.

## Result

Entry `on-road-route-with-no-path-stands-still`, page regenerated. Test: `test_a_column_on_road_with_no_path_is_a_known_trap`.
