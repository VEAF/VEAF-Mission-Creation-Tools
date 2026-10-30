"""Read a VEAF combat log and tell, pilot by pilot, what was fired and what it did (FEAT-COMBAT-LOG).

The mission's ``veafCombatLog`` module writes one JSON object per line: every ``shot`` (a missile, a bomb, a
rocket), every ``hit``, every ``kill``, and every gun burst (``shooting_start`` / ``shooting_end``, the
rounds counted from the shells the unit carried). The Tacview of 2026-10-29 had to guess who fired: an ACMI
names no shooter, records no destruction, and showed none of the AH-64s' gun. This reads the file the
mission wrote and gives the debrief its figures.
"""

from __future__ import annotations

import json
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class Kill:
    """One target a pilot destroyed."""

    time: float
    target: str
    weapon: str
    friendly: bool = False
    """Same coalition as the shooter."""


@dataclass
class PilotRecap:
    """What one pilot fired, and what it did."""

    pilot: str
    aircraft: str = ""
    shots: Counter[str] = field(default_factory=Counter)
    """Missiles, bombs and rockets, by weapon type."""
    rounds: Counter[str] = field(default_factory=Counter)
    """Gun rounds, by gun; a burst whose rounds could not be counted adds nothing here."""
    bursts: int = 0
    hits: Counter[str] = field(default_factory=Counter)
    """Hits on a target, by weapon."""
    kills: list[Kill] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        """The recap as plain JSON types (``dataclasses.asdict`` turns a ``Counter`` into a counter of tuples)."""
        return {
            "pilot": self.pilot,
            "aircraft": self.aircraft,
            "shots": dict(self.shots),
            "rounds": dict(self.rounds),
            "bursts": self.bursts,
            "hits": dict(self.hits),
            "kills": [vars(kill) for kill in self.kills],
        }


@dataclass
class CombatLog:
    """A combat log read from its file."""

    start: dict[str, Any]
    """The ``start`` line: theatre, date, ``start_time`` (seconds after midnight), real time."""
    records: list[dict[str, Any]]
    skipped: int = 0
    """Lines that were not JSON objects (a file cut short by a server crash ends with one)."""


def read_combat_log(path: Path) -> CombatLog:
    """Read a ``veaf-combat-log-*.jsonl`` file.

    Args:
        path: The file the mission wrote.

    Returns:
        Its ``start`` line and its records, in file order.

    Raises:
        OSError: When the file cannot be read.
    """
    start: dict[str, Any] = {}
    records: list[dict[str, Any]] = []
    skipped = 0
    # a crash can cut the last line inside a character: replaced, so that one line is skipped, not the file
    for text in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not text.strip():
            continue
        try:
            line = json.loads(text)
        except ValueError:
            skipped += 1
            continue
        if not isinstance(line, dict):
            skipped += 1
        elif line.get("event") == "start":
            start = line
        else:
            records.append(line)
    return CombatLog(start, records, skipped)


def _name(side: Any) -> str:
    """How a shooter or a target is named: its player, else its unit, else its type."""
    if not isinstance(side, dict):
        return ""
    return str(side.get("player") or side.get("name") or side.get("type") or "")


def pilot_recaps(log: CombatLog, include_ai: bool = False) -> list[PilotRecap]:
    """Gather the records by pilot.

    Args:
        log: The combat log.
        include_ai: Also list the AI shooters, by unit name; only the players otherwise.

    Returns:
        One recap per shooter, in the order they first fired.
    """
    recaps: dict[str, PilotRecap] = {}
    for record in log.records:
        shooter = record.get("shooter")
        if not isinstance(shooter, dict) or not (shooter.get("player") or include_ai):
            continue
        name = _name(shooter)
        if not name:
            continue
        recap = recaps.setdefault(name, PilotRecap(name, str(shooter.get("type") or "")))
        weapon = str(record.get("weapon") or record.get("weapon_name") or "?")
        event = record.get("event")
        if event == "shot":
            recap.shots[weapon] += 1
        elif event == "shooting_start":
            recap.bursts += 1
        elif event == "shooting_end" and isinstance(record.get("rounds"), int | float):
            recap.rounds[weapon] += int(record["rounds"])
        elif event == "hit":
            recap.hits[weapon] += 1
        elif event == "kill":
            target = record.get("target") or {}
            # a coalition nobody could read (a unit gone before the event was read) is not friendly fire
            coalition = target.get("coalition") if isinstance(target, dict) else None
            friendly = coalition is not None and coalition == shooter.get("coalition")
            label = str((target.get("type") if isinstance(target, dict) else "") or _name(target) or "?")
            recap.kills.append(Kill(float(record.get("t") or 0), label, weapon, friendly))
    return list(recaps.values())


def clock(log: CombatLog, mission_time: float) -> str:
    """A mission time as the mission's clock reads it, ``HH:MM``, from the ``start`` line's start time."""
    start = log.start.get("start_time")
    seconds = (float(start) if isinstance(start, int | float) else 0.0) + mission_time
    minutes = int(seconds // 60)
    return f"{minutes // 60 % 24:02d}:{minutes % 60:02d}"
