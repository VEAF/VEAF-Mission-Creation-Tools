"""Placing a map's labels so that none covers another, or a symbol.

The Kolkhida mission briefing's prototype needed two rendering rounds to move the QRA label and the
bullseye label off Poti's (FEAT-CAMPAIGN-MISSION-BRIEFING ticket 03), and the Open Training missions
tuned theirs by eye, one exception per mission (FEAT-BRIEFING-MAP). Here a label tries the places
around what it names, nearest first, and takes the first one free; a symbol reserves its place before
any label is set.
"""

from __future__ import annotations

from dataclasses import dataclass, field

#: A rectangle in pixels: left, top, right, bottom.
Box = tuple[float, float, float, float]

#: The places around an anchor a label tries, nearest first: right, left, above, below, then the corners.
_SIDES: tuple[tuple[float, float], ...] = ((1, 0), (-1, 0), (0, -1), (0, 1), (1, -1), (-1, -1), (1, 1), (-1, 1))

#: How far from its anchor a label may go, in multiples of the gap, before it settles for the least overlap.
_DISTANCES: tuple[int, ...] = (1, 3, 6, 10)


def intersects(a: Box, b: Box) -> bool:
    """Whether two boxes overlap, touching edges excluded.

    Args:
        a: A box.
        b: Another.

    Returns:
        True when they share some area.
    """
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def _overlap(a: Box, b: Box) -> float:
    return max(0.0, min(a[2], b[2]) - max(a[0], b[0])) * max(0.0, min(a[3], b[3]) - max(a[1], b[1]))


@dataclass
class LabelPlacer:
    """Places labels on a picture, each clear of the labels and symbols already there."""

    width: float
    height: float
    gap: float = 6.0
    """Pixels between a label and what it names."""
    taken: list[Box] = field(default_factory=list)
    """Every symbol and label placed so far."""
    labels: list[Box] = field(default_factory=list)
    """The labels placed so far."""

    def reserve(self, box: Box) -> None:
        """Keep a symbol's place clear of labels.

        Args:
            box: The symbol's box.
        """
        self.taken.append(box)

    def place(self, anchor: Box, size: tuple[float, float]) -> tuple[float, float]:
        """Find a free place for a label beside what it names, and keep it.

        Args:
            anchor: The box of what the label names: a symbol, a circle.
            size: The label's width and height, its background included.

        Returns:
            The label's top-left corner.
        """
        width, height = size
        centre_x, centre_y = (anchor[0] + anchor[2]) / 2, (anchor[1] + anchor[3]) / 2
        best: tuple[float, Box] | None = None
        for distance in _DISTANCES:
            gap = self.gap * distance
            for dx, dy in _SIDES:
                left = anchor[2] + gap if dx > 0 else anchor[0] - gap - width if dx < 0 else centre_x - width / 2
                top = anchor[3] + gap if dy > 0 else anchor[1] - gap - height if dy < 0 else centre_y - height / 2
                box = (left, top, left + width, top + height)
                outside = box[0] < 0 or box[1] < 0 or box[2] > self.width or box[3] > self.height
                cost = sum(_overlap(box, other) for other in self.taken) + (1e9 if outside else 0.0)
                if cost == 0:
                    return self._keep(box)
                if best is None or cost < best[0]:
                    best = (cost, box)
        assert best is not None
        return self._keep(best[1])

    def _keep(self, box: Box) -> tuple[float, float]:
        self.taken.append(box)
        self.labels.append(box)
        return box[0], box[1]
