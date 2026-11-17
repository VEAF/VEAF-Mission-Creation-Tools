"""A persistent campaign's kneeboard: the network map, the zone table, the radio plan and a cheat sheet.

No weather page and no objectives of the day: the server sets the weather and the campaign has no mission plan
(David, 2026-11-17). The pages go into the mission folder's ``KNEEBOARD/IMAGES``, which every aircraft shows, and
are written again at every `campaign next`.
"""

from __future__ import annotations

import re
from collections.abc import Callable, Mapping
from pathlib import Path

from mission_briefing.briefing_kneeboard import KneeboardTable, map_page, page_name, table_pages, text_pages
from veaf_libs.coordinates import latlon_to_xy
from veaf_libs.i18n import t
from veaf_libs.map_tiles import Fetch
from veaf_libs.mgrs import target_coordinates

from campaign_manager.models import CampaignDefinition, CampaignState
from campaign_manager.network_map import kind_of, render_network_map
from campaign_manager.strategic_map import zone_position
from campaign_manager.theatre_dossier import owners_of, radio_rows, shop_prices

#: Where the pages go, under the mission folder.
KNEEBOARD_DIR = Path("src") / "mission" / "KNEEBOARD" / "IMAGES"

#: The pages this module writes: what it may replace or delete on a later run.
_OURS = re.compile(r"\d{2}-briefing-campaign-[a-z0-9-]+\.jpg")

#: The map rendered for the kneeboard, beside the pages' sources.
KNEEBOARD_MAP = Path("src") / "kneeboard-network.png"

Elevation = Callable[[float, float], float | None]


def _elevation(theatre: str) -> Elevation:
    """Ground height at a DCS point, metres, from the theatre's elevation grid; ``None`` when it is not there."""
    try:
        from veaf_libs.terrain_elevation import grid_for_theatre

        grid = grid_for_theatre(theatre)
    except Exception:  # noqa: BLE001 — no grid (offline, unknown theatre) is a dash in the table
        grid = None
    if grid is None:
        return lambda _x, _y: None
    return grid.elevation_at


def zone_rows(
    campaign: CampaignDefinition, numbers: Mapping[str, int], elevation: Elevation | None = None
) -> list[tuple[str, ...]]:
    """The zone table: waypoint, name and kind, coordinates (DDM, MGRS), elevation in feet, airfield frequency.

    Args:
        campaign: The validated campaign.
        numbers: Each zone's waypoint number.
        elevation: The ground height at a DCS point; the theatre's grid when omitted.

    Returns:
        A row per zone, by waypoint number, the zones without one last.
    """
    from presets_injector.airfield_channels_manager import load_reference

    height = elevation or _elevation(campaign.theatre)
    reference = {str(entry["name"]): entry for entry in load_reference(campaign.theatre).values()}
    ordered = sorted(campaign.zones, key=lambda zone: (numbers.get(zone.name, 10_000), zone.name))
    rows: list[tuple[str, ...]] = []
    for zone in ordered:
        lat, lon = zone_position(campaign, zone)
        ddm, mgrs = target_coordinates(lat, lon)
        x, y = latlon_to_xy(campaign.theatre, lat, lon)
        metres = height(x, y)
        feet = f"{metres / 0.3048:.0f} ft" if metres is not None else "—"
        airfield = reference.get(zone.location.airfield or "", {})
        freq = " / ".join(f"{airfield[band]:.3f}" for band in ("vhf", "uhf") if band in airfield) or "—"
        rows.append(
            (
                str(numbers.get(zone.name, "—")),
                f"{zone.label} ({t(f'campaign.kneeboard.kind.{kind_of(zone)}')})",
                f"{ddm.removeprefix('DDM ')} {mgrs.removeprefix('MGRS ')}",
                feet,
                freq,
            )
        )
    return rows


def kneeboard_pages(
    campaign: CampaignDefinition,
    state: CampaignState,
    mission_folder: Path,
    numbers: Mapping[str, int],
    *,
    elevation: Elevation | None = None,
    cache_dir: Path | None = None,
    fetch: Fetch | None = None,
) -> dict[str, bytes]:
    """The persistent campaign's kneeboard pages, by file name.

    Args:
        campaign: The validated campaign.
        state: The state they show.
        mission_folder: The mission folder: its radio plan, and where the map is drawn.
        numbers: Each zone's waypoint number.
        elevation: The ground height at a DCS point (tests pass their own).
        cache_dir: Where map tiles are kept.
        fetch: How a tile is downloaded.

    Returns:
        The pages, JPEG.
    """
    png = render_network_map(
        campaign,
        owners_of(state),
        mission_folder / KNEEBOARD_MAP,
        numbers=numbers,
        aspect=2 / 3,
        cache_dir=cache_dir,
        fetch=fetch,
    )
    pages: list[tuple[str, bytes]] = [("campaign-network", map_page(t("campaign.kneeboard.title.map"), png.path))]
    columns = tuple(t(f"campaign.kneeboard.column.{c}") for c in ("wp", "zone", "position", "elevation", "frequency"))
    table: KneeboardTable = (None, columns, (0.07, 0.3, 0.33, 0.12, 0.18), zone_rows(campaign, numbers, elevation))
    for index, page in enumerate(table_pages(t("campaign.kneeboard.title.zones"), [table]), 1):
        pages.append((f"campaign-zones-{index}", page))
    radio_tables: list[KneeboardTable] = [
        (
            t(f"campaign.dossier.heading.{band}"),
            ("#", t("campaign.kneeboard.column.channel"), "MHz"),
            (0.12, 0.6, 0.28),
            list(rows),
        )
        for band, rows in radio_rows(mission_folder, campaign.player_side).items()
        if rows
    ]
    if radio_tables:
        for index, page in enumerate(table_pages(t("campaign.dossier.title.radio"), radio_tables), 1):
            pages.append((f"campaign-radio-{index}", page))
    prices = shop_prices(campaign)
    blocks: list[tuple[str | None, list[str]]] = [
        (t("campaign.dossier.guide.menu_title"), [t("campaign.dossier.guide.menu")]),
        (t("campaign.dossier.guide.capture_title"), [t("campaign.dossier.guide.capture")]),
        (
            t("campaign.dossier.guide.shop_title"),
            [
                t("campaign.dossier.guide.price", item=t(f"campaign.dossier.shop.{i}"), price=p)
                for i, p in prices.items()
            ],
        ),
    ]
    for index, page in enumerate(text_pages(t("campaign.kneeboard.title.cheat_sheet"), blocks), 1):
        pages.append((f"campaign-cheat-sheet-{index}", page))
    return {page_name(number, slug): data for number, (slug, data) in enumerate(pages, 1)}


def write_kneeboard(mission_folder: Path, pages: Mapping[str, bytes]) -> Path:
    """Put the pages in the mission folder, replacing the ones a previous run wrote.

    Args:
        mission_folder: The mission folder.
        pages: The pages, by file name.

    Returns:
        The folder they are in.
    """
    target = mission_folder / KNEEBOARD_DIR
    if target.is_dir():
        for stale in target.iterdir():
            if _OURS.fullmatch(stale.name) and stale.name not in pages:
                stale.unlink(missing_ok=True)
    target.mkdir(parents=True, exist_ok=True)
    for name, data in pages.items():
        (target / name).write_bytes(data)
    return target
