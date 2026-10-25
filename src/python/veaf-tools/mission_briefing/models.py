"""What a one-shot mission's briefing is made of (FEAT-MCP-MISSION-BRIEFING).

Two kinds of data: what the assistant writes (:class:`BriefingContent`, the scenario's words) and what
the built mission says (:class:`ObjectiveArea`, :class:`RadioPlan`), read back so that every figure in
the briefing is the mission's.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Objective:
    """An objective as the assistant states it."""

    zone: str
    """The combat zone's trigger-zone name."""
    title: str
    task: tuple[str, ...] = ()
    """What to do there, one line each."""


@dataclass(frozen=True)
class Threat:
    """A known threat, as intelligence states it."""

    name: str
    group: str
    """The group that stands where the threat is."""
    family: str = ""
    """``SA-6``, ``AAA``…"""
    engagement_nm: float | None = None
    detection_nm: float | None = None
    source: str = ""
    """Where the ranges come from; a range is only drawn when one is given."""


@dataclass(frozen=True)
class BriefingContent:
    """What the assistant passes: the scenario's words, never a figure the mission holds."""

    title: str
    context: tuple[str, ...] = ()
    mission: tuple[str, ...] = ()
    objectives: tuple[Objective, ...] = ()
    threats: tuple[Threat, ...] = ()
    air_opposition: tuple[str, ...] = ()
    air_defences: tuple[str, ...] = ()
    other: tuple[str, ...] = ()
    pilots: dict[str, list[str]] = field(default_factory=dict)
    """Pilots' names by flight group name."""
    loadouts: dict[str, str] = field(default_factory=dict)
    """Imposed loadout by flight group name."""


@dataclass(frozen=True)
class Target:
    """One member of an objective's zone, where it stands."""

    name: str
    x: float
    y: float


@dataclass(frozen=True)
class ObjectiveArea:
    """An objective's combat zone and the enemy units in it, read from the built mission."""

    zone: str
    x: float
    y: float
    radius: float
    targets: tuple[Target, ...] = ()


@dataclass(frozen=True)
class RadioPlan:
    """The channels of one radio, shared by the flights listed."""

    radio: int
    flights: tuple[str, ...]
    """Flight group names; a dynamic-slot template is named by its aircraft type."""
    channels: tuple[tuple[int, str, float], ...]
    """``(channel, name, MHz)``; the name is empty when the preset has none."""


@dataclass(frozen=True)
class SlotFlight:
    """An aircraft type a base offers in dynamic slots, with the channel its pilots find first."""

    aircraft: str
    """The DCS type."""
    callsign: str
    """The name of the first channel of its first radio: the flight's callsign on the package plan, or empty."""
    frequency: float | None
    """That channel's MHz, ``None`` when the aircraft carries no preset."""


@dataclass(frozen=True)
class BriefingReport:
    """What building the briefing produced."""

    deck: Path
    pages: int
    maps: list[Path]
    pictures: list[str]
    """The DCS briefing pictures' resource keys, in display order."""
    miz: Path
    offline: bool
    """Whether a map had to do without its background."""
    warnings: list[str] = field(default_factory=list)
    pdf: Path | None = None
    """The same pages as a PDF, drawn by the executable."""
    pdf_pages: int = 0
    """Its page count: the deck's, or more when a page's text runs on."""
    archives: list[Path] = field(default_factory=list)
    """Every built `.miz` the pictures went into: the build's own, then each weather variant."""
    kneeboard: list[str] = field(default_factory=list)
    """The kneeboard pages written, in the order the kneeboard shows them."""
