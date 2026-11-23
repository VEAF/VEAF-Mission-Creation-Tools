"""How a tanker refuels: with a boom or with a basket (David, 2026-11-17: a briefing says which, every time).

A boom serves the F-16, the F-15 and the A-10; a basket (hose and drogue) the F/A-18, the AV-8B, the F-14 and the
Rafale. The KC-10 carries both. DCS type names.
"""

from __future__ import annotations

from veaf_libs.i18n import t

#: The tankers that refuel with a boom.
BOOM_TANKERS = frozenset({"KC-135", "KC-10A"})

#: The tankers that refuel with a basket.
BASKET_TANKERS = frozenset({"KC135MPRS", "KC130", "KC130J", "S-3B Tanker", "IL-78M", "KC-10A"})


def refuelling_kind(unit_type: str) -> str | None:
    """``boom``, ``basket``, ``both``, or ``None`` when the type is no tanker this module knows.

    Args:
        unit_type: The DCS type of the tanker.

    Returns:
        The kind.
    """
    boom, basket = unit_type in BOOM_TANKERS, unit_type in BASKET_TANKERS
    if boom and basket:
        return "both"
    if boom:
        return "boom"
    return "basket" if basket else None


def with_refuelling(name: str, unit_type: str) -> str:
    """A tanker's name followed by how it refuels, in the current language: ``Texaco (boom)``.

    Args:
        name: The name to show (callsign, group name, role).
        unit_type: The DCS type of the aircraft.

    Returns:
        The name alone when the type is no known tanker.
    """
    kind = refuelling_kind(unit_type)
    return f"{name} ({t(f'tanker.kind.{kind}')})" if kind else name
