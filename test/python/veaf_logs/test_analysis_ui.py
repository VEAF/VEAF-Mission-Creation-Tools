"""Tests d'interface d'« Expliquer » et de « Preparer un rapport ».

Ils tiennent au cablage, pas au gestionnaire : ce sont les branchements qui
tombent en silence — une action qui n'appelle rien, un bouton relie a un signal
que personne n'ecoute, une analyse calculee sur autre chose que ce qui est
affiche. Le rendu hors ecran suffit pour tout ca.
"""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

pytest.importorskip("PySide6")

from PySide6.QtWidgets import QApplication  # noqa: E402
from veaf_logs.analysis import Analysis, analyse  # noqa: E402
from veaf_logs.filters import FilterSet, State  # noqa: E402
from veaf_logs.profiles import DEFAULT_PROFILE, ProfileStore  # noqa: E402
from veaf_logs.report import BLOCK_START, FENCE_OPEN, parse_report_block  # noqa: E402
from veaf_logs.session import Session  # noqa: E402
from veaf_logs.ui.analysis_view import AnalysisDialog  # noqa: E402
from veaf_logs.ui.main_window import MainWindow  # noqa: E402
from veaf_logs_journal import ENTRIES  # noqa: E402


@pytest.fixture(scope="session")
def app():
    return QApplication.instance() or QApplication([])


@pytest.fixture
def window(app, journal_file, tmp_path, rules):
    window = MainWindow(rules, Session())
    window.profiles = ProfileStore(rules, tmp_path / "profiles.json")
    window._reload_profile_box(DEFAULT_PROFILE)
    window.open_path(journal_file)
    yield window
    window.timer.stop()
    window.close()


@pytest.fixture
def dialogue(app, store, rules):
    analysis = analyse(store, rules, FilterSet())
    dialog = AnalysisDialog(analysis)
    yield dialog
    dialog.close()


class TestCablage:
    """L'action existe, elle est atteignable, et elle porte sur ce qui est affiche."""

    def test_l_action_expliquer_est_dans_le_menu_et_branchee(self, window, monkeypatch):
        """Presente *et* reliee : une action qui n'appelle rien s'affiche pareil."""
        declenchees: list[Analysis] = []
        monkeypatch.setattr(AnalysisDialog, "exec", lambda self: declenchees.append(self.analysis))
        action = next(item for item in window.actions() if "Expliquer" in item.text())
        action.trigger()
        assert len(declenchees) == 1

    def test_le_modele_expose_ce_qu_il_affiche(self, window):
        assert window.current_tab().model.visible_indices() == list(range(ENTRIES))

    def test_les_indices_exposes_suivent_les_filtres(self, window):
        window.filters.levels["INFO"] = State.OFF
        window.apply_filters()
        indices = window.current_tab().model.visible_indices()
        assert len(indices) < ENTRIES
        assert indices == sorted(indices)

    def test_expliquer_analyse_la_vue_et_pas_le_journal(self, window, journal_file, monkeypatch):
        """La bevue a eviter : reevaluer les filtres au lieu de lire ce qui est affiche.

        Les deux donnent le meme resultat tant que la vue est a jour, donc un
        test pris sur une vue a jour ne distingue rien. On les fait diverger
        comme la realite les fait diverger : des lignes arrivent dans le journal
        et sont indexees avant que le tableau ne soit rafraichi. L'analyse doit
        porter sur ce que l'utilisateur regarde, pas sur ce qui est arrive
        depuis.
        """
        tab = window.current_tab()
        affiche = len(tab.model.visible_indices())
        with open(journal_file, "a", encoding="utf-8") as handle:
            handle.write("2026-08-31 12:30:00.000 ERROR   APP (Main): arrivee apres coup\n")
        tab.store.index_new()
        assert len(tab.store) > affiche

        vues: list[Analysis] = []
        monkeypatch.setattr(AnalysisDialog, "exec", lambda self: vues.append(self.analysis))
        window.explain_current_view()
        assert len(vues) == 1
        assert vues[0].excerpt.selected == affiche

    def test_expliquer_respecte_les_categories_masquees(self, window, monkeypatch):
        window.filters.levels["INFO"] = State.OFF
        window.apply_filters()
        attendu = len(window.current_tab().model.visible_indices())
        assert attendu < ENTRIES

        vues: list[Analysis] = []
        monkeypatch.setattr(AnalysisDialog, "exec", lambda self: vues.append(self.analysis))
        window.explain_current_view()
        assert vues[0].excerpt.selected == attendu
        assert all(entry.level != "INFO" for entry in vues[0].excerpt.entries)

    def test_sans_journal_ouvert_l_action_ne_tombe_pas(self, app, rules, tmp_path):
        window = MainWindow(rules, Session())
        window.profiles = ProfileStore(rules, tmp_path / "profiles.json")
        try:
            window.explain_current_view()
        finally:
            window.timer.stop()
            window.close()


class TestFenetreDAnalyse:
    """Le catalogue est affiche d'emblee ; rien ne part sans qu'on le demande."""

    def test_le_catalogue_est_affiche_sans_reseau(self, dialogue):
        texte = dialogue.text.toPlainText()
        assert "CATALOGUE" in texte
        assert texte == dialogue.analysis.to_text()

    def test_le_commentaire_recu_remplace_la_section_du_modele(self, dialogue):
        dialogue.show_commentary("  la cause est en tete  ")
        assert dialogue.analysis.commentary == "la cause est en tete"
        assert "la cause est en tete" in dialogue.text.toPlainText()
        assert dialogue.online_button.isEnabled()

    def test_un_echec_est_dit_dans_la_barre_d_etat_sans_boite_de_dialogue(self, dialogue):
        """Une boite modale suggererait que la reponse du catalogue est perdue."""
        dialogue.show_failure("service injoignable")
        assert dialogue.status.text() == "service injoignable"
        assert dialogue.analysis.model_error == "service injoignable"
        assert "service injoignable" in dialogue.text.toPlainText()
        assert dialogue.online_button.isEnabled()

    def test_l_analyse_reste_immuable(self, dialogue):
        """Le bloc de rapport se construit dessus : elle est remplacee, pas modifiee."""
        avant = dialogue.analysis
        dialogue.show_commentary("autre chose")
        assert dialogue.analysis is not avant
        assert avant.commentary == ""

    def test_une_seconde_demande_pendant_la_premiere_est_ignoree(self, dialogue):
        class FauxFil:
            def isRunning(self):
                return True

            def wait(self, _ms):
                return True

        occupe = FauxFil()
        dialogue._thread = occupe
        dialogue.run_online()
        assert dialogue._thread is occupe

    def test_la_fermeture_attend_une_requete_en_cours(self, dialogue):
        """Sans ca, la fenetre part en laissant un fil de discussion derriere elle."""
        attentes: list[int] = []

        class FauxFil:
            def isRunning(self):
                return True

            def wait(self, ms):
                attentes.append(ms)
                return True

        dialogue._thread = FauxFil()
        dialogue.close()
        assert attentes == [1000]

    def test_la_couche_en_ligne_recoit_l_extrait_et_les_motifs(self, dialogue, monkeypatch):
        """Ce qui part : l'extrait deja caviarde, et les motifs deja apparies ici."""
        envois: list[tuple] = []

        class FauxFil:
            def __init__(self, excerpt, matches, question, parent=None):
                envois.append((excerpt, matches, question))

            def isRunning(self):
                return False

            @property
            def answered(self):
                return _Signal()

            @property
            def failed(self):
                return _Signal()

            def start(self):
                pass

        monkeypatch.setattr("veaf_logs.ui.analysis_view.OnlineAnalysisThread", FauxFil)
        dialogue.question.setText("pourquoi ?")
        dialogue.run_online()
        excerpt, matches, question = envois[0]
        assert excerpt == dialogue.analysis.excerpt.to_text()
        assert question == "pourquoi ?"
        assert all(set(item) == {"id", "label", "help", "count"} for item in matches)


class _Signal:
    def connect(self, _slot):
        return None


class TestRapport:
    """« Preparer un rapport » remplit le presse-papier ; rien n'est envoye."""

    def test_le_bouton_remplit_le_presse_papier(self, dialogue, app):
        """Par le bouton, pas par la methode : c'est le branchement qui casse en silence."""
        QApplication.clipboard().setText("")
        dialogue.report_button.click()
        assert BLOCK_START in QApplication.clipboard().text()

    def test_le_bloc_arrive_dans_le_presse_papier(self, dialogue, app):
        dialogue.copy_report()
        colle = QApplication.clipboard().text()
        assert colle.startswith(FENCE_OPEN)
        assert BLOCK_START in colle
        assert parse_report_block(colle).fields["schema"]

    def test_l_etat_dit_ce_qui_a_ete_copie(self, dialogue, app):
        dialogue.copy_report()
        assert "Rapport copié" in dialogue.status.text()

    def test_un_diagnostic_incollectable_ne_perd_pas_le_rapport(self, dialogue, app, monkeypatch):
        """Le doctor lit des fichiers : son echec coute sa section, pas le rapport."""
        monkeypatch.setattr("veaf_logs.ui.analysis_view._doctor_report", lambda: None)
        dialogue.copy_report()
        relu = parse_report_block(QApplication.clipboard().text())
        assert relu.doctor is None
        assert relu.fields["schema"]
