"""Data models of a multi-mission campaign (FEAT-MULTI-MISSION-CAMPAIGN).

Two structures, kept apart on purpose:

- :class:`CampaignDefinition` is what the author declares in ``campaign.yaml``. The tools read it
  and never rewrite it.
- :class:`CampaignState` is what the campaign has become. It is rewritten after every mission, and
  the mission's own state file (ticket 05) has the same shape, so merging one into the other is a
  replacement per zone rather than a translation.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Any

#: The coalitions that can own a zone. A neutral zone has lost its whole garrison and waits to be
#: captured (tickets 02 and 04).
SIDES: tuple[str, ...] = ("blue", "red", "neutral")

#: The coalitions that play: they have a reserve, objectives can be theirs.
COALITIONS: tuple[str, ...] = ("blue", "red")

#: The eras `veafCasMission`'s generators know (`veaf.ERA` in `veaf.lua`).
ERAS: tuple[str, ...] = ("MODERN", "COLD_WAR", "WW2")

#: What a zone can be besides a garrisoned position. A logistics zone feeds its side's reserve
#: between missions (ticket 06).
ZONE_KINDS: tuple[str, ...] = ("logistics",)

#: How many missions the objectives are sized for when `campaign.yaml` does not say.
DEFAULT_MISSIONS = 10

#: The version of the campaign state's format. A state written in another version is refused
#: rather than half-read.
STATE_FORMAT_VERSION = 1

#: Each generator parameter of a size class, with the range `veafCasMission` accepts for it — the
#: same bounds its marker parser applies (`veafCasMission.MarkerSpec`).
SIZE_PARAMETER_RANGES: dict[str, tuple[int, int]] = {"size": (1, 5), "defense": (0, 5), "armor": (0, 5)}

#: The categories a side's ground reserve is counted in (ticket 06).
RESERVE_CATEGORIES: tuple[str, ...] = ("armor", "air_defense", "transport")

#: Seconds one side has to hold a neutral zone alone to capture it (ticket 04).
DEFAULT_CAPTURE_SECONDS = 120

#: Seconds between two writes of the state file during a flight (ticket 05).
DEFAULT_STATE_WRITE_SECONDS = 60

#: The mission folder, in the campaign folder, every mission is copied from (ticket 09).
DEFAULT_MISSION_TEMPLATE = "template"

#: The bounds of a zone's radius, in metres: a few vehicles at the least, a sector at the most.
ZONE_RADIUS_RANGE: tuple[int, int] = (200, 20000)

#: When a campaign mission starts when `campaign.yaml` does not say: half an hour after sunrise on
#: the campaign's ground, a clock time (``"06:30"``) or a solar expression the build's weather
#: variants accept (``"sunset-45*60"``).
DEFAULT_START_TIME = "sunrise+30*60"


@dataclass(frozen=True)
class CampaignRules:
    """The fixed rules of the turn played between two missions (ticket 08)."""

    logistics_output: dict[str, int] = field(default_factory=lambda: {"armor": 2, "air_defense": 1, "transport": 1})
    """What each logistics zone adds to its owner's reserve after every mission."""
    repairs_per_mission: int = 4
    """How many lost garrison units each side gets back from its reserve after every mission."""
    counter_attack: bool = True
    """Whether a neutral zone bordered by one side only is retaken by it between missions."""
    assault_convoys: bool = True
    """Whether, in flight, each side sends an assault convoy to a neutral zone it borders."""
    assault_seconds: int = 600
    """Seconds between a zone becoming such a target and the convoy leaving for it."""
    intel_seconds: int = 1200
    """Seconds between a convoy leaving and the other side hearing of it; 0 tells it at once."""


@dataclass(frozen=True)
class SizeClass:
    """How big a zone's garrison is, as parameters of `veafCasMission`'s generators."""

    name: str
    size: int
    defense: int
    armor: int
    long_range_sam: bool = False


#: The shipped size classes. A campaign overrides any parameter of them, or declares new ones.
#:
#: Measured on 2026-10-06, 40 draws each with the real spawn data: an outpost averages 23 units
#: (12 to 36), an airfield 51 (35 to 74), of which its long-range battery is about 20. The first
#: values, CAS-mission sizes 2 and 4 drawn through `generateCasGroup`, gave 49 and 119 — about a
#: thousand ground units for the 12-zone example campaign.
DEFAULT_SIZE_CLASSES: dict[str, SizeClass] = {
    "outpost": SizeClass("outpost", size=1, defense=1, armor=1),
    "airfield": SizeClass("airfield", size=1, defense=3, armor=2, long_range_sam=True),
}


@dataclass(frozen=True)
class ZoneLocation:
    """Where a zone stands: on an airfield, or at coordinates."""

    airfield: str | None = None
    lat: float | None = None
    lon: float | None = None


@dataclass(frozen=True)
class CampaignZone:
    """One zone of the campaign, as declared."""

    name: str
    location: ZoneLocation
    size: str
    side: str
    kind: str | None = None
    garrison: tuple[str, ...] | None = None
    """An explicit list of aliases or DCS types that replaces the draw, or ``None`` to draw."""
    radius: int = 2000
    """Metres around the zone's centre: where its garrison stands and where ground holds it."""
    display_name: str | None = None
    """How the briefing names the zone to the players ("Dépôt de Khobi"); the name stays the key."""
    intel: str | None = None
    """What the intelligence says of the zone when the enemy holds it, in place of the generated text."""

    @property
    def label(self) -> str:
        """The zone's name as the players read it."""
        return self.display_name or self.name


@dataclass(frozen=True)
class Objective:
    """What winning means, one condition at a time."""

    kind: str
    """``capture`` (every zone owned by the player side) or ``destroy`` (the zone's garrison gone)."""
    zones: tuple[str, ...]
    target_kind: str | None = None


@dataclass(frozen=True)
class CampaignDefinition:
    """A whole `campaign.yaml`, validated."""

    name: str
    theatre: str
    era: str
    missions: int
    player_side: str
    objectives: tuple[Objective, ...]
    size_classes: dict[str, SizeClass]
    zones: tuple[CampaignZone, ...]
    connections: tuple[tuple[str, str], ...]
    reserves: dict[str, dict[str, int]] = field(default_factory=dict)
    """Each coalition's ground reserve at the start, by category."""
    rules: CampaignRules = field(default_factory=CampaignRules)
    capture_seconds: int = DEFAULT_CAPTURE_SECONDS
    state_write_seconds: int = DEFAULT_STATE_WRITE_SECONDS
    mission_template: str = DEFAULT_MISSION_TEMPLATE
    """The mission folder, relative to the campaign folder, every mission starts as a copy of."""
    start_date: date | None = None
    """The first mission's date, or ``None`` to keep the template's."""
    start_time: str = DEFAULT_START_TIME
    """When each mission starts, as a clock time or a solar expression."""
    players: tuple[int, int] | None = None
    """The fewest and the most players the squadron expects, or ``None`` when the campaign does not say."""

    def zone(self, name: str) -> CampaignZone:
        """Return the zone of that name.

        Args:
            name: The zone's name, as declared.

        Returns:
            The zone.

        Raises:
            KeyError: No zone has that name.
        """
        for zone in self.zones:
            if zone.name == name:
                return zone
        raise KeyError(name)

    def neighbours(self, name: str) -> tuple[str, ...]:
        """Return the zones connected to one, in the order the connections declare them.

        Args:
            name: The zone's name.

        Returns:
            The names of the zones it is connected to.
        """
        return tuple(b if a == name else a for a, b in self.connections if name in (a, b))


@dataclass
class ZoneState:
    """What a zone has become."""

    owner: str
    garrison: list[dict[str, Any]] | None = None
    """The drawn composition with its losses (ticket 02), or ``None`` until it is drawn."""
    capture: dict[str, Any] | None = None
    """The capture in progress (ticket 04), or ``None``."""
    warehouse: dict[str, Any] | None = None
    """The airbase warehouse as the last mission left it (ticket 06), or ``None``."""


@dataclass
class SideState:
    """What a coalition holds at the campaign level."""

    reserve: dict[str, int] = field(default_factory=dict)
    """Ground units held back, by category (ticket 06)."""


@dataclass
class CampaignState:
    """What the campaign has become after a number of missions."""

    format_version: int
    campaign: str
    mission: int
    """How many missions have been applied: 0 before the first is flown."""
    zones: dict[str, ZoneState]
    sides: dict[str, SideState]
    scenery_destroyed: list[dict[str, Any]] = field(default_factory=list)
    """Scenery objects destroyed so far (ticket 07)."""
    convoys: list[dict[str, Any]] = field(default_factory=list)
    """The assault convoys a mission sent (FEAT-OPPOSITION-SCALES-WITH-PLAYERS ticket 04): in a state
    file only, ``{name, side, from, to, sent, alive, absorbed}`` with unit types. The merge settles
    them, so the campaign state never keeps one."""
    history: list[dict[str, Any]] = field(default_factory=list)
    """One entry per mission applied: what changed, for the next briefing (tickets 08 and 09), and the
    date the mission was flown on (``date``, ``YYYY-MM-DD``), which the next mission's date follows."""
