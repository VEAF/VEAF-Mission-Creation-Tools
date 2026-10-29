"""The briefing as kneeboard pages (FIX-COWORK-SESSION-FINDINGS ticket 08).

DCS stretches a kneeboard image onto the whole 2:3 page without keeping its proportions, so every page
is drawn at exactly that size, the maps fitted inside it rather than stretched.
"""

from __future__ import annotations

import io
from datetime import date
from pathlib import Path

from campaign_manager.mission_picture import FlightPlan, Waypoint
from mission_briefing.briefing_kneeboard import (
    KNEEBOARD_PAGE,
    flight_card_blocks,
    is_kneeboard_page,
    map_page,
    page_name,
    targets_blocks,
    text_pages,
)
from mission_briefing.models import ObjectiveArea, Target
from PIL import Image
from presets_injector.presets_manager import KNEEBOARD_PAGE_SIZE
from veaf_libs.coordinates import latlon_to_xy, offset_latlon, xy_to_latlon
from veaf_libs.magnetic import declination


def _jpeg_size(data: bytes) -> tuple[int, int]:
    with Image.open(io.BytesIO(data)) as image:
        assert image.format == "JPEG"
        return image.size


def test_the_page_is_the_kneeboards_two_by_three() -> None:
    assert KNEEBOARD_PAGE == KNEEBOARD_PAGE_SIZE


def test_a_landscape_map_is_fitted_not_stretched(tmp_path: Path) -> None:
    png = tmp_path / "map.png"
    Image.new("RGB", (1600, 900), (10, 200, 10)).save(png)
    data = map_page("3. Overview", png)
    assert _jpeg_size(data) == KNEEBOARD_PAGE
    with Image.open(io.BytesIO(data)) as page:
        # the map keeps its 16:9: green across the width, white above and below it
        width, height = page.size
        assert page.getpixel((width // 2, height // 2))[1] > 150
        assert min(page.getpixel((width // 2, height - 10))) > 230


def test_a_long_text_runs_on_several_pages() -> None:
    blocks = [("Route", [f"W{n}. POINT {n} — N42°00'00\" E041°00'00\"" for n in range(1, 120)])]
    pages = text_pages("Flight card", blocks)
    assert len(pages) > 1
    assert all(_jpeg_size(page) == KNEEBOARD_PAGE for page in pages)


def test_the_flight_card_gives_heading_and_distance_and_no_radio_plan() -> None:
    """FEAT-OBJECTIVE-BRIEFING-QUALITY 06: the presets are already in the cockpits, the card keeps the route."""
    plan = FlightPlan(
        "plane",
        ("AJS37",),
        (
            Waypoint("FEET WET", -268000, 603000, 0, "BARO"),
            Waypoint("PUSH", -200000, 450000, 0, "BARO"),
        ),
    )
    blocks = flight_card_blocks("Caucasus", date(2016, 6, 1), [plan], [("Senaki-Kolkhi", -281782, 647280)])
    text = "\n".join(line for _, lines in blocks for line in lines)
    assert "FEET WET" in text and "PUSH" in text
    # Senaki -> FEET WET: 287°M, 25 nm; FEET WET -> PUSH: 293°M, 90 nm. The grid gave 287° and 294°: on the
    # Caucasus in 2016 its 6 degrees off true nearly cancel the 6.5 of declination (FIX-BRIEFING-MAGNETIC-HEADINGS).
    assert "287°M" in text and "25 nm" in text
    assert "293°M" in text and "90 nm" in text
    assert len(blocks) == 1 and all("Radio" not in (heading or "") for heading, _ in blocks)
    assert "MHz" not in text


def test_the_targets_page_lists_each_target_with_its_coordinates() -> None:
    area = ObjectiveArea("AdlerDepot", -162275, 463825, 250, (Target("AdlerDepot Fuel Tank 1", -162320, 463800),))
    blocks = targets_blocks("Caucasus", date(2016, 6, 1), [("Adler depot", area)])
    assert blocks[0][0] == "Adler depot"
    assert blocks[0][1][0].startswith("AdlerDepot Fuel Tank 1")
    assert "N43" in blocks[0][1][0]


def test_a_target_says_where_it_stands_from_the_bullseye_magnetic() -> None:
    """FIX-BRIEFING-MAGNETIC-HEADINGS: the bullseye bearing was on the grid, with no unit."""
    lat, lon = xy_to_latlon("Caucasus", -162275, 463825)
    when = date(2016, 6, 1)
    east = latlon_to_xy("Caucasus", *offset_latlon(lat, lon, 90.0, 18520))
    area = ObjectiveArea("AdlerDepot", -162275, 463825, 250, (Target("Fuel Tank", *east),))
    ((_, lines),) = targets_blocks("Caucasus", when, [("Adler depot", area)], (-162275, 463825))
    # On the ellipsoid: the grid read 10.1 nm, its scale 7 degrees from the projection's meridian.
    assert lines[1] == f"      Bullseye {round(90 - declination(lat, lon, when)):03d}°M / 10.0 nm"


def test_page_names_sort_after_the_calibration_page_and_are_recognised() -> None:
    names = [page_name(n, slug) for n, slug in enumerate(["overview", "objective-adlerdepot", "flight-card"], 1)]
    assert names == ["01-briefing-overview.jpg", "02-briefing-objective-adlerdepot.jpg", "03-briefing-flight-card.jpg"]
    assert sorted(["00-veaf-calibration.png", *names])[0] == "00-veaf-calibration.png"
    assert all(is_kneeboard_page(name) for name in names)
    assert not is_kneeboard_page("00-veaf-calibration.png")
    assert not is_kneeboard_page("../01-briefing-x.jpg")
