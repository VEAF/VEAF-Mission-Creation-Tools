"""The second regeneration of "Marteau du Golan"'s briefing, after #1210 (FIX-BRIEFING-PARITY-MARTEAU-2).

One class per point of the retest: the overview, the combat map, the frequencies, the prerequisite, the
kneeboard flight card, the ATO.
"""

from __future__ import annotations

import io
from dataclasses import replace
from datetime import date
from pathlib import Path

import pytest
from campaign_manager.map_canvas import MapCanvas, flight_level
from campaign_manager.mission_picture import Airfield, FlightPlan, Support, Waypoint, read_mission_picture
from mission_briefing.briefing_kneeboard import flight_card_tables, table_pages
from mission_briefing.briefing_maps import render_overview_map, retraces
from mission_briefing.mission_briefing_worker import (
    _ato_page,
    _frequencies_page,
    _named_plan,
    _objective_blocks,
    _objective_title,
    _placed,
    _with_slot_bases,
)
from mission_briefing.models import (
    BriefingContent,
    GroundPicture,
    MapLine,
    Objective,
    ObjectiveArea,
    PackageFlight,
    RadioPlan,
    SupportAsset,
)
from objective_mission_fixture import KHOBI_ZONE, objective_mission
from PIL import Image
from veaf_libs.i18n import language
from veaf_mission_mcp.build_briefing import _status


def _white(url: str) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (256, 256), (255, 255, 255)).save(buffer, format="PNG")
    return buffer.getvalue()


class TestTheOverview:
    """Point 1: no bases, Ramat David out of the frame, no tanker level, the helicopters' route keyed twice."""

    def test_a_flight_level_to_the_nearest_five_levels(self) -> None:
        assert flight_level(18_000 * 0.3048) == "FL180"
        assert flight_level(18_500 * 0.3048) == "FL185"
        assert flight_level(5_000 * 0.3048) == "FL050"

    def test_a_drawn_line_retracing_a_route_is_left_out(self) -> None:
        route = [(0.0, 0.0), (10_000.0, 0.0), (10_000.0, 10_000.0)]
        along = MapLine(
            "Route helicopteres", (0, 85, 255), 3, True, ((0.0, 500.0), (9_000.0, -800.0), (10_500.0, 9_000.0))
        )
        front = MapLine("Ligne de contact", (204, 0, 0), 4, False, ((-5_000.0, 30_000.0), (5_000.0, 30_000.0)))
        assert retraces(along, [route])
        assert not retraces(front, [route])

    def test_the_bases_the_tanker_levels_and_one_helicopter_route(self, tmp_path: Path) -> None:
        picture = read_mission_picture(objective_mission(tmp_path), "blue", tmp_path)
        _, x, y, _ = KHOBI_ZONE
        helicopter = FlightPlan("helicopter", ("AH-64D",), (Waypoint("MASADA", x - 8000, y - 4000, 300, "RADIO"),))
        tanker = Support(
            "Texaco 1-1", "tanker", "KC-135", 290.1, None, ((x - 40_000, y), (x - 50_000, y)), 18_000 * 0.3048
        )
        picture = replace(picture, flight_plans=[*picture.flight_plans, helicopter], support=[tanker])
        drawn = MapLine("Route helicopteres", (0, 85, 255), 3, True, ((x - 8000, y - 4100), (x - 7900, y - 3900)))
        ground = GroundPicture(lines=(drawn,), enemy_bases=(("Senaki", x + 20_000, y + 5_000),))
        report = render_overview_map(
            picture,
            [],
            [],
            [("Kobuleti", x - 30_000, y)],
            tmp_path / "o.png",
            cache_dir=tmp_path,
            fetch=_white,
            aspect=2.0,
            width=1200,
            ground=ground,
        )
        assert {"Senaki", "Kobuleti", "key enemy_base", "key departure", "key helicopter_route"} <= set(report.symbols)
        assert "key line 0" not in report.symbols  # the drawn route retraces the helicopters' own

    def test_a_dynamic_slot_base_is_a_departure(self, tmp_path: Path) -> None:
        picture = read_mission_picture(objective_mission(tmp_path), "blue", tmp_path)
        picture = replace(picture, airfields=[Airfield("Senaki-Kolkhi", None, None, None, None)])
        content = BriefingContent(title="T", flights=(PackageFlight("Ninja", base="Senaki-Kolkhi", aircraft="F-16C"),))
        starts = _with_slot_bases([], picture, content)
        assert [name for name, _, _ in starts] == ["Senaki-Kolkhi"]

    def test_a_route_leaves_from_the_base_its_flights_take_off_from(self) -> None:
        plan = FlightPlan("plane", ("F-16C_50",), ())
        flights = (
            PackageFlight("Ninja", base="Ramat David", aircraft="F-16C"),
            PackageFlight("Blade", base="Rosh Pina", aircraft="AH-64D"),
        )
        assert _named_plan(plan, flights).departure == "Ramat David"


class TestTheCombatMap:
    """Point 2: the key over SA-11 and W8, long titles running into one another, scattered QRA arcs."""

    def test_no_qra_and_objectives_named_as_the_flight_plan(self, tmp_path: Path) -> None:
        picture = read_mission_picture(objective_mission(tmp_path), "blue", tmp_path)
        assert picture.qra_zones
        name, x, y, radius = KHOBI_ZONE
        area = ObjectiveArea(name, x, y, radius, label="KHOBI")
        report = render_overview_map(
            picture,
            [(Objective(name, "Un titre long qui chevauchait les autres"), area)],
            [],
            [],
            tmp_path / "c.png",
            cache_dir=tmp_path,
            fetch=_white,
            combat_area=True,
        )
        assert "key qra" not in report.symbols

    def test_the_corner_counts_the_labels_still_to_set(self, tmp_path: Path) -> None:
        canvas = MapCanvas("Caucasus", [(42.0, 41.6), (42.3, 42.1)], 3_000, tmp_path, _white, aspect=2.0, width=800)
        canvas.turn()
        width, _ = canvas.background.size
        labels = [(width - 60.0, 20.0, width - 40.0, 40.0)] * 3  # three labels to set in the top-right corner
        left, top, _, _ = canvas.free_corner((100, 100), labels)
        assert (left, top) != (width - canvas.px(12) - 100, canvas.px(12))

    def test_a_bottom_corner_sits_above_the_scale_and_the_credit(self, tmp_path: Path) -> None:
        canvas = MapCanvas("Caucasus", [(42.0, 41.6), (42.3, 42.1)], 3_000, tmp_path, _white, aspect=2.0, width=800)
        canvas.turn()
        canvas.scale(5_000, "5 km")
        for _ in range(4):
            box = canvas.free_corner((50, 50))
            assert box[3] <= canvas.background.size[1] - canvas._foot


class TestFrequencyHeadings:
    """Point 3: two blocks headed "Radio 1 / 2 — Ninja, Arctic, Archer, Jedi, Blade"."""

    def test_each_block_says_which_flights_carry_it_on_which_radio(self, tmp_path: Path) -> None:
        picture = read_mission_picture(objective_mission(tmp_path), "blue", tmp_path)
        package = ((1, "Package", 291.0),)
        bases = ((1, "Kobuleti", 133.0),)
        plans = [
            RadioPlan(1, ("F-16C_50",), package),
            RadioPlan(2, ("AH-64D_BLK_II",), package),
            RadioPlan(2, ("F-16C_50",), bases),
            RadioPlan(1, ("AH-64D_BLK_II",), bases),
        ]
        flights = (PackageFlight("Ninja", aircraft="F-16C"), PackageFlight("Blade", aircraft="AH-64D"))
        with language("fr"):
            headings = [block.heading for block in _frequencies_page(picture, plans, flights).blocks]
        assert headings[:2] == ["Radio 1 — Ninja · Radio 2 — Blade", "Radio 1 — Blade · Radio 2 — Ninja"]

    def test_two_plans_alike_say_their_first_channel(self, tmp_path: Path) -> None:
        picture = read_mission_picture(objective_mission(tmp_path), "blue", tmp_path)
        plans = [
            RadioPlan(1, ("F-16C_50",), ((1, "Package", 291.0),)),
            RadioPlan(1, ("F-16C_50",), ((1, "Tanker", 290.1),)),
        ]
        with language("fr"):
            headings = [
                block.heading
                for block in _frequencies_page(picture, plans, (PackageFlight("Ninja", aircraft="F-16C"),)).blocks
            ]
        assert headings[:2] == ["Radio 1 — Ninja — Ch. 1 : Package", "Radio 1 — Ninja — Ch. 1 : Tanker"]


class TestPrerequisite:
    """Point 4: the SA-6 the helicopters wait for was "secondary"."""

    def test_a_status_wins_over_the_operation(self, tmp_path: Path) -> None:
        picture = read_mission_picture(objective_mission(tmp_path), "blue", tmp_path)
        (tmp_path / "mission.yaml").write_text(
            "modules:\n  COMBATZONE:\n    combat_zones:\n      - type: operation\n        zone_name: Op\n"
            "        tasking_orders:\n          - zone_name: Khan\n",
            encoding="utf-8",
        )
        areas = [
            (Objective("Khan", "La ligne"), ObjectiveArea("Khan", 0, 0, 1)),
            (Objective("Sa6", "Le SA-6", status="prerequisite"), ObjectiveArea("Sa6", 0, 0, 1)),
            (Objective("Sa11", "Le SA-11"), ObjectiveArea("Sa11", 0, 0, 1)),
        ]
        placed = _placed(areas, picture, tmp_path)
        with language("fr"):
            blocks = _objective_blocks(placed, set())
            title = _objective_title(*placed[1])
        assert [(block.heading, block.paragraphs) for block in blocks] == [
            ("Préalables", ("– Le SA-6",)),
            ("Objectifs principaux", ("1. La ligne",)),
            ("Objectifs secondaires", ("– Le SA-11",)),
        ]
        assert title.endswith("(préalable)")

    def test_the_parameter_takes_three_statuses(self) -> None:
        assert _status(None) == "" and _status("prerequisite") == "prerequisite"
        with pytest.raises(ValueError, match="status"):
            _status("optional")


class TestFlightCardTable:
    """Point 5: the kneeboard flight card was a list, without the altitudes."""

    def test_a_table_per_route_with_the_altitude(self) -> None:
        plan = FlightPlan(
            "plane",
            ("Ninja",),
            (Waypoint("PUSH", -228000, -30000, 67, "BARO"), Waypoint("KHAN", -203930, -7802, 939, "BARO")),
        )
        with language("fr"):
            ((heading, columns, _, rows),) = flight_card_tables("Syria", date(2024, 6, 1), [plan], [("Ramat David", -259121, -75105)])
        assert heading == "Ninja" and columns[2] == "Altitude"
        assert rows[0][0] == "Ramat David" and rows[1][0] == "W1 PUSH" and rows[1][2] == "220 ft BARO"
        assert rows[2][1].endswith(" nm") and rows[2][4].startswith("N33")

    def test_a_long_table_runs_on_with_its_header(self) -> None:
        rows = [
            (f"W{n}", "055° / 3 nm", "2 000 ft BARO", "2 500 ft", "N33°19'39.20\" E036°05'46.29\"") for n in range(60)
        ]
        pages = table_pages(
            "Carte de vol",
            [("Ninja", ("Point", "Cap", "Alt", "Relief", "Position"), (0.2, 0.2, 0.2, 0.15, 0.25), rows)],
        )
        assert len(pages) >= 2
        assert all(page[:2] == b"\xff\xd8" for page in pages)


class TestAtoSupport:
    """Point 6: no tanker level, no JTAC, no fat cow, no GCI in the ATO."""

    def test_the_level_and_the_support_the_mission_has_no_group_for(self, tmp_path: Path) -> None:
        picture = read_mission_picture(objective_mission(tmp_path), "blue", tmp_path)
        tanker = Support("Texaco 1-1", "tanker", "KC-135", 290.1, "60Y", ((0.0, 0.0),), 18_000 * 0.3048)
        picture = replace(picture, support=[tanker])
        content = BriefingContent(title="T", support=(SupportAsset("Abu Nada", "JTAC", "FM 35.55", "Code 1511"),))
        with language("fr"):
            page = _ato_page(content, picture, [])
        (support,) = [table for table in page.tables if table.heading == "Moyens de soutien"]
        assert support.columns[-1] == "Niveau"
        assert support.rows == (
            ("Texaco 1-1", "ravitailleur", "KC-135", "290.1 MHz", "60Y", "FL180"),
            ("Abu Nada", "JTAC", "Code 1511", "FM 35.55", "—", "—"),
        )


class TestTheReviewFindings:
    """pr-code-review of #1212."""

    def test_a_tanker_leaving_its_parking_has_the_level_of_its_first_point_in_the_air(self) -> None:
        from campaign_manager.mission_picture import _cruise_altitude

        group = {
            "route": {"points": {1: {"type": "TakeOffParking", "alt": 30}, 2: {"type": "Turning Point", "alt": 5486.4}}}
        }
        assert flight_level(_cruise_altitude(group)) == "FL180"
        assert _cruise_altitude({"route": {"points": {1: {"type": "TakeOffParking", "alt": 30}}}}) == 0.0

    def test_a_base_named_in_another_case_is_still_the_routes(self) -> None:
        plan = FlightPlan("plane", ("Ninja",), (Waypoint("PUSH", 0.0, 0.0, 100, "BARO"),), departure="ramat david")
        with language("fr"):
            ((_, _, _, rows),) = flight_card_tables(
                "Syria", date(2024, 6, 1), [plan], [("Rosh Pina", 1.0, 1.0), ("Ramat David", 50_000.0, 0.0)]
            )
        assert rows[0][0] == "Ramat David"

    def test_the_channel_a_heading_names_is_its_own_number(self, tmp_path: Path) -> None:
        picture = read_mission_picture(objective_mission(tmp_path), "blue", tmp_path)
        plans = [
            RadioPlan(1, ("F-16C_50",), ((1, "", 30.0), (3, "AWACS", 282.2))),
            RadioPlan(1, ("F-16C_50",), ((1, "Package", 291.0),)),
        ]
        with language("fr"):
            headings = [
                block.heading
                for block in _frequencies_page(picture, plans, (PackageFlight("Ninja", aircraft="F-16C"),)).blocks
            ]
        assert headings[0].endswith("Ch. 3 : AWACS") and headings[1].endswith("Ch. 1 : Package")
