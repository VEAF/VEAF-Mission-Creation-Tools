# veafHoundElintHelper — Hound ELINT Integration


**Module ID:** — | **File:** `veafHoundElintHelper.lua`

---

## Purpose

Integrates VEAF-spawned units with the [Hound ELINT](https://github.com/hounddoglu/DCS-Hound) third-party script. When `veafSpawn` creates new emitting units (SAMs, EWR radars), this helper registers them with Hound so they appear on its ELINT picture.

---

## Prerequisites

- Hound ELINT script must be loaded before `veafHoundElintHelper`
- Hound must be initialised in your mission

---

## Enable

```lua
veafHoundElintHelper.initialize()
```

After this call, units spawned by `veafSpawn` that are radar emitters will automatically be added to the Hound ELINT network.

---

## Registration Delay

There is a configurable delay before attempting to add newly spawned units to Hound ELINT. This is required for aircraft spawned dynamically:

```lua
veafSpawn.HoundElintAddDelay = 1  -- seconds (default)
```

Increase if Hound reports units not found immediately after spawn.

---

## Notes

- Hound ELINT is a third-party script not included in VEAF — download separately
- Only units that are radar emitters will appear in the ELINT picture
- Registration is fully automatic once the helper is initialised

---

## See Also

- [veafSkynetIadsHelper](veafSkynetIadsHelper.md) — Skynet IADS integration
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafHoundElintHelper` API
