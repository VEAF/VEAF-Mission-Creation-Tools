"""Compose a METAR from a variant's manual weather, for the briefing's ``${METAR}``.

A variant declaring ``weather:`` only had no METAR, so the build left ``${METAR}`` printed raw in six of
the fifteen Syria briefings (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 10). The values are the ones the
build injects, so the pilot reads the sky they fly in.

There is no station: a manual sky belongs to no airfield, so the report starts with its time group.
"""

from datetime import datetime
from typing import Any

_MPS_TO_KT = 1.943844
_M_TO_FT = 3.28084
#: Manual ``cloud_type`` -> METAR cover; a clear sky reads ``SKC``.
_COVER = {"few": "FEW", "scattered": "SCT", "broken": "BKN", "overcast": "OVC"}


def _temperature(celsius: float) -> str:
    """``15`` -> ``15``, ``-5`` -> ``M05``: a METAR writes a negative temperature with ``M``."""
    value = round(celsius)
    return f"M{abs(value):02d}" if value < 0 else f"{value:02d}"


def compose_metar(manual: dict[str, Any], when_utc: datetime, qnh_hpa: float | None = None) -> str:
    """Write a variant's manual weather as a METAR.

    Args:
        manual: The variant's ``weather:`` mapping — ``wind_speed`` (m/s), ``wind_direction`` (from,
            degrees), ``visibility`` (m), ``cloud_type`` and ``cloud_height`` (m), ``precipitation``,
            ``fog_enabled``, ``temperature`` (°C); each optional.
        when_utc: The variant's start, in UTC.
        qnh_hpa: The pressure the mission carries, in hPa, when there is one.

    Returns:
        ``METAR DDHHMMZ dddssKT vvvv [cover] TT/// Qpppp``, the groups present in ``manual`` only.
    """
    groups = ["METAR", when_utc.strftime("%d%H%MZ")]
    speed = manual.get("wind_speed")
    if speed is not None:
        knots = round(float(speed) * _MPS_TO_KT)
        direction = round(float(manual.get("wind_direction") or 0) / 10) * 10 % 360
        groups.append("00000KT" if knots == 0 else f"{direction or 360:03d}{knots:02d}KT")
    visibility = manual.get("visibility")
    if visibility is not None:
        groups.append(f"{min(round(float(visibility)), 9999):04d}")
    if manual.get("precipitation"):
        groups.append("RA")
    if manual.get("fog_enabled"):
        groups.append("FG")
    cover = str(manual.get("cloud_type") or "").lower()
    if cover in _COVER:
        base = manual.get("cloud_height")
        hundreds = f"{round(float(base) * _M_TO_FT / 100):03d}" if base is not None else "///"
        groups.append(f"{_COVER[cover]}{hundreds}")
    elif cover == "clear":
        groups.append("SKC")
    temperature = manual.get("temperature")
    if temperature is not None:
        # No dew point in a manual sky: written missing, as a METAR does.
        groups.append(f"{_temperature(float(temperature))}///")
    if qnh_hpa:
        groups.append(f"Q{round(qnh_hpa):04d}")
    return " ".join(groups)
