"""A small mission night and its training: block, shared by the FEAT-ROLE-TRAINING-VARIANTS tests.

An enemy CAP flight, a QRA, an on-demand CAP, a long-range SAM, a combat zone with its target, the SA-6
that protects it and two SA-8 the briefing only calls "defences around", a column of tanks described as
vague, and a blue group nobody declares. **No VEAF command at all**: the draws must work on a mission
whose units are all placed by hand.
"""

from __future__ import annotations

from typing import Any


def unit(name: str, unit_type: str, x: float, y: float) -> dict[str, Any]:
    return {"name": name, "type": unit_type, "x": x, "y": y, "unitId": 0}


def group(name: str, units: list[dict[str, Any]]) -> dict[str, Any]:
    return {"name": name, "groupId": 0, "x": units[0]["x"], "y": units[0]["y"], "units": units}


def night_mission() -> dict[str, Any]:
    red_vehicles = [
        group("SA-10 Gudauta", [unit("SA-10 Gudauta-1", "S-300PS 5P85C ln", -50000, 20000)]),
        group("Factory-Tanks", [unit("Factory-Tanks-1", "T-72B", 1000, 1000)]),
        group("Factory-SA-6", [unit("Factory-SA-6-1", "Kub 2P25 ln", 1200, 900)]),
        group("Factory-Shilka", [unit("Factory-Shilka-1", "ZSU-23-4 Shilka", 900, 1100)]),
        group("Factory-SA-8 #1", [unit("Factory-SA-8 #1-1", "Osa 9A33 ln", 1500, 1500)]),
        group("Factory-SA-8 #2", [unit("Factory-SA-8 #2-1", "Osa 9A33 ln", 500, 500)]),
        group("Column 1", [unit("Column 1-1", "T-72B", 20000, 20000), unit("Column 1-2", "T-72B", 20015, 20000)]),
        group("Column 2", [unit("Column 2-1", "BMP-2", 20600, 20000)]),
    ]
    red_planes = [
        group("Red CAP Maykop", [unit("Red CAP Maykop-1", "MiG-29S", 60000, 0)]),
        group("QRA-Maykop-MiG29", [unit("QRA-Maykop-MiG29-1", "MiG-29S", 61000, 0)]),
        group("OnDemand-CAP-Red", [unit("OnDemand-CAP-Red-1", "Su-27", 62000, 0)]),
    ]
    return {
        "coalition": {
            "red": {
                "country": [
                    {"id": 0, "name": "Russia", "vehicle": {"group": red_vehicles}, "plane": {"group": red_planes}}
                ]
            },
            "blue": {
                "country": [
                    {
                        "id": 2,
                        "name": "USA",
                        "vehicle": {"group": [group("Blue HQ", [unit("Blue HQ-1", "M-1 Abrams", -90000, 0)])]},
                    }
                ]
            },
        },
        "triggers": {"zones": [{"name": "Factory", "x": 1000, "y": 1000, "radius": 3000, "zoneId": 1}]},
        "trig": {},
        "trigrules": {},
    }


def night_training() -> dict[str, Any]:
    return {
        "elements": [
            {"groups": ["Red CAP*"], "kind": "enemy_cap"},
            {"qra": "QRA-Maykop", "kind": "qra"},
            {"cap_mission": "CAP-Red", "kind": "enemy_cap"},
            {"groups": "SA-10 Gudauta", "kind": "sam_lr"},
            {"zone": "Factory", "kind": "a2g_target"},
            {"groups": ["Factory-SA-6"], "kind": "sam_threat"},
        ],
        "randomize": [
            {
                "name": "fdef",
                "replaces": ["Factory-SA-8 *"],
                "pool": [
                    {"group": "Factory-SA-8 #1"},
                    {"command": "-sa15"},
                    {"units": [{"type": "Strela-10M3", "count": 2}]},
                ],
                "count": "1-2",
                "radius": "500-2000",
            },
            {
                "name": "column",
                "replaces": ["Column *"],
                "pool": [{"group": "Column 1"}, {"command": "-armor"}],
                "radius": "0-500",
            },
        ],
    }


def night_yaml(**extra: Any) -> dict[str, Any]:
    data: dict[str, Any] = {
        "modules": {
            "COMBATZONE": {"enabled": True, "combat_zones": [{"zone_name": "Factory", "active_at_start": False}]},
            "QRA": {
                "enabled": True,
                "definitions": [
                    {
                        "name": "QRA-Maykop",
                        "trigger_zone": "Factory",
                        "groups_by_enemy_count": [{"enemy_count": 1, "groups": ["QRA-Maykop-MiG29"]}],
                        "active_at_start": False,
                    }
                ],
            },
        },
        "cap_missions": [{"group_name": "CAP-Red", "menu_name": "CAP"}],
        "training": night_training(),
    }
    data.update(extra)
    return data
