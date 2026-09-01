"""Panneau lateral et barre de recherche."""

from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QComboBox,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QScrollArea,
    QSpinBox,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

from ..filters import Mode, PatternError, State, TextFilter, compile_pattern

# Symbole et infobulle de chaque etat, dans l'ordre de defilement au clic.
_STATE_CYCLE = (State.ON, State.CONTEXT, State.OFF)
_STATE_MARK = {State.ON: "✓", State.CONTEXT: "◐", State.OFF: "✕"}
_STATE_HINT = {
    State.ON: "affiche",
    State.CONTEXT: "affiche seulement autour des lignes retenues",
    State.OFF: "masque",
}


class SearchBar(QWidget):
    """Champ de recherche, choix du mode, inversion, casse, contexte."""

    changed = Signal()
    add_requested = Signal()

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        layout = QHBoxLayout(self)
        layout.setContentsMargins(6, 4, 6, 4)

        self.field = QLineEdit()
        self.field.setPlaceholderText("Rechercher…  (Ctrl+F)")
        self.field.setClearButtonEnabled(True)

        self.mode = QComboBox()
        for mode in Mode:
            self.mode.addItem(mode.label, mode)
        self.mode.setToolTip(
            "Texte : recherche litterale.\n"
            "Jokers : * (n'importe quelle suite), ? (un caractere) ; le point reste litteral.\n"
            "Regex : expression reguliere complete."
        )

        self.invert = QToolButton()
        self.invert.setText("≠")
        self.invert.setCheckable(True)
        self.invert.setToolTip("Masquer les lignes qui correspondent")

        self.case = QToolButton()
        self.case.setText("Aa")
        self.case.setCheckable(True)
        self.case.setToolTip("Respecter la casse")

        # Portee propre a ce critere. A zero, le champ affiche entre parentheses
        # la valeur commune dont il herite, plutot que de rester muet.
        self.context = QSpinBox()
        self.context.setRange(0, 999)
        self.context.setPrefix("±")
        self.context.setMaximumWidth(72)
        self.context.setToolTip(
            "Lignes gardees de part et d'autre des resultats de cette recherche.\n"
            "Entre parentheses : la valeur commune reglee dans le panneau lateral."
        )
        self.set_common_context(0)

        self.add = QPushButton("Ajouter au filtre")
        self.add.setToolTip("Cumuler ce critere avec les filtres deja actifs")

        self.error = QLabel()
        self.error.setStyleSheet("color: #ff6b6b;")

        layout.addWidget(self.field, 1)
        layout.addWidget(self.mode)
        layout.addWidget(self.invert)
        layout.addWidget(self.case)
        layout.addWidget(self.context)
        layout.addWidget(self.add)
        layout.addWidget(self.error)

        self.field.textChanged.connect(self._on_changed)
        self.mode.currentIndexChanged.connect(self._on_changed)
        self.invert.toggled.connect(self._on_changed)
        self.case.toggled.connect(self._on_changed)
        self.context.valueChanged.connect(self._on_changed)
        self.add.clicked.connect(self.add_requested)

    def current_filter(self) -> TextFilter:
        return TextFilter(
            pattern=self.field.text(),
            mode=self.mode.currentData(),
            case_sensitive=self.case.isChecked(),
            invert=self.invert.isChecked(),
            context_lines=self.context.value() or None,
        )

    def set_common_context(self, lines: int) -> None:
        """Montre la valeur commune la ou le champ n'en impose pas.

        Passe par `specialValueText` et non par un suffixe : a zero, Qt remplace
        tout l'affichage — prefixe et suffixe compris — par ce texte, donc un
        suffixe y serait invisible.
        """
        self.context.setSpecialValueText(f"({lines})")

    def _on_changed(self) -> None:
        """Valide le motif avant de propager : une regex en cours de frappe est
        souvent invalide, on affiche l'erreur sans reconstruire la vue."""
        try:
            compile_pattern(self.field.text(), self.mode.currentData(), self.case.isChecked())
        except PatternError as exc:
            self.error.setText(str(exc))
            return
        self.error.clear()
        self.changed.emit()


class StateButton(QPushButton):
    """Categorie a trois etats : affiche, contexte, masque.

    Un bouton plutot qu'une case a cocher : Qt propose bien un troisieme etat
    (`PartiallyChecked`) mais il se lit comme « partiellement selectionne »,
    alors qu'il s'agit ici d'un mode a part entiere.
    """

    changed = Signal()

    def __init__(self, key: str, label: str, count: int, colour: str | None, hint: str) -> None:
        super().__init__()
        self.key = key
        self._label = label
        self._count = count
        self._state = State.ON
        self._hint = hint
        self.setFlat(True)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self._colour = colour or "#c9d1d9"
        if colour:
            font = QFont(self.font())
            font.setBold(True)
            self.setFont(font)
        self.clicked.connect(self._cycle)
        self._render()

    def state(self) -> State:
        return self._state

    def set_state(self, state: State, notify: bool = False) -> None:
        if state == self._state:
            return
        self._state = state
        self._render()
        if notify:
            self.changed.emit()

    def set_count(self, count: int) -> None:
        if count != self._count:
            self._count = count
            self._render()

    def _cycle(self) -> None:
        position = _STATE_CYCLE.index(self._state)
        self.set_state(_STATE_CYCLE[(position + 1) % len(_STATE_CYCLE)], notify=True)

    def _render(self) -> None:
        self.setText(f" {_STATE_MARK[self._state]}  {self._label}  ({self._count})")
        colour = "#5a6169" if self._state is State.OFF else self._colour
        style = "italic" if self._state is State.CONTEXT else "normal"
        self.setStyleSheet(
            f"QPushButton {{ color:{colour}; font-style:{style}; text-align:left;"
            " border:none; padding:1px 2px; }"
            " QPushButton:hover { background:#21262d; }"
        )
        etat = f"Etat : {_STATE_HINT[self._state]}\nClic : etat suivant"
        self.setToolTip(f"{self._hint}\n\n{etat}" if self._hint else etat)


class CategoryRow(QWidget):
    """Une categorie : son bouton d'etat et, en mode contexte, sa portee.

    La portee n'apparait que lorsqu'elle a un sens. Laisser un champ inerte a
    cote de chaque categorie encombrerait le panneau pour rien.
    """

    changed = Signal()

    def __init__(self, key: str, label: str, count: int, colour: str | None, hint: str) -> None:
        super().__init__()
        self.key = key
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)

        self.button = StateButton(key, label, count, colour, hint)
        self.button.changed.connect(self._on_state_changed)
        layout.addWidget(self.button, 1)

        self.span = QSpinBox()
        self.span.setRange(0, 999)
        self.span.setPrefix("±")
        self.span.setMaximumWidth(64)
        self.span.setToolTip(
            "Lignes gardees de part et d'autre, pour cette categorie.\nVide le champ pour revenir a la valeur commune."
        )
        self.span.setSpecialValueText("")
        self.span.setVisible(False)
        self.span.valueChanged.connect(lambda _: self.changed.emit())
        layout.addWidget(self.span)

    def _on_state_changed(self) -> None:
        self._sync_span_visibility()
        self.changed.emit()

    def _sync_span_visibility(self) -> None:
        self.span.setVisible(self.button.state() is State.CONTEXT)

    # -- etat -------------------------------------------------------------

    def state(self) -> State:
        return self.button.state()

    def set_state(self, state: State) -> None:
        self.button.set_state(state)
        self._sync_span_visibility()

    def set_count(self, count: int) -> None:
        self.button.set_count(count)

    def span_value(self) -> int | None:
        """Portee choisie, ou None si la categorie suit la valeur commune."""
        if self.button.state() is not State.CONTEXT:
            return None
        return self.span.value() or None

    def set_span(self, value: int | None, default: int) -> None:
        self.span.blockSignals(True)
        self.span.setValue(0 if value is None else value)
        self.span.blockSignals(False)
        self.span.setSuffix("" if value else f" ({default})")


class StateList(QGroupBox):
    """Groupe de categories a trois etats."""

    changed = Signal()

    def __init__(self, title: str, parent=None) -> None:
        super().__init__(title, parent)
        self._layout = QVBoxLayout(self)
        self._layout.setContentsMargins(8, 6, 8, 6)
        self._layout.setSpacing(0)
        self._rows: dict[str, CategoryRow] = {}

        actions = QHBoxLayout()
        for label, state in (("tout", State.ON), ("contexte", State.CONTEXT), ("rien", State.OFF)):
            button = QToolButton()
            button.setText(label)
            button.clicked.connect(lambda _=False, s=state: self.set_all(s))
            actions.addWidget(button)
        actions.addStretch(1)
        self._layout.addLayout(actions)

    def rebuild(self, items: list[tuple[str, str, int, str | None, str]]) -> None:
        """items : (cle, libelle, compte, couleur ou None, infobulle).

        Les boutons deja presents sont conserves — seul leur compteur change —
        pour que l'etat choisi survive au rafraichissement provoque par
        l'arrivee de nouvelles lignes.
        """
        seen = set()
        for key, label, count, colour, hint in items:
            seen.add(key)
            row = self._rows.get(key)
            if row is None:
                row = CategoryRow(key, label, count, colour, hint)
                row.changed.connect(self.changed)
                self._layout.addWidget(row)
                self._rows[key] = row
            else:
                row.set_count(count)

        for key in [key for key in self._rows if key not in seen]:
            row = self._rows.pop(key)
            self._layout.removeWidget(row)
            row.setParent(None)
            row.deleteLater()

    def set_all(self, state: State) -> None:
        for row in self._rows.values():
            row.set_state(state)
        self.changed.emit()

    def apply_states(self, states: dict[str, State]) -> None:
        """Impose un etat par cle ; les cles absentes reviennent a `ON`."""
        for key, row in self._rows.items():
            row.set_state(states.get(key, State.ON))

    def states(self) -> dict[str, State]:
        """Etats differents de `ON` seulement."""
        return {key: row.state() for key, row in self._rows.items() if row.state() is not State.ON}

    def apply_spans(self, filters, kind: str) -> None:
        for key, row in self._rows.items():
            surcharge = filters.context_spans.get(filters.span_key(kind, key))
            row.set_span(surcharge, filters.context_lines)

    def collect_spans(self, filters, kind: str) -> None:
        for key, row in self._rows.items():
            filters.set_span(kind, key, row.span_value())

    def keys(self) -> list[str]:
        return list(self._rows)


class SidePanel(QScrollArea):
    """Colonne de gauche : niveaux, sources, bruit ED, largeur des contextes."""

    changed = Signal()

    def __init__(self, rules, parent=None) -> None:
        super().__init__(parent)
        self.rules = rules
        self.setWidgetResizable(True)
        self.setMinimumWidth(300)

        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(6, 6, 6, 6)

        legend = QLabel("✓ affiche     ◐ contexte     ✕ masque")
        legend.setStyleSheet("color:#8b949e; padding:2px;")
        layout.addWidget(legend)

        # Deux contextes distincts, nommes pour qu'on ne les confonde pas : les
        # categories en ◐ d'un cote, les resultats de la recherche de l'autre.
        self.context_lines = self._span_field(
            layout,
            "Contexte des categories : ±",
            "Nombre de lignes gardees de part et d'autre d'une ligne retenue,\n"
            "pour les categories en mode contexte (◐).",
        )
        self.search_context_lines = self._span_field(
            layout,
            "Contexte de recherche : ±",
            "Nombre de lignes gardees autour de chaque resultat de recherche.\n"
            "Elles restent soumises aux filtres : une ligne masquee le reste.",
        )

        self.levels = StateList("Niveaux")
        self.sources = StateList("Sources")
        self.noise = StateList("Bruit ED")
        for widget in (self.levels, self.sources, self.noise):
            widget.changed.connect(self.changed)
            layout.addWidget(widget)
        layout.addStretch(1)
        self.setWidget(content)

    def _span_field(self, layout: QVBoxLayout, label: str, hint: str) -> QSpinBox:
        row = QHBoxLayout()
        row.addWidget(QLabel(label))
        spin = QSpinBox()
        spin.setRange(0, 200)
        spin.setSuffix(" lignes")
        spin.setToolTip(hint)
        spin.valueChanged.connect(self.changed)
        row.addWidget(spin)
        row.addStretch(1)
        layout.addLayout(row)
        return spin

    def refresh(self, model) -> None:
        """Met a jour les compteurs sans toucher aux etats choisis."""
        levels = model.counts_by_level()
        self.levels.rebuild(
            [
                (level, level, levels[level], self.rules.level_style(level).color, "")
                for level in sorted(levels, key=self.rules.level_order)
            ]
        )

        labels = self.rules.source_labels()
        sources = model.counts_by_source()
        self.sources.rebuild(
            [
                (source, labels.get(source, source), count, self.rules.source_color(source), "")
                for source, count in sorted(sources.items(), key=lambda kv: -kv[1])
            ]
        )

        noise = model.counts_by_noise()
        self.noise.rebuild(
            [
                (family.id, family.label, noise.get(family.id, 0), None, family.help)
                for family in self.rules.noise
                if noise.get(family.id, 0) or family.default_hidden
            ]
        )

    # -- lecture / ecriture de l'etat -------------------------------------

    def apply(self, filters) -> None:
        for kind, widget in self._lists():
            widget.apply_states(getattr(filters, kind))
            widget.apply_spans(filters, kind)
        for spin, value in (
            (self.context_lines, filters.context_lines),
            (self.search_context_lines, filters.search_context_lines),
        ):
            spin.blockSignals(True)
            spin.setValue(value)
            spin.blockSignals(False)

    def _lists(self):
        return (("levels", self.levels), ("sources", self.sources), ("noise", self.noise))

    def collect(self, filters) -> None:
        """Reporte l'etat des boutons dans un jeu de filtres.

        Les categories absentes du journal courant n'ont pas de bouton : leur
        etat est conserve tel quel. Sans cela, charger un profil qui masque les
        traces DEBUG puis ouvrir un journal qui n'en contient pas encore
        perdrait la consigne, et les premieres traces venues s'afficheraient.
        """

        def merge(current: dict, shown: dict, keys: list[str]) -> dict:
            merged = {key: state for key, state in current.items() if key not in keys}
            merged.update(shown)
            return merged

        filters.context_lines = self.context_lines.value()
        filters.search_context_lines = self.search_context_lines.value()
        for kind, widget in self._lists():
            setattr(filters, kind, merge(getattr(filters, kind), widget.states(), widget.keys()))
            widget.collect_spans(filters, kind)
