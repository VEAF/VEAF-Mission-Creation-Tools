"""The MGRS square a position falls in — the grid DCS draws on the F10 map (FEAT-TERRAIN-ELEVATION).

Only what naming a square takes: the UTM zone, the latitude band, the 100 km square letters and the
truncated easting and northing. UTM is the transverse Mercator :mod:`veaf_libs.coordinates` already
computes for the theatres, with the scale factor 0.9996 both share. Svalbard's zone exceptions are
left out: no DCS theatre reaches 72° N.
"""

import math

from veaf_libs.coordinates import _tmerc_forward

_BANDS = "CDEFGHJKLMNPQRSTUVWX"
_COLUMN_SETS = ("ABCDEFGH", "JKLMNPQR", "STUVWXYZ")
_ROWS = "ABCDEFGHJKLMNPQRSTUV"


def utm_zone(lat: float, lon: float) -> int:
    """Return the UTM zone of a position, with southern Norway's exception (zone 32 widened west).

    Args:
        lat: Latitude, decimal degrees.
        lon: Longitude, decimal degrees.

    Returns:
        The zone number, 1 to 60.
    """
    if 56.0 <= lat < 64.0 and 3.0 <= lon < 12.0:
        return 32
    return int((lon + 180.0) // 6.0) % 60 + 1


def mgrs_square(lat: float, lon: float, size: int) -> str:
    """Name the MGRS square of ``size`` metres holding a position, e.g. ``"37T GG 4 1"`` for 10 km.

    Args:
        lat: Latitude, decimal degrees.
        lon: Longitude, decimal degrees.
        size: The square's side: 100 000 (no digits), 10 000 (one digit each) or 1 000 (two).

    Returns:
        Zone and band, the 100 km square letters, then the truncated easting and northing digits.

    Raises:
        ValueError: If the latitude is outside MGRS's UTM range, or ``size`` is not one of the three.
    """
    if not -80.0 <= lat <= 84.0:
        raise ValueError(f"latitude {lat} is outside MGRS's UTM range (-80 to 84)")
    digits = {100000: 0, 10000: 1, 1000: 2}.get(size)
    if digits is None:
        raise ValueError(f"square size {size} m: expected 100000, 10000 or 1000")
    zone = utm_zone(lat, lon)
    central = (zone - 1) * 6 - 180 + 3
    northing, easting = _tmerc_forward(math.radians(lat), math.radians(lon - central))
    easting += 500000.0
    if lat < 0:
        northing += 10000000.0
    band = _BANDS[min(int((lat + 80.0) // 8.0), len(_BANDS) - 1)]
    column = _COLUMN_SETS[(zone - 1) % 3][int(easting // 100000) - 1]
    row = _ROWS[(int(northing // 100000) + (5 if zone % 2 == 0 else 0)) % len(_ROWS)]
    square = f"{zone}{band} {column}{row}"
    if not digits:
        return square
    unit = 10 ** (5 - digits)
    east = int(easting % 100000) // unit
    north = int(northing % 100000) // unit
    return f"{square} {east:0{digits}d} {north:0{digits}d}"
