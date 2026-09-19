# Missing references

Your `mission.yaml` names a group, a trigger zone, a unit or an airfield; the build looks in the
mission and cannot find it. This is the most common family, and the most expensive: the mission
builds, loads and plays — and the feature concerned simply does nothing, **with no word in game**.

## The framed block at the end of the build {#builder-reference-issues-header}

> ────────────────────────────────────────────────────────────
> 3 mission.yaml reference(s) to a Mission-Editor object are missing (the .miz was still built) —
> fix them in the Mission Editor or mission.yaml:
>   • …
>   • …
> ────────────────────────────────────────────────────────────

Every missing reference is gathered there, at the very end, in a frame — rather than scattered
through the build output where they would go unnoticed.

**The build does not stop, and that is deliberate.** To place the missing group you need to open
the mission in the DCS editor; refusing to produce the `.miz` would deny you the very thing you
need in order to fix it.

**To read the list again without rebuilding:**

```powershell
.\veaf-tools.exe validate
```

> **The `.\` is required.** PowerShell does not search the current folder — deliberately. See
> [PowerShell or command prompt?](../GUIDE.en.md#powershell-vs-cmd).

## How to read one of these messages {#how-to-read}

They all have the same shape: **what** is missing, and **where** it is declared.

> Group 'Alert-CAP-1' declared in **QRA** is absent from the mission

The bold word is a path inside your `mission.yaml`, not a folder and not a script. Here are the
sections actually checked:

| What is checked | `mission.yaml` sections |
|---|---|
| **Groups** placed in the editor | `modules.ASSETS` (`name`, `linked`), `modules.QRA` (`simple_groups`, `groups_by_enemy_count`), `cap_missions`, `combat_missions` |
| **Trigger zones** | `modules.AIRWAVES` (`trigger_zone_name`), `modules.QRA` (`trigger_zone`), `modules.COMBATZONE` (`zone_name`) |
| **Units** (or groups) | `modules.SANCTUARY` (`polygon_units`) |
| **Airfields** | `modules.QRA` (`airport_link`) |
| **Sub-zones** declared elsewhere in the YAML | `modules.COMBATZONE`, operations (`tasking_orders`, `dependencies`) |

If your message names a section that is not in this table, it does not belong to this family — go
back to the [index](README.en.md).

## A declared group is absent from the mission {#validate-missing-group}

> Group 'Alert-CAP-1' declared in QRA is absent from the mission — place it in the Mission Editor,
> or the feature fails at runtime.

At build time the same finding appears in a slightly longer form, with an example of what breaks:

> Group 'Alert-CAP-1' declared in QRA is not present in the mission — it must be placed in the
> Mission Editor, otherwise the feature fails at runtime (e.g. veafAssets.respawn).

**In the editor.** The name must match the group name in the DCS editor **exactly** — the one in
the left-hand column, not the name of a unit inside the group. Capitals, spaces and dashes
included.

**The two traps that are not typos.**

- **`cap_missions` looks for a prefixed name.** The runtime prepends `OnDemand-` to the name you
  write, so your template group in the editor must be called `OnDemand-<your name>`. If you wrote
  `group_name: North-Patrol`, the editor must hold `OnDemand-North-Patrol`.
- **Renaming in the editor does not update `mission.yaml`.** The two files do not talk to each
  other: if you rename or re-place a group in the editor, carrying the new name over to the YAML is
  on you. This is the most common cause of a name that "worked yesterday".

**The ways out.** Place the missing group in the editor, fix the name in `mission.yaml`, or remove
the entry if you no longer need the feature.

**What it is not.** Not a VEAF script error, and rebuilding will change nothing: the build reads
what your `.miz` contains, it does not create groups.

## A trigger zone does not exist {#validate-missing-trigger-zone}

> Trigger zone 'ZONE-KOBULETI' referenced by COMBATZONE does not exist in the mission — create it
> in the Mission Editor.

**In the editor.** Trigger zones are the circles and polygons under the *Trigger zones* tab. A
combat zone or a QRA without its own fails at module start-up: on the `VeafCombatZone` side,
initialisation raises an error and the module stops.

**The ways out.** Create the zone in the editor, or fix the name in `mission.yaml`. Here too the
name must be identical to the character, and renaming a zone in the editor does not update the
YAML.

## …but a centre and a radius will take over {#validate-missing-trigger-zone-optional}

> Trigger zone 'AIRWAVE-1' referenced by AIRWAVES does not exist in the mission — the configured
> center/radius will be used instead. Remove trigger_zone_name to silence this.

**The benign version of the previous one**, and the difference comes from your own configuration:
an AIRWAVES zone carrying both `zone_center_coordinates` and `zone_radius` has everything it needs
without the editor's zone. The build sees that, downgrades the error to a warning, and the mission
works.

**The ways out.** Create the zone if you really wanted it, or remove `trigger_zone_name` to commit
to the centre/radius — and silence the message.

**What it is not.** Never the case for QRA or COMBATZONE zones: those have no fallback, and stay
errors.

## A referenced unit is absent {#validate-missing-unit}

> Unit 'Sanctuary_Kutaisi_Polygon #003' referenced by SANCTUARY is absent from the mission — place
> it in the Mission Editor, or the zone polygon is incomplete.

**In the editor.** A sanctuary draws its polygon by joining units placed at the corners. One is
missing: the polygon closes some other way, so the protected zone is not the shape you wanted — and
nothing will say so in game.

**The trap worth knowing.** The name may designate a **unit** *or* a **group**. The runtime looks
for a unit first and, failing that, takes the first unit of the group with that name. So a
`polygon_units` list naming groups is perfectly valid — there is nothing to "fix" towards unit
names.

## An airfield is unknown on this theatre {#validate-unknown-airfield}

> Airfield 'Kobuletti' referenced by QRA.airport_link is unknown on this theatre — check the
> spelling against the Mission Editor airfield name.

**In the editor.** The expected name is the one the DCS editor shows for the airfield, letter for
letter. Names transliterated from Georgian, Syrian or Persian are doubled-consonant traps —
*Kobuleti*, not *Kobuletti*.

**What it is not.** The check does not run at all on a theatre the tools have no airdrome table
for: better to say nothing than to flag every airfield on an uncovered map. So silence does not
prove your name is right — it may simply mean the map is not known.

## A sub-zone is not declared {#validate-undeclared-subzone}

> Sub-zone 'ZONE-SOUTH' referenced by COMBATZONE.operation[OPERATION-TEST] is not declared as a
> combat_zones entry — the operation cannot resolve it at runtime.

**This one is not about the DCS editor at all.** It is entirely internal to your `mission.yaml`: an
operation chains combat zones through its `tasking_orders` and `dependencies`, and each must name a
`combat_zones` entry **in the same file**, one that is not itself an operation.

**The ways out.** Declare the missing zone under `combat_zones`, or fix the reference in the
tasking order.

**What it is not.** Not a missing trigger zone — the object being looked for is a YAML entry, not a
circle on the map.

## Going further {#more}

- [Build messages](README.en.md) — the other families
- [Combat zones](../concepts/combat-zones.en.md)
- [`mission.yaml` reference](../../MISSION_YAML_REFERENCE.en.md)
