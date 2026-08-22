"""DCS weather conversion from METAR data."""

import json
import re
import traceback
from functools import lru_cache
from typing import Any

from veaf_libs.i18n import t
from veaf_libs.logger import logger

try:
    from avwx.current.metar import Metar

    AVWX_AVAILABLE = True
except ImportError:
    AVWX_AVAILABLE = False


class DCSWeatherConverter:
    """Convert METAR strings to DCS weather table format."""

    # DCS weather cloud types
    CLOUD_TYPES = {
        "clear": 0,
        "few": 1,
        "scattered": 2,
        "broken": 3,
        "overcast": 4,
    }

    @staticmethod
    def to_dcs_lua_table(
        metar_string: str = "",
        airport_icao: str = "",
        temperature_celsius: float | None = None,
        wind_speed_mps: float | None = None,
        wind_direction_degrees: float | None = None,
        visibility_meters: float | None = None,
        cloud_coverage: str | None = None,
        cloud_height_meters: float | None = None,
        fog_enabled: bool = False,
        fog_density: float = 0.0,
        fog_thickness_meters: float = 200.0,
    ) -> dict[str, Any]:
        """
        Convert weather parameters to DCS mission weather table.

        Supports three weather input methods:
        1. metar_string: User-provided METAR string (parsed with regex)
        2. airport_icao: Airport code to fetch live METAR from avwx-engine
        3. Individual parameters: Manual weather values

        Priority: metar_string > airport_icao > individual parameters > defaults

        Args:
            metar_string: METAR weather string (provided manually)
            airport_icao: Airport ICAO code to fetch live METAR from avwx
            temperature_celsius: Temperature override
            wind_speed_mps: Wind speed in m/s override
            wind_direction_degrees: Wind direction override
            visibility_meters: Visibility in meters override
            cloud_coverage: Cloud type ("clear", "few", "scattered", "broken", "overcast")
            cloud_height_meters: Cloud base altitude in meters
            fog_enabled: Enable fog effect
            fog_density: Fog density (0.0-1.0)
            fog_thickness_meters: Fog vertical thickness

        Returns:
            Dictionary representing DCS weather table structure
        """
        try:
            weather = {}

            # Priority 1: Use provided METAR string
            if metar_string:
                weather = _extract_metar_values(metar_string)
            # Priority 2: Fetch live weather from avwx if airport code provided
            elif airport_icao:
                weather = _fetch_live_metar(airport_icao)

            # Apply parameter overrides
            if temperature_celsius is not None:
                weather["temperature"] = temperature_celsius
            if wind_speed_mps is not None:
                weather["wind_speed"] = wind_speed_mps
            if wind_direction_degrees is not None:
                weather["wind_direction"] = wind_direction_degrees
            if visibility_meters is not None:
                weather["visibility"] = visibility_meters
            if cloud_coverage:
                weather["cloud_type"] = DCSWeatherConverter.CLOUD_TYPES.get(cloud_coverage.lower(), 0)
            if cloud_height_meters is not None:
                weather["cloud_height"] = cloud_height_meters

            # Build DCS weather table
            dcs_weather = {
                "atmosphere": {
                    "temperature_celsius": weather.get("temperature", 15.0),
                    "wind": {
                        "speed_mps": weather.get("wind_speed", 5.0),
                        "direction_degrees": weather.get("wind_direction", 0.0),
                    },
                    "visibility_meters": weather.get("visibility", 10000.0),
                    "clouds": {
                        "type": weather.get("cloud_type", 0),
                        "base_altitude_meters": weather.get("cloud_height", 2000.0),
                        "density": 0.0,
                    },
                },
                "fog": {
                    "enabled": fog_enabled,
                    "density": fog_density,
                    "thickness_meters": fog_thickness_meters,
                },
            }

            logger.debug(f"Converted weather: {json.dumps(dcs_weather, indent=2)}")
            return dcs_weather

        except Exception as e:
            logger.error(t("weather.converter.convert_failed", error=str(e)))
            raise


def fetch_metar_string(airport_icao: str) -> str:
    """The raw METAR text for *airport_icao*, for showing to a pilot.

    Args:
        airport_icao: Airport ICAO code.

    Returns:
        The METAR as the station published it, or ``""`` when it cannot be had.

    Derived from the **same** fetch that builds the DCS weather table, not a second request. That matters
    twice over (caught in review, Sourcery PR #786): a station publishing a new report between two
    requests would put a METAR in the briefing that contradicts the weather actually injected, and a
    second request is a second chance to be rate-limited or to fail.

    ``${METAR}`` in a briefing wants what a pilot would read, so this is the published text rather than a
    reconstruction of it from the parsed values.
    """
    return str(_fetch_live_metar(airport_icao).get("raw", "") or "")


def clear_metar_cache() -> None:
    """Forget the fetched reports.

    For tests, and for a caller that deliberately wants a fresh look at the weather.
    """
    _fetch_live_metar.cache_clear()


@lru_cache(maxsize=32)
def _fetch_live_metar(airport_icao: str) -> dict[str, Any]:
    """
    Fetch live METAR data from avwx-engine by airport ICAO code.

    Args:
        airport_icao: Airport ICAO code (e.g., "OSDI", "KJFK")

    Returns:
        Dictionary with keys: temperature, wind_speed, wind_direction,
        visibility, cloud_type, cloud_height, and ``raw`` — the published text.

    **Memoised per ICAO**, so a station is asked once per process however many places want it. Two
    consumers exist — the weather table and the briefing's ``${METAR}`` — and they must agree: a station
    publishing between two requests would otherwise have the briefing contradict the weather the mission
    was actually built with (Sourcery, PR #786). It also keeps seven variants sharing one ICAO down to a
    single request instead of seven.

    The cached dict is returned by reference and callers only read it. :func:`clear_metar_cache` exists
    for tests and for a caller that wants a deliberately fresh look.
    """
    result: dict[str, Any] = {
        "temperature": 15.0,  # Default
        "wind_speed": 5.0,  # m/s
        "wind_direction": 0.0,  # degrees
        "visibility": 10000.0,  # meters
        "cloud_type": 0,  # Clear
        "cloud_height": 2000.0,  # meters
        "raw": "",  # the published text, for a briefing to show
    }

    if not airport_icao or not AVWX_AVAILABLE:
        if not AVWX_AVAILABLE:
            logger.warning(t("weather.converter.avwx_unavailable"))
        return result

    try:
        logger.debug(f"Fetching live METAR for airport {airport_icao} from avwx-engine")
        metar = Metar(airport_icao)

        # VMR-006: `Metar(icao)` only *constructs* — `.update()` is what fetches. Without it
        # every attribute below is None, so the function returned its canned defaults while
        # logging "Successfully fetched", and a mission asking for live weather quietly got
        # invented weather. The return value matters too: avwx reports a failed fetch by
        # returning False rather than raising, so ignoring it reinstates the same silence.
        if not metar.update():  # type: ignore[attr-defined]
            logger.warning(t("weather.converter.metar_fetch_empty", icao=airport_icao))
            return result

        result["raw"] = str(getattr(metar, "raw", "") or "")

        if metar.temperature and metar.temperature.value is not None:  # type: ignore[attr-defined]
            result["temperature"] = metar.temperature.value  # type: ignore[attr-defined]

        if metar.wind_speed and metar.wind_speed.value is not None:  # type: ignore[attr-defined]
            # avwx returns knots, convert to m/s
            result["wind_speed"] = metar.wind_speed.value / 1.944  # type: ignore[attr-defined]

        if metar.wind_direction and metar.wind_direction.value is not None:  # type: ignore[attr-defined]
            result["wind_direction"] = float(metar.wind_direction.value)  # type: ignore[attr-defined]

        if metar.visibility and metar.visibility[0].value is not None:  # type: ignore[attr-defined]
            result["visibility"] = metar.visibility[0].value  # type: ignore[attr-defined]

        # Process clouds
        if metar.clouds:  # type: ignore[attr-defined]
            for cloud in metar.clouds:  # type: ignore[attr-defined]
                if cloud[0]:
                    cloud_coverage = cloud[0].lower()
                    if cloud_coverage in ["skc", "clr"]:
                        result["cloud_type"] = 0  # Clear
                    elif cloud_coverage == "few":
                        result["cloud_type"] = 1
                    elif cloud_coverage == "sct":
                        result["cloud_type"] = 2  # Scattered
                    elif cloud_coverage == "bkn":
                        result["cloud_type"] = 3  # Broken
                    elif cloud_coverage == "ovc":
                        result["cloud_type"] = 4  # Overcast

                if cloud[1]:
                    result["cloud_height"] = float(cloud[1].value)
                    break  # Use first cloud layer

        logger.debug(f"Successfully fetched METAR for {airport_icao}: {result}")
    except Exception as e:
        # Kept broad on purpose: this is a network call to a third-party library, and a build must
        # not die because a weather service is down. But naming the exception type is what makes a
        # programming error tellable from an outage (SECREV-2 / VMR-069) — an AttributeError from an
        # avwx API change used to read exactly like a failed request, and the traceback was lost
        # entirely. The mission then flies the default weather, so the warning has to be legible.
        logger.warning(t("weather.converter.metar_fetch_failed", icao=airport_icao, error=f"{type(e).__name__}: {e}"))
        logger.debug(f"METAR fetch traceback for {airport_icao}:\n{traceback.format_exc()}")

    return result


def _extract_metar_values(metar_string: str) -> dict[str, Any]:
    """
    Extract weather values from METAR string using regex-based parsing.

    Args:
        metar_string: METAR weather string (e.g., "OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018")

    Returns:
        Dictionary with keys: temperature, wind_speed, wind_direction,
        visibility, cloud_type, cloud_height
    """
    result = {
        "temperature": 15.0,  # Default
        "wind_speed": 5.0,  # m/s
        "wind_direction": 0.0,  # degrees
        "visibility": 10000.0,  # meters
        "cloud_type": 0,  # Clear
        "cloud_height": 2000.0,  # meters
    }

    if not metar_string:
        return result

    # Use fallback regex-based parsing for provided METAR strings
    result = _fallback_metar_parsing(metar_string, result)

    return result


def _fallback_metar_parsing(metar_string: str, defaults: dict[str, Any]) -> dict[str, Any]:
    """
    Fallback regex-based METAR parsing for common patterns.

    Used when avwx-engine is not available or parsing fails.
    Extracts basic values from standard METAR format.

    Args:
        metar_string: METAR weather string
        defaults: Default values to use

    Returns:
        Dictionary with extracted weather values
    """
    result = defaults.copy()

    if not metar_string:
        return result

    parts = metar_string.split()

    # Everything from the first of these words on describes a *forecast* or free-text remarks, not
    # the current observation (SECREV-2 / VMR-070). The loop used to read straight through them, and
    # since the visibility branch has no `break`, the last four-digit group won: a report ending in
    # `TEMPO 3000` was flown at 3000 m even though it was observed at 9999.
    _NOT_OBSERVED_FROM = ("TEMPO", "BECMG", "NOSIG", "RMK", "PROB30", "PROB40", "FM")
    for cut, part in enumerate(parts):
        if part.upper().startswith(_NOT_OBSERVED_FROM):
            parts = parts[:cut]
            break

    #: Which single-valued groups have already been read, so a later token cannot overwrite them.
    seen: set[str] = set()

    for i, part in enumerate(parts):
        # Temperature/Dewpoint: "15/10" format
        if "/" in part and i > 0:
            with_temp = part.split("/")[0]
            # VMR-016: a METAR marks a negative temperature with an `M` prefix, not a minus
            # sign — `M05/M10` is -5 °C with a -10 °C dewpoint. Testing `lstrip("-").isdigit()`
            # therefore rejected every sub-zero reading and left the default in place
            # **silently**, so a winter mission quietly flew at whatever temperature happened to
            # be configured. Both spellings are accepted now; the `-` form is not valid METAR but
            # was already tolerated here, and removing tolerance would be a second change.
            if with_temp.upper().startswith("M"):
                with_temp = "-" + with_temp[1:]
            if with_temp.lstrip("-").isdigit():
                try:
                    result["temperature"] = float(with_temp)
                except ValueError:
                    pass

        # Wind: "27015G25KT" or "27015KT" format (direction speed[gust]KT/MPS)
        if "KT" in part or "MPS" in part:
            match = re.match(r"(\d{3})(\d{2})(?:G(\d{2}))?", part)
            if match:
                try:
                    result["wind_direction"] = float(match.group(1))
                    speed = float(match.group(2))
                    # Convert knots to m/s (1 knot = 0.51444 m/s)
                    result["wind_speed"] = speed * 0.51444
                except ValueError:
                    pass

        # Visibility: "9999" format (meters) or "10SM" (statute miles).
        # First one only: a METAR carries at most one prevailing visibility, and taking the last
        # four-digit group let a later one overwrite it (SECREV-2 / VMR-070).
        if part.isdigit() and len(part) == 4 and "visibility" not in seen:
            result["visibility"] = float(part)
            seen.add("visibility")

        # Cloud coverage groups: "FEW010", "SCT025", "BKN040", "OVC100"
        cloud_match = re.match(r"(SKC|CLR|FEW|SCT|BKN|OVC)(\d{3})?", part)
        if cloud_match:
            coverage = cloud_match.group(1)
            altitude = cloud_match.group(2)

            if coverage in ["SKC", "CLR"]:
                result["cloud_type"] = 0
            elif coverage == "FEW":
                result["cloud_type"] = 1
            elif coverage == "SCT":
                result["cloud_type"] = 2
            elif coverage == "BKN":
                result["cloud_type"] = 3
            elif coverage == "OVC":
                result["cloud_type"] = 4

            if altitude:
                try:
                    # Altitude in METAR is in hundreds of feet
                    result["cloud_height"] = float(altitude) * 100 * 0.3048  # Convert to meters
                except ValueError:
                    pass

    return result
