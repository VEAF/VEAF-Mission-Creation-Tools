"""Tests d'integration de l'interface, en rendu hors ecran.

Ils couvrent les enchainements ou les bugs se logent : l'etat des filtres qui
survit a l'ouverture d'un second onglet et au rafraichissement des compteurs,
le suivi qui alimente la vue sans relacher les filtres, et le va-et-vient entre
profils et filtres courants.
"""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

pytest.importorskip("PySide6")

from PySide6.QtCore import QItemSelectionModel, Qt  # noqa: E402
from PySide6.QtGui import QFontMetrics, QTextCursor  # noqa: E402
from PySide6.QtWidgets import QApplication, QHeaderView  # noqa: E402
from veaf_logs.appearance import (  # noqa: E402
    DEFAULT_FONT_SIZE,
    MAX_FONT_SIZE,
    MIN_FONT_SIZE,
)
from veaf_logs.filters import State  # noqa: E402
from veaf_logs.profiles import DEFAULT_PROFILE, ProfileStore  # noqa: E402
from veaf_logs.rules import Rules  # noqa: E402
from veaf_logs.session import Session  # noqa: E402
from veaf_logs.ui.main_window import MainWindow  # noqa: E402
from veaf_logs.ui.model import COL_MESSAGE  # noqa: E402
from veaf_logs_journal import ENTRIES  # noqa: E402


@pytest.fixture(scope="session")
def app():
    return QApplication.instance() or QApplication([])


@pytest.fixture
def window(app, journal_file, tmp_path, rules):
    window = MainWindow(rules, Session())
    # Profils isoles : on ne touche pas a ceux de l'utilisateur.
    window.profiles = ProfileStore(rules, tmp_path / "profiles.json")
    window._reload_profile_box(DEFAULT_PROFILE)
    window.open_path(journal_file)
    yield window
    window.timer.stop()
    window.close()


def rows(window) -> int:
    return window.current_tab().model.rowCount()


class TestChargement:
    def test_entrees_indexees(self, window):
        assert window.current_tab().model.total == ENTRIES

    def test_tout_affiche_par_defaut(self, window):
        assert rows(window) == ENTRIES

    def test_colonnes_lues_a_la_demande(self, window):
        entry = window.current_tab().model.entry_at(0)
        assert entry.level == "ERROR"
        assert entry.source_label == "APP"


class TestRecherche:
    def test_texte(self, window):
        window.search.field.setText("zone introuvable")
        window.apply_filters()
        assert rows(window) == 1

    def test_dans_une_trace_rattachee(self, window):
        window.search.field.setText("getUnitRecordById")
        window.apply_filters()
        assert rows(window) == 1

    def test_regex(self, window):
        window.search.mode.setCurrentIndex(2)
        window.search.field.setText(r"VEAF\|[WE]\|")
        window.apply_filters()
        assert rows(window) == 1

    def test_jokers(self, window):
        window.search.mode.setCurrentIndex(1)
        window.search.field.setText("No taxiroad*Batumi*")
        window.apply_filters()
        assert rows(window) == 1

    def test_regex_invalide_n_applique_rien(self, window):
        window.search.mode.setCurrentIndex(2)
        window.search.field.setText("[non fermee")
        assert window.search.error.text()
        assert rows(window) == ENTRIES

    def test_cumul_puis_retrait(self, window):
        window.search.field.setText("VEAF")
        window.add_current_filter()
        assert len(window.filters.text_filters) == 1
        # `isVisible` est faux tant que la fenetre n'est pas affichee : on
        # interroge la visibilite propre du widget.
        assert not window.chips.isHidden()
        window.remove_filter(0)
        assert window.filters.text_filters == []
        assert rows(window) == ENTRIES


class TestTriEtat:
    def test_masquer_un_niveau(self, window):
        window.side.levels.apply_states({"INFO": State.OFF})
        window.side.changed.emit()
        assert rows(window) == 4

    def test_contexte(self, window):
        window.side.levels.apply_states({"INFO": State.CONTEXT, "WARNING": State.OFF})
        window.side.context_lines.setValue(1)
        window.side.changed.emit()
        assert rows(window) == 4, "les 2 erreurs, plus 2 INFO voisines"

    def test_le_contexte_se_combine_avec_la_recherche(self, window):
        window.side.levels.apply_states({"INFO": State.CONTEXT, "WARNING": State.OFF})
        window.side.context_lines.setValue(1)
        window.side.changed.emit()
        window.search.field.setText("Mission script error")
        window.apply_filters()
        assert rows(window) == 2, "l'erreur trouvee et sa voisine de contexte"

    def test_bruit_masque_puis_niveaux(self, window):
        """Les deux dimensions se cumulent au lieu de se remplacer."""
        window.side.noise.apply_states({"damage_model": State.OFF})
        window.side.changed.emit()
        assert rows(window) == ENTRIES - 1
        window.side.levels.apply_states({"INFO": State.OFF})
        window.side.changed.emit()
        assert rows(window) == 3

    def test_reinitialiser(self, window):
        window.side.levels.apply_states({"INFO": State.OFF})
        window.side.changed.emit()
        window.reset_filters()
        assert rows(window) == ENTRIES
        assert window.filters.is_empty


class TestEtatPersistant:
    def test_second_onglet_herite_des_filtres(self, window, journal_file):
        window.side.levels.apply_states({"INFO": State.OFF})
        window.side.changed.emit()
        avant = rows(window)

        window.open_path(journal_file)
        assert rows(window) == avant, "le nouvel onglet applique les memes filtres"
        window.tabs.setCurrentIndex(0)
        assert rows(window) == avant, "l'onglet d'origine garde les siens"

    def test_le_suivi_n_efface_pas_les_filtres(self, window, journal_file):
        window.side.levels.apply_states({"INFO": State.OFF})
        window.side.changed.emit()
        avant = rows(window)
        with open(journal_file, "a", encoding="utf-8") as handle:
            handle.write("2026-08-31 12:00:00.000 INFO    APP (Main): sans interet\n")
        window._poll_all()
        assert rows(window) == avant, "une ligne INFO masquee ne doit pas apparaitre"

    def test_les_nouvelles_lignes_arrivent(self, window, journal_file):
        with open(journal_file, "a", encoding="utf-8") as handle:
            handle.write("2026-08-31 12:00:00.000 ERROR   APP (Main): nouvelle\n")
        window._poll_all()
        assert rows(window) == ENTRIES + 1

    def test_categorie_absente_conservee(self, window, journal_file):
        """Masquer DEBUG doit tenir meme si le journal n'en contient pas encore."""
        window.filters.levels["DEBUG"] = State.OFF
        window.side.collect(window.filters)
        assert window.filters.levels.get("DEBUG") is State.OFF

        with open(journal_file, "a", encoding="utf-8") as handle:
            handle.write("2026-08-31 12:00:00.000 INFO    SCRIPTING (Main): VEAF|D|1: trace\n")
        window._poll_all()
        window.apply_filters()
        assert rows(window) == ENTRIES, "la trace DEBUG ne doit pas s'afficher"


class TestProfils:
    def test_profils_fournis_listes(self, window):
        assert window.profile_box.findText("Tout") > 0

    def test_charger_un_profil_fourni(self, window):
        window.load_profile("Lecture (sans le bruit ED)")
        assert rows(window) == ENTRIES - 2, "les deux lignes de bruit connu"

    def test_charger_le_profil_diagnostic(self, window):
        window.load_profile("Diagnostic (erreurs + contexte)")
        assert window.filters.levels["INFO"] is State.CONTEXT
        assert window.side.context_lines.value() == window.filters.context_lines

    def test_enregistrer_et_recharger(self, window, tmp_path):
        window.side.levels.apply_states({"INFO": State.OFF})
        window.side.changed.emit()
        window.side.collect(window.filters)
        window.profiles.save_profile("Mon profil", window.filters)
        window._reload_profile_box("Mon profil")

        window.reset_filters()
        assert rows(window) == ENTRIES
        window.load_profile("Mon profil")
        assert rows(window) == 4

    def test_charger_ne_reecrit_pas_le_profil(self, window):
        """Refleter un profil dans les widgets ne doit pas passer pour une action."""
        window.profiles.save_profile("P", window.filters.copy())
        window.load_profile("P")
        window.side.levels.apply_states({"INFO": State.OFF})
        window.side.changed.emit()
        assert window.profiles.get("P").levels == {}, "le profil enregistre est intact"

    def test_profil_fourni_non_supprimable(self, window):
        window.profile_box.setCurrentText("Tout")
        window._update_profile_buttons()
        assert not window.profile_delete.isEnabled()


class TestPolice:
    """La police vivait en trois exemplaires, avec une hauteur de ligne en dur."""

    def test_une_seule_source_pour_la_table_et_le_detail(self, window):
        window.font_size = 9
        window.zoom(5)
        tab = window.current_tab()
        assert tab.view.font().pointSize() == 14
        assert tab.detail.font().pointSize() == 14
        assert tab.model.data(tab.model.index(0, 0), Qt.ItemDataRole.FontRole).pointSize() == 14

    def test_hauteur_de_ligne_suit_la_police(self, window):
        tab = window.current_tab()
        avant = tab.view.verticalHeader().defaultSectionSize()
        window.zoom(10)
        apres = tab.view.verticalHeader().defaultSectionSize()
        assert apres > avant
        assert apres == QFontMetrics(tab.view.font()).height() + 4

    def test_zoom_borne_en_bas(self, window):
        for _ in range(50):
            window.zoom(-1)
        assert window.font_size == MIN_FONT_SIZE

    def test_zoom_borne_en_haut(self, window):
        for _ in range(80):
            window.zoom(1)
        assert window.font_size == MAX_FONT_SIZE

    def test_taille_par_defaut(self, window):
        window.zoom(6)
        window.reset_font()
        assert window.font_size == DEFAULT_FONT_SIZE

    def test_ctrl_molette(self, window):
        """La table relaie le geste ; c'est la fenetre qui decide de la taille."""
        avant = window.font_size
        window.current_tab().zoom_requested.emit(1)
        assert window.font_size == avant + 1

    def test_nouvel_onglet_herite(self, window, journal_file):
        window.zoom(4)
        window.open_path(journal_file)
        assert window.current_tab().view.font().pointSize() == window.font_size

    def test_persistance(self, window, tmp_path, rules):
        window.zoom(7)
        chemin = tmp_path / "session.json"
        window._capture().save(chemin)

        rouverte = MainWindow(rules, Session.load(chemin))
        try:
            assert rouverte.font_size == window.font_size
        finally:
            rouverte.timer.stop()
            rouverte.close()

    def test_choix_dans_le_dialogue(self, window, monkeypatch):
        """PySide rend `(ok, police)` : l'ordre inverse compile et casse a l'usage.

        Verifie a l'execution le 2026-09-01 ; mypy le tient aussi depuis les
        stubs, ce test garde la lecture du tuple du bon cote.
        """
        from PySide6.QtGui import QFont
        from PySide6.QtWidgets import QFontDialog

        monkeypatch.setattr(QFontDialog, "getFont", lambda *a, **k: (True, QFont("Consolas", 14)))
        window.choose_font()
        assert window.font_family == "Consolas"
        assert window.font_size == 14

    def test_dialogue_annule(self, window, monkeypatch):
        from PySide6.QtGui import QFont
        from PySide6.QtWidgets import QFontDialog

        avant = window.font_size
        monkeypatch.setattr(QFontDialog, "getFont", lambda *a, **k: (False, QFont("Consolas", 30)))
        window.choose_font()
        assert window.font_size == avant

    def test_taille_aberrante_dans_la_session(self, app, rules):
        """Un `session.json` edite a la main ne doit pas empecher le lancement."""
        window = MainWindow(rules, Session(font_size=9000))
        try:
            assert window.font_size == MAX_FONT_SIZE
        finally:
            window.timer.stop()
            window.close()


class TestDefilementHorizontal:
    def test_colonne_message_non_etiree(self, window):
        """`Stretch` definissait la colonne comme etant le viewport : rien a defiler."""
        header = window.current_tab().view.horizontalHeader()
        assert header.sectionResizeMode(COL_MESSAGE) == QHeaderView.ResizeMode.Interactive

    def test_largeur_suit_le_plus_long_message(self, window, journal_file):
        tab = window.current_tab()
        avant = tab.view.columnWidth(COL_MESSAGE)
        with open(journal_file, "a", encoding="utf-8") as handle:
            handle.write("2026-08-31 12:00:00.000 ERROR   APP (Main): " + "x" * 600 + "\n")
        window._poll_all()
        assert tab.view.columnWidth(COL_MESSAGE) > avant
        assert tab.store.max_message_length == 600

    def test_largeur_minimale_remplit_la_place(self, window):
        """Un journal de lignes courtes ne laisse pas de bande vide a droite."""
        tab = window.current_tab()
        assert tab.view.columnWidth(COL_MESSAGE) >= 200

    def test_largeur_tiree_a_la_main_respectee(self, window, journal_file):
        tab = window.current_tab()
        tab.view.setColumnWidth(COL_MESSAGE, 300)
        with open(journal_file, "a", encoding="utf-8") as handle:
            handle.write("2026-08-31 12:00:00.000 ERROR   APP (Main): " + "y" * 600 + "\n")
        window._poll_all()
        assert tab.view.columnWidth(COL_MESSAGE) == 300, "la largeur choisie ne doit pas etre ecrasee"

    def test_changer_de_police_reprend_la_main(self, window):
        tab = window.current_tab()
        tab.view.setColumnWidth(COL_MESSAGE, 300)
        window.zoom(6)
        assert tab.view.columnWidth(COL_MESSAGE) != 300


class TestPanneauDeDetail:
    def test_ligne_sans_trace(self, window):
        """Il ne s'ouvrait que pour les entrees portant une trace de pile."""
        tab = window.current_tab()
        tab.view.selectRow(1)
        assert not tab.detail.isHidden()
        assert "Loading version" in tab.detail.toPlainText()

    def test_la_trace_est_montree_entiere(self, window):
        tab = window.current_tab()
        tab.view.selectRow(4)
        assert "getUnitRecordById" in tab.detail.toPlainText()

    def test_rien_de_selectionne(self, window):
        tab = window.current_tab()
        tab.view.selectRow(0)
        tab.view.clearSelection()
        assert tab.detail.isHidden()

    def test_bascule(self, window):
        tab = window.current_tab()
        tab.view.selectRow(0)
        window.toggle_detail(False)
        assert tab.detail.isHidden()
        window.toggle_detail(True)
        assert not tab.detail.isHidden()

    def test_bascule_persistee(self, window, tmp_path, rules):
        window.toggle_detail(False)
        chemin = tmp_path / "session.json"
        window._capture().save(chemin)
        assert Session.load(chemin).detail_visible is False


class TestCopie:
    @staticmethod
    def clipboard() -> str:
        return QApplication.clipboard().text()

    def test_une_ligne(self, window):
        tab = window.current_tab()
        tab.view.selectRow(1)
        assert tab.copy_selection() == 1
        assert "Loading version 6.16.5" in self.clipboard()

    def test_plusieurs_lignes_dans_l_ordre(self, window):
        tab = window.current_tab()
        tab.view.selectRow(3)
        tab.view.selectionModel().select(
            tab.model.index(1, 0),
            QItemSelectionModel.SelectionFlag.Select | QItemSelectionModel.SelectionFlag.Rows,
        )
        assert tab.copy_selection() == 2
        lignes = self.clipboard().splitlines()
        assert "Loading version" in lignes[0], "l'ordre du journal, pas celui des clics"
        assert "[CTLD]" in lignes[1]

    def test_la_trace_suit_son_erreur(self, window):
        """Copier un `Mission script error` sans sa trace rendrait l'inexplicable."""
        tab = window.current_tab()
        tab.view.selectRow(4)
        tab.copy_selection()
        assert "getUnitRecordById" in self.clipboard()

    def test_sans_l_entete_dcs(self, window):
        tab = window.current_tab()
        tab.view.selectRow(1)
        tab.copy_selection(message_only=True)
        assert self.clipboard().startswith("VEAF|I|")

    def test_rien_de_selectionne(self, window):
        tab = window.current_tab()
        tab.view.clearSelection()
        assert tab.copy_selection() == 0

    def test_tout_selectionner(self, window):
        window.select_all()
        assert window.current_tab().copy_selection() == ENTRIES

    def test_ctrl_a_dans_le_champ_de_recherche(self, window):
        """Meme piege que Ctrl+C : le raccourci de fenetre passe avant le champ."""
        window.search.field.setText("VEAF")
        window.search.field.setFocus()
        window.select_all()
        assert window.search.field.selectedText() == "VEAF"
        assert not window.current_tab().view.selectionModel().hasSelection()

    def test_ctrl_c_dans_le_champ_de_recherche(self, window):
        window.search.field.setText("VEAF")
        window.search.field.setFocus()
        window.search.field.selectAll()
        QApplication.clipboard().clear()
        window.copy_selection()
        assert self.clipboard() == "VEAF"

    def test_le_detail_garde_son_ctrl_c(self, window):
        """Le raccourci est pose sur la fenetre : sans aiguillage il volerait
        la selection de caracteres faite dans le detail."""
        tab = window.current_tab()
        tab.view.selectRow(4)
        tab.detail.setFocus()
        curseur = tab.detail.textCursor()
        curseur.setPosition(0)
        curseur.setPosition(10, QTextCursor.MoveMode.KeepAnchor)
        tab.detail.setTextCursor(curseur)

        QApplication.clipboard().clear()
        window.copy_selection()
        copie = self.clipboard()
        assert copie == tab.detail.toPlainText()[:10]
        assert "getUnitRecordById" not in copie, "la ligne entiere n'a pas ete copiee"

    def test_la_table_copie_bien_la_ligne_entiere(self, window):
        """Le pendant du test precedent : sans le focus, c'est la ligne."""
        tab = window.current_tab()
        tab.view.selectRow(4)
        tab.view.setFocus()
        window.copy_selection()
        assert "getUnitRecordById" in self.clipboard()


class TestContexteDeRechercheDansLInterface:
    def test_reglage_commun_applique(self, window):
        window.side.search_context_lines.setValue(1)
        window.side.changed.emit()
        window.search.field.setText("zone introuvable")
        window.apply_filters()
        assert rows(window) == 3, "la ligne trouvee et ses deux voisines"

    def test_les_filtres_priment_sur_le_contexte(self, window):
        window.side.search_context_lines.setValue(1)
        window.side.levels.apply_states({"INFO": State.OFF})
        window.side.changed.emit()
        window.search.field.setText("zone introuvable")
        window.apply_filters()
        assert rows(window) == 1, "les voisines INFO restent masquees"

    def test_surcharge_du_champ_de_recherche(self, window):
        window.search.context.setValue(2)
        window.search.field.setText("zone introuvable")
        window.apply_filters()
        assert rows(window) == 5

    def test_la_surcharge_suit_la_pastille(self, window):
        window.search.context.setValue(2)
        window.search.field.setText("zone introuvable")
        window.add_current_filter()
        assert window.filters.text_filters[0].context_lines == 2
        assert rows(window) == 5

    def test_le_champ_vide_montre_la_valeur_commune(self, window):
        """A zero, Qt remplace tout l'affichage du champ par ce seul texte."""
        window.side.search_context_lines.setValue(3)
        window.side.changed.emit()
        assert window.search.context.text() == "(3)"
        window.search.context.setValue(5)
        assert window.search.context.text() == "±5"

    def test_persistance_dans_un_profil(self, window):
        window.side.search_context_lines.setValue(4)
        window.side.changed.emit()
        window.side.collect(window.filters)
        window.profiles.save_profile("Avec contexte", window.filters)
        window.reset_filters()
        window.load_profile("Avec contexte")
        assert window.filters.search_context_lines == 4
        assert window.side.search_context_lines.value() == 4


class TestSession:
    def test_capture_et_restauration(self, window, journal_file, tmp_path, rules):
        window.search.field.setText("VEAF")
        window.add_current_filter()
        window.side.levels.apply_states({"INFO": State.OFF})
        window.side.changed.emit()

        chemin = tmp_path / "session.json"
        window._capture().save(chemin)

        relue = Session.load(chemin)
        assert [item.path for item in relue.files] == [str(journal_file)]
        assert relue.get_filters().levels == {"INFO": State.OFF}

        rouverte = MainWindow(rules, relue)
        try:
            assert rouverte.tabs.count() == 1
            assert len(rouverte.filters.text_filters) == 1
            assert rouverte.current_tab().model.rowCount() == 1
        finally:
            rouverte.timer.stop()
            rouverte.close()
