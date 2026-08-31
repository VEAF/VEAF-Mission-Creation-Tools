"""Tests de l'ouverture, de la rotation et des archives."""

from __future__ import annotations

import zipfile

import pytest
from veaf_logs.buffer import FileBuffer
from veaf_logs.store import LogStore
from veaf_logs.tailer import LogSource, LogUnavailable, archive_members

LIGNE = "2026-08-31 11:5{n}:00.000 INFO    APP (Main): message {n}\n"


@pytest.fixture
def journal(tmp_path):
    path = tmp_path / "dcs.log"
    path.write_text(LIGNE.format(n=0), encoding="utf-8")
    return path


class TestOuverture:
    def test_fichier_ordinaire(self, journal):
        source = LogSource(journal)
        buffer = source.open()
        assert buffer.size() == journal.stat().st_size
        source.close()

    def test_fichier_absent(self, tmp_path):
        with pytest.raises(LogUnavailable):
            LogSource(tmp_path / "rien.log").open()

    def test_fichier_vide(self, tmp_path):
        """Le journal existe mais DCS n'a encore rien ecrit."""
        path = tmp_path / "vide.log"
        path.touch()
        source = LogSource(path)
        assert source.open().size() == 0
        source.close()

    def test_suivi_possible(self, journal):
        assert LogSource(journal).followable


class TestIdentiteDuFichier:
    """L'identite ne doit tenir qu'a l'inode et au peripherique.

    Elle a un temps inclus `st_ctime`, ce qui passait sous Windows — la date de
    creation n'y bouge pas — et faussait tout sous Linux, ou cette date est
    celle du dernier changement d'inode : chaque ecriture la modifie.
    """

    def test_ecrire_ne_change_pas_l_identite(self, journal):
        from veaf_logs.tailer import FileIdentity

        avant = FileIdentity.of(journal)
        with open(journal, "a", encoding="utf-8") as handle:
            handle.write(LIGNE.format(n=1))
        assert FileIdentity.of(journal) == avant

    def test_un_autre_fichier_a_une_autre_identite(self, journal, tmp_path):
        from veaf_logs.tailer import FileIdentity

        autre = tmp_path / "autre.log"
        autre.write_text(LIGNE.format(n=2), encoding="utf-8")
        assert FileIdentity.of(autre) != FileIdentity.of(journal)


class TestRotation:
    def test_pas_de_rotation_quand_le_fichier_grossit(self, journal):
        source = LogSource(journal)
        source.open()
        for n in range(1, 4):
            with open(journal, "a", encoding="utf-8") as handle:
                handle.write(LIGNE.format(n=n))
            assert not source.check_rotation(journal.stat().st_size)
        source.close()

    def test_reecriture_de_meme_longueur(self, journal):
        """Ni la taille ni l'identite ne changent : seule l'empreinte le dit."""
        source = LogSource(journal)
        source.open()
        taille = journal.stat().st_size
        remplacement = LIGNE.format(n=7)
        assert len(remplacement) == len(LIGNE.format(n=0))
        journal.write_text(remplacement, encoding="utf-8")
        assert source.check_rotation(taille)
        source.close()

    def test_fichier_tronque(self, journal):
        source = LogSource(journal)
        source.open()
        indexe = journal.stat().st_size
        journal.write_text("court\n", encoding="utf-8")
        assert source.check_rotation(indexe)
        source.close()

    def test_fichier_disparu(self, journal):
        source = LogSource(journal)
        source.open()
        journal.unlink()
        with pytest.raises(LogUnavailable):
            source.check_rotation(0)

    def test_reouverture_repart_du_nouveau_fichier(self, rules, journal):
        source = LogSource(journal)
        store = LogStore(rules, source.open())
        assert store.index_new() == 1

        journal.write_text(LIGNE.format(n=4) + LIGNE.format(n=5), encoding="utf-8")
        assert source.check_rotation(store.indexed_bytes)
        store.buffer = source.reopen()
        store.clear()
        assert store.index_new() == 2
        assert "message 4" in store.entry(0).message
        source.close()


class TestArchives:
    @pytest.fixture
    def archive(self, tmp_path):
        path = tmp_path / "dcs.log-20260613-184244.zip"
        with zipfile.ZipFile(path, "w") as zf:
            # Ordre volontairement defavorable : le journal en dernier.
            zf.writestr("dxdiag.txt", "rapport materiel")
            zf.writestr("dcs.20260613-184244.dmp", b"\x00binaire")
            zf.writestr("dcs.20260613-184244.log", LIGNE.format(n=0) + LIGNE.format(n=1))
        return path

    def test_le_journal_passe_avant_dxdiag(self, archive):
        assert archive_members(archive)[0].endswith(".log")

    def test_le_binaire_est_ecarte(self, archive):
        assert not any(name.endswith(".dmp") for name in archive_members(archive))

    def test_lecture(self, rules, archive):
        source = LogSource(archive)
        store = LogStore(rules, source.open())
        assert store.index_new() == 2

    def test_pas_de_suivi(self, archive):
        assert not LogSource(archive).followable

    def test_rotation_sans_objet(self, archive):
        source = LogSource(archive)
        source.open()
        assert not source.check_rotation(0)

    def test_nom_affiche(self, archive):
        source = LogSource(archive)
        source.open()
        assert "dcs.20260613-184244.log" in source.display_name

    def test_archive_sans_journal(self, tmp_path):
        path = tmp_path / "vide.zip"
        with zipfile.ZipFile(path, "w") as zf:
            zf.writestr("data.bin", b"\x00")
        with pytest.raises(LogUnavailable):
            LogSource(path).open()

    def test_membre_impose(self, archive):
        source = LogSource(archive, archive_member="dxdiag.txt")
        buffer = source.open()
        assert buffer.slice(0, buffer.size()) == b"rapport materiel"


class TestBufferFichier:
    def test_croissance_prise_en_compte(self, journal):
        buffer = FileBuffer(journal)
        premiere = buffer.size()
        with open(journal, "a", encoding="utf-8") as handle:
            handle.write(LIGNE.format(n=1))
        assert buffer.refresh() > premiere
        assert b"message 1" in buffer.slice(0, buffer.size())

    def test_lecture_partielle(self, journal):
        assert FileBuffer(journal).slice(0, 4) == b"2026"

    def test_le_journal_n_est_jamais_verrouille(self, journal, tmp_path):
        """DCS renomme son journal au lancement : rien ne doit l'en empecher.

        Sous Windows, un descripteur ouvert — projection memoire ou simple
        `open()` maintenu — suffit a faire echouer le renommage.
        """
        import os

        buffer = FileBuffer(journal)
        buffer.slice(0, 10)
        buffer.refresh()
        os.rename(journal, tmp_path / "dcs.log.old")  # ne doit pas lever

    def test_fichier_disparu_rend_des_octets_vides(self, journal):
        buffer = FileBuffer(journal)
        journal.unlink()
        assert buffer.slice(0, 10) == b""
        assert buffer.refresh() == 0
