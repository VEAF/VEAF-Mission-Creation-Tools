# FIX-SANCTUARY-SHIFTED-ALIAS-CALLS — sanctuary defences never spawn, they raise

Status: ✅ done

Found on 2026-08-24 while enumerating `bypassSecurity` call sites for
[`FIX-SPAWN-BYPASSSECURITY-AS-SILENT`](../FIX-SPAWN-BYPASSSECURITY-AS-SILENT/PRD.md). Not folded in
there, to keep that lot's scope.

## The defect

`VeafSanctuaryZone:deployDefenses` calls `veafShortcuts.ExecuteAlias` at **eight** places
(`veafSanctuary.lua:438, 447, 458, 467, 482, 491, 502, 511`) with its arguments **shifted one position
left**. The signature is:

```lua
function veafShortcuts.ExecuteAlias(aliasName, delay, remainingCommand, position, eventCoalition, markId, bypassSecurity, spawnedGroups, route)
```

and the call passes seven arguments:

```lua
veafShortcuts.ExecuteAlias(
  ship1,                                                    -- aliasName          ✓
  "radius 2000, multiplier 2, skynet false" .. heading1S,   -- delay              ✗ meant remainingCommand
  positionIn20s,                                            -- remainingCommand   ✗ meant position
  self:getCoalition(),                                      -- position           ✗ meant eventCoalition
  nil,                                                      -- eventCoalition     ✗ meant markId
  true,                                                     -- markId             ✗ meant bypassSecurity
  spawnedGroupsNames                                        -- bypassSecurity     ✗ meant spawnedGroups
)
```

Those seven fit the signature **exactly** as it stood before commit `c396eaea` (2021-04-13, *"added the
option to delay an alias with the -<alias>!<delay> syntax"*) inserted `delay` as the second parameter.
veafSanctuary was never updated. The shift is therefore **five years old**.

## The consequence

A command string lands on `delay`, so `ExecuteAlias` takes the `if delay and delay ~= ""` branch
(`veafShortcuts.lua:540`) and evaluates:

```lua
timer.getTime() + delay   -- delay == "radius 2000, multiplier 2, skynet false, hdg 123"
```

which raises *attempt to perform arithmetic on a string value* in Lua 5.1. The defences never spawn.

## Is it reachable?

**Yes, by design and documented.** `deployDefenses` runs when a player lingers in a sanctuary zone past
`delaySpawn` (`veafSanctuary.lua:705-707`), and `delay_spawn` is a shipped `mission.yaml` option — the
commented example in `src/defaults/mission-folder/mission.yaml:138` sets `delay_spawn: 60`, and
`lua_config_generator.py` emits `setDelaySpawn` for it. The default is `-1`, which disables the branch, so
**only a mission that sets `delay_spawn` is affected** — which is also why nobody has reported it.

## Scope

1. Realign the eight calls.
2. Make `ExecuteAlias` refuse a non-numeric delay **loudly** instead of letting the arithmetic raise. A
   legitimate delay always arrives as digits: `markTextAnalysis` extracts it with `!(%d*)`. So anything
   that is neither nil, empty, nor numeric is a caller bug, and the right answer is to say so and run the
   alias **immediately** — losing the delay rather than losing the spawn.
3. A test that would have caught the shift. The interesting assertion is not "the defences spawn" but
   "`ExecuteAlias` was handed a numeric-or-nil delay", because a misaligned call is invisible until it runs.

## Definition of done

- [x] The eight calls realigned — `nil` inserted for `delay`, by a script anchored on the alias variable
      so a site that did not match would fail loudly rather than be skipped silently. Eight matched
- [x] `ExecuteAlias` refuses a non-numeric delay loudly rather than raising — `tonumber`, an error naming
      the value, and the alias runs immediately
- [x] A Lua test that fails on the shifted call — **seven**, written before the fix and red for seven
      different aspects of the shift
- [x] CHANGELOG entry and the version bump across the three manifests — 6.15.48

## How it went

The tests came first and were red before anything was fixed, each on a different consequence of the same
shift: the delay was a command string, the position was a coalition number, the coalition slot was nil, the
bypass flag was a table. That last one matters on its own — the accumulator the caller passes to collect
the spawned group names was landing on `bypassSecurity`, so even if the delay had not raised, the caller
would never have got its groups back.

Two mist functions were missing from the shared mocks and were added rather than stubbed locally, since
production code calls both: `mist.getHeading` (returns radians, and records whether the caller asked for
true or magnetic north — both look identical in the result) and `mist.utils.makeVec2`.

### Mutations

| Mutation | Result |
|---|---|
| the shift restored (the eight `nil`s removed) | the suite fails |
| the guard removed, back to `timer.getTime() + delay` | the suite fails |
| the refusal made silent | 1 test fails |
| it complains about a *good* delay | 1 test fails |

The last two exist because "refused **loudly**" is the requirement, and a comment is not a requirement:
without a test on the log, the next tidy-up could drop it and leave a misaligned caller quietly losing its
delay — a quieter version of the bug this lot exists to fix.

## Noticed, not established, not touched

The **land** branch's first wave spawns its two SAM sites at the *same* radius and the *same* position
(`radius 2000`, `positionIn20s` both times, `veafSanctuary.lua:460` and `:470`), differing only in heading.
Its neighbours all vary both: the water branch uses 2000/`positionIn20s` then 3000/`positionIn40s`, and the
harder land wave uses 3000/`positionIn20s` then 4000/`positionIn40s`.

That reads like a copy-paste slip, but it is **not proven**: two SAM sites at one point with different
headings is a defensible layout, since a site's heading decides where its launchers face. Left exactly as
it was — guessing at intent and "fixing" a deliberate layout would be worse than the asymmetry. Recorded
here so the next reader does not have to re-notice it.

## What was not done

**No documentation change.** `doc/mission-maker/scripts/veafSanctuary.md` already documents `delay_spawn`
as deploying the defences (`:31`, `:58`, `:72`, `:113`). It was describing behaviour that never worked; the
fix makes the page true rather than out of date, and no interface changed.
