"""A campaign sizes its missions' air opposition to the squadron (FEAT-OPPOSITION-SCALES-WITH-PLAYERS).

`campaign.yaml` may say how many players the squadron expects (`players: 5-7`), and `campaign next
--players 6` says it for tonight. The mission's `opposition:` block is then sized for the most expected
and follows the players connected, down to who actually came.
"""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

import pytest
import yaml
from campaign_fixture import VALID
from campaign_fixture import mission_template as _template
from campaign_manager.campaign_manager import initial_state, parse_campaign, parse_players
from campaign_manager.campaign_worker import CAMPAIGN_FILE, CampaignWorker
from campaign_manager.next_mission import opposition_for, prepare_next_mission
from typer.testing import CliRunner
from veaf_libs.lua_config_generator import emit_opposition_block


def _campaign(**head: Any) -> Any:
    raw = copy.deepcopy(VALID)
    raw["campaign"].update(head)
    campaign, issues = parse_campaign(raw)
    return campaign, issues


@pytest.mark.parametrize(("raw", "expected"), [(6, (6, 6)), ("6", (6, 6)), ("5-7", (5, 7)), (" 5 - 7 ", (5, 7))])
def test_the_players_expected(raw: object, expected: tuple[int, int]) -> None:
    assert parse_players(raw) == expected


@pytest.mark.parametrize("raw", [0, -2, "7-5", "lots", "5-", True, 2.5])
def test_a_wrong_count_is_refused(raw: object) -> None:
    with pytest.raises(ValueError):
        parse_players(raw)


def test_campaign_yaml_carries_the_squadron_size() -> None:
    campaign, issues = _campaign(players="5-7")
    assert issues == []
    assert campaign.players == (5, 7)


def test_campaign_yaml_says_nothing_by_default() -> None:
    campaign, _ = _campaign()
    assert campaign.players is None


def test_a_wrong_squadron_size_is_an_error() -> None:
    campaign, issues = _campaign(players="many")
    assert campaign is None
    assert any("players" in issue.message for issue in issues)


def test_the_opposition_is_sized_for_the_most_expected_and_follows_the_players() -> None:
    assert opposition_for((5, 7), "blue") == {"level": 7, "follow": "air_to_air", "players_coalition": "BLUE"}


def test_the_block_written_is_one_the_build_reads() -> None:
    emit_opposition_block(opposition_for((5, 7), "red"))


def test_next_writes_the_opposition_block(tmp_path: Path) -> None:
    _template(tmp_path)
    campaign, _ = _campaign(players="5-7")
    prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
    mission_yaml = yaml.safe_load((tmp_path / "m1" / "mission.yaml").read_text(encoding="utf-8"))
    assert mission_yaml["opposition"] == {"level": 7, "follow": "air_to_air", "players_coalition": "BLUE"}


def test_tonights_count_beats_the_campaigns(tmp_path: Path) -> None:
    _template(tmp_path)
    campaign, _ = _campaign(players="5-7")
    prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1", players=(3, 3))
    mission_yaml = yaml.safe_load((tmp_path / "m1" / "mission.yaml").read_text(encoding="utf-8"))
    assert mission_yaml["opposition"]["level"] == 3


def test_a_refresh_keeps_what_was_designed_in_the_block(tmp_path: Path) -> None:
    _template(tmp_path)
    campaign, _ = _campaign(players="5-7")
    prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
    path = tmp_path / "m1" / "mission.yaml"
    mission_yaml = yaml.safe_load(path.read_text(encoding="utf-8"))
    mission_yaml["opposition"].update({"follow": "airborne", "lower_after": 600})
    path.write_text(yaml.safe_dump(mission_yaml), encoding="utf-8")
    prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1", players=(4, 4))
    block = yaml.safe_load(path.read_text(encoding="utf-8"))["opposition"]
    assert block == {"level": 4, "follow": "airborne", "lower_after": 600, "players_coalition": "BLUE"}


def test_no_count_leaves_mission_yaml_alone(tmp_path: Path) -> None:
    _template(tmp_path)
    campaign, _ = _campaign()
    prepare_next_mission(campaign, initial_state(campaign), tmp_path, tmp_path / "m1")
    mission_yaml = yaml.safe_load((tmp_path / "m1" / "mission.yaml").read_text(encoding="utf-8"))
    assert "opposition" not in mission_yaml


def test_the_command_takes_players(tmp_path: Path) -> None:
    import veaf_tools.commands  # noqa: F401
    from veaf_tools.app import app

    (tmp_path / CAMPAIGN_FILE).write_text(yaml.safe_dump(copy.deepcopy(VALID)), encoding="utf-8")
    _template(tmp_path)
    CampaignWorker(tmp_path).init()
    result = CliRunner().invoke(app, ["campaign-next", str(tmp_path), "--players", "6"])
    assert result.exit_code == 0, result.output
    folder = tmp_path / "missions" / "mission-01" / "mission"
    assert yaml.safe_load((folder / "mission.yaml").read_text(encoding="utf-8"))["opposition"]["level"] == 6


def test_the_command_refuses_a_wrong_count(tmp_path: Path) -> None:
    import veaf_tools.commands  # noqa: F401
    from veaf_tools.app import app

    result = CliRunner().invoke(app, ["campaign-next", str(tmp_path), "--players", "lots"])
    assert result.exit_code != 0


# ---------------------------------------------------------------------------
# The mission briefing says the scaled threat as intelligence, never as a figure
# ---------------------------------------------------------------------------

_SCALED_QRA = (
    "modules:\n  CSAR: true\n  QRA:\n    enabled: true\n    definitions:\n"
    "      - name: QRA Senaki\n        coalition: RED\n        trigger_zone: QRA Senaki\n"
    "        groups_by_enemy_count:\n"
    "          - {enemy_count: 1, groups: [MiG-29A]}\n"
    "          - {enemy_count: 5, groups: [MiG-29A, Su-27]}\n"
)


_FOLLOWING_QRA = (
    "modules:\n  QRA:\n    enabled: true\n    definitions:\n"
    "      - {name: QRA Senaki, coalition: RED, trigger_zone: QRA Senaki, simple_groups: [g],"
    " scale_with_opposition: true}\n"
)


def _qra_text(tmp_path: Path, mission_yaml: str | None) -> str:
    from campaign_fixture import built_mission
    from campaign_manager.mission_deck import _qra_line
    from campaign_manager.mission_picture import read_mission_picture
    from veaf_libs.i18n import language

    miz = built_mission(tmp_path / "mission")
    if mission_yaml is not None:
        (tmp_path / "mission" / "mission.yaml").write_text(mission_yaml, encoding="utf-8")
    picture = read_mission_picture(miz, "blue", tmp_path / "mission")
    campaign, _ = _campaign()
    with language("fr"):
        text = _qra_line(campaign, picture)
    assert text is not None
    return text


def test_a_qra_with_tiers_reinforces_its_alert_without_a_figure(tmp_path: Path) -> None:
    text = _qra_text(tmp_path, _SCALED_QRA)
    assert "renforce son alerte face à un dispositif important" in text
    assert not any(character.isdigit() for character in text)


def test_a_qra_following_the_level_reinforces_its_alert(tmp_path: Path) -> None:
    text = _qra_text(tmp_path, "opposition: {level: 6, follow: players}\n" + _FOLLOWING_QRA)
    assert "renforce son alerte" in text


def test_following_a_level_the_mission_does_not_set_scales_nothing(tmp_path: Path) -> None:
    assert "renforce" not in _qra_text(tmp_path, _FOLLOWING_QRA)


def test_a_fixed_qra_says_nothing_of_it(tmp_path: Path) -> None:
    assert "renforce" not in _qra_text(tmp_path, None)
