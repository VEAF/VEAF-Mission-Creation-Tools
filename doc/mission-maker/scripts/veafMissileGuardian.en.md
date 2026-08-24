# veafMissileGuardian — Missile Interception


**Module ID:** `MISSILEGUARDIAN` | **File:** `veafMissileGuardian.lua`

---

> **Experimental / incomplete module.** This module is a skeleton (version `0.0.2`). The classes described below exist, but the protection logic is not yet implemented (`veafMissileGuardian.getLargeScaleProtector()` and the protector watchdog are stubs). Use for exploratory purposes only.

---

## Purpose

Aims to intercept and destroy incoming missiles to protect designated assets. A `VeafMG_Guardian` observes units and reacts when a shot targets one of them inside a protected zone, warning the target.

---

## Dependencies

---

## Enable

```lua
veafMissileGuardian.initialize()
```

`initialize()` builds the "GUARDIAN" radio menu. Then define a guardian:

```lua
local guardian = VeafMG_Guardian:new()
  :setName("carrier-defense")
  :setFriendlyName("Carrier Defense")
  :addProtectedUnit("CVN-73")        -- DCS unit name to protect (call repeatedly for several units)
  :setProtectedZone(polygon)         -- polygon (list of points) where protection applies
guardian:start()                     -- register the event handler
```

`guardian:stop()` deregisters the event handler.

---

## Builder Methods (`VeafMG_Guardian`)

The guardian is built with `VeafMG_Guardian:new()`. Each setter returns the guardian, allowing chaining.

| Method | Description |
|--------|-------------|
| `:setName(value)` | Internal identifier |
| `:setFriendlyName(value)` | Human-friendly name shown to players |
| `:addProtectedUnit(value)` | Add a DCS unit to protect (name or unit object) |
| `:setProtectedZone(value)` | Polygon (list of points) bounding the protection zone |
| `:start()` | Register the event handler |
| `:stop()` | Deregister the event handler |

---

## What works, and what does not {#state}

Established by reading the code on 2026-08-24 rather than inferred:

| What you can do | State |
|---|---|
| Build a guardian, give it units and a zone, attach it with `start()` | works |
| **Be warned** when a shot targets a protected unit inside the zone | works |
| Have the missile destroyed in flight | **not implemented** — there is no watchdog at all, and `veafMissileGuardian.getLargeScaleProtector()` is a stub returning `nil` |
| `veafMissileGuardian.AddGuardian` / `ActivateGuardian` / `DesactivateGuardian` | **refuse**: the module has no guardian storage, and the class has neither `activate` nor `desactivate`. They warn in the DCS log instead of raising |
| List guardians from the radio menu | **not implemented**: the "GUARDIAN" menu holds a Help entry and nothing else |

Up to 6.15.36 the warning to the pilot was followed by a **Lua error on every shot** (the missing
protector), and the three verbs above raised on a function that was never written. So the one behaviour
this page describes — warning the target — is now complete, and the rest is explicitly refused rather
than silently broken.

## Notes

- A guardian only warns targets inside its protected zone when a shot is detected
- Internal classes: `VeafMG_Weapon` (weapon in flight), `VeafMG_Guardian` (observer), `VeafMG_Protector` (protector, stub: its `start()` and `stop()` have empty bodies)

---

## See Also

- [veafSanctuary](veafSanctuary.en.md) — unit entry protection
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafMissileGuardian` API
