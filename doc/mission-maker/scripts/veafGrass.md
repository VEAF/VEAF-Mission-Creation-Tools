# veafGrass — Grass Airstrip Configuration

> 🇫🇷 [Version française](../fr/scripts/veafGrass.md)

**Module ID:** — | **File:** `veafGrass.lua`

---

## Purpose

Configures unprepared grass airstrips for use in DCS missions. Provides positioning data, radio frequencies, and landing aids for rough-field landing zones that are not standard DCS airbases.

---

## Enable

```lua
veafGrass.initialize()
```

Then define each grass strip:

```lua
VeafGrassRunway:new()
  :setName("FARP Whiskey")
  :setGroupName("FARP-WHISKEY-GROUP")   -- static objects defining the strip
  :setRunwayHeading(270)                -- runway heading in degrees
  :setAtcFrequency(127500000)           -- Hz (127.5 MHz)
  :setAtcModulation(radio.modulation.AM)
  :setTacanChannel(74, "X", "WHK")     -- optional TACAN
  :initialize()
```

---

## Builder Methods

| Method | Description |
|--------|-------------|
| `:setName(name)` | Internal identifier and label |
| `:setGroupName(name)` | DCS group of static objects forming the strip |
| `:setRunwayHeading(deg)` | Primary runway magnetic heading |
| `:setAtcFrequency(hz)` | ATC radio frequency in Hz |
| `:setAtcModulation(mod)` | `radio.modulation.AM` or `FM` |
| `:setTacanChannel(ch, band, morse)` | TACAN channel, band (X/Y), Morse ID |
| `:initialize()` | Register the strip |

---

## Notes

- The "group" should contain the static objects (windsock, fuel trucks, etc.) that visually define the strip
- Position and heading are read from the group's lead unit
- ATC frequency is announced via the F10 menu and in radio messages

---

## See Also

- [veafAssets](veafAssets.md) — for managed tankers and AWACS at regular airbases
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafGrass` API
