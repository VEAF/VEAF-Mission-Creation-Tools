# 12 — Clear ground for statics

Status: ✅ done

`create_combat_zone` with `category: static` (six fuel tanks at Adler) returned no warning, while the same call with a vehicle was moved 625 m "onto clear ground".
The assistant then placed a throw-away vehicle group (`ProbeDepot`) to find clear ground, moved the six tanks there, and deleted the probe; its report says the tanks "were never checked".

Measure: whether statics skip the clear-ground placement on purpose (a static is often meant to sit on a building or a parking), in `add_group` / `create_combat_zone`.

Done when: a static placed where the clear-ground catalogue says the ground is not clear gets a warning naming the nearest clear spot — not a silent move, a static's position is the maker's — and where no catalogue covers the place, the same "nothing says it is not in trees or buildings" warning as vehicles; tests.

## Result

Statics skip the move on purpose (their position is the maker's); now `insert_group_into_content` asks the same clear-ground placement for a static and, when it would have moved it, warns with the distance and the nearest clear spot, without moving it; where no catalogue covers the place, the same "nothing says it is not in trees or buildings" warning as a vehicle.
Tests: `test_a_static_on_ground_not_clear_is_warned_and_not_moved`, `test_a_static_where_no_catalogue_looks_says_so`.
