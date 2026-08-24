"""The shipped waypoints template must not inject a waypoint that claims to be a bullseye.

**Why this exists.** `src/defaults/mission-folder/src/waypoints.yaml` declared an example waypoint named
`BULLSEYE` at fixed coordinates. That file is copied into every folder `veaf-tools mission prepare`
creates, and the waypoints injector runs as an ordinary `mission build` step whenever the file is present
— so the example was not dormant, it was **injected**. Measured in the built Syria smoke-test mission: one
waypoint named `BULLSEYE`, at the template's coordinates, **483 km** from that mission's own blue bullseye
and 216 km from its red one. All four mission folders in this repository carried it.

The failure is silent by construction: a pilot has no reason to distrust a steerpoint labelled BULLSEYE,
and a mission maker reads it as something he put there himself. Nothing could have caught it, which is
why this is a gate rather than a corrected file.

**What it does not claim.** It does not check that the other examples' coordinates mean anything —
`INITIAL_POINT` and `TARGET` are per-mission choices and no value is wrong. A bullseye is different: the
mission already carries one, with a single correct value, so naming an example after it is a claim.
"""

from __future__ import annotations

import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]

#: The shipped template, plus every mission folder in the repository that copied it.
TEMPLATES = (
    ROOT / "src/defaults/mission-folder/src/waypoints.yaml",
    ROOT / "test/veaf-tools/smoke-test-mission/src/waypoints.yaml",
    ROOT / "test/veaf-tools/verify-mission-a/src/waypoints.yaml",
    ROOT / "test/veaf-tools/verify-mission-c/src/waypoints.yaml",
    ROOT / "test/veaf-tools/demo-mission/src/waypoints.yaml",
)

#: Names that assert a real-world position the mission itself defines. A waypoint may not be called one
#: of these with coordinates written into a template, because the template cannot know the answer.
CLAIMED_NAMES = {"BULLSEYE", "BULLS", "BE"}


class TestDefaultWaypointsTemplate(unittest.TestCase):
    def test_the_files_are_there_and_readable(self) -> None:
        """A check that silently reads nothing passes every assertion below."""
        for path in TEMPLATES:
            self.assertTrue(path.is_file(), f"{path} is missing — update this list rather than deleting it")
            self.assertIsInstance(yaml.safe_load(path.read_text(encoding="utf-8")), dict, str(path))

    def test_no_waypoint_claims_to_be_the_bullseye(self) -> None:
        """The defect itself: a key, or a `name:`, asserting a position the template cannot know."""
        offences = []
        for path in TEMPLATES:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            for key, waypoint in (data.get("waypoints") or {}).items():
                if str(key).upper() in CLAIMED_NAMES:
                    offences.append(f"{path.name}: waypoint key {key!r}")
                if isinstance(waypoint, dict) and str(waypoint.get("name", "")).upper() in CLAIMED_NAMES:
                    offences.append(f"{path.name}: waypoint {key!r} is named {waypoint['name']!r}")

        self.assertEqual(
            offences,
            [],
            "a template waypoint claims to be the mission's bullseye, and the coordinates cannot be "
            "right — the mission carries its own:\n  " + "\n  ".join(offences),
        )

    def test_no_flight_plan_references_one_either(self) -> None:
        """A plan referencing a name no waypoint defines injects nothing and reports nothing.

        Checked separately from the waypoint itself because the two are edited in different places: a
        rename that misses a plan leaves a dangling reference, which fails silently.
        """
        offences = []
        for path in TEMPLATES:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            for plan_name, plan in (data.get("settings") or {}).items():
                for key, value in ((plan or {}).get("waypoints") or {}).items():
                    if str(key).upper() in CLAIMED_NAMES or str(value).upper() in CLAIMED_NAMES:
                        offences.append(f"{path.name}: plan {plan_name!r} references {key!r} -> {value!r}")

        self.assertEqual(offences, [], "a flight plan still references a bullseye waypoint:\n  " + "\n  ".join(offences))

    def test_every_plan_reference_resolves(self) -> None:
        """The rename's own failure mode, and it is silent: a plan pointing at a waypoint that is gone."""
        dangling = []
        for path in TEMPLATES:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            defined = set((data.get("waypoints") or {}).keys())
            for plan_name, plan in (data.get("settings") or {}).items():
                for value in ((plan or {}).get("waypoints") or {}).values():
                    if value not in defined:
                        dangling.append(f"{path.name}: plan {plan_name!r} wants {value!r}, which is not defined")

        self.assertEqual(dangling, [], "a flight plan references an undefined waypoint:\n  " + "\n  ".join(dangling))


if __name__ == "__main__":
    unittest.main()
