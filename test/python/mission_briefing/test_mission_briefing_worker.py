"""A one-shot mission's briefing deck and DCS briefing pictures (FEAT-MCP-MISSION-BRIEFING ticket 04)."""

from __future__ import annotations

import io
import zipfile
from pathlib import Path

import pytest
from mission_briefing.mission_briefing_worker import PICTURE_PREFIX, build_mission_briefing
from mission_briefing.models import BriefingContent, Objective, Threat
from mission_tools.miz_tools import read_miz, write_miz
from objective_mission_fixture import KHOBI_ZONE, objective_mission
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
    return [
        [shape.text_frame.text for shape in slide.shapes if shape.has_text_frame]
        for slide in Presentation(str(deck)).slides
    ]


def _deck_text(deck: Path) -> str:
    return chr(10).join(chr(10).join(slide) for slide in _slides(deck))


def _side_pictures(content: dict, side: str) -> list[str]:
    return [str(key) for key in indexed(content.get(f"pictureFileName{side}"))]


class TestTheDeck:
    def test_the_nine_pages_of_the_template_in_the_missions_language(self, tmp_path: Path) -> None:
        objective_mission(tmp_path)
        report = _build(tmp_path)
        assert report.deck == tmp_path / "docs" / "briefing.pptx"
        slides = _slides(report.deck)
        assert "Marteau de Khobi" in slides[0][0] or "Marteau de Khobi" in "\n".join(slides[0])
        titles = [slide[0] for slide in slides[1:]]
        assert titles == [
            "1. Situation générale",
            "2. ATO",
            "3. Situation tactique",
            "4. Situation tactique — Khobi",
            "5. Déroulement mission",
            "6. Plan de vol",
            "7. Plan de fréquences",
            "8. Coordonnées cibles",
        ]
        assert report.pages == len(slides)

    def test_the_figures_are_the_missions(self, tmp_path: Path) -> None:
        objective_mission(tmp_path)
        text = "\n".join("\n".join(slide) for slide in _slides(_build(tmp_path).deck))
        assert "Les dépôts de Khobi ravitaillent le front." in text
        assert "– Détruire le dépôt" in text
        assert "SA-6 Gori — SA-6 : engagement ≈ 13 nm, détection ≈ 30 nm (mesuré en jeu)" in text
        assert "Ch. 1 — Ninja : 390.5 MHz" in text and "243" not in text
        assert "1. Zip  2. Couz" in text
        _, zx, zy, _ = KHOBI_ZONE
        assert f"SA8 : {to_dms(*xy_to_latlon('Caucasus', zx + 300, zy + 200))}" in text
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


class TestTheDcsPictures:
    def test_the_maps_go_into_the_folder_and_the_built_mission_blue_and_neutral(self, tmp_path: Path) -> None:
        miz = objective_mission(tmp_path)
        report = _build(tmp_path)
        assert report.pictures == [f"{PICTURE_PREFIX}overview", f"{PICTURE_PREFIX}objective-khobi"]
        folder = load_folder_mission(tmp_path)
        for mission in (folder, read_miz(miz)):
            content = mission.mission_content or {}
            assert _side_pictures(content, "B")[:2] == report.pictures
            assert _side_pictures(content, "N")[:2] == report.pictures
            assert _side_pictures(content, "R") == []
            assert (mission.map_resource_content or {})[report.pictures[0]] == "briefing-overview.jpg"
        assert (tmp_path / "src" / "mission" / "l10n" / "DEFAULT" / "briefing-overview.jpg").is_file()
        with zipfile.ZipFile(miz) as archive:
            data = archive.read("l10n/DEFAULT/briefing-overview.jpg")
        assert Image.open(io.BytesIO(data)).format == "JPEG"

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
    """FIX-DEMO-VIDEO-FINDINGS 03: with dynamic slots the ATO listed no flight; an AI wrote a script to fill it."""

    @staticmethod
    def _link_the_template(miz: Path) -> None:
        """Link the fixture's F-16C template to Kobuleti, and give the template its preset channel."""
        mission = read_miz(miz)
        content = mission.mission_content or {}
        template = next(
            group
            for country in indexed(content["coalition"]["blue"]["country"])
            for group in indexed((country.get("plane") or {}).get("group"))
            if group.get("dynSpawnTemplate")
        )
        template["groupId"] = 9001  # the fixture's templates carry none; the warehouse links a template by it
        unit = indexed(template["units"])[0]
        unit["Radio"] = {1: {"channels": {1: 390.5, 2: 282.2}, "channelsNames": {1: "Ninja", 2: "Magic"}}}
        airports = (mission.warehouses_content or {})["airports"]
        entry = next(iter(airports.values()))
        entry["aircrafts"] = {"planes": {"F-16C_50": {"initialAmount": 4, "linkDynTempl": 9001}}}
        write_miz(mission, miz)

    def test_the_dynamic_airfield_lists_the_types_it_offers_with_their_first_channel(self, tmp_path: Path) -> None:
        miz = objective_mission(tmp_path)
        self._link_the_template(miz)
        text = _deck_text(_build(tmp_path).deck)
        assert "Slots dynamiques — Kobuleti" in text
        assert "F-16C_50 — Ninja : 390.5 MHz" in text

    def test_a_base_linking_no_template_lists_no_type(self, tmp_path: Path) -> None:
        objective_mission(tmp_path)
        text = _deck_text(_build(tmp_path).deck)
        assert "Slots dynamiques — Kobuleti" in text
        assert "F-16C_50 —" not in text
