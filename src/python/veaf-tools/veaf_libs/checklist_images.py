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

import hashlib
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
        file_names: One embedded file name per progress state, indexed by state.
        files: Mapping of file name to PNG bytes, to embed in the ``.miz``.
    """

    checklist_id: str
    resource_keys: list[str]
    file_names: list[str]
    files: dict[str, bytes]

    def __post_init__(self) -> None:
        """Refuse a mapping that cannot be paired.

        :meth:`resources` indexes ``file_names`` by the position of a key, so two lists of
        different lengths either raise deep inside the caller or — worse — pair a state with
        another state's picture and say nothing. Checked at construction rather than in
        :meth:`resources`, so a wrong object cannot exist to be asked twice (Sourcery, #718).

        Raises:
            ValueError: if there is not exactly one file name per resource key.
        """
        if len(self.file_names) != len(self.resource_keys):
            raise ValueError(
                f"checklist '{self.checklist_id}': {len(self.resource_keys)} resource keys "
                f"but {len(self.file_names)} file names — they are paired by state index"
            )

    @property
    def total_bytes(self) -> int:
        """Total weight the checklist adds to the ``.miz``."""
        return sum(len(payload) for payload in self.files.values())

    def resources(self) -> dict[str, str]:
        """Return the ``mapResource`` entries: resource key → embedded file name.

        Paired by state index rather than by sorting the file names, which would put
        ``…-10…`` between ``…-1…`` and ``…-2…`` and silently pair every state of a
        ten-step-or-longer checklist with the wrong picture.

        Reads :attr:`file_names` rather than rebuilding them: a name carries a digest of its
        own bytes, so it cannot be recomputed from the id and the state alone. Rebuilding it
        here is how ``mapResource`` would come to name a file the archive does not contain —
        and the DCS editor prunes what its resource table does not declare, which is exactly
        the shape ``FIX-COMMUNITY-SOUNDS-PRUNED`` had to repair.

        Returns:
            One entry per progress state.
        """
        return {key: self.file_names[state] for state, key in enumerate(self.resource_keys)}


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


#: Hex characters of the content digest kept in a file name.
#:
#: Eight, i.e. 32 bits, and the reason it is enough is that **the digest is not a global identifier**:
#: the name already carries the checklist id and the state, so a collision would have to be between
#: two *different renderings of the same state of the same checklist*. That population is the handful
#: of times a mission maker edits one step — tens, not millions. At a hundred renderings of one state
#: the birthday probability is around 1e-6, and the consequence is one stale bitmap, which is the bug
#: this already fixes at a millionth of its former rate.
#:
#: Reviewed on #718, where a longer digest was suggested. Left at eight deliberately: lengthening it
#: costs nothing but buys nothing measurable either, and a constant nobody can justify is how the next
#: reader loses the reasoning.
_DIGEST_LENGTH = 8


def image_filename(checklist_id: str, state: int, payload: bytes) -> str:
    """Return the ``.miz`` file name of one progress state, digest included.

    **DCS caches embedded resources by name.** During the first checklist flight the picture for
    state 0 showed raw i18n keys while every later state was translated: the ``.miz`` was innocent —
    all seven PNGs matched a fresh render byte for byte — but state 0 was the only one already
    *displayed* under an earlier, untranslated build, so DCS served its cached bitmap. Only a full
    restart cleared it.

    The symptom, *"the text is wrong, but only on the first image"*, points nowhere near the cause,
    and it hits any mission maker iterating on a checklist. Naming the file after its content means
    a changed picture cannot arrive under a name DCS already holds.

    The **resource key** deliberately carries no digest (see :func:`resource_key`): it is the stable
    handle the emitted Lua asks for, so editing a label must not change the mission's scripts.

    Args:
        checklist_id: The checklist id.
        state: Number of steps already ticked (``0`` … ``len(steps)``).
        payload: The rendered PNG bytes this name identifies.

    Returns:
        The file name.
    """
    digest = hashlib.sha256(payload).hexdigest()[:_DIGEST_LENGTH]
    return f"assist-{checklist_id}-{state}-{digest}.png"


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
    names: list[str] = []
    for state in range(len(checklist.steps) + 1):
        payload = _encode(render_state(title, labels, state))
        name = image_filename(checklist.id, state, payload)
        files[name] = payload
        names.append(name)
        keys.append(resource_key(checklist.id, state))
    return ChecklistImages(checklist_id=checklist.id, resource_keys=keys, file_names=names, files=files)


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
