"""The briefing as kneeboard pages (FIX-COWORK-SESSION-FINDINGS ticket 08).

DCS stretches a kneeboard image onto the whole 2:3 page without keeping its proportions, so every page
is drawn at exactly that size, the maps fitted inside it rather than stretched.
"""

from __future__ import annotations

import io
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
from mission_briefing.models import ObjectiveArea, RadioPlan, Target
from PIL import Image
from presets_injector.presets_manager import KNEEBOARD_PAGE_SIZE


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


def test_the_flight_card_gives_heading_distance_and_frequencies() -> None:
    plan = FlightPlan(
        "plane",
        ("AJS37",),
        (
            Waypoint("FEET WET", -268000, 603000, 0, "BARO"),
            Waypoint("PUSH", -200000, 450000, 0, "BARO"),
        ),
    )
    radios = [RadioPlan(1, ("AJS37",), ((1, "Lion", 251.0), (2, "Senaki", 261.0)))]
    blocks = flight_card_blocks("Caucasus", [plan], [("Senaki-Kolkhi", -281782, 647280)], radios)
    text = "\n".join(line for _, lines in blocks for line in lines)
    assert "FEET WET" in text and "PUSH" in text
    # Senaki -> FEET WET: 287°, 25 nm; FEET WET -> PUSH: 294°, 90 nm (measured on the session's figures)
    assert "287°" in text and "25 nm" in text
    assert "294°" in text and "90 nm" in text
    assert "Lion" in text and "251.0" in text


def test_the_targets_page_lists_each_target_with_its_coordinates() -> None:
    area = ObjectiveArea("AdlerDepot", -162275, 463825, 250, (Target("AdlerDepot Fuel Tank 1", -162320, 463800),))
    blocks = targets_blocks("Caucasus", [("Adler depot", area)])
    assert blocks[0][0] == "Adler depot"
    assert blocks[0][1][0].startswith("AdlerDepot Fuel Tank 1")
    assert "N43" in blocks[0][1][0]


def test_page_names_sort_after_the_calibration_page_and_are_recognised() -> None:
    names = [page_name(n, slug) for n, slug in enumerate(["overview", "objective-adlerdepot", "flight-card"], 1)]
    assert names == ["01-briefing-overview.jpg", "02-briefing-objective-adlerdepot.jpg", "03-briefing-flight-card.jpg"]
    assert sorted(["00-veaf-calibration.png", *names])[0] == "00-veaf-calibration.png"
    assert all(is_kneeboard_page(name) for name in names)
    assert not is_kneeboard_page("00-veaf-calibration.png")
    assert not is_kneeboard_page("../01-briefing-x.jpg")
