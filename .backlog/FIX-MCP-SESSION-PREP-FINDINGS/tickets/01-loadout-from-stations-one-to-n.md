# 01 — `loadout_from` copies a loadout whose stations run 1 to n

Status: ✅ done

`normalize_pylons` iterated `pylons.items()`; a loadout read from a mission group with stations 1..n and no gap comes back from the Lua parser as a list.

- A list is read as stations from 1, in order (`aircraft_payload.normalize_pylons`).
- Tests: the function on a list and on a dict; `create_qra` with `loadout_from` a group whose pylons are `[1]` and `[2]`.
