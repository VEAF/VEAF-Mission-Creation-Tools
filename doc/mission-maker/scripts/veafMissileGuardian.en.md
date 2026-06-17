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

## Notes

- The module is experimental: actual missile destruction is not yet implemented
- A guardian only warns targets inside its protected zone when a shot is detected
- Internal classes: `VeafMG_Weapon` (weapon in flight), `VeafMG_Guardian` (observer), `VeafMG_Protector` (protector, stub)

---

## See Also

- [veafSanctuary](veafSanctuary.md) — unit entry protection
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafMissileGuardian` API
