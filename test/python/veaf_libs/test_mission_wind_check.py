"""`mission-check`'s wind check, without DCS (FEAT-MISSION-WIND-CHECK ticket 05).

*Marteau du Golan* (2026-10-31): the briefing announced "17 kt au sol, plus fort en altitude"; with its
setting (9 / 11 / 14 m/s from 270), DCS flew 24 kt at 10 m above Rosh Pina and 36 kt at 1,000 ft.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import read_miz, write_miz
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_libs.dcs_mission_check import Report, format_line, verdict
from veaf_libs.dcs_wind import base_wind
from veaf_libs.mission_wind import HelicopterPlace
from veaf_libs.mission_wind_check import (
    MEASURE_HEIGHTS_M,
    WindPlace,
    check_built_mission,
    check_wind,
    combat_zone_names,
    extract_wind_mentions,
    judge_measure,
    measure_lua,
    parse_measure,
    wind_places,
    write_measure,
)

_MARTEAU = {"atGround": {"speed": 9, "dir": 90}, "at2000": {"speed": 11, "dir": 90}, "at8000": {"speed": 14, "dir": 90}}
_ROSH_PINA = WindPlace("Rosh Pina (departure)", 0.0, 0.0, 264.6, departure=True)
_ORIGINAL = "Météo : CAVOK, vent du 270 pour 17 kt au sol, plus fort en altitude."
_REWRITTEN = "Météo : CAVOK. Vent du 270 pour 24 kt au sol, 36 kt à 1 000 ft : forte couche de vent pour les hélicos."
_BUILT = Path(__file__).resolve().parents[2] / "veaf-tools" / "demo-mission" / "veaf-demo-mission.miz"


# --- the mentions -------------------------------------------------------------------------------------


def test_the_original_marteau_sentence_reads_a_surface_figure_and_a_layer_without_one() -> None:
    surface, aloft = extract_wind_mentions(_ORIGINAL, "descriptionText")
    assert (surface.layer, surface.knots, surface.from_deg) == ("surface", 17.0, 270.0)
    assert (aloft.layer, aloft.knots) == ("aloft", None)


@pytest.mark.parametrize(
    ("text", "layer", "knots", "from_deg"),
    [
        ("Wind 270/17 at the surface.", "surface", 17.0, 270.0),
        ("Surface wind 270° 17 kt.", "surface", 17.0, 270.0),
        ("Wind: 17 kt from the west.", "surface", 17.0, 270.0),
        ("Vent du nord-ouest, 12 nœuds au sol.", "surface", 12.0, 315.0),
        ("Wind 36 kt at 1,000 ft.", pytest.approx(304.8), 36.0, None),
        ("Low level wind 30 kt from 270.", "low level", 30.0, 270.0),
    ],
)
def test_wind_mentions_in_both_languages(text: str, layer: Any, knots: float, from_deg: float | None) -> None:
    (mention,) = extract_wind_mentions(text, "t")
    assert (mention.layer, mention.knots, mention.from_deg) == (layer, knots, from_deg)


def test_a_sentence_without_wind_is_left_alone() -> None:
    assert extract_wind_mentions("Take off at 0800, 17 kt climb.", "t") == []


# --- the judgement ------------------------------------------------------------------------------------


def test_the_original_marteau_briefing_fails() -> None:
    report = check_wind(_MARTEAU, [_ROSH_PINA], {"descriptionText": _ORIGINAL})
    failed = [text for ok, text in report.lines if ok is False]
    assert len(failed) == 1 and "contradicts the simulated wind at surface: 24-24 kt" in failed[0]


def test_the_rewritten_marteau_briefing_passes() -> None:
    report = check_wind(_MARTEAU, [_ROSH_PINA], {"descriptionText": _REWRITTEN})
    assert [ok for ok, _ in report.lines if ok is not None] == [True, True]


def test_a_wrong_direction_fails() -> None:
    report = check_wind(_MARTEAU, [_ROSH_PINA], {"t": "Wind 090/24 at the surface."})
    assert [ok for ok, _ in report.lines if ok is not None] == [False]


def test_the_helicopter_rule_warns_when_announced_and_fails_when_not() -> None:
    helicopters = [HelicopterPlace("Rosh Pina", 264.6)]
    announced = check_wind(_MARTEAU, [_ROSH_PINA], {"t": _REWRITTEN}, helicopters)
    assert [ok for ok, _ in announced.lines if ok in ("warn", False)] == ["warn"]
    silent = check_wind(_MARTEAU, [_ROSH_PINA], {"t": "Météo : CAVOK."}, helicopters)
    assert [ok for ok, _ in silent.lines if ok in ("warn", False)] == ["warn", False]


def test_no_place_is_said() -> None:
    (line,) = check_wind(_MARTEAU, [], {"t": _ORIGINAL}).lines
    assert line[0] is None


# --- the places ---------------------------------------------------------------------------------------


def _content() -> dict[str, Any]:
    group = {
        "name": "Hind-1",
        "units": {1: {"skill": "Client", "type": "Mi-24P"}},
        "route": {
            "points": {
                1: {"airdromeId": airdrome_id_for_name("Syria", "Rosh Pina"), "x": 0, "y": 0},
                2: {"x": -260000.0, "y": -40000.0},
            }
        },
    }
    return {
        "descriptionText": _ORIGINAL,
        "weather": {"wind": _MARTEAU},
        "triggers": {"zones": {1: {"name": "Kiswah", "x": -300000.0, "y": 10000.0}}},
        "coalition": {
            "blue": {"country": {1: {"name": "CJTF Blue", "helicopter": {"group": {1: group}}}}},
            "red": {"country": {}},
        },
    }


def test_combat_zones_are_read_from_veaf_config() -> None:
    config = 'veafCombatZone.AddZone(VeafCombatZone:new():setMissionEditorZoneName("Kiswah"):setFriendlyName("K"))'
    assert combat_zone_names(config + config) == ["Kiswah"]


def test_the_places_are_departures_zones_and_helicopter_points() -> None:
    config = ':setMissionEditorZoneName("Kiswah")'
    places, unknown = wind_places(_content(), "Syria", veaf_config=config, ground_at=lambda x, y: 700.0)
    assert [p.name for p in places] == ["Rosh Pina (departure)", "Kiswah (objective)", "Hind-1 waypoint 1"]
    assert places[0].ground_msl == pytest.approx(264.6)
    assert unknown == []
    places, unknown = wind_places(_content(), "Syria", veaf_config=config)
    assert [p.name for p in places] == ["Rosh Pina (departure)"]
    assert unknown == ["Kiswah (objective)", "Hind-1 waypoint 1"]


def test_a_built_mission_is_checked_with_its_folder(tmp_path: Path) -> None:
    miz = tmp_path / "marteau.miz"
    shutil.copy2(_BUILT, miz)
    mission = read_miz(miz)
    mission.mission_content = _content()
    mission.theatre_content = "Syria"
    mission.warehouses_content = {"airports": {}}  # the demo's dynamic slots are Caucasus airfields
    write_miz(mission, miz)
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "briefing-contenu.md").write_text("# Météo\n\n" + _REWRITTEN + "\n", encoding="utf-8")
    report = check_built_mission(miz, tmp_path)
    oks = [ok for ok, _ in report.lines]
    assert oks.count(False) == 1  # the .miz still carries the original sentence
    assert oks.count(True) == 2  # the approved content is right
    assert "warn" in oks
    assert any("kneeboard" in text for _, text in report.lines)


# --- the report level ---------------------------------------------------------------------------------


def test_a_warning_shows_in_the_verdict_without_failing() -> None:
    report = Report()
    report.add(True, "wind", "fine")
    line = report.add(None, "wind", "helicopters at X", warning=True)
    assert report.passed and report.warnings == [line] and line.ok is None
    assert "1 warning(s)" in verdict(report) and "PASS" in verdict(report)
    assert "[yellow]![/]" in format_line(line)


# --- the measurement ----------------------------------------------------------------------------------


def test_the_measure_chunk_asks_every_place_and_height() -> None:
    lua = measure_lua([_ROSH_PINA])
    assert "atmosphere.getWind" in lua and "land.getHeight" in lua and "_APP_VERSION" in lua
    assert all(f"{h:.1f}" in lua for h in MEASURE_HEIGHTS_M)


def test_a_vector_blowing_east_reads_from_270_and_matches_the_model(tmp_path: Path) -> None:
    model = base_wind(_MARTEAU, 274.6, 10.0)
    reply = f"2.9.31.29434\n1\t10.00\t264.60\t{model.x:.5f}\t{model.z:.5f}"
    version, readings = parse_measure(reply, [_ROSH_PINA], _MARTEAU)
    assert version == "2.9.31.29434"
    assert readings[0].measured.from_deg == pytest.approx(270.0)
    ((ok, text),) = judge_measure(version, readings)
    assert ok is True, text
    target = tmp_path / "m_CHECK.wind.json"
    write_measure(target, version, readings)
    assert json.loads(target.read_text(encoding="utf-8"))["readings"][0]["gap_knots"] == 0.0


def test_a_gap_over_half_a_knot_fails_with_both_versions() -> None:
    model = base_wind(_MARTEAU, 274.6, 10.0)
    reply = f"2.9.40.1\n1\t10.00\t264.60\t{model.x:.5f}\t{model.z + 1.0:.5f}"
    ((ok, text),) = judge_measure(*parse_measure(reply, [_ROSH_PINA], _MARTEAU))
    assert ok is False and "2.9.40.1" in text and "2.9.31.29434" in text


def test_an_empty_or_broken_reply() -> None:
    assert judge_measure("?", [])[0][0] is False
    with pytest.raises(ValueError):
        parse_measure("v\nnot a line", [_ROSH_PINA], _MARTEAU)
