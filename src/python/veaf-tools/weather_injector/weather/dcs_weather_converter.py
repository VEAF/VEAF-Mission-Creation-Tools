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

#: DCS cloud presets per coverage, in order of preference, with the cloud-base range in metres DCS
#: accepts for each: ``presetAltMin`` / ``presetAltMax`` in ``Config/Effects/clouds.lua`` of the DCS
#: install. The coverage lists follow the METAR each preset declares in its ``readableName`` there.
#: v5 picked one at random from similar lists; a build must be reproducible, so the first preset whose
#: range holds the base wins.
_PRESETS_BY_COVERAGE: dict[int, list[tuple[str, float, float]]] = {
    1: [("Preset1", 840, 4200), ("Preset2", 1260, 2520)],  # FEW
    2: [("Preset3", 840, 2520), ("Preset4", 1260, 2520), ("Preset5", 1260, 4620), ("Preset8", 3780, 5460)],  # SCT
    3: [("Preset13", 1680, 3360), ("Preset15", 840, 5040), ("Preset16", 1260, 4200), ("Preset17", 0, 2520)],  # BKN
    4: [("Preset21", 1260, 4200), ("Preset22", 420, 4200), ("Preset19", 0, 2940)],  # OVC
}
_RAINY_PRESETS: list[tuple[str, float, float]] = [("RainyPreset1", 420, 2940), ("RainyPreset2", 840, 2520)]

#: 15 kt: the wind cap of ``clearsky: true``.
_CLEARSKY_MAX_WIND_MPS = 7.72

#: METAR present-weather groups that make DCS rain: rain, drizzle, hail, unknown precipitation, and
#: a thunderstorm. Snow is left out on purpose: no DCS preset is a snow preset, and what DCS does
#: with a rainy preset below zero has not been checked.
_PRECIPITATION = re.compile(r"[-+]?(?:VC)?(?:TS|SH|FZ)?(?:RA|DZ|GR|GS|UP)+|[-+]?(?:VC)?TS")
#: Fog groups (``FG``, ``MIFG``, ``BCFG``, ``PRFG``, ``FZFG``).
_FOG = re.compile(r"(?:MI|BC|PR|FZ)?FG")


def _select_cloud_preset(cloud_type: int, base: float, precipitation: bool) -> tuple[str | None, float]:
    """Pick the DCS cloud preset for a coverage and base, and the base DCS will accept with it.

    Args:
        cloud_type: Coverage, 0 (clear) to 4 (overcast) as in ``DCSWeatherConverter.CLOUD_TYPES``.
        base: Wanted cloud base in metres.
        precipitation: Whether it rains, which only the rainy presets render.

    Returns:
        The preset name (None for a clear sky) and the base, moved into the preset's range if needed.
    """
    candidates = _RAINY_PRESETS if precipitation else _PRESETS_BY_COVERAGE.get(cloud_type)
    if not candidates:
        return None, base
    for name, low, high in candidates:
        if low <= base <= high:
            return name, base
    name, low, high = min(candidates, key=lambda c: max(c[1] - base, base - c[2]))
    return name, min(max(base, low), high)


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
        precipitation: bool | None = None,
        fog_enabled: bool = False,
        fog_thickness_meters: float = 200.0,
        clearsky: bool = False,
    ) -> dict[str, Any]:
        """
        Convert weather parameters to the fields of the DCS mission ``weather`` table.

        Supports three weather input methods:
        1. metar_string: User-provided METAR string (parsed with regex)
        2. airport_icao: Airport code to fetch live METAR from avwx-engine
        3. Individual parameters: Manual weather values

        Priority: metar_string > airport_icao > individual parameters > defaults

        The result holds the keys DCS reads (``season``, ``wind``, ``visibility``, ``clouds``, ``qnh``,
        ``enable_fog``, ``fog``, ``atmosphere_type``) and is merged into the mission's table, so the
        keys it does not set (``cyclones``, ``groundTurbulence``, dust...) keep the base mission's values.
        It used to return an ``atmosphere`` table DCS does not know, so every variant flew the base
        mission's sky (FIX-SCRATCH-MISSION-FINDINGS ticket 01).

        Args:
            metar_string: METAR weather string (provided manually)
            airport_icao: Airport ICAO code to fetch live METAR from avwx
            temperature_celsius: Temperature override
            wind_speed_mps: Wind speed in m/s override
            wind_direction_degrees: Wind direction override, where the wind comes FROM as in a METAR
            visibility_meters: Visibility in meters override
            cloud_coverage: Cloud type ("clear", "few", "scattered", "broken", "overcast")
            cloud_height_meters: Cloud base altitude in meters
            precipitation: Rain override; a METAR's rain groups set it otherwise
            fog_enabled: Enable fog effect (a METAR's fog group enables it too)
            fog_thickness_meters: Fog vertical thickness
            clearsky: Cap to VFR-friendly conditions: clouds at most FEW, wind under 15 kt,
                visibility 10 km or more, no rain, no fog

        Returns:
            Dictionary of DCS ``weather`` table fields
        """
        try:
            weather: dict[str, Any] = {}

            # Priority 1: Use provided METAR string
            if metar_string:
                weather = _extract_metar_values(metar_string)
            # Priority 2: Fetch live weather from avwx if airport code provided
            elif airport_icao:
                # A copy: the fetch is memoised and returns its dict by reference.
                weather = dict(_fetch_live_metar(airport_icao))

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
            if precipitation is not None:
                weather["precipitation"] = precipitation
            fog = fog_enabled or bool(weather.get("fog"))

            if clearsky:
                weather["cloud_type"] = min(weather.get("cloud_type", 0), DCSWeatherConverter.CLOUD_TYPES["few"])
                weather["wind_speed"] = min(weather.get("wind_speed", 5.0), _CLEARSKY_MAX_WIND_MPS)
                weather["visibility"] = max(weather.get("visibility", 10000.0), 9999.0)
                weather["precipitation"] = False
                fog = False
                logger.debug(t("weather.clearsky_applied"))

            preset, base = _select_cloud_preset(
                weather.get("cloud_type", 0), weather.get("cloud_height", 2000.0), bool(weather.get("precipitation"))
            )
            clouds: dict[str, Any] = {"thickness": 200, "density": 0, "base": round(base), "iprecptns": 0}
            if preset:
                clouds["preset"] = preset

            # A METAR gives where the wind comes FROM, the mission file where it blows TO (v5 did the
            # same, `convertFromTo`). Aloft, v5 added a random 1-3 m/s at 2000 m and 2-8 m/s at 8000 m;
            # the middle of each range is used so a build is reproducible.
            speed = weather.get("wind_speed", 5.0)
            direction = round((weather.get("wind_direction", 0.0) + 180) % 360)
            visibility = weather.get("visibility", 10000.0)

            dcs_weather: dict[str, Any] = {
                "atmosphere_type": 0,  # static weather: with dynamic weather DCS ignores the fields below
                "season": {"temperature": weather.get("temperature", 15.0)},
                "wind": {
                    "atGround": {"speed": speed, "dir": direction},
                    "at2000": {"speed": speed + 2.0, "dir": direction},
                    "at8000": {"speed": speed + 5.0, "dir": direction},
                },
                # A METAR's 9999 means "10 km or more"; v5 flew it as DCS's 80 km.
                "visibility": {"distance": 80000 if visibility >= 9000 else round(visibility)},
                "clouds": clouds,
                "enable_fog": fog,
                # v5's fog: 800-1000 m visibility, 100-300 m thick; the middle, for reproducibility.
                "fog": {"visibility": 900 if fog else 0, "thickness": round(fog_thickness_meters) if fog else 0},
            }
            # Only a pressure actually reported: otherwise the base mission's QNH stays.
            if weather.get("qnh_hpa"):
                dcs_weather["qnh"] = round(weather["qnh_hpa"] * 0.750062, 1)  # DCS stores mmHg

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
        visibility, cloud_type, cloud_height, qnh_hpa, precipitation, fog, and ``raw`` — the published text.

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
        "qnh_hpa": None,  # hPa, only when reported
        "precipitation": False,
        "fog": False,
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
        # the published text is empty, so the function returned its canned defaults while
        # logging "Successfully fetched", and a mission asking for live weather quietly got
        # invented weather. The return value matters too: avwx reports a failed fetch by
        # returning False rather than raising, so ignoring it reinstates the same silence.
        if not metar.update():  # type: ignore[attr-defined]
            logger.warning(t("weather.converter.metar_fetch_empty", icao=airport_icao))
            return result

        result["raw"] = str(getattr(metar, "raw", "") or "")

        # The published text goes through the same parser as a METAR written in versions.yaml. This
        # used to read `metar.temperature`, `metar.clouds[i][0]`... — attributes the avwx `Metar` does
        # not have (its values live under `.data`), so every live fetch died on AttributeError and flew
        # the defaults; the tests passed on a fake shaped like that invented API
        # (FIX-SCRATCH-MISSION-FINDINGS ticket 01). One parser also gives both paths the pressure, the
        # rain and the fog.
        result = _fallback_metar_parsing(result["raw"], result)

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
        visibility, cloud_type, cloud_height, qnh_hpa, precipitation, fog
    """
    result: dict[str, Any] = {
        "temperature": 15.0,  # Default
        "wind_speed": 5.0,  # m/s
        "wind_direction": 0.0,  # degrees
        "visibility": 10000.0,  # meters
        "cloud_type": 0,  # Clear
        "cloud_height": 2000.0,  # meters
        "qnh_hpa": None,  # hPa, only when reported
        "precipitation": False,
        "fog": False,
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
            # A variable wind (`VRB02KT`) has no direction: it keeps the default. Both used to be
            # read as knots, and a VRB group not at all — harmless while the weather never reached
            # DCS, wrong since it does (URSS, feeding Caucasus v6, reports in MPS).
            match = re.match(r"(\d{3}|VRB)(\d{2})(?:G(\d{2}))?(KT|MPS)", part)
            if match:
                try:
                    if match.group(1) != "VRB":
                        result["wind_direction"] = float(match.group(1))
                    speed = float(match.group(2))
                    # Convert knots to m/s (1 knot = 0.51444 m/s)
                    result["wind_speed"] = speed if match.group(4) == "MPS" else speed * 0.51444
                except ValueError:
                    pass

        # Visibility: "9999" format (meters) or "10SM" (statute miles).
        # First one only: a METAR carries at most one prevailing visibility, and taking the last
        # four-digit group let a later one overwrite it (SECREV-2 / VMR-070).
        if part.isdigit() and len(part) == 4 and "visibility" not in seen:
            result["visibility"] = float(part)
            seen.add("visibility")

        # Pressure: "Q1018" (hPa) or "A2992" (inches of mercury, hundredths)
        pressure = re.fullmatch(r"([QA])(\d{4})", part)
        if pressure and "qnh" not in seen:
            value = float(pressure.group(2))
            result["qnh_hpa"] = value if pressure.group(1) == "Q" else value / 100 * 33.8639
            seen.add("qnh")

        # Present weather: rain, drizzle, thunderstorm... and fog
        if _PRECIPITATION.fullmatch(part):
            result["precipitation"] = True
        if _FOG.fullmatch(part):
            result["fog"] = True

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
