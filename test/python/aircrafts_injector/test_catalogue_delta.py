"""An empty catalogue is not an empty intention, and a pull never overwrites what is already there.

FEAT-DEFAULTS-CATALOGUE-FLOW. Two behaviours are load-bearing and neither is visible in a build log:

- ``catalogue_has_groups`` is what decides whether the build reads the mission's file or the one
  shipped with the tool. The 62-byte ``airplanes: {coalitions: {}}`` skeleton two mission folders
  on this machine already carry must answer *no*, or those folders keep injecting nothing.
- ``merge_missing`` is the mirror of the extractor's ``_merge_over``. Flip it and a pull silently
  replaces a mission maker's hand-tuned loadouts with the shipped ones — the exact outcome David
  ruled out ("pas brutalement tous les defaults").
"""

from __future__ import annotations

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import yaml
from aircrafts_injector.catalogue import (
    DYNAMIC_TEMPLATES_FILENAME,
    SPAWNABLES_FILENAME,
    GroupRef,
    catalogue_file_has_groups,
    catalogue_has_groups,
    empty_catalogue_yaml,
    iter_groups,
    load_catalogue,
    merge_missing,
)

EMPTY = {"airplanes": {"coalitions": {}}, "helicopters": {"coalitions": {}}}


def _catalogue(*names: str, payload: str = "shipped") -> dict:
    """A one-coalition catalogue holding *names*, each group carrying a recognisable payload."""
    return {
        "airplanes": {
            "coalitions": {"blue": {"CJTF Blue": {name: {"name": name, "origin": payload} for name in names}}}
        }
    }


class TestEmptyMeansEmpty(unittest.TestCase):
    def test_the_62_byte_skeleton_carries_no_group(self) -> None:
        self.assertFalse(catalogue_has_groups(EMPTY))

    def test_one_group_is_enough(self) -> None:
        self.assertTrue(catalogue_has_groups(_catalogue("F-14BU Template")))

    def test_a_missing_file_carries_no_group(self) -> None:
        with TemporaryDirectory() as tmp:
            self.assertFalse(catalogue_file_has_groups(Path(tmp) / "nope.yaml"))

    def test_a_blank_file_carries_no_group(self) -> None:
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "empty.yaml"
            path.write_text("", encoding="utf-8")
            self.assertFalse(catalogue_file_has_groups(path))

    def test_an_unparseable_file_carries_no_group(self) -> None:
        """A file the YAML parser refuses must not crash the build; it reads as empty."""
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "broken.yaml"
            path.write_text("airplanes: [unclosed\n", encoding="utf-8")
            self.assertFalse(catalogue_file_has_groups(path))
            self.assertEqual(load_catalogue(path), {})

    def test_a_populated_file_carries_groups(self) -> None:
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "full.yaml"
            path.write_text(yaml.safe_dump(_catalogue("A-10C II Template")), encoding="utf-8")
            self.assertTrue(catalogue_file_has_groups(path))

    def test_a_malformed_level_is_walked_past_rather_than_raised_on(self) -> None:
        """This walk decides whether a file is usable, so it has to survive a broken one."""
        broken = {"airplanes": {"coalitions": {"blue": "not a mapping"}}, "helicopters": None}
        self.assertFalse(catalogue_has_groups(broken))


class TestTheSkeletonSaysWhatEmptyMeans(unittest.TestCase):
    """A reader must not take the empty file for a way to switch the step off."""

    def test_it_parses_to_an_empty_catalogue(self) -> None:
        for filename in (SPAWNABLES_FILENAME, DYNAMIC_TEMPLATES_FILENAME):
            with self.subTest(filename):
                parsed = yaml.safe_load(empty_catalogue_yaml(filename))
                self.assertFalse(catalogue_has_groups(parsed))
                self.assertIn("airplanes", parsed)
                self.assertIn("helicopters", parsed)

    def test_it_names_the_real_way_to_disable_the_step(self) -> None:
        self.assertIn("dynamic_slot_templates: false", empty_catalogue_yaml(DYNAMIC_TEMPLATES_FILENAME))
        self.assertIn("spawnable_aircrafts: false", empty_catalogue_yaml(SPAWNABLES_FILENAME))

    def test_it_says_empty_is_not_none(self) -> None:
        header = empty_catalogue_yaml(DYNAMIC_TEMPLATES_FILENAME)
        self.assertIn("ON PURPOSE", header)
        self.assertIn("pull-aircraft-groups", header)


class TestMergeMissingNeverOverwrites(unittest.TestCase):
    def test_it_adds_what_is_missing(self) -> None:
        mine = _catalogue("A-10C II Template", payload="mine")
        shipped = _catalogue("A-10C II Template", "F-14BU Template")

        merged, added = merge_missing(mine, shipped)

        self.assertEqual([ref.name for ref in added], ["F-14BU Template"])
        groups = merged["airplanes"]["coalitions"]["blue"]["CJTF Blue"]
        self.assertEqual(sorted(groups), ["A-10C II Template", "F-14BU Template"])

    def test_an_entry_the_maker_owns_is_left_exactly_as_it_was(self) -> None:
        """The whole point: his versions stay his, even when the shipped one differs."""
        mine = _catalogue("A-10C II Template", payload="mine")
        shipped = _catalogue("A-10C II Template", "F-14BU Template")

        merged, _ = merge_missing(mine, shipped)

        self.assertEqual(merged["airplanes"]["coalitions"]["blue"]["CJTF Blue"]["A-10C II Template"]["origin"], "mine")

    def test_the_source_catalogues_are_not_mutated(self) -> None:
        mine = _catalogue("A-10C II Template", payload="mine")
        shipped = _catalogue("F-14BU Template")

        merge_missing(mine, shipped)

        self.assertEqual(sorted(mine["airplanes"]["coalitions"]["blue"]["CJTF Blue"]), ["A-10C II Template"])
        self.assertEqual(sorted(shipped["airplanes"]["coalitions"]["blue"]["CJTF Blue"]), ["F-14BU Template"])

    def test_a_name_selection_takes_only_that_one(self) -> None:
        mine = _catalogue("A-10C II Template", payload="mine")
        shipped = _catalogue("F-14BU Template", "F-16C Template", "AV-8B Template")

        merged, added = merge_missing(mine, shipped, names={"F-16C Template"})

        self.assertEqual([ref.name for ref in added], ["F-16C Template"])
        self.assertEqual(
            sorted(merged["airplanes"]["coalitions"]["blue"]["CJTF Blue"]),
            ["A-10C II Template", "F-16C Template"],
        )

    def test_an_empty_local_catalogue_takes_everything(self) -> None:
        merged, added = merge_missing(dict(EMPTY), _catalogue("One", "Two"))
        self.assertEqual(sorted(ref.name for ref in added), ["One", "Two"])
        self.assertTrue(catalogue_has_groups(merged))

    def test_a_group_lands_under_its_own_coalition_and_country(self) -> None:
        shipped = {
            "helicopters": {"coalitions": {"red": {"CJTF Red": {"Mi-24P Template": {"name": "Mi-24P Template"}}}}}
        }
        merged, added = merge_missing({}, shipped)
        self.assertEqual(added, [GroupRef("helicopters", "red", "CJTF Red", "Mi-24P Template")])
        self.assertIn("Mi-24P Template", merged["helicopters"]["coalitions"]["red"]["CJTF Red"])

    def test_a_deleted_entry_stays_deleted_when_nothing_is_asked_for(self) -> None:
        """A maker who removed an entry on purpose and pulls nothing keeps it removed."""
        mine = _catalogue("A-10C II Template", payload="mine")
        shipped = _catalogue("A-10C II Template", "F-14BU Template")

        merged, added = merge_missing(mine, shipped, names=set())

        self.assertEqual(added, [])
        self.assertEqual(merged, mine)


class TestIterGroups(unittest.TestCase):
    def test_it_reports_the_full_path_of_each_group(self) -> None:
        refs = [ref for ref, _ in iter_groups(_catalogue("F-14BU Template"))]
        self.assertEqual(refs, [GroupRef("airplanes", "blue", "CJTF Blue", "F-14BU Template")])
        self.assertEqual(str(refs[0]), "airplanes / blue / CJTF Blue / F-14BU Template")


if __name__ == "__main__":
    unittest.main()
