"""FEAT-DYNSLOT-CATALOGUE-REFRESH ticket 04 — the shipped dynamic-slot catalogue's invariants.

Why these exist
---------------
Tickets 05 and 06 add 24 templates and rewrite 11 loadouts **inside a 9 500-line YAML, by
script**. A scripted edit that matches nothing reports nothing: this repository has already
shipped four consecutive commits that each claimed to bump a version and left it untouched,
found by a human reading the diff and by nothing else. Reading 9 500 lines back by eye is not a
check, so what the graft must preserve is written here as assertions instead.

Every invariant below was **measured** on the catalogue as it stood before the graft, so this
module is a description of the file rather than a wish about it. Two blemishes it found are
fixed by this ticket: ``CH-47F Template-1`` (the only name off the naming convention, and its own
route point already carried the clean name) and ``F-15E S4+ Template Red`` (filed under country
``Russia`` while the other 51 red templates sit under ``CJTF Red``).

The counts are **floors**, not equalities: adding a template later must not be a test edit.
"""

from __future__ import annotations

import unittest
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import yaml
from aircrafts_injector import AircraftGroupsYAMLValidator

_REPO_ROOT = Path(__file__).parents[3]
_DYNSLOT = _REPO_ROOT / "src" / "defaults" / "mission-folder" / "src" / "dynamic-slot-templates.yaml"

#: One country per coalition, and this is a design constraint rather than tidiness. A template
#: filed under a real country makes the injection demand that country join a side: it creates it
#: and lists its id in `coalitions.<side>` without checking the other side, so a blue `France`
#: template injected into a mission where France is red lists France on both. `CJTF Blue` (80) and
#: `CJTF Red` (81) are side-locked by construction and cannot collide. Mixing the two models is
#: also how `F-15E S4+ Template Red` ended up alone under `Russia`.
_COUNTRY_FOR_COALITION = {"blue": "CJTF Blue", "red": "CJTF Red"}

#: Name suffix per coalition. Red names are *not* the blue name plus " Red" — `A-10C II  Template`
#: has a double space on the red side — so the mirror is checked on unit **types**, not on names.
_SUFFIX_FOR_COALITION = {"blue": " Template", "red": " Template Red"}

#: Floors, in the ratchet sense: what the catalogue guarantees, raised by each lot that adds to
#: it — never lowered, and never an equality, so adding a template is not a test edit.
#: 104 templates of which 18 were armed before this lot grafted 24 and armed 15 more.
_MIN_TEMPLATES = 128
_MIN_ARMED = 33


class _Template:
    """One catalogue entry, flattened with everything an assertion needs to name it."""

    def __init__(self, bucket: str, coalition: str, country: str, key: str, group: dict[str, Any]):
        self.bucket = bucket
        self.coalition = coalition
        self.country = country
        self.key = key
        self.group = group

    def __str__(self) -> str:
        return f"{self.key} ({self.bucket}/{self.coalition}/{self.country})"

    @property
    def units(self) -> list[dict[str, Any]]:
        """The group's units, as a list whatever shape the YAML carries."""
        units = self.group.get("units") or []
        if isinstance(units, dict):  # a keyed Lua table deserializes as a dict
            units = list(units.values())
        return [u for u in units if isinstance(u, dict)]

    @property
    def route_points(self) -> list[dict[str, Any]]:
        """The route's points, as a list (the catalogue stores them as a keyed table)."""
        points = (self.group.get("route") or {}).get("points") or []
        if isinstance(points, dict):
            points = list(points.values())
        return [p for p in points if isinstance(p, dict)]

    @property
    def unit_type(self) -> str:
        return str(self.units[0].get("type"))

    @property
    def pylons(self) -> dict[str, Any]:
        return (self.units[0].get("payload") or {}).get("pylons") or {}


def _iter_templates(data: dict[str, Any]) -> Iterator[_Template]:
    for bucket in ("airplanes", "helicopters"):
        coalitions = (data.get(bucket) or {}).get("coalitions") or {}
        for coalition, countries in coalitions.items():
            for country, groups in (countries or {}).items():
                for key, group in (groups or {}).items():
                    yield _Template(bucket, coalition, country, key, group)


class ShippedCataloguesValidateSilentlyTest(unittest.TestCase):
    """Neither shipped catalogue may raise a validation message, at any level.

    The validator's "unusual field" check listed the group keys it knew, and the tool's own
    output was not among them: `dynSpawnTemplate` — the flag that *defines* a dynamic-slot
    template — plus `uncontrollable`, `DTC`, and `hiddenOnPlanner`/`hiddenOnMFD`, which the
    injector writes itself. Measured before the list was completed: **262 info messages across
    the two shipped catalogues, all of them noise.** A stream that is entirely noise is a stream
    nobody reads, so a real message arriving there would go unseen — the failure this repository
    has already measured once, on a log written 124 lines a minute.
    """

    def test_neither_shipped_catalogue_says_anything(self) -> None:
        for name in ("dynamic-slot-templates.yaml", "spawnables.yaml"):
            with self.subTest(catalogue=name):
                validator = AircraftGroupsYAMLValidator(_DYNSLOT.parent / name)
                is_valid, errors = validator.validate()
                self.assertTrue(is_valid, f"{name} does not validate")
                self.assertEqual(
                    [f"{e.path}: {e.message}" for e in errors],
                    [],
                    f"{name} raises validation messages; a noisy stream is an unread stream",
                )


class DynSlotCatalogueInvariantsTest(unittest.TestCase):
    """The shipped catalogue, read once."""

    templates: list[_Template]

    @classmethod
    def setUpClass(cls) -> None:
        data = yaml.safe_load(_DYNSLOT.read_text(encoding="utf-8")) or {}
        cls.templates = list(_iter_templates(data))

    def test_the_catalogue_is_not_empty(self) -> None:
        self.assertGreaterEqual(len(self.templates), _MIN_TEMPLATES)

    def test_every_entry_is_a_dynamic_slot_template(self) -> None:
        """What makes it one at all: the flag, one unit, and that unit playable."""
        for tpl in self.templates:
            with self.subTest(template=str(tpl)):
                self.assertIs(tpl.group.get("dynSpawnTemplate"), True)
                self.assertEqual(len(tpl.units), 1, "a dynamic-slot template describes one aircraft")
                self.assertEqual(tpl.units[0].get("skill"), "Client")

    def test_every_template_is_hidden_and_late_activated(self) -> None:
        """A template is referenced by name; it is never drawn on the F10 map nor activated.

        The injector forces both since ticket 02, so a catalogue that lost them still built
        correctly — but the catalogue is also read by hand and copied into mission folders, so
        it carries the truth rather than relying on the injector to repair it.
        """
        for tpl in self.templates:
            with self.subTest(template=str(tpl)):
                self.assertIs(tpl.group.get("hidden"), True)
                self.assertIs(tpl.group.get("lateActivation"), True)

    def test_no_template_carries_a_position(self) -> None:
        """A template has no place on the map. Extracts carry the coordinates of their mission."""
        for tpl in self.templates:
            with self.subTest(template=str(tpl)):
                self.assertEqual(tpl.group.get("x"), 0)
                self.assertEqual(tpl.group.get("y"), 0)
                self.assertEqual(tpl.units[0].get("x"), 0)
                self.assertEqual(tpl.units[0].get("y"), 0)

    def test_no_template_carries_a_password(self) -> None:
        """The injector applies its own slot password; a foreign hash here is noise."""
        for tpl in self.templates:
            with self.subTest(template=str(tpl)):
                self.assertNotIn("password", tpl.group)

    def test_the_names_agree_with_each_other(self) -> None:
        """The warehouses step links a stocked aircraft to a template **by name**."""
        for tpl in self.templates:
            with self.subTest(template=str(tpl)):
                self.assertEqual(tpl.group.get("name"), tpl.key, "the group's name must be its catalogue key")
                self.assertEqual(tpl.units[0].get("name"), f"{tpl.key} #01")
                self.assertEqual(len(tpl.route_points), 1)
                self.assertEqual(tpl.route_points[0].get("name"), tpl.key)

    def test_the_names_follow_the_convention(self) -> None:
        for tpl in self.templates:
            with self.subTest(template=str(tpl)):
                self.assertTrue(
                    tpl.key.endswith(_SUFFIX_FOR_COALITION[tpl.coalition]),
                    f"{tpl} must end with '{_SUFFIX_FOR_COALITION[tpl.coalition]}'",
                )

    def test_each_coalition_uses_its_single_country(self) -> None:
        for tpl in self.templates:
            with self.subTest(template=str(tpl)):
                self.assertEqual(tpl.country, _COUNTRY_FOR_COALITION[tpl.coalition])

    def test_the_red_side_mirrors_the_blue_side(self) -> None:
        """The catalogue's promise: whatever blue can fly, red can fly."""
        by_coalition: dict[str, set[tuple[str, str]]] = {"blue": set(), "red": set()}
        for tpl in self.templates:
            by_coalition[tpl.coalition].add((tpl.bucket, tpl.unit_type))

        self.assertEqual(
            by_coalition["blue"] - by_coalition["red"],
            set(),
            "these types are flyable blue and have no red counterpart",
        )
        self.assertEqual(
            by_coalition["red"] - by_coalition["blue"],
            set(),
            "these types are flyable red and have no blue counterpart",
        )

    def test_the_ids_are_unique(self) -> None:
        """Duplicate ids are a DCS load failure, and the injector does not renumber."""
        group_ids = [tpl.group.get("groupId") for tpl in self.templates]
        unit_ids = [tpl.units[0].get("unitId") for tpl in self.templates]

        self.assertNotIn(None, group_ids, "every template needs a groupId")
        self.assertNotIn(None, unit_ids, "every template needs a unitId")
        self.assertEqual(len(group_ids), len(set(group_ids)), "duplicate groupId in the catalogue")
        self.assertEqual(len(unit_ids), len(set(unit_ids)), "duplicate unitId in the catalogue")

    def test_enough_templates_come_armed(self) -> None:
        """DCS serves the aircraft **as the template describes it**, loadout included."""
        armed = [tpl for tpl in self.templates if tpl.pylons]
        self.assertGreaterEqual(
            len(armed),
            _MIN_ARMED,
            f"only {len(armed)} templates carry a loadout; the catalogue had {_MIN_ARMED}",
        )

    def test_every_pylon_is_well_formed(self) -> None:
        """Pylon tables are data copied in from foreign missions; a malformed one fails the load."""
        for tpl in self.templates:
            for station, pylon in tpl.pylons.items():
                with self.subTest(template=str(tpl), station=station):
                    self.assertIsInstance(station, int, "a pylon station is a DCS integer index")
                    self.assertIsInstance(pylon, dict)
                    clsid = pylon.get("CLSID")
                    self.assertIsInstance(clsid, str)
                    self.assertTrue(clsid, "an empty CLSID is an empty pylon, which DCS omits")


if __name__ == "__main__":
    unittest.main()
