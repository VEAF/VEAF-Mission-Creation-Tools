"""Tests de l'index : decoupage, classement, rattachement, suivi."""

from __future__ import annotations

import pytest
from veaf_logs.buffer import BytesBuffer, FileBuffer
from veaf_logs.store import LogStore
from veaf_logs_journal import ENTRIES, JOURNAL


class TestIndexation:
    def test_nombre_d_entrees(self, store):
        assert len(store) == ENTRIES

    def test_les_traces_rejoignent_leur_erreur(self, store):
        erreur = store.entry(4)
        assert erreur.level == "ERROR"
        assert erreur.continuations == ["stack traceback:", "\t[C]: in function 'getUnitRecordById'"]

    def test_la_recherche_porte_sur_la_trace(self, store):
        assert "getUnitRecordById" in store.entry(4).text

    def test_numerotation_sur_les_lignes_du_fichier(self, store):
        """La derniere entree est la 8e ligne, pas la 6e entree."""
        assert store.entry(ENTRIES - 1).lineno == len(JOURNAL)

    def test_horodatage(self, store):
        assert store.entry(0).timestamp == "2026-08-31 11:50:40.872"
        assert store.entry(0).time_only == "11:50:40.872"

    def test_message_sans_l_entete(self, store):
        assert store.entry(0).message.startswith("Error: Unit [F-14B]")

    def test_ligne_vide_de_fin_ignoree(self, rules):
        store = LogStore(rules, BytesBuffer(b"2026-08-31 11:00:00.000 INFO APP (Main): a\n"))
        assert store.index_new() == 1

    def test_ligne_incomplete_attendue(self, rules):
        """DCS ecrit en continu : une ligne sans fin de ligne n'est pas indexee."""
        store = LogStore(rules, BytesBuffer(b"2026-08-31 11:00:00.000 INFO APP (Main): tronq"))
        assert store.index_new() == 0

    def test_fins_de_ligne_windows(self, rules):
        data = b"2026-08-31 11:00:00.000 INFO    APP (Main): crlf\r\n"
        store = LogStore(rules, BytesBuffer(data))
        store.index_new()
        assert store.entry(0).message == "crlf", "le \\r ne doit pas rester"

    def test_octets_invalides(self, rules):
        data = b"2026-08-31 11:00:00.000 INFO    APP (Main): \xff\xfe casse\n"
        store = LogStore(rules, BytesBuffer(data))
        assert store.index_new() == 1
        assert "casse" in store.entry(0).message


class TestClassement:
    def test_niveaux(self, store):
        assert [store.level_of(i) for i in range(ENTRIES)] == [
            "ERROR",
            "INFO",
            "WARNING",
            "INFO",
            "ERROR",
            "WARNING",
        ]

    def test_avertissement_veaf_sous_un_info_dcs(self, store):
        """DCS journalise tout le Lua en INFO ; le vrai niveau est dans le prefixe."""
        assert store.level_of(2) == "WARNING"
        assert "zone introuvable" in store.entry(2).message

    def test_sources(self, store):
        assert store.source_of(1) == "veaf"
        assert store.source_of(3) == "ctld"
        assert store.source_of(0) == "dcs"

    def test_sous_systeme_en_libelle_de_source(self, store):
        assert store.entry(0).source_label == "APP"

    def test_bruit_reconnu(self, store):
        assert "damage_model" in store.noise_of(0)
        assert "taxiroad" in store.noise_of(5)

    def test_erreur_de_script_jamais_du_bruit(self, store):
        assert store.noise_of(4) == ()

    def test_module_veaf(self, rules):
        data = b"2026-08-31 11:00:00.000 INFO    SCRIPTING (Main): VEAF-GRASS|I|1: x\n"
        store = LogStore(rules, BytesBuffer(data))
        store.index_new()
        assert store.entry(0).module == "GRASS"


class TestComptages:
    def test_par_niveau(self, store):
        assert store.counts_by_level() == {"ERROR": 2, "INFO": 2, "WARNING": 2}

    def test_par_source(self, store):
        counts = store.counts_by_source()
        assert counts["veaf"] == 2
        assert counts["ctld"] == 1

    def test_par_famille_de_bruit(self, store):
        counts = store.counts_by_noise()
        assert counts["damage_model"] == 1
        assert counts["taxiroad"] == 1


class TestSuiviIncremental:
    def test_indexation_par_lots(self, rules, journal_file):
        store = LogStore(rules, FileBuffer(journal_file))
        assert store.index_new() == ENTRIES
        assert store.index_new() == 0, "rien de neuf"

        with open(journal_file, "ab") as handle:
            handle.write(b"2026-08-31 12:00:00.000 ERROR   APP (Main): nouvelle\n")
        assert store.index_new() == 1
        assert store.entry(len(store) - 1).message == "nouvelle"
        store.buffer.close()

    def test_trace_arrivee_apres_coup(self, rules, journal_file):
        """La derniere ligne est indexee tout de suite ; sa trace la rejoint."""
        store = LogStore(rules, FileBuffer(journal_file))
        store.index_new()
        with open(journal_file, "ab") as handle:
            handle.write(b"2026-08-31 12:00:00.000 ERROR   SCRIPTING (Main): boum\n")
        store.index_new()
        dernier = len(store) - 1
        assert store.entry(dernier).continuations == []

        with open(journal_file, "ab") as handle:
            handle.write(b"stack traceback:\n")
        assert store.index_new() == 0, "une suite ne cree pas d'entree"
        assert store.entry(dernier).continuations == ["stack traceback:"]
        store.buffer.close()

    def test_octets_indexes_bornent_la_recherche(self, rules, journal_file):
        store = LogStore(rules, FileBuffer(journal_file))
        store.index_new()
        assert store.indexed_bytes == journal_file.stat().st_size
        store.buffer.close()

    def test_remise_a_zero(self, store):
        store.clear()
        assert len(store) == 0
        assert store.indexed_bytes == 0
        assert store.index_new() == ENTRIES, "tout doit pouvoir etre relu"


class TestCorrespondanceOffsets:
    def test_chaque_position_appartient_a_une_entree(self, store):
        """La recherche ramene une position du fichier a son entree."""
        assert store.index_at_offset(0) == 0
        for index in range(len(store)):
            debut = store.offsets[index]
            assert store.index_at_offset(debut) == index

    def test_une_position_dans_la_trace_designe_l_erreur(self, store):
        data = b"\n".join(line.encode() for line in JOURNAL)
        position = data.index(b"getUnitRecordById")
        assert store.index_at_offset(position) == 4


class TestLimites:
    def test_trop_de_familles_de_bruit(self, rules):
        """Le masque binaire ne va pas au-dela de 64 familles."""
        from veaf_logs.rules import Rules
        from veaf_logs.store import MAX_NOISE_FAMILIES

        data = dict(rules.data)
        modele = data["noise"][0]
        data["noise"] = [dict(modele, id=f"f{i}") for i in range(MAX_NOISE_FAMILIES + 1)]
        with pytest.raises(ValueError, match="familles de bruit"):
            LogStore(Rules(data), BytesBuffer(b""))
