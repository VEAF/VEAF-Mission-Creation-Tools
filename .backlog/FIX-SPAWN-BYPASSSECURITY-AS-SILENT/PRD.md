# FIX-SPAWN-BYPASSSECURITY-AS-SILENT — a shortcut alias spawns without telling anybody

Status: ✅ done

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


## The enumeration — established 2026-08-24

Mechanically, not by sampling: every `registerCommandHandler` block was parsed, the call receiving
`bypassSecurity` located, its argument **position** taken, and that position looked up in the callee's own
signature. The PRD guessed "around a dozen". It is **fourteen**.

| Handler | File | Callee | Position | Lands on |
|---|---|---|---|---|
| `unit` | veafSpawnAircraft | `spawnUnit` | 14 | `silent` |
| `cap` | veafSpawnAircraft | `spawnCombatAirPatrol` | 12 | `silent` |
| `airDefenseBattery` | veafSpawnGround | `spawnAirDefenseBattery` | 9 | `silent` |
| `armoredPlatoon` | veafSpawnGround | `spawnArmoredPlatoon` | 11 | `silent` |
| `convoy` | veafSpawnGround | `spawnConvoy` | 16 | `silent` |
| `farp` | veafSpawnGround | `spawnFarp` | 9 | `silent` |
| `fob` | veafSpawnGround | `spawnFob` | 9 | `silent` |
| `fullCombatGroup` | veafSpawnGround | `spawnFullCombatGroup` | 11 | `silent` |
| `group` | veafSpawnGround | `spawnGroup` | 10 | `silent` |
| `infantryGroup` | veafSpawnGround | `spawnInfantryGroup` | 11 | `silent` |
| `transportCompany` | veafSpawnGround | `spawnTransportCompany` | 10 | `silent` |
| `cargo` | veafSpawnEffects | `spawnCargo` | 8 | `silent` |
| `logistic` | veafSpawnEffects | `spawnLogistic` | 4 | `silent` |
| `teleport` | veafSpawnEffects | `teleport` | 3 | `silent` |

**Not affected, and worth recording so nobody "fixes" them:**

| Handler | Why not |
|---|---|
| `afac` | hard-codes `false` at the `silent` position (`spawnAFAC` param 11) — already correct |
| `beacon` | passes `options.silent` — correct, though see the note below |
| `destroy`, `bomb`, `smoke`, `flare`, `signal` | declare `bypassSecurity` and never forward it |

**Not one of the fourteen callees has a security parameter.** `bypassSecurity` was landing on `silent` and
on nothing else, in all fourteen. The security decision is already taken *before* the handler runs, by the
dispatcher: `if not bypassSecurity and _security then <check>` (`veafSpawnCore.lua:361`). So removing the
argument from these calls cannot weaken security — there is nothing downstream for it to do.

## The premise the PRD got wrong: the conflation is right for the dominant caller

Two entry points reach the handlers, and `veafCommands` sets both flags itself:

| Line | Path | `bypassSecurity` | `fromMarker` |
|---|---|---|---|
| `veafCommands.lua:210` | a player dropped a marker | **false** | **true** |
| `veafCommands.lua:232` | the interpreter | **true** | **false** |

The interpreter is what `veafCombatZone.lua:1543` and `veafAirWaves.lua:1039` use, plus pre-placed units
firing commands at mission start. **Those callers must be silent** — a zone that spawns thirty groups must
not print thirty messages to every player. So `bypassSecurity → silent` does the right thing for the
dominant caller, which is why it survived; that is *why* it is not simply a typo.

On the marker path `bypassSecurity` arrives as **false always**. The only way a marker becomes silent is an
alias setting the flag on itself (`_bypassSecurity = bypassSecurity or self:isBypassSecurity()`,
`veafShortcuts.lua:204`) — a **player action inheriting the silence meant for scripts**.

So **PRD option 1 as written would be a regression**: passing `options.silent` (always nil) would make
combat zones and AirWaves announce every group they spawn.

### What actually changes, per path

| Path | silent today | silent after | |
|---|---|---|---|
| a plain `_spawn …` marker | false | false | unchanged |
| an alias with `setBypassSecurity(true)`, from a marker | **true** | **false** | **the bug, fixed** |
| the interpreter (zones, waves, pre-placed) | true | true | unchanged |

One row changes, and it is the defect.

### Option 3, and the recommendation

**Silence follows "was this a script or a player", not "did it need a password".** The bit already exists
and is already threaded to exactly the right place: `fromMarker`, which both entry points receive
(`veafSpawnCore.lua:1042`, `veafShortcuts.lua:1730`) and already use — for the coalition choice.

Recommended over options 1 and 2: option 1 regresses the scripted callers, and option 2 (a per-alias
`setSilent`) asks every alias author to restate a rule that is already derivable.

### Corroboration: the symptom was patched once already

`veafSpawnAircraft.lua:263` reads `if (role == "jtac") or not silent then`. Somebody hit this exact defect
for `-jtac`, and exempted that one role instead of fixing the conflation. **This means `-jtac` is not
mute** — contrary to what a first reading of the alias list suggests — and it means the special case can
be deleted once `silent` stops carrying the security flag.

### Only one shipped alias is affected today

Of 131 aliases, **9** set `setBypassSecurity(true)`: `-point`, `-jtac`, `-afac`, `-light`, `-smoke`,
`-longsmoke`, `-signal`, `-tacan`, `-beacon`. Traced each to its handler: `-point` is not a spawn;
`-jtac` is exempted by the special case above; `-afac` and `-beacon` are the two already-correct
handlers; `-light`, `-smoke`, `-longsmoke` and `-signal` reach effects handlers that never forward the
flag. **`-tacan` is the only one that goes mute** — it parses to `options.unit = true`
(`veafSpawnParser.lua:470-473`), and `unit` is the first registered handler.

That does not shrink the lot to one line: the other thirteen are live wires. Any alias that sets the flag
on a ground or cargo command goes silent with no warning, which is how `-tacan` got here.

### A side finding

`options.silent` is **not a parsed marker option** anywhere — `silent` is a function parameter throughout.
So the `beacon` handler's `options.silent` is always nil. Its behaviour is right (a beacon always reports),
but the code implies an option a mission maker can set, and there is none.

## Worth checking while in there

`-tacan` has no message of its own even when not silenced: it falls through to
`veaf.t("spawn.unit_spawned", …)`, which names the unit type and the country and **never the channel or
band**. Compare `spawn.jtac_spawned` (`veafI18n.lua:230-233`), which does report code and frequency. A
TACAN whose channel is never told to the pilot is half a feature.

## Definition of done

- [x] Every handler passing `bypassSecurity` onward enumerated, with the callee parameter it lands on —
      the table above: **fourteen**, not "around a dozen", and three of them (`cargo`, `logistic`,
      `teleport`) were in a file the PRD did not name
- [x] The coupling decided and recorded here, not chosen inside the implementation — **option 3**, and the
      PRD's own option 1 would have been a regression
- [x] `-tacan` confirms its spawn and reports its channel and band — new `spawn.tacan_spawned`, band
      upper-cased for display
- [x] Lua tests through the command path, since the defect is invisible in the handler read alone — six at
      the dispatcher, six at the alias layer. **The alias ones exist because a mutation demanded them**:
      reverting the actual fix left all 37 suites green
- [x] Documented if the behaviour a mission maker sees changes — `veafShortcuts` page, both languages,
      with the who-asked table. The page also said **eight** bypassing aliases; there are nine

## How it was fixed

`bypassSecurity` and `fromMarker` are **perfectly anti-correlated at the entry point** — `veafCommands`
passes `(false, true)` on the marker path (`:210`) and `(true, false)` on the interpreter path (`:232`).
So the bit "a script asked, not a person" already existed and already arrived where it was needed.

The corruption happened in exactly one line, `veafShortcuts.lua:204`:

```lua
local _bypassSecurity = bypassSecurity or self:isBypassSecurity()
```

which is right for skipping a password check and wrong for deciding whether to speak. The fix keeps
`_bypassSecurity` for security and passes the **unmodified** `bypassSecurity` as a new trailing argument,
which `veafSpawn.executeCommand` stores once as `options.silent` for all fourteen handlers to read.

`options.silent` was previously never set by anything — the `beacon` handler already read it and was
always getting nil. That side finding closed itself, and with a behaviour change worth stating plainly: a
beacon placed **by a script** is now quiet, where before it always spoke. That is the rule this lot
establishes, applied to the one handler that was already asking the right question.

### Mutations

| Mutation | Result |
|---|---|
| silence back to `bypassSecurity` at the dispatcher | 2 tests fail |
| nothing is ever silent | 2 tests fail |
| everything is silent | 3 tests fail |
| the tacan message branch removed | 4 tests fail |
| the band not upper-cased | 1 test fails |
| the jtac exemption dropped | 1 test fails |
| **the alias-level fix reverted** | 1 test fails |
| the silence argument dropped from the alias call | 3 tests fail |
| the alias stops bypassing passwords | 1 test fails |
| `scripted` dropped from the delayed reschedule | 1 test fails |
| `scripted` dropped from the repeat reschedule | 1 test fails |

**One mutation killed nothing at first**, and it was the one that mattered: reverting the fix in
`VeafAlias:execute` — the whole point of the lot — passed all 37 suites. Six dispatcher tests proved the
*dispatcher*; nothing reached the two variables one letter apart. That is what the alias suite is for.

### Two callers the first sweep missed

`veafSpawn.executeCommand` re-enters itself through `mist.scheduleFunction` on the **delayed** and
**repeated** paths (`veafSpawnCore.lua:262`, `:295`), each with a literal argument table. Both tables
stopped at `requesterCoalition`, so the new flag was dropped and a scripted spawn carrying `delayed 30` or
`repeat 3` would have come back chatty on its second pass — the same defect one indirection further out.
Found by grepping for the function's own name rather than for the handlers, after the fourteen were done.

## Found but not fixed here

`veafSanctuary.lua` calls `veafShortcuts.ExecuteAlias` at eight places with arguments **shifted by one
position**: its seven arguments fit the signature as it stood before commit `c396eaea` (2021-04-13) added
`delay` as the second parameter. A command string therefore lands on `delay`, and
`timer.getTime() + delay` (`veafShortcuts.lua:544`) would raise a Lua arithmetic error whenever a
sanctuary zone triggers over water. Filed separately rather than folded in.
