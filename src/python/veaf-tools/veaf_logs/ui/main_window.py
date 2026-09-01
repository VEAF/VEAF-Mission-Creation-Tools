"""Fenetre principale : onglets de journaux, panneau lateral, profils."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QByteArray, QEvent, QObject, Qt, QTimer, QUrl, Signal
from PySide6.QtGui import (
    QAction,
    QDesktopServices,
    QFont,
    QFontMetrics,
    QKeySequence,
    QWheelEvent,
)
from PySide6.QtWidgets import (
    QApplication,
    QComboBox,
    QFileDialog,
    QFontDialog,
    QHBoxLayout,
    QHeaderView,
    QInputDialog,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMenu,
    QMessageBox,
    QPlainTextEdit,
    QProgressBar,
    QPushButton,
    QSplitter,
    QStatusBar,
    QTableView,
    QTabWidget,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

from ..appearance import DEFAULT_FONT_FAMILY, DEFAULT_FONT_SIZE, clamp_font_size
from ..filters import FilterSet, highlight_patterns
from ..parser import Entry
from ..profiles import DEFAULT_PROFILE, ProfileStore
from ..rules import Rules
from ..session import OpenFile, Session
from ..store import LogStore
from ..tailer import LogSource, LogUnavailable, archive_members
from .delegate import MessageDelegate
from .indexing import ProgressiveIndexer
from .model import COL_LEVEL, COL_LINE, COL_MESSAGE, COL_SOURCE, COL_TIME, LogModel
from .panels import SearchBar, SidePanel

POLL_MS = 400

# Colonnes de largeur fixe : le reste de la place revient au message.
FIXED_COLUMNS = (COL_LINE, COL_TIME, COL_LEVEL, COL_SOURCE)

# Marge de la colonne Message, en caracteres : le `[+3]` d'une trace repliee,
# plus de quoi ne pas coller le dernier caractere au bord.
MESSAGE_MARGIN_CHARS = 8

# Intervalle minimal entre deux reconstructions du panneau lateral pendant
# l'indexation d'un gros journal.
PANEL_REFRESH_MS = 400


def _now_ms() -> float:
    from time import perf_counter

    return perf_counter() * 1000


DIALOG_FILTER = "Journaux DCS (*.log *.log.old *.zip);;Tous les fichiers (*)"


class LogTab(QWidget):
    """Un journal ouvert : sa source, son index, sa vue."""

    counts_changed = Signal()
    indexing_finished = Signal()
    # +1 / -1, emis par Ctrl+molette sur la table.
    zoom_requested = Signal(int)

    def __init__(self, source: LogSource, rules: Rules, parent=None) -> None:
        super().__init__(parent)
        self.source = source
        self.rules = rules
        self.store = LogStore(rules, source.buffer)
        self.model = LogModel(self.store, rules, self)
        self.follow = source.followable
        self._last_panel_refresh = 0.0
        self.detail_enabled = True
        # Vrai pendant qu'on pose nous-memes la largeur de la colonne Message :
        # `sectionResized` ne dit pas qui l'a redimensionnee.
        self._setting_width = False
        self._user_width = False

        self.view = QTableView()
        self.view.setModel(self.model)
        self.view.setShowGrid(False)
        self.view.setSelectionBehavior(QTableView.SelectionBehavior.SelectRows)
        self.view.setWordWrap(False)
        self.view.verticalHeader().setVisible(False)
        # Le defilement horizontal par element sauterait une colonne entiere.
        self.view.setHorizontalScrollMode(QTableView.ScrollMode.ScrollPerPixel)

        self.delegate = MessageDelegate(self.view)
        self.view.setItemDelegateForColumn(COL_MESSAGE, self.delegate)

        header = self.view.horizontalHeader()
        header.setSectionResizeMode(QHeaderView.ResizeMode.Interactive)
        # `Stretch` sur la colonne Message la definissait comme etant exactement
        # le viewport : aucune barre horizontale ne pouvait apparaitre, donc la
        # fin d'une longue ligne etait hors d'atteinte.
        header.setSectionResizeMode(COL_MESSAGE, QHeaderView.ResizeMode.Interactive)
        header.setStretchLastSection(False)
        header.sectionResized.connect(self._on_section_resized)
        self.view.setColumnWidth(COL_LINE, 68)
        self.view.setColumnWidth(COL_TIME, 92)
        self.view.setColumnWidth(COL_LEVEL, 78)
        self.view.setColumnWidth(COL_SOURCE, 130)

        self.detail = QPlainTextEdit()
        self.detail.setReadOnly(True)
        self.detail.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)
        self.detail.setVisible(False)
        self.detail.setStyleSheet("background:#161b22; border:none;")

        # Un `QSplitter` plutot qu'un empilement : le detail s'ouvre desormais
        # pour toute ligne, et une trace de pile de quarante lignes chasserait
        # la table hors de la fenetre s'il prenait la hauteur qu'il demande.
        self.split = QSplitter(Qt.Orientation.Vertical)
        self.split.addWidget(self.view)
        self.split.addWidget(self.detail)
        self.split.setStretchFactor(0, 1)
        self.split.setCollapsible(0, False)
        # Un cinquieme de la hauteur : de quoi lire le debut d'une trace de pile
        # sans amputer la table. Le reste se prend a la souris.
        self.split.setSizes([5, 1])

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.split)

        self.progress = QProgressBar()
        self.progress.setVisible(False)
        self.progress.setFormat("Indexation… %p%")
        self.progress.setMaximumHeight(16)
        layout.addWidget(self.progress)

        self.cancel_button = QPushButton("Interrompre l'indexation")
        self.cancel_button.setVisible(False)
        self.cancel_button.clicked.connect(self._cancel_indexing)
        layout.addWidget(self.cancel_button)

        self.view.selectionModel().selectionChanged.connect(self.refresh_detail)
        self.view.selectionModel().currentRowChanged.connect(self.refresh_detail)
        self.view.viewport().installEventFilter(self)
        self.view.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.view.customContextMenuRequested.connect(self._show_context_menu)

        self.set_font(QFont(DEFAULT_FONT_FAMILY, DEFAULT_FONT_SIZE))

        self.indexer = ProgressiveIndexer(self.store, self)
        self.indexer.batch_ready.connect(self._on_batch)
        self.indexer.progress.connect(self._on_progress)
        self.indexer.finished.connect(self._on_indexing_done)

    # -- apparence --------------------------------------------------------

    def set_font(self, font: QFont) -> None:
        """Impose la police a la table, au modele et au detail.

        La hauteur de ligne en decoule : elle etait ecrite en dur a 18 pixels,
        ce qui coupait les glyphes des la taille augmentee.
        """
        self.view.setFont(font)
        self.model.set_font(font)
        self.detail.setFont(font)
        metrics = QFontMetrics(font)
        self.view.verticalHeader().setDefaultSectionSize(metrics.height() + 4)
        # Changer de police redefinit ce qu'est une largeur correcte : on reprend
        # la main sur une colonne que l'utilisateur avait tiree.
        self._user_width = False
        self.sync_message_width()

    def sync_message_width(self) -> None:
        """Ajuste la colonne Message au plus long message du journal.

        En dessous de la place disponible, on prend la place disponible : un
        journal de lignes courtes ne doit pas laisser une bande vide a droite.
        """
        if self._user_width:
            return
        metrics = QFontMetrics(self.view.font())
        needed = metrics.horizontalAdvance("0") * (self.store.max_message_length + MESSAGE_MARGIN_CHARS)
        header = self.view.horizontalHeader()
        available = self.view.viewport().width() - sum(header.sectionSize(column) for column in FIXED_COLUMNS)
        self._setting_width = True
        try:
            self.view.setColumnWidth(COL_MESSAGE, max(needed, available, 200))
        finally:
            self._setting_width = False

    def _on_section_resized(self, index: int, _old: int, _new: int) -> None:
        if index == COL_MESSAGE and not self._setting_width:
            self._user_width = True

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self.sync_message_width()

    def eventFilter(self, watched: QObject, event: QEvent) -> bool:
        """Ctrl+molette sur la table : zoom plutot que defilement."""
        if isinstance(event, QWheelEvent) and event.modifiers() & Qt.KeyboardModifier.ControlModifier:
            delta = event.angleDelta().y()
            if delta:
                self.zoom_requested.emit(1 if delta > 0 else -1)
            return True
        return super().eventFilter(watched, event)

    # -- indexation -------------------------------------------------------

    def start_indexing(self) -> None:
        """Lance l'indexation initiale.

        La barre n'apparait que si le journal est assez gros pour que
        l'indexation se poursuive en tranches.
        """
        poursuit = self.indexer.start()
        self.progress.setVisible(poursuit)
        self.cancel_button.setVisible(poursuit)

    def _cancel_indexing(self) -> None:
        self.indexer.cancel()

    def _on_batch(self, added: int) -> None:
        shown = self.model.refresh_from_store()
        self.sync_message_width()
        if shown and self.follow:
            self.view.scrollToBottom()
        # Pendant l'indexation d'un gros journal, reconstruire le panneau a
        # chaque tranche coute plus cher que l'indexation elle-meme. On espace,
        # et `_on_indexing_done` donne le compte definitif.
        if not self.indexer.running or self._since_refresh() > PANEL_REFRESH_MS:
            self._last_panel_refresh = _now_ms()
            self.counts_changed.emit()

    def _since_refresh(self) -> float:
        return _now_ms() - self._last_panel_refresh

    def _on_progress(self, done: int, total: int) -> None:
        if total <= 0:
            return
        self.progress.setMaximum(total)
        self.progress.setValue(done)

    def _on_indexing_done(self) -> None:
        self.progress.setVisible(False)
        self.cancel_button.setVisible(False)
        self.counts_changed.emit()
        self.indexing_finished.emit()

    def poll(self) -> int:
        """Prend en compte ce qui a ete ecrit depuis le dernier passage."""
        if self.indexer.running:
            # L'indexation initiale avance deja : la laisser finir plutot que
            # de lui disputer le curseur.
            return 0
        try:
            rotated = self.source.check_rotation(self.store.indexed_bytes)
        except LogUnavailable:
            return 0

        if rotated:
            # DCS a remplace le journal : on repart du nouveau fichier.
            self.store.buffer = self.source.reopen()
            self.store.clear()
            self.model.clear()

        last_before = len(self.store) - 1
        added = self.store.index_new()
        if not added:
            return 0

        # La derniere entree deja affichee a pu recevoir sa trace de pile.
        if last_before >= 0:
            self.model.invalidate(last_before)
        shown = self.model.refresh_from_store()
        self.sync_message_width()
        if shown and self.follow:
            self.view.scrollToBottom()
        self.counts_changed.emit()
        return added

    def close_source(self) -> None:
        self.source.close()

    # -- detail -----------------------------------------------------------

    def set_detail_enabled(self, enabled: bool) -> None:
        self.detail_enabled = enabled
        self.refresh_detail()

    def refresh_detail(self) -> None:
        """Montre l'entree courante en entier, quel que soit son niveau.

        Le panneau ne s'ouvrait que pour les entrees portant une trace de pile,
        c'est-a-dire justement celles qui etaient deja les moins tronquees.
        """
        entry = self.current_entry()
        if entry is None or not self.detail_enabled:
            self.detail.setVisible(False)
            self.detail.clear()
            return
        self.detail.setPlainText(entry.text)
        self.detail.setVisible(True)

    def current_entry(self) -> Entry | None:
        index = self.view.currentIndex()
        if not index.isValid() or not self.view.selectionModel().hasSelection():
            return None
        return self.model.entry_at(index.row())

    # -- copie ------------------------------------------------------------

    def selected_entries(self) -> list[Entry]:
        rows = sorted(index.row() for index in self.view.selectionModel().selectedRows())
        found = (self.model.entry_at(row) for row in rows)
        return [entry for entry in found if entry is not None]

    def copy_selection(self, message_only: bool = False) -> int:
        """Copie les lignes selectionnees. Rend le nombre d'entrees copiees.

        Une entree porte sa trace de pile : la copier sans elle rendrait un
        `Mission script error` que rien n'explique.
        """
        entries = self.selected_entries()
        if not entries:
            return 0
        if message_only:
            text = "\n".join(entry.message or entry.raw for entry in entries)
        else:
            text = "\n".join(entry.text for entry in entries)
        QApplication.clipboard().setText(text)
        return len(entries)

    def _show_context_menu(self, position) -> None:
        if not self.view.selectionModel().hasSelection():
            return
        menu = QMenu(self.view)
        count = len(self.view.selectionModel().selectedRows())
        lignes = "la ligne" if count == 1 else f"les {count} lignes"
        menu.addAction(f"Copier {lignes}", lambda: self.copy_selection())
        menu.addAction(
            f"Copier {'le message' if count == 1 else 'les messages'} sans l'en-tete",
            lambda: self.copy_selection(message_only=True),
        )
        menu.exec(self.view.viewport().mapToGlobal(position))


class MainWindow(QMainWindow):
    def __init__(self, rules: Rules, session: Session) -> None:
        super().__init__()
        self.rules = rules
        self.session = session
        self.profiles = ProfileStore(rules)
        self.filters: FilterSet = session.get_filters()
        # Vrai pendant qu'on reflete un etat dans les widgets : sans ce verrou,
        # le signal emis par les widgets serait repris comme une action de
        # l'utilisateur et reecrirait aussitot ce qu'on vient de charger.
        self._syncing = False

        # Police unique, poussee a chaque onglet ouvert ou a ouvrir.
        self.font_family = session.font_family or DEFAULT_FONT_FAMILY
        self.font_size = clamp_font_size(session.font_size)
        self.detail_enabled = bool(session.detail_visible)

        self.setWindowTitle("veaf-logs — journaux DCS")
        self.resize(1500, 900)

        self.tabs = QTabWidget()
        self.tabs.setTabsClosable(True)
        self.tabs.setMovable(True)
        self.tabs.tabCloseRequested.connect(self.close_tab)
        self.tabs.currentChanged.connect(self._on_tab_changed)

        self.side = SidePanel(rules)
        self.side.changed.connect(self._on_side_changed)

        self.search = SearchBar()
        self.search.changed.connect(self.apply_filters)
        self.search.add_requested.connect(self.add_current_filter)

        right = QWidget()
        right_layout = QVBoxLayout(right)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(0)
        right_layout.addWidget(self._build_profile_bar())
        right_layout.addWidget(self.search)
        right_layout.addWidget(self._build_chips())
        right_layout.addWidget(self.tabs, 1)

        splitter = QSplitter()
        splitter.addWidget(self.side)
        splitter.addWidget(right)
        splitter.setStretchFactor(1, 1)
        splitter.setSizes([320, 1180])
        self.setCentralWidget(splitter)

        self.status = QStatusBar()
        self.setStatusBar(self.status)
        self.status_counts = QLabel()
        self.status_follow = QLabel()
        # Les deux sont permanents : `showMessage()` occupe la zone de gauche
        # et masquerait un widget ordinaire au lieu de cohabiter avec lui.
        self.status.addPermanentWidget(self.status_counts)
        self.status.addPermanentWidget(self.status_follow)

        self._build_menus()
        self._refresh_chips()
        self._sync_side()

        self.timer = QTimer(self)
        self.timer.timeout.connect(self._poll_all)
        self.timer.start(POLL_MS)

        self._restore(session)

    # -- barre de profils -------------------------------------------------

    def _build_profile_bar(self) -> QWidget:
        bar = QWidget()
        layout = QHBoxLayout(bar)
        layout.setContentsMargins(6, 4, 6, 2)

        layout.addWidget(QLabel("Profil :"))
        self.profile_box = QComboBox()
        self.profile_box.setMinimumWidth(250)
        self.profile_box.setToolTip("Jeu de filtres enregistre")
        layout.addWidget(self.profile_box)

        self.profile_save = QToolButton()
        self.profile_save.setText("Enregistrer…")
        self.profile_save.setToolTip("Enregistrer les filtres courants sous un nom")
        self.profile_save.clicked.connect(self.save_profile)
        layout.addWidget(self.profile_save)

        self.profile_delete = QToolButton()
        self.profile_delete.setText("Supprimer")
        self.profile_delete.clicked.connect(self.delete_profile)
        layout.addWidget(self.profile_delete)

        layout.addStretch(1)

        # Zoom a portee de souris : tout le monde ne lit pas les menus.
        self.zoom_out = QToolButton()
        self.zoom_out.setText("A−")
        self.zoom_out.setToolTip("Reduire la police  (Ctrl+-, ou Ctrl+molette)")
        self.zoom_out.clicked.connect(lambda: self.zoom(-1))
        layout.addWidget(self.zoom_out)

        self.zoom_in = QToolButton()
        self.zoom_in.setText("A+")
        self.zoom_in.setToolTip("Agrandir la police  (Ctrl++, ou Ctrl+molette)")
        self.zoom_in.clicked.connect(lambda: self.zoom(1))
        layout.addWidget(self.zoom_in)
        self._reload_profile_box(self.session.profile or DEFAULT_PROFILE)
        self.profile_box.currentTextChanged.connect(self.load_profile)
        return bar

    def _build_chips(self) -> QWidget:
        self.chips = QWidget()
        self.chips_layout = QHBoxLayout(self.chips)
        self.chips_layout.setContentsMargins(6, 0, 6, 4)
        self.chips_layout.addStretch(1)
        self.chips.setVisible(False)
        return self.chips

    def _reload_profile_box(self, selected: str | None = None) -> None:
        self.profile_box.blockSignals(True)
        self.profile_box.clear()
        # En tete : les filtres en cours, qui n'ont pas encore de nom.
        self.profile_box.addItem(DEFAULT_PROFILE)
        self.profile_box.insertSeparator(1)
        self.profile_box.addItems(self.profiles.names())
        if selected:
            self.profile_box.setCurrentIndex(max(0, self.profile_box.findText(selected)))
        self.profile_box.blockSignals(False)
        self._update_profile_buttons()

    def _update_profile_buttons(self) -> None:
        name = self.profile_box.currentText()
        self.profile_delete.setEnabled(name != DEFAULT_PROFILE and not self.profiles.is_builtin(name))

    def load_profile(self, name: str) -> None:
        if not name or name == DEFAULT_PROFILE:
            self._update_profile_buttons()
            return
        filters = self.profiles.get(name)
        if filters is None:
            return
        self.filters = filters
        self.search.field.clear()
        if self.profile_box.currentText() != name:
            self.profile_box.blockSignals(True)
            self.profile_box.setCurrentIndex(max(0, self.profile_box.findText(name)))
            self.profile_box.blockSignals(False)
        self._sync_side()
        self._refresh_chips()
        self.apply_filters()
        self._update_profile_buttons()
        self.status.showMessage(f"Profil « {name} » charge.", 3000)

    def save_profile(self) -> None:
        current = self.profile_box.currentText()
        known = current == DEFAULT_PROFILE or self.profiles.is_builtin(current)
        name, ok = QInputDialog.getText(self, "Enregistrer le profil", "Nom :", text="" if known else current)
        if not ok:
            return
        self.side.collect(self.filters)
        try:
            self.profiles.save_profile(name, self.filters)
        except (ValueError, OSError) as exc:
            QMessageBox.warning(self, "Profil non enregistre", str(exc))
            return
        self._reload_profile_box(name.strip())
        self.status.showMessage(f"Profil « {name.strip()} » enregistre.", 3000)

    def delete_profile(self) -> None:
        name = self.profile_box.currentText()
        if name == DEFAULT_PROFILE or self.profiles.is_builtin(name):
            return
        confirm = QMessageBox.question(self, "Supprimer le profil", f"Supprimer definitivement « {name} » ?")
        if confirm != QMessageBox.StandardButton.Yes:
            return
        try:
            self.profiles.delete(name)
        except (ValueError, OSError) as exc:
            QMessageBox.warning(self, "Profil conserve", str(exc))
            return
        self._reload_profile_box(DEFAULT_PROFILE)

    # -- menus ------------------------------------------------------------

    def _build_menus(self) -> None:
        files = self.menuBar().addMenu("&Fichier")
        self._action(files, "Ouvrir le journal DCS courant", "Ctrl+D", self.open_current_dcs_log)
        self._action(files, "Ouvrir un fichier…", QKeySequence.StandardKey.Open, self.open_dialog)
        files.addSeparator()
        self._action(files, "Fermer l'onglet", "Ctrl+W", lambda: self.close_tab(self.tabs.currentIndex()))
        self._action(files, "Quitter", "Ctrl+Q", self.close)

        edition = self.menuBar().addMenu("&Edition")
        self._action(edition, "Copier", QKeySequence.StandardKey.Copy, self.copy_selection)
        self._action(edition, "Copier sans l'en-tete", "Ctrl+Shift+C", self.copy_messages)
        edition.addSeparator()
        self._action(edition, "Tout selectionner", QKeySequence.StandardKey.SelectAll, self.select_all)

        view = self.menuBar().addMenu("&Affichage")
        self.action_follow = self._action(view, "Suivre la fin du fichier", "F", self.toggle_follow, checkable=True)
        self.action_follow.setChecked(True)
        self._action(view, "Aller a la fin", "Ctrl+Fin", self.scroll_to_end)
        view.addSeparator()
        self._action(view, "Police…", None, self.choose_font)
        agrandir = self._action(view, "Agrandir", QKeySequence.StandardKey.ZoomIn, lambda: self.zoom(1))
        # `ZoomIn` est Ctrl++, qui demande Shift sur un clavier francais.
        agrandir.setShortcuts([QKeySequence(QKeySequence.StandardKey.ZoomIn), QKeySequence("Ctrl+=")])
        self._action(view, "Reduire", QKeySequence.StandardKey.ZoomOut, lambda: self.zoom(-1))
        self._action(view, "Taille par defaut", "Ctrl+0", self.reset_font)
        self.action_detail = self._action(view, "Panneau de detail", "Ctrl+I", self.toggle_detail, checkable=True)
        self.action_detail.setChecked(self.detail_enabled)
        view.addSeparator()
        self._action(view, "Tout afficher (reinitialiser les filtres)", "Ctrl+R", self.reset_filters)
        self._action(view, "Chercher", "Ctrl+F", lambda: self.search.field.setFocus())

        profils = self.menuBar().addMenu("&Profils")
        self._action(profils, "Enregistrer sous…", "Ctrl+S", self.save_profile)
        self._action(profils, "Supprimer le profil courant", None, self.delete_profile)

        rules_menu = self.menuBar().addMenu("&Regles")
        self._action(rules_menu, "Recharger le catalogue", "F5", self.reload_rules)
        self._action(rules_menu, "Ouvrir rules.json", None, self.open_rules_file)

    def _action(self, menu, text, shortcut, slot, checkable=False) -> QAction:
        action = QAction(text, self)
        if shortcut:
            action.setShortcut(shortcut)
        action.setCheckable(checkable)
        action.triggered.connect(slot)
        menu.addAction(action)
        self.addAction(action)
        return action

    # -- ouverture --------------------------------------------------------

    def open_current_dcs_log(self) -> None:
        path = Path.home() / "Saved Games" / "DCS" / "Logs" / "dcs.log"
        if not path.exists():
            QMessageBox.warning(
                self,
                "Journal introuvable",
                f"Aucun fichier a {path}.\nUtilise « Ouvrir un fichier… ».",
            )
            return
        self.open_path(path)

    def open_dialog(self) -> None:
        start = str(Path.home() / "Saved Games" / "DCS" / "Logs")
        paths, _ = QFileDialog.getOpenFileNames(self, "Ouvrir un journal DCS", start, DIALOG_FILTER)
        for path in paths:
            self.open_path(Path(path))

    def open_path(self, path: Path, member: str | None = None) -> LogTab | None:
        path = Path(path)
        if path.suffix.lower() == ".zip" and member is None:
            member = self._choose_archive_member(path)
            if member is None:
                return None

        source = LogSource(path, archive_member=member)
        try:
            source.open()
        except (LogUnavailable, OSError) as exc:
            QMessageBox.warning(self, "Ouverture impossible", str(exc))
            return None

        tab = LogTab(source, self.rules, self)
        tab.counts_changed.connect(self._refresh_side)
        tab.zoom_requested.connect(self.zoom)
        self.apply_appearance(tab)
        index = self.tabs.addTab(tab, source.display_name)
        self.tabs.setTabToolTip(index, str(path))
        self.tabs.setCurrentIndex(index)

        tab.indexing_finished.connect(self._refresh_side)
        tab.start_indexing()
        self._refresh_side()
        self.apply_filters()
        return tab

    def _choose_archive_member(self, path: Path) -> str | None:
        """Une archive DCS contient aussi le vidage memoire et la mission."""
        try:
            members = archive_members(path)
        except (OSError, ValueError) as exc:
            QMessageBox.warning(self, "Archive illisible", str(exc))
            return None
        if not members:
            QMessageBox.warning(self, "Archive", f"Aucun journal dans {path.name}.")
            return None
        if len(members) == 1:
            return members[0]
        choice, ok = QInputDialog.getItem(
            self,
            "Contenu de l'archive",
            f"{path.name} contient plusieurs fichiers :",
            members,
            0,
            False,
        )
        return choice if ok else None

    def close_tab(self, index: int) -> None:
        if index < 0:
            return
        widget = self.tabs.widget(index)
        self.tabs.removeTab(index)
        if isinstance(widget, LogTab):
            widget.close_source()
            widget.deleteLater()
        self._refresh_side()

    # -- filtres ----------------------------------------------------------

    def current_tab(self) -> LogTab | None:
        widget = self.tabs.currentWidget()
        return widget if isinstance(widget, LogTab) else None

    def _tabs(self):
        """Onglets de journal, dans l'ordre."""
        for index in range(self.tabs.count()):
            widget = self.tabs.widget(index)
            if isinstance(widget, LogTab):
                yield widget

    def effective_filters(self) -> FilterSet:
        """Filtres enregistres, plus le critere en cours de frappe."""
        effective = self.filters.copy()
        live = self.search.current_filter()
        if live.pattern:
            effective.text_filters.append(live)
        return effective

    def apply_filters(self) -> None:
        effective = self.effective_filters()
        patterns = highlight_patterns(effective)
        for tab in self._tabs():
            tab.model.set_filters(effective)
            tab.delegate.set_patterns(patterns)
            tab.view.viewport().update()
            tab.refresh_detail()
        self.search.set_common_context(self.filters.search_context_lines)
        self._refresh_status()

    def _on_side_changed(self) -> None:
        if self._syncing:
            return
        self.side.collect(self.filters)
        self._mark_modified()
        self.apply_filters()

    def _mark_modified(self) -> None:
        """Les filtres ne correspondent plus au profil affiche.

        On revient a l'entree sans nom plutot que de laisser croire que le
        profil enregistre a change.
        """
        if self.profile_box.currentText() == DEFAULT_PROFILE:
            return
        self.profile_box.blockSignals(True)
        self.profile_box.setCurrentIndex(0)
        self.profile_box.blockSignals(False)
        self._update_profile_buttons()

    def add_current_filter(self) -> None:
        live = self.search.current_filter()
        if not live.pattern:
            return
        self.filters.text_filters.append(live)
        self.search.field.clear()
        self._mark_modified()
        self._refresh_chips()
        self.apply_filters()

    def remove_filter(self, index: int) -> None:
        if 0 <= index < len(self.filters.text_filters):
            del self.filters.text_filters[index]
            self._mark_modified()
            self._refresh_chips()
            self.apply_filters()

    def _refresh_chips(self) -> None:
        while self.chips_layout.count() > 1:
            item = self.chips_layout.takeAt(0)
            widget = item.widget() if item is not None else None
            if widget is not None:
                widget.setParent(None)
                widget.deleteLater()
        for position, text_filter in enumerate(self.filters.text_filters):
            button = QPushButton(f"{text_filter.describe()}  ✕")
            button.setToolTip("Retirer ce filtre")
            button.setFlat(True)
            button.setStyleSheet(
                "QPushButton { background:#21262d; border:1px solid #30363d; border-radius:9px; padding:2px 8px; }"
            )
            button.clicked.connect(lambda _=False, i=position: self.remove_filter(i))
            self.chips_layout.insertWidget(position, button)
        self.chips.setVisible(bool(self.filters.text_filters))

    def reset_filters(self) -> None:
        self.filters = FilterSet()
        self.search.field.clear()
        self._mark_modified()
        self._sync_side()
        self._refresh_chips()
        self.apply_filters()

    # -- apparence --------------------------------------------------------

    def log_font(self) -> QFont:
        font = QFont(self.font_family, self.font_size)
        font.setStyleHint(QFont.StyleHint.Monospace)
        return font

    def apply_appearance(self, tab: LogTab | None = None) -> None:
        """Pousse la police et l'etat du detail dans un onglet, ou dans tous."""
        font = self.log_font()
        targets = [tab] if tab is not None else list(self._tabs())
        for target in targets:
            target.set_font(font)
            target.set_detail_enabled(self.detail_enabled)

    def zoom(self, step: int) -> None:
        size = clamp_font_size(self.font_size + step)
        if size == self.font_size:
            return
        self.font_size = size
        self.apply_appearance()
        self.status.showMessage(f"Police : {self.font_family} {self.font_size} pt", 2000)

    def reset_font(self) -> None:
        self.font_family = DEFAULT_FONT_FAMILY
        self.font_size = DEFAULT_FONT_SIZE
        self.apply_appearance()
        self.status.showMessage(f"Police : {self.font_family} {self.font_size} pt", 2000)

    def choose_font(self) -> None:
        # PySide rend d'abord le `bool *ok` de Qt, puis la police : l'ordre
        # inverse compilait et cassait le dialogue a l'usage.
        ok, chosen = QFontDialog.getFont(
            self.log_font(),
            self,
            "Police du journal",
            QFontDialog.FontDialogOption.MonospacedFonts,
        )
        if not ok:
            return
        self.font_family = chosen.family()
        self.font_size = clamp_font_size(chosen.pointSize())
        self.apply_appearance()

    def toggle_detail(self, checked: bool) -> None:
        self.detail_enabled = checked
        for tab in self._tabs():
            tab.set_detail_enabled(checked)

    # -- copie ------------------------------------------------------------

    def copy_selection(self) -> None:
        """Copie ce qui est selectionne, la ou l'utilisateur regarde.

        Les raccourcis d'edition sont poses sur la fenetre, donc ils passent
        avant ceux des champs de saisie : sans cet aiguillage, selectionner
        trois mots dans le detail puis faire Ctrl+C copierait la ligne entiere.
        """
        focused = self.focusWidget()
        if isinstance(focused, QLineEdit) and focused.hasSelectedText():
            focused.copy()
            return
        tab = self.current_tab()
        if tab is None:
            return
        if focused is tab.detail and tab.detail.textCursor().hasSelection():
            tab.detail.copy()
            self.status.showMessage("Selection copiee.", 2000)
            return
        self._report_copy(tab.copy_selection())

    def copy_messages(self) -> None:
        tab = self.current_tab()
        if tab is not None:
            self._report_copy(tab.copy_selection(message_only=True))

    def _report_copy(self, count: int) -> None:
        if not count:
            self.status.showMessage("Rien de selectionne a copier.", 2000)
            return
        self.status.showMessage(f"{count} ligne{'s' if count > 1 else ''} copiee{'s' if count > 1 else ''}.", 2000)

    def select_all(self) -> None:
        """Tout le journal, ou tout le champ ou l'on est en train d'ecrire."""
        focused = self.focusWidget()
        if isinstance(focused, (QLineEdit, QPlainTextEdit)):
            focused.selectAll()
            return
        tab = self.current_tab()
        if tab is not None:
            tab.view.selectAll()

    # -- suivi ------------------------------------------------------------

    def toggle_follow(self, checked: bool) -> None:
        tab = self.current_tab()
        if tab is not None:
            tab.follow = checked
            if checked:
                tab.view.scrollToBottom()
        self._refresh_status()

    def scroll_to_end(self) -> None:
        tab = self.current_tab()
        if tab is not None:
            tab.view.scrollToBottom()

    def _poll_all(self) -> None:
        changed = False
        for index in range(self.tabs.count()):
            tab = self.tabs.widget(index)
            if isinstance(tab, LogTab) and tab.source.followable:
                changed |= bool(tab.poll())
        if changed:
            self._refresh_status()

    # -- catalogue --------------------------------------------------------

    def reload_rules(self) -> None:
        try:
            rules = Rules.load()
        except (OSError, ValueError) as exc:
            QMessageBox.critical(self, "Catalogue invalide", str(exc))
            return
        self.rules = rules
        self.side.rules = rules
        self.profiles = ProfileStore(rules)
        for index in range(self.tabs.count()):
            tab = self.tabs.widget(index)
            if not isinstance(tab, LogTab):
                continue
            tab.rules = rules
            tab.model.rules = rules
            tab.store.reclassify(rules)
            tab.model.clear()
        self._reload_profile_box(self.profile_box.currentText())
        self._refresh_side()
        self.apply_filters()
        self.status.showMessage("Catalogue recharge.", 4000)

    def open_rules_file(self) -> None:
        from ..rules import DEFAULT_RULES_PATH

        QDesktopServices.openUrl(QUrl.fromLocalFile(str(DEFAULT_RULES_PATH)))

    # -- rafraichissements ------------------------------------------------

    def _on_tab_changed(self) -> None:
        tab = self.current_tab()
        if tab is not None:
            self.action_follow.setChecked(tab.follow)
            self.action_follow.setEnabled(tab.source.followable)
        self._refresh_side()

    def _sync_side(self) -> None:
        """Reflete `self.filters` dans les widgets, sans declencher de rebond."""
        self._syncing = True
        try:
            self.side.apply(self.filters)
        finally:
            self._syncing = False

    def _refresh_side(self) -> None:
        tab = self.current_tab()
        if tab is None:
            return
        self._syncing = True
        try:
            self.side.refresh(tab.model)
            self.side.apply(self.filters)
        finally:
            self._syncing = False
        self._refresh_status()

    def _refresh_status(self) -> None:
        tab = self.current_tab()
        if tab is None:
            self.status_counts.setText("Aucun journal ouvert.")
            self.status_follow.setText("")
            return
        total = tab.model.total
        shown = tab.model.rowCount()
        hidden = tab.model.hidden_count
        message = f"{shown} lignes affichees sur {total}"
        if hidden:
            message += f"   —   {hidden} masquees par les filtres"
        self.status_counts.setText(message)
        if not tab.source.followable:
            self.status_follow.setText("archive (pas de suivi)")
        else:
            self.status_follow.setText("suivi actif" if tab.follow else "suivi en pause")

    # -- session ----------------------------------------------------------

    def _restore(self, session: Session) -> None:
        if session.geometry:
            self.restoreGeometry(QByteArray.fromBase64(session.geometry.encode()))
        for item in session.existing_files():
            self.open_path(Path(item.path), item.archive_member)
        if session.files and 0 <= session.active < self.tabs.count():
            self.tabs.setCurrentIndex(session.active)
        self._refresh_chips()
        self.apply_filters()

    def _capture(self) -> Session:
        files = [OpenFile(str(tab.source.path), tab.source.archive_member) for tab in self._tabs()]
        self.side.collect(self.filters)
        session = Session(
            files=files,
            active=max(0, self.tabs.currentIndex()),
            profile=self.profile_box.currentText(),
            geometry=bytes(self.saveGeometry().toBase64().data()).decode("ascii"),
            font_family=self.font_family,
            font_size=self.font_size,
            detail_visible=self.detail_enabled,
        )
        session.set_filters(self.filters)
        return session

    def closeEvent(self, event) -> None:
        try:
            self._capture().save()
        except OSError:
            # Une session non sauvegardee ne doit pas empecher de fermer.
            pass
        for tab in self._tabs():
            tab.close_source()
        super().closeEvent(event)


def main() -> int:
    """Point d'entree de la commande `veaf-logs`."""
    import sys

    return run(sys.argv)


def run(argv: list[str] | None = None) -> int:
    import sys

    argv = sys.argv if argv is None else argv
    app = QApplication(argv)
    app.setApplicationName("veaf_logs")
    app.setStyle("Fusion")
    _apply_dark_palette(app)

    rules = Rules.load()
    session = Session.load()
    window = MainWindow(rules, session)

    extra = [Path(arg) for arg in argv[1:] if not arg.startswith("-")]
    for path in extra:
        window.open_path(path)
    if not window.tabs.count() and not extra:
        default = Path.home() / "Saved Games" / "DCS" / "Logs" / "dcs.log"
        if default.exists():
            window.open_path(default)

    window.show()
    return app.exec()


def _apply_dark_palette(app: QApplication) -> None:
    from PySide6.QtGui import QColor, QPalette

    palette = QPalette()
    palette.setColor(QPalette.ColorRole.Window, QColor("#0d1117"))
    palette.setColor(QPalette.ColorRole.WindowText, QColor("#c9d1d9"))
    palette.setColor(QPalette.ColorRole.Base, QColor("#0d1117"))
    palette.setColor(QPalette.ColorRole.AlternateBase, QColor("#161b22"))
    palette.setColor(QPalette.ColorRole.Text, QColor("#c9d1d9"))
    palette.setColor(QPalette.ColorRole.Button, QColor("#21262d"))
    palette.setColor(QPalette.ColorRole.ButtonText, QColor("#c9d1d9"))
    palette.setColor(QPalette.ColorRole.Highlight, QColor("#1f6feb"))
    palette.setColor(QPalette.ColorRole.HighlightedText, QColor("#ffffff"))
    palette.setColor(QPalette.ColorRole.ToolTipBase, QColor("#161b22"))
    palette.setColor(QPalette.ColorRole.ToolTipText, QColor("#c9d1d9"))
    app.setPalette(palette)
