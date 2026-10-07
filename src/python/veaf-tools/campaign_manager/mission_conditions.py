"""A campaign mission's date, time and weather (FEAT-CAMPAIGN-MISSION-BRIEFING ticket 01).

David, 2026-10-07: one mission and no weather variant; date, time and weather fixed in the mission;
the date moves on with the campaign; the weather may change from one mission to the next, but the
ground stays visible — CAVOK or nearly.

So `campaign next` writes them into the mission it creates, once: the date follows the last mission
flown, the time is computed on the campaign's own ground (the shipped `versions.yaml` puts its solar
times at Damascus, which made "sunrise" wrong on the Caucasus), and the weather is drawn within
limits, seeded by the campaign and the mission so that the same mission always draws the same sky.
A refresh leaves all three alone: what Claude set afterwards is design.
"""

from __future__ import annotations

import random
import re
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path
from typing import Any

from mission_tools.mission_yaml_editor import load_yaml, save_yaml
from veaf_mission_mcp.mission_folder import open_mission
from veaf_mission_mcp.mission_settings import set_mission_date, set_weather
from weather_injector.models import Position
from weather_injector.utils.solar_calculator import SolarCalculator
from weather_injector.utils.theatre_offsets import theatre_utc_offset
from weather_injector.utils.time_expression_parser import _safe_arithmetic_eval
from weather_injector.weather.dcs_weather_converter import _PRESETS_BY_COVERAGE

from campaign_manager.models import CampaignDefinition, CampaignState
from campaign_manager.strategic_map import zone_position

#: Days between two missions when nothing else says.
DAYS_BETWEEN_MISSIONS = 1

#: The weather variants file a campaign mission does without.
VERSIONS_FILE = "src/versions.yaml"

#: The ground stays visible: no lower visibility, in metres.
MIN_VISIBILITY = 8000

#: The cloud covers a campaign mission may draw: clear, few, scattered — never broken or overcast.
GROUND_VISIBLE_COVERS: tuple[str, ...] = ("clear", "few", "scattered")

#: The DCS cloud presets of those covers (`dcs_weather_converter`, after `Config/Effects/clouds.lua`).
_GROUND_VISIBLE_PRESETS = frozenset(name for cover in (1, 2) for name, _, _ in _PRESETS_BY_COVERAGE[cover])

#: Mean ground temperature by month, °C, for a mid-latitude northern theatre. An estimate, not a
#: climatology: it keeps June warm and January cold, which is all a briefing needs.
_MONTHLY_TEMPERATURE = (3, 4, 8, 13, 18, 22, 25, 25, 21, 15, 9, 5)

_CLOCK = re.compile(r"^\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*$")


@dataclass(frozen=True)
class MissionConditions:
    """The date, start time and weather written into a campaign mission."""

    date: date
    start_time: int
    """Seconds since midnight, on the theatre's clock — the one DCS shows."""
    weather: dict[str, Any]
    """The drawn weather, in `set_weather`'s vocabulary: wind FROM, as pilots read it."""

    @property
    def clock(self) -> str:
        """The start time as ``HH:MM``."""
        return f"{self.start_time // 3600:02d}:{self.start_time % 3600 // 60:02d}"


def start_seconds(expression: str, sunrise: int, sunset: int) -> int:
    """Turn a start time — ``"06:30"`` or ``"sunrise+30*60"`` — into seconds since midnight.

    Args:
        expression: A clock time, or an arithmetic expression of ``sunrise`` and ``sunset``.
        sunrise: Sunrise, in seconds since midnight.
        sunset: Sunset, in seconds since midnight.

    Returns:
        Seconds since midnight, within the day.

    Raises:
        ValueError: The expression is neither.
    """
    clock = _CLOCK.match(expression)
    if clock:
        hours, minutes, seconds = int(clock[1]), int(clock[2]), int(clock[3] or 0)
        if hours > 23 or minutes > 59 or seconds > 59:
            raise ValueError(f"not a time of day: {expression!r}")
        return hours * 3600 + minutes * 60 + seconds
    try:
        value = _safe_arithmetic_eval(expression.replace("sunrise", str(sunrise)).replace("sunset", str(sunset)))
    except (SyntaxError, ValueError, ZeroDivisionError) as error:
        raise ValueError(f"not a clock time nor a solar expression: {expression!r}") from error
    return max(0, min(86399, int(value)))


def campaign_centre(campaign: CampaignDefinition) -> tuple[float, float]:
    """The middle of the campaign's ground: the mean of its zones' centres.

    Args:
        campaign: The validated campaign.

    Returns:
        ``(lat, lon)``.
    """
    points = [zone_position(campaign, zone) for zone in campaign.zones]
    return sum(lat for lat, _ in points) / len(points), sum(lon for _, lon in points) / len(points)


def mission_start(campaign: CampaignDefinition, on: date) -> int:
    """When a mission of the campaign starts on a date, its solar expression computed on the campaign's ground.

    Args:
        campaign: The validated campaign, for its theatre, its zones and its `start_time`.
        on: The mission's date.

    Returns:
        Seconds since midnight, on the theatre's clock.
    """
    lat, lon = campaign_centre(campaign)
    offset = theatre_utc_offset(campaign.theatre, "UTC", on)
    sun = SolarCalculator.get_sun_times(Position(lat, lon, "UTC"), on, offset)
    return start_seconds(campaign.start_time, sun["sunrise"], sun["sunset"])


def mission_date(campaign: CampaignDefinition, state: CampaignState, current: date) -> date:
    """The coming mission's date: the day after the last mission flown.

    Args:
        campaign: The validated campaign, for its `start_date`.
        state: The campaign state the coming mission starts from.
        current: The date the mission folder holds now, the template's.

    Returns:
        The last mission's date plus a day; for the first mission, `start_date` or the template's;
        for a state that recorded no date, the first date plus a day per mission flown.
    """
    flown = [entry["date"] for entry in state.history if entry.get("date")]
    if flown:
        return date.fromisoformat(str(flown[-1])) + timedelta(days=DAYS_BETWEEN_MISSIONS)
    return (campaign.start_date or current) + timedelta(days=DAYS_BETWEEN_MISSIONS * state.mission)


def draw_weather(campaign: CampaignDefinition, mission: int, on: date) -> dict[str, Any]:
    """Draw a mission's weather within ground-visible limits, the same for the same mission.

    Clouds clear, few or scattered, based between 1 500 and 3 500 m; visibility 8 km or more; wind
    from anywhere at 1 to 8 m/s; no rain — DCS rains only under its rainy presets, which are overcast
    —, no fog; a temperature for the season.

    Args:
        campaign: The validated campaign: its name and the mission number seed the draw.
        mission: The mission number.
        on: The mission's date, for the season.

    Returns:
        `set_weather`'s arguments.
    """
    rng = random.Random(f"{campaign.name}/{mission}")
    month = on.month - 1
    if campaign_centre(campaign)[0] < 0:  # the southern hemisphere's summer is in January
        month = (month + 6) % 12
    return {
        "cloud_type": rng.choice(("clear", "few", "few", "scattered")),
        "cloud_height": float(rng.randrange(1500, 3501, 100)),
        "visibility": float(rng.choice((MIN_VISIBILITY, 10000, 10000))),
        "wind_direction": float(rng.randrange(0, 360, 10)),
        "wind_speed": round(rng.uniform(1.0, 8.0), 1),
        "temperature": float(round(_MONTHLY_TEMPERATURE[month] + rng.uniform(-3.0, 3.0))),
        "precipitation": False,
        "fog_enabled": False,
    }


def ground_visible(weather: dict[str, Any]) -> bool:
    """Whether a mission's weather table — the one DCS reads — leaves the ground visible.

    Args:
        weather: The mission's ``weather`` table.

    Returns:
        True when the clouds are clear, few or scattered, the visibility 8 km or more, no fog, no rain.
    """
    clouds = weather.get("clouds") or {}
    preset = clouds.get("preset")
    return (
        (preset is None or preset in _GROUND_VISIBLE_PRESETS)
        and not clouds.get("iprecptns")
        and float((weather.get("visibility") or {}).get("distance", 0)) >= MIN_VISIBILITY
        and not weather.get("enable_fog")
    )


def single_variant(folder: Path) -> None:
    """Make a mission folder build one mission: no `src/versions.yaml`, `pipeline.weather: false`.

    The `pipeline` block is the last of `mission.yaml`: written in the middle, on 2026-10-07, it
    took the two module entries that followed it as its own.

    Args:
        folder: The mission folder.
    """
    (folder / VERSIONS_FILE).unlink(missing_ok=True)
    path = folder / "mission.yaml"
    data = load_yaml(path)
    pipeline = data.pop("pipeline", None)
    if not isinstance(pipeline, dict):
        pipeline = {}
    pipeline["weather"] = False
    data["pipeline"] = pipeline
    save_yaml(path, data)


def set_conditions(campaign: CampaignDefinition, state: CampaignState, folder: Path) -> MissionConditions:
    """Fix the coming mission's date, start time and weather in its folder.

    Args:
        campaign: The validated campaign.
        state: The campaign state the coming mission starts from.
        folder: The mission folder, just created from the template.

    Returns:
        What was written.
    """
    _, content = open_mission(folder)
    stored = content.get("date") or {}
    try:
        current = date(int(stored["Year"]), int(stored["Month"]), int(stored["Day"]))
    except (KeyError, TypeError, ValueError):
        current = date(2016, 6, 1)  # the blank mission's date
    on = mission_date(campaign, state, current)
    start = mission_start(campaign, on)
    weather = draw_weather(campaign, state.mission + 1, on)
    set_mission_date(
        folder, date=on.isoformat(), start_time=f"{start // 3600:02d}:{start % 3600 // 60:02d}:{start % 60:02d}"
    )
    set_weather(folder, **weather)
    single_variant(folder)
    return MissionConditions(date=on, start_time=start, weather=weather)


def folder_date(folder: Path) -> str | None:
    """The date a mission folder holds, ``YYYY-MM-DD``, or ``None`` when it cannot be read.

    Args:
        folder: The mission folder.

    Returns:
        The date, or ``None``.
    """
    try:
        _, content = open_mission(folder)
        stored = content["date"]
        return date(int(stored["Year"]), int(stored["Month"]), int(stored["Day"])).isoformat()
    except (OSError, ValueError, KeyError, TypeError):
        return None
