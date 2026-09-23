"""FIX-DYNSLOT-WIRING ticket 01 — an injected group must not steal an id the mission already uses.

The injector wrote the catalogue's ``groupId``/``unitId`` into the target mission verbatim. The
shipped catalogues live in a low band (``groupId`` 145–544 for the dynamic-slot templates, 47–152
for the spawnables) while a real mission runs to ~3900, so the two overlap by construction.
Measured before the fix: 6 duplicate ``groupId`` and 11 duplicate ``unitId`` after injecting the
dynamic-slot catalogue into ``test/veaf-tools/aircrafts-injector/test-import.miz``, 4 and 9 on the
Open Training Caucasus mission, and 4 ``unitId`` shared between the two shipped catalogues on any
mission that injects both.

What the duplicate costs is not an error: ``linkDynTempl: <id>`` then designates two groups, only
one of which is a ``dynSpawnTemplate``, and **that aircraft type alone** stops being offered as a
dynamic slot. Nothing warns.

A blank mission reproduces none of this — measured, 0 duplicates on a mission built from
``prepare --theatre Caucasus`` — which is why the defect outlived the existing tests. Every mission
built here therefore carries ids in the catalogue's own band on purpose.

:func:`test_every_stocked_type_links_to_its_own_template` is the one that states the user-visible
bug rather than the mechanism; the others pin the behaviour around it.
"""

from __future__ import annotations

import functools
import unittest
from pathlib import Path
from typing import Any

import yaml
from aircrafts_injector.aircrafts_injector_worker import AircraftGroupsInjectorWorker
from mission_tools.miz_tools import DcsMission
from mission_tools.sequence_normalisation import normalise_mission_sequences
from warehouses_injector.warehouses_injector_worker import apply_warehouses

_REPO_ROOT = Path(__file__).parents[3]
_DYNSLOT = _REPO_ROOT / "src" / "defaults" / "mission-folder" / "src" / "dynamic-slot-templates.yaml"
_SPAWNABLES = _REPO_ROOT / "src" / "defaults" / "mission-folder" / "src" / "spawnables.yaml"


@functools.lru_cache(maxsize=2)
def _catalogue(path: Path) -> dict:
    """Load a shipped catalogue once (351 KB of YAML; parsing it per test is the slow part)."""
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def _worker(yaml_data: dict, mission: DcsMission) -> AircraftGroupsInjectorWorker:
    """Return a worker wired to in-memory data, with no file the test has to write."""
    dummy = Path("/dev/null")
    worker = AircraftGroupsInjectorWorker(input_yaml=dummy, target_mission=dummy, output_mission=dummy)
    worker.yaml_data = yaml_data
    worker.dcs_mission = mission
    return worker


def _mission(
    groups: list[dict],
    *,
    theatre: str = "",
    airports: dict | None = None,
    statics: list[dict] | None = None,
    vehicles: list[dict] | None = None,
) -> DcsMission:
    """Build a mission holding *groups* under blue/USA/plane, plus an optional warehouse table."""
    country: dict[str, Any] = {
        "name": "USA",
        "id": 2,
        "plane": {"group": groups},
        "helicopter": {"group": []},
    }
    if statics is not None:
        country["static"] = {"group": statics}
    if vehicles is not None:
        country["vehicle"] = {"group": vehicles}
    return DcsMission(
        file_path=Path("/dev/null"),
        theatre_content=theatre,
        mission_content={
            "coalition": {"blue": {"country": [country]}},
            "coalitions": {"blue": [2], "red": []},
        },
        warehouses_content={"airports": airports} if airports is not None else None,
    )


def _group(name: str, group_id: int, unit_id: int, unit_type: str = "FA-18C_hornet") -> dict:
    """A minimal mission group carrying the two ids that can collide."""
    return {
        "name": name,
        "groupId": group_id,
        "units": [{"name": f"{name} #01", "unitId": unit_id, "type": unit_type}],
    }


def _yaml_of(groups: list[dict]) -> dict:
    """Wrap *groups* in the catalogue shape the injector reads."""
    return {
        "airplanes": {"coalitions": {"blue": {"USA": {g["name"]: g for g in groups}}}},
        "helicopters": {"coalitions": {}},
    }


def _settle(mission: DcsMission) -> DcsMission:
    """Close the sequence tables, standing in for the write + re-read the pipeline does.

    A catalogue keys ``units`` by ``1..N``, which is a dict once loaded from YAML; ``read_miz``
    turns those into lists and every reader relies on it. In the build the two steps are separated
    by a ``.miz`` written and read back, so the conversion happens for free — in a test that keeps
    one mission in memory it has to be asked for.
    """
    normalise_mission_sequences(mission.mission_content)
    return mission


def _ids(mission: DcsMission) -> tuple[list[Any], list[Any]]:
    """Return every ``groupId`` and every ``unitId`` of the mission, duplicates included."""
    group_ids, unit_ids = [], []
    for group in mission.iter_groups():
        group_ids.append(group.group_dcs.get("groupId"))
        unit_ids.extend(unit.get("unitId") for unit in (group.group_dcs.get("units") or []))
    return group_ids, unit_ids


class InjectedIdsDoNotCollideTest(unittest.TestCase):
    """The ids an injection writes stay unique within the mission."""

    def assert_unique(self, mission: DcsMission) -> None:
        """Fail naming the duplicates, so a regression says which ids rather than only that it broke."""
        group_ids, unit_ids = _ids(_settle(mission))
        for label, values in (("groupId", group_ids), ("unitId", unit_ids)):
            duplicates = sorted({v for v in values if values.count(v) > 1})
            self.assertEqual([], duplicates, f"duplicate {label}: {duplicates}")

    def test_a_colliding_group_id_is_reallocated(self) -> None:
        """An injected group whose id the mission already uses gets a new one."""
        mission = _mission([_group("Incumbent", 472, 554)])
        worker = _worker(_yaml_of([_group("F-14B Template", 472, 999)]), mission)

        worker.inject_groups(mode="add", silent=True)

        self.assert_unique(mission)
        injected = next(g for g in mission.iter_groups() if g.name == "F-14B Template")
        self.assertNotEqual(472, injected.group_dcs["groupId"])

    def test_a_free_group_id_is_kept(self) -> None:
        """Reallocation happens on collision only: an id nobody uses survives untouched."""
        mission = _mission([_group("Incumbent", 10, 11)])
        worker = _worker(_yaml_of([_group("F-14B Template", 472, 554)]), mission)

        worker.inject_groups(mode="add", silent=True)

        injected = next(g for g in mission.iter_groups() if g.name == "F-14B Template")
        self.assertEqual(472, injected.group_dcs["groupId"])
        self.assertEqual(554, injected.group_dcs["units"][0]["unitId"])

    def test_a_colliding_unit_id_is_reallocated(self) -> None:
        """A unit id collides on its own, independently of the group id."""
        mission = _mission([_group("Incumbent", 10, 554)])
        worker = _worker(_yaml_of([_group("F-14B Template", 472, 554)]), mission)

        worker.inject_groups(mode="add", silent=True)

        self.assert_unique(mission)
        injected = next(g for g in mission.iter_groups() if g.name == "F-14B Template")
        self.assertEqual(472, injected.group_dcs["groupId"], "the group id was free and must not move")
        self.assertNotEqual(554, injected.group_dcs["units"][0]["unitId"])

    def test_a_static_or_a_vehicle_holds_an_id_just_as_much_as_an_aircraft(self) -> None:
        """DCS numbers every category in one space, so the scan cannot stop at the aircraft.

        Found by reviewing the first version of this fix, which walked ``plane`` and
        ``helicopter`` only. Measured on 2026-09-22 with that scan in place: the dynamic-slot
        catalogue still collided with 8 ``groupId`` and 5 ``unitId`` held by vehicles and statics,
        identically on ``test-import.miz`` and on the Open Training Caucasus mission.
        """
        mission = _mission(
            [],
            statics=[_group("FARP Kaspi", 472, 554, unit_type="FARP")],
            vehicles=[_group("Convoy lead", 525, 610, unit_type="M-2 Bradley")],
        )
        worker = _worker(
            _yaml_of([_group("F-14B Template", 472, 554), _group("F-14BU Template", 525, 610)]),
            mission,
        )

        worker.inject_groups(mode="add", silent=True)

        used: list[object] = []
        for country in mission.mission_content["coalition"]["blue"]["country"]:
            for category in ("plane", "helicopter", "static", "vehicle"):
                for group in (country.get(category) or {}).get("group") or []:
                    used.append(group["groupId"])
                    used.extend(unit["unitId"] for unit in group["units"])
        assert len(used) == len(set(used)), f"an id is held twice across categories: {used}"

    def test_two_injected_groups_do_not_collide_with_each_other(self) -> None:
        """Reallocating twice from the same maximum would hand out the same id twice."""
        mission = _mission([_group("Incumbent", 472, 554)])
        worker = _worker(
            _yaml_of([_group("Template A", 472, 554), _group("Template B", 472, 554)]),
            mission,
        )

        worker.inject_groups(mode="add", silent=True)

        self.assert_unique(mission)

    def test_replace_mode_does_not_reallocate_the_group_it_replaces(self) -> None:
        """The group being replaced must not count itself as taken, or its id creeps every build."""
        mission = _mission([])
        catalogue = _yaml_of([_group("F-14B Template", 472, 554)])

        _worker(catalogue, mission).inject_groups(mode="replace", silent=True)
        first = next(g for g in mission.iter_groups() if g.name == "F-14B Template").group_dcs["groupId"]
        _worker(catalogue, mission).inject_groups(mode="replace", silent=True)
        second = next(g for g in mission.iter_groups() if g.name == "F-14B Template").group_dcs["groupId"]

        self.assertEqual(first, second, "a rebuild must not move the id it already allocated")
        self.assert_unique(mission)

    def test_the_two_shipped_catalogues_do_not_collide(self) -> None:
        """Measured before the fix: 4 ``unitId`` are shared between spawnables and dynslot templates."""
        mission = _mission([])

        _worker(_catalogue(_SPAWNABLES), mission).inject_groups(mode="add", silent=True)
        _worker(_catalogue(_DYNSLOT), mission).inject_groups(mode="add", silent=True)

        self.assert_unique(mission)

    def test_every_stocked_type_links_to_its_own_template(self) -> None:
        """The user-visible bug: a dynamic slot must resolve to one template, of the right type.

        Injects the shipped catalogue into a mission whose own ids deliberately cover the
        catalogue's band, then runs the warehouse step exactly as the build does, and checks every
        link it wrote. Before the fix this fails on the types whose ids were stolen.
        """
        squatters = [_group(f"Squatter {i}", i, i) for i in range(140, 640)]
        mission = _mission(squatters, theatre="", airports={18: {"coalition": "BLUE"}})

        _worker(_catalogue(_DYNSLOT), mission).inject_groups(mode="add", silent=True)
        apply_warehouses(_settle(mission), {"blue": {"defaults": {"fuel": "unlimited"}}})

        templates = {
            group.group_dcs["groupId"]: group
            for group in mission.iter_groups()
            if group.group_dcs.get("dynSpawnTemplate") is True
        }
        self.assertEqual(128, len(templates), "the whole catalogue must be injected and keep distinct ids")

        stock = (mission.warehouses_content or {})["airports"][18]["aircrafts"]
        links = {
            aircraft_type: entry["linkDynTempl"]
            for sub_table in stock.values()
            for aircraft_type, entry in sub_table.items()
            if "linkDynTempl" in entry
        }
        self.assertTrue(links, "the step must have linked something, or this test proves nothing")
        for aircraft_type, group_id in sorted(links.items()):
            target = templates.get(group_id)
            self.assertIsNotNone(target, f"{aircraft_type} links to group {group_id}, which is no template")
            assert target is not None  # narrowed for mypy
            self.assertEqual(aircraft_type.lower(), (target.unit_type or "").lower())


if __name__ == "__main__":
    unittest.main()
