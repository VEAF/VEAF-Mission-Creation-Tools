# FIX-SPAWN-BYPASSSECURITY-AS-SILENT — a shortcut alias spawns without telling anybody

Status: ⬜ ready

Found on 2026-08-24 while establishing the open question of
[`FEAT-RADIO-BEACONS`](../FEAT-RADIO-BEACONS/PRD.md), which set out to copy `-tacan` and discovered
`-tacan` says nothing to the player.

## The defect

`veafSpawn.spawnUnit` documents its parameters, and one of them is:

```lua
-- @param boolean silent (mutes messages to players except errors)
```

The `unit` command handler passes `bypassSecurity` into that position
(`src/scripts/veaf/veafSpawnAircraft.lua:1441`, against the signature at `:29-44`). Two unrelated things
are conflated: *"this command ran without a password"* and *"the player does not want to be told what
happened"*.

The consequence is visible in a shipped alias. `-tacan` sets `setBypassSecurity(true)`
(`veafShortcuts.lua:1469-1474`), so the spawn is silent — a pilot who drops a `-tacan` marker gets **no
confirmation at all**, and no channel or band either. Verified by reading the call and the signature side
by side.

## Not one line — establish the family before fixing

The same argument is passed in the same position by **around a dozen** handlers, across
`veafSpawnAircraft.lua` and `veafSpawnGround.lua` — `unit`, `cap`, `farp`, `fob`, `group`,
`infantryGroup`, `armoredPlatoon`, `airDefenseBattery`, `transportCompany`, `fullCombatGroup` and more.
Whether each one lands on a `silent` parameter depends on **that callee's** signature, and they are not
all the same function.

So the first work is enumeration, not repair: for every handler, which parameter of which callee receives
`bypassSecurity`, and is that parameter `silent`. A sampled fix here would leave siblings broken, which is
the mistake `sweep-enumerated-not-sampled` records. The enumeration belongs in this PRD as a table.

Then decide, once, what the right coupling is. Candidates:

1. **Never silent from a bypass**: pass `options.silent` (adding it as a marker option if wanted) and
   leave `bypassSecurity` for security. A pilot always learns what he spawned.
2. **Silent by intent, per alias**: give `veafShortcuts` its own `setSilent(...)`, so `-tacan` can be
   quiet if that was ever the point — but as a stated choice rather than a side effect of not needing a
   password.

Option 1 is the safe default; option 2 is only worth building if some alias genuinely wants silence.

## Worth checking while in there

`-tacan` has no message of its own even when not silenced: it falls through to
`veaf.t("spawn.unit_spawned", …)`, which names the unit type and the country and **never the channel or
band**. Compare `spawn.jtac_spawned` (`veafI18n.lua:230-233`), which does report code and frequency. A
TACAN whose channel is never told to the pilot is half a feature.

## Definition of done

- [ ] Every handler passing `bypassSecurity` onward enumerated, with the callee parameter it lands on
- [ ] The coupling decided and recorded here, not chosen inside the implementation
- [ ] `-tacan` confirms its spawn and reports its channel and band
- [ ] Lua tests through the command path, since the defect is invisible in the handler read alone
- [ ] Documented if the behaviour a mission maker sees changes
