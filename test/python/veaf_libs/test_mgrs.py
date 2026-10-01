"""Tests for the MGRS square of a position, against published conversions."""

import pytest
from veaf_libs.mgrs import mgrs_square, utm_zone


@pytest.mark.parametrize(
    ("lat", "lon", "expected"),
    [
        # The origin, the textbook case: 31N AA 66021 00000.
        (0.00001, 0.0, "31N AA 6 0"),
        # The Eiffel Tower, 31U DQ 48251 11932.
        (48.858370, 2.294481, "31U DQ 4 1"),
        # An even zone, where the row letters shift by five: the Statue of Liberty, 18T WL 80654 06346.
        (40.689247, -74.044502, "18T WL 8 0"),
        # Southern hemisphere: Sydney Opera House, 56H LH 34792 50908.
        (-33.856784, 151.215297, "56H LH 3 5"),
    ],
)
def test_the_ten_kilometre_square_matches_published_conversions(lat: float, lon: float, expected: str) -> None:
    assert mgrs_square(lat, lon, 10000) == expected


def test_a_hundred_kilometre_square_drops_the_digits() -> None:
    assert mgrs_square(48.858370, 2.294481, 100000) == "31U DQ"


def test_southern_norway_takes_zone_32() -> None:
    assert utm_zone(60.0, 4.0) == 32
    assert utm_zone(60.0, 2.0) == 31


def test_outside_mgrs_latitudes_is_refused() -> None:
    with pytest.raises(ValueError, match="84"):
        mgrs_square(85.0, 0.0, 10000)
