# 01 — A bridge session shared by the commands

Status: ✅ done

One helper the commands call instead of each opening the hook: start `dcs-serve` (loopback, a key of its own, in the folder `clear-ground-sweep` already uses) unless one answers, wait until the mission's bridge connects (it reconnects with a back-off of up to 60 s of mission time), and stop the server it started at the end.

- a Lua error comes back from `dcs-serve` as `{"error": …}` with HTTP 200; `exec_over_bridge` returned an empty string for it. It now raises;
- `in_state_lua(state, code)`: the chunk that runs *code* in another Lua state through `net.dostring_in`, which hands a Lua error back as its string result — told apart by its shape, as the hook client did.

Done when: the helper and both behaviours are unit-tested.
