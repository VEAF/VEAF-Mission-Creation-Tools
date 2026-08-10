"""Tests for declaring the CTLD/CSAR sounds so the Mission Editor keeps them.

`BUILD-COMMUNITY-SOUNDS-001` embedded the `.ogg` files and stopped there, by its own stated
scope: *"files-only — no mapResource entry, no out_sound trigger"*. Measured consequence
(FIX-COMMUNITY-SOUNDS-PRUNED): opening a built mission in the DCS Mission Editor and saving it
**deletes** `CSAR.ogg`, `beacon.ogg`, `beaconsilent.ogg` and `csar-beacon.ogg`. The editor keeps
what its own resource table declares and prunes the rest — reasonable, since CTLD and CSAR ask for
these by filename at runtime from a script it never reads.

The repair is the trick the v5 missions already carried: a mission-start action playing each sound
to a country **nobody uses**, plus the `mapResource` entry that action needs. Nothing is audible;
the resource simply becomes something the editor knows about.

The rule is about **orphans**, not about CTLD/CSAR. The sounds that were measured came from the
mission's own `src/mission/l10n/DEFAULT/` with both modules *disabled*, so keying on the
tool-injected set would have missed the very case that started this.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import (
    MissionBuilderWorker,
    SoundAction,
    _emit_trig_action_string,
    _emit_trigrule_actions,
)
from mission_tools.miz_tools import DcsMission


def _make_worker(yaml_content: str = "") -> MissionBuilderWorker:
    with tempfile.TemporaryDirectory() as tmpdir:
        mission_dir = Path(tmpdir)
        (mission_dir / "mission.yaml").write_text(yaml_content, encoding="utf-8")
        return MissionBuilderWorker(
            mission_folder=mission_dir,
            output_mission=mission_dir / "out.miz",
            dynamic_mode=None,
        )


def _mission_using_countries(*country_ids: int) -> DcsMission:
    """A mission whose blue coalition holds the given country ids."""
    return DcsMission(
        file_path=Path("dummy.miz"),
        mission_content={
            "coalition": {
                "blue": {"country": [{"id": cid, "name": f"C{cid}"} for cid in country_ids]},
                "red": {"country": []},
            },
            "trig": {"actions": {}, "conditions": {}},
            "trigrules": {},
        },
        dictionary_content={},
        map_resource_content={},
    )


class TestSoundActionEmission(unittest.TestCase):
    """One action, two forms — the compiled `trig` string and the editor `trigrules` dict."""

    def test_trig_form_matches_the_dcs_call(self) -> None:
        emitted = _emit_trig_action_string([SoundAction(map_key="VEAF_MapKey_Sound_0", country_id=7)])
        self.assertEqual(emitted, 'a_out_sound_c(7, getValueResourceByKey("VEAF_MapKey_Sound_0"), 0);')

    def test_trigrule_form_declares_the_file(self) -> None:
        # `file` is the field the Mission Editor's resource scan reads; without it the .ogg is an
        # orphan and gets pruned, which is the whole defect.
        emitted = _emit_trigrule_actions([SoundAction(map_key="VEAF_MapKey_Sound_0", country_id=7)])
        self.assertEqual(
            emitted,
            [
                {
                    "predicate": "a_out_sound_c",
                    "countrylist": 7,
                    "file": "VEAF_MapKey_Sound_0",
                    "start_delay": 0,
                }
            ],
        )

    def test_mixed_actions_keep_their_order(self) -> None:
        from mission_builder.mission_builder_worker import LuaAction

        emitted = _emit_trig_action_string([LuaAction('env.info("x")'), SoundAction(map_key="K", country_id=1)])
        self.assertEqual(emitted, 'a_do_script("env.info(\\"x\\")");a_out_sound_c(1, getValueResourceByKey("K"), 0);')


class TestUnusedCountryId(unittest.TestCase):
    """The country is chosen by looking at the mission, not by hardcoding one.

    A hardcoded id is correct until the day a mission actually uses that country and its pilots
    start hearing beacons at mission start.
    """

    def test_picks_an_id_the_mission_does_not_use(self) -> None:
        worker = _make_worker()
        worker.dcs_mission = _mission_using_countries(0, 1, 2)
        self.assertNotIn(worker._unused_country_id(), {0, 1, 2})

    def test_avoids_ids_used_by_either_coalition(self) -> None:
        worker = _make_worker()
        worker.dcs_mission = _mission_using_countries(0, 1)
        worker.dcs_mission.mission_content["coalition"]["red"]["country"] = [{"id": 2, "name": "C2"}]
        self.assertNotIn(worker._unused_country_id(), {0, 1, 2})

    def test_returns_a_real_dcs_country_id(self) -> None:
        # An id DCS does not know makes the Mission Editor crash on load, so the candidate set is
        # the generated country table rather than an arbitrary large number.
        from veaf_libs.dcs_countries import all_country_ids

        worker = _make_worker()
        worker.dcs_mission = _mission_using_countries(0)
        self.assertIn(worker._unused_country_id(), all_country_ids())

    def test_is_stable_across_calls(self) -> None:
        # Two builds of the same mission must produce the same trigger, or every rebuild shows a
        # spurious diff.
        worker = _make_worker()
        worker.dcs_mission = _mission_using_countries(0, 1, 2)
        self.assertEqual(worker._unused_country_id(), worker._unused_country_id())

    def test_avoids_the_countries_missions_actually_use(self) -> None:
        # The low ids are Russia/Ukraine/USA/Turkey. Handing out Turkey on a Syria map would play
        # beacons at its pilots the day someone adds it, so the choice comes from the top of the
        # table, not the bottom.
        from veaf_libs.dcs_countries import country_id_for_name

        worker = _make_worker()
        worker.dcs_mission = _mission_using_countries(0, 1, 2)
        chosen = worker._unused_country_id()
        for common in ("Russia", "Ukraine", "USA", "Turkey", "UK", "France", "Germany"):
            self.assertNotEqual(chosen, country_id_for_name(common), f"{common} is a country missions use")


class TestSoundTriggerIsBuilt(unittest.TestCase):
    """The 7th VEAF trigger exists exactly when the mission carries an undeclared sound."""

    def _specs(
        self,
        yaml_content: str = "",
        tool_sounds: dict[str, bytes] | None = None,
        mission_files: dict[str, bytes] | None = None,
        declared: dict[str, str] | None = None,
    ) -> list:
        worker = _make_worker(yaml_content)
        worker.dcs_mission = _mission_using_countries(0, 1, 2)
        worker.dcs_mission.map_resource_content = dict(declared or {})
        worker.collected_community_sound_files = tool_sounds or {}
        worker.collected_mission_data_files = mission_files or {}
        return worker._build_veaf_trigger_specs({}, {})

    def test_present_for_a_tool_injected_sound(self) -> None:
        specs = self._specs(tool_sounds={"l10n/DEFAULT/beacon.ogg": b"x"})
        sound_specs = [s for s in specs if any(isinstance(a, SoundAction) for a in s.actions)]
        self.assertEqual(len(sound_specs), 1)
        self.assertEqual(len(sound_specs[0].actions), 1)

    def test_present_for_a_sound_the_mission_brought_itself(self) -> None:
        # The measured case: CTLD and CSAR both **off**, the .ogg files sitting in the mission's own
        # src/mission/l10n/DEFAULT/. Keying on the tool-injected set alone missed exactly this, which
        # is how the first implementation of this fix left the reported bug in place.
        specs = self._specs(
            yaml_content="modules:\n  CTLD: false\n  CSAR: false\n",
            mission_files={"l10n/DEFAULT/csar-beacon.ogg": b"x"},
        )
        sound_spec = next(s for s in specs if any(isinstance(a, SoundAction) for a in s.actions))
        self.assertEqual(len(sound_spec.actions), 1)

    def test_absent_when_the_mission_carries_no_sound(self) -> None:
        specs = self._specs()
        self.assertEqual([s for s in specs if any(isinstance(a, SoundAction) for a in s.actions)], [])
        # and the other six are untouched
        self.assertEqual(len(specs), 6)

    def test_an_already_declared_sound_is_left_alone(self) -> None:
        # A briefing clip with its own trigger is not an orphan; declaring it twice would be noise.
        specs = self._specs(
            mission_files={"l10n/DEFAULT/briefing.ogg": b"x"},
            declared={"ResKey_Action_900": "briefing.ogg"},
        )
        self.assertEqual([s for s in specs if any(isinstance(a, SoundAction) for a in s.actions)], [])

    def test_non_sound_mission_files_are_ignored(self) -> None:
        specs = self._specs(mission_files={"l10n/DEFAULT/kneeboard.png": b"x", "l10n/DEFAULT/notes.txt": b"y"})
        self.assertEqual([s for s in specs if any(isinstance(a, SoundAction) for a in s.actions)], [])

    def test_one_action_per_sound_from_either_source(self) -> None:
        specs = self._specs(
            tool_sounds={"l10n/DEFAULT/beacon.ogg": b"x", "l10n/DEFAULT/beaconsilent.ogg": b"y"},
            mission_files={"l10n/DEFAULT/CSAR.ogg": b"z"},
        )
        sound_spec = next(s for s in specs if any(isinstance(a, SoundAction) for a in s.actions))
        self.assertEqual(len(sound_spec.actions), 3)

    def test_each_sound_gets_a_map_resource_entry(self) -> None:
        worker = _make_worker("")
        worker.dcs_mission = _mission_using_countries(0)
        worker.dcs_mission.map_resource_content = {}
        worker.collected_community_sound_files = {
            "l10n/DEFAULT/beacon.ogg": b"x",
            "l10n/DEFAULT/CSAR.ogg": b"z",
        }
        worker.collected_mission_data_files = {}
        specs = worker._build_veaf_trigger_specs({}, {})
        sound_spec = next(s for s in specs if any(isinstance(a, SoundAction) for a in s.actions))

        resources = worker.dcs_mission.map_resource_content or {}
        for action in sound_spec.actions:
            self.assertIn(action.map_key, resources, "the action's key must resolve to a file")
        self.assertEqual(sorted(resources[a.map_key] for a in sound_spec.actions), ["CSAR.ogg", "beacon.ogg"])

    def test_map_resource_value_is_the_bare_filename(self) -> None:
        # CTLD calls outSound("beacon.ogg"); an l10n/DEFAULT/ prefix here would not resolve.
        worker = _make_worker("")
        worker.dcs_mission = _mission_using_countries(0)
        worker.dcs_mission.map_resource_content = {}
        worker.collected_community_sound_files = {"l10n/DEFAULT/beacon.ogg": b"x"}
        worker.collected_mission_data_files = {}
        worker._build_veaf_trigger_specs({}, {})
        self.assertEqual(list((worker.dcs_mission.map_resource_content or {}).values()), ["beacon.ogg"])


class TestOnlySoundsAreDeclared(unittest.TestCase):
    """The declaration covers sounds, and deliberately nothing else (ticket 02).

    `veafDynamicConfig.lua` is packaged into the archive and read from **disk** at runtime
    (`VEAF_DYNAMIC_MISSIONPATH`), never from the archive; static mode does not load it at all,
    since it *is* the dynamic loader. So the editor pruning that copy costs nothing, and declaring
    it would assert a dependency that does not exist.
    """

    def test_a_lua_orphan_is_not_declared(self) -> None:
        worker = _make_worker()
        worker.dcs_mission = _mission_using_countries(0)
        worker.dcs_mission.map_resource_content = {}
        worker.collected_community_sound_files = {}
        worker.collected_mission_data_files = {"l10n/DEFAULT/veafDynamicConfig.lua": b"x"}
        specs = worker._build_veaf_trigger_specs({}, {})
        self.assertEqual([s for s in specs if any(isinstance(a, SoundAction) for a in s.actions)], [])


if __name__ == "__main__":
    unittest.main()
