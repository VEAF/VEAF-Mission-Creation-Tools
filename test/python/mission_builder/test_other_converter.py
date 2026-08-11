"""Tests for the third-party (non-VEAF) mission converter — FOOTHOLD-V6-001.

Detection of native script-loader triggers: the converter must list the scripts
loaded by a third-party mission's native triggers, **in load order**, so it can
scaffold an ordered ``custom_scripts:`` block. Structure mirrors the real Foothold
Caucasus `.miz` (Lekaa): each loader trigrule carries ordered ``a_do_script_file``
actions whose ``file`` is a ``mapResource`` key resolving to a ``.lua`` filename.
"""

import os
import tempfile
import textwrap
import unittest
import zipfile
from pathlib import Path

from mission_builder.other_converter import (
    DetectedLoader,
    OtherMissionConverter,
    build_scaffold_yaml,
    detect_native_loader_triggers,
    detect_native_script_loaders,
    diff_scripts,
)
from mission_tools.miz_tools import DcsMission


def _mission(trigrules: dict, mapres: dict) -> DcsMission:
    return DcsMission(
        file_path=Path("x.miz"),
        mission_content={"trigrules": trigrules},
        map_resource_content=mapres,
    )


class TestDetectNativeScriptLoaders(unittest.TestCase):
    def test_orders_by_trigrule_then_action_and_resolves_lua(self) -> None:
        trigrules = {
            2: {
                "comment": "ScriptLoader 1",
                "predicate": "triggerStart",
                "actions": [
                    {"predicate": "a_do_script_file", "file": "K1"},
                    {"predicate": "a_do_script_file", "file": "K2"},
                ],
            },
            3: {
                "comment": "ScriptLoader 2",
                "predicate": "triggerStart",
                "actions": [
                    {"predicate": "a_do_script_file", "file": "K3"},
                ],
            },
        }
        mapres = {"K1": "Moose.lua", "K2": "Foothold Config.lua", "K3": "MA_Setup_CA.lua"}

        result = detect_native_script_loaders(_mission(trigrules, mapres))

        self.assertEqual(
            [d.script for d in result],
            ["Moose.lua", "Foothold Config.lua", "MA_Setup_CA.lua"],
        )
        self.assertEqual(result[0], DetectedLoader("Moose.lua", 2, "ScriptLoader 1"))
        self.assertEqual(result[2].trigger_index, 3)

    def test_ignores_non_lua_resources(self) -> None:
        trigrules = {1: {"comment": "sounds", "actions": [{"predicate": "a_do_script_file", "file": "S"}]}}
        mapres = {"S": "beacon.ogg"}

        self.assertEqual(detect_native_script_loaders(_mission(trigrules, mapres)), [])

    def test_ignores_unresolved_keys(self) -> None:
        trigrules = {1: {"comment": "x", "actions": [{"predicate": "a_do_script_file", "file": "MISSING"}]}}

        self.assertEqual(detect_native_script_loaders(_mission(trigrules, {})), [])

    def test_empty_mission_yields_nothing(self) -> None:
        self.assertEqual(detect_native_script_loaders(DcsMission(file_path=Path("x.miz"))), [])

    def test_mixed_action_key_types_do_not_raise(self) -> None:
        # Defensive: a parser yielding mixed int/str keys must not crash sorting.
        trigrules = {
            1: {
                "comment": "X",
                "actions": {2: {"predicate": "a_do_script_file", "file": "K2"}, "a": {"predicate": "noop"}},
            }
        }
        mapres = {"K2": "Second.lua"}

        result = detect_native_script_loaders(_mission(trigrules, mapres))

        self.assertEqual([d.script for d in result], ["Second.lua"])

    def test_handles_dict_form_actions_keyed_by_index(self) -> None:
        # DCS stores actions as a dict keyed by numeric index (the real .miz form),
        # the keys carrying the order — not as a list.
        trigrules = {
            1: {
                "comment": "ScriptLoader",
                "actions": {
                    2: {"predicate": "a_do_script_file", "file": "K2"},
                    1: {"predicate": "a_do_script_file", "file": "K1"},
                },
            }
        }
        mapres = {"K1": "First.lua", "K2": "Second.lua"}

        result = detect_native_script_loaders(_mission(trigrules, mapres))

        self.assertEqual([d.script for d in result], ["First.lua", "Second.lua"])


class TestDetectNativeLoaderTriggers(unittest.TestCase):
    def test_lists_loader_trigrules_in_order_with_comment(self) -> None:
        trigrules = {
            3: {"comment": "ScriptLoader 2", "actions": [{"predicate": "a_do_script_file", "file": "K3"}]},
            2: {"comment": "ScriptLoader 1", "actions": [{"predicate": "a_do_script_file", "file": "K1"}]},
        }
        mapres = {"K1": "Moose.lua", "K3": "Setup.lua"}

        result = detect_native_loader_triggers(_mission(trigrules, mapres))

        self.assertEqual(result, [(2, "ScriptLoader 1"), (3, "ScriptLoader 2")])

    def test_detects_inline_loader_via_do_script(self) -> None:
        trigrules = {1: {"comment": "boot", "actions": [{"predicate": "a_do_script", "text": "dofile('x.lua')"}]}}

        self.assertEqual(detect_native_loader_triggers(_mission(trigrules, {})), [(1, "boot")])

    def test_ignores_triggers_without_script_loading(self) -> None:
        trigrules = {1: {"comment": "flag", "actions": [{"predicate": "a_set_flag_value", "text": "x"}]}}

        self.assertEqual(detect_native_loader_triggers(_mission(trigrules, {})), [])


class TestBuildScaffoldYaml(unittest.TestCase):
    def _loaders(self) -> list[DetectedLoader]:
        return [
            DetectedLoader("Moose.lua", 2, "ScriptLoader 1"),
            DetectedLoader("Foothold Config.lua", 2, "ScriptLoader 1"),
            DetectedLoader("AIEN.lua", 5, "AIEN"),
        ]

    def test_custom_scripts_listed_in_order(self) -> None:
        yaml = build_scaffold_yaml(self._loaders(), [(2, "ScriptLoader 1"), (5, "AIEN")])

        i_moose = yaml.index("Moose.lua")
        i_config = yaml.index("Foothold Config.lua")
        i_aien = yaml.index("AIEN.lua")
        self.assertTrue(i_moose < i_config < i_aien)
        self.assertIn("custom_scripts:", yaml)

    def test_paths_with_spaces_are_quoted(self) -> None:
        yaml = build_scaffold_yaml(self._loaders(), [])

        self.assertIn('"src/scripts/Foothold Config.lua"', yaml)
        self.assertIn("src/scripts/Moose.lua", yaml)

    def test_strip_native_triggers_lists_comments(self) -> None:
        yaml = build_scaffold_yaml(self._loaders(), [(2, "ScriptLoader 1"), (5, "AIEN")])

        self.assertIn("strip_native_triggers:", yaml)
        self.assertIn("ScriptLoader 1", yaml)
        self.assertIn("AIEN", yaml)

    def test_modules_block_uses_minimal_tier(self) -> None:
        yaml = build_scaffold_yaml(self._loaders(), [])

        self.assertIn("modules:", yaml)
        # The 'minimal' tier enables the core feature modules.
        self.assertRegex(yaml, r"RADIO:\s*true")
        self.assertRegex(yaml, r"SPAWN:\s*true")
        # A standard-tier-only module (WEATHER) is not enabled in minimal.
        self.assertNotRegex(yaml, r"^\s*WEATHER:\s*true")


class TestBuildScaffoldYamlWithProfile(unittest.TestCase):
    def _profile(self):  # type: ignore[no-untyped-def]
        from veaf_libs.conversion_profile import load_profile

        return load_profile("foothold")

    def test_writes_conversion_profile_marker(self) -> None:
        yaml = build_scaffold_yaml([], [], self._profile())
        self.assertIn("conversion_profile: foothold", yaml)

    def test_modules_block_comes_from_profile(self) -> None:
        yaml = build_scaffold_yaml([], [], self._profile())
        self.assertIn("'foothold' conversion profile", yaml)
        self.assertRegex(yaml, r"RADIO:\s*true")
        # CTLD is incompatible — never enabled by the scaffold.
        self.assertNotRegex(yaml, r"^\s*CTLD:\s*true")

    def test_config_override_scaffold_is_commented(self) -> None:
        yaml = build_scaffold_yaml([], [], self._profile())
        self.assertIn("# config_override:", yaml)
        self.assertIn("Foothold Config.lua", yaml)
        self.assertIn("CapDifficulty", yaml)

    def test_config_override_scaffold_offers_foothold_locale(self) -> None:
        # The locale is a setting a VEAF mission-maker actually changes, so the commented
        # scaffold must surface it (upstream config V1.0.9 accepts "FR").
        yaml = build_scaffold_yaml([], [], self._profile())
        self.assertIn("#     FootholdLocale: FR", yaml)

    def test_community_scripts_disabled_inside_modules_block(self) -> None:
        # FOOTHOLD-V6-009 fix: disables go INSIDE the unified modules: block — a separate
        # community_scripts: block is the deprecated form and is ignored when modules: exists.
        yaml = build_scaffold_yaml([], [], self._profile())
        self.assertNotIn("community_scripts:", yaml)  # no separate (deprecated, ignored) block
        modules_body = yaml.split("modules:", 1)[1]
        for sid in ("ctld", "aien", "csar", "skynet", "stts", "hercules", "tum"):
            self.assertIn(f"{sid}: false", modules_body, f"{sid} must be disabled inside modules:")

    def test_no_disabled_community_lines_without_profile(self) -> None:
        yaml = build_scaffold_yaml([], [], None)
        self.assertNotIn("community_scripts:", yaml)
        self.assertNotIn("aien: false", yaml)


#: A real upstream Foothold Caucasus `.miz`, if the developer has one. Overridable via
#: ``VEAF_TEST_FOOTHOLD_MIZ`` so the path does not rot with each Lekaa release (the
#: default below tracks the release these tests were last exercised against).
_REAL_MIZ = Path(
    os.environ.get(
        "VEAF_TEST_FOOTHOLD_MIZ",
        r"D:\dev\_VEAF\tmp\foothold-2026.07.28"
        r"\Foothold_CA_4.4.1_Multi_Language_Coldwar-Modern-Vietnam"
        r"\Foothold_CA_4.4.1_Multi_Language_Coldwar-Modern-Vietnam.miz",
    )
)


@unittest.skipUnless(_REAL_MIZ.exists(), "real third-party Foothold .miz not available")
class TestOtherMissionConverterIntegration(unittest.TestCase):
    """End-to-end on the real Lekaa Foothold Caucasus `.miz`."""

    def test_scaffold_lists_scripts_in_load_order(self) -> None:
        from mission_builder.other_converter import OtherMissionConverter

        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "mission"
            report = OtherMissionConverter(version="test").convert(_REAL_MIZ, out)

            self.assertTrue(report.mission_yaml_generated)
            yaml = (out / "mission.yaml").read_text(encoding="utf-8")
            expected_order = [
                "Moose_2026-06-14.lua",
                "Foothold_Localization.lua",
                "Foothold Config.lua",
                "zoneCommander.lua",
                "MA_Setup_CA.lua",
                "WelcomeMessage.lua",
                "Zeus.lua",
                "EWRS.lua",
                "Foothold CTLD.lua",
                "Foothold_CTLD_Red.lua",
                "Splash_Damage_3.4.1_leka.lua",
                "AIEN.lua",
            ]
            positions = [yaml.index(name) for name in expected_order]
            self.assertEqual(positions, sorted(positions), "custom_scripts must follow native load order")
            self.assertIn("strip_native_triggers:", yaml)
            # Extracted scripts land in src/scripts/.
            self.assertTrue((out / "src" / "scripts" / "AIEN.lua").exists())

    def test_foothold_profile_normalizes_versioned_names_and_marks_profile(self) -> None:
        from mission_builder.other_converter import OtherMissionConverter

        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "mission"
            OtherMissionConverter(version="test").convert(_REAL_MIZ, out, profile_name="foothold")

            yaml = (out / "mission.yaml").read_text(encoding="utf-8")
            self.assertIn("conversion_profile: foothold", yaml)
            # Both version-stamped names normalised, on disk and in the scaffold, so the
            # custom_scripts paths survive the next Lekaa bump.
            for versioned, fixed in (
                ("Moose_2026-06-14.lua", "Moose.lua"),
                ("Splash_Damage_3.4.1_leka.lua", "Splash_Damage.lua"),
            ):
                self.assertTrue((out / "src" / "scripts" / fixed).exists(), fixed)
                self.assertFalse((out / "src" / "scripts" / versioned).exists(), versioned)
                self.assertIn(f"src/scripts/{fixed}", yaml)
                self.assertNotIn(versioned, yaml)

    def test_existing_yaml_not_overwritten_without_force(self) -> None:
        from mission_builder.other_converter import OtherMissionConverter

        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "mission"
            out.mkdir(parents=True)
            (out / "mission.yaml").write_text("sentinel: true\n", encoding="utf-8")

            report = OtherMissionConverter(version="test").convert(_REAL_MIZ, out, force=False)

            self.assertFalse(report.mission_yaml_generated)
            self.assertIn("sentinel: true", (out / "mission.yaml").read_text(encoding="utf-8"))

    def test_update_preserves_yaml_and_refreshes_scripts(self) -> None:
        """`--update` re-import: refresh scripts, preserve the tuned mission.yaml, report the diff."""
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "mission"
            # First adoption (scaffolds mission.yaml, extracts scripts).
            OtherMissionConverter(version="test").convert(_REAL_MIZ, out, profile_name="foothold")

            # Tune mission.yaml and tamper a script to prove the refresh overwrites it.
            yaml_path = out / "mission.yaml"
            yaml_path.write_text(yaml_path.read_text(encoding="utf-8") + "\n# TUNED BY USER\n", encoding="utf-8")
            aien = out / "src" / "scripts" / "AIEN.lua"
            aien.write_text("-- TAMPERED\n", encoding="utf-8")

            # Re-import the same upstream with --update.
            report = OtherMissionConverter(version="test").convert(_REAL_MIZ, out, profile_name="foothold", update=True)

            # mission.yaml preserved (never regenerated in update mode).
            self.assertFalse(report.mission_yaml_generated)
            self.assertTrue(report.mission_yaml_existed)
            self.assertIn("# TUNED BY USER", yaml_path.read_text(encoding="utf-8"))
            # The tampered script was refreshed from upstream.
            self.assertNotEqual(aien.read_text(encoding="utf-8"), "-- TAMPERED\n")
            # The report flags the refreshed (updated) script (case-insensitive on Windows).
            self.assertTrue(any("aien.lua" in a.lower() for a in report.actions))


class TestDiffScripts(unittest.TestCase):
    """Pure add/remove/update diff for `--update` (FOOTHOLD-V6-005)."""

    def test_added_are_upstream_not_seen_before(self) -> None:
        diff = diff_scripts(before={"A.lua": "h1"}, after={"A.lua": "h1", "B.lua": "h2"}, upstream={"A.lua", "B.lua"})
        self.assertEqual(diff.added, ("B.lua",))
        self.assertEqual(diff.removed, ())
        self.assertEqual(diff.updated, ())

    def test_removed_are_gone_from_upstream(self) -> None:
        diff = diff_scripts(before={"A.lua": "h1", "Old.lua": "h0"}, after={"A.lua": "h1"}, upstream={"A.lua"})
        self.assertEqual(diff.removed, ("Old.lua",))

    def test_updated_are_common_with_changed_hash(self) -> None:
        diff = diff_scripts(before={"A.lua": "h1"}, after={"A.lua": "h2"}, upstream={"A.lua"})
        self.assertEqual(diff.updated, ("A.lua",))

    def test_unchanged_yields_empty_diff(self) -> None:
        diff = diff_scripts(before={"A.lua": "h1"}, after={"A.lua": "h1"}, upstream={"A.lua"})
        self.assertTrue(diff.is_empty())

    def test_results_are_sorted(self) -> None:
        diff = diff_scripts(before={}, after={}, upstream={"Z.lua", "A.lua", "M.lua"})
        self.assertEqual(diff.added, ("A.lua", "M.lua", "Z.lua"))


if __name__ == "__main__":
    unittest.main()


class TestDetectedDelay(unittest.TestCase):
    """A loader trigger's `c_time_after` seconds, so an adoption reproduces the staging.

    Shapes taken from the real upstream `.miz` (Foothold_CA 4.4.1): a staged loader is a
    `triggerOnce` whose single rule is `{predicate: c_time_after, seconds: N}` — alongside
    `coalitionlist`/`unitType`/`zone` leftovers of the editor's form, which are ignored here.
    Verified end to end against that mission: 6 scripts with no delay, 5 at +3 s, AIEN at +12 s.
    """

    def _staged(self, rules) -> DcsMission:
        return _mission(
            {
                2: {
                    "comment": "ScriptLoader 1",
                    "predicate": "triggerStart",
                    "actions": [{"predicate": "a_do_script_file", "file": "K1"}],
                },
                3: {
                    "comment": "AIEN",
                    "predicate": "triggerOnce",
                    "rules": rules,
                    "actions": [{"predicate": "a_do_script_file", "file": "K2"}],
                },
            },
            {"K1": "Moose.lua", "K2": "AIEN.lua"},
        )

    def test_an_undelayed_loader_reports_no_delay(self):
        loaders = detect_native_script_loaders(self._staged({1: {"predicate": "c_time_after", "seconds": 12}}))
        self.assertIsNone(loaders[0].delay_seconds)

    def test_a_delayed_loader_reports_its_seconds(self):
        loaders = detect_native_script_loaders(self._staged({1: {"predicate": "c_time_after", "seconds": 12}}))
        self.assertEqual(12.0, loaders[1].delay_seconds)

    def test_the_editor_leftovers_beside_the_rule_are_ignored(self):
        rules = {1: {"coalitionlist": "red", "unitType": "ALL", "zone": 365, "predicate": "c_time_after", "seconds": 3}}
        self.assertEqual(3.0, detect_native_script_loaders(self._staged(rules))[1].delay_seconds)

    def test_rules_as_a_list_work_too(self):
        # luadata may hand a 1-based table back as either a dict or a list.
        rules = [{"predicate": "c_time_after", "seconds": 7}]
        self.assertEqual(7.0, detect_native_script_loaders(self._staged(rules))[1].delay_seconds)

    def test_a_zero_delay_is_no_delay(self):
        rules = {1: {"predicate": "c_time_after", "seconds": 0}}
        self.assertIsNone(detect_native_script_loaders(self._staged(rules))[1].delay_seconds)

    def test_another_predicate_is_not_a_delay(self):
        rules = {1: {"predicate": "c_flag_is_true", "seconds": 5}}
        self.assertIsNone(detect_native_script_loaders(self._staged(rules))[1].delay_seconds)

    def test_a_non_numeric_seconds_is_ignored(self):
        rules = {1: {"predicate": "c_time_after", "seconds": "soon"}}
        self.assertIsNone(detect_native_script_loaders(self._staged(rules))[1].delay_seconds)


class TestScaffoldReproducesTheStaging(unittest.TestCase):
    """The real prize of the ticket: an adopted mission stages like upstream by default."""

    def test_a_delayed_script_gets_delay_seconds(self):
        yaml_text = build_scaffold_yaml(
            [
                DetectedLoader("Moose.lua", 2, "ScriptLoader 1"),
                DetectedLoader("AIEN.lua", 5, "AIEN", 12.0),
            ],
            [],
        )
        # The delay must sit under its own path entry, indented as a mapping key of it — a
        # `delay_seconds` at the wrong depth would be a sibling entry, not this script's delay.
        self.assertIn(
            "\n".join(["    - path: src/scripts/AIEN.lua", "      delay_seconds: 12"]),
            yaml_text,
        )

    def test_an_undelayed_script_gets_no_such_key(self):
        yaml_text = build_scaffold_yaml([DetectedLoader("Moose.lua", 2, "ScriptLoader 1")], [])
        self.assertNotIn("delay_seconds", yaml_text)

    def test_a_fractional_delay_survives(self):
        yaml_text = build_scaffold_yaml([DetectedLoader("A.lua", 2, "c", 0.5)], [])
        self.assertIn("delay_seconds: 0.5", yaml_text)

    def test_the_scaffold_is_still_valid_yaml(self):
        import yaml as yaml_module

        parsed = yaml_module.safe_load(
            build_scaffold_yaml(
                [DetectedLoader("Moose.lua", 2, "c"), DetectedLoader("AIEN.lua", 5, "AIEN", 12.0)],
                [],
            )
        )
        self.assertEqual(
            [{"path": "src/scripts/Moose.lua"}, {"path": "src/scripts/AIEN.lua", "delay_seconds": 12}],
            parsed["custom_scripts"]["scripts"],
        )


class TestUpdateReportsAStagingChange(unittest.TestCase):
    """`--update` preserves the tuned mission.yaml, so a moved delay has to be said out loud."""

    def _report_for(self, declared_yaml: str, loaders):
        from mission_builder.other_converter import _delay_changes

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "mission.yaml"
            path.write_text(declared_yaml, encoding="utf-8")
            return _delay_changes(path, loaders)

    _DECLARED = textwrap.dedent("""        custom_scripts:
          scripts:
            - path: src/scripts/AIEN.lua
              delay_seconds: 12
        """)

    def test_an_unchanged_delay_is_silent(self):
        self.assertEqual([], self._report_for(self._DECLARED, [DetectedLoader("AIEN.lua", 5, "AIEN", 12.0)]))

    def test_a_changed_delay_is_reported_with_both_values(self):
        changes = self._report_for(self._DECLARED, [DetectedLoader("AIEN.lua", 5, "AIEN", 20.0)])
        self.assertEqual(1, len(changes))
        self.assertIn("AIEN.lua", changes[0])
        self.assertIn("12", changes[0])
        self.assertIn("20", changes[0])

    def test_a_delay_dropped_upstream_is_reported(self):
        changes = self._report_for(self._DECLARED, [DetectedLoader("AIEN.lua", 5, "AIEN", None)])
        self.assertEqual(1, len(changes))

    def test_a_delay_added_upstream_is_reported(self):
        declared = textwrap.dedent("""            custom_scripts:
              scripts:
                - path: src/scripts/AIEN.lua
            """)
        changes = self._report_for(declared, [DetectedLoader("AIEN.lua", 5, "AIEN", 12.0)])
        self.assertEqual(1, len(changes))

    def test_a_script_absent_from_the_yaml_is_not_reported(self):
        # It is an *added* script, which the existing diff already reports; saying it twice with a
        # confusing "declared none" would just be noise.
        changes = self._report_for(self._DECLARED, [DetectedLoader("New.lua", 6, "c", 5.0)])
        self.assertEqual([], changes)

    def test_a_missing_yaml_reports_nothing(self):
        from mission_builder.other_converter import _delay_changes

        self.assertEqual([], _delay_changes(None, [DetectedLoader("AIEN.lua", 5, "AIEN", 12.0)]))
