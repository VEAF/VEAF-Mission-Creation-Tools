"""Build the next mission of a campaign from its state (ticket 09).

What the tools apply is everything the state decides: who owns each airbase, and so where each side's
dynamic slots are; the campaign data table the runtime module reads (garrisons with their losses,
reserves, destroyed scenery); the `CAMPAIGN` module in `mission.yaml`; and the factual half of the
strategic briefing. The mission itself — objectives, packages, the narrative — is designed on top of
that folder afterwards, by Claude through the MCP, never instead of it.
"""

from __future__ import annotations

import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml
from mission_tools.mission_yaml_editor import load_yaml, save_yaml
from veaf_libs.i18n import language, t
from veaf_mission_mcp.airbase import set_airbase_coalition
from veaf_mission_mcp.mission_settings import set_briefing

from campaign_manager.mission_conditions import MissionConditions, set_conditions
from campaign_manager.models import COALITIONS, CampaignDefinition, CampaignState
from campaign_manager.turn_manager import describe_change, enemy_of, evaluate_objectives, garrison_strength, outcome

#: The data table, in the mission folder, the build turns into `veafCampaign.data`.
DATA_FILE = "src/campaign-data.yaml"

#: The factual part of the strategic briefing, one file per language, at the mission folder's root.
BRIEFING_FILE = "strategic-situation.{lang}.txt"

#: The languages the briefing is written in.
BRIEFING_LANGUAGES: tuple[str, ...] = ("fr", "en")

#: What a mission folder copied from the template leaves behind: build output is not a template.
_NOT_COPIED = shutil.ignore_patterns("build", "*.miz.bak", "__pycache__")


@dataclass(frozen=True)
class NextMissionReport:
    """What `campaign next` produced."""

    mission: int
    folder: Path
    created: bool
    """Whether the folder was copied from the template now, rather than refreshed."""
    airbases: list[str]
    deck: Path | None = None
    """The strategic briefing deck written next to the folder, or ``None`` when it could not be."""
    conditions: MissionConditions | None = None
    """The date, time and weather fixed in a folder created now; ``None`` on a refresh, which keeps them."""
    mission_deck: Path | None = None
    """The mission briefing deck, written when the folder holds a built mission."""


def mission_data(campaign: CampaignDefinition, state: CampaignState) -> dict[str, Any]:
    """Return the campaign data table of the next mission: `veafCampaign.data` at run time.

    Zones carry their position as the runtime can resolve it — an airbase name, or coordinates the
    runtime converts with `coord.LLtoLO` — so the tools need no projection of their own.

    Args:
        campaign: The validated campaign.
        state: The campaign state the mission starts from.

    Returns:
        Plain data, with the structure the state file has on its way back.
    """
    zones = []
    for zone in campaign.zones:
        zone_state = state.zones[zone.name]
        size = campaign.size_classes[zone.size]
        entry: dict[str, Any] = {
            "name": zone.name,
            "radius": zone.radius,
            "owner": zone_state.owner,
            "size": {
                "size": size.size,
                "defense": size.defense,
                "armor": size.armor,
                "long_range_sam": size.long_range_sam,
            },
        }
        if zone.location.airfield:
            entry["airbase"] = zone.location.airfield
        else:
            entry["lat"], entry["lon"] = zone.location.lat, zone.location.lon
        if zone.kind:
            entry["kind"] = zone.kind
        if zone.garrison:
            # the declared side's garrison: a side that takes the zone draws its own instead
            entry["garrison_list"] = list(zone.garrison)
            entry["declared_side"] = zone.side
        if zone_state.garrison is not None:
            entry["garrison"] = zone_state.garrison
        zones.append(entry)
    return {
        "format_version": state.format_version,
        "campaign": campaign.name,
        "mission": state.mission + 1,
        "missions": campaign.missions,
        "capture_seconds": campaign.capture_seconds,
        "assault_convoys": campaign.rules.assault_convoys,
        "assault_seconds": campaign.rules.assault_seconds,
        "state_write_seconds": campaign.state_write_seconds,
        "objectives": [{"kind": o.kind, "zones": list(o.zones)} for o in campaign.objectives],
        "zones": zones,
        "connections": [list(connection) for connection in campaign.connections],
        "sides": {side: {"reserve": dict(state.sides[side].reserve)} for side in COALITIONS},
        "scenery_destroyed": state.scenery_destroyed,
    }


def strategic_situation(campaign: CampaignDefinition, state: CampaignState) -> str:
    """Write the factual part of the next mission's strategic briefing, in the current language.

    The front, what changed in the last mission, the enemy's state, the objectives and the missions
    left. The narrative — what the enemy intends, what is asked of the players — is not here.

    Args:
        campaign: The validated campaign.
        state: The campaign state the mission starts from.

    Returns:
        Plain text, one fact per line.
    """
    mission = state.mission + 1
    lines = [t("campaign.briefing.header", mission=mission, missions=campaign.missions), ""]
    for side in (*COALITIONS, "neutral"):
        held = [zone.name for zone in campaign.zones if state.zones[zone.name].owner == side]
        if held:
            lines.append(t(f"campaign.briefing.held.{side}", zones=", ".join(held)))
    if state.history:
        last = state.history[-1]
        lines += ["", t("campaign.briefing.last_mission", mission=last["mission"])]
        lines += [f"- {describe_change(change)}" for change in last["changes"]] or [t("campaign.briefing.quiet")]
    enemy = enemy_of(campaign.player_side)
    reserve = state.sides[enemy].reserve
    lines += [
        "",
        t(
            "campaign.briefing.enemy_reserve",
            armor=reserve.get("armor", 0),
            air_defense=reserve.get("air_defense", 0),
            transport=reserve.get("transport", 0),
        ),
    ]
    for zone in campaign.zones:
        zone_state = state.zones[zone.name]
        if zone_state.owner != enemy:
            continue
        strength = garrison_strength(zone_state.garrison)
        if strength is None:
            lines.append(t("campaign.briefing.enemy_zone_unknown", zone=zone.name))
        else:
            lines.append(t("campaign.briefing.enemy_zone", zone=zone.name, strength=strength))
    lines += ["", t("campaign.briefing.objectives")]
    for objective, met in evaluate_objectives(campaign, state):
        mark = "[x]" if met else "[ ]"
        lines.append(f"{mark} {t(f'campaign.objective.{objective.kind}', zones=', '.join(objective.zones))}")
    left = max(campaign.missions - state.mission, 0)
    lines.append(t(f"campaign.briefing.outcome.{outcome(campaign, state)}", left=left))
    return "\n".join(lines) + "\n"


def _enable_campaign_module(mission_yaml: Path, era: str) -> None:
    """Turn the `CAMPAIGN` module on in `mission.yaml`, pointed at the data file; set the era."""
    data = load_yaml(mission_yaml)
    modules = data.setdefault("modules", {})
    if modules is None:
        modules = data["modules"] = {}
    modules["CAMPAIGN"] = {"enable": True, "data_file": DATA_FILE}
    mission = data.setdefault("mission", {})
    if mission is None:
        mission = data["mission"] = {}
    mission["era"] = era
    save_yaml(mission_yaml, data)


def opposition_for(players: tuple[int, int], player_side: str) -> dict[str, Any]:
    """Return the `opposition:` block of a mission flown by that many players.

    Sized for the most expected, and following the players connected: a squadron that comes short
    meets the opposition of who came, once the count has held for a few minutes.

    Args:
        players: The fewest and the most players expected.
        player_side: The coalition the players fly for.

    Returns:
        The block, as mission.yaml holds it.
    """
    return {"level": players[1], "follow": "players", "players_coalition": player_side.upper()}


def _set_opposition(mission_yaml: Path, block: dict[str, Any]) -> None:
    """Write the `opposition:` block of `mission.yaml`, keeping the rest of the file.

    The level is the campaign's; any other key already in the block was designed in the mission
    folder (a follow mode, a delay) and is kept, the way a refresh keeps the rest of the design.

    Args:
        mission_yaml: The mission's `mission.yaml`.
        block: The block `opposition_for` computed.
    """
    data = load_yaml(mission_yaml)
    existing = data.get("opposition")
    designed = dict(existing) if isinstance(existing, dict) else {}
    data["opposition"] = {**block, **designed, "level": block["level"]}
    save_yaml(mission_yaml, data)


def prepare_next_mission(
    campaign: CampaignDefinition,
    state: CampaignState,
    campaign_folder: Path,
    mission_folder: Path,
    players: tuple[int, int] | None = None,
) -> NextMissionReport:
    """Create, or refresh, the next mission's folder from the campaign state.

    A folder that does not exist yet is copied from the campaign's mission template, and its date, start
    time and weather are fixed there, one mission and no weather variant. One that does is only
    refreshed — the campaign files rewritten, the airbases set again — so the design already done in
    it, date, time and weather included, survives a second run.

    Args:
        campaign: The validated campaign.
        state: The campaign state the mission starts from.
        campaign_folder: The campaign folder, holding the mission template.
        mission_folder: Where the next mission goes.
        players: How many players are expected tonight, beating `campaign.yaml`'s `players`; with
            neither, the mission's `opposition:` block is left as it is.

    Returns:
        What was produced.

    Raises:
        FileNotFoundError: The template has no `mission.yaml`.
    """
    template = campaign_folder / campaign.mission_template
    created = not mission_folder.exists()
    if created:
        if not (template / "mission.yaml").is_file():
            raise FileNotFoundError(t("campaign.issue.no_template", path=template))
        shutil.copytree(template, mission_folder, ignore=_NOT_COPIED)

    airbases = []
    for zone in campaign.zones:
        if zone.location.airfield:
            owner = state.zones[zone.name].owner
            set_airbase_coalition(
                mission_folder, name=zone.location.airfield, coalition=owner, dynamic_spawn=owner in COALITIONS
            )
            airbases.append(zone.location.airfield)

    data_path = mission_folder / DATA_FILE
    data_path.parent.mkdir(parents=True, exist_ok=True)
    data_path.write_text(
        yaml.safe_dump(mission_data(campaign, state), allow_unicode=True, sort_keys=False), encoding="utf-8"
    )
    for lang in BRIEFING_LANGUAGES:
        with language(lang):
            text = strategic_situation(campaign, state)
        (mission_folder / BRIEFING_FILE.format(lang=lang)).write_text(text, encoding="utf-8")
    if created:
        # the mission flies with the facts even if nobody designs it further; a refresh leaves the
        # briefing alone, since what was written on top of them is design
        set_briefing(mission_folder, situation=strategic_situation(campaign, state))
    _enable_campaign_module(mission_folder / "mission.yaml", campaign.era)
    expected = players or campaign.players
    if expected:
        _set_opposition(mission_folder / "mission.yaml", opposition_for(expected, campaign.player_side))
    # date, time and weather are fixed once, when the folder is created: a refresh keeps what was set since
    conditions = set_conditions(campaign, state, mission_folder) if created else None
    return NextMissionReport(
        mission=state.mission + 1, folder=mission_folder, created=created, airbases=airbases, conditions=conditions
    )
