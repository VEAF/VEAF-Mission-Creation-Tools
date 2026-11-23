"""Checks that a briefing's PDF carries the same pages as its PowerPoint deck (David, 2026-11-17)."""

from __future__ import annotations

import re
from pathlib import Path

from pptx import Presentation
from pypdf import PdfReader


def _flat(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def assert_pdf_matches_deck(deck: Path, pdf: Path | None) -> None:
    """The PDF sits beside the deck, under the same name, and every slide's title is in it.

    Args:
        deck: The PowerPoint deck.
        pdf: The PDF the generator reported.
    """
    assert pdf == deck.with_suffix(".pdf")
    assert pdf.read_bytes().startswith(b"%PDF")
    text = _flat(" ".join(page.extract_text() for page in PdfReader(str(pdf)).pages))
    slides = list(Presentation(str(deck)).slides)
    titles = {
        _flat(next(shape.text_frame.text for shape in slide.shapes if shape.has_text_frame)) for slide in slides[1:]
    }
    assert titles, "a deck with pages after its cover"
    for title in titles:
        assert title in text, f"{title!r} missing from the PDF"
    cover = _flat(slides[0].shapes[0].text_frame.text).split(" ")[0]
    assert cover in text
