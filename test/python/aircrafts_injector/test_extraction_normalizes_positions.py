"""FIX-DYNSLOT-WIRING ticket 04 — an extracted catalogue carries no position (#984).

`_clean_group_data` removed ``radio`` and ``Radio`` and nothing else, so `x`/`y` came out of the
extractor exactly as they were in the source mission — at group level, at unit level, and on every
route point. Those coordinates mean nothing in another mission and less than nothing on another
theatre, where the same numbers land in the sea or in a different country.

The proof was in our own shipped file: `veafSpawn-MQ9 - AFAC - JTAC - DRONE` sat at
x = −250 000, y = −360 000, the position it had where it was extracted. The 128 dynamic-slot
templates are at (0,0) only because the 2026-09-21 graft normalized them **by hand**.

(0,0) is the normalized value, and it is a real point on the map rather than a void: measured
against the bundled Caucasus parking data, it lies north-west, 241 km west of the westernmost
airfield. A template is never spawned where it stands — it is late-activated, hidden, and
referenced by name — so what matters is that the placeholder is the same everywhere and carries
nothing from the mission it came from.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from aircrafts_injector.aircrafts_injector_worker import AircraftGroupsExtractorWorker
from mission_tools import KIND_SPAWNABLE
from mission_tools.miz_tools import DcsMission

_X, _Y = -250000.5, -360000.25


def _group_at_a_real_position() -> dict:
    """A group carrying a position at all three levels, as a real mission does."""
    return {
        "name": "veafSpawn-Viper 1",
        "x": _X,
        "y": _Y,
        "alt": 2000,
        "heading": 1.57,
        "units": [
            {"name": "veafSpawn-Viper 1 #01", "type": "F-16C_50", "x": _X, "y": _Y, "alt": 2000, "heading": 1.57}
        ],
        "route": {
            "points": {
                1: {"name": "wp1", "x": _X, "y": _Y, "alt": 2000, "action": "Turning Point"},
                2: {"name": "wp2", "x": _X + 5000, "y": _Y + 5000, "alt": 3000, "action": "Turning Point"},
            }
        },
    }


def _extractor() -> AircraftGroupsExtractorWorker:
    """An extractor over a one-group mission, with no file touched."""
    worker = AircraftGroupsExtractorWorker(
        input_lua=Path("lua-input"),
        output_spawnables=Path("out-spawnables.yaml"),
    )
    worker.dcs_mission = DcsMission(
        file_path=Path("dummy.miz"),
        mission_content={
            "coalition": {"blue": {"country": [{"name": "USA", "plane": {"group": [_group_at_a_real_position()]}}]}}
        },
    )
    return worker


def _extracted() -> dict:
    """Run the extraction and return the single group it produced."""
    worker = _extractor()
    worker.find_matching_groups(silent=True)
    worker.extract_plane_groups(silent=True)
    return worker.extracted[KIND_SPAWNABLE]["airplanes"]["coalitions"]["blue"]["USA"]["veafSpawn-Viper 1"]


def _positions(node: Any) -> list[float]:
    """Every ``x``/``y`` value anywhere in the structure."""
    found: list[float] = []
    if isinstance(node, dict):
        for key, value in node.items():
            if key in ("x", "y") and isinstance(value, (int, float)):
                found.append(value)
            else:
                found.extend(_positions(value))
    elif isinstance(node, list):
        for item in node:
            found.extend(_positions(item))
    return found


def test_no_coordinate_survives_the_extraction() -> None:
    """Group, unit and route point alike — the sweep is by key, not by a list of places."""
    assert _positions(_extracted()) != [], "the group must still declare its coordinates, at zero"
    assert set(_positions(_extracted())) == {0}


def test_everything_else_is_untouched() -> None:
    """Only the position travels badly: altitude, heading and the route itself stay."""
    group = _extracted()
    assert group["alt"] == 2000
    assert group["heading"] == 1.57
    assert group["units"][0]["type"] == "F-16C_50"
    assert [point["name"] for point in group["route"]["points"].values()] == ["wp1", "wp2"]
    assert [point["alt"] for point in group["route"]["points"].values()] == [2000, 3000]


def test_the_source_mission_is_not_mutated() -> None:
    """The extractor works on a copy; zeroing the original would corrupt the mission being read."""
    worker = _extractor()
    worker.find_matching_groups(silent=True)
    worker.extract_plane_groups(silent=True)
    source = worker.dcs_mission.mission_content["coalition"]["blue"]["country"][0]["plane"]["group"][0]
    assert source["x"] == _X
    assert source["units"][0]["y"] == _Y
