"""A one-shot mission's briefing deck and DCS briefing pictures (FEAT-MCP-MISSION-BRIEFING ticket 04)."""

from __future__ import annotations

import io
import zipfile
from pathlib import Path
from typing import NamedTuple

import pytest
from mission_briefing.mission_briefing_worker import PICTURE_PREFIX, build_mission_briefing
from mission_briefing.models import BriefingContent, BriefingReport, Objective, Threat
from mission_tools.miz_tools import read_miz, write_miz
from objective_mission_fixture import KHOBI_ZONE, objective_mission
from offline import offline
from PIL import Image
from pptx import Presentation
from veaf_libs.coordinates import to_dms, xy_to_latlon
from veaf_libs.i18n import language
from veaf_mission_mcp.mission_folder import load_folder_mission
from veaf_mission_mcp.mission_table import indexed

CONTENT = BriefingContent(
    title="Marteau de Khobi",
    context=("Les dépôts de Khobi ravitaillent le front.",),
    mission=("Détruire le dépôt", "Rentrer à Kobuleti"),
    objectives=(Objective("Khobi", "Détruire le dépôt de Khobi", ("Le dépôt et sa défense SA-8.",)),),
    threats=(Threat("SA-6 Gori", "SA-6 Site", "SA-6", engagement_nm=13, detection_nm=30, source="mesuré en jeu"),),
    air_opposition=("Alerte d'interception à Senaki.",),
    air_defences=("Passer au sud du SA-6.",),
    other=("Attaque en piqué conseillée.",),
    pilots={"Kobuleti Viper": ["Zip", "Couz"]},
)


def _white(url: str) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (256, 256), (255, 255, 255)).save(buffer, format="PNG")
    return buffer.getvalue()


def _build(folder: Path, content: BriefingContent = CONTENT):
    return build_mission_briefing(folder, content, cache_dir=folder / "tiles", fetch=_white)


def _slides(deck: Path) -> list[list[str]]:
    """Each slide's texts: its text boxes, then each cell of its tables."""
    return [
        [shape.text_frame.text for shape in slide.shapes if shape.has_text_frame]
        + [cell.text for shape in slide.shapes if shape.has_table for row in shape.table.rows for cell in row.cells]
        for slide in Presentation(str(deck)).slides
    ]


def _deck_text(deck: Path) -> str:
    return chr(10).join(chr(10).join(slide) for slide in _slides(deck))


def _side_pictures(content: dict, side: str) -> list[str]:
    return [str(key) for key in indexed(content.get(f"pictureFileName{side}"))]


class Built(NamedTuple):
    folder: Path
    miz: Path
    report: BriefingReport


def _built_once(tmp_path_factory: pytest.TempPathFactory, content: BriefingContent) -> Built:
    folder = tmp_path_factory.mktemp("briefing")
    with offline(folder):
        miz = objective_mission(folder)
        return Built(folder, miz, _build(folder, content))


@pytest.fixture(scope="module")
def built(tmp_path_factory: pytest.TempPathFactory) -> Built:
    """`CONTENT`'s briefing, built once for the tests that only read it: a build takes seconds.

    A test that writes into the folder, or builds it again, makes its own.
    """
    return _built_once(tmp_path_factory, CONTENT)


class TestTheDeck:
    def test_the_nine_pages_of_the_template_in_the_missions_language(self, built: Built) -> None:
        report = built.report
        assert report.deck == built.folder / "docs" / "briefing.pptx"
        slides = _slides(report.deck)
        assert "Marteau de Khobi" in slides[0][0] or "Marteau de Khobi" in "\n".join(slides[0])
        titles = [slide[0] for slide in slides[1:]]
        assert titles == [
            "1. Situation générale",
            "2. ATO",
            "3. Situation tactique",
            "4. Zone des combats",
            "5. KHOBI — Détruire le dépôt de Khobi",  # named as the flight plan names it
            "6. Déroulement mission",
            "7. Plan de vol",
            "8. Plan de vol — étape par étape",
            "8. Plan de vol — étape par étape (suite)",  # the helicopters' route, on a slide of its own
            "9. Plan de fréquences",
            "10. Coordonnées cibles",
        ]
        assert report.pages == len(slides)

    def test_the_figures_are_the_missions(self, built: Built) -> None:
        text = "\n".join("\n".join(slide) for slide in _slides(built.report.deck))
        assert "Les dépôts de Khobi ravitaillent le front." in text
        assert "– Détruire le dépôt" in text
        assert "SA-6 Gori — SA-6 : engagement ≈ 13 nm, détection ≈ 30 nm (mesuré en jeu)" in text
        assert "Ch. 1 — Ninja : 390.5 MHz" in text and "243" not in text
        assert "1. Zip  2. Couz" in text
        _, zx, zy, _ = KHOBI_ZONE
        dms = to_dms(*xy_to_latlon("Caucasus", zx + 300, zy + 200))
        assert f"SA8{chr(10)}Osa 9A33 ln{chr(10)}missiles sol-air à courte portée{chr(10)}DMS {dms}" in text
        assert "Patrol" not in text  # near the zone, not one of its members

    def test_a_threat_whose_group_is_missing_is_a_warning(self, tmp_path: Path) -> None:
        objective_mission(tmp_path)
        content = BriefingContent(title="T", threats=(Threat("Ghost", "No such group"),))
        report = _build(tmp_path, content)
        assert report.deck.is_file()
        assert any("No such group" in warning for warning in report.warnings)

    def test_an_unbuilt_mission_or_an_unknown_zone_is_refused(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="build_mission"):
            _build(tmp_path)
        objective_mission(tmp_path)
        with pytest.raises(ValueError, match="Nowhere"):
            _build(tmp_path, BriefingContent(title="T", objectives=(Objective("Nowhere", "x"),)))


class TestProse:
    """FEAT-OBJECTIVE-BRIEFING-QUALITY 04: a strategic situation page, and prose where bullets were."""

    def test_the_strategic_situation_is_the_first_page_after_the_cover(self, tmp_path: Path) -> None:
        from dataclasses import replace

        objective_mission(tmp_path)
        text = ("Le front s'est figé sur la Purple Line.", "La coalition frappe en profondeur avant la négociation.")
        slides = _slides(_build(tmp_path, replace(CONTENT, strategic_situation=text)).deck)
        assert slides[1][0] == "1. Situation stratégique"
        assert slides[1][1] == chr(10).join(text)
        assert slides[2][0] == "2. Situation générale"
        assert "1. Situation stratégique" in slides[0][-1]

    def test_no_strategic_situation_no_page(self, built: Built) -> None:
        assert "Situation stratégique" not in _deck_text(built.report.deck)

    def test_a_mission_written_as_prose_keeps_no_dash(self, tmp_path: Path) -> None:
        from dataclasses import replace

        objective_mission(tmp_path)
        content = replace(CONTENT, mission=("Aveugler la défense, puis frapper le PC.",), mission_prose=True)
        text = _deck_text(_build(tmp_path, content).deck)
        assert "Aveugler la défense, puis frapper le PC." in text
        assert "– Aveugler" not in text


@pytest.fixture(scope="module")
def sheets(tmp_path_factory: pytest.TempPathFactory) -> BriefingReport:
    """`TestTheSheets._content()`'s briefing, built once: its tests only read it."""
    return _built_once(tmp_path_factory, TestTheSheets._content()).report


class TestTheSheets:
    """FEAT-OBJECTIVE-BRIEFING-QUALITY 03 and 05: target sheets, the flight plan step by step, the deployment."""

    @staticmethod
    def _content() -> BriefingContent:
        from dataclasses import replace

        return replace(
            CONTENT,
            deployment=("Viper décolle le premier, à H-10.", "Coordination sur la fréquence package."),
            waypoint_notes={"KHOBI": "Largage sur le dépôt, sortie par le sud."},
        )

    def test_the_targets_are_sheets_with_their_kind_coordinates_and_thumbnail(self, sheets: BriefingReport) -> None:
        deck = Presentation(str(sheets.deck))
        (slide,) = [s for s in deck.slides if "Coordonnées cibles" in s.shapes[0].text_frame.text]
        text = chr(10).join(shape.text_frame.text for shape in slide.shapes if shape.has_text_frame)
        assert "Détruire le dépôt de Khobi" in text  # the objective the sheets belong to
        assert "SA8" in text and "Osa 9A33 ln" in text  # the target, and what it is
        assert "DDM N4" in text and "DMS N4" in text
        assert sum(1 for shape in slide.shapes if shape.shape_type == 13) >= 2  # a thumbnail each

    def test_the_flight_plan_step_by_step_with_what_is_done_there(self, sheets: BriefingReport) -> None:
        slides = _slides(sheets.deck)
        steps = [slide for slide in slides if "étape par étape" in slide[0]]
        assert steps
        text = chr(10).join(chr(10).join(slide) for slide in steps)
        assert "W2 — KHOBI" in text
        assert "Largage sur le dépôt, sortie par le sud." in text
        assert "cap " in text and " nm" in text

    def test_the_deployment_page_follows_the_flow_and_is_left_out_when_empty(
        self, sheets: BriefingReport, built: Built
    ) -> None:
        titles = [slide[0] for slide in _slides(sheets.deck)[1:]]
        flow = next(i for i, title in enumerate(titles) if title.endswith("Déroulement mission"))
        assert titles[flow + 1].endswith("Déploiement et coordination")
        assert "Déploiement" not in _deck_text(built.report.deck)

    def test_the_pdf_carries_the_sheets_too(self, sheets: BriefingReport, built: Built) -> None:
        assert sheets.pdf_pages > built.report.pdf_pages  # the deployment page


class TestTheDcsPictures:
    def test_the_maps_go_into_the_folder_and_the_built_mission_blue_and_neutral(self, built: Built) -> None:
        tmp_path, miz, report = built
        assert report.pictures == [
            f"{PICTURE_PREFIX}overview",
            f"{PICTURE_PREFIX}combat-area",
            f"{PICTURE_PREFIX}objective-khobi",
        ]
        folder = load_folder_mission(tmp_path)
        for mission in (folder, read_miz(miz)):
            content = mission.mission_content or {}
            assert _side_pictures(content, "B")[:3] == report.pictures
            assert _side_pictures(content, "N")[:3] == report.pictures
            assert _side_pictures(content, "R") == []
            assert (mission.map_resource_content or {})[report.pictures[0]] == "briefing-overview.jpg"
        assert (tmp_path / "src" / "mission" / "l10n" / "DEFAULT" / "briefing-overview.jpg").is_file()
        with zipfile.ZipFile(miz) as archive:
            data = archive.read("l10n/DEFAULT/briefing-overview.jpg")
        assert Image.open(io.BytesIO(data)).format == "JPEG"

    def test_every_weather_variant_gets_the_maps_too(self, tmp_path: Path) -> None:
        """FIX-COWORK-SESSION-FINDINGS 01: the players fly `missions/<name>_<variant>.miz`, not the root one."""
        import shutil

        miz = objective_mission(tmp_path)
        variants = tmp_path / "missions"
        variants.mkdir()
        dawn, dusk = variants / "m_dawn.miz", variants / "m_dusk.miz"
        shutil.copy(miz, dawn)
        shutil.copy(miz, dusk)
        report = _build(tmp_path)
        assert report.archives == [miz, dawn, dusk]
        for archive_path in (dawn, dusk):
            content = read_miz(archive_path).mission_content or {}
            assert _side_pictures(content, "B")[:3] == report.pictures
            with zipfile.ZipFile(archive_path) as archive:
                assert "l10n/DEFAULT/briefing-overview.jpg" in archive.namelist()

    def test_the_kneeboard_pages_go_into_the_folder_and_every_archive(self, built: Built) -> None:
        """FIX-COWORK-SESSION-FINDINGS 08: maps, flight card and targets, 2:3 JPEG, in KNEEBOARD/IMAGES/."""
        tmp_path, miz, report = built
        assert report.kneeboard[0] == "01-briefing-overview.jpg"
        assert "03-briefing-objective-khobi.jpg" in report.kneeboard
        assert any(name.endswith("-briefing-targets.jpg") for name in report.kneeboard)
        folder_pages = tmp_path / "src" / "mission" / "KNEEBOARD" / "IMAGES"
        assert sorted(path.name for path in folder_pages.iterdir()) == sorted(report.kneeboard)
        with zipfile.ZipFile(miz) as archive:
            data = archive.read(f"KNEEBOARD/IMAGES/{report.kneeboard[0]}")
        with Image.open(io.BytesIO(data)) as page:
            assert page.format == "JPEG"
            assert page.size == (1536, 2304)

    def test_no_kneeboard_writes_none_and_removes_the_previous_pages(self, tmp_path: Path) -> None:
        objective_mission(tmp_path)
        _build(tmp_path)
        folder_pages = tmp_path / "src" / "mission" / "KNEEBOARD" / "IMAGES"
        (folder_pages / "mine.png").write_bytes(b"kept")
        report = build_mission_briefing(tmp_path, CONTENT, cache_dir=tmp_path / "tiles", fetch=_white, kneeboard=False)
        assert report.kneeboard == []
        assert [path.name for path in folder_pages.iterdir()] == ["mine.png"]
        with zipfile.ZipFile(report.miz) as archive:
            assert not [name for name in archive.namelist() if "-briefing-" in name and name.startswith("KNEEBOARD/")]

    def test_a_second_run_replaces_its_own_pictures_and_keeps_the_others(self, tmp_path: Path) -> None:
        objective_mission(tmp_path)
        folder = load_folder_mission(tmp_path)
        (folder.mission_content or {})["pictureFileNameB"] = ["Mine"]
        from veaf_mission_mcp.mission_folder import save_folder_mission

        save_folder_mission(folder, tmp_path)
        _build(tmp_path)
        report = _build(tmp_path)
        content = load_folder_mission(tmp_path).mission_content or {}
        assert _side_pictures(content, "B") == [*report.pictures, "Mine"]

    def test_red_pictures_are_left_alone_and_reported(self, tmp_path: Path) -> None:
        objective_mission(tmp_path)
        folder = load_folder_mission(tmp_path)
        (folder.mission_content or {})["pictureFileNameR"] = ["RedMap"]
        from veaf_mission_mcp.mission_folder import save_folder_mission

        save_folder_mission(folder, tmp_path)
        report = _build(tmp_path)
        assert _side_pictures(load_folder_mission(tmp_path).mission_content or {}, "R") == ["RedMap"]
        assert any("pictureFileNameR" in warning for warning in report.warnings)


class TestTheFrequencyPlan:
    def test_named_channels_one_a_line_bare_frequencies_together(self, tmp_path: Path) -> None:
        from campaign_manager.mission_picture import read_mission_picture
        from mission_briefing.mission_briefing_worker import _frequencies_page
        from mission_briefing.models import RadioPlan

        picture = read_mission_picture(objective_mission(tmp_path), "blue", tmp_path)
        plan = RadioPlan(3, ("ARCHER",), ((1, "Archer", 390.0), (2, "", 30.0), (3, "", 31.0)))
        with language("en"):
            page = _frequencies_page(picture, [plan])
        (block,) = [b for b in page.blocks if b.heading and b.heading.startswith("Radio")]
        assert block.paragraphs == ("Ch. 1 — Archer: 390.0 MHz", "Ch. 2: 30.0 MHz · Ch. 3: 31.0 MHz")

    def test_red_players_get_them_in_the_red_and_neutral_lists(self, tmp_path: Path) -> None:
        from mission_briefing.mission_briefing_worker import _list_pictures

        mission = read_miz(objective_mission(tmp_path))
        other = _list_pictures(mission, {"MCP_Briefing_overview": "briefing-overview.jpg"}, "red")
        content = mission.mission_content or {}
        assert _side_pictures(content, "R") == ["MCP_Briefing_overview"]
        assert _side_pictures(content, "N") == ["MCP_Briefing_overview"]
        assert _side_pictures(content, "B") == [] and other == []


def test_only_pictures_the_tool_wrote_are_deleted(tmp_path: Path) -> None:
    """`mapResource` comes from the mission, which may come from anywhere: a name under an
    `MCP_Briefing_` key that climbs out of `l10n/DEFAULT/` must not be deleted (security review, 6.31.0).
    """
    from mission_briefing.mission_briefing_worker import _stale_pictures

    l10n = tmp_path / "l10n" / "DEFAULT"
    l10n.mkdir(parents=True)
    previous = {"briefing-old.jpg", "briefing-kept.jpg", "../../mission.yaml", r"..\..\x.jpg", "notes.txt"}

    stale = _stale_pictures(l10n, previous, kept={"briefing-kept.jpg"})

    assert stale == [(l10n / "briefing-old.jpg").resolve()]


class TestWaypointNumbers:
    """FIX-DEMO-VIDEO-FINDINGS 07: the route had BULLSEYE third, the texts had written W3 for the target.

    The fixture's route is POTI (W1), KHOBI (W2), BULLSEYE (W3).
    """

    @staticmethod
    def _warnings(tmp_path: Path, *lines: str) -> list[str]:
        objective_mission(tmp_path)
        report = _build(tmp_path, BriefingContent(title="T", mission=lines))
        return [warning for warning in report.warnings if "waypoint" in warning.lower()]

    def test_a_number_that_names_another_point_is_warned(self, tmp_path: Path) -> None:
        warnings = self._warnings(tmp_path, "Détruire le dépôt de Khobi (W3).")
        assert len(warnings) == 1
        assert "W3" in warnings[0] and "KHOBI" in warnings[0] and "W2" in warnings[0]

    def test_a_number_past_the_end_of_the_route_is_warned(self, tmp_path: Path) -> None:
        warnings = self._warnings(tmp_path, "Rentrer par W7.")
        assert len(warnings) == 1 and "W7" in warnings[0] and "3 point" in warnings[0]

    def test_numbers_that_match_the_route_say_nothing(self, tmp_path: Path) -> None:
        assert self._warnings(tmp_path, "Rejoindre POTI (W1), puis KHOBI (W2) et le bullseye (W3).") == []

    def test_a_text_with_no_waypoint_number_says_nothing(self, tmp_path: Path) -> None:
        assert self._warnings(tmp_path, "Détruire le dépôt de Khobi.") == []


class TestDynamicSlotAto:
    """FEAT-OBJECTIVE-BRIEFING-QUALITY 01: a base listed the 61 types it offers, six slides for two bases.

    (FIX-DEMO-VIDEO-FINDINGS 03 had listed them so that the ATO was not empty.) A dynamic-slot base now says
    so, then the flights the assistant names; never the types.
    """

    @staticmethod
    def _link_the_template(miz: Path) -> None:
        """Link the fixture's F-16C template to Kobuleti, as a base offering it would."""
        mission = read_miz(miz)
        content = mission.mission_content or {}
        template = next(
            group
            for country in indexed(content["coalition"]["blue"]["country"])
            for group in indexed((country.get("plane") or {}).get("group"))
            if group.get("dynSpawnTemplate")
        )
        template["groupId"] = 9001
        airports = (mission.warehouses_content or {})["airports"]
        entry = next(iter(airports.values()))
        entry["aircrafts"] = {"planes": {"F-16C_50": {"initialAmount": 4, "linkDynTempl": 9001}}}
        write_miz(mission, miz)

    @staticmethod
    def _ato(deck: Path) -> str:
        return chr(10).join(
            chr(10).join(slide) for slide in _slides(deck) if slide and slide[0].split(". ", 1)[-1].startswith("ATO")
        )

    def test_a_dynamic_base_says_so_and_lists_no_type(self, tmp_path: Path) -> None:
        self._link_the_template(objective_mission(tmp_path))
        ato = self._ato(_build(tmp_path).deck)
        assert "Slots dynamiques\n\nKobuleti" in ato  # a row of the package's table: no aircraft named
        assert "F-16C_50 —" not in ato  # the fixture's own Viper flight is an F-16C_50 too
        assert "1. ______  2. ______  3. ______  4. ______" in ato

    def test_the_flights_named_are_listed_under_their_base_with_their_pilots(self, tmp_path: Path) -> None:
        from dataclasses import replace

        from mission_briefing.models import PackageFlight

        self._link_the_template(objective_mission(tmp_path))
        flights = (PackageFlight("Ninja", base="Kobuleti", aircraft="F-16C", count=2, task="SEAD"),)
        content = replace(CONTENT, flights=flights, pilots={"Ninja": ["Zip"]}, loadouts={"Ninja": "2 HARM"})
        ato = self._ato(_build(tmp_path, content).deck)
        assert "Ninja\n2 × F-16C\nKobuleti (slot dyn)\nSEAD\n1. Zip  2. ______\n2 HARM" in ato

    def test_a_flight_from_no_dynamic_base_is_listed_apart_and_warned(self, tmp_path: Path) -> None:
        from dataclasses import replace

        from mission_briefing.models import PackageFlight

        objective_mission(tmp_path)
        content = replace(CONTENT, flights=(PackageFlight("Jedi", base="Nowhere"), PackageFlight("Arctic")))
        report = _build(tmp_path, content)
        ato = self._ato(report.deck)
        assert "Jedi\n\nSlots dynamiques — base au choix" in ato
        assert "Arctic\n\nSlots dynamiques — base au choix" in ato
        assert any("Jedi" in warning and "Nowhere" in warning for warning in report.warnings)


class TestDiversionFields:
    """FIX-COWORK-SESSION-FINDINGS 04: the deck named the departure itself as the diversion field."""

    @staticmethod
    def _flow(tmp_path: Path, content: BriefingContent) -> str:
        from dataclasses import replace

        from campaign_manager.mission_picture import Airfield, read_mission_picture
        from mission_briefing.mission_briefing_worker import _flow_page

        miz = objective_mission(tmp_path)
        picture = read_mission_picture(miz, "blue", tmp_path)
        fields = (Airfield("Senaki-Kolkhi", None, None, None, None), Airfield("Kutaisi", None, None, None, None))
        picture = replace(picture, airfields=fields)
        with language("en"):
            page = _flow_page(content, picture, [("Senaki-Kolkhi", 0.0, 0.0)])
        return "\n".join(text for block in page.blocks for text in block.paragraphs)

    def test_the_departure_is_left_out(self, tmp_path: Path) -> None:
        text = self._flow(tmp_path, CONTENT)
        assert "Diversion fields: Kutaisi and Stennis." in text  # the fixture's carrier too

    def test_the_assistants_list_replaces_it(self, tmp_path: Path) -> None:
        from dataclasses import replace

        text = self._flow(tmp_path, replace(CONTENT, diversions=("Batumi", "Kobuleti")))
        assert "Diversion fields: Batumi" in text and "Kutaisi" not in text
