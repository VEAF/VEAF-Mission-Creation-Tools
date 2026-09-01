"""Tests for AircraftGroupsInjectorWorker.inject_groups — non-regression for duplicate-group bug.

Background
----------
After a v5 → v6 mission conversion the source ``src/mission/mission`` file already contains
late-activation spawnable aircraft groups (FA-18C, F-16C …) that include DCS-specific metadata
such as ``datalinks``.  The ``convert-v5`` command also extracts those groups into
``src/aircraft-templates.yaml`` but *without* the DCS metadata (the v5 Lua config did not carry
``datalinks`` information).

During a subsequent ``veaf-tools build`` the pipeline calls
``AircraftGroupsInjectorWorker.inject_groups(mode="add")``.  Before the fix, mode ``"add"`` would
always *append* the YAML group, even when a group with the same name was already present in the
mission.  This created a duplicate: the original group (with ``datalinks``) alongside the injected
copy (without ``datalinks``).

DCS Mission Editor then crashed at load time::

    ALERT LUACOMMON (Main): Error: GUI Error:
    [string ".\\CoreMods\\aircraft\\FA-18C\\Datalinks\\Link16.lua"]:404:
    attempt to index global 'teamMemberDatalinks' (a nil value)

because ``me_mission.lua:fixDatalink`` calls ``Link16.lua:fillNetworkTableByDefaultValues`` for
every FA-18C/F-16C unit, and the function assumes ``teamMemberDatalinks`` has been populated by an
earlier network-setup step that only runs when a valid ``datalinks.Link16.network`` structure is
present in the unit.

Fix (aircrafts_injector_worker.py)
-----------------------------------
In mode ``"add"``, a group whose name already exists in the mission is now *skipped* instead of
appended.  This preserves the original group (with its full DCS metadata) and avoids the duplicate
that caused the crash.
"""

from __future__ import annotations

import unittest
from pathlib import Path

from aircrafts_injector.aircrafts_injector_worker import AircraftGroupsInjectorWorker, InjectionResult
from mission_tools.miz_tools import DcsMission

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _worker() -> AircraftGroupsInjectorWorker:
    """Return a worker with dummy paths (no I/O used in unit tests)."""
    dummy = Path("/dev/null")
    return AircraftGroupsInjectorWorker(input_yaml=dummy, target_mission=dummy, output_mission=dummy)


def _mission_with_groups(group_names: list[str]) -> DcsMission:
    """Build a minimal DcsMission whose blue/USA/plane list contains *group_names*."""
    groups = [{"name": name, "units": []} for name in group_names]
    mission_content = {
        "coalition": {
            "blue": {
                "country": [
                    {
                        "name": "USA",
                        "id": 2,
                        "plane": {"group": groups},
                        "helicopter": {"group": []},
                    }
                ]
            }
        }
    }
    return DcsMission(file_path=Path("/dev/null"), mission_content=mission_content)


def _yaml_data(group_names: list[str]) -> dict:
    """Build yaml_data dict for *group_names* as airplane groups in blue/USA."""
    return {
        "airplanes": {
            "coalitions": {
                "blue": {"USA": {name: {"name": name, "units": [{"type": "FA-18C_hornet"}]} for name in group_names}}
            }
        }
    }


def _get_groups(worker: AircraftGroupsInjectorWorker) -> list[dict]:
    """Return the blue/USA/plane group list from the worker's mission."""
    assert worker.dcs_mission is not None
    assert worker.dcs_mission.mission_content is not None
    return worker.dcs_mission.mission_content["coalition"]["blue"]["country"][0]["plane"]["group"]


# ---------------------------------------------------------------------------
# Tests — mode "add"
# ---------------------------------------------------------------------------


class TestInjectGroupsAddMode(unittest.TestCase):
    """inject_groups(mode='add') must not create duplicate groups."""

    def test_new_group_is_added(self) -> None:
        """A group absent from the mission is appended in mode 'add'."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups(["existing-group"])
        worker.yaml_data = _yaml_data(["new-group"])

        result = worker.inject_groups(mode="add", silent=True)

        self.assertTrue(result.success)
        names = [g["name"] for g in _get_groups(worker)]
        self.assertIn("existing-group", names)
        self.assertIn("new-group", names)
        self.assertEqual(len(names), 2)

    def test_duplicate_group_is_skipped(self) -> None:
        """A YAML group whose name already exists in the mission is skipped — no duplicate created."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups(["spawn-f18-fox1"])
        worker.yaml_data = _yaml_data(["spawn-f18-fox1"])

        worker.inject_groups(mode="add", silent=True)

        groups = _get_groups(worker)
        names = [g["name"] for g in groups]
        # The group must appear exactly once.
        self.assertEqual(names.count("spawn-f18-fox1"), 1, "Duplicate group created in mode 'add'")

    def test_original_group_data_preserved_when_skipped(self) -> None:
        """The original group data (e.g. datalinks) is untouched when the YAML copy is skipped."""
        datalinks = {
            "Link16": {
                "network": {"donors": {}, "teamMembers": {1: {"missionUnitId": 117}}},
                "settings": {"AIC_Channel": 1, "FF1_Channel": 2},
            }
        }
        original_group = {
            "name": "spawn-f18-fox1",
            "units": [{"type": "FA-18C_hornet", "unitId": 117, "datalinks": datalinks}],
        }
        mission_content = {
            "coalition": {
                "blue": {
                    "country": [
                        {
                            "name": "USA",
                            "id": 2,
                            "plane": {"group": [original_group]},
                            "helicopter": {"group": []},
                        }
                    ]
                }
            }
        }
        worker = _worker()
        worker.dcs_mission = DcsMission(file_path=Path("/dev/null"), mission_content=mission_content)
        # YAML version of the same group — without datalinks
        worker.yaml_data = _yaml_data(["spawn-f18-fox1"])

        worker.inject_groups(mode="add", silent=True)

        groups = _get_groups(worker)
        self.assertEqual(len(groups), 1)
        # The original unit's datalinks must still be present.
        unit = groups[0]["units"][0]
        self.assertIn("datalinks", unit, "datalinks were lost after inject_groups(mode='add')")
        self.assertIn("Link16", unit["datalinks"])

    def test_mix_existing_and_new_groups(self) -> None:
        """Existing groups are kept; new groups are appended; no duplicates are created."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups(["alpha", "bravo"])
        worker.yaml_data = _yaml_data(["alpha", "charlie"])  # alpha exists, charlie is new

        result = worker.inject_groups(mode="add", silent=True)

        names = [g["name"] for g in _get_groups(worker)]
        self.assertEqual(names.count("alpha"), 1, "alpha must not be duplicated")
        self.assertIn("bravo", names)
        self.assertIn("charlie", names)
        self.assertEqual(len(names), 3)
        # charlie injected, alpha skipped (already present).
        self.assertEqual(result.groups_injected, 1)
        self.assertEqual(result.groups_skipped, 1)

    def test_no_groups_injected_when_all_exist(self) -> None:
        """When every YAML group already exists, nothing is added but all are reported skipped."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups(["g1", "g2", "g3"])
        worker.yaml_data = _yaml_data(["g1", "g2", "g3"])

        result = worker.inject_groups(mode="add", silent=True)

        self.assertEqual(len(_get_groups(worker)), 3)
        self.assertEqual(result.groups_injected, 0)
        self.assertEqual(result.groups_skipped, 3)

    def test_new_group_reports_zero_skipped(self) -> None:
        """A purely additive injection reports no skips."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups(["existing"])
        worker.yaml_data = _yaml_data(["brand-new"])

        result = worker.inject_groups(mode="add", silent=True)

        self.assertEqual(result.groups_injected, 1)
        self.assertEqual(result.groups_skipped, 0)


# ---------------------------------------------------------------------------
# Tests — mode "replace"
# ---------------------------------------------------------------------------


class TestInjectGroupsReplaceMode(unittest.TestCase):
    """inject_groups(mode='replace') must replace existing groups and add new ones."""

    def test_existing_group_is_replaced(self) -> None:
        """A YAML group whose name matches an existing group replaces it."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups(["alpha"])
        worker.yaml_data = _yaml_data(["alpha"])

        worker.inject_groups(mode="replace", silent=True)

        groups = _get_groups(worker)
        self.assertEqual(len(groups), 1)
        # The injected group has a units list from yaml_data; the original had an empty list.
        self.assertEqual(len(groups[0].get("units", [])), 1)

    def test_new_group_added_in_replace_mode(self) -> None:
        """A YAML group with a new name is appended even in replace mode."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups(["alpha"])
        worker.yaml_data = _yaml_data(["beta"])

        worker.inject_groups(mode="replace", silent=True)

        names = [g["name"] for g in _get_groups(worker)]
        self.assertIn("alpha", names)
        self.assertIn("beta", names)

    def test_replace_does_not_duplicate(self) -> None:
        """Replacing a group keeps exactly one entry with that name."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups(["spawn-f16"])
        worker.yaml_data = _yaml_data(["spawn-f16"])

        worker.inject_groups(mode="replace", silent=True)

        names = [g["name"] for g in _get_groups(worker)]
        self.assertEqual(names.count("spawn-f16"), 1)


# ---------------------------------------------------------------------------
# Tests — error / edge cases
# ---------------------------------------------------------------------------


class TestInjectGroupsEdgeCases(unittest.TestCase):
    def test_returns_failure_when_mission_not_loaded(self) -> None:
        worker = _worker()
        worker.yaml_data = _yaml_data(["g"])
        result = worker.inject_groups(silent=True)
        self.assertFalse(result.success)

    def test_returns_failure_when_yaml_not_loaded(self) -> None:
        worker = _worker()
        worker.dcs_mission = _mission_with_groups([])
        result = worker.inject_groups(silent=True)
        self.assertFalse(result.success)

    def test_empty_yaml_data_returns_failure(self) -> None:
        # An empty dict is falsy — treated the same as None (not loaded).
        worker = _worker()
        worker.dcs_mission = _mission_with_groups(["g"])
        worker.yaml_data = {}
        result = worker.inject_groups(mode="add", silent=True)
        self.assertFalse(result.success)


class TestCountryIdResolution(unittest.TestCase):
    """_get_or_create_country must always stamp a valid DCS country.id.

    A country created without an ``id`` crashes the DCS Mission Editor on load
    (``me_mission.lua`` → ``fixCountriesNames`` → nil-index). This regression
    covers a country absent from the whole mission (e.g. injecting French
    aircraft into a USA/Ukraine-only mission).
    """

    def test_country_absent_from_mission_gets_dcs_id(self) -> None:
        """A brand-new country absent everywhere is created with its DCS id."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups([])  # blue/USA only
        coalition = worker.dcs_mission.mission_content["coalition"]["blue"]

        country = worker._get_or_create_country(coalition, "France")

        self.assertEqual(country["id"], 5)  # France == 5 in the DCS country table

    def test_country_display_name_resolves(self) -> None:
        """The Mission Editor display name (e.g. CJTF Blue) resolves to an id."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups([])
        coalition = worker.dcs_mission.mission_content["coalition"]["blue"]

        country = worker._get_or_create_country(coalition, "CJTF Blue")

        self.assertEqual(country["id"], 80)

    def test_existing_mission_id_takes_priority(self) -> None:
        """An id already present in the mission is preserved over the table."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups([])
        # blue/USA already carries id 2; a non-standard id would still win.
        coalition = worker.dcs_mission.mission_content["coalition"]["blue"]
        coalition["country"][0]["id"] = 999

        country = worker._get_or_create_country(coalition, "USA")

        self.assertEqual(country["id"], 999)

    def test_unknown_country_raises(self) -> None:
        """An unknown country name fails loudly instead of emitting a nil id."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups([])
        coalition = worker.dcs_mission.mission_content["coalition"]["blue"]

        with self.assertRaises(ValueError):
            worker._get_or_create_country(coalition, "Wakanda")


class TestInjectedTemplateHiddenFromSlotList(unittest.TestCase):
    """FIX-TEMPLATE-SLOTS-VISIBLE: injected templates must not appear as pickable MP slots."""

    def test_added_group_is_hidden_from_planner(self) -> None:
        """A newly injected template carries hiddenOnPlanner/hiddenOnMFD."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups([])
        worker.yaml_data = _yaml_data(["tmpl-a10"])

        result = worker.inject_groups(mode="add", silent=True)

        self.assertTrue(result.success)
        injected = next(g for g in _get_groups(worker) if g["name"] == "tmpl-a10")
        self.assertTrue(injected["hiddenOnPlanner"])
        self.assertTrue(injected["hiddenOnMFD"])
        self.assertTrue(injected["password"])  # locked slot password (b)

    def test_replaced_group_is_hidden_from_planner(self) -> None:
        """A replaced template is hardened too (both insertion paths)."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups(["tmpl-a10"])
        worker.yaml_data = _yaml_data(["tmpl-a10"])

        worker.inject_groups(mode="replace", silent=True)

        injected = next(g for g in _get_groups(worker) if g["name"] == "tmpl-a10")
        self.assertTrue(injected["hiddenOnPlanner"])
        self.assertTrue(injected["hiddenOnMFD"])
        self.assertTrue(injected["password"])  # locked slot password (b)


class TestInjectGroupsDictContainer(unittest.TestCase):
    """FIX-AIRCRAFT-INJECT-DICT-GROUP — a country whose ["group"] is a dict (luadata turns an
    empty `{}` or a keyed Lua table into a dict, not a list) must not crash inject_groups."""

    @staticmethod
    def _mission_with_plane_group(plane_group: object) -> DcsMission:
        mission_content = {
            "coalition": {
                "blue": {
                    "country": [{"name": "USA", "id": 2, "plane": {"group": plane_group}, "helicopter": {"group": []}}]
                }
            }
        }
        return DcsMission(file_path=Path("/dev/null"), mission_content=mission_content)

    def test_empty_dict_group_container(self) -> None:
        """An empty `{}` group container (Lua `{}` → dict) is normalized to a list and injection works."""
        worker = _worker()
        worker.dcs_mission = self._mission_with_plane_group({})
        worker.yaml_data = _yaml_data(["new-group"])

        result = worker.inject_groups(mode="add", silent=True)

        self.assertTrue(result.success)
        self.assertEqual([g["name"] for g in _get_groups(worker)], ["new-group"])

    def test_keyed_dict_group_container_preserves_existing(self) -> None:
        """A keyed dict group container (e.g. {1: group}) keeps existing groups and appends the new one."""
        worker = _worker()
        worker.dcs_mission = self._mission_with_plane_group({1: {"name": "existing", "units": []}})
        worker.yaml_data = _yaml_data(["new-group"])

        result = worker.inject_groups(mode="add", silent=True)

        self.assertTrue(result.success)
        names = [g["name"] for g in _get_groups(worker)]
        self.assertIn("existing", names)
        self.assertIn("new-group", names)


class TestInjectedCountryIsAssignedToItsSide(unittest.TestCase):
    """FIX-PREPARE-THEATRE-COALITIONS: injecting units must also assign the country to the side.

    ``coalition.<side>.country`` holds the units; ``coalitions.<side>`` lists the country ids the
    side owns. A country in the first and not in the second makes DCS open the CHANGING COALITIONS
    screen and refuse the mission — which is what a mission scaffolded by ``prepare --theatre`` hit,
    since its ``coalitions`` table starts empty.
    """

    def _yaml_for(self, coalition: str, country: str, group_name: str) -> dict:
        return {
            "airplanes": {
                "coalitions": {
                    coalition: {country: {group_name: {"name": group_name, "units": [{"type": "FA-18C_hornet"}]}}}
                }
            }
        }

    def test_new_country_is_listed_in_coalitions(self) -> None:
        """A country created by the injection is added to `coalitions.<side>`."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups([])
        worker.dcs_mission.mission_content["coalitions"] = {"blue": {}, "red": {}}
        worker.yaml_data = self._yaml_for("blue", "France", "new-group")

        worker.inject_groups(mode="add", silent=True)

        self.assertEqual(worker.dcs_mission.mission_content["coalitions"]["blue"], [5])

    def test_existing_country_is_listed_once(self) -> None:
        """Two groups from the same country leave a single entry, and an existing id is kept."""
        worker = _worker()
        worker.dcs_mission = _mission_with_groups([])
        worker.dcs_mission.mission_content["coalitions"] = {"blue": [2], "red": {}}
        worker.yaml_data = self._yaml_for("blue", "USA", "g1")
        worker.yaml_data["airplanes"]["coalitions"]["blue"]["USA"]["g2"] = {"name": "g2", "units": []}

        worker.inject_groups(mode="add", silent=True)

        self.assertEqual(worker.dcs_mission.mission_content["coalitions"]["blue"], [2])


if __name__ == "__main__":
    unittest.main()
