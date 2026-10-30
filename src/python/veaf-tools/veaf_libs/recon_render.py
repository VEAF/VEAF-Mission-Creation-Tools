"""Turn a raw DCS shot into a reconnaissance photo: the look, the banner and the felt-pen marks.

The look is a contrasted black and white print with grain and a vignette; the banner says the
operation, the target, the heading, the pitch, the target's position in DDM and MGRS, the ground elevation and the
time; a rose gives the heading; and the targets are circled the way an intelligence officer would
with a red felt pen — irregular loops that do not close, a stroke that thickens mid-gesture, a
shaky leader line and a handwritten label.

The marks are placed by projecting each unit's live position through the camera the shot was taken
with (:func:`veaf_libs.dcs_recon.project`), so they land on the vehicles without anyone pointing
at them. Every random choice is seeded by the shot's title, so a re-render draws the same pen.
"""

from __future__ import annotations

import math
import random
from collections.abc import Callable
from datetime import date
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

from veaf_libs.dcs_recon import LiveUnit, camera_of, dominant_type, project
from veaf_libs.dcs_units_data import is_mobile_vehicle_group
from veaf_libs.i18n import t
from veaf_libs.magnetic import grid_heading_to_magnetic, grid_heading_to_true
from veaf_libs.mgrs import target_coordinates

#: The felt pen.
RED = (205, 22, 22)
#: The banner's highlight.
YELLOW = (255, 220, 40)
#: The banner's text.
PAPER = (230, 230, 220)

#: Windows ships these; elsewhere Pillow's own font stands in, at the same size.
_MONO = ("consola.ttf", "DejaVuSansMono.ttf")
_MONO_BOLD = ("consolab.ttf", "DejaVuSansMono-Bold.ttf")
_HAND = ("Inkfree.ttf", "DejaVuSans-Oblique.ttf")

Font = ImageFont.FreeTypeFont | ImageFont.ImageFont


def _font(candidates: tuple[str, ...], size: int) -> Font:
    """Return the first of *candidates* that loads, or Pillow's default font at *size*."""
    for name in candidates:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default(size=size)


def recce_look(image: Image.Image) -> Image.Image:
    """Give a colour shot the look of a reconnaissance print.

    Args:
        image: The raw shot.

    Returns:
        A new RGB image of the same size.
    """
    grey = ImageOps.autocontrast(ImageOps.grayscale(image), cutoff=1)
    grey = grey.filter(ImageFilter.UnsharpMask(radius=2, percent=80, threshold=2))
    width, height = grey.size
    noise = Image.effect_noise((width, height), 22).filter(ImageFilter.GaussianBlur(0.6))
    grey = Image.blend(grey, noise, 0.10)
    vignette = Image.radial_gradient("L").resize((width, height)).point(lambda v: 255 - int(v * 0.55))
    grey = Image.composite(grey, Image.new("L", (width, height), 0), vignette)
    return ImageOps.colorize(grey, black=(12, 14, 10), white=(236, 232, 214))


def felt_ring(
    draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, rng: random.Random
) -> tuple[float, float]:
    """Draw one felt-pen loop around a point: an irregular ellipse overshooting its start.

    Args:
        draw: Where to draw.
        cx: Centre, pixels.
        cy: Centre, pixels.
        radius: Rough radius, pixels.
        rng: The pen's randomness.

    Returns:
        The loop's horizontal and vertical radii.
    """
    rx, ry = radius * rng.uniform(1.05, 1.3), radius * rng.uniform(0.75, 0.95)
    rotation = rng.uniform(-0.5, 0.5)
    phase2, phase3, start = rng.uniform(0, 6.3), rng.uniform(0, 6.3), rng.uniform(0, 6.3)
    overshoot = rng.uniform(0.25, 0.55)
    steps = 90
    points = []
    for i in range(steps + 1):
        angle = start + (2 * math.pi + overshoot) * i / steps
        wobble = 1 + 0.07 * math.sin(2 * angle + phase2) + 0.04 * math.sin(3 * angle + phase3) + 0.06 * i / steps
        x, y = rx * wobble * math.cos(angle), ry * wobble * math.sin(angle)
        points.append(
            (
                cx + x * math.cos(rotation) - y * math.sin(rotation) + rng.uniform(-1, 1),
                cy + x * math.sin(rotation) + y * math.cos(rotation) + rng.uniform(-1, 1),
            )
        )
    for i in range(len(points) - 1):
        # The pen presses hardest in the middle of the gesture.
        draw.line([points[i], points[i + 1]], fill=RED, width=int(5 + 3 * math.sin(math.pi * i / len(points))))
    return rx, ry


def felt_label(
    draw: ImageDraw.ImageDraw,
    start: tuple[float, float],
    end: tuple[float, float],
    text: str,
    rng: random.Random,
    font: Font,
) -> None:
    """Draw a shaky leader from the loop to the label, then the handwritten label.

    Args:
        draw: Where to draw.
        start: Where the leader leaves the loop.
        end: Where the label sits.
        text: The label.
        rng: The pen's randomness.
        font: The handwriting.
    """
    (x0, y0), (x1, y1) = start, end
    steps = 12
    previous = start
    for i in range(1, steps + 1):
        frac = i / steps
        bend = math.sin(math.pi * frac) * rng.uniform(-14, 14)
        current = (x0 + (x1 - x0) * frac + bend, y0 + (y1 - y0) * frac + rng.uniform(-2, 2))
        draw.line([previous, current], fill=RED, width=5)
        previous = current
    width = draw.textlength(text, font=font)
    tx = x1 + 8 if x1 >= x0 else x1 - width - 8
    draw.text((tx + 2, y1 - 28), text, fill=(255, 255, 255), font=font)  # a light halo, for legibility
    draw.text((tx, y1 - 30), text, fill=RED, font=font)


def _units_of(meta: dict[str, Any]) -> list[LiveUnit]:
    """Rebuild the shot's units from its metadata."""
    return [LiveUnit(u["kind"], 0, u["group"], u["type"], u["x"], u["z"], u["alt"]) for u in meta["units"]]


def _label(labels: dict[str, str], key: str, fallback: str) -> str:
    """Return the label whose key *key* starts with, or *fallback*."""
    for prefix, label in labels.items():
        if key.startswith(prefix):
            return label
    return fallback


def marks_of(meta: dict[str, Any], size: tuple[int, int]) -> list[tuple[float, float, float, str]]:
    """Work out where the rings go: ``(x, y, radius, label)`` in the cropped shot's pixels.

    In ``groups`` mode one ring covers each group's projected vehicles; in ``units`` mode one ring
    per vehicle. What projects outside the frame, or behind the camera, is not marked, and neither is a
    group of vehicles that move about — tanks, armour, trucks: the photo shows their zone, not where
    each one stood (David, FIX-MARTEAU-PLAY-FINDINGS 07).

    Args:
        meta: The shot's metadata.
        size: The cropped shot's ``(width, height)``.

    Returns:
        The marks, top of the frame first.
    """
    camera = camera_of(meta)
    window = meta["window"]
    width, height = size
    labels: dict[str, str] = meta.get("labels") or {}

    def inside(point: tuple[float, float] | None) -> bool:
        return point is not None and 0 <= point[0] < width and 0 <= point[1] < height

    units = _units_of(meta)
    types: dict[str, list[str]] = {}
    for unit in units:
        types.setdefault(unit.group, []).append(unit.type)
    projected: dict[str, list[tuple[LiveUnit, tuple[float, float]]]] = {}
    for unit in units:
        # a vehicle placed as a static does not move: it is ringed like any target
        if unit.kind == "unit" and is_mobile_vehicle_group(types[unit.group]):
            continue
        point = project(camera, unit.x, unit.z, unit.alt, window["width"], window["height"])
        if point is not None and inside(point):
            projected.setdefault(unit.group, []).append((unit, point))

    marks: list[tuple[float, float, float, str]] = []
    for group, members in projected.items():
        if meta.get("mark") == "units":
            for unit, (px, py) in members:
                marks.append((px, py, 30.0, _label(labels, unit.type, unit.type)))
            continue
        xs, ys = [p[0] for _, p in members], [p[1] for _, p in members]
        radius = max(max(xs) - min(xs), max(ys) - min(ys)) / 2 + 36
        label = _label(labels, group, dominant_type([u for u, _ in members]))
        marks.append(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, radius, label))
    return sorted(marks, key=lambda m: m[1])


def annotate(image: Image.Image, meta: dict[str, Any]) -> int:
    """Circle and label the shot's targets in red felt pen.

    Args:
        image: The shot, cropped; drawn on in place.
        meta: Its metadata.

    Returns:
        How many marks were drawn.
    """
    draw = ImageDraw.Draw(image)
    width = image.size[0]
    rng = random.Random(meta["title"])
    hand = _font(_HAND, 50)
    placed: list[tuple[float, float]] = []
    marks = marks_of(meta, image.size)
    for px, py, radius, text in marks:
        rx, ry = felt_ring(draw, px, py, radius, rng)
        side = 1 if px < width * 0.7 else -1
        lx, ly = px + side * (rx + 90), py - ry - 60
        while any(abs(ly - q) < 60 and abs(lx - p) < 420 for p, q in placed):
            ly -= 64
        placed.append((lx, ly))
        felt_label(draw, (px + side * rx * 0.7, py - ry * 0.7), (lx, ly), text, rng, hand)
    return len(marks)


def shot_headings(meta: dict[str, Any]) -> tuple[int, float]:
    """A shot's heading as the banner prints it, magnetic, and true, for the rose's north (the maps' north).

    The camera's heading is on the mission's grid, as DCS holds a camera: taken where the camera stands,
    at the mission's date.

    Args:
        meta: The shot's metadata (``shot_metadata``).

    Returns:
        ``(magnetic, true)``, degrees.
    """
    camera = meta["camera"]["position"]
    at = (camera[0], camera[2])
    when = date.fromisoformat(meta["date"])
    heading = meta["heading_deg"]
    return (
        grid_heading_to_magnetic(meta["theatre"], when, at, heading),
        grid_heading_to_true(meta["theatre"], at, heading),
    )


def frame(image: Image.Image, meta: dict[str, Any], operation: str, index: int, total: int) -> Image.Image:
    """Put the banner, the corner marks and the heading rose around a shot.

    Args:
        image: The annotated shot.
        meta: Its metadata.
        operation: The operation's name.
        index: The shot's number, from 1.
        total: How many shots there are.

    Returns:
        A new, taller image.
    """
    width, height = image.size
    top, bottom = 70, 166
    magnetic, true = shot_headings(meta)
    out = Image.new("RGB", (width, height + top + bottom), (8, 8, 8))
    out.paste(image, (0, top))
    draw = ImageDraw.Draw(out)
    mono, bold = _font(_MONO, 30), _font(_MONO_BOLD, 34)
    header = t("recon.banner.header", operation=operation.upper()) if operation else t("recon.banner.header_bare")
    draw.text((24, 18), header, fill=PAPER, font=bold)
    draw.text((width - 330, 18), f"FRAME {index:02d}/{total:02d}", fill=PAPER, font=bold)

    target = meta["target"]
    # a target's position is DDM and MGRS, never DMS (FIX-MARTEAU-PLAY-FINDINGS 04)
    position, grid = target_coordinates(target["lat"], target["lon"]) if target.get("lat") is not None else ("", "")
    line = t(
        "recon.banner.line",
        heading=f"{magnetic:03d}",
        pitch=f"{meta['pitch_deg']:.0f}",
        position=position,
        elevation=round(target["alt_m"] * 3.281),
        date=meta.get("date", ""),
        time=meta.get("time", ""),
    )
    draw.text((24, height + top + 14), meta["title"].upper(), fill=YELLOW, font=_font(_MONO_BOLD, 40))
    draw.text((24, height + top + 70), line, fill=PAPER, font=mono)
    # its own line: beside the DDM it ran past the right edge of a 1920-pixel grab
    draw.text((24, height + top + 112), grid, fill=PAPER, font=mono)

    for x0, y0, sx, sy in (
        (40, top + 40, 1, 1),
        (width - 40, top + 40, -1, 1),
        (40, top + height - 40, 1, -1),
        (width - 40, top + height - 40, -1, -1),
    ):
        draw.line([(x0, y0), (x0 + 70 * sx, y0)], fill=PAPER, width=4)
        draw.line([(x0, y0), (x0, y0 + 70 * sy)], fill=PAPER, width=4)

    # The image's up is the shot's heading, so true north is turned by as much the other way.
    cx, cy, length = width - 110, top + 130, 60
    draw.ellipse([cx - 75, cy - 75, cx + 75, cy + 75], outline=PAPER, width=3)
    angle = math.radians(-true)
    nx, ny = cx + length * math.sin(angle), cy - length * math.cos(angle)
    draw.line([(cx, cy), (nx, ny)], fill=YELLOW, width=6)
    draw.text((nx - 10, ny - 20), "N", fill=YELLOW, font=_font(_MONO_BOLD, 34))
    draw.text((cx - 60, cy + 82), f"HDG {magnetic:03d}°M", fill=PAPER, font=_font(_MONO_BOLD, 26))
    return out


def render_shot(
    raw: Path,
    meta: dict[str, Any],
    out: Path,
    operation: str,
    index: int,
    total: int,
    progress: Callable[[str], None] | None = None,
) -> tuple[int, int]:
    """Render one raw shot into its reconnaissance photo.

    Args:
        raw: The raw PNG, cropped of the F11 bar.
        meta: Its metadata.
        out: The JPEG to write.
        operation: The operation's name.
        index: The shot's number, from 1.
        total: How many shots there are.
        progress: Told how many marks were drawn.

    Returns:
        The written image's size.
    """
    image = recce_look(Image.open(raw).convert("RGB"))
    count = annotate(image, meta)
    result = frame(image, meta, operation, index, total)
    out.parent.mkdir(parents=True, exist_ok=True)
    result.save(out, quality=88)
    if progress:
        progress(t("recon.render.marks", name=out.name, count=count))
    return result.size
