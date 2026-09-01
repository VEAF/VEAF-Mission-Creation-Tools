"""Tests des modes de recherche, du cumul, et du tri-etat avec contexte."""

from __future__ import annotations

import pytest
from veaf_logs.buffer import BytesBuffer
from veaf_logs.filters import (
    FilterSet,
    Mode,
    PatternError,
    State,
    TextFilter,
    compile_pattern,
    evaluate,
    glob_to_regex,
    highlight_patterns,
)
from veaf_logs.store import LogStore


def visible(store, filters) -> list[int]:
    return evaluate(store, filters)


class TestJokers:
    def test_etoile(self):
        assert glob_to_regex("VEAF*error") == "VEAF.*error"

    def test_point_interrogation(self):
        assert glob_to_regex("v?") == "v."

    def test_point_est_litteral(self):
        """C'est la difference avec la regex : `.` ne doit pas etre un joker."""
        regex = compile_pattern("CSAR.lua", Mode.GLOB)
        assert regex.search("CSAR.lua")
        assert not regex.search("CSARxlua")

    def test_crochets_echappes(self):
        assert compile_pattern("[CTLD]", Mode.GLOB).search("[CTLD][INFO] x")

    def test_barre_verticale_litterale(self):
        regex = compile_pattern("VEAF|W|", Mode.GLOB)
        assert regex.search("VEAF|W|log|123: x")
        assert not regex.search("VEAF|I|5390: x")


class TestModes:
    def test_texte_simple_est_litteral(self):
        regex = compile_pattern("a.b", Mode.PLAIN)
        assert regex.search("xa.by")
        assert not regex.search("axb")

    def test_regex_complete(self):
        regex = compile_pattern(r"VEAF\|[WE]\|", Mode.REGEX)
        assert regex.search("VEAF|W|log|1: x")
        assert not regex.search("VEAF|I|1: x")

    def test_regex_invalide(self):
        with pytest.raises(PatternError):
            compile_pattern("[non fermee", Mode.REGEX)

    def test_casse_ignoree_par_defaut(self):
        assert compile_pattern("veaf", Mode.PLAIN).search("VEAF|I|")

    def test_casse_respectee(self):
        assert not compile_pattern("veaf", Mode.PLAIN, case_sensitive=True).search("VEAF|I|")

    def test_motif_vide(self):
        assert compile_pattern("", Mode.REGEX) is None

    def test_mode_recu_en_chaine(self):
        """Qt rend `currentData()` sous forme de chaine pour une enum de str."""
        assert TextFilter(pattern="a.b", mode="plain").mode is Mode.PLAIN
        assert not compile_pattern("a.b", "plain").search("axb")

    def test_mode_inconnu_rejete(self):
        with pytest.raises(ValueError):
            TextFilter(pattern="x", mode="inconnu")


class TestRechercheTextuelle:
    def test_sans_critere_tout_passe(self, store):
        assert len(visible(store, FilterSet())) == len(store)

    def test_texte_simple(self, store):
        fs = FilterSet(text_filters=[TextFilter(pattern="zone introuvable")])
        assert visible(store, fs) == [2]

    def test_recherche_dans_une_trace_rattachee(self, store):
        """Un symbole present seulement dans la trace doit ramener l'erreur."""
        fs = FilterSet(text_filters=[TextFilter(pattern="getUnitRecordById")])
        assert visible(store, fs) == [4]

    def test_regex(self, store):
        fs = FilterSet(text_filters=[TextFilter(pattern=r"VEAF\|[WE]\|", mode=Mode.REGEX)])
        assert visible(store, fs) == [2]

    def test_jokers(self, store):
        fs = FilterSet(text_filters=[TextFilter(pattern="No taxiroad*Batumi*", mode=Mode.GLOB)])
        assert visible(store, fs) == [5]

    def test_filtre_inverse(self, store):
        fs = FilterSet(text_filters=[TextFilter(pattern="VEAF", invert=True)])
        assert 1 not in visible(store, fs)
        assert 2 not in visible(store, fs)

    def test_cumul_en_et(self, store):
        fs = FilterSet(text_filters=[TextFilter(pattern="VEAF"), TextFilter(pattern="zone")])
        assert visible(store, fs) == [2]

    def test_filtre_desactive_ignore(self, store):
        fs = FilterSet(text_filters=[TextFilter(pattern="zone", enabled=False)])
        assert len(visible(store, fs)) == len(store)

    def test_motifs_surlignes_excluent_les_inverses(self):
        fs = FilterSet(text_filters=[TextFilter(pattern="VEAF"), TextFilter(pattern="x", invert=True)])
        assert len(highlight_patterns(fs)) == 1


class TestEtatsDesCategories:
    def test_niveau_masque(self, store):
        fs = FilterSet(levels={"INFO": State.OFF})
        assert visible(store, fs) == [0, 2, 4, 5]

    def test_source_masquee(self, store):
        fs = FilterSet(sources={"veaf": State.OFF})
        assert 1 not in visible(store, fs)

    def test_bruit_masque(self, store):
        fs = FilterSet(noise={"damage_model": State.OFF, "taxiroad": State.OFF})
        assert visible(store, fs) == [1, 2, 3, 4]

    def test_off_prime_sur_context(self, store):
        """Une entree exclue par un critere le reste, meme en contexte ailleurs."""
        fs = FilterSet(levels={"INFO": State.CONTEXT}, sources={"veaf": State.OFF})
        assert 1 not in visible(store, fs)

    def test_categorie_inconnue_affichee(self, store):
        """Un niveau qui apparait en cours de suivi ne doit pas etre masque."""
        fs = FilterSet(levels={"NOUVEAU": State.OFF})
        assert len(visible(store, fs)) == len(store)


class TestContexte:
    def test_contexte_autour_des_erreurs(self, store):
        """INFO en contexte : on ne les voit qu'autour d'une ligne retenue."""
        fs = FilterSet(
            levels={"INFO": State.CONTEXT, "WARNING": State.OFF},
            context_lines=1,
        )
        # Retenues : 0 et 4 (ERROR). Voisines a +/-1 et de niveau INFO : 1 et 3.
        assert visible(store, fs) == [0, 1, 3, 4]

    def test_contexte_zero_desactive_le_voisinage(self, store):
        fs = FilterSet(
            levels={"INFO": State.CONTEXT, "WARNING": State.OFF},
            context_lines=0,
        )
        assert visible(store, fs) == [0, 4]

    def test_contexte_large(self, store):
        fs = FilterSet(levels={"INFO": State.CONTEXT, "WARNING": State.OFF}, context_lines=10)
        assert visible(store, fs) == [0, 1, 3, 4]

    def test_le_contexte_ne_subit_pas_le_filtre_textuel(self, store):
        """Une ligne de contexte n'a pas a contenir le texte cherche.

        Sinon elle n'apporterait rien : c'est justement ce qui entoure la
        correspondance qu'on veut lire.
        """
        fs = FilterSet(
            levels={"INFO": State.CONTEXT, "WARNING": State.OFF},
            text_filters=[TextFilter(pattern="Mission script error")],
            context_lines=1,
        )
        assert visible(store, fs) == [3, 4]

    def test_sans_categorie_en_contexte_rien_ne_change(self, store):
        fs = FilterSet(levels={"INFO": State.OFF}, context_lines=5)
        assert visible(store, fs) == [0, 2, 4, 5]

    def test_bornes_du_journal(self, store):
        """Le voisinage ne deborde pas du debut ni de la fin."""
        fs = FilterSet(
            levels={"ERROR": State.OFF, "WARNING": State.OFF, "INFO": State.CONTEXT},
            context_lines=50,
        )
        assert visible(store, fs) == [], "sans ligne retenue, aucun contexte"

    def test_uses_context(self):
        assert not FilterSet().uses_context
        assert FilterSet(levels={"INFO": State.CONTEXT}).uses_context
        assert not FilterSet(levels={"INFO": State.OFF}).uses_context


class TestContexteDeRecherche:
    """Lignes gardees autour d'un resultat de recherche, comme le -C de grep.

    Le journal de reference : 0 ERROR, 1 INFO VEAF, 2 WARNING VEAF, 3 INFO CTLD,
    4 ERROR de script, 5 WARNING ED.
    """

    def test_desactive_par_defaut(self, store):
        fs = FilterSet(text_filters=[TextFilter(pattern="zone introuvable")])
        assert visible(store, fs) == [2], "sans reglage, la recherche ne ramene que ses lignes"

    def test_voisinage_commun(self, store):
        fs = FilterSet(
            text_filters=[TextFilter(pattern="zone introuvable")],
            search_context_lines=1,
        )
        assert visible(store, fs) == [1, 2, 3]

    def test_portee_plus_large(self, store):
        fs = FilterSet(text_filters=[TextFilter(pattern="zone introuvable")], search_context_lines=2)
        assert visible(store, fs) == [0, 1, 2, 3, 4]

    def test_bornes_du_journal(self, store):
        fs = FilterSet(text_filters=[TextFilter(pattern="Corrupt damage model")], search_context_lines=50)
        assert visible(store, fs) == [0, 1, 2, 3, 4, 5], "le voisinage ne deborde pas"

    def test_les_categories_masquees_le_restent(self, store):
        """Le contexte elargit la recherche, il ne defait pas un filtre.

        C'est le point ou une implementation naive se trompe : les lignes
        voisines 1 et 3 sont INFO, donc masquees, et le contexte n'a pas a les
        faire reapparaitre.
        """
        fs = FilterSet(
            levels={"INFO": State.OFF},
            text_filters=[TextFilter(pattern="zone introuvable")],
            search_context_lines=1,
        )
        assert visible(store, fs) == [2]

    def test_une_seule_voisine_autorisee(self, store):
        """Masquer la source CTLD retire la voisine de droite, pas celle de gauche."""
        fs = FilterSet(
            sources={"ctld": State.OFF},
            text_filters=[TextFilter(pattern="zone introuvable")],
            search_context_lines=1,
        )
        assert visible(store, fs) == [1, 2]

    def test_surcharge_par_critere(self, store):
        fs = FilterSet(text_filters=[TextFilter(pattern="zone introuvable", context_lines=2)])
        assert visible(store, fs) == [0, 1, 2, 3, 4], "la surcharge s'applique sans valeur commune"

    def test_surcharge_prime_sur_le_commun(self, store):
        fs = FilterSet(
            text_filters=[TextFilter(pattern="zone introuvable", context_lines=0)],
            search_context_lines=2,
        )
        assert visible(store, fs) == [2], "0 explicite n'est pas « suit le commun »"

    def test_la_plus_large_gagne(self, store):
        """Deux criteres cumules : la portee la plus large s'applique au resultat."""
        fs = FilterSet(
            text_filters=[
                TextFilter(pattern="VEAF"),
                TextFilter(pattern="zone", context_lines=2),
            ],
            search_context_lines=0,
        )
        assert visible(store, fs) == [0, 1, 2, 3, 4]

    def test_critere_inverse_n_apporte_pas_de_contexte(self, store):
        """Un critere `sans X` n'a pas de resultat a entourer."""
        fs = FilterSet(
            text_filters=[TextFilter(pattern="VEAF", invert=True, context_lines=3)],
            search_context_lines=0,
        )
        assert visible(store, fs) == [0, 3, 4, 5]

    def test_critere_desactive_ignore(self, store):
        fs = FilterSet(
            text_filters=[TextFilter(pattern="zone introuvable", enabled=False)],
            search_context_lines=2,
        )
        assert len(visible(store, fs)) == len(store)

    def test_sans_critere_textuel_rien_ne_change(self, store):
        fs = FilterSet(levels={"INFO": State.OFF}, search_context_lines=5)
        assert visible(store, fs) == [0, 2, 4, 5]

    def test_se_combine_avec_le_contexte_des_categories(self, store):
        """Les deux contextes se composent au lieu de se remplacer.

        La recherche trouve l'erreur 4 ; sa voisine 3 est INFO, donc en contexte
        avec sa propre portee, et ressort par ce chemin-la.
        """
        fs = FilterSet(
            levels={"INFO": State.CONTEXT, "WARNING": State.OFF},
            text_filters=[TextFilter(pattern="Mission script error")],
            context_lines=1,
            search_context_lines=0,
        )
        assert visible(store, fs) == [3, 4]

    def test_span_de_recherche(self):
        assert FilterSet().search_span() == 0
        fs = FilterSet(text_filters=[TextFilter(pattern="a")], search_context_lines=3)
        assert fs.search_span() == 3
        fs.text_filters[0].context_lines = 7
        assert fs.search_span() == 7

    def test_persistance(self):
        fs = FilterSet(
            text_filters=[TextFilter(pattern="a", context_lines=4)],
            search_context_lines=2,
        )
        relu = FilterSet.from_dict(fs.to_dict())
        assert relu.search_context_lines == 2
        assert relu.text_filters[0].context_lines == 4

    def test_valeurs_invalides_ignorees(self):
        fs = FilterSet.from_dict(
            {
                "search_context_lines": "beaucoup",
                "text_filters": [{"pattern": "a", "context_lines": "trois"}],
            }
        )
        assert fs.search_context_lines == 0
        assert fs.text_filters[0].context_lines is None

    def test_pastille_montre_la_surcharge(self):
        assert TextFilter(pattern="a").describe() == "Texte : a"
        assert TextFilter(pattern="a", context_lines=3).describe() == "Texte : a  ±3"


class TestPersistance:
    def test_aller_retour(self):
        fs = FilterSet(
            levels={"INFO": State.CONTEXT},
            sources={"veaf": State.OFF},
            noise={"taxiroad": State.OFF},
            text_filters=[TextFilter(pattern="x", mode=Mode.REGEX, invert=True)],
            context_lines=7,
        )
        relu = FilterSet.from_dict(fs.to_dict())
        assert relu.levels == {"INFO": State.CONTEXT}
        assert relu.sources == {"veaf": State.OFF}
        assert relu.context_lines == 7
        assert relu.text_filters[0].invert and relu.text_filters[0].mode is Mode.REGEX

    def test_etat_on_non_stocke(self):
        """Seules les categories qui derogent sont retenues."""
        fs = FilterSet.from_dict({"levels": {"INFO": "on", "DEBUG": "off"}})
        assert fs.levels == {"DEBUG": State.OFF}

    def test_valeurs_invalides_ignorees(self):
        fs = FilterSet.from_dict(
            {"levels": {"INFO": "n_importe_quoi"}, "text_filters": [{"pattern": "a", "mode": "?"}]}
        )
        assert fs.levels == {}
        assert fs.text_filters == []

    def test_copie_independante(self):
        fs = FilterSet(levels={"INFO": State.OFF}, text_filters=[TextFilter(pattern="a")])
        copie = fs.copy()
        copie.levels["INFO"] = State.CONTEXT
        copie.text_filters.append(TextFilter(pattern="b"))
        assert fs.levels == {"INFO": State.OFF}
        assert len(fs.text_filters) == 1

    def test_set_state(self):
        fs = FilterSet()
        fs.set_state("levels", "INFO", State.OFF)
        assert fs.levels == {"INFO": State.OFF}
        fs.set_state("levels", "INFO", State.ON)
        assert fs.levels == {}, "revenir a ON retire l'entree"


class TestJournalVide:
    def test_aucune_entree(self, rules):
        store = LogStore(rules, BytesBuffer(b""))
        store.index_new()
        assert evaluate(store, FilterSet(levels={"INFO": State.OFF})) == []


class TestPorteeParCategorie:
    """Chaque categorie en contexte peut avoir sa propre portee."""

    def test_defaut_commun(self):
        fs = FilterSet(context_lines=4)
        assert fs.span_for("levels", "INFO") == 4

    def test_surcharge(self):
        fs = FilterSet(context_lines=4)
        fs.set_span("levels", "INFO", 10)
        assert fs.span_for("levels", "INFO") == 10
        assert fs.span_for("levels", "DEBUG") == 4, "les autres suivent le defaut"

    def test_surcharge_egale_au_defaut_non_stockee(self):
        fs = FilterSet(context_lines=4)
        fs.set_span("levels", "INFO", 4)
        assert fs.context_spans == {}

    def test_retour_au_defaut(self):
        fs = FilterSet(context_lines=4)
        fs.set_span("levels", "INFO", 10)
        fs.set_span("levels", "INFO", None)
        assert fs.span_for("levels", "INFO") == 4

    def test_familles_independantes(self):
        fs = FilterSet(context_lines=1)
        fs.set_span("levels", "INFO", 5)
        assert fs.span_for("sources", "INFO") == 1, "meme cle, famille differente"

    def test_portee_appliquee(self, store):
        """INFO a large portee, WARNING masque : seules les INFO proches sortent."""
        fs = FilterSet(levels={"INFO": State.CONTEXT, "WARNING": State.OFF}, context_lines=0)
        assert visible(store, fs) == [0, 4]
        fs.set_span("levels", "INFO", 1)
        assert visible(store, fs) == [0, 1, 3, 4]

    def test_la_plus_large_gagne(self, store):
        """Une entree en contexte par deux criteres prend la plus grande portee."""
        fs = FilterSet(
            levels={"INFO": State.CONTEXT, "WARNING": State.OFF},
            sources={"veaf": State.CONTEXT},
            context_lines=0,
        )
        fs.set_span("sources", "veaf", 1)
        # L'entree 1 est INFO (portee 0) et VEAF (portee 1) : elle sort.
        assert 1 in visible(store, fs)

    def test_persistance(self):
        fs = FilterSet(levels={"INFO": State.CONTEXT}, context_lines=2)
        fs.set_span("levels", "INFO", 8)
        relu = FilterSet.from_dict(fs.to_dict())
        assert relu.span_for("levels", "INFO") == 8

    def test_valeurs_invalides_ignorees(self):
        fs = FilterSet.from_dict({"context_spans": {"levels:INFO": "beaucoup", "levels:X": True}})
        assert fs.context_spans == {}

    def test_copie_independante(self):
        fs = FilterSet()
        fs.set_span("levels", "INFO", 9)
        copie = fs.copy()
        copie.set_span("levels", "INFO", 1)
        assert fs.span_for("levels", "INFO") == 9
