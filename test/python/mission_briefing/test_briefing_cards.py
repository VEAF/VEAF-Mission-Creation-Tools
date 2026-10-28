"""Sheets of cards: the targets and the flight plan's steps (FEAT-OBJECTIVE-BRIEFING-QUALITY 03, 05)."""

from __future__ import annotations

import io
from pathlib import Path

from mission_briefing.briefing_cards import PER_PAGE, Card, CardSection, thumbnail, to_ddm
from PIL import Image
from veaf_libs.i18n import language


def test_ddm_rounds_once_then_splits() -> None:
    assert to_ddm(33.12560, 35.82470) == "N33°07.536' E035°49.482'"
    assert to_ddm(-0.99999999, -10.5) == "S01°00.000' W010°30.000'"


def test_a_thumbnail_is_a_square_kept_inside_the_map(tmp_path: Path) -> None:
    png = tmp_path / "map.png"
    Image.new("RGB", (800, 500), (255, 255, 255)).save(png)
    with Image.open(io.BytesIO(thumbnail(png, (5, 5), 300))) as square:
        assert square.size == (300, 300)
    with Image.open(io.BytesIO(thumbnail(png, (400, 250), 900))) as square:
        assert square.size == (500, 500)  # no larger than the map


def test_a_group_never_shares_a_slide_and_the_next_slide_says_it_continues() -> None:
    cards = [Card(f"T{n}", ()) for n in range(PER_PAGE + 1)]
    section = CardSection("9. Fiches", [("A", cards), ("B", [Card("X", ())])])
    with language("fr"):
        pages = section.pages()
    assert [len(page.cards) for page in pages] == [PER_PAGE, 1, 1]
    assert [page.heading for page in pages] == ["A", "A", "B"]
    assert pages[0].title == "9. Fiches" and pages[1].title.startswith("9. Fiches") and pages[1].title != "9. Fiches"
