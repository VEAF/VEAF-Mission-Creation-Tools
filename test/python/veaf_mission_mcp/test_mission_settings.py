"""`set_mission_date`, `set_bullseye`, `set_briefing` — FIX-SCRATCH-MISSION-FINDINGS ticket 07.

On GermanyCW-v6 the agent patched `src/mission/mission` through a Lua serializer for all three: the
blank mission is dated 2016 when a Cold War mission wants 1980, `describe_map` read the bullseyes and
nothing wrote them, and the briefing texts had no action at all — in an editor-saved mission they
live in the l10n dictionary, not in the mission table (FEAT-BRIEFING-METAR found that out).
"""

from pathlib import Path

import pytest
from mission_tools.miz_tools import read_mission_folder
from veaf_mission_mcp.mission_settings import set_briefing, set_bullseye, set_mission_date

_MISSION = """\
mission =
{
  ["date"] = {["Day"] = 1, ["Month"] = 6, ["Year"] = 2016},
  ["start_time"] = 28800,
  ["sortie"] = "DictKey_sortie_1",
  ["descriptionText"] = "old situation",
  ["coalition"] =
  {
    ["blue"] = {["bullseye"] = {["x"] = 0, ["y"] = 0}, ["country"] = {}},
    ["red"] = {["bullseye"] = {["x"] = 0, ["y"] = 0}, ["country"] = {}},
  },
}
"""

_DICTIONARY = """\
dictionary =
{
  ["DictKey_sortie_1"] = "Old sortie",
}
"""


def _folder(tmp_path: Path) -> Path:
    exploded = tmp_path / "src" / "mission"
    (exploded / "l10n" / "DEFAULT").mkdir(parents=True)
    (exploded / "mission").write_text(_MISSION, encoding="utf-8")
    (exploded / "l10n" / "DEFAULT" / "dictionary").write_text(_DICTIONARY, encoding="utf-8")
    (tmp_path / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    return tmp_path


class TestSetMissionDate:
    def test_the_date_and_start_time_are_written(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        result = set_mission_date(folder, date="1980-06-01", start_time="09:30")
        content = read_mission_folder(folder).mission_content or {}
        assert content["date"] == {"Day": 1, "Month": 6, "Year": 1980}
        assert content["start_time"] == 9 * 3600 + 30 * 60
        assert result["start_time"] == "09:30:00"

    def test_either_can_be_given_alone(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_mission_date(folder, date="1980-06-01")
        content = read_mission_folder(folder).mission_content or {}
        assert content["start_time"] == 28800

    def test_a_bad_date_is_refused(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="date"):
            set_mission_date(_folder(tmp_path), date="1980-02-30")

    def test_a_bad_time_is_refused(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="start_time"):
            set_mission_date(_folder(tmp_path), start_time="25:00")

    def test_nothing_to_set_is_refused(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError):
            set_mission_date(_folder(tmp_path))


class TestSetBullseye:
    def test_one_coalition_is_written(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_bullseye(folder, coalition="blue", position={"x": -384298.0, "y": -745152.0})
        content = read_mission_folder(folder).mission_content or {}
        assert content["coalition"]["blue"]["bullseye"] == {"x": -384298.0, "y": -745152.0}
        assert content["coalition"]["red"]["bullseye"] == {"x": 0, "y": 0}

    def test_an_unknown_coalition_is_refused(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="coalition"):
            set_bullseye(_folder(tmp_path), coalition="green", position={"x": 0.0, "y": 0.0})


class TestSetBriefing:
    def test_a_text_held_in_the_dictionary_is_written_there(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_briefing(folder, sortie="Cold War Open Training")
        mission = read_mission_folder(folder)
        assert (mission.mission_content or {})["sortie"] == "DictKey_sortie_1", "the key stays a key"
        assert (mission.dictionary_content or {})["DictKey_sortie_1"] == "Cold War Open Training"

    def test_a_text_held_in_the_mission_table_is_written_there(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_briefing(folder, situation="Central Europe, June 1980.")
        content = read_mission_folder(folder).mission_content or {}
        assert content["descriptionText"] == "Central Europe, June 1980."

    def test_the_coalition_tasks_are_written(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_briefing(folder, blue_task="Hold the Fulda Gap.", red_task="Break through.", neutrals_task="Watch.")
        content = read_mission_folder(folder).mission_content or {}
        assert content["descriptionBlueTask"] == "Hold the Fulda Gap."
        assert content["descriptionRedTask"] == "Break through."
        assert content["descriptionNeutralsTask"] == "Watch."

    def test_a_field_left_out_is_untouched(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path)
        set_briefing(folder, blue_task="Hold.")
        content = read_mission_folder(folder).mission_content or {}
        assert content["descriptionText"] == "old situation"

    def test_nothing_to_set_is_refused(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError):
            set_briefing(_folder(tmp_path))


def test_another_action_leaves_the_dictionary_file_alone(tmp_path: Path) -> None:
    """The dictionary is written back only when its content changes — not re-formatted by every action.

    Caught before review: writing it whenever the serialised text differed rewrote an editor-saved
    dictionary on the first folder action of any kind, a whole-file diff for nothing.
    """
    folder = _folder(tmp_path)
    dictionary = folder / "src" / "mission" / "l10n" / "DEFAULT" / "dictionary"
    before = dictionary.read_bytes()
    set_bullseye(folder, coalition="blue", position={"x": 1.0, "y": 2.0})
    assert dictionary.read_bytes() == before
