# Phase 2 — prompts to edit an existing mission (a list, nothing coded)

Read from the action catalogue (`veaf_mission_mcp/actions.py`, 2026-11-27), for David to choose from. One prompt per family; each takes `mission` (the folder) plus the arguments below, and ends with `validate_mission` then `build_mission` once, as the guide says. Positions are DCS `x`/`y` already converted (the prompt says so), or a place name the model resolves with `geocode`. Every prompt cites only actions of this table.

A rule that holds for all: the prompt edits a **mission folder** (both worlds, durable), never a bare `.miz`.

## Things a mission maker adds

| Family | Typical arguments | Actions called |
|---|---|---|
| QRA | `base`, centre `x`/`y`, `rayon_km`, `appareils` (and the count that raises the tier), `delai_s` (from the **first intrusion**), `camp` | `create_qra`, `list_payloads` |
| Combat zone | `nom`, `x`/`y`, `rayon`, `contenu` (VEAF aliases), `camp`, active at start | `create_combat_zone`, `list_shortcuts` |
| Combat operation | `nom`, `titre`, the zones it holds, active at start | `add_combat_operation` |
| On-demand CAP | `nom`, `camp`, `appareils`, `x`/`y` of the orbit, F10 menu name | `create_cap_mission` |
| JTAC | `x`/`y`, `code_laser`, `frequence`, `modulation`, `nom`, `lieu`, `camp` | `add_group`, `set_mission_module` (`ASSETS`) |
| Ground group | `nom`, `camp`, `pays`, `type`/`nombre`, `x`/`y`, may not fire, route | `add_group`, `list_unit_types`, `list_countries` |
| Static (command post, depot) | `nom`, `camp`, `type`, `x`/`y` | `add_group` (category static) |
| Tanker / AWACS | `nom`, `type`, `x`/`y` of the track (two points), altitude, `frequence`, TACAN | `add_air_group`, `edit_route` (`tanker`/`awacs`, beacon, orbit) |
| AI flight on the ramp | `base`, `type`, `nombre`, `charge`, `camp` | `add_air_group`, `list_payloads` |
| Player slot | `base` or parking, `type`, `nombre` | `add_player_slot` |
| FARP | `nom`, `x`/`y`, `frequence`, `camp` | `add_farp` |
| Carrier group | `type` (Stennis, Roosevelt, Tarawa), `x`/`y`, `camp`, TACAN/ICLS/tower | `add_carrier_group` |
| F10 map drawing | `titre`, shape, points, `camp` | `add_map_drawing` |
| Sound | `fichier`, trigger | `add_sound` |

## Things a mission maker changes

| Family | Typical arguments | Actions called |
|---|---|---|
| Airfield | `nom`, `camp`, with or without dynamic slots, channels | `set_airbase_coalition`, `set_airfield_channels`, `describe_airfield_channels` |
| Move, rename or retune a group | `nom`, new `x`/`y`, new name, loadout, skill | `set_group_properties`, `set_unit_properties`, `describe_units` |
| Remove a group | `nom` | `remove_group` |
| Reshape a zone | `nom`, new `x`/`y` or radius | `edit_zone` |
| Players' flight plan | waypoints (name, `x`/`y`, altitude) | `set_route`, `edit_route` |
| Date, time, weather, bullseye | `date`, `heure`, wind, clouds, bullseye `x`/`y` | `set_mission_date`, `set_weather`, `set_bullseye` |
| Briefing | `titre`, situation, tasks per side, pictures | `set_briefing`, `set_briefing_picture`, `build_mission_briefing` |
| Modules and settings | module, on/off, security, forced options | `set_mission_module`, `set_mission_setting`, `set_mission_security`, `set_forced_options` |
| Training versions | roles (A2G, CAP, SEAD) | `propose_training_plan`, `set_training_plan` |

## Campaign

| Family | Typical arguments | Actions called |
|---|---|---|
| Next mission of a multi-mission campaign | `campagne` folder | `campaign_status`, `campaign_next`, `campaign_briefing` |
| Apply a flown mission | the state file | `campaign_apply`, `campaign_validate` |

## Where I would start (a recommendation, not a decision)

The five families a pilot asks for most, and that the Marteau du Golan trial exercised: **QRA**, **combat zone**, **JTAC**, **ground group**, **tanker / AWACS**. They also need the most arguments, so they gain most from a dialog. Settings and campaign actions are better left to the model reading the guide: their arguments are few or come from a file.

## Open points for David

1. Which families to build (all of the first table, or the five above).
2. The "change" family is a grey area: *move a group* needs the group's exact name, which the pilot does not know; the prompt would have to ask the model to list them first (`describe_mission`). Build it, or leave editing to a free request?
