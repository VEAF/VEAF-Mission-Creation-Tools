"""`add_map_drawing` / `edit_map_drawing` — F10 map drawings that survive a rebuild.

Ticket 07 of ``FEAT-MCP-MUTATION-ACTIONS``. Nothing in VMCT touched F10 drawings, so a briefing line,
an ingress corridor or a no-fly box was drawn by hand in the Mission Editor **and lost the moment the
mission was regenerated from its folder**. That is the whole argument for putting it here: a drawing
an agent places is part of the recipe, a hand-drawn one is not.

**The measurement that dominates the design**, read out of this repository's fixtures:

    ``points`` are **relative to the drawing's ``mapX``/``mapY`` anchor**, the first one being
    ``{0, 0}``.

A drawing written in absolute coordinates lands hundreds of kilometres away and **nothing errors** —
the same class of silent failure as confusing the mission table's ``{x=north, y=east}`` with a runtime
vec3 (see ``docs/agents/dcs-coordinates.md``). So these actions take the absolute coordinates a caller
actually has, and do the anchoring themselves. The payoff shows up in ``edit_map_drawing``: moving a
drawing is moving its anchor, and the shape follows for free.

**Three shapes ship because three shapes were measured**:

- ``Line`` — ``points``, plus ``lineMode`` (``segment`` for two points, ``segments`` for a polyline)
  and ``closed`` for a shape that joins up. That last one is how a free-form area gets drawn.
- ``Polygon`` in ``rect`` mode — ``width``/``height``/``angle`` around the anchor, and **no points at
  all**.
- ``TextBox`` — ``text``/``font``/``fontSize``, no points either. The font is taken from a real
  drawing rather than chosen: one DCS does not have renders as nothing.

The other ``polygonMode`` values (``circle``, ``oval``, ``free``, ``arrow``) and
``primitiveType: "Icon"`` are **absent from every fixture in this repository**, so their field shapes
are unknown. The ticket's own rule is to read a real ``.miz`` rather than assume, so they are refused
by name — inventing a field layout here would produce a drawing the editor silently drops, which is
exactly the failure ``FIX-MAPRESOURCE-KEY`` and ``FIX-COMMUNITY-SOUNDS-PRUNED`` already cost. The
measurement is listed in ``DCS-SESSION-TODO.md``.
"""

from pathlib import Path
from typing import Any

from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import read_miz, write_miz

from veaf_mission_mcp.mission_table import indexed, listed

#: The layers DCS ships, measured across the fixtures. A drawing on the wrong one is invisible to the
#: pilots who need it and visible to the ones who should not see it, so the layer is never defaulted.
LAYERS: tuple[str, ...] = ("Red", "Blue", "Neutral", "Common", "Author")

#: Shapes whose field layout was read out of a real mission.
_MEASURED_SHAPES: tuple[str, ...] = ("line", "rect", "textbox")

#: Shapes DCS supports but which appear in no fixture here, so their fields are unknown.
_UNMEASURED_SHAPES: tuple[str, ...] = ("circle", "oval", "free", "arrow", "chevron", "icon")

#: Defaults taken from real drawings rather than invented.
_DEFAULT_COLOR = "0xff0000ff"
_DEFAULT_FILL_COLOR = "0x00000080"
_DEFAULT_FONT = "DejaVuLGCSansCondensed.ttf"
_DEFAULT_FONT_SIZE = 14
_DEFAULT_THICKNESS = 8
_DEFAULT_POLYGON_THICKNESS = 2


def add_map_drawing(
    miz_path: Path,
    *,
    layer: str,
    shape: str,
    name: str,
    points: list[dict[str, float]] | None = None,
    position: dict[str, float] | None = None,
    text: str | None = None,
    width: float | None = None,
    height: float | None = None,
    angle: float = 0,
    closed: bool = False,
    color: str | None = None,
    fill_color: str | None = None,
    thickness: float | None = None,
    font_size: int | None = None,
) -> dict[str, Any]:
    """Add a drawing to one of the mission's F10 map layers, in place, backed up first.

    Args:
        miz_path: Path to the mission's source `.miz`.
        layer: Which coalition sees it — ``Red``, ``Blue``, ``Neutral``, ``Common`` or ``Author``.
            Never defaulted: the wrong layer shows the drawing to the wrong side.
        shape: ``line``, ``rect`` or ``textbox``. Other DCS shapes are refused, their field layout
            being unmeasured.
        name: The drawing's name, which is how it is addressed later. Must be free on that layer.
        points: **Absolute** coordinates for a line, two or more. The anchoring is done here.
        position: **Absolute** anchor for a ``rect`` or a ``textbox``.
        text: The text, for a ``textbox``.
        width: Width in metres, for a ``rect``.
        height: Height in metres, for a ``rect``.
        angle: Rotation, for a ``rect`` or a ``textbox``.
        closed: Whether a line joins back up — how a free-form area is drawn.
        color: Outline colour as DCS's ``0xRRGGBBAA`` string.
        fill_color: Fill colour, for a ``rect`` or a ``textbox``.
        thickness: Outline thickness.
        font_size: Font size, for a ``textbox``.

    Returns:
        ``{layer, name, shape, anchor}``.

    Raises:
        ValueError: If the archive is not a valid mission, the layer or shape is unknown, the name is
            taken on that layer, or the shape's own required parameters are missing.
    """
    _check_layer(layer)
    _check_shape(shape)

    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    objects = _layer_objects(mission.mission_content, layer)
    for existing in objects:
        if isinstance(existing, dict) and str(existing.get("name", "")) == name:
            raise ValueError(
                f"a drawing named {name!r} already exists on layer {layer!r} — edit and remove address "
                "a drawing by name, so a duplicate makes both ambiguous"
            )

    if shape == "line":
        drawing, anchor = _build_line(name, layer, points, closed, color, thickness)
    elif shape == "rect":
        drawing, anchor = _build_rect(name, layer, position, width, height, angle, color, fill_color, thickness)
    else:  # textbox
        drawing, anchor = _build_textbox(name, layer, position, text, angle, color, fill_color, font_size)

    objects.append(drawing)

    backup_before_write(miz_path)
    write_miz(mission, miz_path)

    return {"layer": layer, "name": name, "shape": shape, "anchor": anchor}


def edit_map_drawing(
    miz_path: Path,
    *,
    layer: str,
    name: str,
    new_name: str | None = None,
    position: dict[str, float] | None = None,
    text: str | None = None,
    remove: bool = False,
) -> dict[str, Any]:
    """Move, retitle, rename or remove an existing drawing, in place, backed up first.

    Args:
        miz_path: Path to the mission's source `.miz`.
        layer: The layer the drawing sits on.
        name: Its current name.
        new_name: A new name.
        position: A new **absolute** anchor. Because points are relative, the shape follows.
        text: New text — only for a drawing that has some.
        remove: Delete it.

    Returns:
        ``{layer, name, changed}``.

    Raises:
        ValueError: If the archive is not a valid mission, the layer or drawing does not exist,
            nothing was given, or `text` is set on a drawing that carries none.
    """
    _check_layer(layer)
    if not remove and all(value is None for value in (new_name, position, text)):
        raise ValueError("no change given — pass at least one of new_name, position, text, remove")

    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")

    objects = _layer_objects(mission.mission_content, layer)
    drawing = _find_drawing(objects, layer, name)

    changed: dict[str, Any] = {}
    if remove:
        objects.remove(drawing)
        changed["removed"] = name
    else:
        if position is not None:
            if "x" not in position or "y" not in position:
                raise ValueError(f"position must carry x and y, got {position!r}")
            changed["position"] = {
                "from": {"x": drawing.get("mapX"), "y": drawing.get("mapY")},
                "to": {"x": float(position["x"]), "y": float(position["y"])},
            }
            # Only the anchor moves: `points` are relative to it, so the shape travels for free.
            drawing["mapX"], drawing["mapY"] = float(position["x"]), float(position["y"])
        if text is not None:
            if "text" not in drawing:
                raise ValueError(
                    f"drawing {name!r} carries no text ({drawing.get('primitiveType')}), so there is "
                    "nothing to retitle — only a textbox has text"
                )
            changed["text"] = {"from": drawing.get("text"), "to": text}
            drawing["text"] = text
        if new_name is not None:
            changed["name"] = {"from": drawing.get("name"), "to": new_name}
            drawing["name"] = new_name

    backup_before_write(miz_path)
    write_miz(mission, miz_path)

    return {"layer": layer, "name": new_name or name, "changed": changed}


def _check_layer(layer: str) -> None:
    """Raise unless `layer` is one of the layers DCS ships.

    Args:
        layer: The layer name.

    Raises:
        ValueError: If it is not a real layer.
    """
    if layer not in LAYERS:
        raise ValueError(f"unknown drawing layer {layer!r}; expected one of {', '.join(LAYERS)}")


def _check_shape(shape: str) -> None:
    """Raise unless `shape` is one whose field layout was measured.

    Args:
        shape: The requested shape.

    Raises:
        ValueError: If the shape is unknown, or known to DCS but unmeasured here.
    """
    if shape in _MEASURED_SHAPES:
        return
    if shape in _UNMEASURED_SHAPES:
        raise ValueError(
            f"shape {shape!r} is not measured: DCS supports it, but no mission in this repository "
            f"contains one, so its field layout is unknown and writing a guessed one produces a "
            f"drawing the editor silently drops. Available: {', '.join(_MEASURED_SHAPES)} "
            f"(a closed 'line' draws a free-form area). See DCS-SESSION-TODO.md"
        )
    raise ValueError(f"unknown shape {shape!r}; expected one of {', '.join(_MEASURED_SHAPES)}")


def _layer_objects(mission_content: dict[str, Any], layer: str) -> list[dict[str, Any]]:
    """Return one drawing layer's object list, creating the tables when the mission has none.

    A mission never opened in the editor may carry no ``drawings`` table at all, and a layer with no
    drawings may be absent rather than empty.

    Args:
        mission_content: The parsed ``mission`` table.
        layer: The layer's name.

    Returns:
        The object list, held under that layer's ``objects``.
    """
    drawings = mission_content.setdefault("drawings", {})
    layers = indexed(drawings.get("layers"))
    drawings["layers"] = layers
    for entry in layers:
        if isinstance(entry, dict) and str(entry.get("name", "")) == layer:
            existing: list[dict[str, Any]] = indexed(entry.get("objects"))
            entry["objects"] = existing
            return existing
    fresh: list[dict[str, Any]] = []
    layers.append({"name": layer, "visible": True, "objects": fresh})
    return fresh


def _find_drawing(objects: list[dict[str, Any]], layer: str, name: str) -> dict[str, Any]:
    """Return the drawing named `name` on that layer, or raise naming what the layer holds.

    Args:
        objects: The layer's drawings.
        layer: Its name, for the message.
        name: The drawing to find.

    Returns:
        The drawing table.

    Raises:
        ValueError: If the layer holds no drawing with that name.
    """
    for drawing in objects:
        if isinstance(drawing, dict) and str(drawing.get("name", "")) == name:
            return drawing
    names = [str(drawing.get("name", "")) for drawing in objects if isinstance(drawing, dict)]
    raise ValueError(f"No drawing named {name!r} on layer {layer!r}. That layer holds: {listed(names)}")


def _common_fields(name: str, layer: str, anchor: dict[str, float]) -> dict[str, Any]:
    """Return the fields every measured drawing carries.

    ``layerName`` is written **as well as** the drawing sitting inside that layer, because every real
    drawing carries both and nothing here should be the first to disagree.

    Args:
        name: The drawing's name.
        layer: Its layer.
        anchor: Its absolute anchor.

    Returns:
        The shared field set.
    """
    return {
        "name": name,
        "layerName": layer,
        "mapX": anchor["x"],
        "mapY": anchor["y"],
        "visible": True,
    }


def _build_line(
    name: str,
    layer: str,
    points: list[dict[str, float]] | None,
    closed: bool,
    color: str | None,
    thickness: float | None,
) -> tuple[dict[str, Any], dict[str, float]]:
    """Build a ``Line``, anchoring it on its first point and storing the rest as offsets.

    Args:
        name: The drawing's name.
        layer: Its layer.
        points: Absolute coordinates, two or more.
        closed: Whether the line joins back up.
        color: Outline colour.
        thickness: Outline thickness.

    Returns:
        ``(drawing, anchor)``.

    Raises:
        ValueError: If there are fewer than two points, or one lacks a coordinate.
    """
    if not points or len(points) < 2:
        raise ValueError(f"a line needs at least two points, got {len(points or [])}")
    for number, point in enumerate(points, start=1):
        if not isinstance(point, dict) or "x" not in point or "y" not in point:
            raise ValueError(f"point {number} must be an object with x and y, got {point!r}")

    anchor = {"x": float(points[0]["x"]), "y": float(points[0]["y"])}
    drawing = _common_fields(name, layer, anchor)
    drawing.update(
        {
            "primitiveType": "Line",
            # `segment` for a single leg, `segments` for a polyline — DCS's own spelling, plural.
            "lineMode": "segment" if len(points) == 2 else "segments",
            "closed": closed,
            "style": "solid",
            "colorString": color or _DEFAULT_COLOR,
            "thickness": thickness if thickness is not None else _DEFAULT_THICKNESS,
            "hiddenOnPlanner": False,
            "points": [
                {"x": float(point["x"]) - anchor["x"], "y": float(point["y"]) - anchor["y"]} for point in points
            ],
        }
    )
    return drawing, anchor


def _build_rect(
    name: str,
    layer: str,
    position: dict[str, float] | None,
    width: float | None,
    height: float | None,
    angle: float,
    color: str | None,
    fill_color: str | None,
    thickness: float | None,
) -> tuple[dict[str, Any], dict[str, float]]:
    """Build a ``Polygon`` in ``rect`` mode — dimensions around an anchor, and no point list.

    Args:
        name: The drawing's name.
        layer: Its layer.
        position: Its absolute anchor.
        width: Width in metres.
        height: Height in metres.
        angle: Rotation.
        color: Outline colour.
        fill_color: Fill colour.
        thickness: Outline thickness.

    Returns:
        ``(drawing, anchor)``.

    Raises:
        ValueError: If the anchor or the dimensions are missing.
    """
    anchor = _anchor_from(position, "rect")
    if width is None or height is None:
        raise ValueError("a rect needs width and height, in metres")
    drawing = _common_fields(name, layer, anchor)
    drawing.update(
        {
            "primitiveType": "Polygon",
            "polygonMode": "rect",
            "width": float(width),
            "height": float(height),
            "angle": angle,
            "style": "solid",
            "colorString": color or _DEFAULT_COLOR,
            "fillColorString": fill_color or _DEFAULT_FILL_COLOR,
            "thickness": thickness if thickness is not None else _DEFAULT_POLYGON_THICKNESS,
        }
    )
    return drawing, anchor


def _build_textbox(
    name: str,
    layer: str,
    position: dict[str, float] | None,
    text: str | None,
    angle: float,
    color: str | None,
    fill_color: str | None,
    font_size: int | None,
) -> tuple[dict[str, Any], dict[str, float]]:
    """Build a ``TextBox`` — a label at an anchor, with no point list either.

    Args:
        name: The drawing's name.
        layer: Its layer.
        position: Its absolute anchor.
        text: The label.
        angle: Rotation.
        color: Text colour.
        fill_color: Background colour.
        font_size: Font size.

    Returns:
        ``(drawing, anchor)``.

    Raises:
        ValueError: If the anchor or the text is missing.
    """
    anchor = _anchor_from(position, "textbox")
    if not text:
        raise ValueError("a textbox needs text")
    drawing = _common_fields(name, layer, anchor)
    drawing.update(
        {
            "primitiveType": "TextBox",
            "text": text,
            # Taken from a real drawing rather than chosen: a font DCS lacks renders as nothing.
            "font": _DEFAULT_FONT,
            "fontSize": font_size if font_size is not None else _DEFAULT_FONT_SIZE,
            "angle": angle,
            "borderThickness": 1,
            "colorString": color or _DEFAULT_COLOR,
            "fillColorString": fill_color or _DEFAULT_FILL_COLOR,
        }
    )
    return drawing, anchor


def _anchor_from(position: dict[str, float] | None, shape: str) -> dict[str, float]:
    """Return an absolute anchor from a `position` parameter, or raise naming the shape.

    Args:
        position: The caller's anchor.
        shape: The shape's name, for the message.

    Returns:
        ``{"x": ..., "y": ...}``.

    Raises:
        ValueError: If the position is missing or incomplete.
    """
    if position is None or "x" not in position or "y" not in position:
        raise ValueError(f"a {shape} needs position {{x, y}}")
    return {"x": float(position["x"]), "y": float(position["y"])}
