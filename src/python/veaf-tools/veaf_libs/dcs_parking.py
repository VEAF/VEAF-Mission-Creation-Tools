"""Look up an airfield's parking stands at design time.

Backed by the slimmed, bundled ``data/parking/<Theatre>.json`` files the dev tool
``veaf-build update-dcs-data --parking`` generates from runtime captures (see
``veaf_build/dcs_data/parking.py``). Each stand carries what placing an aircraft on a ramp needs: the
stand number (``parking``, the runtime ``Term_Index``), its mission position and altitude, its terminal
type, and its distance to the runway.

Two facts, both measured in game on 2026-08-15, are baked into how callers use this:

- A unit is placed at the stand's exact ``x``/``y``/``alt`` with ``parking`` = the stand number.
- ``parking_id`` is not stored and is not load-bearing: a caller sets it equal to ``parking``.

A theatre not captured yet simply has no file, and the lookups return empty.
"""

from __future__ import annotations

import functools
import json
from dataclasses import dataclass

from veaf_libs.bundled_data import read_bundled_text

#: Terminal types this tool seats an aircraft on. Equal to DCS's own ``FighterAircraft`` mask
#: (244 = 68 + 72 + 104, "effectively all spots usable by fixed wing aircraft"), and deliberately
#: **narrower than** :data:`PLANE_STAND_TYPES`: it leaves out ``100`` (SmallSizeFighter). Lives here,
#: beside the parking data, so parking-type policy is in one place rather than scattered across the
#: actions that consume it.
#:
#: Measured 2026-08-31 (CHORE-AIRCRAFT-STAND-TYPES) to settle whether the original ``{68, 104}`` —
#: read off one Caucasus mission — described reality or merely that sample. It did not.
#:
#: **Stand census** over the three bundled captures (``data/parking/*.json``, 6521 stands, 276
#: airfields; 126 with at least one plane stand, 150 helipad-only): 104 ×3113, 40 ×1010, 72 ×982,
#: 68 ×809, 16 ×324, 100 ×283. Note 68 is Caucasus-and-Syria only — **Persian Gulf has none**, so on
#: that theatre ``{68, 104}`` meant "104 only". Seven plane-capable airfields carry ``72`` and no
#: ``68``/``104`` at all, i.e. the tool refused to place anything on them: Bandar Lengeh, Tunb Island
#: AFB, Tunb Kochak, Bandar-e-Jask, Lavan Island and Jiroft (Persian Gulf), and Tha'lah (Syria, 16
#: OpenMed stands). Adding ``72`` unlocks all seven and takes the usable stand count from 3922 to
#: 4904 (+25%).
#:
#: **Real usage** in the VEAF Foothold missions (Caucasus / Syria / Persian Gulf) and the Open
#: Training Syria mission, resolving each parked unit's ``parking`` against these captures and keeping
#: only units whose own ``x``/``y`` lands within 25 m of the stand it names: 105 confirmed parked
#: planes sit on 104 ×41 (39%), 68 ×35 (33%) and **72 ×29 (28%)** — 24 distinct airframes on 72,
#: A-10C, AV8BNA, F-15ESE and F-14 among them. Mission makers use OpenMed for planes in quantity; the
#: original measurement missed it because Caucasus has only 46 OpenMed stands against 850 of 68/104.
#: (The position check is what makes the count trustworthy: 8 Syria units name a stand more than 100 m
#: from where they actually sit — a stale ``parking`` after a hand move — and would otherwise have
#: reported three planes parked on helipads.)
#:
#: **Why ``100`` stays out.** DCS documents it as "tight spots for smaller type fixed wing aircraft,
#: like the F-16", so seating a heavy there is a defect waiting to happen; it exists on 11 Syrian
#: airfields and **nowhere else**, every one of which already has ``68``/``104``, so including it
#: unlocks **zero** additional airfields (only 283 more stands); and no confirmed parked unit in any
#: measured mission sits on one. Including it would take an airframe-shaped risk for no capacity gain
#: — which is also why this set is ``FighterAircraft`` (244) and not ``FighterAircraftSmall`` (344).
#: Should ``100`` ever be wanted, it needs the airframe test this set deliberately does not have.
AIRCRAFT_STAND_TYPES: frozenset[str] = frozenset({"68", "72", "104"})

#: DCS ``Term_Type`` values, from the ``Airbase.TerminalType`` enumeration. Sourced 2026-08-31 from
#: two independent references that agree value for value — the Hoggit wiki's `getParking` page
#: (https://wiki.hoggitworld.com/view/DCS_func_getParking) and MOOSE's `AIRBASE.TerminalType`
#: (https://flightcontrol-master.github.io/MOOSE_DOCS/Documentation/Wrapper.Airbase.html):
#:
#: =====  ==================  ====================================================
#: Value  Name                Meaning
#: =====  ==================  ====================================================
#: 16     Runway              Valid spawn point on the runway (not a parking stand)
#: 40     HelicopterOnly      Helipad
#: 68     Shelter             Hardened aircraft shelter
#: 72     OpenMed             Open / shelter air, airplane only
#: 100    SmallSizeFighter    Tight stand for a small fixed-wing aircraft
#: 104    OpenBig             Open air stand, generally larger
#: =====  ==================  ====================================================
#:
#: The sets here come from that reference's own composite masks, which are the sums of the values they
#: combine (re-read 2026-08-31 to settle CHORE-AIRCRAFT-STAND-TYPES):
#:
#: ======================  =====  ==================================================================
#: Mask                    Value  Combines
#: ======================  =====  ==================================================================
#: OpenMedOrBig            176    72 + 104
#: HelicopterUsable        216    40 + 72 + 104 — every stand a helicopter can use
#: FighterAircraft         244    68 + 72 + 104 — "effectively all spots usable by fixed wing"
#: FighterAircraftSmall    344    68 + 72 + 100 + 104 — the same, for a *small* fixed wing
#: ======================  =====  ==================================================================
#:
#: ``Runway`` (16) is in none of them: it is a runway spawn, not a stand.
#:
#: This set is ``FighterAircraftSmall`` (344) because it answers *"can this airfield park a plane at
#: all?"* — a field with nothing but ``100`` can, for a small one. :data:`AIRCRAFT_STAND_TYPES` above
#: answers the narrower question of which stands this tool will *seat* a unit on itself, and is
#: ``FighterAircraft`` (244); the constant's own comment carries the measurement behind the gap.
#:
#: Consistency check against the bundled dumps: the airfields reported in game as offering
#: helicopters only (Syria's Lakatamia 48 and Naqoura 52) carry nothing but 40 (plus a runway),
#: while every airfield that works carries 104/68/72 in quantity. One correction to the reference,
#: measured on those dumps: 68 is *not* "currently only on Caucasus" as MOOSE's note says — Syria
#: carries 469 Shelter stands. Persian Gulf, on the other hand, carries none at all.
PLANE_STAND_TYPES: frozenset[str] = frozenset({"68", "72", "100", "104"})

#: Stands a helicopter can use. See :data:`PLANE_STAND_TYPES` for the source of the table.
HELICOPTER_STAND_TYPES: frozenset[str] = frozenset({"40", "72", "104"})


@dataclass(frozen=True)
class ParkingStand:
    """One parking stand at an airfield, in mission coordinates."""

    parking: str
    x: float
    y: float
    alt: float
    term_type: str
    dist_to_runway: float


@functools.lru_cache(maxsize=8)
def _theatre_table(theatre_key: str) -> dict[str, list[ParkingStand]]:
    """Load (and cache) ``{airbase_id: [ParkingStand, ...]}`` for a theatre, or empty if uncaptured."""
    try:
        raw = json.loads(read_bundled_text("veaf_libs", "data", "parking", f"{theatre_key}.json"))
    except (FileNotFoundError, OSError):
        return {}
    table: dict[str, list[ParkingStand]] = {}
    for airbase_id, stands in (raw.get("by_airbase") or {}).items():
        table[str(airbase_id)] = [
            ParkingStand(
                parking=str(s["p"]),
                x=float(s["x"]),
                y=float(s["y"]),
                alt=float(s["alt"]),
                term_type=str(s["t"]),
                dist_to_runway=float(s["d"]),
            )
            for s in stands
        ]
    return table


def _resolve_theatre_file(theatre: str) -> str | None:
    """Return the bundled file stem matching ``theatre`` (case-insensitive), or None if none ships."""
    import contextlib

    from veaf_libs.bundled_data import bundled_dir

    with contextlib.suppress(FileNotFoundError, OSError):
        for path in bundled_dir("veaf_libs", "data", "parking").glob("*.json"):
            if path.stem.lower() == theatre.strip().lower():
                return path.stem
    return None


def has_theatre(theatre: str) -> bool:
    """Return whether parking data ships for ``theatre`` (case-insensitive)."""
    return bool(theatre) and _resolve_theatre_file(theatre) is not None


def stands_for_airbase(theatre: str, airbase_id: int | str) -> list[ParkingStand]:
    """Return every parking stand at an airbase, nearest-to-runway first.

    Args:
        theatre: The DCS theatre/map name (case-insensitive).
        airbase_id: The DCS numeric airdrome id.

    Returns:
        The stands, sorted by ascending distance to the runway (empty if the theatre or airbase is
        not in the bundled data).
    """
    stem = _resolve_theatre_file(theatre) if theatre else None
    if stem is None:
        return []
    stands = _theatre_table(stem).get(str(airbase_id), [])
    return sorted(stands, key=lambda s: s.dist_to_runway)


def aircraft_stands_for_airbase(theatre: str, airbase_id: int | str) -> list[ParkingStand]:
    """Return only the stands aircraft actually park on, nearest-to-runway first.

    Filters :func:`stands_for_airbase` to :data:`AIRCRAFT_STAND_TYPES`, so a caller never seats an
    aircraft on a runway threshold or a helipad.

    Args:
        theatre: The DCS theatre/map name (case-insensitive).
        airbase_id: The DCS numeric airdrome id.

    Returns:
        The aircraft-capable stands (empty if the theatre or airbase is not in the bundled data).
    """
    return [s for s in stands_for_airbase(theatre, airbase_id) if s.term_type in AIRCRAFT_STAND_TYPES]


def parkable_kinds(theatre: str, airbase_id: int | str) -> frozenset[str] | None:
    """Return which kinds of aircraft an airfield can park, or ``None`` when nothing is known.

    DCS only ever offers a slot for an aircraft the terrain has a stand for: a helipad-only field
    offers helicopters whatever the mission stocks. A caller uses this to stop writing stock DCS
    will never show.

    Args:
        theatre: The DCS theatre/map name (case-insensitive).
        airbase_id: The DCS numeric airdrome id.

    Returns:
        A subset of ``{"plane", "helicopter"}``, or ``None`` when the theatre ships no parking data
        or the airfield is absent from it — in which case the caller must not filter anything.
    """
    stands = stands_for_airbase(theatre, airbase_id)
    if not stands:
        return None
    types = {s.term_type for s in stands}
    kinds: set[str] = set()
    if types & PLANE_STAND_TYPES:
        kinds.add("plane")
    if types & HELICOPTER_STAND_TYPES:
        kinds.add("helicopter")
    return frozenset(kinds)
