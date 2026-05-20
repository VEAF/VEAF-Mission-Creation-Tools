# veafMissileGuardian — Missile Interception

> 🇫🇷 [Version française](veafMissileGuardian.md)

**Module ID:** — | **File:** `veafMissileGuardian.lua`

---

## Purpose

Intercepts and destroys specific incoming missiles to protect designated assets or zones. Useful for protecting carriers, FARPs, or other high-value targets from ballistic threats in scenarios where realistic missile defense is desired.

---

## Dependencies

- `veafEventHandler` — for missile-fired event monitoring

---

## Enable

```lua
veafMissileGuardian.initialize()
```

Then define protection zones:

```lua
VeafMissileGuardian:new()
  :setName("Carrier Defense")
  :setGroupName("CVN-73")           -- protect this group
  :setRadius(30000)                 -- interception radius in metres
  :setMissileTypes({ "P-700", "Kh-41" })  -- intercept these missile types
  :initialize()
```

---

## Builder Methods

| Method | Description |
|--------|-------------|
| `:setName(name)` | Internal identifier |
| `:setGroupName(name)` | DCS group to protect |
| `:setZoneName(zone)` | Alternatively, protect a zone |
| `:setRadius(m)` | Interception radius around the protected target |
| `:setMissileTypes(list)` | List of DCS weapon type names to intercept |
| `:setAllMissiles(bool)` | If true, intercept all missiles |
| `:setSilent(bool)` | Suppress interception messages |
| `:initialize()` | Activate the guardian |

---

## Notes

- Missiles are destroyed when they enter the protection radius
- Use specific missile type lists to avoid intercepting friendly ordnance
- Works for both anti-ship and surface-to-air missiles

---

## See Also

- [veafSanctuary](veafSanctuary.md) — unit entry protection
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafMissileGuardian` API
