"""The wave/QRA spawn offset must put latitude on the northing and longitude on the easting.

`veafAirWaves` and `veafQraCore` each apply `[latDelta,lonDelta]` in **two** branches — the VEAF
command one and the DCS group one — so the same arithmetic is written four times. Until 2026-09-01
all four read `x = zoneCenter.x - lonDelta, z = zoneCenter.z + latDelta`: the first bracket number
went east and the second went south, neither where its name says.

The Lua suites assert the resulting direction for the command branch of both modules, which is the
path a mission actually takes. The DCS-group branch only reaches its offset when DCS fails to return
a group's units — a degraded path that is awkward to drive and easy to leave behind, which is exactly
how a swap survives in half the call sites. This test covers all four at once by refusing the shape
itself, so a repair that misses one is caught wherever it sits.

Source-level, deliberately: the defect is a pairing of names to axes, and that pairing is visible in
the text. See `docs/agents/dcs-coordinates.md` for why `x` is the northing and `z` the easting.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[2] / "src" / "scripts" / "veaf"
MODULES = ("veafAirWaves.lua", "veafQraCore.lua")

# An assignment of `x` or `z` built from one of the two deltas, e.g.
#   x = zoneCenter.x - lonDelta,
#   z = zoneCenter.z + self.respawnDefaultOffset.latDelta,
ASSIGNMENT = re.compile(r"\b(?P<axis>[xz])\s*=\s*zoneCenter\.[xz]\s*(?P<sign>[-+])\s*(?P<term>[\w.]*(?:lat|lon)Delta)")

AXIS_FOR = {"lat": "x", "lon": "z"}


def _offending_lines(text: str) -> list[tuple[int, str, str]]:
    """Return `(line number, line, why)` for every offset assignment on the wrong axis or sign.

    Args:
        text: The Lua source to scan.

    Returns:
        One entry per defect found; empty when every assignment is correct.
    """
    defects: list[tuple[int, str, str]] = []
    for number, line in enumerate(text.splitlines(), start=1):
        code = line.split("--", 1)[0]  # the comments quote the old form on purpose
        for match in ASSIGNMENT.finditer(code):
            delta = "lat" if "latDelta" in match.group("term") else "lon"
            expected = AXIS_FOR[delta]
            if match.group("axis") != expected:
                defects.append(
                    (number, line.strip(), f"{delta}Delta belongs on `{expected}`, not `{match.group('axis')}`")
                )
            elif match.group("sign") != "+":
                defects.append((number, line.strip(), f"{delta}Delta must be added, not subtracted"))
    return defects


class TestTheOffsetLandsOnTheRightAxis(unittest.TestCase):
    """`latDelta` moves the northing, `lonDelta` moves the easting, and both are added."""

    def test_no_module_applies_a_delta_to_the_wrong_axis(self) -> None:
        for module in MODULES:
            with self.subTest(module=module):
                path = SCRIPTS / module
                self.assertTrue(path.is_file(), f"{path} is missing")

                defects = _offending_lines(path.read_text(encoding="utf-8"))

                self.assertEqual(
                    defects, [], "\n".join(f"{module}:{number}: {why}\n    {line}" for number, line, why in defects)
                )

    def test_every_module_actually_carries_such_an_assignment(self) -> None:
        # Without this, renaming the fields or the local would leave the check above passing on a
        # file it no longer understands — green because it found nothing to look at.
        for module in MODULES:
            with self.subTest(module=module):
                text = (SCRIPTS / module).read_text(encoding="utf-8")
                found = [m for line in text.splitlines() for m in ASSIGNMENT.finditer(line.split("--", 1)[0])]

                self.assertEqual(len(found), 4, f"{module} should apply both deltas in both of its branches")


if __name__ == "__main__":
    unittest.main()
