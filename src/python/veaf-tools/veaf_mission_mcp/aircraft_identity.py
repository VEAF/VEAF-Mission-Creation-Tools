"""Give a new flight the callsign and tail numbers the Mission Editor would have given it.

`add_air_group` and `add_player_slot` wrote no ``callsign`` and numbered every flight's tail numbers
from 10, so the E-3A, the KC-135 and the first fighter of a mission all carried ``10`` and none had
a callsign (FIX-OPEN-TRAINING-PROMPT-FINDINGS ticket 01).

The editor's family->word tables are compiled into the game and not in the datamine, so the ones
used here were **measured** on 377 distinct missions under ``D:\\dev\\_VEAF`` (2026-09-28):

- an aircraft of **Russia, USSR, Ukraine, China or Abkhazia** carries a bare number (``callsign =
  182``) — 10 832 of 10 956 aircraft of those countries; every other country present carries a
  ``{1: family, 2: flight, 3: number, name}`` table;
- the family word follows the group's **task**: ``Refueling`` uses Texaco / Arco / Shell (807 of
  807), ``AWACS`` Overlord / Magic / Wizard / Focus / Darkstar, and every other task the eight
  common families Enfield ... Pontiac (the type-specific families — Viper, Hornet, Hawg — are an
  alternative the editor offers, never the only choice).

Countries absent from those missions (Belarus, Kazakhstan, South Ossetia...) get a table: that is
what a mission maker can see and correct, where a guessed number would pass unnoticed.
"""

import re
from typing import Any

from veaf_libs.dcs_countries import country_name_for_id
from veaf_libs.mission_table import indexed

#: Countries whose aircraft carry a numeric callsign, as measured (see the module docstring).
NUMERIC_CALLSIGN_COUNTRIES: frozenset[str] = frozenset({"Russia", "USSR", "Ukraine", "China", "Abkhazia"})

#: Family words by group task, index 1 first; any task not listed uses ``_COMMON_FAMILIES``.
_TASK_FAMILIES: dict[str, tuple[str, ...]] = {
    "Refueling": ("Texaco", "Arco", "Shell"),
    "AWACS": ("Overlord", "Magic", "Wizard", "Focus", "Darkstar"),
}
_COMMON_FAMILIES: tuple[str, ...] = ("Enfield", "Springfield", "Uzi", "Colt", "Dodge", "Ford", "Chevy", "Pontiac")

#: Every family word of every task, lower case.
_ALL_FAMILY_WORDS: frozenset[str] = frozenset(
    word.lower() for words in (*_TASK_FAMILIES.values(), _COMMON_FAMILIES) for word in words
)

#: A callsign's flight and number are single digits: ``name`` concatenates them.
_MAX_DIGIT = 9

#: A group name that reads as a callsign: a word, then a flight digit (``Texaco 2``, ``Magic1``).
_NAME_CALLSIGN = re.compile(r"^([A-Za-z]+)[ _-]*([1-9])")

#: First numeric callsign handed out when the mission has none yet.
_FIRST_NUMERIC_CALLSIGN = 101

#: First tail number handed out when the mission has none yet.
_FIRST_ONBOARD_NUM = 10


def _aircraft_units(content: dict[str, Any]) -> list[dict[str, Any]]:
    """Return every aircraft unit of the mission, both coalitions, planes and helicopters."""
    units: list[dict[str, Any]] = []
    for coalition in (content.get("coalition") or {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in indexed(coalition.get("country")):
            if not isinstance(country, dict):
                continue
            for category in ("plane", "helicopter"):
                for group in indexed((country.get(category) or {}).get("group")):
                    if isinstance(group, dict):
                        units.extend(u for u in indexed(group.get("units")) if isinstance(u, dict))
    return units


def assign_identities(
    content: dict[str, Any], group: dict[str, Any], *, country_id: int, task: str
) -> str | None:
    """Give each unit of a flight not yet in the mission a callsign and a free tail number.

    Tail numbers continue after the highest numeric one already in the mission, so they never
    repeat. A western callsign follows the group's name when it reads as one — a family word of the
    task and a flight digit, ``Texaco 2`` — provided that flight is free; otherwise it takes the
    first family (for the task) that no aircraft of the mission uses yet, flight 1; once every family
    is taken, the least used family's next free flight. Either way it is numbered 1, 2, ... within
    the flight. A numeric callsign continues after the highest in the mission.

    Args:
        content: The parsed ``mission`` table, read to avoid what is already taken.
        group: The flight being inserted, mutated in place; a unit that already carries a
            ``callsign`` or an ``onboard_num`` keeps it.
        country_id: The DCS country id the flight is filed under.
        task: The group's task, which selects the family words.

    Returns:
        A note when the group's name reads as a callsign that could not be given — a word that is
        not a family of the task, or a flight already held — naming the callsign given instead;
        ``None`` otherwise.
    """
    existing = _aircraft_units(content)
    units = [u for u in indexed(group.get("units")) if isinstance(u, dict)]

    tails = [int(str(u["onboard_num"])) for u in existing if str(u.get("onboard_num", "")).isdigit()]
    next_tail = max(max(tails, default=_FIRST_ONBOARD_NUM - 1) + 1, _FIRST_ONBOARD_NUM)
    for unit in units:
        if unit.get("onboard_num") is None:
            unit["onboard_num"] = f"{next_tail:03d}"
            next_tail += 1

    if country_name_for_id(country_id) in NUMERIC_CALLSIGN_COUNTRIES:
        numbers = [u["callsign"] for u in existing if isinstance(u.get("callsign"), int)]
        next_number = max(max(numbers, default=_FIRST_NUMERIC_CALLSIGN - 1) + 1, _FIRST_NUMERIC_CALLSIGN)
        for unit in units:
            if unit.get("callsign") is None:
                unit["callsign"] = next_number
                next_number += 1
        return None

    families = _TASK_FAMILIES.get(task, _COMMON_FAMILIES)
    taken: dict[str, set[int]] = {word: set() for word in families}
    for unit in existing:
        callsign = unit.get("callsign")
        if not isinstance(callsign, dict):
            continue
        name = str(callsign.get("name", ""))
        word = name.rstrip("0123456789")
        if word in taken and isinstance(callsign.get(2), int):
            taken[word].add(callsign[2])
    asked = _callsign_in_name(str(group.get("name", "")), families)
    note: str | None = None
    if asked is not None and asked[1] not in taken[families[asked[0] - 1]]:
        family_index, flight = asked
    else:
        family_index, flight = _free_family_and_flight(families, taken)
    word = families[family_index - 1]
    if asked is None:
        spoken = _NAME_CALLSIGN.match(str(group.get("name", "")))
        # Only a word that is some task's family reads as a callsign asked for: "MiG29" or "SA-6" do not.
        if spoken is not None and spoken.group(1).lower() in _ALL_FAMILY_WORDS:
            note = (
                f"group {group.get('name')!r}: {spoken.group(1)!r} is not a callsign family of task {task!r} "
                f"({', '.join(families)}); given {word}{flight}1"
            )
    elif (family_index, flight) != asked:
        note = (
            f"group {group.get('name')!r}: flight {families[asked[0] - 1]}{asked[1]} is already held; "
            f"given {word}{flight}1"
        )
    for position, unit in enumerate(units):
        if unit.get("callsign") is None:
            # The number is one digit: a tenth aircraft continues on the next flight (Enfield21).
            unit_flight = min(flight + position // _MAX_DIGIT, _MAX_DIGIT)
            digit = position % _MAX_DIGIT + 1
            unit["callsign"] = {1: family_index, 2: unit_flight, 3: digit, "name": f"{word}{unit_flight}{digit}"}
    return note


def _callsign_in_name(name: str, families: tuple[str, ...]) -> tuple[int, int] | None:
    """Read the callsign a group's name asks for, ``Texaco 2`` or ``Texaco21``.

    Args:
        name: The group's name.
        families: The family words of the group's task, index 1 first.

    Returns:
        ``(family index, flight)`` when the name starts with one of ``families`` (any case) followed
        by a flight digit, else ``None``.
    """
    match = _NAME_CALLSIGN.match(name)
    if match is None:
        return None
    lowered = [word.lower() for word in families]
    if match.group(1).lower() not in lowered:
        return None
    return lowered.index(match.group(1).lower()) + 1, int(match.group(2))


def _free_family_and_flight(families: tuple[str, ...], taken: dict[str, set[int]]) -> tuple[int, int]:
    """Return the 1-based family index and flight for a new flight.

    Args:
        families: The family words, index 1 first.
        taken: Family word -> the flights of it already used in the mission.

    Returns:
        ``(family index, flight)`` — an unused family's flight 1, else the least used family's
        lowest free flight (flight 9 again if all nine are used, which only a huge mission reaches).
    """
    for index, word in enumerate(families, start=1):
        if not taken[word]:
            return index, 1
    index, word = min(enumerate(families, start=1), key=lambda item: len(taken[item[1]]))
    free = [flight for flight in range(1, _MAX_DIGIT + 1) if flight not in taken[word]]
    return index, free[0] if free else _MAX_DIGIT
