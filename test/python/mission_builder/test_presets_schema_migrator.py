"""Migrating a v5 `presets.yaml` to the v6 schema — FIX-CONVERT-V5-PRESETS-SCHEMA ticket 02.

The acceptance test that matters is at the bottom: the repository's **own** demo mission carries a
real v5 presets file, and the migrated result must load cleanly through `PresetsManager`. Anything
short of that is asserting my own idea of the schema rather than the reader's.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml
from mission_builder.presets_schema_migrator import (
    CONVERTED_COLLECTION_NAME,
    CONVERTED_RADIOS_COLLECTION_NAME,
    is_v5_schema,
    migrate,
)
from presets_injector.presets_manager import PresetsManager
from veaf_libs.i18n import language

_V5 = {
    "presets_definition": {
        "modern_blue": {
            "title": "Blue",
            "radios": {
                "radio_1": {
                    "title": "UHF",
                    "channels": {
                        "channel_01": {"freq": 243.0, "name": "Guard", "mod": 0},
                        "channel_02": {"freq": 260.0, "name": "Batumi"},
                    },
                },
                "radio_2": {"title": "VHF", "channels": {"channel_01": {"freq": 121.5, "name": "Guard VHF"}}},
            },
        }
    },
    "presets_assignments": {"coalitions": {"blue": {"plane": {"all": "modern_blue"}}}},
}


class TestDetection(unittest.TestCase):
    """By structure, never by file name — a name says nothing about content."""

    def test_the_v5_section_name_settles_it(self) -> None:
        self.assertTrue(is_v5_schema({"presets_definition": {}}))

    def test_the_extra_coalitions_level_settles_it(self) -> None:
        self.assertTrue(is_v5_schema({"presets_assignments": {"coalitions": {}}}))

    def test_a_v6_document_is_not_flagged(self) -> None:
        self.assertFalse(is_v5_schema({"presets_collection": {}, "presets_assignments": {"blue": {}}}))

    def test_a_half_converted_file_still_counts(self) -> None:
        # Renaming the section by hand is not enough: the file cannot be read as it stands.
        self.assertTrue(is_v5_schema({"presets_collection": {}, "presets_assignments": {"coalitions": {}}}))

    def test_nonsense_input_is_not_flagged(self) -> None:
        for value in (None, [], "presets", 3):
            self.assertFalse(is_v5_schema(value), value)


class TestMigration(unittest.TestCase):
    def setUp(self) -> None:
        self.out, self.warnings = migrate(_V5)

    def test_the_section_is_renamed_and_gains_its_collection_level(self) -> None:
        self.assertIn("presets_collection", self.out)
        self.assertNotIn("presets_definition", self.out)
        self.assertIn("modern_blue", self.out["presets_collection"][CONVERTED_COLLECTION_NAME])

    def test_radios_are_lifted_out_and_referenced_by_name(self) -> None:
        preset = self.out["presets_collection"][CONVERTED_COLLECTION_NAME]["modern_blue"]
        self.assertEqual(preset["radios"], {"radio_1": "modern_blue_radio_1", "radio_2": "modern_blue_radio_2"})
        lifted = self.out["radios_collection"][CONVERTED_RADIOS_COLLECTION_NAME]
        self.assertEqual(sorted(lifted), ["modern_blue_radio_1", "modern_blue_radio_2"])

    def test_the_radio_name_carries_the_preset_so_two_presets_cannot_collide(self) -> None:
        # A v5 file names its radios per preset — 'radio_1' in every one of them.
        two = dict(_V5)
        two["presets_definition"] = dict(_V5["presets_definition"])
        two["presets_definition"]["modern_red"] = _V5["presets_definition"]["modern_blue"]
        out, _ = migrate(two)
        lifted = out["radios_collection"][CONVERTED_RADIOS_COLLECTION_NAME]
        self.assertIn("modern_blue_radio_1", lifted)
        self.assertIn("modern_red_radio_1", lifted)

    def test_channel_keys_become_integers(self) -> None:
        channels = self.out["radios_collection"][CONVERTED_RADIOS_COLLECTION_NAME]["modern_blue_radio_1"]["channels"]
        self.assertEqual(sorted(channels), [1, 2])

    def test_a_channel_name_becomes_a_title_and_the_rest_is_untouched(self) -> None:
        channels = self.out["radios_collection"][CONVERTED_RADIOS_COLLECTION_NAME]["modern_blue_radio_1"]["channels"]
        self.assertEqual(channels[1], {"freq": 243.0, "title": "Guard", "mod": 0})
        self.assertEqual(channels[2], {"freq": 260.0, "title": "Batumi"})

    def test_the_coalitions_level_is_removed(self) -> None:
        self.assertEqual(self.out["presets_assignments"], {"blue": {"plane": {"all": "modern_blue"}}})

    def test_the_input_is_not_modified(self) -> None:
        self.assertIn("presets_definition", _V5)
        self.assertIn("coalitions", _V5["presets_assignments"])

    def test_a_clean_file_produces_no_warning(self) -> None:
        self.assertEqual(self.warnings, [])


class TestMigrationReportsWhatItCouldNotDo(unittest.TestCase):
    """A migration that guesses in silence is the defect this lot exists to remove."""

    def test_an_unrecognised_channel_key_is_reported_and_kept(self) -> None:
        data = {
            "presets_definition": {
                "p": {"radios": {"radio_1": {"channels": {"guard": {"freq": 243.0}}}}},
            }
        }
        out, warnings = migrate(data)
        channels = out["radios_collection"][CONVERTED_RADIOS_COLLECTION_NAME]["p_radio_1"]["channels"]
        self.assertIn("guard", channels)
        self.assertTrue(any("guard" in w for w in warnings), warnings)

    def test_a_preset_without_radios_is_reported(self) -> None:
        _, warnings = migrate({"presets_definition": {"p": {"title": "x"}}})
        self.assertTrue(any("radios" in w for w in warnings), warnings)

    def test_a_radio_already_given_as_a_name_is_left_alone(self) -> None:
        out, warnings = migrate({"presets_definition": {"p": {"radios": {"radio_1": "some_radio"}}}})
        self.assertEqual(out["presets_collection"][CONVERTED_COLLECTION_NAME]["p"]["radios"], {"radio_1": "some_radio"})
        self.assertNotIn("radios_collection", out)

    def test_other_sections_are_carried_over_untouched(self) -> None:
        out, _ = migrate({"presets_definition": {}, "channel_lists": {"blue": {"primary_1": {1: "Guard"}}}})
        self.assertEqual(out["channel_lists"], {"blue": {"primary_1": {1: "Guard"}}})


class TestInferredRadioType(unittest.TestCase):
    """v6 requires a radio `type:` that v5 never wrote, so one has to be chosen.

    It is only ever consulted to resolve a channel *alias*, and converted channels carry explicit
    frequencies, so the value cannot change what is injected. It still has to be right, because a
    mission maker reads this file.
    """

    def _type_of(self, freqs: list[float]) -> tuple[str, list[str]]:
        channels = {f"channel_{i:02d}": {"freq": f} for i, f in enumerate(freqs, 1)}
        out, warnings = migrate({"presets_definition": {"p": {"radios": {"radio_1": {"channels": channels}}}}})
        return out["radios_collection"][CONVERTED_RADIOS_COLLECTION_NAME]["p_radio_1"]["type"], warnings

    def test_uhf(self) -> None:
        self.assertEqual(self._type_of([243.0, 260.0, 399.0])[0], "uhf")

    def test_vhf(self) -> None:
        self.assertEqual(self._type_of([121.5, 140.0])[0], "vhf")

    def test_fm(self) -> None:
        self.assertEqual(self._type_of([30.0, 34.0, 87.5])[0], "fm")

    def test_a_radio_spanning_bands_is_reported_rather_than_chosen_in_silence(self) -> None:
        band, warnings = self._type_of([243.0, 260.0, 30.0])
        self.assertEqual(band, "uhf", "the majority band")
        self.assertTrue(any("several bands" in w for w in warnings), warnings)

    def test_no_frequency_at_all_is_reported(self) -> None:
        out, warnings = migrate({"presets_definition": {"p": {"radios": {"radio_1": {"channels": {}}}}}})
        self.assertEqual(out["radios_collection"][CONVERTED_RADIOS_COLLECTION_NAME]["p_radio_1"]["type"], "uhf")
        self.assertTrue(any("no frequency" in w for w in warnings), warnings)

    def test_an_explicit_type_is_never_overwritten(self) -> None:
        out, _ = migrate(
            {"presets_definition": {"p": {"radios": {"radio_1": {"type": "fm", "channels": {"channel_01": 243.0}}}}}}
        )
        self.assertEqual(out["radios_collection"][CONVERTED_RADIOS_COLLECTION_NAME]["p_radio_1"]["type"], "fm")


class TestTheRepositorysOwnDemoMission(unittest.TestCase):
    """The real fixture that started this, migrated and then read by the real reader.

    A frozen copy of the demo's former v5 presets, owned by this test so the demo could move to v6
    (MIGRATE-DEMO-MISSION-V6 ticket 01).
    """

    SOURCE = Path(__file__).parents[3] / "test" / "veaf-tools" / "migration-v5-fixture" / "src" / "presets.yaml"

    def test_the_fixture_is_still_v5(self) -> None:
        # It must stay v5, or this test stops testing the v5 → v6 path. If this fails, something
        # converted it in place — which convert-v5 does by default.
        data = yaml.safe_load(self.SOURCE.read_text(encoding="utf-8"))
        self.assertTrue(is_v5_schema(data))

    def test_the_migrated_file_loads_through_the_real_reader(self) -> None:
        data = yaml.safe_load(self.SOURCE.read_text(encoding="utf-8"))
        migrated, _ = migrate(data)

        path = Path(tempfile.mkdtemp()) / "presets.yaml"
        path.write_text(yaml.safe_dump(migrated, allow_unicode=True, sort_keys=False), encoding="utf-8")
        manager = PresetsManager()
        with language("en"):
            manager.read_yaml(path)  # raises if anything is off

        assignment = manager.get_radios_for(coalition="blue", aircraft_type="plane", unit_type="F-16C_50")
        self.assertIsNotNone(assignment, "the blue plane assignment must survive the migration")

    def test_every_frequency_survives_the_migration(self) -> None:
        data = yaml.safe_load(self.SOURCE.read_text(encoding="utf-8"))
        before = sorted(
            channel["freq"]
            for preset in data["presets_definition"].values()
            for radio in preset["radios"].values()
            for channel in radio["channels"].values()
            if isinstance(channel, dict) and "freq" in channel
        )
        migrated, _ = migrate(data)
        after = sorted(
            channel["freq"]
            for radio in migrated["radios_collection"][CONVERTED_RADIOS_COLLECTION_NAME].values()
            for channel in radio["channels"].values()
            if isinstance(channel, dict) and "freq" in channel
        )
        self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
