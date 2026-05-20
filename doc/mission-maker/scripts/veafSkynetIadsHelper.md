# veafSkynetIadsHelper — Skynet IADS Integration


**Module ID:** — | **File:** `veafSkynetIadsHelper.lua`

---

## Purpose

Integrates VEAF mission groups with the [Skynet IADS](https://github.com/walder/Skynet-IADS) third-party script. Automatically registers SAM sites, EWR radars, and command centres defined in VEAF missions into the Skynet network, enabling coordinated IADS behaviour.

---

## Prerequisites

- Skynet IADS script must be loaded before `veafSkynetIadsHelper`
- Skynet must be initialised in your mission

---

## Enable

```lua
-- Load Skynet first (in your DO SCRIPT FILE triggers or missionconfig.lua)
-- Then:
veafSkynetIadsHelper.initialize()
```

---

## Registration

VEAF groups can be registered with Skynet via naming conventions or explicit calls:

```lua
-- Register a SAM site by DCS group name
veafSkynetIadsHelper.addSamSiteByGroupName("SA-6 Battery Alpha", iads)

-- Register an EWR by group name
veafSkynetIadsHelper.addEwrByGroupName("EWR P-18 North", iads)

-- Register all groups matching a prefix
veafSkynetIadsHelper.addAllGroupsMatchingPrefix("SAM-", iads)
```

---

## Automatic Registration on Spawn

When `veafSpawn` creates new SAM or EWR units, `veafSkynetIadsHelper` can automatically register them:

```lua
-- Enable auto-registration for dynamically spawned units
veafSkynetIadsHelper.autoRegisterSpawnedUnits = true
```

---

## Notes

- Skynet IADS is a third-party script not included in VEAF — download separately
- Group names in the DCS mission editor must match what you register
- See the [Skynet IADS documentation](https://github.com/walder/Skynet-IADS) for IADS configuration options

---

## See Also

- [veafHoundElintHelper](veafHoundElintHelper.md) — Hound ELINT integration
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafSkynetIadsHelper` API
