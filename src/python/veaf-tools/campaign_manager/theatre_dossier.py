"""A persistent campaign's briefing: the theatre dossier, in place of the campaign and mission decks.

A persistent campaign has no mission objectives and no plan the players follow: no ATO, no weather (the server
sets it), no date, no "mission 1", no flight plan of the day. What guides them is the network: who holds what,
what feeds what, where to cut it (David, 2026-11-17). One deck, in the VEAF look, dated with the state it shows:

1. the cover; 2. the strategic situation; 3. the network map; 4. the enemy network and its critical nodes;
5. the air defences known; 6. the axes of effort; 7. our means; 8. the radio plan; 9. the player's guide;
10. the rules of engagement.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any

import yaml
from mission_briefing.briefing_pdf import Cover, MapSheet, write_pdf
from PIL import Image
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.presentation import Presentation as PresentationType
from pptx.util import Emu
from veaf_libs.i18n import t
from veaf_libs.map_tiles import Fetch
from veaf_libs.tankers import with_refuelling

from campaign_manager.air_defence_names import describe_garrison_entry
from campaign_manager.briefing_deck import (
    _BLUE,
    _GREY,
    _HEIGHT,
    _MARGIN,
    _WIDTH,
    Block,
    Page,
    _frame,
    _run,
    _titled_slide,
    _write_page,
    deck_file,
    map_notes,
    paginate,
)
from campaign_manager.briefing_prose import BriefingProse
from campaign_manager.campaign_checks import _group_types
from campaign_manager.intelligence import enemy_picture
from campaign_manager.models import CampaignDefinition, CampaignState, CampaignZone
from campaign_manager.network import NetworkPicture, network_picture
from campaign_manager.network_map import ReachCircle, render_network_map
from campaign_manager.strategic_map import OWNER_COLOURS, MapReport, zone_position
from campaign_manager.turn_manager import enemy_of

DOSSIER_FILE = "dossier-de-theatre.pptx"
NETWORK_MAP_FILE = "carte-du-reseau.png"
DEFENCE_MAP_FILE = "carte-des-defenses.png"

#: What each shop item costs when `economy.prices` does not say: `veafCampaignEconomy.PRICES`, which a test reads
#: back from the Lua.
SHOP_PRICES: dict[str, int] = {
    "jtac": 300,
    "illumination": 50,
    "smoke": 50,
    "cap": 400,
    "barcap": 400,
    "tanker": 300,
    "intel": 150,
    "capture": 250,
    "resupply": 200,
    "bomber": 1300,
    "assault": 300,
    "escort": 300,
    "cas": 500,
    "sead": 600,
}

#: What the players earn when `economy` does not say: `veafCampaign.DYNAMIC_DEFAULTS.economy`, which a test reads back
#: from the Lua (FIX-CAMPAIGN-ECONOMY-BALANCE 01, Foothold's rewards).
REWARDS: dict[str, int] = {
    "kill_ground": 10,
    "kill_sam": 30,
    "kill_air": 50,
    "kill_building": 100,
    "rescue": 200,
    "capture": 200,
}

#: The groups bought in the shop a zone holds at most when `economy.upgrades_per_zone` does not say:
#: `veafCampaign.DYNAMIC_DEFAULTS.economy.upgrades_per_zone`.
UPGRADES_PER_ZONE = 2

#: The reach a long-range SAM is assumed to have before it is measured, metres: `veafCampaignOps.ASSUMED_LONG_RANGE`.
ASSUMED_LONG_RANGE = 75000

#: The reach a medium-range one is assumed to have, metres: `veafCampaignOps.ASSUMED_MEDIUM_RANGE`.
ASSUMED_MEDIUM_RANGE = 40000

#: Words of an explicit garrison entry that name an air defence: what "our defences" lists.
_AIR_DEFENCE_WORDS = (
    "hawk",
    "patriot",
    "nasams",
    "iris",
    "rapier",
    "avenger",
    "stinger",
    "roland",
    "gepard",
    "vulcan",
    "chaparral",
    "sa",
    "airdefense",
)


@dataclass(frozen=True)
class DossierReport:
    """What writing the dossier produced."""

    path: Path
    network_map: MapReport
    pages: int
    pdf: Path | None = None
    """The same pages as a PDF, beside the deck."""


def owners_of(state: CampaignState) -> dict[str, str]:
    """Each zone's owner."""
    return {name: zone.owner for name, zone in state.zones.items()}


def shop_prices(campaign: CampaignDefinition) -> dict[str, int]:
    """The shop's prices: the defaults, overridden by `economy.prices`."""
    prices = dict(SHOP_PRICES)
    prices.update({str(k): int(v) for k, v in ((campaign.dynamic.get("economy") or {}).get("prices") or {}).items()})
    return prices


def shop_lines(campaign: CampaignDefinition) -> list[str]:
    """The shop as the player's guide lists it: each item with its price, then the zone upgrades.

    The upgrades' prices are their units' spawn price, drawn in game: the guide gives the rule, the limit, and what
    the air defence upgrades come to with the default unit prices (FIX-CAMPAIGN-ECONOMY-BALANCE 05).

    Args:
        campaign: The campaign, its `economy` settings read.

    Returns:
        One line per item, the zone upgrades last.
    """
    economy = campaign.dynamic.get("economy") or {}
    limit = economy.get("upgrades_per_zone", UPGRADES_PER_ZONE)
    lines = [
        t("campaign.dossier.guide.price", item=t(f"campaign.dossier.shop.{item}"), price=price)
        for item, price in shop_prices(campaign).items()
        if item in SHOP_PRICES  # an upgrade's entry of `economy.prices` is not a shop item of its own
    ]
    lines.append(t("campaign.dossier.guide.upgrades", limit=limit))
    return lines


def reward_line(campaign: CampaignDefinition) -> str:
    """What the players earn, as the player's guide says it: the defaults, overridden by `economy`.

    Args:
        campaign: The campaign, its `economy` settings read.

    Returns:
        One sentence with each reward.
    """
    economy = campaign.dynamic.get("economy") or {}
    return t("campaign.dossier.guide.rewards", **{key: int(economy.get(key, value)) for key, value in REWARDS.items()})


def _title(zone: CampaignZone, numbers: Mapping[str, int]) -> str:
    return f"{zone.label} (WP {numbers[zone.name]})" if zone.name in numbers else zone.label


def _names(campaign: CampaignDefinition, names: tuple[str, ...], numbers: Mapping[str, int]) -> str:
    return ", ".join(_title(campaign.zone(name), numbers) for name in names)


def _situation_page(prose: BriefingProse | None) -> Page:
    blocks = []
    for heading, section, part in (
        ("campaign.dossier.heading.mission", "mission", "mission"),
        ("campaign.deck.heading.political", "situation", "political"),
        ("campaign.deck.heading.economic", "situation", "economic"),
        ("campaign.dossier.heading.enemy_course", "situation", "enemy_course_of_action"),
        ("campaign.dossier.heading.friendly", "situation", "friendly"),
    ):
        paragraphs = prose.text(section, part) if prose else ()
        if paragraphs:
            blocks.append(Block(t(heading), paragraphs))
    if not blocks:
        blocks.append(Block(None, (t("campaign.deck.prose_missing"),)))
    return Page(t("campaign.dossier.title.situation"), blocks)


def network_blocks(campaign: CampaignDefinition, picture: NetworkPicture, numbers: Mapping[str, int]) -> list[Block]:
    """The enemy network's page: its factories and what they feed, its depots, its critical nodes."""
    blocks = []
    lines = [
        t(
            "campaign.dossier.network.factory",
            factory=_title(campaign.zone(f), numbers),
            zones=_names(campaign, fed, numbers) or "—",
        )
        for f, fed in picture.factories.items()
    ]
    blocks.append(Block(t("campaign.dossier.heading.factories"), tuple(lines) or (t("campaign.dossier.network.none"),)))
    lines = [
        t(
            "campaign.dossier.network.depot",
            depot=_title(campaign.zone(d), numbers),
            zones=_names(campaign, near, numbers) or "—",
        )
        for d, near in picture.depots.items()
    ]
    if lines:
        blocks.append(Block(t("campaign.dossier.heading.depots"), tuple(lines)))
    lines = [
        t(
            "campaign.dossier.network.critical",
            zone=_title(campaign.zone(node.zone), numbers),
            zones=_names(campaign, node.isolated, numbers),
        )
        for node in picture.critical
    ]
    blocks.append(
        Block(t("campaign.dossier.heading.critical"), tuple(lines) or (t("campaign.dossier.network.no_critical"),))
    )
    if picture.cut_off:
        blocks.append(Block(t("campaign.dossier.heading.cut_off"), (_names(campaign, picture.cut_off, numbers),)))
    return blocks


def defence_circles(campaign: CampaignDefinition, state: CampaignState) -> list[ReachCircle]:
    """A circle per long- or medium-range SAM, at the reach the campaign assumes until it is measured."""
    owners = owners_of(state)
    circles = []
    for zone in campaign.zones:
        owner = owners.get(zone.name, "neutral")
        if owner not in ("blue", "red"):
            continue
        # the longer reach only: a zone with both batteries is one circle
        if campaign.has_long_range_sam(zone):
            reach = ASSUMED_LONG_RANGE
        elif campaign.has_medium_range_sam(zone):
            reach = ASSUMED_MEDIUM_RANGE
        else:
            continue
        lat, lon = zone_position(campaign, zone)
        circles.append(ReachCircle(lat, lon, reach, OWNER_COLOURS[owner], zone.label))
    return circles


def _air_defence_page(campaign: CampaignDefinition, state: CampaignState, numbers: Mapping[str, int]) -> Page:
    owners = owners_of(state)
    player, enemy = campaign.player_side, enemy_of(campaign.player_side)
    enemy_lines = [
        f"{_title(zone, numbers)} : {enemy_picture(campaign, state, zone)}"
        for zone in campaign.zones
        if owners.get(zone.name) == enemy and campaign.has_sam_battery(zone)
    ]
    our_lines = []
    for zone in campaign.zones:
        if owners.get(zone.name) != player:
            continue
        # David, 2026-11-17: what each is, not its template's alias
        declared = [
            describe_garrison_entry(entry)
            for entry in (zone.garrison or ())
            if any(word in entry.lower().replace("-", "").split("_")[0] for word in _AIR_DEFENCE_WORDS)
        ]
        if campaign.has_medium_range_sam(zone):
            declared.insert(0, t("campaign.dossier.defence.medium_range"))
        if campaign.has_long_range_sam(zone):
            declared.insert(0, t("campaign.dossier.defence.long_range"))
        if declared:
            our_lines.append(f"{_title(zone, numbers)} : {' ; '.join(declared)}")
    return Page(
        t("campaign.dossier.title.defences"),
        [
            Block(
                t("campaign.dossier.heading.enemy_defences"),
                tuple(enemy_lines) or (t("campaign.dossier.defence.none"),),
            ),
            Block(
                t("campaign.dossier.heading.our_defences"), tuple(our_lines) or (t("campaign.dossier.defence.none"),)
            ),
        ],
        note=t("campaign.dossier.defence.note", km=ASSUMED_LONG_RANGE // 1000, medium_km=ASSUMED_MEDIUM_RANGE // 1000),
    )


def _axes_page(prose: BriefingProse | None) -> Page:
    axes = prose.effort() if prose else ()
    blocks = [Block(f"{index}. {axis.title}", axis.text) for index, axis in enumerate(axes, 1)]
    return Page(
        t("campaign.dossier.title.axes"),
        blocks or [Block(None, (t("campaign.dossier.axes.none"),))],
        note=t("campaign.dossier.axes.note"),
    )


def _means_page(
    campaign: CampaignDefinition, state: CampaignState, numbers: Mapping[str, int], types: Mapping[str, str]
) -> Page:
    owners = owners_of(state)
    player = campaign.player_side
    bases = [_title(z, numbers) for z in campaign.zones if owners.get(z.name) == player and z.location.airfield]
    depots = [_title(z, numbers) for z in campaign.zones if owners.get(z.name) == player and z.kind == "depot"]
    # David, 2026-11-17: each tanker says whether it is a boom or a basket
    support = [
        with_refuelling(str(name), types.get(str(name), ""))
        for name in ((campaign.dynamic.get("support") or {}).get("assets") or [])
    ]
    return Page(
        t("campaign.dossier.title.means"),
        [
            Block(t("campaign.dossier.heading.bases"), (", ".join(bases) or "—", t("campaign.dossier.means.slots"))),
            Block(
                t("campaign.dossier.heading.support"),
                (
                    ", ".join(support) or t("campaign.dossier.means.no_support"),
                    t("campaign.dossier.means.support_rule"),
                ),
            ),
            Block(t("campaign.dossier.heading.csar"), (t("campaign.dossier.means.csar"),)),
            Block(
                t("campaign.dossier.heading.logistics"),
                (
                    t("campaign.dossier.means.depots", depots=", ".join(depots) or "—"),
                    t("campaign.dossier.means.crates"),
                    t("campaign.dossier.means.warehouses"),
                ),
            ),
        ],
    )


def radio_rows(mission_folder: Path | None, side: str) -> dict[str, list[tuple[str, str, str]]]:
    """The radio plan the mission folder holds: by radio, its channels as ``(number, title, MHz)``.

    Args:
        mission_folder: The mission folder, or ``None``.
        side: The players' side.

    Returns:
        ``{"uhf": [...], "vhf": [...]}``, empty lists when the plan cannot be read.
    """
    rows: dict[str, list[tuple[str, str, str]]] = {"uhf": [], "vhf": []}
    path = mission_folder / "src" / "presets.yaml" if mission_folder else None
    if path is None or not path.is_file():
        return rows
    try:
        presets: dict[str, Any] = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError:
        return rows
    collections = presets.get("channels_collection") or {}

    def channel(alias: str) -> dict[str, Any]:
        for collection in collections.values():
            if isinstance(collection, dict) and isinstance(collection.get(alias), dict):
                return dict(collection[alias])
        return {}

    lists = (presets.get("channel_lists") or {}).get(side) or {}
    for radio, band in (("primary_1", "uhf"), ("primary_2", "vhf")):
        for number, alias in (lists.get(radio) or {}).items():
            name = alias.get("channel") if isinstance(alias, dict) else alias
            found = channel(str(name))
            freq = (found.get("freqs") or {}).get(band)
            rows[band].append(
                (f"{int(number):02d}", str(found.get("title") or name), f"{float(freq):.3f}" if freq else "—")
            )
    return rows


def _radio_page(mission_folder: Path | None, side: str) -> Page:
    rows = radio_rows(mission_folder, side)
    blocks = [
        Block(t(f"campaign.dossier.heading.{band}"), tuple(f"{n}  {title}  {mhz}" for n, title, mhz in lines))
        for band, lines in rows.items()
        if lines
    ]
    return Page(t("campaign.dossier.title.radio"), blocks or [Block(None, (t("campaign.dossier.radio.none"),))])


def guide_blocks(campaign: CampaignDefinition) -> list[Block]:
    """The game's rules for a pilot discovering it, with the shop's prices."""
    economy = campaign.dynamic.get("economy") or {}
    share = economy.get("landing_share", 50)
    shop = tuple(shop_lines(campaign))
    return [
        Block(t("campaign.dossier.guide.capture_title"), (t("campaign.dossier.guide.capture"),)),
        Block(
            t("campaign.dossier.guide.credits_title"),
            (t("campaign.dossier.guide.credits", share=share), reward_line(campaign)),
        ),
        Block(t("campaign.dossier.guide.shop_title"), shop),
        Block(t("campaign.dossier.guide.tasks_title"), (t("campaign.dossier.guide.tasks"),)),
        Block(t("campaign.dossier.guide.intel_title"), (t("campaign.dossier.guide.intel"),)),
        Block(t("campaign.dossier.guide.menu_title"), (t("campaign.dossier.guide.menu"),)),
        Block(t("campaign.dossier.guide.enemy_title"), (t("campaign.dossier.guide.enemy"),)),
    ]


def _roe_page(prose: BriefingProse | None) -> Page | None:
    blocks = []
    for part in ("targeting", "civilians", "self_defence"):
        paragraphs = prose.text("rules_of_engagement", part) if prose else ()
        if paragraphs:
            blocks.append(Block(t(f"campaign.deck.heading.roe_{part}"), tuple(f"– {p}" for p in paragraphs)))
    return Page(t("campaign.deck.title.roe"), blocks) if blocks else None


def _write_cover(
    deck: PresentationType, campaign: CampaignDefinition, prose: BriefingProse | None, day: date, contents: list[str]
) -> None:
    slide = deck.slides.add_slide(deck.slide_layouts[6])
    frame = _frame(slide, _MARGIN, Emu(1700000), Emu(6600000), Emu(3000000))
    _run(frame.paragraphs[0], t("campaign.deck.operation"), 40, bold=True)
    _run(
        frame.add_paragraph(),
        (prose.operation if prose and prose.operation else campaign.name).upper(),
        60,
        bold=True,
        colour=_BLUE,
    )
    _run(frame.add_paragraph(), t("campaign.dossier.cover", theatre=campaign.theatre), 22, colour=_GREY)
    _run(
        frame.add_paragraph(),
        t("campaign.dossier.state_of", day=day.strftime("%d/%m/%Y")),
        16,
        italic=True,
        colour=_GREY,
    )
    toc = _frame(slide, Emu(7700000), Emu(1500000), Emu(4100000), Emu(4600000))
    _run(toc.paragraphs[0], t("campaign.deck.contents"), 20, bold=True)
    for item in contents:
        _run(toc.add_paragraph(), item, 15)


def _write_map(deck: PresentationType, title: str, report: MapReport, legend_lines: list[str]) -> None:
    slide = _titled_slide(deck, title)
    with Image.open(report.path) as image:
        ratio = image.width / image.height
    height = _HEIGHT - Emu(1250000)
    width = min(int(height * ratio), Emu(8200000))
    height = int(width / ratio)
    slide.shapes.add_picture(str(report.path), _MARGIN, Emu(1050000), width=Emu(width), height=Emu(height))
    legend = _frame(slide, _MARGIN + width + Emu(300000), Emu(1200000), _WIDTH - width - 3 * _MARGIN, Emu(4500000))
    _run(legend.paragraphs[0], t("campaign.deck.legend"), 18, bold=True)
    for owner in ("blue", "red", "neutral"):
        paragraph = legend.add_paragraph()
        _run(paragraph, "● ", 18, colour=RGBColor(*OWNER_COLOURS[owner]))
        _run(paragraph, t(f"campaign.deck.legend_{owner}"), 15)
    for line in legend_lines:
        _run(legend.add_paragraph(), line, 14)
    if report.offline:
        _run(legend.add_paragraph(), t("campaign.deck.map_offline"), 12, italic=True, colour=_GREY)


def theatre_dossier(
    campaign: CampaignDefinition,
    state: CampaignState,
    prose: BriefingProse | None,
    folder: Path,
    numbers: Mapping[str, int],
    *,
    mission_folder: Path | None = None,
    day: date | None = None,
    cache_dir: Path | None = None,
    fetch: Fetch | None = None,
) -> DossierReport:
    """Write a persistent campaign's theatre dossier and its maps into a folder.

    Args:
        campaign: The validated campaign.
        state: The state it shows.
        prose: `briefing.yaml`, or ``None``.
        folder: Where the dossier goes, `missions/mission-01/`.
        numbers: Each zone's waypoint number.
        mission_folder: The mission folder, for its radio plan.
        day: The date of the state shown; today when omitted.
        cache_dir: Where map tiles are kept between runs.
        fetch: How a tile is downloaded (tests pass their own).

    Returns:
        Where the dossier is.
    """
    folder.mkdir(parents=True, exist_ok=True)
    owners = owners_of(state)
    enemy = enemy_of(campaign.player_side)
    network_map = render_network_map(
        campaign, owners, folder / NETWORK_MAP_FILE, numbers=numbers, cache_dir=cache_dir, fetch=fetch
    )
    defence_map = render_network_map(
        campaign,
        owners,
        folder / DEFENCE_MAP_FILE,
        numbers=numbers,
        circles=defence_circles(campaign, state),
        cache_dir=cache_dir,
        fetch=fetch,
    )
    sections: list[Page | None] = [
        _situation_page(prose),
        Page(t("campaign.dossier.title.network_map"), is_map=True),
        Page(
            t("campaign.dossier.title.enemy_network"),
            network_blocks(campaign, network_picture(campaign, owners, enemy), numbers),
        ),
        _air_defence_page(campaign, state, numbers),
        _axes_page(prose),
        _means_page(campaign, state, numbers, (_group_types(mission_folder) or {}) if mission_folder else {}),
        _radio_page(mission_folder, campaign.player_side),
        Page(t("campaign.dossier.title.guide"), guide_blocks(campaign)),
        _roe_page(prose),
    ]
    pages = [page for page in sections if page is not None]
    for number, page in enumerate(pages, 2):
        page.title = f"{number}. {page.title}"
    kinds = [t(f"campaign.dossier.legend.{kind}") for kind in ("airfield", "outpost", "factory", "depot")]
    network_legend = [*kinds, t("campaign.dossier.legend.numbers")]
    circles_legend = [
        t("campaign.dossier.legend.circles", km=ASSUMED_LONG_RANGE // 1000, medium_km=ASSUMED_MEDIUM_RANGE // 1000)
    ]
    day = day or date.today()
    deck = Presentation()
    deck.slide_width, deck.slide_height = _WIDTH, _HEIGHT
    _write_cover(deck, campaign, prose, day, [page.title for page in pages])
    sheets: list[Page | MapSheet] = []
    for page in pages:
        if page.is_map:
            _write_map(deck, page.title, network_map, network_legend)
            sheets.append(MapSheet(page.title, network_map.path, map_notes(network_map, network_legend)))
            continue
        for part in paginate(page):
            _write_page(deck, part)
            sheets.append(part)
        if page.title.endswith(t("campaign.dossier.title.defences")):
            _write_map(deck, page.title, defence_map, circles_legend)
            sheets.append(MapSheet(page.title, defence_map.path, map_notes(defence_map, circles_legend)))
    out = folder / deck_file(campaign, prose, DOSSIER_FILE, None)
    deck.save(str(out))
    cover = Cover(
        f"{t('campaign.deck.operation')} {(prose.operation if prose and prose.operation else campaign.name).upper()}",
        t("campaign.dossier.cover", theatre=campaign.theatre),
        t("campaign.dossier.state_of", day=day.strftime("%d/%m/%Y")),
        t("campaign.deck.contents"),
        [page.title for page in pages],
    )
    pdf = out.with_suffix(".pdf")
    write_pdf(pdf, cover, sheets)
    return DossierReport(path=out, network_map=network_map, pages=len(deck.slides), pdf=pdf)
