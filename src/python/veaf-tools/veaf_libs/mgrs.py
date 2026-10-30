"""The MGRS square a position falls in — the grid DCS draws on the F10 map (FEAT-TERRAIN-ELEVATION).

Only what naming a square takes: the UTM zone, the latitude band, the 100 km square letters and the
truncated easting and northing. UTM is the transverse Mercator :mod:`veaf_libs.coordinates` already
computes for the theatres, with the scale factor 0.9996 both share. Svalbard's zone exceptions are
left out: no DCS theatre reaches 72° N.
"""

import math

from veaf_libs.coordinates import _tmerc_forward, to_ddm

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
        size: The square's side: 100 000 (no digits), 10 000 (one digit each), 1 000 (two), 100, 10 or 1
            (five: the full ten-digit grid reference).

    Returns:
        Zone and band, the 100 km square letters, then the truncated easting and northing digits.

    Raises:
        ValueError: If the latitude is outside MGRS's UTM range, or ``size`` is not one of the three.
    """
    if not -80.0 <= lat <= 84.0:
        raise ValueError(f"latitude {lat} is outside MGRS's UTM range (-80 to 84)")
    digits = {100000: 0, 10000: 1, 1000: 2, 100: 3, 10: 4, 1: 5}.get(size)
    if digits is None:
        raise ValueError(f"square size {size} m: expected 100000, 10000, 1000, 100, 10 or 1")
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


def to_mgrs(lat: float, lon: float) -> str:
    """A position as a ten-digit MGRS grid reference, to the metre: ``37S BT 12345 67890``.

    How a target's precise position is given beside its degrees and decimal minutes
    (FIX-MARTEAU-PLAY-FINDINGS 04): an A-10 or an AH-64 takes it as is.

    Args:
        lat: Latitude, decimal degrees.
        lon: Longitude, decimal degrees.

    Returns:
        Zone and band, the 100 km square letters, then the easting and northing in metres.

    Raises:
        ValueError: If the latitude is outside MGRS's UTM range.
    """
    return mgrs_square(lat, lon, 1)


def target_coordinates(lat: float, lon: float) -> tuple[str, str]:
    """A target's precise position as a briefing writes it: degrees and decimal minutes, and MGRS.

    David's rule (FIX-MARTEAU-PLAY-FINDINGS 04): never degrees, minutes and seconds for a target — the
    cockpits take DD°MM.mmm' (F-16, F/A-18) or a grid reference (A-10, AH-64).

    Args:
        lat: Latitude, decimal degrees.
        lon: Longitude, decimal degrees.

    Returns:
        ``("DDM N33°07.536' E035°49.482'", "MGRS 36S YB 12345 67890")``.
    """
    return f"DDM {to_ddm(lat, lon)}", f"MGRS {to_mgrs(lat, lon)}"
