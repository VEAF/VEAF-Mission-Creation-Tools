"""UTC offset of each DCS theatre's clock.

DCS reads ``mission.start_time`` as the theatre's local time, with one fixed offset per theatre and no
daylight saving time. Caucasus v6 ``dawn-broken`` was computed in UTC and started at 01:28, pitch dark
in DCS (FIX-SCRATCH-MISSION-FINDINGS ticket 02).

DCS keeps its own table in an encrypted terrain file. The values here mirror the one the in-game
scripts already use, ``veafTime.getTimezone()`` in ``src/scripts/veaf/veafTime.lua``; a test keeps
the two identical. ``GermanyCW`` was measured in DCS on 2026-09-24 (June only).
"""

from datetime import date as dt_date
from datetime import datetime, time
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from veaf_libs.i18n import t
from veaf_libs.logger import logger

THEATRE_UTC_OFFSETS: dict[str, float] = {
    "Caucasus": 4,
    "PersianGulf": 4,
    "Nevada": -8,
    "Normandy": 0,
    "TheChannel": 2,
    "Syria": 3,
    "MarianaIslands": 10,
    "Falklands": -3,
    "SinaiMap": 2,
    "Kola": 3,
    "Afghanistan": 4.5,
    "GermanyCW": 2,
}


def theatre_utc_offset(theatre: str | None, fallback_timezone: str, on_date: dt_date) -> float:
    """Return the offset, in hours, of the theatre's clock from UTC.

    Args:
        theatre: The mission's theatre name as DCS writes it (``theatre`` member of the ``.miz``).
        fallback_timezone: IANA zone from ``versions.yaml``, used only for a theatre not in the table.
        on_date: Date the fallback zone's offset is taken on.

    Returns:
        The offset in hours; 0 when neither the theatre nor the zone is known.
    """
    if theatre in THEATRE_UTC_OFFSETS:
        return THEATRE_UTC_OFFSETS[theatre]
    try:
        offset = ZoneInfo(fallback_timezone).utcoffset(datetime.combine(on_date, time(12)))
        hours = offset.total_seconds() / 3600 if offset is not None else 0.0
    except (ZoneInfoNotFoundError, ValueError, OSError):
        hours = 0.0
    logger.warning(
        t("weather.theatre_offset.fallback", theatre=theatre or "?", timezone=fallback_timezone, hours=hours)
    )
    return hours
