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
    _MARGIN,
    KNEEBOARD_PAGE,
    KNEEBOARD_SAVED_PAGE,
    flight_card_blocks,
    is_kneeboard_page,
    map_and_photo_aspect,
    map_and_photo_page,
    map_page,
    page_name,
    targets_blocks,
    text_layout,
    text_pages,
)
from mission_briefing.models import ObjectiveArea, Target
from PIL import Image
from presets_injector.presets_manager import KNEEBOARD_PAGE_SIZE
from veaf_libs.coordinates import latlon_to_xy, offset_latlon, xy_to_latlon
from veaf_libs.magnetic import declination
from veaf_libs.mgrs import target_coordinates


def _jpeg_size(data: bytes) -> tuple[int, int]:
    with Image.open(io.BytesIO(data)) as image:
        assert image.format == "JPEG"
        return image.size


def test_the_page_is_the_kneeboards_two_by_three() -> None:
    assert KNEEBOARD_PAGE == KNEEBOARD_PAGE_SIZE


def test_a_page_is_saved_smaller_but_still_two_by_three_and_sharper_than_ed_s() -> None:
    """FIX-KNEEBOARD-PAGE-WEIGHT: drawn at the full page, saved at 1024 px so a mission does not gain 20 MB."""
    width, height = KNEEBOARD_SAVED_PAGE
    assert width * KNEEBOARD_PAGE[1] == height * KNEEBOARD_PAGE[0]
    assert 768 < width < KNEEBOARD_PAGE[0]


def test_a_landscape_map_is_fitted_not_stretched(tmp_path: Path) -> None:
    png = tmp_path / "map.png"
    Image.new("RGB", (1600, 900), (10, 200, 10)).save(png)
    data = map_page("3. Overview", png)
    assert _jpeg_size(data) == KNEEBOARD_SAVED_PAGE
    with Image.open(io.BytesIO(data)) as page:
        # the map keeps its 16:9: green across the width, white above and below it
        width, height = page.size
        assert page.getpixel((width // 2, height // 2))[1] > 150
        assert min(page.getpixel((width // 2, height - 10))) > 230


def test_a_long_text_runs_on_several_pages() -> None:
    blocks = [("Route", [f"W{n}. POINT {n} — N42°00'00\" E041°00'00\"" for n in range(1, 120)])]
    pages = text_pages("Flight card", blocks)
    assert len(pages) > 1
    assert all(_jpeg_size(page) == KNEEBOARD_SAVED_PAGE for page in pages)


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
    assert lines[2] == f"      Bullseye {round(90 - declination(lat, lon, when)):03d}°M / 10.0 nm"


def test_page_names_sort_after_the_calibration_page_and_are_recognised() -> None:
    names = [page_name(n, slug) for n, slug in enumerate(["overview", "objective-adlerdepot", "flight-card"], 1)]
    assert names == ["01-briefing-overview.jpg", "02-briefing-objective-adlerdepot.jpg", "03-briefing-flight-card.jpg"]
    assert sorted(["00-veaf-calibration.png", *names])[0] == "00-veaf-calibration.png"
    assert all(is_kneeboard_page(name) for name in names)
    assert not is_kneeboard_page("00-veaf-calibration.png")
    assert not is_kneeboard_page("../01-briefing-x.jpg")


def test_a_target_is_given_in_ddm_and_mgrs_and_vehicles_by_their_zone() -> None:
    """FIX-MARTEAU-PLAY-FINDINGS 04: DD°MM.mmm' and MGRS, never DMS; vehicles that move say it is their zone."""
    lat, lon = xy_to_latlon("Caucasus", -162275, 463825)
    ddm, mgrs = target_coordinates(lat, lon)
    area = ObjectiveArea(
        "AdlerDepot",
        -162275,
        463825,
        250,
        (Target("Fuel Tank", -162275, 463825), Target("Armour", -162275, 463825, mobile=True)),
    )
    ((_, lines),) = targets_blocks("Caucasus", date(2016, 6, 1), [("Adler depot", area)], None)
    assert ddm in lines[0] and '"' not in lines[0]
    assert lines[1] == f"      {mgrs}"
    assert "zone" in lines[2] and ddm in lines[2]


class TestOpenTrainingLayout:
    """The eight Open Trainings regenerated with 6.37.0: what their kneeboards showed wrong."""

    LONG_TITLE = "Z01 Front des îles — crêtes de Mount Longdon et Wireless Ridge, dépôt avancé d'Alamagan"

    #: The "Commandes" sheet of the Caucasus OT, as the 6.37.0 prompt writes it: one block per line.
    COMMANDS = (
        "Marqueur : carte F10, clic droit, « Ajouter un marqueur », tapez la commande, validez.",
        "Paliers : [ouvert] tout le monde · [pilote VEAF] pilote que le serveur connaît · [confiance] membre de "
        "confiance. Un pilote que le serveur ne connaît pas ajoute « , password <mot de passe du palier> » à son "
        "marqueur.",
        "-cas : une zone d'appui aérien rapproché, des groupes dispersés autour du marqueur, terminée par le menu "
        "F10 [pilote VEAF]",
        "-shilka, -manpads, -sa6, -sa11, -sa15, -samSR, -samLR : une défense aérienne à neutraliser ou à éviter "
        "[pilote VEAF]",
        "-armor, -infantry : une cible au sol [pilote VEAF]",
        "-convoy, dest <point> : une cible mobile [pilote VEAF]",
        "-cap <type> (ex. -cap Su-27) : une cible aérienne [pilote VEAF]",
        "-tankerlow, -tankerhigh : le ravitailleur le plus proche au FL120 / FL220 [pilote VEAF]",
        "-farp <nom>, -fob : une base avancée [pilote VEAF]",
        "-jtac (laser 1688), -smoke (option color), -tacan : désignation, marque visuelle, balise [ouvert]",
        "-point <nom> : nommer un point (la destination d'un convoi) [ouvert]",
        "-destroy : retire ce qui est à moins de 100 m du marqueur [confiance]",
        "F10 › VEAF › APPARITION › Page suivante › Mes spawns : retirer ce que vos marqueurs ont fait apparaître, "
        "tout ou un par un [ouvert]",
        "_spawn unit, name <type DCS>, multiplier 4 : un type précis, là où -armor tire au hasard [pilote VEAF]",
        "Options : side red/blue, defense 0-5, armor 0-5, size.",
        "Le reste passe par le menu F10 › VEAF : ZONES DE COMBAT, MOYENS, OPS PORTE-AVIONS.",
    )

    @staticmethod
    def _title_rows(data: bytes) -> list[int]:
        """The rows of a saved page holding the title's blue."""
        with Image.open(io.BytesIO(data)) as page:
            rgb = page.convert("RGB")
            width, height = rgb.size
            return [
                y
                for y in range(height // 4)
                if any((p := rgb.getpixel((x, y)))[2] > 120 and p[0] < 60 for x in range(0, width, 2))
            ]

    def test_a_long_title_is_wrapped_inside_the_page(self, tmp_path: Path) -> None:
        png = tmp_path / "map.png"
        Image.new("RGB", (900, 1350), (255, 255, 255)).save(png)
        long_rows, short_rows = self._title_rows(map_page(self.LONG_TITLE, png)), self._title_rows(map_page("Z01", png))
        assert max(long_rows) > max(short_rows) + 40  # a second line under the first
        with Image.open(io.BytesIO(map_page(self.LONG_TITLE, png))) as page:
            rgb = page.convert("RGB")
            margin = _MARGIN * rgb.width // KNEEBOARD_PAGE[0]
            right = [rgb.getpixel((x, y)) for x in range(rgb.width - margin + 4, rgb.width) for y in long_rows]
            assert all(min(p) > 200 for p in right)  # nothing drawn in the right margin

    def test_the_text_under_a_long_title_starts_below_it(self) -> None:
        (short,) = text_layout("Zones", [("Z01", ["ligne"])])
        (long,) = text_layout(self.LONG_TITLE, [("Z01", ["ligne"])])
        assert long[0][0] > short[0][0]

    def test_the_commands_sheet_of_sixteen_lines_holds_on_one_page(self) -> None:
        assert len(text_pages("Commandes", [(None, [line]) for line in self.COMMANDS])) == 1

    def test_a_zone_entry_is_never_cut_between_two_pages(self) -> None:
        entry = ["F10 > Zones de combat > Zone > Activer", "Centre : DDM N43°00.000' E041°00.000'", "MGRS 37T", "BE"]
        blocks: list[tuple[str | None, list[str]]] = [(f"Zone {n} - blindés - facile", entry) for n in range(40)]
        pages = text_layout("Zones de combat", blocks)
        assert len(pages) > 1
        for rows in pages:
            texts = [text for _, text, _ in rows]
            assert texts[0].startswith("Zone ") and texts[-1] == "BE"  # each page opens and closes on whole entries

    def test_a_block_taller_than_a_page_still_runs_on(self) -> None:
        pages = text_layout("Commandes", [(None, [f"Ligne {n}" for n in range(80)])])
        assert len(pages) > 1 and pages[0][0][1] == "Ligne 0"

    def test_the_one_photo_of_a_zone_shares_the_zoom_s_page(self, tmp_path: Path) -> None:
        png, photo = tmp_path / "map.png", tmp_path / "photo.jpg"
        aspect = map_and_photo_aspect(self.LONG_TITLE, (photo_file := self._photo(photo), "Légende"))
        assert aspect > 1  # the map takes a landscape half of the page
        Image.new("RGB", (1392, round(1392 / aspect)), (10, 200, 10)).save(png)
        data = map_and_photo_page(self.LONG_TITLE, png, (photo_file, "Légende"))
        assert _jpeg_size(data) == KNEEBOARD_SAVED_PAGE
        with Image.open(io.BytesIO(data)) as page:
            rgb = page.convert("RGB")
            middle = rgb.width // 2
            column = [rgb.getpixel((middle, y)) for y in range(rgb.height)]
            green = [y for y, p in enumerate(column) if p[1] > 150 and p[0] < 80]
            red = [y for y, p in enumerate(column) if p[0] > 150 and p[1] < 80]
            assert green and red and max(green) < min(red)  # the map above, the photo below
            assert red[-1] - green[0] > rgb.height * 0.6  # together they fill the page

    @staticmethod
    def _photo(path: Path) -> Path:
        Image.new("RGB", (1400, 980), (200, 10, 10)).save(path)
        return path
