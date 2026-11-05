"""Tests for the DCS static-weather wind model (FEAT-MISSION-WIND-CHECK tickets 01 and 02).

The five in-game runs of the whitepaper are read where they live, under
``docs/whitepapers/dcs-wind-model/data/``: one copy of the measurement, owned by the whitepaper.
"""

from __future__ import annotations

import ast
import json
import math
import sys
from pathlib import Path
from typing import Any

import pytest
from veaf_libs import dcs_wind
from veaf_libs.dcs_wind import (
    KNOTS_PER_MPS,
    WindVector,
    base_wind,
    cap_setting_for_band,
    ground_setting_for_surface_wind,
    max_wind_between,
    setting_for_surface_wind,
    surface_wind,
    turbulence_for_gust,
    wind_profile,
)

_REPO = Path(__file__).resolve().parents[3]
_RUNS = sorted((_REPO / "docs" / "whitepapers" / "dcs-wind-model" / "data").glob("*.json"))
_MODULE = Path(dcs_wind.__file__)
_VECTORS = json.loads((_MODULE.parent / "dcs_wind_vectors.json").read_text(encoding="utf-8"))

#: The *Marteau du Golan* reference airfield: Rosh Pina, as `airfields_for_theatre` gives it.
_ROSH_PINA_M = 264.61
_FT = 0.3048


def _layer(speed: float, to_deg: float) -> dict[str, float]:
    return {"speed": speed, "dir": to_deg}


def _setting(ground: float, at2000: float, at8000: float, to_deg: float = 90.0) -> dict[str, Any]:
    return {"atGround": _layer(ground, to_deg), "at2000": _layer(at2000, to_deg), "at8000": _layer(at8000, to_deg)}


# --- a. the base wind, replayed on the five measured runs ---------------------------------------


def test_the_five_runs_are_there() -> None:
    assert len(_RUNS) == 5


@pytest.mark.parametrize("run", _RUNS, ids=lambda path: path.stem)
def test_base_wind_replays_every_measured_point(run: Path) -> None:
    data = json.loads(run.read_text(encoding="utf-8"))
    setting = data["weather"]
    worst = 0.0
    for point in data["P"]:
        wind = base_wind(setting, point["y"], point["y"] - point["ground"])
        measured_x, _, measured_z = point["v"]
        worst = max(worst, abs(wind.x - measured_x), abs(wind.z - measured_z))
    assert worst <= 0.001, f"{run.stem}: worst gap {worst:.5f} m/s"


def test_a_vector_blowing_east_comes_from_270() -> None:
    wind = WindVector(0.0, 10.0)
    assert wind.from_deg == pytest.approx(270.0)
    assert wind.speed == pytest.approx(10.0)
    assert wind.knots == pytest.approx(10.0 * KNOTS_PER_MPS)


def test_below_the_ground_there_is_no_wind() -> None:
    assert base_wind(_setting(10, 10, 10), 100.0, -1.0).speed == 0.0


def test_above_8000_m_the_top_level_blows_as_set() -> None:
    assert base_wind(_setting(5, 8, 14), 9000.0, 8000.0).speed == pytest.approx(14.0)


def test_at_sea_level_the_setting_is_scaled_by_45_to_the_fifth() -> None:
    # 500 m above a sea-level point, the ground factor is 1: the 0 m level as it is.
    assert base_wind(_setting(5, 8, 14), 0.0, 500.0).speed == pytest.approx(5 * 45**0.2)


# --- b. the profile above a place -----------------------------------------------------------------


@pytest.mark.parametrize(
    ("at2000", "expected_knots"),
    [(7.0, (13, 20, 19, 16)), (11.0, (13, 20, 21, 21))],
)
def test_the_rosh_pina_figures_of_the_prd(at2000: float, expected_knots: tuple[int, ...]) -> None:
    setting = _setting(5.0, at2000, at2000 + 3.0)
    heights = [10.0, 1000 * _FT, 2000 * _FT, 3000 * _FT]
    profile = wind_profile(setting, 262.0, heights)
    assert tuple(round(layer.wind.knots) for layer in profile) == expected_knots
    assert [layer.height_agl for layer in profile] == heights
    assert profile[0].altitude_msl == pytest.approx(272.0)


def test_surface_wind_is_the_wind_10_m_above_the_ground() -> None:
    setting = _setting(9, 11, 14, to_deg=90)
    assert surface_wind(setting, _ROSH_PINA_M) == base_wind(setting, _ROSH_PINA_M + 10, 10)


def test_marteau_du_golan_flew_24_kt_at_the_surface_and_36_at_1000_ft() -> None:
    # The original setting: 9 / 11 / 14 m/s from 270, measured in game on 2026-10-31.
    setting = _setting(9, 11, 14, to_deg=90)
    assert surface_wind(setting, _ROSH_PINA_M).knots == pytest.approx(24, abs=1)
    assert wind_profile(setting, _ROSH_PINA_M, [1000 * _FT])[0].wind.knots == pytest.approx(36, abs=1)


def test_max_wind_between_finds_the_low_layer_peak() -> None:
    setting = _setting(5.0, 7.0, 10.0)
    peak = max_wind_between(setting, 262.0, 0.0, 600.0)
    assert 300.0 <= peak.height_agl <= 600.0
    assert peak.wind.knots > surface_wind(setting, 262.0).knots + 5


def test_max_wind_between_refuses_an_empty_band() -> None:
    with pytest.raises(ValueError):
        max_wind_between(_setting(5, 7, 10), 0.0, 600.0, 10.0)


# --- c/d. the two inversions ------------------------------------------------------------------------


@pytest.mark.parametrize("ground", [0.0, 262.0, 1000.0])
@pytest.mark.parametrize("knots", [5.0, 15.0, 30.0])
@pytest.mark.parametrize("veer", [0.0, 20.0, 30.0])
def test_setting_for_surface_wind_round_trips(ground: float, knots: float, veer: float) -> None:
    result = setting_for_surface_wind(250.0, knots, ground, veer_deg=veer)
    back = surface_wind(result.setting, ground)
    assert back.knots == pytest.approx(knots, abs=0.1)
    assert back.from_deg == pytest.approx(250.0, abs=0.5)
    assert result.setting["at2000"]["speed"] == pytest.approx(2.2 * result.setting["atGround"]["speed"])
    # Veered to the right: the direction aloft is the surface's plus the veer.
    turn = (result.setting["at2000"]["dir"] - result.setting["atGround"]["dir"]) % 360
    assert turn == pytest.approx(veer, abs=1e-6)
    assert result.setting["at8000"]["speed"] == pytest.approx(result.setting["at2000"]["speed"] + 3.0)


def test_default_setting_grows_with_height_above_rosh_pina() -> None:
    setting = setting_for_surface_wind(270.0, 10.0, 262.0).setting
    heights = [10.0 + 50.0 * i for i in range(20)]
    speeds = [layer.wind.speed for layer in wind_profile(setting, 262.0, heights)]
    assert all(upper >= lower - 0.01 for lower, upper in zip(speeds, speeds[1:], strict=False))


def test_setting_for_surface_wind_refuses_a_veer_outside_0_30() -> None:
    with pytest.raises(ValueError, match="veer"):
        setting_for_surface_wind(270.0, 10.0, 0.0, veer_deg=45.0)


def test_setting_for_surface_wind_refuses_a_ratio_that_makes_a_jet() -> None:
    with pytest.raises(ValueError, match="jet"):
        setting_for_surface_wind(270.0, 10.0, 0.0, at2000_ratio=1.5)


def test_no_inversion_at_or_above_2000_m() -> None:
    with pytest.raises(ValueError, match="2000"):
        setting_for_surface_wind(270.0, 10.0, 2000.0)
    with pytest.raises(ValueError, match="2000"):
        ground_setting_for_surface_wind(270.0, 10.0, 2100.0, _layer(5.0, 90.0))


@pytest.mark.parametrize("ground", [0.0, 262.0, 1000.0])
def test_ground_setting_for_surface_wind_round_trips(ground: float) -> None:
    result = ground_setting_for_surface_wind(320.0, 11.0, ground, _layer(2.65, 227.0))
    assert surface_wind(result.setting, ground).knots == pytest.approx(11.0, abs=0.1)
    assert result.setting["at2000"] == _layer(2.65, 227.0)
    assert result.reliable


def test_a_high_reference_point_is_flagged_unreliable() -> None:
    result = ground_setting_for_surface_wind(270.0, 10.0, 1500.0, _layer(5.0, 90.0))
    assert result.ground_weight < 0.5
    assert not result.reliable


def test_a_zero_wind_wanted_gives_a_zero_ground_setting() -> None:
    result = setting_for_surface_wind(270.0, 0.0, 262.0)
    assert result.setting["atGround"]["speed"] == pytest.approx(0.0)


# --- d2. the cap on a band -----------------------------------------------------------------------


@pytest.mark.parametrize("ground", [0.0, 231.0, 468.0])
def test_cap_setting_for_band_holds_the_band_under_the_cap(ground: float) -> None:
    setting = setting_for_surface_wind(270.0, 25.0, ground).setting
    capped = cap_setting_for_band(setting, ground, 20.0, 1500 * _FT)
    peak = max_wind_between(capped.setting, ground, 10.0, 1500 * _FT)
    assert peak.wind.knots <= 20.0 + 0.05
    assert peak.wind.knots >= 19.5
    assert capped.reduced
    assert not capped.at2000_reduced


def test_cap_setting_for_band_leaves_a_calm_setting_alone() -> None:
    setting = setting_for_surface_wind(270.0, 5.0, 0.0).setting
    capped = cap_setting_for_band(setting, 0.0, 20.0, 1500 * _FT)
    assert not capped.reduced
    assert capped.setting == setting


def test_cap_setting_for_band_reduces_at2000_on_high_terrain() -> None:
    setting = _setting(2.0, 20.0, 23.0)
    capped = cap_setting_for_band(setting, 1600.0, 20.0, 1500 * _FT)
    assert capped.at2000_reduced
    assert capped.setting["atGround"]["speed"] == pytest.approx(0.0)
    assert max_wind_between(capped.setting, 1600.0, 10.0, 1500 * _FT).wind.knots <= 20.05


# --- 02. gusts ---------------------------------------------------------------------------------------


def test_turbulence_for_gust_follows_the_measured_mapping_and_its_cap() -> None:
    assert turbulence_for_gust(24, 37) == pytest.approx(dcs_wind.GUST_TURBULENCE_CAP_MPS)
    assert turbulence_for_gust(15, 16) == pytest.approx(1 * 0.514444 / 0.62, abs=1e-3)
    assert turbulence_for_gust(15, None) == 0.0
    assert turbulence_for_gust(15, 12) == 0.0


# --- g. the shared vectors ------------------------------------------------------------------------


@pytest.mark.parametrize("case", _VECTORS["surface_inversions"], ids=lambda case: case["name"])
def test_shared_surface_inversion_vectors(case: dict[str, Any]) -> None:
    wanted = case["wanted"]
    if "at2000" in case:
        call = lambda: ground_setting_for_surface_wind(  # noqa: E731
            wanted["from_deg"], wanted["knots"], case["ground_msl"], case["at2000"]
        )
    else:
        call = lambda: setting_for_surface_wind(wanted["from_deg"], wanted["knots"], case["ground_msl"])  # noqa: E731
    expected = case["expected"]
    if "error" in expected:
        with pytest.raises(ValueError):
            call()
        return
    result = call()
    assert result.setting["atGround"]["speed"] == pytest.approx(expected["atGround"]["speed"], abs=0.01)
    assert result.setting["atGround"]["dir"] == pytest.approx(expected["atGround"]["dir"], abs=0.5)
    assert result.ground_weight == pytest.approx(expected["ground_weight"], abs=0.001)
    assert result.reliable is expected["reliable"]
    back = surface_wind(result.setting, case["ground_msl"])
    assert back.knots == pytest.approx(expected["surface"]["knots"], abs=0.05)
    assert back.from_deg == pytest.approx(expected["surface"]["from_deg"], abs=0.5)


@pytest.mark.parametrize("case", _VECTORS["band_caps"], ids=lambda case: case["name"])
def test_shared_band_cap_vectors(case: dict[str, Any]) -> None:
    capped = cap_setting_for_band(case["setting"], case["ground_msl"], case["max_knots"], case["top_agl"])
    expected = case["expected"]
    assert capped.setting["atGround"]["speed"] == pytest.approx(expected["atGround_speed"], abs=0.01)
    assert capped.setting["at2000"]["speed"] == pytest.approx(expected["at2000_speed"], abs=0.01)
    assert capped.at2000_reduced is expected["at2000_reduced"]


@pytest.mark.parametrize("case", _VECTORS["gusts"], ids=lambda case: case["name"])
def test_shared_gust_vectors(case: dict[str, Any]) -> None:
    assert turbulence_for_gust(case["mean_knots"], case["gust_knots"]) == pytest.approx(case["expected_mps"], abs=0.01)


# --- the contract with the DCSServerBot fork -----------------------------------------------------


def test_the_module_imports_only_the_standard_library() -> None:
    tree = ast.parse(_MODULE.read_text(encoding="utf-8"))
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module and node.level == 0:
            imported.add(node.module.split(".")[0])
    assert imported, "the module imports nothing?"
    assert imported <= set(sys.stdlib_module_names), imported - set(sys.stdlib_module_names)


def test_the_model_names_its_dcs_version() -> None:
    assert dcs_wind.MODEL_DCS_VERSION == "2.9.31.29434"


def test_one_knot_is_1852_m_per_hour() -> None:
    assert KNOTS_PER_MPS == pytest.approx(3600 / 1852, rel=1e-6)
    assert math.isclose(1 / KNOTS_PER_MPS, 0.514444, rel_tol=1e-5)
