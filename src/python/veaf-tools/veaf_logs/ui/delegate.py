"""Rendu de la colonne Message avec surlignage des correspondances.

Qt ne sait pas colorer une partie d'une cellule ; il faut dessiner le texte
soi-meme. On passe par `QTextDocument`, qui gere le rendu riche et la mesure,
plutot que par un decoupage manuel au `QPainter` : le texte reste selectionnable
visuellement et l'elision de fin est correcte.
"""

from __future__ import annotations

import html
import re

from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import (
    QAbstractTextDocumentLayout,
    QPalette,
    QTextDocument,
    QTextOption,
)
from PySide6.QtWidgets import QApplication, QStyle, QStyledItemDelegate, QStyleOptionViewItem

from .model import COL_MESSAGE

# Fond du surlignage des correspondances de la recherche.
MATCH_BACKGROUND = "#7a5c00"
MATCH_FOREGROUND = "#ffffff"


class MessageDelegate(QStyledItemDelegate):
    """Dessine le message en surlignant ce que la recherche a trouve."""

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._patterns: list[re.Pattern] = []
        self._document = QTextDocument()
        self._document.setDocumentMargin(0)
        # Une ligne de journal reste sur une ligne : sans cela le message
        # deborde sur plusieurs lignes dans la hauteur d'une seule cellule.
        options = QTextOption()
        options.setWrapMode(QTextOption.WrapMode.NoWrap)
        self._document.setDefaultTextOption(options)

    def set_patterns(self, patterns: list[re.Pattern]) -> None:
        self._patterns = patterns

    def paint(self, painter, option: QStyleOptionViewItem, index) -> None:
        if index.column() != COL_MESSAGE or not self._patterns:
            super().paint(painter, option, index)
            return

        text = index.data(Qt.ItemDataRole.DisplayRole) or ""
        marked = self._mark(str(text))
        if marked is None:
            super().paint(painter, option, index)
            return

        self.initStyleOption(option, index)
        option.text = ""
        style = option.widget.style() if option.widget else QApplication.style()
        style.drawControl(QStyle.ControlElement.CE_ItemViewItem, option, painter, option.widget)

        colour = option.palette.color(
            QPalette.ColorRole.HighlightedText
            if option.state & QStyle.StateFlag.State_Selected
            else QPalette.ColorRole.Text
        )
        foreground = index.data(Qt.ItemDataRole.ForegroundRole)
        if foreground is not None and not (option.state & QStyle.StateFlag.State_Selected):
            colour = foreground.color()

        self._document.setDefaultFont(option.font)
        self._document.setHtml(f'<span style="color:{colour.name()}">{marked}</span>')

        painter.save()
        painter.translate(option.rect.topLeft())
        context = QAbstractTextDocumentLayout.PaintContext()
        self._document.documentLayout().draw(painter, context)
        painter.restore()

    def sizeHint(self, option: QStyleOptionViewItem, index) -> QSize:
        size = super().sizeHint(option, index)
        return QSize(size.width(), max(size.height(), option.fontMetrics.height() + 4))

    def _mark(self, text: str) -> str | None:
        """Rend le texte en HTML avec les correspondances surlignees.

        Rend None si aucun motif ne correspond : l'appelant retombe alors sur le
        rendu standard, nettement moins couteux.
        """
        spans: list[tuple[int, int]] = []
        for pattern in self._patterns:
            for match in pattern.finditer(text):
                if match.end() > match.start():
                    spans.append((match.start(), match.end()))
        if not spans:
            return None

        spans.sort()
        fused: list[list[int]] = []
        for start, end in spans:
            if fused and start <= fused[-1][1]:
                fused[-1][1] = max(fused[-1][1], end)
            else:
                fused.append([start, end])

        out: list[str] = []
        cursor = 0
        for start, end in fused:
            out.append(html.escape(text[cursor:start]))
            out.append(
                f'<span style="background-color:{MATCH_BACKGROUND};'
                f'color:{MATCH_FOREGROUND}">{html.escape(text[start:end])}</span>'
            )
            cursor = end
        out.append(html.escape(text[cursor:]))
        return "".join(out)
