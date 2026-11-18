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
from collections import Counter
from collections.abc import Callable
from datetime import date
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

from veaf_libs.dcs_recon import LiveUnit, camera_of, dominant_type, project
from veaf_libs.dcs_units_data import get_unit_attributes
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


#: The categories a group is labelled with, highest priority first: ``(i18n key, test on the DCS attributes)``.
#: David's choice for the Open Training photos (2026-11-17): plural categories a pilot reads at a glance.
CATEGORIES: tuple[tuple[str, Callable[[frozenset[str]], bool]], ...] = (
    ("long_range_sam", lambda a: "LR SAM" in a),
    ("medium_range_sam", lambda a: "MR SAM" in a),
    ("short_range_sam", lambda a: bool(a & {"SR SAM", "IR Guided SAM", "MANPADS", "AAA", "SAM", "SAM LL", "SAM TR"})),
    ("ewr", lambda a: "EWR" in a),
    ("ss_missile", lambda a: "SS_missile" in a),
    ("artillery", lambda a: bool(a & {"Artillery", "Indirect fire", "MLRS"})),
    ("heavy_armor", lambda a: bool(a & {"HeavyArmoredUnits", "Tanks"}) and "Ground Units" in a),
    ("light_armor", lambda a: bool(a & {"LightArmoredUnits", "IFV", "APC"}) and "Ground Units" in a),
    ("infantry", lambda a: "Infantry" in a),
    ("logistics", lambda a: bool(a & {"Trucks", "Unarmed vehicles", "Cars"})),
    ("armed_ships", lambda a: bool(a & {"Armed ships", "Armed Ship"})),
    ("ships", lambda a: "Ships" in a),
)
#: Categories that name a site by its best element: a SA-6 battery is one radar and more launchers, and
#: its launchers alone read short-range.
_SITE_CATEGORIES = frozenset({"long_range_sam", "medium_range_sam"})
#: Pixels between two rings of the same label below which they are drawn as one, and the largest radius
#: such a merged ring may reach (Open Training, 2026-11-17).
MERGE_PX = 260.0
MAX_MERGED_RADIUS_PX = 330.0


def category_of(unit_type: str) -> tuple[int, str | None]:
    """Return a unit type's category: ``(rank, key)``, rank 0 first, ``key`` ``None`` when none fits."""
    attributes = get_unit_attributes(unit_type)
    for rank, (key, test) in enumerate(CATEGORIES):
        if test(attributes):
            return rank, key
    return len(CATEGORIES), None


def group_label(units: list[LiveUnit]) -> str:
    """Label a group by its category, in the plural.

    A long- or medium-range air defence element names the site; otherwise the most frequent category, a
    tie going to the higher priority. A static no category fits is a target; a vehicle none fits keeps
    the dominant type's name.

    Args:
        units: The group's units, at least one.

    Returns:
        The label, in the current language.
    """
    counts: Counter[tuple[int, str | None]] = Counter(category_of(u.type) for u in units)
    sites = sorted(c for c in counts if c[1] in _SITE_CATEGORIES)
    _, key = sites[0] if sites else max(counts.items(), key=lambda kv: (kv[1], -kv[0][0]))[0]
    if key is None:
        return t("recon.category.targets") if all(u.kind == "static" for u in units) else dominant_type(units)
    return t(f"recon.category.{key}")


def _ring(points: list[tuple[float, float]], margin: float) -> tuple[float, float, float]:
    """The centre and radius of a ring around *points*, *margin* pixels clear of them."""
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    return (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, max(max(xs) - min(xs), max(ys) - min(ys)) / 2 + margin


def merge_marks(marks: list[tuple[float, float, float, str]]) -> list[tuple[float, float, float, str]]:
    """Draw rings of the same label close to one another as one, so that their labels do not pile up.

    A ring joins a cluster when it comes within :data:`MERGE_PX` of one of its rings and the cluster's
    ring stays within :data:`MAX_MERGED_RADIUS_PX`.

    Args:
        marks: ``(x, y, radius, label)``.

    Returns:
        The merged marks, top of the frame first.
    """
    clusters: list[tuple[str, list[tuple[float, float, float]]]] = []

    def bounds(rings: list[tuple[float, float, float]]) -> tuple[float, float, float]:
        x0, x1 = min(x - r for x, _, r in rings), max(x + r for x, _, r in rings)
        y0, y1 = min(y - r for _, y, r in rings), max(y + r for _, y, r in rings)
        return (x0 + x1) / 2, (y0 + y1) / 2, max(x1 - x0, y1 - y0) / 2

    for x, y, radius, label in marks:
        for name, rings in clusters:
            near = any(math.hypot(x - a, y - b) < MERGE_PX + radius + r for a, b, r in rings)
            if name == label and near and bounds([*rings, (x, y, radius)])[2] <= MAX_MERGED_RADIUS_PX:
                rings.append((x, y, radius))
                break
        else:
            clusters.append((label, [(x, y, radius)]))
    merged = [(*bounds(rings), label) if len(rings) > 1 else (*rings[0], label) for label, rings in clusters]
    return sorted(merged, key=lambda m: m[1])


def marks_of(meta: dict[str, Any], size: tuple[int, int]) -> list[tuple[float, float, float, str]]:
    """Work out where the rings go: ``(x, y, radius, label)`` in the cropped shot's pixels.

    In ``groups`` mode one ring covers each group's projected units, moving vehicles included — their
    positions are read just before the grab (David, 2026-11-17, over FIX-MARTEAU-PLAY-FINDINGS 07) — and
    is labelled by the group's category; a ship gets a ring of its own, the ships of one group sailing
    kilometres apart; a shot of statics only gets a single ring, the target area; and close rings of the
    same label are merged. In ``units`` mode one ring per unit, labelled by type. What projects outside
    the frame, or behind the camera, is not marked. ``labels`` given in the shot win.

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
    projected: list[tuple[LiveUnit, tuple[float, float]]] = []
    for unit in units:
        point = project(camera, unit.x, unit.z, unit.alt, window["width"], window["height"])
        if point is not None and inside(point):
            projected.append((unit, point))

    if meta.get("mark") == "units":
        marks = [(px, py, 30.0, _label(labels, u.type, u.type)) for u, (px, py) in projected]
        return sorted(marks, key=lambda m: m[1])

    if units and all(u.kind == "static" for u in units):
        if not projected:
            return []
        return [(*_ring([p for _, p in projected], 36), t("recon.category.target_area"))]

    groups: dict[str, list[tuple[LiveUnit, tuple[float, float]]]] = {}
    for index, (unit, point) in enumerate(projected):
        is_ship = category_of(unit.type)[1] in ("armed_ships", "ships")
        groups.setdefault(f"{unit.group}\t{index}" if is_ship else unit.group, []).append((unit, point))
    marks = []
    for key, members in groups.items():
        group = key.split("\t")[0]
        label = _label(labels, group, group_label([u for u in units if u.group == group]))
        marks.append((*_ring([p for _, p in members], 36), label))
    return merge_marks(marks)


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
    # the labels already written: their left and right edges and their baseline
    placed: list[tuple[float, float, float]] = []
    marks = marks_of(meta, image.size)
    for px, py, radius, text in marks:
        rx, ry = felt_ring(draw, px, py, radius, rng)
        side = 1 if px < width * 0.7 else -1
        lx, ly = px + side * (rx + 90), py - ry - 60
        # the label's own width, as felt_label lays it out (a guess of 420 px stacked long labels)
        text_width = draw.textlength(text, font=hand)
        left = lx + 8 if side > 0 else lx - text_width - 8
        while any(abs(ly - q) < 60 and left < b + 20 and a < left + text_width + 20 for a, b, q in placed):
            ly -= 64
        placed.append((left, left + text_width, ly))
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
