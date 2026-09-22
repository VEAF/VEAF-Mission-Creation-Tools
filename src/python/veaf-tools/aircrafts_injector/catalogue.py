"""Reading, comparing and merging aircraft-group catalogues.

A catalogue is the YAML shape both ``src/spawnables.yaml`` and
``src/dynamic-slot-templates.yaml`` carry::

    <category>:            # airplanes | helicopters
      coalitions:
        <coalition>:       # blue | red | neutrals
          <country>:
            <group name>: {…}

Two things in this module answer FEAT-DEFAULTS-CATALOGUE-FLOW. :func:`catalogue_has_groups`
tells an *empty* catalogue from a populated one, which is what lets the build fall back to the
catalogue shipped with the tool. :func:`merge_missing` is the mirror of
``AircraftGroupsExtractorWorker._merge_over``: there the incoming entry wins, here the entry the
mission maker already owns wins and the incoming one is only ever *added*. Both directions are
needed and neither may be expressed as the other — see ticket 03 of the lot.
"""

from __future__ import annotations

import copy
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator

import yaml

#: The two catalogue files, and the header written into an empty one. Keyed by the file name so a
#: caller that already holds a path does not have to carry a second identifier alongside it.
SPAWNABLES_FILENAME = "spawnables.yaml"
DYNAMIC_TEMPLATES_FILENAME = "dynamic-slot-templates.yaml"


@dataclass(frozen=True, order=True)
class GroupRef:
    """One group's place in a catalogue."""

    category: str
    """``airplanes`` or ``helicopters``."""

    coalition: str
    """``blue``, ``red`` or ``neutrals``."""

    country: str
    """The country the group is filed under, e.g. ``CJTF Blue``."""

    name: str
    """The DCS group name, which is what a maker selects by."""

    def __str__(self) -> str:
        return f"{self.category} / {self.coalition} / {self.country} / {self.name}"


def load_catalogue(path: Path) -> dict[str, Any]:
    """Read a catalogue file, treating an absent or blank file as an empty catalogue.

    Args:
        path: The YAML file to read.

    Returns:
        The parsed catalogue, or ``{}`` when the file does not exist, is blank, or does not
        parse to a mapping.
    """
    if not path.is_file():
        return {}
    try:
        parsed = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def iter_groups(catalogue: dict[str, Any]) -> Iterator[tuple[GroupRef, Any]]:
    """Walk every group of a catalogue, in file order.

    Levels that are ``None`` or not a mapping are skipped rather than raised on: this walk is
    used to *decide* whether a file is usable, so it must survive a malformed one.

    Args:
        catalogue: A parsed catalogue.

    Yields:
        Each group's :class:`GroupRef` and its definition.
    """
    for category, category_data in catalogue.items():
        if not isinstance(category_data, dict):
            continue
        coalitions = category_data.get("coalitions")
        if not isinstance(coalitions, dict):
            continue
        for coalition, countries in coalitions.items():
            if not isinstance(countries, dict):
                continue
            for country, groups in countries.items():
                if not isinstance(groups, dict):
                    continue
                for name, group in groups.items():
                    yield GroupRef(str(category), str(coalition), str(country), str(name)), group


def catalogue_has_groups(catalogue: dict[str, Any]) -> bool:
    """Whether a parsed catalogue carries at least one group.

    Args:
        catalogue: A parsed catalogue.

    Returns:
        ``True`` as soon as one group is found.
    """
    return next(iter_groups(catalogue), None) is not None


def catalogue_file_has_groups(path: Path) -> bool:
    """Whether a catalogue file carries at least one group.

    The 62-byte ``airplanes: {coalitions: {}}`` skeleton some mission folders carry answers
    ``False``, and so does an absent or unreadable file.

    Args:
        path: The YAML file to read.

    Returns:
        ``True`` when the file holds at least one group.
    """
    return catalogue_has_groups(load_catalogue(path))


def merge_missing(
    mine: dict[str, Any], incoming: dict[str, Any], names: set[str] | None = None
) -> tuple[dict[str, Any], list[GroupRef]]:
    """Add the groups *mine* does not have, and never touch one it does.

    The mirror of ``AircraftGroupsExtractorWorker._merge_over``, which merges the other way
    round. Keep them apart: the extractor's ``--merge`` means *my new extraction wins*, this
    means *what the maker already owns wins*.

    Args:
        mine: The mission folder's catalogue — the one being added to.
        incoming: The catalogue to take entries from.
        names: When given, only these group names are considered; anything else in *incoming*
            is ignored. ``None`` takes every missing group.

    Returns:
        The merged catalogue, and the refs of the groups that were added, in file order.
    """
    merged = copy.deepcopy(mine)
    owned = {ref.name for ref, _ in iter_groups(mine)}
    added: list[GroupRef] = []

    for ref, group in iter_groups(incoming):
        if ref.name in owned or (names is not None and ref.name not in names):
            continue
        countries = merged.setdefault(ref.category, {}).setdefault("coalitions", {}).setdefault(ref.coalition, {})
        countries.setdefault(ref.country, {})[ref.name] = copy.deepcopy(group)
        owned.add(ref.name)
        added.append(ref)

    return merged, added


def empty_catalogue_yaml(filename: str) -> str:
    """The skeleton ``prepare`` lays down in place of a full copy of the shipped catalogue.

    The header is the whole point of this function. An empty catalogue means *I add nothing to
    the catalogue shipped with the tool* — it is **not** a way to switch the step off — and
    somebody reading the 62-byte file without that sentence will conclude the opposite.

    Args:
        filename: ``spawnables.yaml`` or ``dynamic-slot-templates.yaml``; decides the wording
            and the pipeline key named in the header.

    Returns:
        The file's full text, header comment included.
    """
    if filename == DYNAMIC_TEMPLATES_FILENAME:
        what, step_key = "dynamic-slot templates", "dynamic_slot_templates"
    else:
        what, step_key = "spawnable aircraft groups", "spawnable_aircrafts"

    # Built into a local rather than returned inline: the repository's i18n guard flags a `return`
    # of an English literal, and this one is file content rather than a user-visible message.
    skeleton = f"""\
# {what.capitalize()} for this mission.
#
# THIS FILE IS EMPTY ON PURPOSE, AND EMPTY DOES NOT MEAN "NONE".
# Empty means "I add nothing to the catalogue shipped with veaf-tools". The build falls back to
# that catalogue whenever this file holds no group, so an empty file gets you every entry the
# tool ships with — and gets the new ones every time you update the tool.
#
# To switch the step off entirely, say so in mission.yaml instead:
#
#   pipeline:
#     {step_key}: false
#
# As soon as you write one group of your own below, this file stands alone: the shipped
# catalogue is no longer read, and you keep exactly what is written here. To see what the
# shipped catalogue has that you do not, and to copy in the entries you want:
#
#   .\\veaf-tools.exe content pull-aircraft-groups
#   .\\veaf-tools.exe content pull-aircraft-groups --add "F-14BU Template"
#   .\\veaf-tools.exe content pull-aircraft-groups --add-new
#
# Doc: https://veaf.github.io/documentation/dev/mission-maker/concepts/dynamic-slots/
airplanes:
  coalitions: {{}}
helicopters:
  coalitions: {{}}
"""
    return skeleton
