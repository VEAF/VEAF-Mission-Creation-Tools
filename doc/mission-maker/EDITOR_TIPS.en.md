# Mission Editor tips

Trigger actions of the DCS Mission Editor that VMCT does not wrap, and that are worth knowing.
You set them by hand in the editor, in a VMCT mission as in any other: the build keeps the triggers you wrote.

Each tip says where what it states comes from.
**Read**: found in the editor's Lua files DCS ships in the clear (`MissionEditor/modules/me_trigrules.lua`, DCS 2.9.30); what the action really does is coded in the engine, so it is inferred from its parameters.
**Measured**: seen in game, with the date.

## What VMCT already does {#already-in-vmct}

Before setting a trigger, check that VMCT does not do it already:

| Need | In VMCT |
|------|---------|
| Enforce labels, the F10 view, external views… | `mission.forced_options` — see [the reference](../MISSION_YAML_REFERENCE.en.md#forced-options) |
| A make-believe artillery barrage on a zone | the `-shell`, `-cesar` and `-flak` shortcuts — see [the aliases](../ALIASES.en.md) |
| Mute DCS's ATC | `mission.silence_atc_on_all_airbases` |
| A smoke screen that blinds the AI | does not exist: **measured** 2026-10-08, smoke does not keep the AI from seeing and firing |
| Remove the trees of a zone (*SCENERY REMOVE OBJECTS ZONE*) | does not work: **measured** 2026-10-12, the forest stays |

## A failure on demand {#failure-on-demand}

*SET FAILURE* (`a_set_failure`) causes a failure on the player's aircraft.
**Read**: three parameters, the failure, a probability from 1 to 100 % and a random delay « Within (mm) » in minutes.
The list of failures is the one of the **player** aircraft selected in the editor when you set the action: a mission with several aircraft types can only aim at one type's failures at a time.

Typical use, for training: an F10 menu entry (*RADIO ITEM ADD FOR GROUP*) that raises a flag, and a *FLAG IS TRUE* → *SET FAILURE* trigger.
The instructor causes the failure when the student is ready.

## A group only the game master commands {#game-master-only}

*GROUP CONTROL GAMEMASTER ONLY* (`a_group_controllable_off`) keeps a group for the game master; *GROUP CONTROL DEFAULT* (`a_group_controllable_on`) gives it back to everyone.
**Read**: a single parameter, the group.
Useful for an opposing force played by a Combined Arms game master, that JTACs and tactical commanders must not be able to drive.
Game master slots are opened with `mission.ground_control` (see [the reference](../MISSION_YAML_REFERENCE.en.md#ground-control)).

## Animate an object {#play-argument}

*PLAY ARGUMENT* (`a_play_argument`) plays an animation of a 3D model, unit or static.
**Read**: the model's argument number (0 to 1000), a start position, an end position and a speed.
Examples: open a hangar's doors when an aircraft arrives, raise a barrier.
The argument number depends on the model; DCS's *Model Viewer* shows it.

## Change the briefing mid-mission {#briefing-update}

*SET BRIEFING* (`a_set_briefing`) replaces a coalition's briefing during the mission.
**Read**: the coalition, a picture and a text.
Useful for an operation in several phases: the phase 2 briefing shows once phase 1 is done, for the players who join along the way.

## Grow a zone {#zone-resize}

*(dev) ZONE_INCREMENT_SIZE* (`a_zone_increment_resize`) grows or shrinks a trigger zone.
**Read**: the zone and a number of metres, from -100 000 to 100 000.
The editor offers it despite its « (dev) » label.
Not seen in game yet: check it before relying on it (a front that moves, a no-go zone that spreads).

## Destroy a zone's scenery {#scenery-destruction}

*SCENERY DESTRUCTION ZONE* (`a_scenery_destruction_zone`) destroys the map objects in a zone.
**Read**: the zone and a destruction level from 0 to 100 %.
Example: a town already bombed when the mission starts.
Not seen in game yet; its neighbour *SCENERY REMOVE OBJECTS ZONE* removes nothing (see the table above), so check it before building a mission on it.

## See also {#see-also}

- [`mission.yaml` reference](../MISSION_YAML_REFERENCE.en.md) — what VMCT sets at every build.
- [Guide](GUIDE.en.md) — working in the editor inside a VMCT mission folder.
