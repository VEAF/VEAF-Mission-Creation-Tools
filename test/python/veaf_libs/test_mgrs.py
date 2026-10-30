"""Tests for the MGRS square of a position, against published conversions."""

import math

import pytest
from veaf_libs.mgrs import mgrs_square, to_mgrs, utm_zone


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


def _kruger_utm(lat: float, lon: float) -> tuple[float, float]:
    """UTM easting and northing by Krüger's series (Karney 2011, third order): an oracle independent of ours.

    Our transverse Mercator is Snyder's power series in longitude; Krüger's is accurate to the millimetre
    across a zone. Two different methods agreeing to the metre is what makes the expected values trustworthy:
    the grid references first written here "from memory" were off by up to 1.6 km.
    """
    a, f, k0 = 6378137.0, 1 / 298.257223563, 0.9996
    n = f / (2 - f)
    big_a = a / (1 + n) * (1 + n**2 / 4 + n**4 / 64)
    alpha = (n / 2 - 2 * n**2 / 3 + 5 * n**3 / 16, 13 * n**2 / 48 - 3 * n**3 / 5, 61 * n**3 / 240)
    zone = utm_zone(lat, lon)
    lam = math.radians(lon - ((zone - 1) * 6 - 180 + 3))
    phi = math.radians(lat)
    e = math.sqrt(f * (2 - f))
    tau = math.sinh(math.atanh(math.sin(phi)) - e * math.atanh(e * math.sin(phi)))
    xi = math.atan2(tau, math.cos(lam))
    eta = math.atanh(math.sin(lam) / math.sqrt(1 + tau * tau))
    j = range(1, 4)
    easting = 500000 + k0 * big_a * (eta + sum(alpha[i - 1] * math.cos(2 * i * xi) * math.sinh(2 * i * eta) for i in j))
    northing = k0 * big_a * (xi + sum(alpha[i - 1] * math.sin(2 * i * xi) * math.cosh(2 * i * eta) for i in j))
    return easting, northing + (10000000 if lat < 0 else 0)


def test_to_mgrs_of_the_origin_is_the_textbook_value() -> None:
    assert to_mgrs(0.0, 0.0) == "31N AA 66021 00000"


@pytest.mark.parametrize(
    ("lat", "lon"),
    [
        (33.0, 36.0),  # Syria, 3° from zone 37's central meridian: the series' worst case
        (33.0, 39.5),
        (33.3007, 35.7704),  # the Golan
        (42.2, 41.6),  # Caucasus
        (49.3, -0.6),  # Normandy
        (-51.7, -59.0),  # South Atlantic
        (15.2, 145.7),  # Marianas
    ],
)
def test_to_mgrs_agrees_to_the_metre_with_an_independent_method(lat: float, lon: float) -> None:
    easting, northing = _kruger_utm(lat, lon)
    _, _, east, north = to_mgrs(lat, lon).split()
    assert abs(int(east) - easting % 100000) <= 1
    assert abs(int(north) - northing % 100000) <= 1
