"""Registers every mission-editing action this server ships into a catalog."""

from pathlib import Path
from typing import Any

from presets_injector.airfield_channels_manager import apply_airfield_channels, describe_airfield_channels
from veaf_libs.blank_mission import supported_theatres
from veaf_libs.clear_ground_check import offer_check
from veaf_libs.scenery_lookup import DEFAULT_RADIUS_METERS, offer_lookup

from veaf_mission_mcp.add_air_group import add_air_group
from veaf_mission_mcp.add_farp import add_farp
from veaf_mission_mcp.add_group import add_group
from veaf_mission_mcp.add_sound import add_sound
from veaf_mission_mcp.add_startup_script_trigger import add_startup_script_trigger
from veaf_mission_mcp.add_trigger_zone import add_trigger_zone
from veaf_mission_mcp.airbase import set_airbase_coalition
from veaf_mission_mcp.briefing_picture import set_briefing_picture
from veaf_mission_mcp.build_tools import build_mission, validate_mission
from veaf_mission_mcp.campaign import campaign_apply, campaign_briefing, campaign_next, campaign_status
from veaf_mission_mcp.carrier import CARRIER_TYPES, add_carrier_group
from veaf_mission_mcp.catalog import ActionCatalog
from veaf_mission_mcp.composites import add_combat_operation, create_cap_mission, create_combat_zone, create_qra
from veaf_mission_mcp.describe_mission import describe_mission
from veaf_mission_mcp.describe_units import describe_units
from veaf_mission_mcp.edit_mission_yaml import (
    describe_mission_config,
    set_mission_log_level,
    set_mission_module,
    set_mission_security,
    set_mission_setting,
)
from veaf_mission_mcp.edit_route import edit_route
from veaf_mission_mcp.edit_veaf_config import (
    set_log_level,
    set_module_enabled,
    set_security_disabled,
    set_veaf_config,
)
from veaf_mission_mcp.edit_zone import edit_zone
from veaf_mission_mcp.geo import geocode
from veaf_mission_mcp.group_naming import validate_group_name
from veaf_mission_mcp.map_drawings import add_map_drawing, edit_map_drawing
from veaf_mission_mcp.map_tools import describe_map, list_airfields, resolve_coordinates, resolve_coordinates_batch
from veaf_mission_mcp.mission_settings import set_briefing, set_bullseye, set_mission_date, set_weather
from veaf_mission_mcp.models import ActionSpec
from veaf_mission_mcp.oracle import (
    describe_known_limitations,
    describe_module,
    describe_naming_conventions,
    list_payloads,
    list_shortcuts,
    list_unit_types,
)
from veaf_mission_mcp.player_slot import add_player_slot
from veaf_mission_mcp.remove_group import remove_group
from veaf_mission_mcp.repair_static_shapes import repair_static_shapes
from veaf_mission_mcp.replace_in_files import replace_in_mission_files
from veaf_mission_mcp.scaffold import scaffold_mission
from veaf_mission_mcp.set_group_properties import set_group_properties
from veaf_mission_mcp.set_unit_properties import set_unit_properties
from veaf_mission_mcp.terrain import describe_terrain


def register_default_actions(catalog: ActionCatalog) -> None:
    """Register every action shipped by this server into `catalog`.

    Args:
        catalog: The catalog to populate.
    """
    catalog.register(
        ActionSpec(
            name="describe_mission",
            description=(
                "List the groups and trigger zones currently present in a mission's source "
                ".miz, for situational awareness before an editor-parity write."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                },
                "required": ["miz_path"],
            },
        ),
        handler=lambda params: describe_mission(Path(params["miz_path"])),
    )
    catalog.register(
        ActionSpec(
            name="describe_units",
            description=(
                "Describe a mission's groups down to their UNITS, LOADOUTS and ROUTES -- what "
                "describe_mission does not report. Use this before changing anything about a unit or a "
                "route: it gives each unit's type, skill, livery, callsign, onboard number, position, "
                "heading, fuel and its pylons keyed BY PYLON NUMBER (a real FA-18C carries stations 1, "
                "4, 5, 6 and 9, so the numbering matters), plus each group's task, frequency, hidden "
                "flags, uncontrolled/late-activation state, and its waypoints with their tasks. "
                "ALWAYS FILTER on a big mission: an adopted mission is megabytes of JSON, so pass "
                "group_name (a fragment is enough), coalition or category, and set include_route=false "
                "when the question is about loadouts. Read-only."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "The mission's source .miz, or a mission FOLDER."},
                    "group_name": {
                        "type": "string",
                        "description": "Keep only groups whose name contains this (case-insensitive).",
                    },
                    "coalition": {
                        "type": "string",
                        "enum": ["blue", "red", "neutrals"],
                        "description": "Keep only this coalition.",
                    },
                    "category": {
                        "type": "string",
                        "enum": ["plane", "helicopter", "vehicle", "ship", "static"],
                        "description": "Keep only this group category.",
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum groups returned (default 50). 'truncated' says whether it bit.",
                    },
                    "include_route": {
                        "type": "boolean",
                        "description": "Include each group's waypoints (default true). False omits the key.",
                    },
                },
                "required": ["miz_path"],
            },
        ),
        handler=lambda params: describe_units(
            Path(params["miz_path"]),
            group_name=params.get("group_name"),
            coalition=params.get("coalition"),
            category=params.get("category"),
            limit=params.get("limit"),
            include_route=params.get("include_route", True),
        ),
    )
    catalog.register(
        ActionSpec(
            name="set_mission_date",
            description=(
                "Set the mission's DATE and/or START TIME -- what the Mission Editor sets in its time "
                "panel. The blank mission of a scaffold is dated 2016; a Cold War mission wants 1980. The "
                "time is on the theatre's clock, the one DCS shows. The weather variants of versions.yaml "
                "still override both per variant at build. Target a FOLDER (durable) or a .miz; backed up."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target": {"type": "string", "description": "The mission FOLDER (durable) or a .miz."},
                    "date": {"type": "string", "description": "YYYY-MM-DD."},
                    "start_time": {"type": "string", "description": "HH:MM or HH:MM:SS, theatre clock."},
                },
                "required": ["target"],
            },
        ),
        handler=lambda p: set_mission_date(Path(p["target"]), date=p.get("date"), start_time=p.get("start_time")),
    )
    catalog.register(
        ActionSpec(
            name="set_weather",
            description=(
                "Set the BASE mission's weather, in the fields DCS reads: clouds, wind, temperature, "
                "visibility, rain, fog, QNH. The blank mission of a scaffold has its cloud base on the "
                "ground (Preset1 at 0 m). Same vocabulary as versions.yaml weather, and the same converter, "
                "so a METAR works too; the weather variants still override it per variant at build. "
                "Target a FOLDER (durable) or a .miz; backed up."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target": {"type": "string", "description": "The mission FOLDER (durable) or a .miz."},
                    "metar": {"type": "string", "description": "A METAR string; the fields below override it."},
                    "temperature": {"type": "number", "description": "Ground temperature, degrees C."},
                    "wind_speed": {"type": "number", "description": "Ground wind speed, m/s."},
                    "wind_direction": {
                        "type": "number",
                        "description": "Where the wind comes FROM, degrees (as in a METAR).",
                    },
                    "visibility": {"type": "number", "description": "Visibility, metres."},
                    "cloud_type": {
                        "type": "string",
                        "enum": ["clear", "few", "scattered", "broken", "overcast"],
                    },
                    "cloud_height": {"type": "number", "description": "Cloud base, metres."},
                    "precipitation": {"type": "boolean"},
                    "fog_enabled": {"type": "boolean"},
                    "clearsky": {
                        "type": "boolean",
                        "description": "Cap to VFR-friendly conditions (clouds at most FEW, wind < 15 kt, "
                        "10 km visibility, no rain, no fog).",
                    },
                },
                "required": ["target"],
            },
        ),
        handler=lambda p: set_weather(
            Path(p["target"]),
            **{key: value for key, value in p.items() if key != "target"},
        ),
    )
    catalog.register(
        ActionSpec(
            name="set_bullseye",
            description=(
                "Set one coalition's BULLSEYE. describe_map reads the bullseyes; this writes one. The build "
                "injects each flight plan's BULLSEYE waypoint from it and the in-game scripts announce "
                "positions relative to it, so set it early -- on a landmark. Target a FOLDER (durable) or "
                "a .miz; backed up."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target": {"type": "string", "description": "The mission FOLDER (durable) or a .miz."},
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutrals"]},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "Mission-table coordinates, as describe_map / geocode report them.",
                    },
                },
                "required": ["target", "coalition", "position"],
            },
        ),
        handler=lambda p: set_bullseye(Path(p["target"]), coalition=p["coalition"], position=p["position"]),
    )
    catalog.register(
        ActionSpec(
            name="set_briefing",
            description=(
                "Set the BRIEFING texts: the sortie name, the situation, and each coalition's task. Only "
                "the fields given change. A mission saved by the editor keeps this prose in its l10n "
                "dictionary behind DictKey_ references; the text is written where the mission already "
                "keeps it, so the reference stays valid. ${METAR} and the other briefing variables are "
                "substituted at build, per weather variant. Target a FOLDER (durable) or a .miz; backed up."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target": {"type": "string", "description": "The mission FOLDER (durable) or a .miz."},
                    "sortie": {"type": "string", "description": "The mission's name in the briefing."},
                    "situation": {"type": "string", "description": "The situation text (descriptionText)."},
                    "blue_task": {"type": "string"},
                    "red_task": {"type": "string"},
                    "neutrals_task": {"type": "string"},
                },
                "required": ["target"],
            },
        ),
        handler=lambda p: set_briefing(
            Path(p["target"]),
            sortie=p.get("sortie"),
            situation=p.get("situation"),
            blue_task=p.get("blue_task"),
            red_task=p.get("red_task"),
            neutrals_task=p.get("neutrals_task"),
        ),
    )
    catalog.register(
        ActionSpec(
            name="set_unit_properties",
            description=(
                "CHANGE a unit that already exists: its loadout, chaff and flare, skill, livery, heading, "
                "callsign, onboard number, name or position. Call describe_units FIRST -- this addresses the unit by its EXACT "
                "group name and unit name (a fragment is refused, so an edit cannot land on the wrong "
                "group), and pylons are keyed BY STATION NUMBER, which is not the position in a list. "
                "Only the fields you pass change; the result reports each previous value so you can "
                "tell the mission maker what you did. Two refusals worth knowing: skill accepts the "
                "five AI levels but NOT 'Client'/'Player' (those add or remove a multiplayer slot "
                "rather than set a skill), and changing a callsign's family needs its spoken name too. "
                "Mutates in place, backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {
                        "type": "string",
                        "description": (
                            "The mission's source .miz, OR the mission FOLDER -- same trade-off as "
                            "add_group's target: a folder edit is DURABLE (it goes into src/mission/ and "
                            "survives the next build), a .miz edit is transient (the next build overwrites "
                            "it). Backed up first either way."
                        ),
                    },
                    "group_name": {
                        "type": "string",
                        "description": "The group's EXACT name (not a fragment) -- as describe_units reports it.",
                    },
                    "unit_name": {"type": "string", "description": "The unit's exact name within that group."},
                    "skill": {
                        "type": "string",
                        "enum": ["Average", "Good", "High", "Excellent", "Random"],
                        "description": "AI competence. 'Client'/'Player' are refused: they are human slots.",
                    },
                    "livery": {
                        "type": "string",
                        "description": "Livery id. NOT validated -- DCS shows the default skin for an "
                        "unknown one without any error.",
                    },
                    "heading_deg": {
                        "type": "number",
                        "description": "Heading in DEGREES (0-360, normalised). Stored as radians for you.",
                    },
                    "callsign": {
                        "description": "Aircraft: an object with any of family/flight/number/name "
                        "(1..9 each); 'family' requires 'name' since the family->word table is not "
                        "shipped. 'name' is the word ('Texaco', completed to Texaco21 from flight and "
                        "number) or the full callsign ('Texaco21', kept). Ground unit: the bare number.",
                    },
                    "onboard_num": {
                        "type": "string",
                        "description": "Tail number, as text so a leading zero survives.",
                    },
                    "chaff": {
                        "type": "integer",
                        "description": "Chaff count. Omit to leave it alone.",
                    },
                    "flare": {
                        "type": "integer",
                        "description": "Flare count. Omit to leave it alone.",
                    },
                    "pylons": {
                        "type": "object",
                        "description": "Loadout as {station number: weapon CLSID} or {station number: "
                        "{CLSID: weapon CLSID}} (add_air_group's shape). BY STATION, not by position: a "
                        "real FA-18C carries 1, 4, 5, 6, 9. Any other value is refused. Omit to leave the "
                        "loadout alone; pass {} with mode 'replace' for a clean airframe.",
                    },
                    "pylons_mode": {
                        "type": "string",
                        "enum": ["replace", "merge"],
                        "default": "replace",
                        "description": "'replace' writes exactly the stations given; 'merge' updates "
                        "only those, and an empty CLSID empties that station.",
                    },
                    "new_name": {
                        "type": "string",
                        "description": "Rename this one unit. Refused when another unit already has the "
                        "name (DCS unit names are unique across the mission). Written as given, markers included.",
                    },
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "Move this one unit to {x, y} (DCS local metres); the group's "
                        "anchor and route stay where they are.",
                    },
                },
                "required": ["miz_path", "group_name", "unit_name"],
            },
        ),
        handler=_handle_set_unit_properties,
    )
    catalog.register(
        ActionSpec(
            name="set_group_properties",
            description=(
                "MOVE, RENAME or reconfigure a group that already exists. A move translates every "
                "unit, every waypoint AND the group anchor by one delta, so the formation keeps its "
                "shape and the route stays attached -- give it a bearing + distance (resolved "
                "geodesically, like geocode) or an explicit target. Frequency is checked against the "
                "airframe's own primary-frequency range, because the DCS editor REFUSES TO SAVE a "
                "mission that breaks it. A rename that would trigger a reserved VEAF convention is "
                "refused unless you acknowledge it -- naming a group after a combat zone's trigger "
                "zone makes the runtime despawn it at start. Unit names are never renamed with the "
                "group. A moved ground group or static that lands in the sea (ground 0 m), or a ship "
                "that lands on land, is warned about where the theatre has a swept elevation grid "
                "(terrain_elevation); without one the warning says the surface was not checked. "
                "Mutates in place, backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {
                        "type": "string",
                        "description": (
                            "The mission's source .miz, OR the mission FOLDER -- same trade-off as "
                            "add_group's target: a folder edit is DURABLE (it goes into src/mission/ and "
                            "survives the next build), a .miz edit is transient (the next build overwrites "
                            "it). Backed up first either way."
                        ),
                    },
                    "group_name": {"type": "string", "description": "The group's EXACT current name."},
                    "new_name": {
                        "type": "string",
                        "description": "New group name. Refused on a collision, or on a reserved VEAF "
                        "convention unless acknowledge_conventions is true.",
                    },
                    "move_to": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "Absolute destination for the group anchor. Not with a bearing.",
                    },
                    "move_bearing": {
                        "type": "number",
                        "description": "Bearing in degrees clockwise from north; needs move_distance_m.",
                    },
                    "move_distance_m": {
                        "type": "number",
                        "description": "Distance in METRES along move_bearing.",
                    },
                    "frequency_mhz": {
                        "type": "number",
                        "description": "Group primary frequency in MHz. Refused when the airframe "
                        "cannot tune it (the editor would refuse to save the mission).",
                    },
                    "modulation": {"type": "string", "enum": ["AM", "FM"]},
                    "late_activation": {"type": "boolean"},
                    "hidden": {"type": "boolean"},
                    "uncontrolled": {
                        "type": "boolean",
                        "description": "Aircraft group starts with engines off.",
                    },
                    "acknowledge_conventions": {
                        "type": "boolean",
                        "default": False,
                        "description": "Allow a rename that triggers a reserved VEAF convention. Only "
                        "pass this when the convention is what the mission maker asked for.",
                    },
                },
                "required": ["miz_path", "group_name"],
            },
        ),
        handler=_handle_set_group_properties,
    )
    catalog.register(
        ActionSpec(
            name="edit_route",
            description=(
                "EDIT a group's waypoints and what the flight DOES at them. Operations: add (append), "
                "insert (at a 1-based index), remove, reorder, set (name/altitude/speed/type/eta_locked/road), "
                "add_task, clear_tasks. Call describe_units first to see the route you are editing -- the "
                "result also returns the resulting route so you can check it. UNITS: altitude in FEET and "
                "speed in KNOTS (the mission file holds metres and m/s; the conversion is done for you). "
                "Tasks are a CLOSED named set -- orbit, land, attack_group, bombing, "
                "engage_targets_in_zone, set_frequency, switch_waypoint, and for support flights tanker, "
                "awacs, set_unlimited_fuel, eplrs, activate_beacon (a TACAN), escort, and transmit_message "
                "(a unit plays a sound on its radio -- a beacon a helicopter homes on; embed the sound with "
                "add_sound first, and put a set_frequency BEFORE it) -- each validating its own "
                "parameters, because a made-up task table is one DCS ignores in silence while the flight "
                "does nothing. Note set_frequency takes MHz here even though DCS stores hertz. Every "
                "operation guarantees at least one waypoint keeps a locked time, since DCS refuses to save "
                "a route without one. Mutates in place, backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {
                        "type": "string",
                        "description": (
                            "The mission's source .miz, OR the mission FOLDER -- same trade-off as "
                            "add_group's target: a folder edit is DURABLE (it goes into src/mission/ and "
                            "survives the next build), a .miz edit is transient (the next build overwrites "
                            "it). Backed up first either way."
                        ),
                    },
                    "group_name": {"type": "string", "description": "The group's EXACT name."},
                    "operation": {
                        "type": "string",
                        "enum": ["add", "insert", "remove", "reorder", "set", "add_task", "clear_tasks"],
                    },
                    "index": {
                        "type": "integer",
                        "description": "1-based waypoint the operation acts on (every operation but 'add').",
                    },
                    "to_index": {"type": "integer", "description": "Destination index, for 'reorder'."},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "Coordinates, for 'add' / 'insert'.",
                    },
                    "name": {"type": "string", "description": "Waypoint name."},
                    "altitude_ft": {"type": "number", "description": "Altitude in FEET."},
                    "speed_kt": {"type": "number", "description": "Speed in KNOTS."},
                    "waypoint_type": {
                        "type": "string",
                        "enum": [
                            "Turning Point",
                            "Fly Over Point",
                            "TakeOff",
                            "TakeOffParking",
                            "TakeOffParkingHot",
                            "TakeOffGround",
                            "TakeOffGroundHot",
                            "Land",
                        ],
                        "description": "Its matching DCS 'action' is written with it -- they are a pair.",
                    },
                    "eta_locked": {"type": "boolean", "description": "Whether this waypoint's time is locked."},
                    "road": {
                        "type": "boolean",
                        "description": (
                            "GROUND groups only, for add / insert / set: true writes 'On Road' (the "
                            "vehicles follow the roads), false 'Off Road' (straight across). Only a "
                            "Turning Point carries it."
                        ),
                    },
                    "task": {
                        "type": "string",
                        "enum": [
                            "orbit",
                            "land",
                            "attack_group",
                            "bombing",
                            "engage_targets_in_zone",
                            "set_frequency",
                            "switch_waypoint",
                            "tanker",
                            "awacs",
                            "set_unlimited_fuel",
                            "eplrs",
                            "activate_beacon",
                            "escort",
                            "transmit_message",
                        ],
                        "description": "For 'add_task'. Unknown names are refused rather than guessed.",
                    },
                    "task_position": {
                        "type": "integer",
                        "description": "For 'add_task': the 1-based place among the waypoint's tasks, the "
                        "others renumbered after it; appended when omitted. DCS runs tasks in order, so an "
                        "engagement placed after an orbit that never ends is never reached -- put it first.",
                    },
                    "task_params": {
                        "type": "object",
                        "description": "That task's parameters. orbit: pattern (Race-Track|Circle), "
                        "altitude_ft, speed_kt. land: position, duration_s. attack_group: group_id. "
                        "bombing: position, expend, attack_qty. engage_targets_in_zone: position, "
                        "radius_m, target_types. set_frequency: frequency_mhz, modulation (AM|FM). "
                        "switch_waypoint: to_index, from_index. tanker, awacs: none. set_unlimited_fuel: "
                        "value (default true). eplrs: value (default true). activate_beacon: channel (1-126), "
                        "mode (X|Y), callsign (1-3 letters/digits), bearing, aa. escort: group_name (the "
                        "escorted group, exact), engagement_distance_nm. transmit_message: sound (the key "
                        "add_sound returned, or the file name; refused when the mission does not hold it), "
                        "loop (default true), duration_s (default 5), subtitle (text).",
                    },
                },
                "required": ["miz_path", "group_name", "operation"],
            },
        ),
        handler=_handle_edit_route,
    )
    catalog.register(
        ActionSpec(
            name="edit_zone",
            description=(
                "RESHAPE, move, resize, rename, link or remove a trigger zone that already exists -- "
                "add_trigger_zone only creates circular ones. A VEAF combat zone IS a trigger zone, so "
                "this is how one gets adjusted instead of deleted and rebuilt. Pass 'vertices' (3 or "
                "more absolute x/y points) to make it a polygon following a ridge line; the VEAF "
                "runtime handles any polygon, but the DCS editor only DRAWS 4-point quads, so a "
                "different count is warned about. make_circular turns one back. Moving a polygon "
                "carries its vertices with it. 'link_unit' makes the zone follow a unit (a carrier) and "
                "is refused if that unit does not exist. A rename does NOT update what references the "
                "zone -- mission.yaml and member group prefixes need doing by hand, and the result says "
                "so. Mutates in place, backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {
                        "type": "string",
                        "description": (
                            "The mission's source .miz, OR the mission FOLDER -- same trade-off as "
                            "add_group's target: a folder edit is DURABLE (it goes into src/mission/ and "
                            "survives the next build), a .miz edit is transient (the next build overwrites "
                            "it). Backed up first either way."
                        ),
                    },
                    "zone_name": {"type": "string", "description": "The zone's EXACT current name."},
                    "new_name": {"type": "string", "description": "New name. Refused on a collision."},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "New centre. A polygon's vertices travel with it.",
                    },
                    "radius": {"type": "number", "description": "New radius in metres; must be positive."},
                    "vertices": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                            "required": ["x", "y"],
                        },
                        "description": "3+ ABSOLUTE points making the zone a polygon.",
                    },
                    "make_circular": {
                        "type": "boolean",
                        "default": False,
                        "description": "Turn a polygon back into a circle, dropping its vertices.",
                    },
                    "link_unit": {
                        "type": "string",
                        "description": "Unit name for the zone to follow; empty string unlinks.",
                    },
                    "remove": {
                        "type": "boolean",
                        "default": False,
                        "description": "Delete the zone. Cannot be combined with another change.",
                    },
                },
                "required": ["miz_path", "zone_name"],
            },
        ),
        handler=_handle_edit_zone,
    )
    catalog.register(
        ActionSpec(
            name="add_map_drawing",
            description=(
                "DRAW on the F10 map -- an FSCL, an ingress corridor, a no-fly box, a label. Worth doing "
                "here rather than in the editor because a hand-drawn shape is LOST when the mission is "
                "rebuilt from its folder, while this one is part of the recipe. Give ABSOLUTE mission "
                "coordinates; the relative anchoring DCS stores is done for you (getting that wrong puts "
                "a drawing hundreds of km away with no error). The LAYER decides who sees it and is "
                "never defaulted. Shapes: 'line' (2+ points, closed=true for an area), 'rect' "
                "(width/height), 'textbox' (text), 'circle' (radius), 'oval' (r1/r2/angle), 'free' (3+ "
                "points, a free-form filled polygon). 'arrow' and 'icon' are REFUSED with a reason "
                "(an arrow's outline needs an in-game round-trip; an icon needs a file from DCS's icon set)."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {
                        "type": "string",
                        "description": (
                            "The mission's source .miz, OR the mission FOLDER -- same trade-off as "
                            "add_group's target: a folder edit is DURABLE (it goes into src/mission/ and "
                            "survives the next build), a .miz edit is transient (the next build overwrites "
                            "it). Backed up first either way."
                        ),
                    },
                    "layer": {
                        "type": "string",
                        "enum": ["Red", "Blue", "Neutral", "Common", "Author"],
                        "description": "Who sees it. 'Common' is everyone; 'Author' is the maker's own layer.",
                    },
                    "shape": {"type": "string", "enum": ["line", "rect", "textbox", "circle", "oval", "free"]},
                    "name": {"type": "string", "description": "Name, used to edit or remove it later."},
                    "points": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                            "required": ["x", "y"],
                        },
                        "description": "ABSOLUTE coordinates for a 'line' (2+) or a 'free' polygon (3+).",
                    },
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "ABSOLUTE anchor for a rect, textbox, circle or oval.",
                    },
                    "text": {"type": "string", "description": "The label, for a textbox."},
                    "width": {"type": "number", "description": "Width in metres, for a rect."},
                    "height": {"type": "number", "description": "Height in metres, for a rect."},
                    "radius": {"type": "number", "description": "Radius in metres, for a circle."},
                    "r1": {"type": "number", "description": "Semi-axis in metres along the angle, for an oval."},
                    "r2": {"type": "number", "description": "The other semi-axis in metres, for an oval."},
                    "angle": {"type": "number", "default": 0},
                    "closed": {
                        "type": "boolean",
                        "default": False,
                        "description": "Join a line back up -- how a free-form area is drawn.",
                    },
                    "color": {"type": "string", "description": "Outline colour, DCS 0xRRGGBBAA string."},
                    "fill_color": {"type": "string", "description": "Fill colour, same format."},
                    "thickness": {"type": "number"},
                    "font_size": {"type": "integer", "description": "For a textbox."},
                },
                "required": ["miz_path", "layer", "shape", "name"],
            },
        ),
        handler=_handle_add_map_drawing,
    )
    catalog.register(
        ActionSpec(
            name="edit_map_drawing",
            description=(
                "MOVE, retitle, rename or REMOVE an F10 map drawing that already exists, addressed by "
                "its layer and name. Moving takes ABSOLUTE coordinates and only shifts the anchor -- the "
                "shape follows, since DCS stores a drawing's points relative to it. 'text' only works on "
                "a textbox. Mutates in place, backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {
                        "type": "string",
                        "description": (
                            "The mission's source .miz, OR the mission FOLDER -- same trade-off as "
                            "add_group's target: a folder edit is DURABLE (it goes into src/mission/ and "
                            "survives the next build), a .miz edit is transient (the next build overwrites "
                            "it). Backed up first either way."
                        ),
                    },
                    "layer": {
                        "type": "string",
                        "enum": ["Red", "Blue", "Neutral", "Common", "Author"],
                    },
                    "name": {"type": "string", "description": "The drawing's current name."},
                    "new_name": {"type": "string"},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "New ABSOLUTE anchor.",
                    },
                    "text": {"type": "string", "description": "New text; textbox only."},
                    "remove": {"type": "boolean", "default": False},
                },
                "required": ["miz_path", "layer", "name"],
            },
        ),
        handler=_handle_edit_map_drawing,
    )
    catalog.register(
        ActionSpec(
            name="add_group",
            description=(
                "Insert a ground/vehicle group into a mission, in place, backed up first. Mirrors "
                "adding a group by hand in the DCS Mission Editor -- not deduplicated, calling this "
                "twice creates two groups. Target a mission FOLDER for a durable group in the recipe "
                "(survives rebuild) -- e.g. a permanent SAM via a '#veafInterpreter[\"-samLR\"]' unit "
                "name -- or a .miz for a transient edit of the built mission."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target": {
                        "type": "string",
                        "description": "The mission FOLDER (durable, exploded src/mission/) or a .miz "
                        "(transient, built). Use the folder for standing content that must survive a rebuild.",
                    },
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutral"]},
                    "country_id": {"type": "integer", "description": "DCS numeric country id."},
                    "country_name": {"type": "string", "description": "DCS country name (e.g. 'Russia')."},
                    "category": {
                        "type": "string",
                        "enum": ["vehicle", "plane", "helicopter", "ship", "static"],
                    },
                    "name": {"type": "string", "description": "The group's name."},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "The group's anchor position.",
                    },
                    "units": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string", "description": "DCS unit type, e.g. 'BTR-80'."},
                                "count": {"type": "integer", "default": 1},
                                "name": {
                                    "type": "string",
                                    "description": "Optional explicit unit name (else auto-named). Carry a "
                                    "combat-zone marker here, e.g. '#command=\"-armor ...\"' for a spawn "
                                    "fake-unit (#command/#spawngroup/#spawnradius/#spawncount/#spawnchance/#spawndelay/#alarm).",
                                },
                            },
                            "required": ["type"],
                        },
                        "description": "Unit types are the calling LLM's decision, not this action's.",
                    },
                    "route": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                            "required": ["x", "y"],
                        },
                        "description": "Optional waypoints; defaults to a single stationary point at `position`.",
                    },
                    "patrol": {
                        "type": "boolean",
                        "default": False,
                        "description": "Loop the route's last waypoint back to the first.",
                    },
                    "for_combat_zone": {
                        "type": "string",
                        "description": "Combat-zone trigger-zone name to prefix the group name with "
                        "(so the zone picks it up). Idempotent.",
                    },
                    "late_activation": {
                        "type": "boolean",
                        "default": False,
                        "description": "Mark the group late-activation (QRA interceptors, CAP templates).",
                    },
                    "as_spawn_template": {
                        "type": "boolean",
                        "default": False,
                        "description": "Prefix the name with 'veafSpawn-' (spawnable-aircraft template).",
                    },
                    "keep_position": {
                        "type": "boolean",
                        "default": False,
                        "description": "Set it when the USER gave this exact position: the group is then never "
                        "moved. Otherwise a stationary vehicle group is put on ground measured clear of trees "
                        "and buildings, up to 1 km away (combat-zone markers included, sized from their "
                        "#command), and a warning says where it went or why it stayed. Relay that warning.",
                    },
                },
                "required": [
                    "target",
                    "coalition",
                    "country_id",
                    "country_name",
                    "category",
                    "name",
                    "position",
                    "units",
                ],
            },
        ),
        handler=_handle_add_group,
    )
    catalog.register(
        ActionSpec(
            name="add_player_slot",
            description=(
                "Create a flyable PLAYER SLOT -- the one thing add_group cannot, and the one thing a "
                "from-scratch mission needs before anybody can fly it. Builds an aircraft group with "
                "skill Client (playable in single-player too), a group radio frequency, and "
                "dynSpawnTemplate cleared -- that flag marks a dynamic-spawn TEMPLATE, which needs an "
                "airfield configured for it, and leaving it set is what made a hand-placed slot appear "
                "in the file but not in the slot list. Three starts: 'air' (position + altitude + speed, "
                "needs no runtime data) and 'ground-cold'/'ground-hot' (you supply the parking spot -- "
                "parking, parking_id and airdrome_id). A ground start with no spot is REFUSED rather "
                "than guessed: airfield parking is FEAT-MCP-MUTATION-ACTIONS ticket 09's captured data. "
                "The first waypoint's type/action pair is written for you. Also assigns the country to "
                "its side (coalitions), so the mission stays loadable. Does NOT change an existing "
                "unit's skill. Target a FOLDER (durable) or a .miz (transient); backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target": {
                        "type": "string",
                        "description": "The mission FOLDER (durable, exploded src/mission/) or a .miz (transient).",
                    },
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutral"]},
                    "country_id": {"type": "integer", "description": "DCS numeric country id."},
                    "country_name": {"type": "string", "description": "DCS country name (e.g. 'USA')."},
                    "name": {"type": "string", "description": "The group's name."},
                    "unit_type": {
                        "type": "string",
                        "description": "DCS aircraft type, e.g. 'A-10C_2' -- the caller's decision.",
                    },
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "The slot's anchor position.",
                    },
                    "start": {
                        "type": "string",
                        "enum": ["air", "ground-cold", "ground-hot"],
                        "default": "air",
                        "description": "Air start, or a cold/hot ground start (needs a parking spot).",
                    },
                    "altitude_ft": {
                        "type": "number",
                        "default": 15000,
                        "description": "Air-start altitude in FEET (ignored on the ground).",
                    },
                    "speed_kt": {"type": "number", "default": 250, "description": "Speed in KNOTS."},
                    "heading_deg": {
                        "type": "number",
                        "default": 0,
                        "description": "Heading in degrees (mainly meaningful on the ground).",
                    },
                    "parking": {
                        "type": "string",
                        "description": "Parking-spot number (ground start), as text so a leading zero survives.",
                    },
                    "parking_id": {
                        "type": "string",
                        "description": "Parking id -- the slot's Term_Index (ground start), as text.",
                    },
                    "airdrome_id": {
                        "type": "integer",
                        "description": "Airfield id the parking belongs to (ground start).",
                    },
                    "frequency_mhz": {
                        "type": "number",
                        "default": 251,
                        "description": "Group radio frequency in MHz (written, not inherited).",
                    },
                    "onboard_num": {
                        "type": "string",
                        "description": "Tail number, as text so a leading zero survives. Omit for one no "
                        "other aircraft of the mission carries.",
                    },
                    "task": {
                        "type": "string",
                        "default": "Nothing",
                        "description": "Aircraft-group task (default 'Nothing').",
                    },
                    "fuel": {
                        "type": "number",
                        "description": (
                            "Fuel load in KILOGRAMS. Omit for full internal fuel, read from the units "
                            "database -- an aircraft created with none falls out of the sky."
                        ),
                    },
                    "fuel_fraction": {
                        "type": "number",
                        "description": "Fraction of internal capacity, in ]0, 1]. Alternative to 'fuel'.",
                    },
                    "chaff": {
                        "type": "integer",
                        "description": "Chaff count per aircraft. Omit for the type's Mission Editor default "
                        "(F-14B 140, F/A-18C 60; 0 for a type with no dispenser).",
                    },
                    "flare": {
                        "type": "integer",
                        "description": "Flare count per aircraft. Omit for the type's Mission Editor default.",
                    },
                },
                "required": [
                    "target",
                    "coalition",
                    "country_id",
                    "country_name",
                    "name",
                    "unit_type",
                    "position",
                ],
            },
        ),
        handler=_handle_add_player_slot,
    )
    catalog.register(
        ActionSpec(
            name="add_air_group",
            description=(
                "Put a FLIGHT on the ramp -- 'a two-ship of F-16s at Incirlik' -- resolving the "
                "parking stands itself from the captured airfield data, which add_player_slot (one "
                "aircraft, caller supplies the spot) does not. Give an airfield NAME and a count; it "
                "picks that many free aircraft stands the mission does not already occupy, nearest to "
                "the runway first, and seats each aircraft on its stand. A stand already taken is "
                "REFUSED naming the group that holds it; an airfield with no aircraft stands, an "
                "unknown airfield, or a theatre with no captured parking data is refused rather than "
                "guessed. skill defaults to an AI level (a ramp flight is AI unless you ask for "
                "'Client'). Starts: parking-cold / parking-hot (need 'airfield'), runway (needs "
                "'airfield'), air (needs 'position'), deck-cold / deck-hot (need 'carrier'). Each aircraft "
                "gets its type's default chaff and flare, a callsign and a tail number no other aircraft of "
                "the mission carries; a western flight NAMED like its callsign ('Texaco 2', 'Magic 1') gets "
                "that callsign (Texaco21...) when its family fits the task and the flight is free, else the "
                "next free one and a warning. A fighting task (Escort, CAP, CAS, SEAD...) with no pylons "
                "warns for an AI flight. Target a FOLDER (durable) or .miz (transient); backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target": {
                        "type": "string",
                        "description": "The mission FOLDER (durable, exploded src/mission/) or a .miz (transient).",
                    },
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutral"]},
                    "country_id": {"type": "integer", "description": "DCS numeric country id."},
                    "country_name": {"type": "string", "description": "DCS country name (e.g. 'USA')."},
                    "name": {"type": "string", "description": "The group's name."},
                    "unit_type": {"type": "string", "description": "DCS aircraft type, e.g. 'F-16C_50'."},
                    "count": {
                        "type": "integer",
                        "default": 1,
                        "description": "Aircraft in the flight; each gets its own stand for a parking start.",
                    },
                    "start": {
                        "type": "string",
                        "enum": ["parking-cold", "parking-hot", "runway", "air", "deck-cold", "deck-hot"],
                        "default": "parking-cold",
                        "description": "Parking (needs airfield), runway (needs airfield), air (needs position), "
                        "or on a ship's deck (needs carrier).",
                    },
                    "carrier": {
                        "type": "string",
                        "description": "For a deck start: the ship UNIT's name (add_carrier_group returns it). Each "
                        "aircraft takes the next deck spot; an aircraft that cannot use that deck is refused.",
                    },
                    "airfield": {
                        "type": "string",
                        "description": "Airfield NAME (e.g. 'Incirlik') — required for a parking or runway start.",
                    },
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "Anchor for an air start.",
                    },
                    "altitude_ft": {"type": "number", "default": 15000, "description": "Air-start altitude in FEET."},
                    "speed_kt": {"type": "number", "default": 250, "description": "Speed in KNOTS."},
                    "heading_deg": {"type": "number", "default": 0, "description": "Heading in degrees."},
                    "skill": {
                        "type": "string",
                        "default": "High",
                        "description": "AI level, or 'Client'/'Player' for human slots.",
                    },
                    "frequency_mhz": {"type": "number", "default": 251, "description": "Group radio frequency in MHz."},
                    "task": {
                        "type": "string",
                        "default": "CAS",
                        "description": "Aircraft-group task. 'AFAC' makes a LASER DRONE (an MQ-9 with an air "
                        "start over its zone): its first point gets unlimited fuel and a circle orbit at "
                        "altitude_ft / speed_kt (an AFAC on another start gets a warning instead). The lasing is CTLD's: declare the group in modules.ASSETS "
                        "with jtac (laser code), freq and mod. Checked in game: CTLD moves it to "
                        "JTAC_droneAltitude (3000 m AGL) whatever is written, it designates VEHICLES only, "
                        "and within 10 km.",
                    },
                    "parking": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Optional explicit stand numbers (one per aircraft), overriding auto-selection.",
                    },
                    "fuel": {
                        "type": "number",
                        "description": (
                            "Fuel load in KILOGRAMS. Omit for full internal fuel, read from the units "
                            "database -- an aircraft created with none falls out of the sky."
                        ),
                    },
                    "fuel_fraction": {
                        "type": "number",
                        "description": "Fraction of internal capacity, in ]0, 1]. Alternative to 'fuel'.",
                    },
                    "chaff": {
                        "type": "integer",
                        "description": "Chaff count per aircraft. Omit for the type's Mission Editor default "
                        "(F-14B 140, F/A-18C 60; 0 for a type with no dispenser).",
                    },
                    "flare": {
                        "type": "integer",
                        "description": "Flare count per aircraft. Omit for the type's Mission Editor default.",
                    },
                    "late_activation": {
                        "type": "boolean",
                        "default": False,
                        "description": "Late activation (a QRA interceptor, an on-demand template).",
                    },
                    "pylons": {
                        "type": "object",
                        "description": 'Loadout, {station: {"CLSID": ...}} as the mission file stores it.',
                    },
                    "payload": {
                        "type": "string",
                        "description": "A DCS loadout by the name the Mission Editor lists (list_payloads gives "
                        "a type's names), instead of 'pylons'.",
                    },
                },
                "required": ["target", "coalition", "country_id", "country_name", "name", "unit_type"],
            },
        ),
        handler=_handle_add_air_group,
    )
    catalog.register(
        ActionSpec(
            name="remove_group",
            description=(
                "REMOVE a group from the mission -- the one group-level edit the catalogue was "
                "missing, which is why removal used to be done by hand. Hand-deleting a Lua block "
                "leaves the enclosing list numbered 1,3,4: Lua loads that fine and the BUILD dies "
                "on a traceback pointing nowhere near the edit, so this action RENUMBERS the "
                "survivors to 1..n and drops the 'group' key entirely when it takes the last one. "
                "Addresses the group by EXACT name (a fragment is refused). It does not refuse on "
                "account of references -- you may well mean it -- but it NAMES the ones that would "
                "break in silence: a combat zone capturing the group by name prefix, an Escort task "
                "pointing at its group id, and a mission.yaml modules.ASSETS entry naming it. "
                "Target a FOLDER (durable) or .miz (transient); backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target": {
                        "type": "string",
                        "description": "The mission FOLDER (durable, exploded src/mission/) or a .miz (transient).",
                    },
                    "group_name": {
                        "type": "string",
                        "description": "The group's EXACT name -- as describe_units reports it, not a fragment.",
                    },
                },
                "required": ["target", "group_name"],
            },
        ),
        handler=_handle_remove_group,
    )
    catalog.register(
        ActionSpec(
            name="add_trigger_zone",
            description=(
                "Insert a named circular trigger zone into a mission's source .miz, in place, "
                "backed up first. This is the zone a VEAF combat zone references; combine with "
                "add_group to lay down a full combat zone. Not deduplicated."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {
                        "type": "string",
                        "description": (
                            "The mission's source .miz, OR the mission FOLDER -- same trade-off as "
                            "add_group's target: a folder edit is DURABLE (it goes into src/mission/ and "
                            "survives the next build), a .miz edit is transient (the next build overwrites "
                            "it). Backed up first either way."
                        ),
                    },
                    "name": {"type": "string", "description": "The zone's name."},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "The zone centre.",
                    },
                    "radius": {"type": "number", "description": "The zone radius, in metres."},
                    "hidden": {"type": "boolean", "default": False},
                    "color": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "RGBA fill [r, g, b, a] (0..1). Defaults to translucent white.",
                    },
                },
                "required": ["miz_path", "name", "position", "radius"],
            },
        ),
        handler=_handle_add_trigger_zone,
    )
    catalog.register(
        ActionSpec(
            name="add_startup_script_trigger",
            description=(
                "Add a mission-start trigger that runs a script — for outfitting a vanilla or "
                "CTLD mission with scripting without the DCS editor. Modes: 'inline' (run Lua), "
                "'file_static' (embed a .lua into the .miz and load it), 'file_dynamic' (load a "
                ".lua from a runtime disk path). Backed up first; not deduplicated."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "mode": {"type": "string", "enum": ["inline", "file_static", "file_dynamic"]},
                    "comment": {"type": "string", "description": "The trigger's editor label."},
                    "inline_lua": {"type": "string", "description": "Lua to run (mode='inline')."},
                    "source_path": {
                        "type": "string",
                        "description": "Path to the .lua file to embed (mode='file_static').",
                    },
                    "runtime_path": {
                        "type": "string",
                        "description": "Disk path DCS loadfile's at runtime (mode='file_dynamic').",
                    },
                    "resource_name": {
                        "type": "string",
                        "description": "Basename to embed the static file under (defaults to the source name).",
                    },
                },
                "required": ["miz_path", "mode", "comment"],
            },
        ),
        handler=_handle_add_startup_script_trigger,
    )
    catalog.register(
        ActionSpec(
            name="replace_in_mission_files",
            description=(
                "Generic text/regex search-replace across a mission's embedded Lua files "
                "(restricted to l10n/DEFAULT/**/*.lua — never the raw mission/options tables or "
                "binaries). Edits the built .miz in place, backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "search": {"type": "string", "description": "Text (or regex if `regex`) to find."},
                    "replace": {"type": "string", "description": "Replacement (regex backrefs allowed if `regex`)."},
                    "files": {
                        "type": "string",
                        "default": "*.lua",
                        "description": "Glob against each .lua's path relative to l10n/DEFAULT/ (e.g. 'veaf-*.lua').",
                    },
                    "regex": {"type": "boolean", "default": False},
                },
                "required": ["miz_path", "search", "replace"],
            },
        ),
        handler=_handle_replace_in_mission_files,
    )
    catalog.register(
        ActionSpec(
            name="set_log_level",
            description="Set the global VEAF log level (veaf.ForcedLogLevel) in a built mission, without a rebuild.",
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "level": {"type": "string", "enum": ["error", "warning", "info", "debug", "trace"]},
                },
                "required": ["miz_path", "level"],
            },
        ),
        handler=lambda p: set_log_level(Path(p["miz_path"]), p["level"]),
    )
    catalog.register(
        ActionSpec(
            name="set_module_enabled",
            description="Enable/disable a VEAF module (veaf.setConfig(<MOD>, 'enable', <bool>)) in a built mission.",
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "module_id": {"type": "string", "description": "Module id, e.g. 'QRA', 'COMBATZONE'."},
                    "enabled": {"type": "boolean"},
                },
                "required": ["miz_path", "module_id", "enabled"],
            },
        ),
        handler=lambda p: set_module_enabled(Path(p["miz_path"]), p["module_id"], p["enabled"]),
    )
    catalog.register(
        ActionSpec(
            name="set_security_disabled",
            description="Set the VEAF security flag (veaf.SecurityDisabled) in a built mission.",
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "disabled": {"type": "boolean", "description": "true = no password required."},
                },
                "required": ["miz_path", "disabled"],
            },
        ),
        handler=lambda p: set_security_disabled(Path(p["miz_path"]), p["disabled"]),
    )
    catalog.register(
        ActionSpec(
            name="set_veaf_config",
            description="Set an arbitrary veaf.config.<key> scalar value in a built mission.",
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "key": {"type": "string", "description": "The config key (bare Lua identifier)."},
                    "value": {"description": "A scalar (bool/int/float/string)."},
                },
                "required": ["miz_path", "key", "value"],
            },
        ),
        handler=lambda p: set_veaf_config(Path(p["miz_path"]), p["key"], p["value"]),
    )
    catalog.register(
        ActionSpec(
            name="describe_mission_config",
            description=(
                "List the modules block of a mission's source mission.yaml (the declarative "
                "VMCT config the build consumes), and each module's state (mandatory / "
                "enabled scalar / extended config mapping). Read-only; the VMCT counterpart "
                "of describe_mission."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Path to the mission's source mission.yaml.",
                    },
                },
                "required": ["mission_yaml_path"],
            },
        ),
        handler=lambda p: describe_mission_config(Path(p["mission_yaml_path"])),
    )
    catalog.register(
        ActionSpec(
            name="validate_group_name",
            description=(
                "Check a proposed group name against the reserved VEAF naming conventions "
                "(veafSpawn-/OnDemand-/VEAF-placeholder- prefixes, #veafInterpreter/#command "
                "markers, QRA deploy syntax, fixed CAS names). With a miz_path, also flags the "
                "combat-zone capture trap. Read-only; call before add_group."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "The proposed group name."},
                    "miz_path": {
                        "type": "string",
                        "description": (
                            "Optional .miz OR mission folder to check the combat-zone capture trap against."
                        ),
                    },
                    "expected_combat_zone": {
                        "type": "string",
                        "description": "A combat zone the group is intentionally attached to (suppresses its capture warning).",
                    },
                },
                "required": ["name"],
            },
        ),
        handler=lambda p: validate_group_name(
            p["name"],
            miz_path=Path(p["miz_path"]) if p.get("miz_path") else None,
            expected_combat_zone=p.get("expected_combat_zone"),
        ),
    )
    catalog.register(
        ActionSpec(
            name="set_mission_module",
            description=(
                "Enable/disable a VEAF module or set its extended config block in a mission's "
                "source mission.yaml, comments preserved, backed up first. Pass `value` as a "
                "boolean for the scalar form (MODULE: true/false) or as an object for the "
                "extended block (e.g. a COMBATZONE/CTLD config). Inserts the key if absent."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Path to the mission's source mission.yaml.",
                    },
                    "module_id": {"type": "string", "description": "Module key, e.g. 'CTLD', 'COMBATZONE'."},
                    "value": {
                        "type": ["boolean", "object"],
                        "description": "Boolean toggle, or an object for the extended config block.",
                    },
                },
                "required": ["mission_yaml_path", "module_id", "value"],
            },
        ),
        handler=lambda p: set_mission_module(Path(p["mission_yaml_path"]), p["module_id"], p["value"]),
    )
    catalog.register(
        ActionSpec(
            name="set_mission_log_level",
            description=(
                "Set the global VEAF log level in the source mission.yaml (global_log_level). "
                "Source/recipe counterpart of set_log_level (which edits the built veaf-config.lua)."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Path to the mission's source mission.yaml.",
                    },
                    "level": {"type": "string", "enum": ["error", "warning", "info", "debug", "trace"]},
                },
                "required": ["mission_yaml_path", "level"],
            },
        ),
        handler=lambda p: set_mission_log_level(Path(p["mission_yaml_path"]), p["level"]),
    )
    catalog.register(
        ActionSpec(
            name="set_mission_security",
            description=(
                "Set the security: block in the source mission.yaml (disabled flag + optional "
                "JTF/Mission-Master password hashes). Source counterpart of set_security_disabled, "
                "and covers the hashes the built-side action does not."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Path to the mission's source mission.yaml.",
                    },
                    "disabled": {"type": "boolean", "description": "true = no password required."},
                    "password_hashes": {"type": "array", "items": {"type": "string"}},
                    "password_mm_hashes": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["mission_yaml_path", "disabled"],
            },
        ),
        handler=lambda p: set_mission_security(
            Path(p["mission_yaml_path"]),
            p["disabled"],
            password_hashes=p.get("password_hashes"),
            password_mm_hashes=p.get("password_mm_hashes"),
        ),
    )
    catalog.register(
        ActionSpec(
            name="set_mission_setting",
            description=(
                "Set an arbitrary settings.<key> in the source mission.yaml (rendered to "
                "veaf.config.<key> at build). Source counterpart of set_veaf_config."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Path to the mission's source mission.yaml.",
                    },
                    "key": {"type": "string", "description": "The setting key."},
                    "value": {"description": "The value (scalar or structure)."},
                },
                "required": ["mission_yaml_path", "key", "value"],
            },
        ),
        handler=lambda p: set_mission_setting(Path(p["mission_yaml_path"]), p["key"], p["value"]),
    )
    _campaign_folder = {
        "type": "string",
        "description": "Path to the campaign folder (campaign.yaml, campaign-state.yaml, template/, missions/).",
    }
    catalog.register(
        ActionSpec(
            name="campaign_status",
            description=(
                "Read where a multi-mission campaign stands: missions flown, each zone's owner, garrison "
                "strength, kind and neighbours, both sides' ground reserves, each campaign objective met or "
                "not, and what changed in the last mission. Call it FIRST, before deciding the next "
                "mission: the enemy's intent for the turn (where it reinforces, what it defends) is yours "
                "to decide from this, and goes into the next mission's briefing. Read-only."
            ),
            parameters_schema={
                "type": "object",
                "properties": {"campaign_folder": _campaign_folder},
                "required": ["campaign_folder"],
            },
        ),
        handler=lambda p: campaign_status(Path(p["campaign_folder"])),
    )
    catalog.register(
        ActionSpec(
            name="campaign_apply",
            description=(
                "Apply a flown campaign mission: merge the state file the mission wrote "
                "(Saved Games/DCS/Missions/Saves/<campaign>/mission-NN.state, fetched from the server) into "
                "the campaign state, then play the fixed rules of the turn between missions (logistics feed "
                "the reserves, the reserves repair garrisons, a neutral zone bordered by one side only is "
                "retaken by it) and judge the objectives. Refuses a file already applied, from another "
                "campaign, or skipping a mission; nothing is written then. Keeps the before/after state "
                "and a factual debriefing (French and English) under missions/mission-NN/, and returns "
                "that debriefing: tell it to the squadron as the story of the evening when asked -- who "
                "lost what where, what changed hands, what the enemy will make of it -- keeping to its "
                "facts."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "campaign_folder": _campaign_folder,
                    "state_file": {"type": "string", "description": "The state file the mission wrote."},
                },
                "required": ["campaign_folder", "state_file"],
            },
        ),
        handler=lambda p: campaign_apply(Path(p["campaign_folder"]), Path(p["state_file"])),
    )
    catalog.register(
        ActionSpec(
            name="campaign_next",
            description=(
                "Lay down the next campaign mission's FOLDER (missions/mission-NN/mission), copied from the "
                "campaign's template/ mission folder on the first run and only refreshed afterwards, so the "
                "design already done in it survives: every campaign airbase given to its owner (dynamic "
                "slots for each side's bases, none on a neutral one), the campaign data table the runtime "
                "reads (garrisons with their losses, reserves, destroyed scenery), the CAMPAIGN module "
                "turned on in mission.yaml, the strategic situation as the mission's DCS briefing on a "
                "folder it creates, and the strategic briefing deck next to it (see campaign_briefing). "
                "A folder it CREATES also gets its date, start time and weather, FIXED in the mission: ONE "
                "mission, NO weather variant (pipeline.weather: false, no src/versions.yaml -- never add "
                "one back). The date is the day after the last mission flown (campaign.yaml start_date for "
                "the first), the time campaign.yaml start_time (default sunrise+30*60) computed on the "
                "campaign's own ground, the weather drawn within ground-visible limits (clear, few or "
                "scattered clouds, visibility 8 km or more, no fog, no rain: CAVOK or nearly), returned in "
                "`conditions`. YOU set the date and time from the campaign's progress, in every campaign "
                "mission you prepare: move the date on further when the story needs it, set the hour the "
                "mission wants (set_mission_date); you may change the weather (set_weather) but keep the "
                "ground visible. A refresh keeps what you set. "
                "Returns the folder and the FACTUAL part of the strategic briefing in French and English: "
                "design the mission on top of that folder with the other actions. When you write the DCS "
                "briefing (set_briefing), ADD to the factual block already there, never replace it. "
                "PLAYERS: ask the mission maker how many players are expected tonight and pass it as "
                "'players' (6, or a range \"5-7\"); without it, campaign.yaml's players is used. It writes "
                "the mission's opposition: block (level = the most expected, following the players "
                "connected). Give the enemy QRA tiers by enemy count up to that size (see create_qra)."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "campaign_folder": _campaign_folder,
                    "players": {
                        "type": ["integer", "string"],
                        "description": 'Players expected tonight: a count (6) or a range ("5-7").',
                    },
                },
                "required": ["campaign_folder"],
            },
        ),
        handler=lambda p: campaign_next(Path(p["campaign_folder"]), p.get("players")),
    )
    catalog.register(
        ActionSpec(
            name="campaign_briefing",
            description=(
                "Write the coming mission's strategic briefing deck (missions/mission-NN/"
                "briefing-campagne.pptx, VEAF briefing template, imports into Google Slides) and its "
                "strategic map; once the mission is BUILT (a .miz in missions/mission-NN/mission), also its "
                "own MISSION briefing (briefing-mission.pptx, returned in `mission_deck`): general "
                "situation, ATO, tactical map and one zoom per objective, mission flow, frequency plan, "
                "objective coordinates -- read from the built mission (flights, support, carrier, QRA, "
                "date, time, weather), so build first, and call it again after any change to the mission. "
                "Its objectives are the zones the mission's task titles name in briefing.yaml. "
                "The tools generate the FACTS: the enemy as uneven intelligence, the "
                "friendly positions and reserves, the map, the conditions of victory, and an annex of the "
                "campaign's rules. The PROSE is yours, in briefing.yaml next to campaign.yaml (sections "
                "returned in `sections`; texts are a string or a list of paragraphs, quoted when they hold ': '): "
                "operation, subtitle; "
                "situation.political / economic / enemy_course_of_action / friendly; mission; "
                "intent.purpose / main_effect / method / end_state; objectives.political / military / "
                "economic; concept.phases (one {title, text} per mission at most) and concept.attention; "
                "rules_of_engagement.targeting / civilians / self_defence; missions: {N: {title, tasks: "
                "[{title, text}]}}. Write it as a MILITARY SITUATION BRIEF, the language of a staff: "
                "political, economic and military situation, mission and intent, objectives by nature, "
                "concept by phase, rules of engagement. NO GAME MECHANICS in it -- garrisons drawn from a "
                "reserve, a capture clock, a circle to hold belong to the generated annex. The ENEMY STAYS "
                "MYSTERIOUS: no figure, no count, intelligence of uneven quality; a fixed site (a long-range "
                "SAM) is named by the tools once the campaign state records it, never before. The scenario "
                "is fiction on real ground: places from geocode / list_airfields, never from memory. After "
                "each mission, rewrite the coming mission's page and the concept's progress from the "
                "debriefing campaign_apply returned, and keep the rest unless the situation changed it. "
                "Give zones a display_name in campaign.yaml when their name is not the players' language."
            ),
            parameters_schema={
                "type": "object",
                "properties": {"campaign_folder": _campaign_folder},
                "required": ["campaign_folder"],
            },
        ),
        handler=lambda p: campaign_briefing(Path(p["campaign_folder"])),
    )
    catalog.register(
        ActionSpec(
            name="scaffold_mission",
            description=(
                "Scaffold a fresh VEAF mission FOLDER from an empty folder, driving the real VEAF "
                "bootstrap: download the updater from the release, run it (installs the tools and "
                "published/ into the folder), then 'veaf-tools prepare' for the chosen template. "
                "Step 0 of a from-scratch mission, before the create_* composites. Refuses a "
                "non-empty folder. Ask the maker which template first. If the mission targets a "
                "supported DCS map (see the 'theatre' enum), ALSO pass 'theatre' so a loadable "
                "blank mission for that map is laid down in src/mission — omit it and src/mission "
                "stays empty, leaving nothing for validate/build to work on."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target_folder": {"type": "string", "description": "Empty folder to initialize."},
                    "template": {
                        "type": "string",
                        "enum": ["minimal", "standard", "full"],
                        "description": "Coverage tier (custom is not supported here).",
                    },
                    "theatre": {
                        "type": "string",
                        "enum": supported_theatres(),
                        "description": "DCS theatre for the mission — lays down a loadable synthetic blank mission "
                        "for that map in src/mission (no DCS round-trip). Pass it whenever the mission targets one "
                        "of the supported maps (the enum values); omit ONLY if the maker will supply their own "
                        ".miz, since otherwise src/mission is left empty.",
                    },
                    "github_token": {
                        "type": "string",
                        "description": "Optional GitHub token, relayed to the updater to bypass the API rate limit.",
                    },
                    "tag": {
                        "type": "string",
                        "description": "Release tag to install from (default 'published-latest').",
                    },
                },
                "required": ["target_folder", "template"],
            },
        ),
        handler=lambda p: scaffold_mission(
            p["target_folder"],
            template=p["template"],
            theatre=p.get("theatre"),
            github_token=p.get("github_token"),
            tag=p.get("tag"),
        ),
    )
    catalog.register(
        ActionSpec(
            name="validate_mission",
            description=(
                "Lint a mission FOLDER before building: reports config/runtime issues as errors and "
                "warnings (ok=false when any error). In-process; run before build_mission."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "folder_path": {"type": "string", "description": "Path to the mission folder."},
                },
                "required": ["folder_path"],
            },
        ),
        handler=lambda p: validate_mission(Path(p["folder_path"])),
    )
    catalog.register(
        ActionSpec(
            name="build_mission",
            description=(
                "Build a mission FOLDER into a playable .miz by running 'veaf-tools build' in it "
                "(the binary scaffold_mission installed, or veaf-tools on PATH). The final step of "
                "the create -> edit -> validate -> build -> play loop. A build failure is surfaced."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "folder_path": {"type": "string", "description": "Path to the mission folder to build."},
                    "profile": {
                        "type": "string",
                        "description": "Optional build profile, passed as 'veaf-tools build --profile' "
                        "(e.g. LOCAL_TEST for a local test build). Omitted: the mission's own profiles.",
                    },
                },
                "required": ["folder_path"],
            },
        ),
        handler=lambda p: build_mission(Path(p["folder_path"]), profile=p.get("profile")),
    )
    catalog.register(
        ActionSpec(
            name="add_farp",
            description=(
                "Place a COMPLETE FARP: the heliport static (FARP, Invisible FARP, SINGLE_HELIPAD...), its "
                "radio frequency and callsign, and the warehouse entry that lets helicopters refuel and "
                "rearm there, and by default its ammunition dump ('<name> - Ammo', a FARP Ammo Dump "
                "Coating 120 m east) that CTLD takes as a loading point. add_group with category 'static' "
                "places the object ALONE, which serves nobody. The build's warehouses.yaml ('farps:') then "
                "stocks it like any base. Warns when the pad is in the sea (elevation grid). Target a "
                "FOLDER (durable) or a .miz; backed up."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target": {"type": "string", "description": "The mission FOLDER (durable) or a .miz."},
                    "name": {"type": "string", "description": "The FARP's name."},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                    },
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutral"]},
                    "country_id": {"type": "integer"},
                    "country_name": {"type": "string"},
                    "farp_type": {
                        "type": "string",
                        "enum": ["FARP", "Invisible FARP", "SINGLE_HELIPAD", "FARP_SINGLE_01", "FARP_T"],
                        "default": "FARP",
                    },
                    "frequency_mhz": {"type": "number", "default": 127.5},
                    "modulation": {"type": "string", "enum": ["AM", "FM"], "default": "AM"},
                    "callsign_id": {"type": "integer", "default": 1, "description": "1-based heliport callsign."},
                    "ammo_dump": {
                        "type": "boolean",
                        "default": True,
                        "description": "Place the FARP's ammunition dump (CTLD loading point); false skips it.",
                    },
                },
                "required": ["target", "name", "position", "coalition", "country_id", "country_name"],
            },
        ),
        handler=lambda p: add_farp(Path(p["target"]), **{key: value for key, value in p.items() if key != "target"}),
    )
    catalog.register(
        ActionSpec(
            name="add_carrier_group",
            description=(
                "Place a CARRIER GROUP ready for flight operations: the carrier (and escorts) steaming on "
                "a heading, its tower frequency, TACAN, ICLS, and on an arrested-landing deck Link 4 and "
                "ACLS; the '<carrier> S3B-Tanker' recovery tanker (with its TACAN) and the '<carrier> "
                "Pedro' rescue helicopter that the CARRIER module (veafCarrierOperations) looks for by "
                "those exact names; and the ship's warehouse entry the build's warehouses.yaml ('ships:') "
                "stocks. Then put slots on its deck with add_air_group start 'deck-cold'/'deck-hot' and "
                "carrier = the returned carrier unit name, and enable the CARRIER module in mission.yaml. "
                "Target a FOLDER (durable) or a .miz; backed up."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_path": {"type": "string", "description": "The mission FOLDER (durable) or a .miz."},
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutral"]},
                    "country_id": {"type": "integer"},
                    "country_name": {"type": "string"},
                    "name": {"type": "string", "description": "The ship group's name, e.g. 'CSG-74 Stennis'."},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "The carrier's position, at sea.",
                    },
                    "heading_deg": {"type": "number", "default": 0, "description": "Course, true degrees."},
                    "speed_kt": {"type": "number", "default": 15, "description": "Speed in KNOTS."},
                    "carrier_type": {
                        "type": "string",
                        "enum": list(CARRIER_TYPES),
                        "default": "Stennis",
                        "description": "The carrier types the CARRIER module runs operations for.",
                    },
                    "carrier_name": {
                        "type": "string",
                        "description": "The carrier UNIT's name (the tanker's and Pedro's derive from it); the "
                        "group's name when omitted.",
                    },
                    "escorts": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Escort ship types, e.g. ['TICONDEROG', 'USS_Arleigh_Burke_IIa'].",
                    },
                    "tower_mhz": {"type": "number", "default": 127.5, "description": "Carrier radio, MHz AM."},
                    "tacan_channel": {"type": "integer", "default": 74, "description": "TACAN channel, X mode."},
                    "tacan_callsign": {"type": "string", "default": "CVN", "description": "1-3 letters/digits."},
                    "icls_channel": {"type": ["integer", "null"], "default": 1, "description": "1-20, null for none."},
                    "link4_mhz": {
                        "type": ["number", "null"],
                        "default": 336.0,
                        "description": "Link 4 (with ACLS), MHz; null for none. Only on an arrested-landing deck.",
                    },
                    "recovery_tanker": {"type": "boolean", "default": True},
                    "tanker_tacan_channel": {"type": "integer", "default": 64, "description": "Y mode."},
                    "tanker_tacan_callsign": {"type": "string", "default": "SHL"},
                    "tanker_frequency_mhz": {"type": "number", "default": 290.0},
                    "rescue_helicopter": {"type": "boolean", "default": True},
                },
                "required": ["mission_path", "coalition", "country_id", "country_name", "name", "position"],
            },
        ),
        handler=lambda p: add_carrier_group(
            Path(p["mission_path"]), **{key: value for key, value in p.items() if key != "mission_path"}
        ),
    )
    catalog.register(
        ActionSpec(
            name="add_sound",
            description=(
                "EMBED a sound file (.ogg or .wav) in the mission: copied into l10n/DEFAULT and declared "
                "in mapResource, which is how DCS finds it. Returns the resource key edit_route's "
                "transmit_message takes -- the radio beacon of a helicopter zone, an SOS. Embedding the "
                "same file name again reuses its key. Target a FOLDER (durable) or a .miz; backed up."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_path": {"type": "string", "description": "The mission FOLDER (durable) or a .miz."},
                    "sound_path": {"type": "string", "description": "The .ogg or .wav file to embed."},
                    "resource_name": {
                        "type": "string",
                        "description": "The file name inside the mission; the source's own name when omitted.",
                    },
                },
                "required": ["mission_path", "sound_path"],
            },
        ),
        handler=lambda p: add_sound(
            Path(p["mission_path"]), source_path=p["sound_path"], resource_name=p.get("resource_name")
        ),
    )
    catalog.register(
        ActionSpec(
            name="set_briefing_picture",
            description=(
                "ADD an image (.png or .jpg) to a coalition's BRIEFING: copied into l10n/DEFAULT, declared "
                "in mapResource, and its key appended to the mission's pictureFileNameB / R / N -- the "
                "three pieces DCS keeps apart. The side's existing pictures are kept; adding the same "
                "file again lists it once. Do not put one picture on both sides to 'show it to everyone': "
                "a player whose side the briefing does not know (a Client or dynamic slot) sees the red "
                "list then the blue one, so it twice. Target a FOLDER (durable) or a .miz; backed up."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_path": {"type": "string", "description": "The mission FOLDER (durable) or a .miz."},
                    "source_path": {"type": "string", "description": "The .png or .jpg file to embed."},
                    "side": {
                        "type": "string",
                        "enum": ["blue", "red", "neutral"],
                        "description": "Whose briefing shows it.",
                    },
                    "resource_name": {
                        "type": "string",
                        "description": "The file name inside the mission; the source's own name when omitted.",
                    },
                },
                "required": ["mission_path", "source_path", "side"],
            },
        ),
        handler=lambda p: set_briefing_picture(
            Path(p["mission_path"]), source_path=p["source_path"], side=p["side"], resource_name=p.get("resource_name")
        ),
    )
    catalog.register(
        ActionSpec(
            name="repair_static_shapes",
            description=(
                "FILL the shape_name of every static placed without one (by a tool before 6.26, or a "
                "script), from the units database -- what the Mission Editor writes. DCS refuses some "
                "static types without it at mission load ('unknown static shape_name') and the object "
                "never exists; validate_mission lists them. Reports what it filled and the statics whose "
                "type has no known shape. Writes nothing when there is nothing to fill. Target a FOLDER "
                "(durable) or a .miz; backed up."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "target": {"type": "string", "description": "The mission FOLDER (durable) or a .miz."},
                },
                "required": ["target"],
            },
        ),
        handler=lambda p: repair_static_shapes(Path(p["target"])),
    )
    catalog.register(
        ActionSpec(
            name="set_airbase_coalition",
            description=(
                "Assign a DCS airfield to a coalition in a mission FOLDER, durably. An airfield's "
                "coalition lives in warehouses.airports[<id>].coalition, NOT in mission.coalition — "
                "so placing a unit near a base never turns the base itself; use this action. Resolves "
                "the airfield name to an id via the mission's theatre, sets the coalition, and turns "
                "on the base's Dynamic Spawn slots (the build then stocks them) unless dynamic_spawn "
                "is false -- e.g. an enemy base that should offer no slot, which is then recorded under "
                "exclude_airports in src/warehouses.yaml so the build keeps it closed. Backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "folder_path": {
                        "type": "string",
                        "description": "Path to the mission folder (mission.yaml + src/mission/).",
                    },
                    "name": {"type": "string", "description": "The airfield display name (e.g. 'Mezzeh')."},
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutral"]},
                    "dynamic_spawn": {
                        "type": "boolean",
                        "default": True,
                        "description": "Whether the base offers Dynamic Spawn slots.",
                    },
                },
                "required": ["folder_path", "name", "coalition"],
            },
        ),
        handler=lambda p: set_airbase_coalition(
            Path(p["folder_path"]),
            name=p["name"],
            coalition=p["coalition"],
            dynamic_spawn=p.get("dynamic_spawn", True),
        ),
    )
    catalog.register(
        ActionSpec(
            name="create_combat_zone",
            description=(
                "Lay down a complete VEAF combat zone in a mission FOLDER, in one pass, editing "
                "both worlds durably (no build): a circular trigger zone + groups placed inside it "
                "(names auto-prefixed with the zone so it captures them) in src/mission, and a "
                "modules.COMBATZONE.combat_zones[] entry appended in mission.yaml."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "folder_path": {
                        "type": "string",
                        "description": "Path to the mission folder (mission.yaml + src/mission/).",
                    },
                    "zone_name": {"type": "string", "description": "The combat zone's trigger-zone name."},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "The zone centre.",
                    },
                    "radius": {"type": "number", "description": "The zone radius, in metres."},
                    "groups": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "units": {"type": "array", "items": {"type": "object"}},
                                "position": {
                                    "type": "object",
                                    "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                                },
                                "route": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                                        "required": ["x", "y"],
                                    },
                                    "description": "Optional waypoints, as add_group's; the first is the start.",
                                },
                                "patrol": {
                                    "type": "boolean",
                                    "default": False,
                                    "description": "Loop the route's last waypoint back to the first.",
                                },
                                "keep_position": {
                                    "type": "boolean",
                                    "default": False,
                                    "description": "As add_group's: the position is the mission maker's own, never move it.",
                                },
                            },
                            "required": ["name", "units"],
                        },
                        "description": "Groups placed inside the zone; names are auto-prefixed with zone_name.",
                    },
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutral"]},
                    "country_id": {"type": "integer"},
                    "country_name": {"type": "string"},
                    "category": {"type": "string", "default": "vehicle"},
                    "combat_zone": {"type": "object", "description": "Optional extra combat_zones[] keys."},
                },
                "required": [
                    "folder_path",
                    "zone_name",
                    "position",
                    "radius",
                    "groups",
                    "coalition",
                    "country_id",
                    "country_name",
                ],
            },
        ),
        handler=_handle_create_combat_zone,
    )
    catalog.register(
        ActionSpec(
            name="add_combat_operation",
            description=(
                "Declare a VEAF combat OPERATION in a mission FOLDER's mission.yaml (no build): a "
                "modules.COMBATZONE.combat_zones[] entry of type 'operation' grouping combat zones the "
                "mission ALREADY declares (create_combat_zone first). Activating the operation spawns ALL its "
                "zones at once; a task's dependencies only decide when it becomes the current objective "
                "(an objective that must not exist before another is a chained_zones of that zone "
                "instead). Players activate the operation from its F10 "
                "menu, or it starts by itself with active_at_start. The operation's name is a label, "
                "not a trigger zone: nothing is written to src/mission. Refuses a task or dependency "
                "naming an undeclared zone (or another operation) -- it would resolve to nothing at "
                "runtime."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "folder_path": {
                        "type": "string",
                        "description": "Path to the mission folder (holds mission.yaml).",
                    },
                    "zone_name": {
                        "type": "string",
                        "description": "The operation's technical name, unique among combat_zones[].",
                    },
                    "friendly_name": {"type": "string", "description": "Label in the F10 menu."},
                    "briefing": {"type": "string", "description": "Text shown to the players."},
                    "active_at_start": {
                        "type": "boolean",
                        "description": "Activate the operation when the mission starts.",
                    },
                    "tasking_orders": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "zone_name": {"type": "string", "description": "A declared combat zone."},
                                "dependencies": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Zones that must be complete before this task starts.",
                                },
                            },
                            "required": ["zone_name"],
                        },
                        "description": "The operation's tasks, in order; at least one.",
                    },
                },
                "required": ["folder_path", "zone_name", "tasking_orders"],
            },
        ),
        handler=_handle_add_combat_operation,
    )
    catalog.register(
        ActionSpec(
            name="create_qra",
            description=(
                "Lay down a complete VEAF QRA in a mission FOLDER, one pass, both worlds (no build): "
                "a trigger zone + Late-Activation interceptor group(s) on the given coalition in "
                "src/mission, and an appended modules.QRA.definitions[] entry in mission.yaml "
                "referencing the group names verbatim. Interceptors are built AIRBORNE and fuelled "
                "(one aircraft type per group); give them a loadout with 'pylons', a DCS loadout by name "
                "with 'payload' (list_payloads), or copy one with "
                "'loadout_from' (a group of the mission or a veafSpawn-* catalogue template) -- an "
                "unarmed interceptor intercepts nothing. Each group gets a single waypoint and no task "
                "on purpose: when it scrambles, the QRA module gives a CAP/Intercept group whose route "
                "engages no aircraft its job -- a patrol across the zone and engagement of what enters "
                "it. Do not add waypoints to such a group without an EngageTargets (Air) task, or that "
                "route is replaced. SIZE IT TO THE PLAYERS: in 'qra', give groups_by_enemy_count tiers "
                "({enemy_count, groups}, every group of the tier scrambles; add random_pick to draw that "
                "many instead, never the same group twice), the biggest tier sized to the squadron's "
                "expected size -- never a single fixed pair against 5 players or more. "
                "scale_with_opposition: true picks the tier from the mission's opposition level (the "
                "opposition: block of mission.yaml) when it is higher than the aircraft in the zone; "
                "rearm_while_occupied: true rearms a dead QRA without waiting for its zone to clear."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "folder_path": {"type": "string", "description": "Path to the mission folder."},
                    "name": {"type": "string", "description": "QRA identifier (radio prefix)."},
                    "coalition": {"type": "string", "enum": ["blue", "red"], "description": "Defending coalition."},
                    "trigger_zone": {
                        "type": "string",
                        "description": "Protected-airspace trigger-zone name (created).",
                    },
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                    },
                    "radius": {"type": "number", "description": "Zone radius in metres."},
                    "groups": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "units": {"type": "array", "items": {"type": "object"}},
                                "position": {
                                    "type": "object",
                                    "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                                },
                                "altitude_ft": {"type": "number", "default": 15000},
                                "speed_kt": {"type": "number", "default": 350},
                                "task": {"type": "string", "default": "Intercept"},
                                "pylons": {
                                    "type": "object",
                                    "description": 'Loadout, {station: {"CLSID": ...}} as the mission file stores it.',
                                },
                                "payload": {
                                    "type": "string",
                                    "description": "A DCS loadout by the name the Mission Editor lists (list_payloads "
                                    "gives a type's names). One of pylons / payload / loadout_from.",
                                },
                                "loadout_from": {
                                    "type": "string",
                                    "description": "Group to copy the loadout from (mission or aircraft catalogues).",
                                },
                            },
                            "required": ["name", "units"],
                        },
                        "description": "Interceptor group(s); placed Late-Activation and referenced by exact name.",
                    },
                    "country_id": {"type": "integer"},
                    "country_name": {"type": "string"},
                    "category": {
                        "type": "string",
                        "default": "plane",
                        "description": "Ignored: the category comes from the aircraft type.",
                    },
                    "enemy_coalitions": {"type": "array", "items": {"type": "string"}},
                    "qra": {"type": "object", "description": "Optional extra definitions[] keys."},
                },
                "required": [
                    "folder_path",
                    "name",
                    "coalition",
                    "trigger_zone",
                    "position",
                    "radius",
                    "groups",
                    "country_id",
                    "country_name",
                ],
            },
        ),
        handler=_handle_create_qra,
    )
    catalog.register(
        ActionSpec(
            name="create_cap_mission",
            description=(
                "Create an on-demand CAP mission in a mission FOLDER, one pass, both worlds (no build): "
                "a Late-Activation template group named OnDemand-<mission_name> in src/mission, and an "
                "appended cap_missions[] entry (group_name: <mission_name>) in mission.yaml. The "
                "template is built AIRBORNE at 'position' and fuelled; give a 'route' point and it "
                "flies a race-track between the two (without one it orbits nowhere), and a loadout "
                "with 'pylons', 'payload' (a DCS loadout by name, list_payloads) or 'loadout_from'."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "folder_path": {"type": "string", "description": "Path to the mission folder."},
                    "mission_name": {
                        "type": "string",
                        "description": "CAP mission name (the un-prefixed YAML group_name).",
                    },
                    "units": {"type": "array", "items": {"type": "object"}, "description": "Template group's units."},
                    "coalition": {"type": "string", "enum": ["blue", "red", "neutral"]},
                    "country_id": {"type": "integer"},
                    "country_name": {"type": "string"},
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                    },
                    "category": {
                        "type": "string",
                        "default": "plane",
                        "description": "Ignored: the category comes from the aircraft type.",
                    },
                    "cap": {"type": "object", "description": "Optional extra cap_missions[] keys."},
                    "route": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "x": {"type": "number"},
                                "y": {"type": "number"},
                                "altitude_ft": {"type": "number"},
                            },
                            "required": ["x", "y"],
                        },
                        "description": "Further points; with one, a race-track between position and it.",
                    },
                    "altitude_ft": {"type": "number", "default": 20000},
                    "speed_kt": {"type": "number", "default": 350},
                    "pylons": {
                        "type": "object",
                        "description": 'Loadout, {station: {"CLSID": ...}} as the mission file stores it.',
                    },
                    "payload": {
                        "type": "string",
                        "description": "A DCS loadout by the name the Mission Editor lists (list_payloads "
                        "gives a type's names). One of pylons / payload / loadout_from.",
                    },
                    "loadout_from": {
                        "type": "string",
                        "description": "Group to copy the loadout from (mission or aircraft catalogues).",
                    },
                },
                "required": [
                    "folder_path",
                    "mission_name",
                    "units",
                    "coalition",
                    "country_id",
                    "country_name",
                    "position",
                ],
            },
        ),
        handler=_handle_create_cap_mission,
    )
    catalog.register(
        ActionSpec(
            name="describe_map",
            description=(
                "Summarize a mission's map for orientation (theatre, per-coalition bullseyes, and "
                "existing trigger zones/groups as reference points -- each zone with its x/y/radius, "
                "each group with its x/y and its number of units), from a .miz or a mission "
                "folder. Read-only; helps place things relative to known anchors without DCS."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_path": {
                        "type": "string",
                        "description": "Path to the mission's .miz or exploded mission folder.",
                    },
                },
                "required": ["mission_path"],
            },
        ),
        handler=lambda p: describe_map(Path(p["mission_path"])),
    )
    catalog.register(
        ActionSpec(
            name="list_airfields",
            description=(
                "List a theatre's airbases -- name, DCS airdrome id, lat/lon, and DCS x/y when the "
                "theatre's projection is known -- from the data shipped with the tools. Read-only. "
                "Use it to choose bases for set_airbase_coalition and to place things near a base, "
                "instead of guessing names or reading data files. Pass the mission, or a theatre name "
                "before there is one."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_path": {
                        "type": "string",
                        "description": "A .miz or mission folder whose theatre to list (wins over theatre).",
                    },
                    "theatre": {"type": "string", "description": "A DCS theatre name, e.g. 'GermanyCW'."},
                },
            },
        ),
        handler=lambda p: list_airfields(
            mission_path=Path(p["mission_path"]) if p.get("mission_path") else None,
            theatre=p.get("theatre"),
        ),
    )
    catalog.register(
        ActionSpec(
            name="describe_airfield_channels",
            description=(
                "List, for a mission FOLDER, the airfields it uses -- side (from warehouses), whether "
                "they offer dynamic slots once src/warehouses.yaml is applied, how many player slots "
                "are parked there -- with the ATC frequencies DCS itself gives them and the TACAN. "
                "Ranked: held with slots first, then held without, then (include_neutral) neutral. "
                "Read-only. Use it BEFORE set_airfield_channels to propose which bases deserve a "
                "radio channel: a DCS radio holds about twenty, so ask the mission author which ones "
                "when the list is longer than the obvious ones. Never type an airfield frequency."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "folder_path": {
                        "type": "string",
                        "description": "Path to the mission folder (src/mission/ + src/presets.yaml).",
                    },
                    "include_neutral": {
                        "type": "boolean",
                        "default": False,
                        "description": "Also list the airfields no side holds.",
                    },
                },
                "required": ["folder_path"],
            },
        ),
        handler=lambda p: describe_airfield_channels(
            Path(p["folder_path"]), include_neutral=p.get("include_neutral", False)
        ),
    )
    catalog.register(
        ActionSpec(
            name="set_airfield_channels",
            description=(
                "Write the chosen airfields into the 'bases' channel collection of a mission FOLDER's "
                "src/presets.yaml, with the frequencies DCS declares for them (refuses an airfield DCS "
                "does not declare -- never invent one). An airfield already in 'bases' keeps its alias; "
                "a new one is aliased Base-<DCS name>; entries matching no chosen airfield (a FARP, a "
                "ship) are left as they are and reported. Only 'bases' changes: tactical and flight "
                "channels and channel_lists are untouched -- the result lists the written channels on "
                "no radio yet, to add to channel_lists. Idempotent. Only write what the author chose: "
                "propose with describe_airfield_channels first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "folder_path": {
                        "type": "string",
                        "description": "Path to the mission folder (src/mission/ + src/presets.yaml).",
                    },
                    "airfields": {
                        "type": "array",
                        "items": {"type": ["string", "integer"]},
                        "description": "Airfields by DCS name or airdrome id, in the order wanted.",
                    },
                },
                "required": ["folder_path", "airfields"],
            },
        ),
        handler=lambda p: apply_airfield_channels(Path(p["folder_path"]), list(p["airfields"])),
    )
    catalog.register(
        ActionSpec(
            name="resolve_coordinates",
            description=(
                "Convert a position between DCS local x/y and geographic lat/lon for the mission's "
                "theatre (read from the mission, so no projection parameters needed). Pass a "
                "position as {x, y} or {lat, lon}; returns both representations. To convert several "
                "points in one call, pass 'positions' (a list) instead: returns {theatre, points}."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_path": {
                        "type": "string",
                        "description": "Path to the mission's .miz or folder (its theatre drives the projection).",
                    },
                    "position": {
                        "type": "object",
                        "description": "Either {x, y} (DCS local metres) or {lat, lon} (decimal degrees). "
                        "If both are given, {x, y} takes precedence.",
                        "properties": {
                            "x": {"type": "number"},
                            "y": {"type": "number"},
                            "lat": {"type": "number"},
                            "lon": {"type": "number"},
                        },
                    },
                    "positions": {
                        "type": "array",
                        "items": {"type": "object"},
                        "description": "Several positions, each shaped like 'position'; converted in order. "
                        "Pass this OR 'position'.",
                    },
                },
                "required": ["mission_path"],
            },
        ),
        handler=_handle_resolve_coordinates,
    )
    catalog.register(
        ActionSpec(
            name="geocode",
            description=(
                "Resolve a real-world place name (optionally offset by a bearing + distance) to DCS "
                "coordinates for the mission's theatre — DCS maps are the real world projected. "
                "Returns lat/lon + x/y; results are approximate (confirm visually). Read-only. "
                "Uses OSM Nominatim by default (or Google if a key is configured). Nominatim takes one "
                "request a second (paced for you; a refusal comes back as found=false saying so), and "
                "often has a single candidate for a transliterated name: osm_class/osm_type say what came "
                "back, and a road or an administrative area (a street of another country, a governorate's "
                "centre) is warned about -- check it, or search a nearby town or landmark."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "mission_path": {
                        "type": "string",
                        "description": "Path to the mission's .miz or folder (its theatre drives the projection).",
                    },
                    "query": {"type": "string", "description": "Real place name, e.g. 'Batumi', 'Kobuleti airport'."},
                    "bearing": {
                        "type": "number",
                        "description": "Optional bearing (degrees clockwise from north) for a relative offset.",
                    },
                    "distance_km": {
                        "type": "number",
                        "description": "Optional distance (km) along `bearing`, e.g. '10 km north of X'.",
                    },
                },
                "required": ["mission_path", "query"],
            },
        ),
        handler=lambda p: geocode(
            Path(p["mission_path"]),
            p["query"],
            bearing=p.get("bearing"),
            distance_km=p.get("distance_km"),
        ),
    )
    catalog.register(
        ActionSpec(
            name="list_unit_types",
            description=(
                "List DCS unit types from the canonical generated database (the same the build "
                "ships). Filter by category and/or a name substring. Read-only knowledge for the "
                "LLM to pick concrete unit types. A unit with weapons or sensors carries "
                "threat_range_m / detection_range_m (metres, DCS's ThreatRange / DetectionRange, the "
                "Mission Editor's range circles): measure an air defence against the bases with those."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "category": {"type": "string", "description": "Exact category, e.g. 'Plane', 'Armor'."},
                    "name_contains": {"type": "string", "description": "Case-insensitive substring on id+name."},
                },
            },
        ),
        handler=lambda p: list_unit_types(category=p.get("category"), name_contains=p.get("name_contains")),
    )
    catalog.register(
        ActionSpec(
            name="list_payloads",
            description=(
                "List the DCS default loadouts of an AI aircraft type by the names the Mission Editor "
                "offers ('R-40T*2,R-33*4' for a MiG-31), with their pylons -- what add_air_group, "
                "create_qra and create_cap_mission take as 'payload'. Without a type, the types that "
                "have loadouts (a module aircraft has none here: give it pylons or loadout_from). "
                "Read-only."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "unit_type": {"type": "string", "description": "Exact DCS type, e.g. 'MiG-31', 'Su-27'."},
                },
            },
        ),
        handler=lambda p: list_payloads(p.get("unit_type")),
    )
    catalog.register(
        ActionSpec(
            name="list_shortcuts",
            description=(
                "List the VEAF spawn aliases (the '-shilka'/'-sa8'… vocabulary) from the "
                "canonical veaf-units.yaml: unit aliases and composite group aliases, plus the "
                "'#command' shortcuts ('-samLR', '-armor'…) with the range of each parameter they "
                "draw at random ('defense', 'armor', 'size'). Read-only."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "name_contains": {"type": "string", "description": "Case-insensitive substring on aliases+target."},
                },
            },
        ),
        handler=lambda p: list_shortcuts(name_contains=p.get("name_contains")),
    )
    catalog.register(
        ActionSpec(
            name="describe_naming_conventions",
            description=(
                "Return the reserved VEAF group/unit naming conventions (combat-zone membership, "
                "veafSpawn-/OnDemand- prefixes, #veafInterpreter/#command markers, QRA deploy "
                "entries, …). Check a proposed group name against these before add_group."
            ),
            parameters_schema={"type": "object", "properties": {}},
        ),
        handler=lambda _p: describe_naming_conventions(),
    )
    catalog.register(
        ActionSpec(
            name="describe_known_limitations",
            description=(
                "Read this before building a mission. Returns, for the running veaf-tools version, "
                "the known limitations of the tools (not yet fixed) and the DCS behaviours that raise "
                "no error and are wrong anyway (late-activated groups visible to scripts, start_time "
                "not delaying an air spawn, a SAM without EWR permanently lit…): symptom, what to do, "
                "and what it cost. Read-only."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "kind": {"type": "string", "enum": ["tool", "dcs"], "description": "Return one kind only."},
                },
            },
        ),
        handler=lambda p: describe_known_limitations(kind=p.get("kind")),
    )
    catalog.register(
        ActionSpec(
            name="offer_clear_ground_check",
            description=(
                "Once a mission is built, OFFER the user to check in DCS whether its ground vehicles stand "
                "in trees or buildings. Launches nothing: returns the command the user runs (it needs DCS), "
                "what it will do, and how it counts — each vehicle's position is probed on an empty survey "
                "mission, so vehicles never block each other. Relay the offer and let the user decide."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "The built .miz to check."},
                },
                "required": ["miz_path"],
            },
        ),
        handler=lambda p: offer_check(Path(p["miz_path"])),
    )
    catalog.register(
        ActionSpec(
            name="offer_scenery_lookup",
            description=(
                "Before using a MAP OBJECT (a bridge, a building that is part of the map) as a combat zone "
                "objective, OFFER the user to look its DCS id up: `scenery_targets` takes ids, and they exist "
                "only inside DCS. Launches nothing: returns the command the user runs (it needs DCS), which "
                "lists the map objects around each point with id, type and distance."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "theatre": {"type": "string", "description": "The theatre, e.g. 'Syria'."},
                    "points": {
                        "type": "array",
                        "description": "Points to search around, in mission coordinates (x north, y east), metres.",
                        "items": {
                            "type": "object",
                            "properties": {
                                "x": {"type": "number"},
                                "y": {"type": "number"},
                                "radius": {
                                    "type": "number",
                                    "description": f"Search radius in metres (default {DEFAULT_RADIUS_METERS:g}).",
                                },
                            },
                            "required": ["x", "y"],
                        },
                        "minItems": 1,
                    },
                },
                "required": ["theatre", "points"],
            },
        ),
        handler=lambda p: offer_lookup(
            p["theatre"],
            [(float(q["x"]), float(q["y"]), float(q.get("radius", DEFAULT_RADIUS_METERS))) for q in p["points"]],
        ),
    )
    catalog.register(
        ActionSpec(
            name="terrain_elevation",
            description=(
                "Ground heights from the theatre's swept elevation grid, with no DCS running. Read-only. "
                "Ask any of: `points` — the ground height at each (target altitudes for a briefing); "
                "`route` — the highest ground along each leg (the floor of a low-level route); `route` + "
                "`observers` — how many metres of each leg each radar or SAM sees over the terrain, within "
                "its range (4/3 Earth radar horizon); `area` — the highest sample per 10 km MGRS square "
                "(F10 grid) or 30' quadrangle. Terrain only (no buildings, pylons, trees) — say so on every "
                "figure; a point off the grid is null, never 0. With no grid for the theatre, returns "
                "`available: false` and the command that sweeps one."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "theatre": {"type": "string", "description": "The theatre, e.g. 'Caucasus'."},
                    "points": {
                        "type": "array",
                        "description": "Points, mission coordinates (x north, y east), metres.",
                        "items": {
                            "type": "object",
                            "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                            "required": ["x", "y"],
                        },
                    },
                    "route": {
                        "type": "array",
                        "description": (
                            "Route points in order, mission coordinates. `alt` (metres) and `alt_type` "
                            "('BARO' above sea level, default; 'RADIO' above the ground, as a waypoint "
                            "carries them) are required with `observers`: a leg between two RADIO points "
                            "follows the ground, any other is straight between the two altitudes."
                        ),
                        "items": {
                            "type": "object",
                            "properties": {
                                "x": {"type": "number"},
                                "y": {"type": "number"},
                                "alt": {"type": "number"},
                                "alt_type": {"type": "string", "enum": ["BARO", "RADIO"]},
                            },
                            "required": ["x", "y"],
                        },
                        "minItems": 2,
                    },
                    "observers": {
                        "type": "array",
                        "description": "Radars or SAMs looking at the route.",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "x": {"type": "number"},
                                "y": {"type": "number"},
                                "range": {"type": "number", "description": "Metres; beyond, a leg is not counted."},
                                "height_agl": {
                                    "type": "number",
                                    "description": "Antenna height above the ground, metres (default 5).",
                                },
                            },
                            "required": ["x", "y", "range"],
                        },
                    },
                    "area": {
                        "type": "object",
                        "description": "An area to give the highest ground of, per cell.",
                        "properties": {
                            "min_x": {"type": "number"},
                            "min_y": {"type": "number"},
                            "max_x": {"type": "number"},
                            "max_y": {"type": "number"},
                            "cell": {"type": "string", "enum": ["mgrs10km", "quadrangle30"]},
                        },
                        "required": ["min_x", "min_y", "max_x", "max_y"],
                    },
                },
                "required": ["theatre"],
            },
        ),
        handler=lambda p: describe_terrain(
            p["theatre"],
            points=p.get("points"),
            route=p.get("route"),
            observers=p.get("observers"),
            area=p.get("area"),
        ),
    )
    catalog.register(
        ActionSpec(
            name="describe_module",
            description=(
                "Look a VEAF module up in the canonical module list and point to its doc page; "
                "optionally report whether it is enabled in a given mission.yaml. Read-only."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "module_id": {"type": "string", "description": "Module id, e.g. 'QRA', 'COMBATZONE'."},
                    "mission_yaml_path": {
                        "type": "string",
                        "description": "Optional mission.yaml to report the enabled state from.",
                    },
                },
                "required": ["module_id"],
            },
        ),
        handler=lambda p: describe_module(
            p["module_id"],
            mission_yaml_path=Path(p["mission_yaml_path"]) if p.get("mission_yaml_path") else None,
        ),
    )


def _handle_replace_in_mission_files(params: dict[str, Any]) -> dict[str, Any]:
    return replace_in_mission_files(
        Path(params["miz_path"]),
        search=params["search"],
        replace=params["replace"],
        files=params.get("files", "*.lua"),
        regex=params.get("regex", False),
    )


def _handle_set_unit_properties(params: dict[str, Any]) -> dict[str, Any]:
    """Adapt the JSON-RPC parameters to :func:`set_unit_properties`.

    A JSON object's keys are always strings, so ``pylons`` arrives as ``{"4": "..."}``. It is
    passed through untouched: the action's own station parsing produces the error message that
    names what a station is, which converting here would replace with `int()`'s.
    """
    return set_unit_properties(
        Path(params["miz_path"]),
        group_name=params["group_name"],
        unit_name=params["unit_name"],
        skill=params.get("skill"),
        livery=params.get("livery"),
        heading_deg=params.get("heading_deg"),
        callsign=params.get("callsign"),
        onboard_num=params.get("onboard_num"),
        chaff=params.get("chaff"),
        flare=params.get("flare"),
        pylons=params.get("pylons"),
        pylons_mode=params.get("pylons_mode", "replace"),
        new_name=params.get("new_name"),
        position=params.get("position"),
    )


def _handle_edit_zone(params: dict[str, Any]) -> dict[str, Any]:
    """Adapt the JSON-RPC parameters to :func:`edit_zone`."""
    return edit_zone(
        Path(params["miz_path"]),
        zone_name=params["zone_name"],
        new_name=params.get("new_name"),
        position=params.get("position"),
        radius=params.get("radius"),
        vertices=params.get("vertices"),
        make_circular=params.get("make_circular", False),
        link_unit=params.get("link_unit"),
        remove=params.get("remove", False),
    )


def _handle_add_map_drawing(params: dict[str, Any]) -> dict[str, Any]:
    """Adapt the JSON-RPC parameters to :func:`add_map_drawing`."""
    return add_map_drawing(
        Path(params["miz_path"]),
        layer=params["layer"],
        shape=params["shape"],
        name=params["name"],
        points=params.get("points"),
        position=params.get("position"),
        text=params.get("text"),
        width=params.get("width"),
        height=params.get("height"),
        radius=params.get("radius"),
        r1=params.get("r1"),
        r2=params.get("r2"),
        angle=params.get("angle", 0),
        closed=params.get("closed", False),
        color=params.get("color"),
        fill_color=params.get("fill_color"),
        thickness=params.get("thickness"),
        font_size=params.get("font_size"),
    )


def _handle_edit_map_drawing(params: dict[str, Any]) -> dict[str, Any]:
    """Adapt the JSON-RPC parameters to :func:`edit_map_drawing`."""
    return edit_map_drawing(
        Path(params["miz_path"]),
        layer=params["layer"],
        name=params["name"],
        new_name=params.get("new_name"),
        position=params.get("position"),
        text=params.get("text"),
        remove=params.get("remove", False),
    )


def _handle_edit_route(params: dict[str, Any]) -> dict[str, Any]:
    """Adapt the JSON-RPC parameters to :func:`edit_route`."""
    return edit_route(
        Path(params["miz_path"]),
        group_name=params["group_name"],
        operation=params["operation"],
        index=params.get("index"),
        to_index=params.get("to_index"),
        position=params.get("position"),
        name=params.get("name"),
        altitude_ft=params.get("altitude_ft"),
        speed_kt=params.get("speed_kt"),
        waypoint_type=params.get("waypoint_type"),
        eta_locked=params.get("eta_locked"),
        task=params.get("task"),
        task_params=params.get("task_params"),
        task_position=params.get("task_position"),
        road=params.get("road"),
    )


def _handle_set_group_properties(params: dict[str, Any]) -> dict[str, Any]:
    """Adapt the JSON-RPC parameters to :func:`set_group_properties`.

    The booleans are read with ``.get()`` rather than defaulted: ``None`` means "not given" and
    ``False`` means "turn it off", and collapsing the two would make a flag impossible to clear.
    """
    return set_group_properties(
        Path(params["miz_path"]),
        group_name=params["group_name"],
        new_name=params.get("new_name"),
        move_to=params.get("move_to"),
        move_bearing=params.get("move_bearing"),
        move_distance_m=params.get("move_distance_m"),
        frequency_mhz=params.get("frequency_mhz"),
        modulation=params.get("modulation"),
        late_activation=params.get("late_activation"),
        hidden=params.get("hidden"),
        uncontrolled=params.get("uncontrolled"),
        acknowledge_conventions=params.get("acknowledge_conventions", False),
    )


def _handle_add_group(params: dict[str, Any]) -> dict[str, Any]:
    return add_group(
        Path(params["target"]),
        coalition=params["coalition"],
        country_id=params["country_id"],
        country_name=params["country_name"],
        category=params["category"],
        name=params["name"],
        position=params["position"],
        units=params["units"],
        route=params.get("route"),
        patrol=params.get("patrol", False),
        for_combat_zone=params.get("for_combat_zone"),
        late_activation=params.get("late_activation", False),
        as_spawn_template=params.get("as_spawn_template", False),
        keep_position=params.get("keep_position", False),
    )


def _handle_add_player_slot(params: dict[str, Any]) -> dict[str, Any]:
    return add_player_slot(
        Path(params["target"]),
        coalition=params["coalition"],
        country_id=params["country_id"],
        country_name=params["country_name"],
        name=params["name"],
        unit_type=params["unit_type"],
        position=params["position"],
        start=params.get("start", "air"),
        altitude_ft=params.get("altitude_ft", 15000.0),
        speed_kt=params.get("speed_kt", 250.0),
        heading_deg=params.get("heading_deg", 0.0),
        parking=params.get("parking"),
        parking_id=params.get("parking_id"),
        airdrome_id=params.get("airdrome_id"),
        frequency_mhz=params.get("frequency_mhz", 251.0),
        onboard_num=params.get("onboard_num"),
        task=params.get("task", "Nothing"),
        fuel=params.get("fuel"),
        fuel_fraction=params.get("fuel_fraction"),
        chaff=params.get("chaff"),
        flare=params.get("flare"),
    )


def _handle_remove_group(params: dict[str, Any]) -> dict[str, Any]:
    return remove_group(Path(params["target"]), group_name=params["group_name"])


def _handle_add_air_group(params: dict[str, Any]) -> dict[str, Any]:
    return add_air_group(
        Path(params["target"]),
        coalition=params["coalition"],
        country_id=params["country_id"],
        country_name=params["country_name"],
        name=params["name"],
        unit_type=params["unit_type"],
        count=params.get("count", 1),
        start=params.get("start", "parking-cold"),
        airfield=params.get("airfield"),
        position=params.get("position"),
        altitude_ft=params.get("altitude_ft", 15000.0),
        speed_kt=params.get("speed_kt", 250.0),
        heading_deg=params.get("heading_deg", 0.0),
        skill=params.get("skill", "High"),
        frequency_mhz=params.get("frequency_mhz", 251.0),
        task=params.get("task", "CAS"),
        parking=params.get("parking"),
        fuel=params.get("fuel"),
        fuel_fraction=params.get("fuel_fraction"),
        late_activation=params.get("late_activation", False),
        pylons=params.get("pylons"),
        payload=params.get("payload"),
        chaff=params.get("chaff"),
        flare=params.get("flare"),
        carrier=params.get("carrier"),
    )


def _handle_resolve_coordinates(p: dict[str, Any]) -> dict[str, Any]:
    """Dispatch `resolve_coordinates` to one position or to a list of them.

    Args:
        p: The action's parameters.

    Returns:
        The single conversion, or ``{theatre, points}`` for ``positions``.

    Raises:
        ValueError: When neither or both of ``position`` and ``positions`` are given.
    """
    if ("position" in p) == ("positions" in p):
        raise ValueError("resolve_coordinates takes 'position' or 'positions', exactly one of them")
    if "positions" in p:
        return resolve_coordinates_batch(Path(p["mission_path"]), p["positions"])
    return resolve_coordinates(Path(p["mission_path"]), p["position"])


def _handle_create_combat_zone(params: dict[str, Any]) -> dict[str, Any]:
    return create_combat_zone(
        Path(params["folder_path"]),
        zone_name=params["zone_name"],
        position=params["position"],
        radius=params["radius"],
        groups=params["groups"],
        coalition=params["coalition"],
        country_id=params["country_id"],
        country_name=params["country_name"],
        category=params.get("category", "vehicle"),
        combat_zone=params.get("combat_zone"),
    )


def _handle_add_combat_operation(params: dict[str, Any]) -> dict[str, Any]:
    return add_combat_operation(
        Path(params["folder_path"]),
        zone_name=params["zone_name"],
        tasking_orders=params["tasking_orders"],
        friendly_name=params.get("friendly_name"),
        briefing=params.get("briefing"),
        active_at_start=params.get("active_at_start"),
    )


def _handle_create_qra(params: dict[str, Any]) -> dict[str, Any]:
    return create_qra(
        Path(params["folder_path"]),
        name=params["name"],
        coalition=params["coalition"],
        trigger_zone=params["trigger_zone"],
        position=params["position"],
        radius=params["radius"],
        groups=params["groups"],
        country_id=params["country_id"],
        country_name=params["country_name"],
        category=params.get("category", "plane"),
        enemy_coalitions=params.get("enemy_coalitions"),
        qra=params.get("qra"),
    )


def _handle_create_cap_mission(params: dict[str, Any]) -> dict[str, Any]:
    return create_cap_mission(
        Path(params["folder_path"]),
        mission_name=params["mission_name"],
        units=params["units"],
        coalition=params["coalition"],
        country_id=params["country_id"],
        country_name=params["country_name"],
        position=params["position"],
        category=params.get("category", "plane"),
        cap=params.get("cap"),
        route=params.get("route"),
        altitude_ft=params.get("altitude_ft", 20000.0),
        speed_kt=params.get("speed_kt", 350.0),
        pylons=params.get("pylons"),
        loadout_from=params.get("loadout_from"),
        payload=params.get("payload"),
    )


def _handle_add_trigger_zone(params: dict[str, Any]) -> dict[str, Any]:
    return add_trigger_zone(
        Path(params["miz_path"]),
        name=params["name"],
        position=params["position"],
        radius=params["radius"],
        hidden=params.get("hidden", False),
        color=params.get("color"),
    )


def _handle_add_startup_script_trigger(params: dict[str, Any]) -> dict[str, Any]:
    return add_startup_script_trigger(
        Path(params["miz_path"]),
        mode=params["mode"],
        comment=params["comment"],
        inline_lua=params.get("inline_lua"),
        source_path=params.get("source_path"),
        runtime_path=params.get("runtime_path"),
        resource_name=params.get("resource_name"),
    )
