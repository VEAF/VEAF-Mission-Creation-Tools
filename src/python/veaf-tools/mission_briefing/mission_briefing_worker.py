"""Build a one-shot mission's VEAF briefing from the built mission (FEAT-MCP-MISSION-BRIEFING ticket 04).

The objective-mission prompt's §3, page for page, in the mission's language: what the assistant wrote
(title, context, mission, objectives, threats, flow) around what the **built** `.miz` holds — date,
time, weather, bullseye, flights, support, carriers, QRA, flight plan, the presets in the cockpits,
each target where it stands. Then the maps become the DCS briefing pictures, in the mission folder
(durable) and in the built `.miz` (no rebuild needed), listed first for the players' side and neutral; the
other side is left alone (`briefing-pictures-red-then-blue`). The pictures this writes carry :data:`PICTURE_PREFIX` keys
and are replaced on every run.
"""

from __future__ import annotations

import io
import math
import re
import unicodedata
from dataclasses import replace
from pathlib import Path
from typing import Any

import luadata
from campaign_manager.briefing_deck import (
    _BLUE,
    _GREY,
    _HEIGHT,
    _MARGIN,
    _WIDTH,
    Block,
    Page,
    _frame,
    _join,
    _run,
    _write_page,
    paginate,
)
from campaign_manager.mission_pages import (
    ato_page,
    carrier_line,
    clock,
    frequencies_page,
    line,
    mhz,
    navigation_page,
    picture_page,
    weather_lines,
)
from campaign_manager.mission_picture import (
    NM,
    MissionPicture,
    _flight_plans,
    find_built_mission,
    read_mission_picture,
)
from mission_tools.mission_constants import DEFAULT_SCRIPTS_LOCATION
from mission_tools.mission_yaml_editor import load_yaml
from mission_tools.miz_backup import backup_before_write
from mission_tools.miz_tools import DcsMission, list_members, read_miz, write_miz
from PIL import Image
from pptx import Presentation
from pptx.presentation import Presentation as PresentationType
from pptx.util import Emu
from veaf_libs.coordinates import to_dms, xy_to_latlon
from veaf_libs.i18n import current_language, language, t
from veaf_libs.map_tiles import OSM, Fetch, TileSource
from veaf_libs.mission_table import indexed
from veaf_libs.terrain_elevation import grid_for_theatre, metres_to_feet
from veaf_mission_mcp.add_sound import _folder_l10n
from veaf_mission_mcp.mission_folder import load_folder_mission, save_folder_mission

from mission_briefing.briefing_kneeboard import (
    KNEEBOARD_FOLDER,
    MAP_ASPECT,
    flight_card_blocks,
    is_kneeboard_page,
    map_page,
    page_name,
    targets_blocks,
    text_pages,
)
from mission_briefing.briefing_maps import OVERVIEW_FILE, render_objective_zoom, render_overview_map, zoom_file
from mission_briefing.briefing_pdf import Cover, MapSheet, write_pdf
from mission_briefing.mission_reader import departures, group_position, objective_area, radio_plans, slot_flights
from mission_briefing.models import (
    BriefingContent,
    BriefingReport,
    Objective,
    ObjectiveArea,
    RadioPlan,
    SlotFlight,
    Threat,
)

#: The deck, in the mission folder.
DECK_FILE = Path("docs") / "briefing.pptx"

#: The PDF of the same pages, in the mission folder.
PDF_FILE = Path("docs") / "briefing.pdf"

#: The maps, in the mission folder.
MAPS_FOLDER = Path("docs") / "maps"

#: The folder the build writes the weather variants into, beside its own `.miz`.
VARIANTS_FOLDER = "missions"

#: The resource keys of the pictures this writes; anything else in the briefing is left alone.
PICTURE_PREFIX = "MCP_Briefing_"

#: The width a DCS briefing picture is brought down to, pixels.
_PICTURE_WIDTH = 1600

#: The mission-table key of each side's briefing pictures; the slots of no side get them too, as ``neutral``.
_PICTURE_KEYS = {"blue": "pictureFileNameB", "red": "pictureFileNameR", "neutral": "pictureFileNameN"}


def _mission_language(folder: Path) -> str:
    """`mission.language` of `mission.yaml`, the tools' language otherwise."""
    path = folder / "mission.yaml"
    mission = (load_yaml(path).get("mission") if path.is_file() else None) or {}
    return str(mission.get("language") or current_language()) if isinstance(mission, dict) else current_language()


def _bullseye_line(theatre: str, picture: MissionPicture, start: tuple[str, float, float] | None) -> str:
    """The bullseye in DMS, and its bearing and range from the players' departure when there is one."""
    lat, lon = xy_to_latlon(theatre, *picture.bullseye)
    if start is None:
        return to_dms(lat, lon)
    name, x, y = start
    dx, dy = picture.bullseye[0] - x, picture.bullseye[1] - y
    bearing = round(math.degrees(math.atan2(dy, dx))) % 360 or 360
    return t(
        "campaign.mission_deck.bullseye",
        dms=to_dms(lat, lon),
        bearing=f"{bearing:03d}",
        range=round(math.hypot(dx, dy) / NM),
        base=name,
    )


def _threat_line(threat: Threat) -> str:
    """``SA-6 Gori — SA-6 : engagement ≈ 13 nm, détection ≈ 30 nm (source)``, with what is known."""
    name = f"{threat.name} — {threat.family}" if threat.family else threat.name
    ranges = []
    if threat.engagement_nm:
        ranges.append(t("mission_briefing.engagement", nm=f"{threat.engagement_nm:g}"))
    if threat.detection_nm:
        ranges.append(t("mission_briefing.detection", nm=f"{threat.detection_nm:g}"))
    if not ranges:
        return name
    source = f" ({threat.source})" if threat.source else ""
    return line(name, ", ".join(ranges) + source)


#: A waypoint number as the texts write it: ``W3``, ``WP3``, ``W 3``.
_WAYPOINT_REFERENCE = re.compile(r"\bW(?:P)?\s?(\d{1,2})\b")


def _folded(text: str) -> str:
    """Lower case, accents removed: ``Nœud`` and ``noeud`` compare equal."""
    return (
        unicodedata.normalize("NFKD", text.replace("œ", "oe").replace("Œ", "OE"))
        .encode("ascii", "ignore")
        .decode()
        .lower()
    )


def _waypoint_warnings(content: BriefingContent, picture: MissionPicture) -> list[str]:
    """Compare the ``W<n>`` of the assistant's words with the route the built mission carries.

    A route gains a point (the build's BULLSEYE, one more objective) after the texts were written, and
    every number after it is false: measured on a run whose briefing and F10 labels said W3, W4, W6 for
    points that were W4, W5, W7 (FIX-DEMO-VIDEO-FINDINGS 07). Nobody without PowerPoint can re-read the
    rendered pages, so the numbers are checked here: one past the end of the longest route, or one the
    same line contradicts by naming another point of the first route.

    Args:
        content: What the assistant wrote.
        picture: What the built mission says.

    Returns:
        One warning per number that does not fit; none when the mission has no route.
    """
    if not picture.flight_plans:
        return []
    longest = max(len(plan.waypoints) for plan in picture.flight_plans)
    names = [wp.name for wp in picture.flight_plans[0].waypoints]
    lines = [
        *content.context,
        *content.mission,
        *content.air_opposition,
        *content.air_defences,
        *content.other,
        *(text for objective in content.objectives for text in (objective.title, *objective.task)),
    ]
    warnings = []
    for text in lines:
        numbers = {int(found) for found in _WAYPOINT_REFERENCE.findall(text)}
        for number in sorted(numbers):
            if number > longest:
                warnings.append(
                    f"Waypoint W{number} in {text!r}: the route has {longest} point(s) after the departure "
                    "(counting the BULLSEYE the build adds); numbers past it point at nothing."
                )
        if len(numbers) == 1:
            number = next(iter(numbers))
            for index, name in enumerate(names, 1):
                if index != number and re.search(rf"\b{re.escape(_folded(name))}\b", _folded(text)):
                    warnings.append(
                        f"Waypoint {name} is W{index} on the route, not W{number} as {text!r} says: "
                        "numbers shift when a point (the BULLSEYE) is declared before the one named."
                    )
    return warnings


def _slot_lines(flights: dict[str, list[SlotFlight]]) -> dict[str, list[str]]:
    """The ATO's lines for what each base offers in dynamic slots: ``A-10C_2 — Archer : 390.0 MHz``."""
    return {
        airfield: [
            t(
                "mission_briefing.slot_flight",
                aircraft=flight.aircraft,
                callsign=flight.callsign or "—",
                frequency=mhz(flight.frequency) if flight.frequency else "—",
            )
            for flight in found
        ]
        for airfield, found in flights.items()
    }


def _situation_page(
    content: BriefingContent,
    picture: MissionPicture,
    starts: list[tuple[str, float, float]],
) -> Page:
    blocks = [Block(t("campaign.mission_deck.heading.context"), content.context)] if content.context else []
    if content.mission:
        blocks.append(Block(t("campaign.mission_deck.heading.mission"), tuple(f"– {item}" for item in content.mission)))
    start = starts[0] if starts else None
    if start is None and picture.carriers:
        start = (picture.carriers[0].name, picture.carriers[0].x, picture.carriers[0].y)
    blocks.append(
        Block(t("campaign.mission_deck.heading.bullseye"), (_bullseye_line(picture.theatre, picture, start),))
    )
    departure = [
        t("campaign.mission_deck.departure_carrier", carrier=c.name, heading=f"{c.heading:03d}")
        for c in picture.carriers
    ]
    dynamic = {airfield.name for airfield in picture.airfields}
    for name, _, _ in starts:
        flights = [flight.callsign for flight in picture.flights if flight.base == name]
        if flights:
            departure.append(line(name, _join(flights)))
        elif name in dynamic:
            departure.append(t("campaign.mission_deck.departure_airfield", airfield=name))
    if departure:
        blocks.append(Block(t("campaign.mission_deck.heading.departure"), tuple(departure)))
    threats = [f"– {_threat_line(threat)}" for threat in content.threats]
    if picture.qra_zones:
        threats.append(f"– {t('mission_briefing.qra')}")
    if threats:
        blocks.append(Block(t("campaign.mission_deck.heading.threat"), tuple(threats)))
    blocks.append(Block(t("campaign.mission_deck.heading.weather"), weather_lines(picture)))
    date = t("campaign.mission_deck.date", day=picture.date.day, month=picture.date.month, year=picture.date.year)
    blocks.append(
        Block(
            t("campaign.mission_deck.heading.time"),
            (t("campaign.mission_deck.time", date=date, time=clock(picture.start_time)),),
        )
    )
    return Page(t("campaign.mission_deck.title.situation"), blocks)


def _flow_page(content: BriefingContent, picture: MissionPicture) -> Page:
    blocks = []
    if content.objectives:
        blocks.append(
            Block(
                t("campaign.mission_deck.heading.objectives"),
                tuple(f"{n}. {objective.title}" for n, objective in enumerate(content.objectives, 1)),
            )
        )
    air = list(content.air_opposition) or ([t("mission_briefing.qra")] if picture.qra_zones else [])
    blocks.append(Block(t("campaign.mission_deck.heading.air"), tuple(air) or (t("campaign.mission_deck.no_air"),)))
    defences = [_threat_line(threat) for threat in content.threats] + list(content.air_defences)
    if defences:
        blocks.append(Block(t("campaign.mission_deck.heading.air_defence"), tuple(defences)))
    others = list(content.other)
    tankers = [s.callsign for s in picture.support if s.role != "awacs"]
    if tankers:
        others.append(t("campaign.mission_deck.refuelling", tankers=_join(tankers)))
    diversions = [a.name for a in picture.airfields] + [c.name for c in picture.carriers]
    if diversions:
        others.append(t("campaign.mission_deck.diversion", fields=_join(diversions)))
    if picture.plane_guard:
        others.append(t("campaign.mission_deck.plane_guard"))
    if picture.csar:
        others.append(t("campaign.mission_deck.csar"))
    if others:
        blocks.append(Block(t("campaign.mission_deck.heading.other"), tuple(others)))
    return Page(t("campaign.mission_deck.title.flow"), blocks)


def _frequencies_page(picture: MissionPicture, plans: list[RadioPlan]) -> Page:
    """The presets the build put in the cockpits, radio by radio; the mission's channels without them."""
    if not plans:
        return frequencies_page(picture)
    blocks = []
    for plan in plans:
        lines = [
            t("mission_briefing.channel", channel=channel, name=name, frequency=mhz(freq))
            for channel, name, freq in plan.channels
            if name
        ]
        # a channel with no name is a bare frequency (an FM radio's thirty): one line for all of them
        unnamed = [
            t("mission_briefing.channel_unnamed", channel=channel, frequency=mhz(freq))
            for channel, name, freq in plan.channels
            if not name
        ]
        if unnamed:
            lines.append(" · ".join(unnamed))
        blocks.append(
            Block(t("mission_briefing.radio", radio=plan.radio, flights=", ".join(plan.flights)), tuple(lines))
        )
    control = [carrier_line(carrier) for carrier in picture.carriers]
    if control:
        blocks.append(Block(t("campaign.mission_deck.heading.control"), tuple(control)))
    return Page(t("campaign.mission_deck.title.frequencies"), blocks)


def _targets_page(theatre: str, areas: list[tuple[Objective, ObjectiveArea]], warnings: list[str]) -> Page:
    grid = grid_for_theatre(theatre)
    if grid is None and any(area.targets for _, area in areas):
        warnings.append(
            f"No terrain elevation grid for {theatre} on this PC: the target coordinates carry no altitude "
            "(see the terrain_elevation action)."
        )
    blocks = [Block(None, (t("mission_briefing.targets_format"),))]
    for objective, area in areas:
        lines = []
        for target in area.targets:
            height = grid.elevation_at(target.x, target.y) if grid else None
            elevation = f" — {metres_to_feet(height):.0f} ft" if height is not None else ""
            lines.append(line(target.name, f"{to_dms(*xy_to_latlon(theatre, target.x, target.y))}{elevation}"))
        blocks.append(Block(objective.title, tuple(lines) or (t("mission_briefing.no_target"),)))
    return Page(t("mission_briefing.title.targets"), blocks)


def _cover_date_line(picture: MissionPicture) -> str:
    """The cover's line under the subtitle: ``13 octobre 2015 — 06h15 locale``."""
    date = t("campaign.mission_deck.date", day=picture.date.day, month=picture.date.month, year=picture.date.year)
    return f"{date} — {t('campaign.mission_deck.local', time=clock(picture.start_time))}"


def _write_cover(deck: PresentationType, title: str, picture: MissionPicture, contents: list[str]) -> None:
    slide = deck.slides.add_slide(deck.slide_layouts[6])
    frame = _frame(slide, _MARGIN, Emu(1700000), Emu(6800000), Emu(3200000))
    _run(frame.paragraphs[0], title, 54, bold=True, colour=_BLUE)
    _run(frame.add_paragraph(), t("campaign.mission_deck.subtitle"), 22, colour=_GREY)
    _run(frame.add_paragraph(), _cover_date_line(picture), 16, italic=True, colour=_GREY)
    toc = _frame(slide, Emu(7900000), Emu(1500000), Emu(3900000), Emu(4600000))
    _run(toc.paragraphs[0], t("campaign.deck.contents"), 20, bold=True)
    for item in contents:
        _run(toc.add_paragraph(), item, 14)


def _jpeg(png: Path) -> bytes:
    """A map as a DCS briefing picture: JPEG, brought down to :data:`_PICTURE_WIDTH` when wider."""
    with Image.open(png) as image:
        picture = image.convert("RGB")
    if picture.width > _PICTURE_WIDTH:
        picture = picture.resize((_PICTURE_WIDTH, round(picture.height * _PICTURE_WIDTH / picture.width)))
    buffer = io.BytesIO()
    picture.save(buffer, format="JPEG", quality=90)
    return buffer.getvalue()


def _list_pictures(mission: DcsMission, pictures: dict[str, str], side: str) -> list[str]:
    """Replace this tool's pictures in the players' side's and the neutral lists; return the other side's list."""
    content = mission.mission_content
    if content is None:
        raise ValueError("Not a valid DCS mission (missing 'mission' content)")
    resources = {k: v for k, v in (mission.map_resource_content or {}).items() if not str(k).startswith(PICTURE_PREFIX)}
    resources.update(pictures)
    mission.map_resource_content = resources
    for key in (_PICTURE_KEYS[side], _PICTURE_KEYS["neutral"]):
        kept = [str(entry) for entry in indexed(content.get(key)) if not str(entry).startswith(PICTURE_PREFIX)]
        content[key] = [*pictures, *kept]
    other = _PICTURE_KEYS["red" if side == "blue" else "blue"]
    return [str(entry) for entry in indexed(content.get(other))]


#: A picture file this tool writes: what it may delete on a later run, and nothing else.
_GENERATED_PICTURE = re.compile(r"briefing-[A-Za-z0-9._-]+\.jpg")


def _stale_pictures(l10n: Path, previous: set[str], kept: set[str]) -> list[Path]:
    """Return the pictures an earlier run wrote and this one no longer writes, safe to delete.

    The names come from the mission's `mapResource`, and a mission may come from anywhere: only a
    name this tool generates, resolved inside `l10n/DEFAULT/`, is returned (security review, 6.31.0).

    Args:
        l10n: The mission folder's `l10n/DEFAULT/`.
        previous: The file names the `MCP_Briefing_` resources pointed at.
        kept: The file names this run writes.

    Returns:
        The files to delete, sorted.
    """
    root = l10n.resolve()
    stale = []
    for name in sorted(previous - kept):
        if _GENERATED_PICTURE.fullmatch(name) is None:
            continue
        path = (root / name).resolve()
        if path.parent == root:
            stale.append(path)
    return stale


def built_archives(folder: Path, miz: Path) -> list[Path]:
    """The build's own `.miz`, then each weather variant the build wrote into `missions/`.

    The players fly a variant, not the build's own archive: pictures written into the latter only
    reached them after a rebuild (FIX-COWORK-SESSION-FINDINGS 01).

    Args:
        folder: The mission folder.
        miz: The build's own `.miz` (`find_built_mission`).

    Returns:
        Every archive the briefing goes into, the build's own first.
    """
    return [miz, *sorted((folder / VARIANTS_FOLDER).glob("*.miz"))]


def _write_kneeboard_folder(folder: Path, pages: dict[str, bytes]) -> None:
    """Put the kneeboard pages in the mission folder, so a rebuild carries them; drop the ones no longer written."""
    target = _folder_l10n(folder).parent.parent / KNEEBOARD_FOLDER
    if target.is_dir():
        for stale in target.iterdir():
            if is_kneeboard_page(stale.name) and stale.name not in pages:
                stale.unlink(missing_ok=True)
    if pages:
        target.mkdir(parents=True, exist_ok=True)
    for name, data in pages.items():
        (target / name).write_bytes(data)


def _write_pictures(
    folder: Path, archives: list[Path], maps: list[Path], side: str, kneeboard: dict[str, bytes]
) -> tuple[list[str], list[str]]:
    """Put the maps and the kneeboard pages in the mission folder and every built `.miz`, backed up first.

    Returns:
        The resource keys, in display order, and the other side's pictures found.
    """
    files = {f"briefing-{path.stem}.jpg": _jpeg(path) for path in maps}
    pictures = {f"{PICTURE_PREFIX}{path.stem}": f"briefing-{path.stem}.jpg" for path in maps}

    mission = load_folder_mission(folder)
    previous = {str(v) for k, v in (mission.map_resource_content or {}).items() if str(k).startswith(PICTURE_PREFIX)}
    other = _list_pictures(mission, pictures, side)
    l10n = _folder_l10n(folder)
    l10n.mkdir(parents=True, exist_ok=True)
    for stale in _stale_pictures(l10n, previous, set(files)):
        stale.unlink(missing_ok=True)
    for name, data in files.items():
        (l10n / name).write_bytes(data)
    save_folder_mission(mission, folder)
    _write_kneeboard_folder(folder, kneeboard)

    for miz in archives:
        built = read_miz(miz)
        _list_pictures(built, pictures, side)
        additional: dict[str, Any] = {f"{DEFAULT_SCRIPTS_LOCATION}/{name}": data for name, data in files.items()}
        additional.update({f"{KNEEBOARD_FOLDER}/{name}": data for name, data in kneeboard.items()})
        if f"{DEFAULT_SCRIPTS_LOCATION}/mapResource" not in list_members(miz):
            # `write_miz` rewrites a `mapResource` member the archive has; one it lacks has to be supplied
            additional[f"{DEFAULT_SCRIPTS_LOCATION}/mapResource"] = (
                "mapResource = \n"
                + luadata.serialize(
                    built.map_resource_content, indent="  ", indent_level=0, always_provide_keyname=True, sort=True
                )
            ).encode()
        backup_before_write(miz)
        write_miz(built, miz, additional_files=additional)
    return list(pictures), other


def _kneeboard_pages(
    folder: Path,
    picture: MissionPicture,
    areas: list[tuple[Objective, ObjectiveArea]],
    threats: list[tuple[Threat, tuple[float, float]]],
    starts: list[tuple[str, float, float]],
    radios: list[RadioPlan],
    tiles: dict[str, Any],
) -> dict[str, bytes]:
    """The briefing for the knee: the maps drawn for the 2:3 page, the flight card, the targets.

    Returns:
        Page file name -> JPEG, in the order the kneeboard shows them.
    """
    theatre = picture.theatre
    maps_folder = folder / MAPS_FOLDER / "kneeboard"
    overview = render_overview_map(
        picture, areas, threats, starts, maps_folder / OVERVIEW_FILE, aspect=MAP_ASPECT, **tiles
    )
    sheets: list[tuple[str, bytes]] = [("overview", map_page(t("campaign.mission_deck.title.tactical"), overview.path))]
    for objective, area in areas:
        zoom = render_objective_zoom(
            theatre, objective, area, threats, maps_folder / zoom_file(area.zone), aspect=MAP_ASPECT, **tiles
        )
        title = t("campaign.mission_deck.title.zoom", zone=area.zone)
        sheets.append((Path(zoom_file(area.zone)).stem, map_page(title, zoom.path)))
    card_blocks = flight_card_blocks(theatre, list(picture.flight_plans), starts, radios)
    card = text_pages(t("mission_briefing.kneeboard.flight_card"), card_blocks) if card_blocks else []
    target_blocks = targets_blocks(theatre, [(objective.title, area) for objective, area in areas])
    targets = text_pages(t("mission_briefing.title.targets"), target_blocks) if target_blocks else []
    for slug, pages in (("flight-card", card), ("targets", targets)):
        sheets += [(slug if n == 1 else f"{slug}-{n}", page) for n, page in enumerate(pages, 1)]
    return {page_name(n, slug): data for n, (slug, data) in enumerate(sheets, 1)}


def build_mission_briefing(
    folder: Path,
    content: BriefingContent,
    *,
    side: str = "blue",
    source: TileSource = OSM,
    cache_dir: Path | None = None,
    fetch: Fetch | None = None,
    kneeboard: bool = True,
) -> BriefingReport:
    """Write a one-shot mission's briefing deck and maps, and put the maps in its DCS briefing.

    Args:
        folder: The mission folder, built (`build_mission`).
        content: What the assistant writes: the scenario's words.
        side: The players' side.
        source: Where the map tiles come from.
        cache_dir: Where map tiles are kept between runs.
        fetch: How a map tile is downloaded (tests pass their own).
        kneeboard: Whether the maps, a flight card and the targets also go into every aircraft's kneeboard.

    Returns:
        The deck, its page count, the maps, the pictures' keys, the `.miz` read, and the warnings.

    Raises:
        ValueError: If the mission is not built, or an objective names no trigger zone of the mission.
    """
    miz = find_built_mission(folder)
    if miz is None:
        raise ValueError(f"No built mission in {folder}: run build_mission first, the briefing reads the built .miz.")
    with language(_mission_language(folder)):
        return _build(folder, miz, content, side, source, cache_dir, fetch, kneeboard)


def _build(
    folder: Path,
    miz: Path,
    content: BriefingContent,
    side: str,
    source: TileSource,
    cache_dir: Path | None,
    fetch: Fetch | None,
    kneeboard: bool,
) -> BriefingReport:
    built = read_miz(miz)
    table = built.mission_content or {}
    picture = read_mission_picture(miz, side, folder)
    dynamic = bool(picture.airfields)
    if not dynamic:  # the scaffold's dynamic-slot templates are nobody's cockpit here
        picture = replace(picture, flight_plans=_flight_plans(table, side, templates=False))
    theatre = picture.theatre
    enemy = "red" if side == "blue" else "blue"
    warnings: list[str] = _waypoint_warnings(content, picture)
    areas = [(objective, objective_area(table, objective.zone, enemy)) for objective in content.objectives]
    threats = []
    for threat in content.threats:
        position = group_position(table, threat.group)
        if position is None:
            warnings.append(f"Threat {threat.name!r}: no group named {threat.group!r} in the built mission, not drawn.")
        else:
            threats.append((threat, position))
    starts = departures(table, side, theatre, templates=dynamic)

    maps_folder = folder / MAPS_FOLDER
    tiles: dict[str, Any] = {"cache_dir": cache_dir, "fetch": fetch, "source": source, "side": side}
    overview = render_overview_map(picture, areas, threats, starts, maps_folder / OVERVIEW_FILE, **tiles)
    zooms = [
        render_objective_zoom(theatre, objective, area, threats, maps_folder / zoom_file(area.zone), **tiles)
        for objective, area in areas
    ]

    situation = _situation_page(content, picture, starts)
    ato = ato_page(picture, content.pilots, content.loadouts, _slot_lines(slot_flights(built, side, theatre)))
    flow = _flow_page(content, picture)
    navigation = navigation_page(theatre, picture)
    if navigation:
        navigation.title = t("mission_briefing.title.flight_plan")
    radios = radio_plans(table, side, templates=dynamic)
    frequencies = _frequencies_page(picture, radios)
    targets = _targets_page(theatre, areas, warnings)
    closing = [flow, *([navigation] if navigation else []), frequencies, targets]
    titles = [
        situation.title,
        ato.title,
        t("campaign.mission_deck.title.tactical"),
        *[t("campaign.mission_deck.title.zoom", zone=area.zone) for _, area in areas],
        *[page.title for page in closing],
    ]
    numbered = [f"{n}. {title}" for n, title in enumerate(titles, 1)]
    situation.title, ato.title = numbered[0], numbered[1]
    for page, title in zip(closing, numbered[-len(closing) :], strict=True):
        page.title = title

    deck = Presentation()
    deck.slide_width, deck.slide_height = _WIDTH, _HEIGHT
    _write_cover(deck, content.title, picture, numbered)
    sheets: list[Page | MapSheet] = []
    for part in [*paginate(situation), *paginate(ato)]:
        _write_page(deck, part)
        sheets.append(part)
    legend = [
        (t("campaign.deck.legend"), True),
        (t("mission_briefing.legend.objectives"), False),
        *([(t("mission_briefing.legend.threats"), False)] if threats else []),
        *([(t("mission_briefing.legend.departures"), False)] if starts else []),
        *([(t("campaign.mission_deck.legend.qra"), False)] if picture.qra_zones else []),
        *([(t("campaign.mission_deck.legend.carrier"), False)] if picture.carriers else []),
        *([(t("campaign.mission_deck.legend.support"), False)] if picture.support else []),
        *([(t("campaign.mission_deck.legend.waypoints"), False)] if navigation else []),
    ]
    picture_page(deck, numbered[2], overview.path, legend)
    sheets.append(MapSheet(numbered[2], overview.path, legend))
    for title, (objective, area), zoom in zip(numbered[3 : 3 + len(areas)], areas, zooms, strict=True):
        notes = [(objective.title, True), *[(text, False) for text in objective.task]]
        if area.targets:
            notes += [(t("mission_briefing.heading.targets"), True), (_join([x.name for x in area.targets]), False)]
        picture_page(deck, title, zoom.path, notes)
        sheets.append(MapSheet(title, zoom.path, notes))
    for part in [part for page in closing for part in paginate(page)]:
        _write_page(deck, part)
        sheets.append(part)
    out = folder / DECK_FILE
    out.parent.mkdir(parents=True, exist_ok=True)
    deck.save(str(out))
    pdf = folder / PDF_FILE
    cover = Cover(
        content.title,
        t("campaign.mission_deck.subtitle"),
        _cover_date_line(picture),
        t("campaign.deck.contents"),
        numbered,
    )
    pdf_pages = write_pdf(pdf, cover, sheets)

    maps = [overview.path, *(zoom.path for zoom in zooms)]
    pages = _kneeboard_pages(folder, picture, areas, threats, starts, radios, tiles) if kneeboard else {}
    archives = built_archives(folder, miz)
    keys, other = _write_pictures(folder, archives, maps, side, pages)
    if other:
        warnings.append(
            f"{_PICTURE_KEYS['red' if side == 'blue' else 'blue']} holds {len(other)} picture(s): a player of no "
            "side sees red's then blue's (known limitation briefing-pictures-red-then-blue). Left as they are."
        )
    offline = overview.offline or any(zoom.offline for zoom in zooms)
    if offline:
        warnings.append("Map tiles could not be downloaded: the maps stand on a plain background.")
    return BriefingReport(
        out, len(deck.slides), maps, keys, miz, offline, warnings, pdf, pdf_pages, archives, list(pages)
    )
