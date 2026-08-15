"""Registers every mission-editing action this server ships into a catalog."""

from pathlib import Path
from typing import Any

from veaf_libs.blank_mission import supported_theatres

from veaf_mission_mcp.add_air_group import add_air_group
from veaf_mission_mcp.add_group import add_group
from veaf_mission_mcp.add_startup_script_trigger import add_startup_script_trigger
from veaf_mission_mcp.add_trigger_zone import add_trigger_zone
from veaf_mission_mcp.airbase import set_airbase_coalition
from veaf_mission_mcp.build_tools import build_mission, validate_mission
from veaf_mission_mcp.catalog import ActionCatalog
from veaf_mission_mcp.composites import create_cap_mission, create_combat_zone, create_qra
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
from veaf_mission_mcp.map_tools import describe_map, resolve_coordinates
from veaf_mission_mcp.models import ActionSpec
from veaf_mission_mcp.oracle import (
    describe_module,
    describe_naming_conventions,
    list_shortcuts,
    list_unit_types,
)
from veaf_mission_mcp.player_slot import add_player_slot
from veaf_mission_mcp.replace_in_files import replace_in_mission_files
from veaf_mission_mcp.scaffold import scaffold_mission
from veaf_mission_mcp.set_group_properties import set_group_properties
from veaf_mission_mcp.set_unit_properties import set_unit_properties


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
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
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
            name="set_unit_properties",
            description=(
                "CHANGE a unit that already exists: its loadout, skill, livery, heading, callsign or "
                "onboard number. Call describe_units FIRST -- this addresses the unit by its EXACT "
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
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
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
                        "shipped. Ground unit: the bare number.",
                    },
                    "onboard_num": {
                        "type": "string",
                        "description": "Tail number, as text so a leading zero survives.",
                    },
                    "pylons": {
                        "type": "object",
                        "description": "Loadout as {station number: weapon CLSID}. BY STATION, not by "
                        "position: a real FA-18C carries 1, 4, 5, 6, 9. Omit to leave the loadout "
                        "alone; pass {} with mode 'replace' for a clean airframe.",
                    },
                    "pylons_mode": {
                        "type": "string",
                        "enum": ["replace", "merge"],
                        "default": "replace",
                        "description": "'replace' writes exactly the stations given; 'merge' updates "
                        "only those, and an empty CLSID empties that station.",
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
                "group. WARNING: the destination's surface cannot be checked design-time, so a "
                "ground group can end up in water. Mutates in place, backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
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
                "insert (at a 1-based index), remove, reorder, set (name/altitude/speed/type/eta_locked), "
                "add_task, clear_tasks. Call describe_units first to see the route you are editing -- the "
                "result also returns the resulting route so you can check it. UNITS: altitude in FEET and "
                "speed in KNOTS (the mission file holds metres and m/s; the conversion is done for you). "
                "Tasks are a CLOSED named set -- orbit, land, attack_group, bombing, "
                "engage_targets_in_zone, set_frequency, switch_waypoint -- each validating its own "
                "parameters, because a made-up task table is one DCS ignores in silence while the flight "
                "does nothing. Note set_frequency takes MHz here even though DCS stores hertz. Every "
                "operation guarantees at least one waypoint keeps a locked time, since DCS refuses to save "
                "a route without one. Mutates in place, backed up first."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
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
                        ],
                        "description": "For 'add_task'. Unknown names are refused rather than guessed.",
                    },
                    "task_params": {
                        "type": "object",
                        "description": "That task's parameters. orbit: pattern (Race-Track|Circle), "
                        "altitude_ft, speed_kt. land: position, duration_s. attack_group: group_id. "
                        "bombing: position, expend, attack_qty. engage_targets_in_zone: position, "
                        "radius_m, target_types. set_frequency: frequency_mhz, modulation (AM|FM). "
                        "switch_waypoint: to_index, from_index.",
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
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
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
                "(width/height), 'textbox' (text). Other DCS shapes (circle, oval, arrow, icon) are "
                "REFUSED: no mission here contains one, so their field layout is unknown and a guess "
                "produces a drawing the editor silently drops."
            ),
            parameters_schema={
                "type": "object",
                "properties": {
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
                    "layer": {
                        "type": "string",
                        "enum": ["Red", "Blue", "Neutral", "Common", "Author"],
                        "description": "Who sees it. 'Common' is everyone; 'Author' is the maker's own layer.",
                    },
                    "shape": {"type": "string", "enum": ["line", "rect", "textbox"]},
                    "name": {"type": "string", "description": "Name, used to edit or remove it later."},
                    "points": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                            "required": ["x", "y"],
                        },
                        "description": "ABSOLUTE coordinates for a line, 2 or more.",
                    },
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}},
                        "required": ["x", "y"],
                        "description": "ABSOLUTE anchor for a rect or a textbox.",
                    },
                    "text": {"type": "string", "description": "The label, for a textbox."},
                    "width": {"type": "number", "description": "Width in metres, for a rect."},
                    "height": {"type": "number", "description": "Height in metres, for a rect."},
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
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
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
                                    "fake-unit (#command/#spawngroup/#spawnradius/#spawncount/#spawnchance/#spawndelay).",
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
                        "default": "010",
                        "description": "Tail number, as text so a leading zero survives.",
                    },
                    "task": {
                        "type": "string",
                        "default": "Nothing",
                        "description": "Aircraft-group task (default 'Nothing').",
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
                "'airfield'), air (needs 'position'). Target a FOLDER (durable) or .miz (transient); "
                "backed up first."
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
                        "enum": ["parking-cold", "parking-hot", "runway", "air"],
                        "default": "parking-cold",
                        "description": "Parking (needs airfield), runway (needs airfield), or air (needs position).",
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
                    "task": {"type": "string", "default": "CAS", "description": "Aircraft-group task."},
                    "parking": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Optional explicit stand numbers (one per aircraft), overriding auto-selection.",
                    },
                },
                "required": ["target", "coalition", "country_id", "country_name", "name", "unit_type"],
            },
        ),
        handler=_handle_add_air_group,
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
                    "miz_path": {"type": "string", "description": "Path to the mission's source .miz."},
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
                        "description": "Optional .miz to check the combat-zone capture trap against.",
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
                },
                "required": ["folder_path"],
            },
        ),
        handler=lambda p: build_mission(Path(p["folder_path"])),
    )
    catalog.register(
        ActionSpec(
            name="set_airbase_coalition",
            description=(
                "Assign a DCS airfield to a coalition in a mission FOLDER, durably. An airfield's "
                "coalition lives in warehouses.airports[<id>].coalition, NOT in mission.coalition — "
                "so placing a unit near a base never turns the base itself; use this action. Resolves "
                "the airfield name to an id via the mission's theatre, sets the coalition, and turns "
                "on the base's Dynamic Spawn slots (the build then stocks them). Backed up first."
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
                },
                "required": ["folder_path", "name", "coalition"],
            },
        ),
        handler=lambda p: set_airbase_coalition(Path(p["folder_path"]), name=p["name"], coalition=p["coalition"]),
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
            name="create_qra",
            description=(
                "Lay down a complete VEAF QRA in a mission FOLDER, one pass, both worlds (no build): "
                "a trigger zone + Late-Activation interceptor group(s) on the given coalition in "
                "src/mission, and an appended modules.QRA.definitions[] entry in mission.yaml "
                "referencing the group names verbatim."
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
                            },
                            "required": ["name", "units"],
                        },
                        "description": "Interceptor group(s); placed Late-Activation and referenced by exact name.",
                    },
                    "country_id": {"type": "integer"},
                    "country_name": {"type": "string"},
                    "category": {"type": "string", "default": "plane"},
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
                "appended cap_missions[] entry (group_name: <mission_name>) in mission.yaml."
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
                    "category": {"type": "string", "default": "plane"},
                    "cap": {"type": "object", "description": "Optional extra cap_missions[] keys."},
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
                "existing trigger zones/groups as reference points), from a .miz or a mission "
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
            name="resolve_coordinates",
            description=(
                "Convert a position between DCS local x/y and geographic lat/lon for the mission's "
                "theatre (read from the mission, so no projection parameters needed). Pass a "
                "position as {x, y} or {lat, lon}; returns both representations."
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
                },
                "required": ["mission_path", "position"],
            },
        ),
        handler=lambda p: resolve_coordinates(Path(p["mission_path"]), p["position"]),
    )
    catalog.register(
        ActionSpec(
            name="geocode",
            description=(
                "Resolve a real-world place name (optionally offset by a bearing + distance) to DCS "
                "coordinates for the mission's theatre — DCS maps are the real world projected. "
                "Returns lat/lon + x/y; results are approximate (confirm visually). Read-only. "
                "Uses OSM Nominatim by default (or Google if a key is configured)."
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
                "LLM to pick concrete unit types."
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
            name="list_shortcuts",
            description=(
                "List the VEAF spawn aliases (the '-shilka'/'-sa8'… vocabulary) from the "
                "canonical veaf-units.yaml: unit aliases and composite group aliases. Read-only."
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
        pylons=params.get("pylons"),
        pylons_mode=params.get("pylons_mode", "replace"),
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
        onboard_num=params.get("onboard_num", "010"),
        task=params.get("task", "Nothing"),
    )


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
    )


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
