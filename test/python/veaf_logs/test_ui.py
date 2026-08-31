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

from PySide6.QtWidgets import QApplication  # noqa: E402
from veaf_logs.filters import State  # noqa: E402
from veaf_logs.profiles import DEFAULT_PROFILE, ProfileStore  # noqa: E402
from veaf_logs.rules import Rules  # noqa: E402
from veaf_logs.session import Session  # noqa: E402
from veaf_logs.ui.main_window import MainWindow  # noqa: E402
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
