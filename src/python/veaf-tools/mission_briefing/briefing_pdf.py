"""The briefing as a PDF, written by the executable (FIX-DEMO-VIDEO-FINDINGS 08).

The objective prompt offers "PPTX + PDF" and the tools wrote the PPTX only: without PowerPoint, two runs
improvised — one printed an HTML copy of the deck with Edge, the other installed LibreOffice by `winget` and
failed (MSI 1603, no elevation). A mission maker with neither Office nor Edge had no PDF at all.

This draws the same pages — the same :class:`~campaign_manager.briefing_deck.Page` blocks, the same maps, the
same words — with `fpdf2` and a bundled font with the accents, so nothing is asked of the machine. It is the
deck's content with its own layout, not a pixel copy of the slides: the fonts differ (DejaVu Sans for
Calibri) and the page breaks follow the PDF's text, not the deck's.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from campaign_manager.briefing_deck import Block, Page
from fpdf import FPDF
from PIL import Image
from veaf_libs.bundled_data import bundled_dir

#: The deck's slide size, 16:9 (13.333 x 7.5 in), in millimetres: a page the deck's proportions.
_PAGE_MM = (190.5, 338.67)

#: Page margin and the top of a page's body, millimetres (the deck's 0.5 in and 1.15 M EMU).
_MARGIN = 12.7
_BODY_TOP = 32.0
_BODY_BOTTOM = 12.0

#: DejaVu Sans is some 18 % wider than the deck's Calibri: every size is scaled down so a page the deck
#: fitted still fits.
_SCALE = 0.85
_BODY_SIZE = 14 * _SCALE
_HEADING_SIZE = 16 * _SCALE
_TITLE_SIZE = 30 * _SCALE
_NOTE_SIZE = 11 * _SCALE
_LINE_SPACING = 1.25

_BLUE = (0x1F, 0x5F, 0xBF)
_GREY = (0x55, 0x55, 0x55)

#: The font family name and the files under ``veaf_libs/data/fonts`` (DejaVu Sans 2.37, free to redistribute).
_FAMILY = "DejaVu"
_REGULAR = "DejaVuSans.ttf"
_BOLD = "DejaVuSans-Bold.ttf"


@dataclass(frozen=True)
class MapSheet:
    """A page with a map on the left and its notes on the right; a note is ``(text, is_heading)``."""

    title: str
    image: Path
    notes: list[tuple[str, bool]]


@dataclass(frozen=True)
class Cover:
    """The first page: the mission's title, its subtitle and date line, and the contents."""

    title: str
    subtitle: str
    date_line: str
    contents_heading: str
    contents: list[str]


class _Pdf(FPDF):
    """An `FPDF` of the deck's proportions with the bundled font."""

    def __init__(self) -> None:
        super().__init__(orientation="L", unit="mm", format=_PAGE_MM)
        fonts = bundled_dir("veaf_libs", "data", "fonts")
        self.add_font(_FAMILY, "", str(fonts / _REGULAR))
        self.add_font(_FAMILY, "B", str(fonts / _BOLD))
        self.set_margins(_MARGIN, _BODY_TOP, _MARGIN)
        self.set_auto_page_break(True, margin=_BODY_BOTTOM)
        self.set_title("VEAF briefing")

    def say(self, text: str, size: float, *, bold: bool = False, colour: tuple[int, int, int] | None = None) -> None:
        """One paragraph at the left margin, wrapped, in the given size."""
        self.set_font(_FAMILY, "B" if bold else "", size)
        self.set_text_color(*(colour or (0, 0, 0)))
        self.multi_cell(0, size * 0.3528 * _LINE_SPACING, text, new_x="LMARGIN", new_y="NEXT")

    def headline(self, title: str) -> None:
        """A page's title at the top, shrunk to one line when it is long."""
        size = _TITLE_SIZE
        self.set_font(_FAMILY, "B", size)
        while size > 14 and self.get_string_width(title) > self.epw:
            size -= 1
            self.set_font(_FAMILY, "B", size)
        self.set_text_color(0, 0, 0)
        self.set_xy(_MARGIN, 10)
        self.cell(0, 14, title, new_x="LMARGIN", new_y="NEXT")
        self.set_xy(_MARGIN, _BODY_TOP)


def _text_page(pdf: _Pdf, page: Page) -> None:
    pdf.add_page()
    pdf.headline(page.title)
    for block in page.blocks:
        _block(pdf, block)
    if page.note:
        pdf.set_xy(_MARGIN, _PAGE_MM[0] - 16)
        pdf.say(page.note, _NOTE_SIZE, colour=_GREY)


def _block(pdf: _Pdf, block: Block) -> None:
    if block.heading:
        pdf.ln(2)
        pdf.say(block.heading, _HEADING_SIZE, bold=True, colour=block.colour)
    for paragraph in block.paragraphs:
        pdf.say(paragraph, _BODY_SIZE)


def _map_page(pdf: _Pdf, sheet: MapSheet) -> None:
    pdf.add_page()
    pdf.headline(sheet.title)
    with Image.open(sheet.image) as opened:
        ratio = opened.width / opened.height
    height = _PAGE_MM[0] - _BODY_TOP - _BODY_BOTTOM
    width = min(height * ratio, _PAGE_MM[1] * 0.6)
    pdf.image(str(sheet.image), x=_MARGIN, y=_BODY_TOP - 4, w=width, h=width / ratio)
    left = _MARGIN + width + 8
    pdf.set_xy(left, _BODY_TOP)
    pdf.set_left_margin(left)
    for text, heading in sheet.notes:
        pdf.say(text, _HEADING_SIZE if heading else _BODY_SIZE * 0.95, bold=heading)
    pdf.set_left_margin(_MARGIN)


def _cover_page(pdf: _Pdf, cover: Cover) -> None:
    pdf.add_page()
    pdf.set_xy(_MARGIN, 45)
    pdf.set_right_margin(_PAGE_MM[1] * 0.42)
    pdf.say(cover.title, 54 * _SCALE, bold=True, colour=_BLUE)
    pdf.say(cover.subtitle, 22 * _SCALE, colour=_GREY)
    pdf.say(cover.date_line, 16 * _SCALE, colour=_GREY)
    pdf.set_right_margin(_MARGIN)
    left = _PAGE_MM[1] * 0.62
    pdf.set_xy(left, 40)
    pdf.set_left_margin(left)
    pdf.say(cover.contents_heading, 20 * _SCALE, bold=True)
    for item in cover.contents:
        pdf.say(item, 14 * _SCALE)
    pdf.set_left_margin(_MARGIN)


def write_pdf(out: Path, cover: Cover, sheets: list[Page | MapSheet]) -> int:
    """Write the briefing's PDF: the cover, then each sheet in the deck's order.

    Args:
        out: Where to write it (its folder is created).
        cover: The first page.
        sheets: The deck's pages after the cover, text pages and map pages in order.

    Returns:
        The number of pages written, which can exceed the deck's when a page's text runs on.
    """
    pdf = _Pdf()
    _cover_page(pdf, cover)
    for sheet in sheets:
        if isinstance(sheet, MapSheet):
            _map_page(pdf, sheet)
        else:
            _text_page(pdf, sheet)
    out.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(out))
    return pdf.page_no()
