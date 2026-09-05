"""Modele de tableau pour l'affichage du journal.

Le modele ne detient aucun texte : il s'appuie sur un `LogStore` et ne garde
qu'un tableau d'indices visibles. Une cellule n'est decodee qu'au moment ou Qt
la demande, c'est-a-dire pour les quelques dizaines de lignes a l'ecran. Le cout
d'affichage est donc independant de la taille du journal.
"""

from __future__ import annotations

from array import array

from PySide6.QtCore import QAbstractTableModel, QModelIndex, QPersistentModelIndex, Qt
from PySide6.QtGui import QBrush, QColor, QFont

from ..appearance import DEFAULT_FONT_FAMILY, DEFAULT_FONT_SIZE
from ..filters import FilterSet, evaluate
from ..parser import Entry

COL_LINE, COL_TIME, COL_LEVEL, COL_SOURCE, COL_MESSAGE = range(5)
HEADERS = ("Ligne", "Heure", "Niveau", "Source", "Message")

# Role personnalise : recuperer l'entree complete depuis la vue.
EntryRole = int(Qt.ItemDataRole.UserRole) + 1

# Nombre d'entrees decodees gardees sous la main. Qt interroge chaque cellule
# d'une ligne separement : sans ce cache, une meme ligne serait decodee cinq
# fois par rafraichissement.
_CACHE_SIZE = 512


class LogModel(QAbstractTableModel):
    def __init__(self, store, rules, parent=None) -> None:
        super().__init__(parent)
        self.store = store
        self.rules = rules
        self._visible = array("l")
        self._filters = FilterSet()
        self._mono = QFont(DEFAULT_FONT_FAMILY, DEFAULT_FONT_SIZE)
        self._mono.setStyleHint(QFont.StyleHint.Monospace)
        self._bold = self._derive_bold()
        self._brushes: dict[str, QBrush] = {}
        self._cache: dict[int, Entry] = {}

    def set_font(self, font: QFont) -> None:
        """Police du `FontRole`, imposee par la fenetre.

        Les deux variantes sont construites une fois : `data()` est appele pour
        chaque cellule visible a chaque rafraichissement, et y creer un `QFont`
        revenait a en fabriquer des centaines par seconde pendant le suivi.
        """
        self._mono = QFont(font)
        self._mono.setStyleHint(QFont.StyleHint.Monospace)
        self._bold = self._derive_bold()

    def _derive_bold(self) -> QFont:
        font = QFont(self._mono)
        font.setBold(True)
        return font

    # -- interface Qt -----------------------------------------------------

    def rowCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self._visible)

    def columnCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else len(HEADERS)

    def headerData(self, section, orientation, role=Qt.ItemDataRole.DisplayRole):
        if role != Qt.ItemDataRole.DisplayRole or orientation != Qt.Orientation.Horizontal:
            return None
        return HEADERS[section]

    def data(
        self,
        index: QModelIndex | QPersistentModelIndex,
        role=Qt.ItemDataRole.DisplayRole,
    ):
        if not index.isValid():
            return None
        entry = self.entry_at(index.row())
        if entry is None:
            return None
        column = index.column()

        if role == Qt.ItemDataRole.DisplayRole:
            return self._display(entry, column)
        if role == EntryRole:
            return entry
        if role == Qt.ItemDataRole.ForegroundRole:
            return self._foreground(entry, column)
        if role == Qt.ItemDataRole.BackgroundRole:
            style = self.rules.level_style(entry.level)
            return self._brush(style.background) if style.background else None
        if role == Qt.ItemDataRole.FontRole:
            return self._bold if self.rules.level_style(entry.level).weight >= 600 else self._mono
        if role == Qt.ItemDataRole.ToolTipRole and entry.continuations:
            return entry.text
        if role == Qt.ItemDataRole.TextAlignmentRole and column == COL_LINE:
            return int(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        return None

    # -- rendu ------------------------------------------------------------

    def _display(self, entry: Entry, column: int):
        if column == COL_LINE:
            return entry.lineno
        if column == COL_TIME:
            return entry.time_only
        if column == COL_LEVEL:
            return entry.level
        if column == COL_SOURCE:
            label = entry.source_label
            return f"{label}-{entry.module}" if entry.module else label
        message = entry.message or entry.raw
        if entry.continuations:
            # Signale qu'une trace est repliee derriere la ligne.
            return f"{message}  [+{len(entry.continuations)}]"
        return message

    def _foreground(self, entry: Entry, column: int):
        if column == COL_SOURCE:
            return self._brush(self.rules.source_color(entry.source))
        if column in (COL_LINE, COL_TIME):
            return self._brush("#6e7681")
        return self._brush(self.rules.level_style(entry.level).color)

    def _brush(self, color: str) -> QBrush:
        brush = self._brushes.get(color)
        if brush is None:
            brush = QBrush(QColor(color))
            self._brushes[color] = brush
        return brush

    # -- alimentation -----------------------------------------------------

    def refresh_from_store(self) -> int:
        """Recalcule les lignes visibles apres l'arrivee de nouvelles entrees.

        Tant que rien n'est filtre, les nouvelles entrees sont simplement
        ajoutees a la suite : reevaluer un million de lignes a chaque battement
        du suivi serait inutile.
        """
        total = len(self.store)
        known = self._visible[-1] + 1 if len(self._visible) else 0

        if self._filters.is_empty and known == len(self._visible):
            if total <= known:
                return 0
            first = len(self._visible)
            self.beginInsertRows(QModelIndex(), first, first + (total - known) - 1)
            self._visible.extend(range(known, total))
            self.endInsertRows()
            return total - known

        before = len(self._visible)
        self.refilter()
        return max(0, len(self._visible) - before)

    def clear(self) -> None:
        self.beginResetModel()
        self._visible = array("l")
        self._cache.clear()
        self.endResetModel()

    # -- filtrage ---------------------------------------------------------

    def set_filters(self, filters: FilterSet) -> None:
        self._filters = filters
        self.refilter()

    def refilter(self) -> None:
        self.beginResetModel()
        self._cache.clear()
        self._visible = array("l", evaluate(self.store, self._filters))
        self.endResetModel()

    @property
    def filters(self) -> FilterSet:
        return self._filters

    # -- consultation -----------------------------------------------------

    def entry_at(self, row: int) -> Entry | None:
        if not 0 <= row < len(self._visible):
            return None
        index = self._visible[row]
        entry = self._cache.get(index)
        if entry is None:
            if len(self._cache) >= _CACHE_SIZE:
                self._cache.clear()
            entry = self.store.entry(index)
            self._cache[index] = entry
        return entry

    def visible_indices(self) -> list[int]:
        """Indices des entrees affichees, dans l'ordre du journal.

        C'est ce que voit l'utilisateur, et donc ce sur quoi porte l'analyse :
        la reconstruire en rappelant `evaluate` donnerait la meme chose au prix
        d'un second balayage, et surtout pourrait en differer si un filtre a
        change depuis le dernier rafraichissement.
        """
        return list(self._visible)

    def row_of_index(self, index: int) -> int:
        """Ligne affichee correspondant a une entree, ou -1 si elle est masquee."""
        from bisect import bisect_left

        position = bisect_left(self._visible, index)
        if position < len(self._visible) and self._visible[position] == index:
            return position
        return -1

    def invalidate(self, index: int) -> None:
        """Signale qu'une entree a change : sa trace de pile vient d'arriver."""
        self._cache.pop(index, None)
        row = self.row_of_index(index)
        if row >= 0:
            self.dataChanged.emit(self.index(row, 0), self.index(row, len(HEADERS) - 1))

    def counts_by_level(self) -> dict[str, int]:
        return self.store.counts_by_level()

    def counts_by_source(self) -> dict[str, int]:
        return self.store.counts_by_source()

    def counts_by_noise(self) -> dict[str, int]:
        return self.store.counts_by_noise()

    @property
    def total(self) -> int:
        return len(self.store)

    @property
    def hidden_count(self) -> int:
        return len(self.store) - len(self._visible)
