"""A persistent campaign's radio plan (FEAT-DYNAMIC-CAMPAIGN ticket 20, David's plan of 2026-11-17).

The first server evening flew on the scaffold's Open Training plan of the Caucasus: Batumi and Kutaisi on the
kneeboards of a Syria campaign, carriers that were not there, no AWACS. David's plan for a persistent campaign:

- **VHF** (the airfields' radio in the VEAF convention): channel 1 "Home Base", which each pilot sets to the field
  he took off from, then the players' side's airfields, with the frequencies DCS gives them on this theatre;
- **UHF**: the AWACS and the tankers, one common air-to-ground frequency ("Air-Sol"), then the VEAF flights.

The build needs a frequency on every channel — a channel with none is dropped and leaves the kneeboard — so Home
Base carries a placeholder no airfield of DCS uses (VHF 118.025, UHF 230.025, checked against
``airfield-frequencies.yaml``): the kneeboard reads "Home Base", the pilot overwrites it.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import yaml

from campaign_manager.models import CampaignDefinition

#: The plan's file, in the mission folder.
PRESETS_FILE = "src/presets.yaml"

#: The channel collection the plan writes its own channels into.
COLLECTION = "campaign"

#: Home Base's placeholder: frequencies no airfield of any theatre uses, so a pilot who forgets to set it
#: calls nobody.
HOME_BASE = {"title": "Home Base", "freqs": {"vhf": 118.025, "uhf": 230.025}}

#: The common air-to-ground frequency, free on every theatre.
AIR_TO_GROUND = {"title": "Air-Sol", "freqs": {"uhf": 305.0}}

#: How many presets a radio of the plan fills.
CHANNELS = 20

#: The VEAF flights, in the shipped plan's order, when the plan has no `flights` collection.
FLIGHTS = ("Archer", "Arctic", "Ninja", "Pinder", "Bengal", "Blade")

_SUFFIX = re.compile(r" \(.*\)$")


def _key(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", _SUFFIX.sub("", name).lower())


def _airport_aliases(presets: dict[str, Any], names: list[str]) -> list[str]:
    """The plan's alias of each airfield, from the `airports-*` collection that holds the most of them."""
    wanted = {_key(name) for name in names}
    best: dict[str, str] = {}
    for collection_name, collection in (presets.get("channels_collection") or {}).items():
        if str(collection_name).startswith("airports-") and isinstance(collection, dict):
            keys = {_key(str(alias)): str(alias) for alias in collection}
            if len(set(keys) & wanted) > len(set(best) & wanted):
                best = keys
    return [best[_key(name)] for name in names if _key(name) in best]


def _support_channels(campaign: CampaignDefinition, mission_folder: Path) -> dict[str, dict[str, Any]]:
    """A channel per AWACS and tanker of `dynamic.support.assets` and `economy.tanker`, on its group's frequency."""
    from mission_tools.miz_tools import read_mission_folder

    dynamic = campaign.dynamic or {}
    names = [str(name) for name in ((dynamic.get("support") or {}).get("assets") or [])]
    tanker = (dynamic.get("economy") or {}).get("tanker")
    if tanker and str(tanker) not in names:
        names.append(str(tanker))
    try:
        groups = {group.name: group for group in read_mission_folder(mission_folder).iter_groups() if group.name}
    except Exception:  # noqa: BLE001 — a mission that cannot be read gives no support channel, not a crash
        return {}
    channels: dict[str, dict[str, Any]] = {}
    for name in names:
        group = groups.get(name)
        frequency = group.group_dcs.get("frequency") if group else None
        if isinstance(frequency, (int, float)) and frequency > 0:
            channels[name.replace(" ", "-")] = {"title": name, "freqs": {"uhf": float(frequency)}}
    return channels


def campaign_radio_plan(
    campaign: CampaignDefinition, presets: dict[str, Any], support: dict[str, dict[str, Any]]
) -> dict[str, list[str]]:
    """The two channel lists of the players' side.

    Args:
        campaign: The validated campaign.
        presets: The parsed plan, for its airfield collections and its flights.
        support: The support channels, alias -> definition.

    Returns:
        ``{"primary_1": UHF aliases, "primary_2": VHF aliases}``.
    """
    side = campaign.player_side
    airfields = [zone.location.airfield for zone in campaign.zones if zone.side == side and zone.location.airfield]
    vhf = ["Home-Base", *_airport_aliases(presets, [str(name) for name in airfields])][:CHANNELS]
    collection = [str(alias) for alias in ((presets.get("channels_collection") or {}).get("flights") or {})]
    # the shipped plan's flights first, in its order, then the collection's others
    flights = [flight for flight in FLIGHTS if not collection or flight in collection]
    flights += [flight for flight in collection if flight not in flights]
    uhf = [*support, "Air-Sol", *flights][:CHANNELS]
    return {"primary_1": uhf, "primary_2": vhf}


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _replace_list(lines: list[str], side: str, radio: str, entries: list[str]) -> list[str]:
    """Replace the entries of `channel_lists.<side>.<radio>`, its key line kept."""
    start = next((i for i, line in enumerate(lines) if line.startswith("channel_lists:")), None)
    if start is None:
        return lines
    side_line = next((i for i in range(start + 1, len(lines)) if lines[i].strip().startswith(f"{side}:")), None)
    if side_line is None:
        return lines
    head = next(
        (
            i
            for i in range(side_line + 1, len(lines))
            if lines[i].strip().startswith(f"{radio}:") and _indent(lines[i]) > _indent(lines[side_line])
        ),
        None,
    )
    if head is None:
        return lines
    end = head + 1
    while end < len(lines) and lines[end].strip() and _indent(lines[end]) > _indent(lines[head]):
        end += 1
    pad = " " * (_indent(lines[head]) + 2)
    written = [f"{pad}{index:02d}: {alias}" for index, alias in enumerate(entries, start=1)]
    return [*lines[: head + 1], *written, *lines[end:]]


def _with_collection(lines: list[str], channels: dict[str, dict[str, Any]]) -> list[str]:
    """Put the plan's own collection first under `channels_collection`, replacing a previous one."""
    start = next((i for i, line in enumerate(lines) if line.startswith("channels_collection:")), None)
    if start is None:
        return lines
    # a previous campaign collection goes: written by this module, rewritten whole
    head = next(
        (i for i in range(start + 1, len(lines)) if lines[i].split("#")[0].rstrip() == f"    {COLLECTION}:"), None
    )
    if head is not None:
        end = head + 1
        while end < len(lines) and lines[end].strip() and _indent(lines[end]) > 4:
            end += 1
        lines = [*lines[:head], *lines[end:]]
    block = [f"    {COLLECTION}: # written by `campaign next`: the campaign's own channels"]
    for alias, definition in channels.items():
        freqs = ", ".join(f"{band}: {value}" for band, value in definition["freqs"].items())
        block.append(f"      {alias}:")
        block.append(f"        title: {definition['title']}")
        block.append(f"        freqs: {{ {freqs} }}")
    return [*lines[: start + 1], *block, *lines[start + 1 :]]


def write_campaign_radio_plan(campaign: CampaignDefinition, mission_folder: Path) -> bool:
    """Write a persistent campaign's radio plan into the mission folder's `src/presets.yaml`.

    Args:
        campaign: The validated campaign.
        mission_folder: The mission folder.

    Returns:
        Whether the file was written; ``False`` for a multi-mission campaign or a folder with no plan.
    """
    path = mission_folder / PRESETS_FILE
    if campaign.mode != "persistent" or not path.is_file():
        return False
    with open(path, encoding="utf-8", newline="") as handle:
        text = handle.read()
    presets = yaml.safe_load(text) or {}
    support = _support_channels(campaign, mission_folder)
    lists = campaign_radio_plan(campaign, presets, support)
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(newline)
    lines = _with_collection(lines, {"Home-Base": HOME_BASE, "Air-Sol": AIR_TO_GROUND, **support})
    for radio, entries in lists.items():
        lines = _replace_list(lines, campaign.player_side, radio, entries)
    updated = newline.join(lines)
    if updated == text:
        return False
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(updated)
    return True
