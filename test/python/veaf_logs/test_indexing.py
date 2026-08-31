"""Tests de l'indexation progressive.

Un gros journal doit se lire par tranches, sans figer l'interface, et un petit
doit se charger d'un trait sans faire clignoter une barre de progression.
"""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

pytest.importorskip("PySide6")

from PySide6.QtWidgets import QApplication  # noqa: E402
from veaf_logs.buffer import FileBuffer  # noqa: E402
from veaf_logs.store import LogStore  # noqa: E402
from veaf_logs.ui.indexing import ProgressiveIndexer  # noqa: E402

LIGNE = "2026-08-31 11:50:00.000 INFO    APP (Main): remplissage numero {n}\n"


@pytest.fixture(scope="session")
def app():
    return QApplication.instance() or QApplication([])


@pytest.fixture
def gros_journal(tmp_path):
    """Un journal assez gros pour depasser la premiere tranche."""
    path = tmp_path / "gros.log"
    with open(path, "w", encoding="utf-8") as handle:
        for n in range(20_000):
            handle.write(LIGNE.format(n=n))
    return path


class TestParTranches:
    def test_petit_journal_indexe_d_un_trait(self, app, journal_file, rules):
        store = LogStore(rules, FileBuffer(journal_file))
        indexer = ProgressiveIndexer(store)
        poursuit = indexer.start()
        assert not poursuit, "un petit journal ne doit pas etaler son indexation"
        assert store.indexed_bytes == store.buffer.size()

    def test_gros_journal_etale(self, app, gros_journal, rules):
        store = LogStore(rules, FileBuffer(gros_journal))
        indexer = ProgressiveIndexer(store)
        # Premiere tranche volontairement minuscule, pour forcer l'etalement.
        assert indexer.start(upfront=4096), "l'indexation doit se poursuivre"
        assert indexer.running
        assert 0 < store.indexed_bytes < store.buffer.size()

    def test_les_premieres_lignes_sont_lisibles_aussitot(self, app, gros_journal, rules):
        store = LogStore(rules, FileBuffer(gros_journal))
        ProgressiveIndexer(store).start(upfront=64 << 10)
        assert len(store) > 0
        assert store.entry(0).message.startswith("remplissage")

    def test_va_jusqu_au_bout(self, app, gros_journal, rules):
        store = LogStore(rules, FileBuffer(gros_journal))
        indexer = ProgressiveIndexer(store)
        indexer.start(upfront=4096)
        while indexer.running:
            app.processEvents()
        assert store.indexed_bytes == store.buffer.size()
        assert len(store) == 20_000

    def test_signaux_emis(self, app, gros_journal, rules):
        store = LogStore(rules, FileBuffer(gros_journal))
        indexer = ProgressiveIndexer(store)
        lots, fini, avancement = [], [], []
        indexer.batch_ready.connect(lots.append)
        indexer.finished.connect(lambda: fini.append(True))
        indexer.progress.connect(lambda done, total: avancement.append((done, total)))

        indexer.start(upfront=4096)
        while indexer.running:
            app.processEvents()

        assert len(lots) > 1, "l'indexation doit avancer par lots"
        assert sum(lots) == 20_000
        assert fini == [True]
        assert avancement[-1][0] == avancement[-1][1], "la progression finit a 100 %"

    def test_interruption(self, app, gros_journal, rules):
        """Ce qui est deja indexe reste consultable apres une interruption."""
        store = LogStore(rules, FileBuffer(gros_journal))
        indexer = ProgressiveIndexer(store)
        indexer.start(upfront=4096)
        indexer.cancel()
        while indexer.running:
            app.processEvents()

        partiel = len(store)
        assert 0 < partiel < 20_000
        assert store.entry(partiel - 1) is not None

    def test_reprise_apres_interruption(self, app, gros_journal, rules):
        store = LogStore(rules, FileBuffer(gros_journal))
        indexer = ProgressiveIndexer(store)
        indexer.start(upfront=4096)
        indexer.cancel()
        while indexer.running:
            app.processEvents()

        indexer.start(upfront=4096)
        while indexer.running:
            app.processEvents()
        assert len(store) == 20_000, "l'indexation reprend ou elle s'etait arretee"

    def test_pas_de_double_demarrage(self, app, gros_journal, rules):
        store = LogStore(rules, FileBuffer(gros_journal))
        indexer = ProgressiveIndexer(store)
        indexer.start(upfront=4096)
        avant = store.indexed_bytes
        assert indexer.start() is True
        assert store.indexed_bytes == avant, "le second appel ne relance rien"


class TestBorneParTranche:
    def test_max_bytes_borne_le_travail(self, rules, gros_journal):
        store = LogStore(rules, FileBuffer(gros_journal))
        store.index_new(max_bytes=8192)
        assert 0 < store.indexed_bytes <= 8192

    def test_appels_successifs_avancent(self, rules, gros_journal):
        store = LogStore(rules, FileBuffer(gros_journal))
        premier = store.index_new(max_bytes=8192)
        second = store.index_new(max_bytes=8192)
        assert premier and second
        assert store.indexed_bytes <= 16384

    def test_sans_borne_tout_est_lu(self, rules, gros_journal):
        store = LogStore(rules, FileBuffer(gros_journal))
        store.index_new()
        assert store.indexed_bytes == store.buffer.size()


class TestComptagesIncrementaux:
    """Les compteurs sont tenus a jour a l'insertion, jamais recalcules."""

    def test_coherents_apres_indexation_partielle(self, rules, gros_journal):
        store = LogStore(rules, FileBuffer(gros_journal))
        store.index_new(max_bytes=8192)
        assert sum(store.counts_by_level().values()) == len(store)
        assert sum(store.counts_by_source().values()) == len(store)

    def test_coherents_apres_indexation_complete(self, store):
        assert sum(store.counts_by_level().values()) == len(store)
        assert store.counts_by_level() == {"ERROR": 2, "INFO": 2, "WARNING": 2}

    def test_remis_a_zero(self, store):
        store.clear()
        assert store.counts_by_level() == {}
        assert store.counts_by_noise() == {}

    def test_bruit_d_une_continuation_compte_une_fois(self, rules, tmp_path):
        """Deux suites porteuses du meme bruit ne comptent pas double."""
        path = tmp_path / "trace.log"
        path.write_text(
            "2026-08-31 11:50:00.000 INFO    DCS (Main): CPU info:\nhypervisor is active\nhypervisor is active\n",
            encoding="utf-8",
        )
        store = LogStore(rules, FileBuffer(path))
        store.index_new()
        assert len(store) == 1
        assert store.counts_by_noise().get("hypervisor") == 1
