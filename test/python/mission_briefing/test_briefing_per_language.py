"""A briefing in each language of a bilingual mission (FEAT-BRIEFING-PER-LANGUAGE 01).

A mission built twice, a French and an English profile (`build_variants`), has `.miz` of both languages in
`missions/`. One call per language writes each archive's pages in its own language, and only the call in the
mission's language touches the folder and its deck.
"""

from __future__ import annotations

import io
import shutil
import zipfile
from pathlib import Path
from typing import Any, NamedTuple

import pytest
from mission_briefing.mission_briefing_worker import (
    archive_language,
    briefing_files,
    build_mission_briefing,
)
from mission_briefing.models import BriefingContent, BriefingReport, Objective
from objective_mission_fixture import objective_mission
from offline import offline
from PIL import Image
from pptx import Presentation

FRENCH = BriefingContent(
    title="Marteau de Khobi",
    context=("Les dépôts de Khobi ravitaillent le front.",),
    objectives=(Objective("Khobi", "Détruire le dépôt de Khobi", ("Le dépôt et sa défense SA-8.",)),),
)

ENGLISH = BriefingContent(
    title="Khobi Hammer",
    context=("The Khobi depots supply the front.",),
    objectives=(Objective("Khobi", "Destroy the Khobi depot", ("The depot and its SA-8.",)),),
)

#: The member a profile's build writes the in-game language into.
_CONFIG = "l10n/DEFAULT/veaf-config.lua"


def _white(url: str) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (256, 256), (255, 255, 255)).save(buffer, format="PNG")
    return buffer.getvalue()


def _build(folder: Path, content: BriefingContent, **options: Any) -> BriefingReport:
    return build_mission_briefing(folder, content, cache_dir=folder / "tiles", fetch=_white, **options)


def _set_language(miz: Path, code: str) -> None:
    """Give the archive the `veaf-config.lua` an `EN` profile's build writes."""
    with zipfile.ZipFile(miz) as archive:
        members = {name: archive.read(name) for name in archive.namelist() if name != _CONFIG}
    members[_CONFIG] = f'veaf.config = veaf.config or {{}}\nveaf.config.language = "{code}"\n'.encode()
    with zipfile.ZipFile(miz, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, data in members.items():
            archive.writestr(name, data)


def _members(miz: Path, prefix: str) -> dict[str, bytes]:
    with zipfile.ZipFile(miz) as archive:
        return {name: archive.read(name) for name in archive.namelist() if name.startswith(prefix)}


def _deck_text(deck: Path) -> str:
    return "\n".join(
        shape.text_frame.text
        for slide in Presentation(str(deck)).slides
        for shape in slide.shapes
        if shape.has_text_frame
    )


def _folder_state(folder: Path) -> dict[str, bytes]:
    """Every file of `src/mission/` and the French deck, to tell whether a call touched them."""
    deck, pdf = briefing_files(folder)
    files = [*sorted((folder / "src" / "mission").rglob("*")), deck, pdf]
    return {str(path): path.read_bytes() for path in files if path.is_file()}


class Bilingual(NamedTuple):
    folder: Path
    french: Path
    english: Path
    fr_report: BriefingReport
    en_report: BriefingReport
    fr_pages: dict[str, bytes]
    folder_after_fr: dict[str, bytes]


@pytest.fixture(scope="module")
def bilingual(tmp_path_factory: pytest.TempPathFactory) -> Bilingual:
    folder = tmp_path_factory.mktemp("bilingual")
    with offline(folder):
        miz = objective_mission(folder)
        variants = folder / "missions"
        variants.mkdir()
        french, english = variants / "m_FR.miz", variants / "m_EN.miz"
        shutil.copy(miz, french)
        shutil.copy(miz, english)
        _set_language(english, "en")
        fr_report = _build(folder, FRENCH, language="fr")
        fr_pages = _members(french, "KNEEBOARD/IMAGES/")
        folder_after_fr = _folder_state(folder)
        en_report = _build(folder, ENGLISH, language="en")
        return Bilingual(folder, french, english, fr_report, en_report, fr_pages, folder_after_fr)


class TestArchiveLanguage:
    def test_read_from_the_profile_config(self, tmp_path: Path) -> None:
        with offline(tmp_path):
            miz = objective_mission(tmp_path)
        _set_language(miz, "en")
        assert archive_language(miz, "fr") == "en"

    def test_an_archive_without_the_line_is_in_the_mission_language(self, tmp_path: Path) -> None:
        with offline(tmp_path):
            miz = objective_mission(tmp_path)
        with zipfile.ZipFile(miz) as archive:
            names = archive.namelist()
        if _CONFIG in names:
            with zipfile.ZipFile(miz) as archive:
                members = {name: archive.read(name) for name in names if name != _CONFIG}
            with zipfile.ZipFile(miz, "w") as archive:
                for name, data in members.items():
                    archive.writestr(name, data)
        assert archive_language(miz, "fr") == "fr"


class TestTwoCalls:
    def test_each_call_reports_only_the_archives_of_its_language(self, bilingual: Bilingual) -> None:
        assert bilingual.english not in bilingual.fr_report.archives
        assert bilingual.french in bilingual.fr_report.archives
        assert bilingual.en_report.archives == [bilingual.english]

    def test_the_english_call_leaves_the_french_archive_as_it_was(self, bilingual: Bilingual) -> None:
        assert _members(bilingual.french, "KNEEBOARD/IMAGES/") == bilingual.fr_pages

    def test_the_english_archive_carries_other_pages_than_the_french(self, bilingual: Bilingual) -> None:
        english = _members(bilingual.english, "KNEEBOARD/IMAGES/")
        assert set(english) == set(bilingual.fr_pages)
        overview = "KNEEBOARD/IMAGES/01-briefing-overview.jpg"
        assert english[overview] != bilingual.fr_pages[overview]

    def test_the_english_archive_lists_the_pictures_under_the_same_names(self, bilingual: Bilingual) -> None:
        assert bilingual.en_report.pictures == bilingual.fr_report.pictures
        assert "l10n/DEFAULT/briefing-overview.jpg" in _members(bilingual.english, "l10n/DEFAULT/")

    def test_the_english_call_does_not_touch_the_folder_nor_the_french_deck(self, bilingual: Bilingual) -> None:
        assert _folder_state(bilingual.folder) == bilingual.folder_after_fr

    def test_each_deck_is_in_its_language(self, bilingual: Bilingual) -> None:
        fr_deck, fr_pdf = briefing_files(bilingual.folder)
        assert bilingual.fr_report.deck == fr_deck and bilingual.fr_report.pdf == fr_pdf
        assert "Situation tactique" in _deck_text(fr_deck)
        en_deck = bilingual.en_report.deck
        assert en_deck == fr_deck.with_name(f"{fr_deck.stem}.en.pptx")
        assert bilingual.en_report.pdf == fr_pdf.with_name(f"{fr_pdf.stem}.en.pdf")
        assert en_deck.is_file() and bilingual.en_report.pdf.is_file()
        assert "Tactical situation" in _deck_text(en_deck)

    def test_the_english_maps_go_into_a_folder_of_their_own(self, bilingual: Bilingual) -> None:
        maps = bilingual.folder / "docs" / "maps"
        assert all(path.parent == maps / "en" for path in bilingual.en_report.maps)
        assert all(path.parent == maps for path in bilingual.fr_report.maps)


class TestNoArchiveInThatLanguage:
    def test_warns_and_writes_no_archive(self, tmp_path: Path) -> None:
        with offline(tmp_path):
            miz = objective_mission(tmp_path)
            before = miz.read_bytes()
            report = _build(tmp_path, ENGLISH, language="en", kneeboard_only=True)
        assert report.archives == []
        assert miz.read_bytes() == before
        assert any("No built mission in English" in warning for warning in report.warnings)

    def test_an_unknown_language_is_refused(self, tmp_path: Path) -> None:
        with offline(tmp_path):
            objective_mission(tmp_path)
            with pytest.raises(ValueError, match="language"):
                _build(tmp_path, ENGLISH, language="de")
