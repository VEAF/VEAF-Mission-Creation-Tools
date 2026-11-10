"""The kneeboard alone, and free text sheets at its head (FEAT-OPEN-TRAINING-KNEEBOARD 01).

An Open Training already has its README and its own DCS briefing pictures: the tool only writes its
kneeboard, and the sheets the session writes (mission, conduct, commands) come first in it.
"""

from __future__ import annotations

import io
import zipfile
from datetime import date
from pathlib import Path
from typing import Any

import pytest
from mission_briefing import mission_briefing_worker
from mission_briefing.briefing_kneeboard import flight_card_tables
from mission_briefing.mission_briefing_worker import DECK_FILE, PDF_FILE, build_mission_briefing
from mission_briefing.models import BriefingContent, Objective, TextSheet
from mission_tools.miz_tools import read_miz, write_miz
from objective_mission_fixture import objective_mission
from offline import offline
from PIL import Image
from veaf_mission_mcp.mission_folder import load_folder_mission, save_folder_mission
from veaf_mission_mcp.mission_table import indexed

SHEETS = (
    TextSheet("Mission", ("Un entraînement ouvert.",)),
    TextSheet("Conduite", ("Ne pas décoller d'un taxiway.", "Annoncer sur la VHF du terrain.")),
    TextSheet("Commandes", ("-cas : une zone d'appui aérien rapproché.",)),
)

CONTENT = BriefingContent(
    title="Open Training Caucasus",
    objectives=(Objective("Khobi", "Khobi - blindés - facile", ("F10 > Zones de combat > Khobi > Activer",)),),
    sheets=SHEETS,
)


def _white(url: str) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (256, 256), (255, 255, 255)).save(buffer, format="PNG")
    return buffer.getvalue()


def _build(folder: Path, content: BriefingContent = CONTENT, **options: Any):
    return build_mission_briefing(folder, content, cache_dir=folder / "tiles", fetch=_white, **options)


def _with_own_pictures(folder: Path, miz: Path) -> None:
    """The mission, its folder and its build, carries a briefing picture of its own, as an OT's `gen_map.py` puts there."""
    mission = load_folder_mission(folder)
    (mission.mission_content or {})["pictureFileNameB"] = ["OwnMap"]
    save_folder_mission(mission, folder)
    built = read_miz(miz)
    (built.mission_content or {})["pictureFileNameB"] = ["OwnMap"]
    write_miz(built, miz)


@pytest.fixture(scope="module")
def kneeboard_only(tmp_path_factory: pytest.TempPathFactory):
    folder = tmp_path_factory.mktemp("kneeboard-only")
    with offline(folder):
        miz = objective_mission(folder)
        _with_own_pictures(folder, miz)
        before = read_miz(miz).mission_content or {}
        return folder, miz, before, _build(folder, kneeboard_only=True)


class TestKneeboardOnly:
    def test_no_deck_no_pdf(self, kneeboard_only) -> None:
        folder, _, _, report = kneeboard_only
        assert report.deck is None and report.pdf is None
        assert report.pages == 0 and report.pdf_pages == 0
        assert not (folder / DECK_FILE).exists() and not (folder / PDF_FILE).exists()

    def test_no_dcs_briefing_picture_added_and_its_own_left_alone(self, kneeboard_only) -> None:
        folder, miz, before, report = kneeboard_only
        assert report.pictures == [] and report.maps == []
        assert [
            str(k) for k in indexed((load_folder_mission(folder).mission_content or {}).get("pictureFileNameB"))
        ] == ["OwnMap"]
        after = read_miz(miz).mission_content or {}
        assert [str(k) for k in indexed(after.get("pictureFileNameB"))] == ["OwnMap"]
        for side in ("B", "R", "N"):
            key = f"pictureFileName{side}"
            assert [str(k) for k in indexed(after.get(key))] == [str(k) for k in indexed(before.get(key))]
        assert not list((folder / "src" / "mission" / "l10n" / "DEFAULT").glob("briefing-*.jpg"))
        with zipfile.ZipFile(miz) as archive:
            assert not [name for name in archive.namelist() if name.startswith("l10n/DEFAULT/briefing-")]

    def test_the_kneeboard_is_written_sheets_first(self, kneeboard_only) -> None:
        folder, miz, _, report = kneeboard_only
        assert report.kneeboard[:4] == [
            "01-briefing-sheet-1.jpg",
            "02-briefing-sheet-2.jpg",
            "03-briefing-sheet-3.jpg",
            "04-briefing-overview.jpg",
        ]
        assert any(name.endswith("-briefing-targets.jpg") for name in report.kneeboard)
        with zipfile.ZipFile(miz) as archive:
            assert {f"KNEEBOARD/IMAGES/{name}" for name in report.kneeboard} <= set(archive.namelist())
        folder_pages = folder / "src" / "mission" / "KNEEBOARD" / "IMAGES"
        assert sorted(path.name for path in folder_pages.iterdir()) == sorted(report.kneeboard)

    def test_a_kneeboard_only_run_with_no_kneeboard_is_refused(self, tmp_path: Path) -> None:
        with offline(tmp_path):
            objective_mission(tmp_path)
            with pytest.raises(ValueError, match="kneeboard_only"):
                _build(tmp_path, kneeboard_only=True, kneeboard=False)


class TestSheets:
    def test_a_long_sheet_runs_on_named_after_its_first_page(self, tmp_path: Path) -> None:
        long = TextSheet("Commandes", tuple(f"Ligne {n} d'une liste de commandes." for n in range(120)))
        with offline(tmp_path):
            objective_mission(tmp_path)
            report = _build(tmp_path, BriefingContent(title="OT", sheets=(long,)), kneeboard_only=True)
        assert report.kneeboard[:2] == ["01-briefing-sheet-1.jpg", "02-briefing-sheet-1-2.jpg"]

    def test_each_sheet_is_laid_out_under_its_title(self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
        laid_out: list[tuple[str, list[Any]]] = []
        real = mission_briefing_worker.text_pages

        def spy(title: str, blocks: list[Any]) -> list[bytes]:
            laid_out.append((title, blocks))
            return real(title, blocks)

        monkeypatch.setattr(mission_briefing_worker, "text_pages", spy)
        with offline(tmp_path):
            objective_mission(tmp_path)
            _build(tmp_path, kneeboard_only=True)
        assert laid_out[:3] == [(sheet.title, [(None, list(sheet.paragraphs))]) for sheet in SHEETS]

    def test_in_kneeboard_only_the_zone_list_says_how_to_start_each_zone(
        self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        """PRD D4: an objective's task is how to start the zone from the F10 menu; the zoom page has no text."""
        laid_out: dict[str, list[Any]] = {}
        real = mission_briefing_worker.text_pages

        def spy(title: str, blocks: list[Any]) -> list[bytes]:
            laid_out[title] = blocks
            return real(title, blocks)

        monkeypatch.setattr(mission_briefing_worker, "text_pages", spy)
        with offline(tmp_path):
            objective_mission(tmp_path)
            _build(tmp_path, kneeboard_only=True)
        ((heading, lines),) = next(
            blocks for title, blocks in laid_out.items() if title not in {"Mission", "Conduite", "Commandes"}
        )
        assert "Khobi - blindés - facile" in str(heading)
        assert lines[0] == "F10 > Zones de combat > Khobi > Activer"


def test_no_flight_plan_no_flight_card() -> None:
    """A mission with no flight plan (an OT's dynamic slots) gets no flight-card page: the card has no table."""
    assert flight_card_tables("Caucasus", date(2016, 6, 1), [], []) == []
