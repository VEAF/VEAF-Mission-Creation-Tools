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
    flights: tuple[str, ...] = ()
    """The flights it is for, by callsign: "Pour : Ninja" on its page (FIX-BRIEFING-PARITY-MARTEAU 04)."""
    status: str = ""
    """``main``, ``secondary`` or ``prerequisite`` (what must fall before the others can go): wins over what the
    operation in `mission.yaml` makes of it; empty leaves it to the operation (FIX-BRIEFING-PARITY-MARTEAU-2 04)."""


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
class PackageFlight:
    """A flight of the package as the assistant names it, for a mission whose players take dynamic slots.

    Such a mission has no flight group to read: its bases offer every type (61 on a Syria base), and the
    ATO listed them all (FEAT-OBJECTIVE-BRIEFING-QUALITY 01).
    """

    callsign: str
    base: str = ""
    """The airfield it takes off from, as DCS names it; empty when any base offering slots will do."""
    aircraft: str = ""
    """What it flies, as the briefing says it: ``F-16C``, ``A-10C ou AV-8B``."""
    count: int = 0
    """How many aircraft; 0 when open (four pilot boxes)."""
    task: str = ""


@dataclass(frozen=True)
class CodeWord:
    """A code word of the package: what it means, who acts on it (FEAT-OBJECTIVE-MISSION-V2 03)."""

    word: str
    meaning: str
    who: str = ""


@dataclass(frozen=True)
class SupportAsset:
    """A support asset as the assistant names it: ``Abu Nada``, ``JTAC``, ``FM 35.55``, ``code 1511``."""

    callsign: str
    role: str
    frequency: str = ""
    details: str = ""


@dataclass(frozen=True)
class ReconPhoto:
    """A recon photo of an objective and what its sidecar says (FEAT-OBJECTIVE-MISSION-V2 04)."""

    image: Path
    zone: str
    title: str
    heading: float | None = None
    """Camera heading, degrees true: the axis the photo looks along."""
    pitch: float | None = None
    """Camera pitch, degrees, negative looking down."""
    x: float | None = None
    y: float | None = None
    """The camera's position, mission coordinates."""
    altitude_m: float | None = None
    order: float = 0.0


@dataclass(frozen=True)
class BriefingContent:
    """What the assistant passes: the scenario's words, never a figure the mission holds."""

    title: str
    context: tuple[str, ...] = ()
    mission: tuple[str, ...] = ()
    mission_prose: bool = False
    """Whether ``mission`` is prose, its paragraphs printed as they are, or bullets, each after a dash."""
    strategic_situation: tuple[str, ...] = ()
    """The political and strategic context, in paragraphs: its own page, left out when empty."""
    objectives: tuple[Objective, ...] = ()
    threats: tuple[Threat, ...] = ()
    air_opposition: tuple[str, ...] = ()
    air_defences: tuple[str, ...] = ()
    other: tuple[str, ...] = ()
    pilots: dict[str, list[str]] = field(default_factory=dict)
    """Pilots' names by flight group name."""
    loadouts: dict[str, str] = field(default_factory=dict)
    """Imposed loadout by flight group name."""
    diversions: tuple[str, ...] | None = None
    """The diversion fields the briefing names; ``None`` lists the side's other airfields."""
    deployment: tuple[str, ...] = ()
    """Who goes first, the slots, the rendezvous, how the flights coordinate: its own page, left out when empty."""
    waypoint_notes: dict[str, str] = field(default_factory=dict)
    """What is done at a waypoint, by its name: on the flight plan's step sheets."""
    plan_notes: dict[str, dict[str, str]] = field(default_factory=dict)
    """What is done at a waypoint of one plan, by category (``plane``, ``helicopter``) then name: jets and
    helicopters share a point's name with different roles; it wins over ``waypoint_notes`` (FIX-BRIEFING-PARITY-MARTEAU 08)."""
    flights: tuple[PackageFlight, ...] = ()
    """The package's flights on dynamic slots; ``pilots`` and ``loadouts`` name them by callsign."""
    code_words: tuple[CodeWord, ...] = ()
    """The package's code words: a coordination page in the deck and on the kneeboard, left out when empty."""
    support: tuple[SupportAsset, ...] = ()
    """The support the mission has no group for (a JTAC, the fat cow, a GCI): rows of the ATO's support table."""


@dataclass(frozen=True)
class Target:
    """One member of an objective's zone, where it stands."""

    name: str
    x: float
    y: float
    kind: str = ""
    """What it is, its units' DCS types counted: ``4 × T-72B, 2 × BMP-2``."""
    role: str = ""
    """What it does, read from its DCS type's attributes: ``lanceur de la batterie``, ``char``."""
    spawned: bool = False
    """A VEAF spawn command, drawn when its zone is activated: its nature varies from one game to the next."""


@dataclass(frozen=True)
class ObjectiveArea:
    """An objective's combat zone and the enemy units in it, read from the built mission."""

    zone: str
    x: float
    y: float
    radius: float
    targets: tuple[Target, ...] = ()
    label: str = ""
    """How the maps and the pages name it: the flight plan's waypoint on it (``KHAN``), its zone otherwise."""
    secondary: bool = False
    """Outside the mission's operation: a secondary objective (FIX-BRIEFING-PARITY-MARTEAU 05)."""
    prerequisite: bool = False
    """To open before the others can go: the SA-6 the helicopters wait for (FIX-BRIEFING-PARITY-MARTEAU-2 04)."""

    @property
    def name(self) -> str:
        """Its label, its zone when it has none."""
        return self.label or self.zone


@dataclass(frozen=True)
class MapLine:
    """A line the author drew on the mission's map (the front line), as the briefing's maps redraw it."""

    name: str
    colour: tuple[int, int, int]
    width: int
    dashed: bool
    points: tuple[tuple[float, float], ...]
    """Mission ``x``/``y``."""


@dataclass(frozen=True)
class GroundPicture:
    """What the maps show on the ground besides the objectives (FIX-BRIEFING-PARITY-MARTEAU 02)."""

    friendlies: tuple[tuple[float, float], ...] = ()
    """Where the players' side's ground groups stand."""
    jtacs: tuple[tuple[str, float, float], ...] = ()
    """The players' JTACs: a group named ``JTAC…``, ``(name, x, y)``."""
    axes: tuple[tuple[str, tuple[tuple[float, float], ...]], ...] = ()
    """The ground groups' routes, ``(side, points)``: the pushes and the counter-attacks."""
    lines: tuple[MapLine, ...] = ()
    """The lines drawn on the players' side's and the common layers."""
    enemy_bases: tuple[tuple[str, float, float], ...] = ()
    """The airfields the enemy's aircraft start from (the QRA's), ``(name, x, y)``: on the overview."""


@dataclass(frozen=True)
class RadioPlan:
    """The channels of one radio, shared by the flights listed."""

    radio: int
    flights: tuple[str, ...]
    """Flight group names; a dynamic-slot template is named by its aircraft type."""
    channels: tuple[tuple[int, str, float], ...]
    """``(channel, name, MHz)``; the name is empty when the preset has none."""
    radios: tuple[int, ...] = ()
    """Every radio number carrying these channels, when the same list is on several (FIX-BRIEFING-PARITY-MARTEAU 06)."""
    by_radio: tuple[tuple[int, tuple[str, ...]], ...] = ()
    """Which flights carry these channels on which radio: ``((1, ("Blade",)), (2, ("Ninja", "Arctic")))``."""


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
    recon: list[Path] = field(default_factory=list)
    """The recon photos the briefing shows."""
