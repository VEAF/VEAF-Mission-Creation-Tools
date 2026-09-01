# 02 — The CAP refusal must name the template it rejected

Status: ✅ done

Type: fix · File: `src/scripts/veaf/veafSpawnAircraft.lua`

## The change

`spawnCombatAirPatrol` fails for two different reasons and described both as the first one:

```lua
if not chosenTemplateName or not chosenTemplateData then
  ... "could not find a template for %s" ... veaf.p(name)
```

`name` is what the pilot typed. In the case that actually happened the name **was** matched —
fourteen templates answered to `mig29` and one was chosen — and it was the mission data behind it
that came back nil. So the log said *that aircraft does not exist* about an aircraft that did, and
sent every investigation to the template table and the search pattern. That is why ticket 01's defect
lived from 2026-03-14 to 2026-09-01.

The two cases are now separate, and the one that can name a template names it:

- nothing matched → `no aircraft template matches "mig29"`
- matched then dropped → `template "veafSpawn-MIG29-NEUTRAL" matched "mig29" but has no mission
  data, and was rejected`

## Also checked, per the PRD

Whether anything else asks for `chosenTemplateData` and silently drops a template it had found.
`veafSpawn.findSpawnableAircraftGroupname` has two callers: this one, and `spawnAFAC`
(`veafSpawnAircraft.lua:468`) which takes the name only and never reads the data, so it neither
dropped a template nor mis-reported one. Nothing else in `src/` calls it.

Found in passing and left alone: `VeafAirUnitTemplate:getGroupData()` has no caller anywhere in
`src/` — the setter is used by the `SpawnablePlanes` branch, the getter by nobody.

## Definition of done

- [x] The two failures are distinguished, and the message says which one happened
- [x] The rejected template is named when there is one to name
- [x] The no-match message still names the pilot's input, and names no template
- [x] A test asserts the message contains the template name, and fails when it prints the input instead
- [x] A readable template is not refused — so the assertions above are not passing on an always-failing spawn
- [x] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean
