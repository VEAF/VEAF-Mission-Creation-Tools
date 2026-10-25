"""A one-shot mission's briefing as kneeboard pages (FIX-COWORK-SESSION-FINDINGS ticket 08).

What a pilot wants on the knee rather than in the deck: the overview, one zoom per objective, a flight
card (each point, the heading and distance to reach it, the highest ground on the way, the frequencies)
and the targets' coordinates. JPEG, in the folder every aircraft shows (``KNEEBOARD/IMAGES/``).

DCS stretches a kneeboard image onto the whole page without keeping its proportions, and the page is
2:3 (`presets_manager.KNEEBOARD_PAGE_SIZE`, measured 2026-10-18): every page is drawn at exactly that
size, and a map is fitted inside it, never stretched.
"""

from __future__ import annotations

import io
import math
import re
from pathlib import Path

from campaign_manager.mission_pages import line, mhz
from campaign_manager.mission_picture import NM, FlightPlan
from campaign_manager.strategic_map import _font
from PIL import Image, ImageDraw, ImageFont
from presets_injector.presets_manager import KNEEBOARD_PAGE_SIZE
from veaf_libs.coordinates import to_dms, xy_to_latlon
from veaf_libs.i18n import t
from veaf_libs.terrain_elevation import grid_for_theatre, metres_to_feet, profile

from mission_briefing.models import ObjectiveArea, RadioPlan

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
            rows.append((heading, True))
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


def flight_card_blocks(
    theatre: str,
    plans: list[FlightPlan],
    departures: list[tuple[str, float, float]],
    radios: list[RadioPlan],
) -> list[TextBlock]:
    """The flight card: each route's points with the leg that reaches them, then the radios.

    Args:
        theatre: The mission's theatre.
        plans: The players' routes, as the built mission carries them.
        departures: The airfields the players take off from, ``(name, x, y)``; a route leaves from the
            one nearest its first point.
        radios: The presets in the cockpits.

    Returns:
        One block per route, one per radio.
    """
    grid = grid_for_theatre(theatre)
    blocks: list[TextBlock] = []
    for plan in plans:
        points = [(wp.name, wp.x, wp.y) for wp in plan.waypoints]
        if departures and points:
            points.insert(0, min(departures, key=lambda d: math.dist(d[1:], points[0][1:])))
        legs = profile(grid, [(x, y) for _, x, y in points]) if grid and len(points) > 1 else []
        lines = [line(points[0][0], to_dms(*xy_to_latlon(theatre, *points[0][1:])))] if departures else []
        offset = 1 if departures else 0
        for index, (name, x, y) in enumerate(points[offset:], 1):
            lines.append(f"W{index}. " + line(name, to_dms(*xy_to_latlon(theatre, x, y))))
            position = index - 1 + offset
            if position == 0:
                continue
            px, py = points[position - 1][1:]
            heading = round(math.degrees(math.atan2(y - py, x - px))) % 360 or 360
            leg = t("mission_briefing.kneeboard.leg", heading=f"{heading:03d}", nm=round(math.dist((px, py), (x, y)) / NM))
            highest = legs[position - 1].highest if legs else None
            if highest is not None:
                leg += " — " + t("mission_briefing.kneeboard.floor", feet=round(metres_to_feet(highest)))
            lines.append(f"      {leg}")
        blocks.append((", ".join(plan.aircraft) or None, lines))
    for radio in radios:
        lines = [
            f"{channel:>2}  {name or '—'}  {mhz(frequency)}" for channel, name, frequency in radio.channels
        ]
        blocks.append((t("mission_briefing.radio", radio=radio.radio, flights=", ".join(radio.flights)), lines))
    return blocks


def targets_blocks(theatre: str, objectives: list[tuple[str, ObjectiveArea]]) -> list[TextBlock]:
    """Each objective's targets, with their coordinates and, when the theatre has a grid, elevation.

    Args:
        theatre: The mission's theatre.
        objectives: Each objective's title and zone.

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
        blocks.append((title, lines or [t("mission_briefing.no_target")]))
    return blocks

