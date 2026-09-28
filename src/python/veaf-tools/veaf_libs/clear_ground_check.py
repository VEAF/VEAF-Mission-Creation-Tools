"""Check in DCS whether a mission's ground units stand in scenery (FEAT-CLEAR-GROUND-AT-AUTHORING 05).

The catalogue is a model of the terrain, and a model gets checked against the thing itself: this
module asks DCS about the positions a mission declares, and compares each answer with what the
catalogue predicted. A disagreement is a finding about the catalogue, not noise.

**How it counts — and why it does not spawn the mission.** DCS's scenery probe answers "is there room
here", and a vehicle occupies room: probed after a spawn, a tight SAM battery fails its own test
wherever it stands, because each vehicle blocks its neighbours. Three published figures were wrong
that way — 81, 76 and 69 (``known-limitations.yaml``, ``disposition-getsimplezones-is-a-lottery``).
So the mission is never loaded: its unit positions are read from the ``.miz`` and probed **on the
empty survey mission**, where no vehicle exists. :data:`CRITERION` says so in every report.

A combat-zone marker (``#command=...``) is not checked: it is not a vehicle, and the group it stands
for is drawn at runtime, around it, by ``veafUnits`` — whose own ``settleGroup`` moves it off scenery.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

from veaf_libs.clear_ground_catalogue import STATE_CLEAR, Catalogue, catalogue_for_theatre
from veaf_libs.clear_ground_survey import LuaExec, probe_points

CRITERION = (
    "DCS's own scenery probe — is there 5 m free within 20 m (Disposition.getSimpleZones, the test "
    "veafUnits.settleGroup applies) — at each unit's declared position, on the empty survey mission: no "
    "vehicle exists there, so no unit is ever counted as blocked by its neighbours"
)

_STATE_NAMES = {"1": "clear", "0": "blocked", "W": "water", "R": "runway", "?": "unknown"}


@dataclass(frozen=True)
class UnitCheck:
    """One ground unit, as DCS answered and as the catalogue predicted."""

    group: str
    unit: str
    x: float
    y: float
    probed: str
    predicted: str

    @property
    def disagrees(self) -> bool:
        """DCS and the catalogue give different answers where both have one."""
        if self.predicted == "not covered" or self.probed == "unknown":
            return False
        return (self.probed == "clear") != (self.predicted == "clear")


@dataclass
class CheckReport:
    """What the check found."""

    theatre: str
    units: list[UnitCheck]
    markers_skipped: int = 0
    criterion: str = CRITERION
    blocked_groups: dict[str, int] = field(default_factory=dict)

    def __post_init__(self) -> None:
        # "unknown" is the probe failing to answer, not the ground being blocked: counting it as
        # blocked would report every vehicle in a wood on a DCS where the probe raises.
        for unit in self.units:
            if unit.probed not in ("clear", "unknown"):
                self.blocked_groups[unit.group] = self.blocked_groups.get(unit.group, 0) + 1

    @property
    def unknown(self) -> int:
        """Units the probe could not answer about."""
        return sum(1 for unit in self.units if unit.probed == "unknown")

    @property
    def blocked(self) -> int:
        """Units DCS reports standing somewhere not clear."""
        return sum(self.blocked_groups.values())

    @property
    def disagreements(self) -> list[UnitCheck]:
        """Units where DCS and the catalogue disagree."""
        return [unit for unit in self.units if unit.disagrees]

    def to_dict(self) -> dict[str, Any]:
        """Serialise to a JSON-ready dict."""
        return {
            "theatre": self.theatre,
            "criterion": self.criterion,
            "units_checked": len(self.units),
            "units_not_clear": self.blocked,
            "groups_not_clear": self.blocked_groups,
            "units_unknown": self.unknown,
            "markers_skipped": self.markers_skipped,
            "disagreements_with_catalogue": [asdict(unit) for unit in self.disagreements],
        }


def ground_units(miz_path: Path) -> tuple[str, list[tuple[str, str, float, float]], int]:
    """Read a mission's ground vehicles.

    Args:
        miz_path: The mission.

    Returns:
        Its theatre, ``(group, unit, x, y)`` for each vehicle, and how many markers were skipped.
    """
    from mission_tools.miz_tools import read_miz  # noqa: PLC0415

    def values(table: Any) -> list[Any]:
        if isinstance(table, dict):
            return list(table.values())
        return list(table or [])

    content = read_miz(miz_path).mission_content or {}
    found: list[tuple[str, str, float, float]] = []
    markers = 0
    for side in values(content.get("coalition")):
        for country in values(side.get("country") if isinstance(side, dict) else None):
            for group in values((country.get("vehicle") or {}).get("group")):
                for unit in values(group.get("units")):
                    name = str(unit.get("name", ""))
                    if "#command" in name.lower():
                        markers += 1
                        continue
                    found.append((str(group.get("name", "")), name, float(unit["x"]), float(unit["y"])))
    return str(content.get("theatre", "")), found, markers


def offer_check(miz_path: Path) -> dict[str, Any]:
    """What checking a mission in DCS would take — an offer for the user to accept, nothing launched.

    Args:
        miz_path: The built mission.

    Returns:
        The command to run, what it needs, and how it counts.

    Raises:
        ValueError: If *miz_path* is not a ``.miz`` (a mission folder must be built first: the check
            reads the positions the build wrote).
    """
    if miz_path.suffix.lower() != ".miz" or not miz_path.is_file():
        raise ValueError(f"{miz_path}: give the built .miz — the check reads the unit positions the build wrote")
    theatre, units, markers = ground_units(miz_path)
    return {
        "launched": False,
        "offer": (
            f"I can check in DCS whether the {len(units)} ground vehicles of this mission stand in trees or "
            f"buildings. It needs DCS and {theatre}: the command below writes an empty survey mission, tells "
            "you what to do in DCS, probes each vehicle's position there, and says when DCS can be closed. "
            "Nothing runs until you say so."
        ),
        "command": f'.\\veaf-tools.exe dcs clear-ground-check "{miz_path}"',
        "theatre": theatre,
        "vehicles": len(units),
        "markers_left_to_runtime": markers,
        "criterion": CRITERION,
    }


def predict(catalogue: Catalogue | None, x: float, y: float) -> str:
    """What the catalogue says about a point: the nearest cell of the finest layer covering it.

    Args:
        catalogue: The theatre's catalogue, if any.
        x: Mission ``x``.
        y: Mission ``y``.

    Returns:
        ``"clear"``, ``"blocked"`` or ``"not covered"``.
    """
    layers = [layer for layer in (catalogue.layers if catalogue else []) if layer.grid.contains(x, y)]
    if not layers:
        return "not covered"
    layer = min(layers, key=lambda candidate: candidate.grid.spacing)
    grid = layer.grid
    row = round((x - grid.origin_x) / grid.spacing)
    col = round((y - grid.origin_y) / grid.spacing)
    return "clear" if layer.states[row * grid.cols + col] == STATE_CLEAR else "blocked"


def check_mission(miz_path: Path, exec_lua: LuaExec) -> CheckReport:
    """Probe every ground vehicle of a mission on the running survey mission, and compare.

    Args:
        miz_path: The mission to check. It is read, never loaded in DCS.
        exec_lua: The transport, to the **empty survey mission** of the same theatre.

    Returns:
        The report.
    """
    theatre, units, markers = ground_units(miz_path)
    answers = probe_points(exec_lua, [(x, y) for _g, _u, x, y in units]) if units else b""
    catalogue = catalogue_for_theatre(theatre) if theatre else None
    checks = [
        UnitCheck(group, unit, x, y, _STATE_NAMES.get(chr(answer), "unknown"), predict(catalogue, x, y))
        for (group, unit, x, y), answer in zip(units, answers, strict=True)
    ]
    return CheckReport(theatre, checks, markers)
