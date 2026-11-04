"""``mission-check``'s wind check: the briefing's wind against the wind DCS simulates, without DCS.

FEAT-MISSION-WIND-CHECK ticket 05. *Marteau du Golan* (2026-10-31) announced "17 kt au sol, plus fort
en altitude"; DCS flew 24 kt at 10 m above Rosh Pina and 36 kt at 1,000 ft, and the helicopter pilots
met it with no warning. The model (:mod:`veaf_libs.dcs_wind`) gives the simulated wind from the built
``.miz`` alone, so an agent can run this at authoring time.

- **Where**: each player departure (airfield of a ``Client`` group, airfield offering dynamic slots),
  each combat zone of ``veaf-config.lua`` and each point of a player helicopter's route, de-duplicated
  within 5 km; a place whose ground altitude is unknown is said, not guessed.
- **What the texts say**: every wind mention of the briefing texts, in English and French, compared with
  the simulated range at the layer it names (:data:`~veaf_libs.mission_wind.BRIEFING_SPEED_TOLERANCE_KNOTS`,
  :data:`~veaf_libs.mission_wind.BRIEFING_DIRECTION_TOLERANCE_DEG`); a contradiction fails.
- **What helicopters fly into**: the helicopter rule warns; it fails only when the briefing announces
  no wind above the surface.
- **Optional measurement** (``--measure-wind``): ``atmosphere.getWind`` at the same points, through the
  bridge, against the model — how a DCS update that changed ``Weather.dll`` gets caught.
"""

from __future__ import annotations

import json
import math
import re
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from veaf_libs.dcs_airdromes import airfields_for_theatre
from veaf_libs.dcs_wind import MODEL_DCS_VERSION, WindVector, base_wind, surface_wind
from veaf_libs.i18n import t
from veaf_libs.mission_wind import (
    BRIEFING_DIRECTION_TOLERANCE_DEG,
    BRIEFING_SPEED_TOLERANCE_KNOTS,
    FEET,
    HELICOPTER_BAND_TOP_M,
    LAYERS_AGL,
    LAYERS_MSL,
    MEASURE_TOLERANCE_KNOTS,
    SURFACE_LAYER,
    HelicopterPlace,
    has_helicopter_slot,
    helicopter_breaches,
)

#: Two places closer than this are one, m.
_SAME_PLACE_M = 5000.0
#: The "aloft" band a mention without a height names: from 1,000 ft above the ground to FL100, m.
_ALOFT_BAND_M = (1000 * FEET, 10000 * FEET)
#: The "low level" band: the one helicopters fly, m above the ground.
_LOW_LEVEL_BAND_M = (0.0, HELICOPTER_BAND_TOP_M)
#: The step a band is sampled at, m.
_BAND_STEP_M = 50.0

_PLAYER_SKILLS = ("client", "player")


@dataclass(frozen=True)
class WindPlace:
    """A place the wind is described at.

    Attributes:
        name: What it is (``Rosh Pina (departure)``).
        x: Mission ``x`` (north), m.
        y: Mission ``y`` (east), m.
        ground_msl: Its ground altitude, m.
        departure: Whether players take off there — where a METAR or an ATIS gives the surface wind.
    """

    name: str
    x: float
    y: float
    ground_msl: float
    departure: bool = False


@dataclass(frozen=True)
class WindMention:
    """A wind a briefing text announces.

    Attributes:
        source: Which text.
        sentence: The sentence, as written.
        layer: ``surface``, ``aloft``, ``low level``, or a height above the ground in metres.
        knots: The speed announced, or None.
        from_deg: Where it comes from, or None.
    """

    source: str
    sentence: str
    layer: str | float
    knots: float | None = None
    from_deg: float | None = None


@dataclass
class WindReport:
    """What the wind check found: ``(ok, text)`` lines, ``ok`` True, False or ``"warn"``, None to inform."""

    lines: list[tuple[bool | str | None, str]] = field(default_factory=list)


# --------------------------------------------------------------------------------------------------
# Where
# --------------------------------------------------------------------------------------------------


def _listed(table: Any) -> list[Any]:
    if isinstance(table, Mapping):
        return [table[key] for key in sorted(table, key=lambda k: int(k) if str(k).isdigit() else 0)]
    return list(table or [])


def _player_groups(content: Mapping[str, Any], categories: tuple[str, ...]) -> list[dict[str, Any]]:
    groups: list[dict[str, Any]] = []
    for side in (content.get("coalition") or {}).values():
        for country in _listed((side or {}).get("country")):
            for category in categories:
                for group in _listed(((country or {}).get(category) or {}).get("group")):
                    units = _listed(group.get("units"))
                    if any(str(unit.get("skill", "")).lower() in _PLAYER_SKILLS for unit in units):
                        groups.append(group)
    return groups


def combat_zone_names(veaf_config: str) -> list[str]:
    """The trigger zones ``veaf-config.lua`` makes combat zones of.

    Args:
        veaf_config: The text of ``veaf-config.lua``.

    Returns:
        Their names, in order, once each.
    """
    return list(dict.fromkeys(re.findall(r':setMissionEditorZoneName\s*\(\s*"([^"]+)"\s*\)', veaf_config or "")))


def wind_places(
    content: Mapping[str, Any],
    theatre: str | None,
    *,
    veaf_config: str = "",
    dynamic_airfields: list[int] | None = None,
    ground_at: Callable[[float, float], float | None] | None = None,
) -> tuple[list[WindPlace], list[str]]:
    """The places the wind is checked at.

    Args:
        content: The mission table.
        theatre: Its theatre.
        veaf_config: The text of ``veaf-config.lua``, for the combat zones.
        dynamic_airfields: Airdrome ids offering dynamic slots.
        ground_at: The ground's altitude at a mission ``(x, y)``, None when unknown.

    Returns:
        The places, de-duplicated within 5 km, and the names of those whose ground is unknown.
    """
    airfields = {int(a["id"]): a for a in airfields_for_theatre(theatre or "")}
    candidates: list[tuple[str, float, float, float | None, bool]] = []

    def airfield(airdrome_id: int, label: str) -> None:
        found = airfields.get(airdrome_id)
        if found is None:
            return
        x, y = _airfield_xy(theatre, found)
        candidates.append((t(label, airfield=found["name"]), x, y, found.get("elevation"), True))

    for group in _player_groups(content, ("plane", "helicopter")):
        points = _listed((group.get("route") or {}).get("points"))
        if points and points[0].get("airdromeId") is not None:
            airfield(int(points[0]["airdromeId"]), "wind.place_departure")
        elif points:
            x, y = float(points[0].get("x", 0)), float(points[0].get("y", 0))
            ground = ground_at(x, y) if ground_at else None
            candidates.append((t("wind.place_departure", airfield=str(group.get("name", "?"))), x, y, ground, True))
    for airdrome_id in dynamic_airfields or []:
        airfield(int(airdrome_id), "wind.place_departure")
    zones = {str(z.get("name")): z for z in _listed((content.get("triggers") or {}).get("zones"))}
    for name in combat_zone_names(veaf_config):
        zone = zones.get(name)
        if zone is not None:
            x, y = float(zone.get("x", 0)), float(zone.get("y", 0))
            candidates.append((t("wind.place_zone", zone=name), x, y, ground_at(x, y) if ground_at else None, False))
    for group in _player_groups(content, ("helicopter",)):
        for index, point in enumerate(_listed((group.get("route") or {}).get("points"))):
            if index and point.get("x") is not None:
                x, y = float(point["x"]), float(point["y"])
                label = t("wind.place_waypoint", group=str(group.get("name", "?")), index=index)
                candidates.append((label, x, y, ground_at(x, y) if ground_at else None, False))

    places: list[WindPlace] = []
    unknown: list[str] = []
    for name, x, y, ground, departure in candidates:
        if any(math.hypot(x - p.x, y - p.y) < _SAME_PLACE_M for p in places):
            continue
        if ground is None:
            unknown.append(name)
            continue
        places.append(WindPlace(name, x, y, float(ground), departure))
    return places, unknown


def _airfield_xy(theatre: str | None, airfield: Mapping[str, Any]) -> tuple[float, float]:
    """An airfield's mission ``(x, y)``."""
    from veaf_libs.coordinates import latlon_to_xy  # noqa: PLC0415

    return latlon_to_xy(theatre or "", float(airfield["lat"]), float(airfield["lon"]))


# --------------------------------------------------------------------------------------------------
# What the texts announce
# --------------------------------------------------------------------------------------------------

_WIND_WORD = re.compile(r"\b(?:wind|winds|vent|vents)\b", re.IGNORECASE)
_SPEED_UNIT = r"(?:kt|kts|knots?|nœuds?|noeuds?|nds)"
#: ``270/17``, ``270° / 17 kt``, ``270°/17kt``.
_DIR_SLASH_SPEED = re.compile(r"\b(\d{3})\s*°?\s*[/]\s*(\d{1,2})\s*" + _SPEED_UNIT + r"?(?![\d/])", re.IGNORECASE)
#: ``270° 17 kt``, ``270° à 17 kt``, ``du 270 pour 17 nœuds``, ``from 270 at 17 kt``.
_DIR_THEN_SPEED = re.compile(
    r"\b(\d{3})\s*°?\s*(?:,|at|à|a|pour|for)?\s*(\d{1,2})\s*" + _SPEED_UNIT + r"\b", re.IGNORECASE
)
_SPEED = re.compile(r"\b(\d{1,2})\s*" + _SPEED_UNIT + r"(?=\W|$)", re.IGNORECASE)
_FROM_DIR = re.compile(r"\b(?:from|du|de)\s+(?:the\s+|l')?(\d{3})\b", re.IGNORECASE)
_CARDINALS = {
    "north": 0,
    "nord": 0,
    "north-east": 45,
    "northeast": 45,
    "nord-est": 45,
    "east": 90,
    "est": 90,
    "south-east": 135,
    "southeast": 135,
    "sud-est": 135,
    "south": 180,
    "sud": 180,
    "south-west": 225,
    "southwest": 225,
    "sud-ouest": 225,
    "west": 270,
    "ouest": 270,
    "north-west": 315,
    "northwest": 315,
    "nord-ouest": 315,
}
_FROM_CARDINAL = re.compile(
    r"\b(?:from the|du|d'|de l')\s*(" + "|".join(sorted(_CARDINALS, key=len, reverse=True)) + r")\b",
    re.IGNORECASE,
)
_HEIGHT = re.compile(r"\b(\d{1,2}[\s ,.]?\d{3}|\d{3,5})\s*(?:ft|feet|pieds)\b", re.IGNORECASE)
_SURFACE = re.compile(r"\b(?:au sol|surface|at the ground|on the ground|ground wind|vent au sol|en surface)\b", re.I)
_LOW_LEVEL = re.compile(r"\b(?:low level|basse altitude|bas niveau|couche basse|low layer)\b", re.IGNORECASE)
_ALOFT = re.compile(r"\b(?:aloft|en altitude|altitude|in altitude|upper|plus haut)\b", re.IGNORECASE)


def _sentences(text: str) -> list[str]:
    return [s.strip() for s in re.split(r"(?<=[.!?;])\s+|\n+", text or "") if s.strip()]


def _clauses(sentence: str) -> list[str]:
    """A sentence split where a new wind statement starts (``17 kt au sol, plus fort en altitude``)."""
    return [c.strip() for c in re.split(r",\s+|\s+(?:and|et|mais|but)\s+", sentence) if c.strip()]


def _layer_of(clause: str) -> str | float:
    height = _HEIGHT.search(clause)
    if height:
        return float(re.sub(r"\D", "", height.group(1))) * FEET
    if _LOW_LEVEL.search(clause):
        return "low level"
    if _SURFACE.search(clause):
        return SURFACE_LAYER
    if _ALOFT.search(clause):
        return "aloft"
    return SURFACE_LAYER


def extract_wind_mentions(text: str, source: str) -> list[WindMention]:
    """Every wind a text announces, in English or French.

    A sentence counts when it says "wind" / "vent", or writes a wind the METAR way (``270/17``). Each
    clause of it with a speed is one mention; a clause naming a layer without a figure ("plus fort en
    altitude") is a mention without a speed — listed, not judged.

    Args:
        text: The text.
        source: Which text it is, for the report.

    Returns:
        The mentions, in reading order.
    """
    mentions: list[WindMention] = []
    for sentence in _sentences(text):
        if not _WIND_WORD.search(sentence) and not _DIR_SLASH_SPEED.search(sentence):
            continue
        sentence_from = _FROM_DIR.search(sentence)
        cardinal = _FROM_CARDINAL.search(sentence)
        default_from = (
            float(sentence_from.group(1))
            if sentence_from
            else float(_CARDINALS[cardinal.group(1).lower()])
            if cardinal
            else None
        )
        found = False
        for clause in _clauses(sentence):
            layer = _layer_of(clause)
            paired = _DIR_SLASH_SPEED.search(clause) or _DIR_THEN_SPEED.search(clause)
            if paired:
                mentions.append(WindMention(source, sentence, layer, float(paired.group(2)), float(paired.group(1))))
                found = True
                continue
            speed = _SPEED.search(clause)
            if speed:
                mentions.append(WindMention(source, sentence, layer, float(speed.group(1)), default_from))
                found = True
            elif layer != SURFACE_LAYER and (
                found or _WIND_WORD.search(clause) or "fort" in clause or "strong" in clause
            ):
                mentions.append(WindMention(source, sentence, layer))
        if not found and not any(m.sentence == sentence for m in mentions):
            mentions.append(WindMention(source, sentence, _layer_of(sentence)))
    return mentions


def briefing_texts(
    content: Mapping[str, Any], dictionary: Mapping[str, Any] | None, folder: Path | None
) -> dict[str, str]:
    """The texts a briefing is made of.

    The kneeboard pages are images drawn from these same words and the same ``.miz`` by
    ``build_mission_briefing``: checking the deck covers them.

    Args:
        content: The mission table.
        dictionary: The mission's ``l10n/DEFAULT/dictionary``, for a ``DictKey_…`` text.
        folder: The mission folder, for ``docs/briefing-contenu.md`` and ``docs/briefing.pptx``.

    Returns:
        Text name to text, for those that exist.
    """
    texts: dict[str, str] = {}
    for key in ("descriptionText", "descriptionBlueTask", "descriptionRedTask"):
        value = content.get(key)
        if isinstance(value, str) and dictionary and value in dictionary:
            value = dictionary[value]
        if isinstance(value, str) and value.strip():
            texts[key] = value
    if folder is not None:
        markdown = folder / "docs" / "briefing-contenu.md"
        if markdown.is_file():
            texts["docs/briefing-contenu.md"] = markdown.read_text(encoding="utf-8")
        deck = folder / "docs" / "briefing.pptx"
        if deck.is_file():
            texts["docs/briefing.pptx"] = _deck_text(deck)
    return texts


def _deck_text(path: Path) -> str:
    """Every paragraph of a ``.pptx``, one per line."""
    from pptx import Presentation  # noqa: PLC0415

    lines: list[str] = []
    for slide in Presentation(str(path)).slides:
        for shape in slide.shapes:
            if shape.has_text_frame:
                lines += [p.text for p in shape.text_frame.paragraphs if p.text.strip()]
    return "\n".join(lines)


# --------------------------------------------------------------------------------------------------
# The judgement
# --------------------------------------------------------------------------------------------------


def _band(layer: str | float) -> tuple[float, float]:
    """The heights above the ground a mention's layer names, m."""
    if isinstance(layer, float):
        return layer, layer
    if layer == "low level":
        return _LOW_LEVEL_BAND_M
    if layer == "aloft":
        return _ALOFT_BAND_M
    return 10.0, 10.0


def simulated_range(setting: Mapping[str, Any], places: list[WindPlace], layer: str | float) -> list[WindVector]:
    """The simulated winds at a layer, over every place and every height of the band.

    A surface wind is what a METAR or an ATIS reports, at an airfield: it is judged at the departures
    when there are some, every other layer over every place.

    Args:
        setting: The ``.miz``'s ``weather.wind`` table.
        places: Where.
        layer: The mention's layer.

    Returns:
        The winds sampled.
    """
    if layer == SURFACE_LAYER and any(place.departure for place in places):
        places = [place for place in places if place.departure]
    bottom, top = _band(layer)
    winds: list[WindVector] = []
    for place in places:
        height = bottom
        while True:
            if layer == SURFACE_LAYER:
                winds.append(surface_wind(setting, place.ground_msl))
            else:
                winds.append(base_wind(setting, place.ground_msl + height, height))
            if height >= top:
                break
            height = min(top, height + _BAND_STEP_M)
    return winds


def _angle(a: float, b: float) -> float:
    return abs((a - b + 180.0) % 360.0 - 180.0)


def _layer_label(layer: str | float) -> str:
    return f"{layer / FEET:.0f} ft" if isinstance(layer, float) else layer


def check_wind(
    setting: Mapping[str, Any],
    places: list[WindPlace],
    texts: dict[str, str],
    helicopters: list[HelicopterPlace] | None = None,
) -> WindReport:
    """Judge every wind the texts announce against the model, then apply the helicopter rule.

    Args:
        setting: The ``.miz``'s ``weather.wind`` table.
        places: Where the wind is described.
        texts: The briefing texts, by name.
        helicopters: Where helicopters fly; None or empty when the mission has no helicopter slot.

    Returns:
        The lines.
    """
    report = WindReport()
    if not places:
        report.lines.append((None, t("wind.check.no_place")))
        return report
    for place in places:
        wind = surface_wind(setting, place.ground_msl)
        report.lines.append(
            (
                None,
                t(
                    "wind.check.place",
                    place=place.name,
                    direction=f"{round(wind.from_deg) % 360:03d}",
                    knots=round(wind.knots),
                ),
            )
        )
    mentions = [m for name, text in texts.items() for m in extract_wind_mentions(text, name)]
    for mention in mentions:
        label = _layer_label(mention.layer)
        if mention.knots is None:
            report.lines.append((None, t("wind.check.unjudged", source=mention.source, sentence=mention.sentence)))
            continue
        winds = simulated_range(setting, places, mention.layer)
        low, high = min(w.knots for w in winds), max(w.knots for w in winds)
        speed_ok = low - BRIEFING_SPEED_TOLERANCE_KNOTS <= mention.knots <= high + BRIEFING_SPEED_TOLERANCE_KNOTS
        direction_ok = mention.from_deg is None or any(
            _angle(w.from_deg, mention.from_deg) <= BRIEFING_DIRECTION_TOLERANCE_DEG for w in winds if w.knots >= 1
        )
        key = "wind.check.match" if speed_ok and direction_ok else "wind.check.contradicts"
        report.lines.append(
            (
                speed_ok and direction_ok,
                t(
                    key,
                    source=mention.source,
                    sentence=mention.sentence,
                    layer=label,
                    low=round(low),
                    high=round(high),
                    tolerance=round(BRIEFING_SPEED_TOLERANCE_KNOTS),
                    angle=round(BRIEFING_DIRECTION_TOLERANCE_DEG),
                ),
            )
        )
    if helicopters:
        breaches = helicopter_breaches(setting, helicopters)
        announced = any(m.layer != SURFACE_LAYER for m in mentions)
        for breach in breaches:
            report.lines.append(("warn", breach.message()))
        if breaches and not announced:
            report.lines.append((False, t("wind.check.not_announced")))
    if not mentions:
        report.lines.append((None, t("wind.check.no_mention", count=len(texts))))
    return report


def check_built_mission(miz: Path, folder: Path | None = None) -> WindReport:
    """Run the wind check on a built ``.miz``, its mission folder's briefing texts with it.

    Args:
        miz: The built mission.
        folder: Its mission folder, for the approved content and the deck; None when there is none.

    Returns:
        The report.
    """
    from mission_tools.miz_tools import list_members, read_member, read_miz  # noqa: PLC0415

    from veaf_libs.terrain_elevation import grid_for_theatre  # noqa: PLC0415

    mission = read_miz(miz)
    content = mission.mission_content or {}
    theatre = (mission.theatre_content or "").strip() or None
    config_member = "l10n/DEFAULT/veaf-config.lua"
    veaf_config = (
        read_member(miz, config_member).decode("utf-8", "replace") if config_member in list_members(miz) else ""
    )
    airports = (mission.warehouses_content or {}).get("airports") or {}
    dynamic = [int(k) for k, a in airports.items() if isinstance(a, Mapping) and a.get("dynamicSpawn")]
    grid = grid_for_theatre(theatre) if theatre else None
    ground_at = grid.elevation_at if grid else None
    places, unknown = wind_places(
        content, theatre, veaf_config=veaf_config, dynamic_airfields=dynamic, ground_at=ground_at
    )
    setting = (content.get("weather") or {}).get("wind") or {}
    texts = briefing_texts(content, mission.dictionary_content, folder)
    # The places already hold the helicopters' departures and route points, and the objectives.
    helicopters = [HelicopterPlace(p.name, p.ground_msl) for p in places] if has_helicopter_slot(content) else []
    report = check_wind(setting, places, texts, helicopters)
    for name in unknown:
        report.lines.insert(0, (None, t("wind.check.unknown_ground", place=name)))
    if folder is not None and (folder / "docs").is_dir():
        report.lines.append((None, t("wind.check.kneeboard")))
    return report


# --------------------------------------------------------------------------------------------------
# d. The optional measurement in DCS
# --------------------------------------------------------------------------------------------------

#: Heights above the ground the measurement samples at each place, m.
MEASURE_HEIGHTS_M: tuple[float, ...] = tuple(h for _, h in LAYERS_AGL) + (HELICOPTER_BAND_TOP_M,)


def measure_lua(places: list[WindPlace]) -> str:
    """The chunk reading ``atmosphere.getWind`` above each place.

    Each line: ``index<TAB>height<TAB>ground<TAB>vx<TAB>vz``, the ground read from ``land.getHeight``
    so the model is asked at the very point DCS answers for; the first line is DCS's version.

    Args:
        places: Where.

    Returns:
        Lua source.
    """
    points = ", ".join(f"{{{p.x:.1f}, {p.y:.1f}}}" for p in places)
    heights = ", ".join(f"{h:.1f}" for h in MEASURE_HEIGHTS_M)
    msl = ", ".join(f"{a:.1f}" for _, a in LAYERS_MSL)
    return f"""
local out = {{ tostring(_APP_VERSION or "?") }}
local points = {{ {points} }}
local heights = {{ {heights} }}
local levels = {{ {msl} }}
for i, p in ipairs(points) do
  local ground = land.getHeight({{ x = p[1], y = p[2] }})
  local function sample(alt)
    local v = atmosphere.getWind({{ x = p[1], y = alt, z = p[2] }})
    out[#out + 1] = string.format("%d\\t%.2f\\t%.2f\\t%.5f\\t%.5f", i, alt - ground, ground, v.x, v.z)
  end
  for _, h in ipairs(heights) do sample(ground + h) end
  for _, a in ipairs(levels) do if a - ground >= 500 then sample(a) end end
end
return table.concat(out, "\\n")
"""


@dataclass(frozen=True)
class Measurement:
    """One reading of ``atmosphere.getWind``, and the model at the same point.

    Attributes:
        place: Where.
        height_agl: Height above DCS's ground, m.
        ground_msl: DCS's ground there, m.
        measured: What DCS answered.
        model: What the model gives.
    """

    place: str
    height_agl: float
    ground_msl: float
    measured: WindVector
    model: WindVector

    @property
    def gap_knots(self) -> float:
        """The vector difference, knots."""
        return WindVector(self.measured.x - self.model.x, self.measured.z - self.model.z).knots


def parse_measure(text: str, places: list[WindPlace], setting: Mapping[str, Any]) -> tuple[str, list[Measurement]]:
    """Read what :func:`measure_lua` returned, and put the model beside each reading.

    Args:
        text: The chunk's reply.
        places: The places the chunk was made for.
        setting: The ``.miz``'s ``weather.wind`` table.

    Returns:
        DCS's version, and the readings.

    Raises:
        ValueError: A line is not what the chunk writes.
    """
    lines = (text or "").splitlines()
    version = lines[0] if lines else "?"
    readings: list[Measurement] = []
    for line in lines[1:]:
        fields = line.split("\t")
        if len(fields) != 5:
            raise ValueError(f"unexpected wind line from DCS: {line!r}")
        index, height, ground, vx, vz = int(fields[0]), *(float(f) for f in fields[1:])
        model = base_wind(setting, ground + height, height)
        readings.append(Measurement(places[index - 1].name, height, ground, WindVector(vx, vz), model))
    return version, readings


def judge_measure(version: str, readings: list[Measurement]) -> list[tuple[bool, str]]:
    """Compare DCS with the model.

    Args:
        version: DCS's version.
        readings: The readings.

    Returns:
        One line: the model holds, or the worst gap with both versions — DCS has changed its wind.
    """
    if not readings:
        return [(False, t("wind.check.measure_empty"))]
    worst = max(readings, key=lambda r: r.gap_knots)
    if worst.gap_knots <= MEASURE_TOLERANCE_KNOTS:
        return [(True, t("wind.check.measure_ok", count=len(readings), gap=f"{worst.gap_knots:.2f}", version=version))]
    return [
        (
            False,
            t(
                "wind.check.measure_gap",
                place=worst.place,
                height=round(worst.height_agl),
                gap=f"{worst.gap_knots:.1f}",
                tolerance=MEASURE_TOLERANCE_KNOTS,
                version=version,
                model=MODEL_DCS_VERSION,
            ),
        )
    ]


def write_measure(path: Path, version: str, readings: list[Measurement]) -> None:
    """Write the measured table beside the test copy.

    Args:
        path: ``<stem>_CHECK.wind.json``.
        version: DCS's version.
        readings: The readings.
    """
    rows = [
        {
            "place": r.place,
            "height_agl_m": round(r.height_agl, 2),
            "ground_msl_m": round(r.ground_msl, 2),
            "measured": {"from_deg": round(r.measured.from_deg, 2), "knots": round(r.measured.knots, 3)},
            "model": {"from_deg": round(r.model.from_deg, 2), "knots": round(r.model.knots, 3)},
            "gap_knots": round(r.gap_knots, 3),
        }
        for r in readings
    ]
    document = {"dcs_version": version, "model_dcs_version": MODEL_DCS_VERSION, "readings": rows}
    path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
