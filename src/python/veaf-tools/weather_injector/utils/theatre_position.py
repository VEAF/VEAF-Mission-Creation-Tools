"""Where solar times are computed when ``versions.yaml`` gives no ``position`` (FIX-SOLAR-DEFAULT-POSITION).

The shipped ``versions.yaml`` used to declare Damascus, so every mission keeping it computed its sunrise
there: a Caucasus ``sunrise`` started at 07:48 on 2024-03-15, 24 minutes late (50 in June). The point is
now the theatre's: the map centre a blank mission of it opens on (``theatre-defaults.yaml``, extracted
from the dcs-maps calibration missions), else the centre of its bounding box (``theatre-bounds.yaml``,
from its airfields' extent). One point per theatre: on a wide map, a mission far from it is a few
minutes off, and a ``position`` in ``versions.yaml`` still says exactly where.
"""

from veaf_libs import coordinates
from veaf_libs.blank_mission import theatre_map_centre
from veaf_libs.geocoding import theatre_bounds

from ..models import Position


def theatre_position(theatre: str | None) -> Position | None:
    """Return the point a theatre's solar times are computed at when none is declared.

    Args:
        theatre: The mission's theatre name as DCS writes it (``theatre`` member of the ``.miz``).

    Returns:
        The point, with the nominal zone of its longitude as timezone (read only for a theatre whose DCS
        clock is not in ``theatre_offsets.py``); ``None`` for a theatre with neither a map centre nor
        bounds, or one the projection does not know.
    """
    if not theatre or not coordinates.is_theatre_supported(theatre):
        return None
    centre = theatre_map_centre(theatre)
    if centre is not None:
        latitude, longitude = coordinates.xy_to_latlon(theatre, *centre)
    else:
        bounds = theatre_bounds(theatre)
        if bounds is None:
            return None
        latitude, longitude = (bounds.min_lat + bounds.max_lat) / 2, (bounds.min_lon + bounds.max_lon) / 2
    # Etc/GMT names are sign-inverted: Etc/GMT-3 is UTC+3.
    return Position(latitude, longitude, f"Etc/GMT{-round(longitude / 15):+d}")
