# 14 — A `country` that belongs to no coalition makes a battery spawn neutral and stop on `networkName nil`

Status: ✅ done
Type: fix
Files: `src/scripts/veaf/veafSpawnCore.lua` (l. 455-472, the Skynet block), `src/scripts/veaf/veafSpawnGround.lua` (`spawnAirDefenseBattery`), `src/scripts/veaf/veafSpawnParser.lua` (l. 104-106, `country`), `veaf_tools` validate, tests

## What happens

Measured in DCS on 2026-10-13, Normandy Open Training test mission (LOCAL_TEST build), probing the training zones one level at a time with `veafCombatZone.ActivateZone`:

| zone | units alive | statics |
|---|---|---|
| `combatZone_Bocage_Easy` (natives and statics only) | 9 | 3 |
| `combatZone_Bocage_Medium` (adds `-aaa` and `-armor` carriers) | 1 | 1 |
| `combatZone_Aurigny_Easy` (one `-samSR` carrier) | 0 | 0 |

`dcs.log`, after each battery logs its units, then every ~19 s: `ERROR VEAF-SCHEDULER|E|: error in scheduled function … attempt to concatenate local 'networkName' (a nil value)` (`veafSkynet.addGroupToNetwork`, the `debug("ADD GROUP START … [" .. networkName .. "]")` line). The zone's later elements never spawn.

Cause, read from the log line `spawnAirDefenseBattery(czName=…, country=GERMANY, side=0, …)` and checked in the running mission with `coalition.getCountryCoalition`: the carrier names read `#command="-samSR, country germany"`. `Germany` (id 6) is in **no coalition** of this mission (neutral, 0). Its red coalition holds `Third Reich` (id 66, `country.id.THIRDREICH`). So the spawn side is 0; `veafSpawnCore.lua` l. 457-459 then does `networkName = veafSkynet.defaultIADS[tostring(options.side)]` — no default network for side 0 — and calls `addGroupToNetwork(nil, …)`. The same carrier names with `country thirdreich` are what the mission now uses. (A first diagnosis blamed the disabled SKYNET module; it was wrong — the error is identical with the module on, and the mission runs with it off.)

Nothing at authoring or build time says the country is wrong: `validate`, the build and `veaf-config.lua` pass, and `country germany` is the natural spelling of a German battery. The documented example of the prompt, `country russia`, only works because Russia happens to be in the red coalition of the missions built so far.

## What ships

- `veafSpawnCore` (Skynet block): when `networkName` is nil, skip the declaration with one `warning` (« no default network for side %s: the group is spawned and not declared to Skynet »), instead of erroring; so a zone never loses its remaining elements to it.
- `spawnAirDefenseBattery` and the other `_spawn … country X` paths: when `country X` is in no coalition, say so in the log (`warning`) and take the side of the carrier unit (the guide already says « a fake-unit spawns in its own coalition »).
- `validate` warns when a `#command` / `#veafInterpreter` name carries `country X` and X is in no coalition of the mission (the build writes the coalitions: use them), naming the countries that are.
- The prompt (ticket 12) and the authoring skill: « the country of an alias must be one of the coalition's countries; for a Third Reich mission it is `thirdreich` ».

## Done when

A WW2 folder whose carriers say `country germany` activates its zones with every element spawned, one warning logged; `validate` flags `country germany` in a Third Reich mission and names `thirdreich`.

## Done

`veaf.resolveSideAndCountry` (`veaf.lua`): a `country X` in no coalition spawns in the coalition of the command's own unit, with a country of that coalition, and one `warning` naming both; used by the spawn core, so every `_spawn … country X` path gets it (the CAS-mission path, `veafCasMission.lua`, still reads the side itself). The Skynet block of `veafSpawnCore` skips the declaration with a warning when the side has no default network, instead of calling `addGroupToNetwork(nil, …)`. `validate` warns about a `#command` or `#veafInterpreter` whose `country` is in no coalition of the mission, naming the countries that are (`thirdreich` and `Third Reich` are the same country). The authoring skill and the Open Training prompt say the country must be one of the coalition's.

Tested with Lua mocks (the helper, three cases) and Python (the validator), then in DCS on 2026-10-13, Normandy test mission, by `veafInterpreter.execute` on the red side: `-samSR, country germany` (coalition 0 here) spawns its battery red under `cjtf red` with the warning `country [GERMANY] is in no coalition of this mission`; `-samSR, country thirdreich` spawns under Third Reich with no warning; with the red side's default Skynet network removed for the test, the battery spawns, one `no default Skynet network for side 1` warning is logged and no `networkName nil` error follows. A whole zone activating with `country germany` carriers was not run.
