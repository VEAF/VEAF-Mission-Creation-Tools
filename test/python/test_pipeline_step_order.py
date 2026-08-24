"""The waypoints step must run after the steps that create the slots it injects into.

**Why this exists.** The build pipeline ran `waypoints` before `spawnable_aircrafts` and
`dynamic_slot_templates`. Those two create the human-piloted slots a flight plan exists for, so when the
waypoints step ran they did not exist yet. Measured in the built `SmokeTest_noon.miz`: **105**
human-piloted groups, exactly **1** carrying a waypoint from the flight plan — the base mission's own
slot. Running the injector at the corrected position over the same archive matches **105 of 105**.

It applied to *declared* waypoints, not only to anything automatic: a mission maker writing a flight plan
for a dynamic-slot mission had it applied to almost nothing.

**Why it was silent, which is the part worth remembering.** The step already reported "N injected" and
"M without a flight plan". At the old position it saw one group and reported `1 injected, 0 without a
plan` — a perfectly healthy line. Nothing lied; the report was taken before the world was finished. So
the fix restores the count as much as the behaviour, and no new reporting was needed.

**Why a source-order test.** The ordering is a property of the sequence of statements, not of any value
a normal test can read, and getting it wrong is invisible: the build succeeds, the report looks healthy,
and only a count of the produced mission shows the difference. The repository already scans source this
way (`test_lua_module_calls_resolve.py`, `test_no_bare_print.py`). Brittle to a refactor by design —
a refactor that moves these steps is exactly what should have to look here.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "src/python/veaf-tools/veaf_tools/commands/build.py"

#: The call that runs the waypoints step, and the two that create the slots it injects into.
WAYPOINTS = re.compile(r'^\s*waypoints_path\s*=\s*_step_file\(\s*"waypoints"', re.M)
AIRCRAFT_STEPS = (
    re.compile(r'^\s*_inject_aircraft_step\(\s*"spawnable_aircrafts"', re.M),
    re.compile(r'^\s*_inject_aircraft_step\(\s*"dynamic_slot_templates"', re.M),
)


class TestPipelineStepOrder(unittest.TestCase):
    def setUp(self) -> None:
        self.source = BUILD.read_text(encoding="utf-8")

    def test_the_steps_are_all_still_there(self) -> None:
        """A renamed step must fail here rather than make this test silently check nothing."""
        self.assertRegex(self.source, WAYPOINTS, "the waypoints step call was renamed or removed")
        for pattern in AIRCRAFT_STEPS:
            self.assertRegex(self.source, pattern, f"an aircraft-injection step matching {pattern.pattern} is gone")

    def test_waypoints_runs_after_the_aircraft_steps(self) -> None:
        """The defect itself: injecting into slots that do not exist yet."""
        waypoints_at = WAYPOINTS.search(self.source).start()
        for pattern in AIRCRAFT_STEPS:
            aircraft_at = pattern.search(self.source).start()
            self.assertLess(
                aircraft_at,
                waypoints_at,
                "the waypoints step runs before an aircraft-injection step, so it injects into slots "
                "that do not exist yet — this reached 1 human group in 105 on the smoke-test mission, "
                "and the build reported it as healthy because it counted the world it could see",
            )

    def test_it_still_runs_before_the_weather_variants(self) -> None:
        """Moving it later must not push it past the step that writes the variant files out.

        Not a guess: the weather step produces the per-variant `.miz` files, so anything injected after it
        would land in none of them. Bounding the move from both sides is what makes the assertion above a
        constraint rather than a direction.
        """
        weather = re.search(r'^\s*weather_path\s*=\s*_step_file\(\s*"weather"', self.source, re.M)
        self.assertIsNotNone(weather, "the weather step call was renamed or removed")
        self.assertLess(
            WAYPOINTS.search(self.source).start(),
            weather.start(),
            "the waypoints step now runs after the weather variants are written, so its injection would "
            "not reach them",
        )


if __name__ == "__main__":
    unittest.main()
