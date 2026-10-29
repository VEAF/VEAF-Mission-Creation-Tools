"""Magnetic declination and bearings (FIX-BRIEFING-MAGNETIC-HEADINGS).

The briefing printed its headings on the DCS grid, which is neither true nor magnetic. The tests measure
the two angles that separate the grid from the cockpit independently: the declination against NOAA's
published test values, the true bearing against GeographicLib's geodesic, not the module's own formula.
"""

from __future__ import annotations

import math
from datetime import date

import pytest
from geographiclib.geodesic import Geodesic  # type: ignore[import-untyped]
from veaf_libs import magnetic
from veaf_libs.coordinates import latlon_to_xy, offset_latlon, xy_to_latlon
from veaf_libs.magnetic import (
    declination,
    grid_heading_to_magnetic,
    grid_heading_to_true,
    ground_distance,
    ground_distance_m,
    magnetic_bearing,
    true_bearing,
)

#: The WMM2020 report's test values: year, height (km), latitude, longitude, declination (degrees).
WMM2020_TEST_VALUES = [
    (2020.0, 0, 80, 0, -1.28),
    (2020.0, 0, 0, 120, 0.16),
    (2020.0, 0, -80, 240, 69.36),
    (2020.0, 100, 80, 0, -1.70),
    (2020.0, 100, 0, 120, 0.16),
    (2020.0, 100, -80, 240, 68.78),
    (2022.5, 0, 80, 0, 0.01),
    (2022.5, 0, 0, 120, -0.06),
    (2022.5, 0, -80, 240, 69.13),
    (2022.5, 100, 80, 0, -0.41),
    (2022.5, 100, 0, 120, -0.05),
    (2022.5, 100, -80, 240, 68.55),
]


@pytest.mark.parametrize(("year", "height", "lat", "lon", "expected"), WMM2020_TEST_VALUES)
def test_the_declination_matches_the_wmm_test_values(
    year: float, height: float, lat: float, lon: float, expected: float
) -> None:
    assert declination(lat, lon, year, height) == pytest.approx(expected, abs=0.006)


def test_a_date_counts_by_its_month_as_dcs_does() -> None:
    assert declination(33.1, 35.8, date(2024, 6, 28)) == declination(33.1, 35.8, 2024 + 5 / 12)


@pytest.mark.parametrize(
    ("when", "epoch"),
    [
        (date(1970, 1, 1), 1985),
        (date(1989, 12, 1), 1985),
        (date(1990, 1, 1), 1990),
        (date(2024, 6, 1), 2020),
        (2031.0, 2025),
    ],
)
def test_each_date_takes_the_last_epoch_before_it(
    when: float | date, epoch: int, monkeypatch: pytest.MonkeyPatch
) -> None:
    read: list[int] = []
    original = magnetic._coefficients
    monkeypatch.setattr(magnetic, "_coefficients", lambda e: read.append(e) or original(e))
    declination(33.1, 35.8, when)
    assert read == [epoch]


def test_every_vendored_epoch_reads_whole() -> None:
    for epoch in magnetic._EPOCHS:
        coefficients = magnetic._coefficients(epoch)
        assert len(coefficients) == sum(n + 1 for n in range(1, 13)), epoch  # degree 12, m from 0 to n


def _off_by(a: float, b: float) -> float:
    return abs((a - b + 180) % 360 - 180)


@pytest.mark.parametrize(
    ("theatre", "when", "start", "end"),
    [
        # The Golan, Syria (projection lon_0 = 39): the grid is 1.7 degrees off true, the declination 5.2 east.
        ("Syria", date(2024, 6, 1), (33.05, 35.55), (33.20, 36.05)),
        ("Syria", date(2024, 6, 1), (33.20, 36.05), (33.40, 35.80)),
        # Kobuleti to Gudauta, Caucasus (lon_0 = 33): the grid is 6 degrees off true, the declination 6.5 east.
        ("Caucasus", date(2016, 6, 1), (41.93, 41.86), (43.10, 40.57)),
    ],
)
def test_the_magnetic_bearing_is_the_true_one_less_the_declination(
    theatre: str, when: date, start: tuple[float, float], end: tuple[float, float]
) -> None:
    true = float(Geodesic.WGS84.Inverse(*start, *end)["azi1"]) % 360
    assert _off_by(true_bearing(*start, *end), true) < 0.001
    expected = true - declination(*start, when)
    bearing = magnetic_bearing(theatre, when, latlon_to_xy(theatre, *start), latlon_to_xy(theatre, *end))
    assert _off_by(bearing, expected) <= 0.5 + 0.001


def test_a_golan_leg_turns_seven_degrees_from_the_grid() -> None:
    # Marteau du Golan, measured 2026-10-29: the grid printed W1 -> W2 at 073, 71.3 true; then 5.2 east less.
    (x1, y1), (x2, y2) = latlon_to_xy("Syria", 33.05, 35.55), latlon_to_xy("Syria", 33.20, 36.05)
    grid = math.degrees(math.atan2(y2 - y1, x2 - x1)) % 360
    bearing = magnetic_bearing("Syria", date(2024, 6, 1), (x1, y1), (x2, y2))
    assert 6 <= _off_by(grid, bearing) <= 8


def test_a_point_true_north_reads_the_declination_off() -> None:
    origin = (41.93, 41.86)
    north = offset_latlon(*origin, 0.0, 20_000)
    when = date(2016, 6, 1)
    bearing = magnetic_bearing("Caucasus", when, latlon_to_xy("Caucasus", *origin), latlon_to_xy("Caucasus", *north))
    assert bearing == round(-declination(*origin, when)) % 360 == 353


@pytest.mark.parametrize(
    ("start", "end"),
    [
        ((33.05, 35.55), (33.20, 36.05)),
        ((41.93, 41.86), (43.10, 40.57)),
        ((41.6, 41.6), (41.7, 44.8)),
        ((10, 0), (14, 3)),
    ],
)
def test_the_distance_is_the_geodesic_one(start: tuple[float, float], end: tuple[float, float]) -> None:
    assert ground_distance_m(*start, *end) == pytest.approx(Geodesic.WGS84.Inverse(*start, *end)["s12"], abs=0.02)
    assert ground_distance_m(*start, *start) == 0.0


def test_the_grid_overstates_a_distance_far_from_its_meridian() -> None:
    # Batumi to Tbilisi, 8.6 to 11.8 degrees east of the Caucasus projection's meridian.
    a, b = latlon_to_xy("Caucasus", 41.6, 41.6), latlon_to_xy("Caucasus", 41.7, 44.8)
    true = Geodesic.WGS84.Inverse(41.6, 41.6, 41.7, 44.8)["s12"]
    assert ground_distance("Caucasus", a, b) == pytest.approx(true, abs=0.5)
    assert math.dist(a, b) / true > 1.005


@pytest.mark.parametrize(("theatre", "at"), [("Syria", (33.1, 35.8)), ("Caucasus", (41.93, 41.86))])
def test_a_grid_heading_is_turned_by_the_meridian_convergence(theatre: str, at: tuple[float, float]) -> None:
    origin = latlon_to_xy(theatre, *at)
    north_on_grid = (origin[0] + 1000, origin[1])
    true = float(Geodesic.WGS84.Inverse(*at, *xy_to_latlon(theatre, *north_on_grid))["azi1"]) % 360
    assert grid_heading_to_true(theatre, origin, 0) == pytest.approx(true, abs=0.001)
    when = date(2024, 6, 1)
    assert grid_heading_to_magnetic(theatre, when, origin, 0) == round(true - declination(*at, when)) % 360
