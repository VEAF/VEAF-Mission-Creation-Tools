# 04 — Draws injected at build

Status: ✅ done

In the training versions only, each `randomize` entry becomes a combat zone injected into the mission table, so the existing combat-zone machinery draws at every launch (PRD, D1 and D6).

For each entry, the build:

1. removes the `replaces` groups from their fixed place;
2. places a trigger zone `TRAINING-<name>` centred on them (or on `at:`), large enough for `radius`;
3. fills it with the pool's candidates, all in one `#spawngroup`, with `#spawncount` = `count` and `#spawnradius` = `radius` in their unit names:
   - `command:` — a fake unit carrying `#command="<alias>"`;
   - `group:` — the Mission Editor group **adopted**: renamed under the zone's prefix, markers added to its unit names, everything else kept (type, units, loadout, skill);
   - `units:` — a real group the build creates from the DCS types, with `mission_tools.group_insertion`;
4. declares the zone in the generated configuration: active at start, no radio menu, no activation by players.

If the vague group is already in one of the night's combat zones, no zone is injected: the markers are added to the existing zone's units, in the training version.

## Done when

- On a fixture mission with **no VEAF command at all**, the training version draws among its own groups: the adopted groups are in the injected zone, with the markers, and the fixed ones are gone.
- Each kind of candidate has its test on the built mission table.
- A `group:` candidate referenced by name in a Mission Editor trigger, in `mission.yaml` (QRA, Skynet, a module's settings) or in an embedded script makes the build **fail**, with a message naming the group and the reference (D6).
- The night's `.miz` holds no `TRAINING-` zone and no marker added by the build.
- A Lua test runs the generated configuration against the DCS mocks and checks the zone spawns `count` elements from the pool, within `radius`.
- An injected SAM is integrated into Skynet when it spawns (Lua test on the mocks, through `veafSkynet.integrateMissionSpawn`).
