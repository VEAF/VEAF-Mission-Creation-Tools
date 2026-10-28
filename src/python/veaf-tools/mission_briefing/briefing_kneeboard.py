"""A one-shot mission's briefing as kneeboard pages (FIX-COWORK-SESSION-FINDINGS ticket 08).

What a pilot wants on the knee rather than in the deck: the overview, one zoom per objective, a flight
card (each point, the heading and distance to reach it, the highest ground on the way) and the targets'
coordinates. No radio plan: the build already put the presets in the cockpits (FEAT-OBJECTIVE-BRIEFING-QUALITY 06). JPEG, in the folder every aircraft shows (``KNEEBOARD/IMAGES/``).

DCS stretches a kneeboard image onto the whole page without keeping its proportions, and the page is
2:3 (`presets_manager.KNEEBOARD_PAGE_SIZE`, measured 2026-10-18): every page is drawn at exactly that
size, and a map is fitted inside it, never stretched.
"""

from __future__ import annotations

import io
import math
import re
from dataclasses import dataclass
from pathlib import Path

from campaign_manager.mission_pages import line
from campaign_manager.mission_picture import NM, FlightPlan, Waypoint
from campaign_manager.strategic_map import _font
from PIL import Image, ImageDraw, ImageFont
from presets_injector.presets_manager import KNEEBOARD_PAGE_SIZE
from veaf_libs.coordinates import to_dms, xy_to_latlon
from veaf_libs.i18n import t
from veaf_libs.terrain_elevation import grid_for_theatre, metres_to_feet, profile

from mission_briefing.models import ObjectiveArea

#: The page, pixels: the kneeboard's 2:3, twice ED's 768 px width.
KNEEBOARD_PAGE = KNEEBOARD_PAGE_SIZE

#: Where the pages go, inside the mission: the folder every aircraft's kneeboard shows.
KNEEBOARD_FOLDER = "KNEEBOARD/IMAGES"

#: The aspect a map drawn for the page should have, width over height: the page's own.
MAP_ASPECT = KNEEBOARD_PAGE[0] / KNEEBOARD_PAGE[1]

_MARGIN = 72
_TITLE_SIZE, _HEADING_SIZE, _TEXT_SIZE = 64, 48, 40

#: A page this tool writes: what it may replace or delete on a later run, and nothing else.
_PAGE_NAME = re.compile(r"\d{2}-briefing-[a-z0-9-]+\.jpg")

#: One block of a text page: a heading (or none) and its lines.
TextBlock = tuple[str | None, list[str]]


def page_name(number: int, slug: str) -> str:
    """The file of a page: ``01-briefing-overview.jpg``, sorting after VEAF's ``00-veaf-calibration.png``."""
    return f"{number:02d}-briefing-{slug}.jpg"


def is_kneeboard_page(name: str) -> bool:
    """Whether a file name is one of the pages this tool writes (a bare name, nothing else)."""
    return _PAGE_NAME.fullmatch(name) is not None


def _wrap(text: str, font: ImageFont.FreeTypeFont | ImageFont.ImageFont, width: int) -> list[str]:
    """Cut a line at spaces into lines no wider than ``width`` pixels; a word wider than it stays whole."""
    if not text:
        return [""]
    lines: list[str] = []
    current = ""
    for word in text.split(" "):
        candidate = f"{current} {word}" if current else word
        if current and font.getlength(candidate) > width:
            lines.append(current)
            current = word
        else:
            current = candidate
    return [*lines, current]


def _jpeg(page: Image.Image) -> bytes:
    buffer = io.BytesIO()
    page.convert("RGB").save(buffer, format="JPEG", quality=88)
    return buffer.getvalue()


def _blank(title: str) -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
    """A white page with its title; returns the page, its pen and the first free row."""
    page = Image.new("RGB", KNEEBOARD_PAGE, (255, 255, 255))
    draw = ImageDraw.Draw(page)
    draw.text((_MARGIN, _MARGIN), title, font=_font(_TITLE_SIZE, bold=True), fill=(0, 51, 153))
    return page, draw, _MARGIN + _TITLE_SIZE + 40


def map_page(title: str, png: Path) -> bytes:
    """A map under its title, fitted into the page with its proportions kept.

    Args:
        title: The page's title.
        png: The rendered map.

    Returns:
        The page, JPEG.
    """
    page, _, top = _blank(title)
    width, height = KNEEBOARD_PAGE[0] - 2 * _MARGIN, KNEEBOARD_PAGE[1] - top - _MARGIN
    with Image.open(png) as opened:
        scale = min(width / opened.width, height / opened.height)
        fitted = opened.convert("RGB").resize((round(opened.width * scale), round(opened.height * scale)))
    page.paste(fitted, (_MARGIN + (width - fitted.width) // 2, top + (height - fitted.height) // 2))
    return _jpeg(page)


def photo_page(title: str, photos: list[tuple[Path, str]]) -> bytes:
    """One or two photos one above the other, each with its caption, fitted into the page.

    Args:
        title: The page's title.
        photos: Each photo and its caption.

    Returns:
        The page, JPEG.
    """
    page, draw, top = _blank(title)
    font = _font(_TEXT_SIZE)
    usable = KNEEBOARD_PAGE[0] - 2 * _MARGIN
    room = (KNEEBOARD_PAGE[1] - top - _MARGIN) // max(1, len(photos))
    for index, (image, text) in enumerate(photos):
        lines = _wrap(text, font, usable)
        y = top + index * room
        height = max(room // 2, room - len(lines) * int(_TEXT_SIZE * 1.35) - 40)
        with Image.open(image) as opened:
            scale = min(usable / opened.width, height / opened.height)
            fitted = opened.convert("RGB").resize((round(opened.width * scale), round(opened.height * scale)))
        page.paste(fitted, (_MARGIN + (usable - fitted.width) // 2, y))
        y += fitted.height + 16
        for text_line in lines:
            draw.text((_MARGIN, y), text_line, font=font, fill=(0, 0, 0))
            y += int(_TEXT_SIZE * 1.35)
    return _jpeg(page)


def text_pages(title: str, blocks: list[TextBlock]) -> list[bytes]:
    """Blocks of text on as many pages as they need, the title repeated on each.

    Args:
        title: The pages' title.
        blocks: Each block's heading and lines; a line too long for the page is wrapped.

    Returns:
        The pages, JPEG, at least one.
    """
    heading_font, text_font = _font(_HEADING_SIZE, bold=True), _font(_TEXT_SIZE)
    usable = KNEEBOARD_PAGE[0] - 2 * _MARGIN
    rows: list[tuple[str, bool]] = []
    for heading, lines in blocks:
        if heading:
            rows += [(part, True) for part in _wrap(heading, heading_font, usable)]
        rows += [(part, False) for text in lines for part in _wrap(text, text_font, usable)]
        rows.append(("", False))
    pages: list[bytes] = []
    page, draw, y = _blank(title)
    for text, is_heading in rows:
        size = _HEADING_SIZE if is_heading else _TEXT_SIZE
        if y + size > KNEEBOARD_PAGE[1] - _MARGIN:
            pages.append(_jpeg(page))
            page, draw, y = _blank(title)
            if not text:
                continue
        draw.text((_MARGIN, y), text, font=heading_font if is_heading else text_font, fill=(0, 0, 0))
        y += int(size * 1.35)
    pages.append(_jpeg(page))
    return pages


@dataclass(frozen=True)
class RouteStep:
    """A point of a route and the leg that reaches it."""

    number: int
    """Its waypoint number, the departure being 0."""
    name: str
    x: float
    y: float
    heading: int | None
    """Degrees, from the previous point; ``None`` for the first point of a route with no departure."""
    nm: int | None
    highest_ft: int | None
    """The highest ground on the leg, when the theatre has an elevation grid."""
    waypoint: Waypoint | None
    """``None`` for the departure."""
    origin: str = ""
    """The previous point's name."""


def route_steps(theatre: str, plan: FlightPlan, departures: list[tuple[str, float, float]]) -> list[RouteStep]:
    """A route's points, its departure first when there is one, each with the leg that reaches it.

    Args:
        theatre: The mission's theatre.
        plan: The route, as the built mission carries it.
        departures: The airfields the players take off from, ``(name, x, y)``; a route leaves from the one
            nearest its first point.

    Returns:
        The departure (number 0) then every waypoint.
    """
    points: list[tuple[str, float, float, Waypoint | None]] = [(wp.name, wp.x, wp.y, wp) for wp in plan.waypoints]
    if departures and points:
        name, x, y = min(departures, key=lambda d: math.dist(d[1:], points[0][1:3]))
        points.insert(0, (name, x, y, None))
    grid = grid_for_theatre(theatre)
    legs = profile(grid, [(x, y) for _, x, y, _ in points]) if grid and len(points) > 1 else []
    offset = 0 if departures else 1
    steps = []
    for position, (name, x, y, waypoint) in enumerate(points):
        heading = nm = highest = None
        origin = ""
        if position:
            origin, px, py, _ = points[position - 1]
            heading = round(math.degrees(math.atan2(y - py, x - px))) % 360 or 360
            nm = round(math.dist((px, py), (x, y)) / NM)
            height = legs[position - 1].highest if legs else None
            highest = round(metres_to_feet(height)) if height is not None else None
        steps.append(RouteStep(position + offset, name, x, y, heading, nm, highest, waypoint, origin))
    return steps


def leg_text(step: RouteStep) -> str:
    """``cap 287°, 25 nm — relief le plus haut 3 120 ft``, with what is known."""
    if step.heading is None or step.nm is None:
        return ""
    leg = t("mission_briefing.kneeboard.leg", heading=f"{step.heading:03d}", nm=step.nm)
    if step.highest_ft is not None:
        leg += " — " + t("mission_briefing.kneeboard.floor", feet=step.highest_ft)
    return leg


def flight_card_blocks(
    theatre: str,
    plans: list[FlightPlan],
    departures: list[tuple[str, float, float]],
) -> list[TextBlock]:
    """The flight card: each route's points with the leg that reaches them.

    Args:
        theatre: The mission's theatre.
        plans: The players' routes, as the built mission carries them.
        departures: The airfields the players take off from, ``(name, x, y)``; a route leaves from the
            one nearest its first point.

    Returns:
        One block per route.
    """
    blocks: list[TextBlock] = []
    for plan in plans:
        lines = []
        for step in route_steps(theatre, plan, departures):
            position = line(step.name, to_dms(*xy_to_latlon(theatre, step.x, step.y)))
            lines.append(position if step.waypoint is None else f"W{step.number}. {position}")
            if step.waypoint is not None and step.heading is not None:
                lines.append(f"      {leg_text(step)}")
        blocks.append((", ".join(plan.aircraft) or None, lines))
    return blocks


def targets_blocks(
    theatre: str, objectives: list[tuple[str, ObjectiveArea]], bullseye: tuple[float, float] | None = None
) -> list[TextBlock]:
    """Each objective's targets, with their coordinates and, when the theatre has a grid, elevation.

    Args:
        theatre: The mission's theatre.
        objectives: Each objective's title and zone.
        bullseye: The mission's bullseye: each target then says where it stands from it.

    Returns:
        One block per objective.
    """
    grid = grid_for_theatre(theatre)
    blocks: list[TextBlock] = []
    for title, area in objectives:
        lines = []
        for target in area.targets:
            height = grid.elevation_at(target.x, target.y) if grid else None
            elevation = f" — {metres_to_feet(height):.0f} ft" if height is not None else ""
            lines.append(line(target.name, f"{to_dms(*xy_to_latlon(theatre, target.x, target.y))}{elevation}"))
            if bullseye is not None:
                dx, dy = target.x - bullseye[0], target.y - bullseye[1]
                bearing = round(math.degrees(math.atan2(dy, dx))) % 360
                lines.append(f"      Bullseye {bearing:03d}° / {math.hypot(dx, dy) / NM:.1f} nm")
        blocks.append((title, lines or [t("mission_briefing.no_target")]))
    return blocks
