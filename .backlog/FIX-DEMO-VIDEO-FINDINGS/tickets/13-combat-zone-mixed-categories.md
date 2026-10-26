# 13 — `create_combat_zone` takes statics and vehicles together

Status: ✅ done

Martinho's session: `create_combat_zone` accepts one `category` per call, so the zone was made with its vehicles and its thirteen statics were added one `add_group … for_combat_zone` call each. David's sandbox run reports the same: a `groups[].units[]` list that fails as a whole after the call.

Fix: the `groups` of `create_combat_zone` each carry their own `category` (vehicle, static, infantry…); the default stays the call's. A group that cannot be built (a static with `count > 1`) is named in the refusal **before** anything is written.

Done when: one call makes a zone with vehicles and statics, with a test; a refused group leaves the mission untouched.

## Result

Fix: a group's own `category` overrides the call's in `create_combat_zone`; a group `insert_group_into_content` refuses is named ("group 'CZ-Depot-bunker': a static is one object…") and, since the mission is saved last, nothing is written. Tests: a zone of vehicles and statics in one call; a refused group leaves `src/mission/mission` and `mission.yaml` byte for byte as they were.
