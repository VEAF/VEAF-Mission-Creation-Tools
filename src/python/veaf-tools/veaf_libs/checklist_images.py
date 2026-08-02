"""Render a guided checklist as one image per progress state.

``a_out_picture_*`` can only show a resource **embedded in the ``.miz``**, so the
checklist cannot be drawn at runtime: the build renders it ahead of time, one PNG per
state — state ``k`` showing the first ``k`` lines ticked, line ``k+1`` current, the rest
pending. A twelve-step checklist is thirteen images.

Progress is therefore linear, and a step the pilot *skipped* looks ticked like any other:
representing "skipped" faithfully would need one image per combination. That exception is
carried by the text channel instead — the image is the dashboard, short messages carry the
events (see the PRD).

Boxes, ticks and the current-step marker are **drawn**, never typed: Arial does not
guarantee ``☐`` or ``✓`` and a missing glyph renders as a blank or a tofu box.
"""

from __future__ import annotations

import io
import re
from dataclasses import dataclass
from typing import cast

from PIL import Image, ImageDraw, ImageFont
from PIL.ImageFont import FreeTypeFont

from veaf_libs.checklists import Checklist, resolve_text
from veaf_libs.i18n import tn
from veaf_libs.logger import logger

#: Width bounds, in pixels. The canvas is sized to its longest line rather than fixed,
#: because ``a_out_picture`` shows trailing empty canvas as trailing empty screen, hiding
#: the cockpit for nothing. Width depends on the labels only, never on the progress state,
#: so the picture does not jump as the pilot advances.
#:
#: The absolute sizes matter: ``a_out_picture``'s ``size`` is a percentage **capped at
#: 100**, so a picture can be shrunk but never enlarged. Whatever legibility is wanted in
#: game has to be rendered in. These values were set after seeing the first version in a
#: cockpit, where it came out unreadable.
MIN_IMAGE_WIDTH = 620
MAX_IMAGE_WIDTH = 1400

_MARGIN = 32
_TITLE_SIZE = 42
_LINE_SIZE = 32
_LINE_HEIGHT = 54
_BOX_SIZE = 28
_MARKER_WIDTH = 18

_BACKGROUND = (255, 255, 255)
_TITLE_COLOR = (0, 0, 0)
_PENDING_COLOR = (60, 60, 60)
_DONE_COLOR = (120, 120, 120)
_CURRENT_COLOR = (0, 0, 0)
_CURRENT_BAND = (255, 235, 150)
#: Ticks are drawn in a colour used nowhere else, which is what lets a test count them
#: by sampling pixels instead of comparing against a golden image that a different font
#: on a different machine would break.
_TICK_COLOR = (0, 140, 0)

#: Progress states of a line, in the order a pilot walks through them.
_DONE, _CURRENT, _PENDING = "done", "current", "pending"

#: Characters kept in a checklist id when it becomes a DCS resource key.
_KEY_SAFE_RE = re.compile(r"[^A-Za-z0-9]+")


@dataclass(frozen=True)
class ChecklistImages:
    """The rendered states of one checklist.

    Attributes:
        checklist_id: The checklist these images belong to.
        resource_keys: One DCS resource key per progress state, indexed by state.
        files: Mapping of file name to PNG bytes, to embed in the ``.miz``.
    """

    checklist_id: str
    resource_keys: list[str]
    files: dict[str, bytes]

    @property
    def total_bytes(self) -> int:
        """Total weight the checklist adds to the ``.miz``."""
        return sum(len(payload) for payload in self.files.values())

    def resources(self) -> dict[str, str]:
        """Return the ``mapResource`` entries: resource key → embedded file name.

        Built by state index rather than by sorting the file names, which would put
        ``…-10.png`` between ``…-1.png`` and ``…-2.png`` and silently pair every state
        of a ten-step-or-longer checklist with the wrong picture.

        Returns:
            One entry per progress state.
        """
        return {key: image_filename(self.checklist_id, state) for state, key in enumerate(self.resource_keys)}


def resource_key(checklist_id: str, state: int) -> str:
    """Return the DCS resource key of one progress state.

    Deterministic, and emitted into the Lua data, so the engine never rebuilds a name by
    string concatenation. Follows the ``VEAF_MapKey_*`` convention the build already uses.

    Args:
        checklist_id: The checklist id.
        state: Number of steps already ticked (``0`` … ``len(steps)``).

    Returns:
        The resource key.
    """
    return f"VEAF_MapKey_Assist_{_KEY_SAFE_RE.sub('_', checklist_id)}_{state}"


def image_filename(checklist_id: str, state: int) -> str:
    """Return the ``.miz`` file name of one progress state."""
    return f"assist-{checklist_id}-{state}.png"


def line_states(step_count: int, state: int) -> list[str]:
    """Return the per-line progress marks of a given state.

    Args:
        step_count: Number of steps in the checklist.
        state: Number of steps already ticked.

    Returns:
        One of ``"done"`` / ``"current"`` / ``"pending"`` per line.
    """
    marks: list[str] = []
    for index in range(step_count):
        if index < state:
            marks.append(_DONE)
        elif index == state:
            marks.append(_CURRENT)
        else:
            marks.append(_PENDING)
    return marks


def _fonts() -> tuple[FreeTypeFont, FreeTypeFont]:
    """Return the (title, line) fonts, falling back to Pillow's default."""
    try:
        return ImageFont.truetype("arial.ttf", _TITLE_SIZE), ImageFont.truetype("arial.ttf", _LINE_SIZE)
    except OSError:
        default = cast(FreeTypeFont, ImageFont.load_default())
        return default, default


def _draw_box(draw: ImageDraw.ImageDraw, left: int, top: int, mark: str) -> None:
    """Draw one line's status box, ticked when the step is done."""
    outline = _DONE_COLOR if mark == _DONE else _PENDING_COLOR
    draw.rectangle([left, top, left + _BOX_SIZE, top + _BOX_SIZE], outline=outline, width=3)
    if mark != _DONE:
        return
    draw.line(
        [
            (left + 6, top + _BOX_SIZE // 2),
            (left + _BOX_SIZE // 2 - 1, top + _BOX_SIZE - 8),
            (left + _BOX_SIZE - 5, top + 6),
        ],
        fill=_TICK_COLOR,
        width=5,
        joint="curve",
    )


def _draw_marker(draw: ImageDraw.ImageDraw, left: int, top: int) -> None:
    """Draw the current-step marker: a filled triangle pointing at the line."""
    middle = top + _BOX_SIZE // 2
    draw.polygon(
        [(left, top + 2), (left + _MARKER_WIDTH, middle), (left, top + _BOX_SIZE - 2)],
        fill=_CURRENT_COLOR,
    )


def _text_width(font: FreeTypeFont, text: str) -> int:
    """Return the pixel width *font* needs for *text*."""
    return int(font.getbbox(text)[2])


def image_width(title: str, labels: list[str]) -> int:
    """Return the canvas width a checklist needs, clamped to the bounds above.

    Args:
        title: Checklist title, already translated.
        labels: Step labels, already translated.

    Returns:
        The width, in pixels.
    """
    title_font, line_font = _fonts()
    text_left = _MARGIN + _MARKER_WIDTH + 10 + _BOX_SIZE + 16
    needed = max(
        [_MARGIN + _text_width(title_font, title)] + [text_left + _text_width(line_font, label) for label in labels]
    )
    return max(MIN_IMAGE_WIDTH, min(MAX_IMAGE_WIDTH, needed + _MARGIN))


def render_state(title: str, labels: list[str], state: int) -> Image.Image:
    """Render one progress state as an RGB image.

    Args:
        title: Checklist title, already translated.
        labels: Step labels, already translated.
        state: Number of steps already ticked.

    Returns:
        The rendered image.
    """
    title_font, line_font = _fonts()
    width = image_width(title, labels)
    height = _MARGIN * 2 + _TITLE_SIZE + 22 + _LINE_HEIGHT * len(labels)
    image = Image.new("RGB", (width, height), color=_BACKGROUND)
    draw = ImageDraw.Draw(image)

    draw.text((_MARGIN, _MARGIN), title, font=title_font, fill=_TITLE_COLOR)
    text_left = _MARGIN + _MARKER_WIDTH + 10 + _BOX_SIZE + 16

    top = _MARGIN + _TITLE_SIZE + 22
    for label, mark in zip(labels, line_states(len(labels), state), strict=True):
        box_left = _MARGIN + _MARKER_WIDTH + 10
        if mark == _CURRENT:
            draw.rectangle([_MARGIN - 6, top - 6, width - _MARGIN + 6, top + _BOX_SIZE + 10], fill=_CURRENT_BAND)
            _draw_marker(draw, _MARGIN, top)
        _draw_box(draw, box_left, top, mark)
        colour = {_DONE: _DONE_COLOR, _CURRENT: _CURRENT_COLOR}.get(mark, _PENDING_COLOR)
        draw.text((text_left, top), label, font=line_font, fill=colour)
        top += _LINE_HEIGHT

    return image


def _encode(image: Image.Image) -> bytes:
    """Encode an image as an indexed PNG.

    Flat text on a plain background needs a handful of colours; an adaptive palette keeps
    a state around 10-20 KB rather than the 100 KB a truecolour PNG would cost, and a
    forty-step checklist proportionally cheap.
    """
    buffer = io.BytesIO()
    image.convert("P", palette=Image.Palette.ADAPTIVE, colors=16).save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def render_checklist_images(
    checklist: Checklist,
    catalog: dict[str, dict[str, str]],
    language: str,
) -> ChecklistImages:
    """Render every progress state of *checklist*.

    Title and labels are resolved through the **runtime** catalogue, in the mission's
    language, so the text baked into the picture matches the messages the pilot reads.

    Args:
        checklist: The checklist to render.
        catalog: The parsed ``veafI18n.lua`` catalogue.
        language: The mission's in-game language.

    Returns:
        One image per progress state, keys and file names included.
    """
    title = resolve_text(checklist.title, catalog, language)
    labels = [resolve_text(step.label, catalog, language) for step in checklist.steps]

    files: dict[str, bytes] = {}
    keys: list[str] = []
    for state in range(len(checklist.steps) + 1):
        files[image_filename(checklist.id, state)] = _encode(render_state(title, labels, state))
        keys.append(resource_key(checklist.id, state))
    return ChecklistImages(checklist_id=checklist.id, resource_keys=keys, files=files)


def render_all(
    checklists: list[Checklist],
    catalog: dict[str, dict[str, str]],
    language: str,
) -> list[ChecklistImages]:
    """Render every activated checklist, reporting what the images cost.

    A mission maker adding a sixty-step checklist should read the price at build time
    rather than discover a fatter ``.miz``.

    Args:
        checklists: The checklists the mission activates.
        catalog: The parsed ``veafI18n.lua`` catalogue.
        language: The mission's in-game language.

    Returns:
        One entry per checklist, in the order given.
    """
    rendered = [render_checklist_images(checklist, catalog, language) for checklist in checklists]
    count = sum(len(entry.files) for entry in rendered)
    if count:
        total_kb = sum(entry.total_bytes for entry in rendered) / 1024
        logger.info(tn("checklist.images_generated", count, n=count, size=f"{total_kb:.0f}"))
    return rendered
