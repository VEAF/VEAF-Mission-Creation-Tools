"""Tests de l'extrait borne, caviarde et honnete sur ce qu'il cache.

Les lignes des fixtures sont des lignes DCS reelles, retouchees pour porter les
donnees que le caviardage doit trouver : un chemin utilisateur Windows, une
adresse IPv4, un jeton.
"""

from __future__ import annotations

import pytest
from veaf_logs.buffer import BytesBuffer
from veaf_logs.excerpt import (
    DEFAULT_MAX_CHARS,
    MAX_CONTINUATION_LINES,
    NOTHING_AFFORDED,
    NOTHING_SELECTED,
    Excerpt,
    build_excerpt,
    context_keys,
    excluded_keys,
    is_excluded,
)
from veaf_logs.filters import FilterSet, State, TextFilter
from veaf_logs.store import LogStore

# Un compte qui n'est pas celui de la machine de test : le caviardage doit
# l'attraper par la regle des repertoires personnels, pas parce qu'il se trouve
# etre le nom de l'utilisateur courant. Sans ca, le test passerait sur le poste
# de son auteur et nulle part ailleurs.
CHEMIN = r"C:\Users\Alphonse Dupont\Saved Games\DCS\Logs\dcs.log"
ADRESSE = "192.168.1.42"
JETON = "ghp_ABCdef0123456789ABCdef0123456789"

SENSIBLE = [
    f"2026-08-31 11:50:40.872 ERROR   APP (Main): cannot open {CHEMIN}",
    f"2026-08-31 11:50:41.000 WARNING NET (Main): peer {ADRESSE} timed out",
    f"2026-08-31 11:50:42.000 ERROR   APP (Main): token={JETON} rejected",
]

# Un resultat de recherche encadre de deux lignes INFO. Avec INFO masque, le
# contexte de recherche ne doit ramener ni l'une ni l'autre.
VOISINAGE = [
    "2026-08-31 12:00:00.000 INFO    APP (Main): avant, sans interet",
    "2026-08-31 12:00:01.000 ERROR   APP (Main): la panne cherchee",
    "2026-08-31 12:00:02.000 INFO    APP (Main): apres, sans interet",
]


def indexer(rules, lignes) -> LogStore:
    store = LogStore(rules, BytesBuffer(("\n".join(lignes) + "\n").encode("utf-8")))
    store.index_new()
    return store


@pytest.fixture
def sensible(rules) -> LogStore:
    return indexer(rules, SENSIBLE)


@pytest.fixture
def voisinage(rules) -> LogStore:
    return indexer(rules, VOISINAGE)


class TestCaviardage:
    """Le caviardage vient de `veaf_libs.redaction` : on verifie qu'il est applique."""

    def test_chemin_utilisateur_windows(self, sensible):
        rendu = build_excerpt(sensible, FilterSet()).to_text()
        assert "Alphonse Dupont" not in rendu
        assert r"C:\Users\<user>" in rendu

    def test_adresse_ipv4(self, sensible):
        rendu = build_excerpt(sensible, FilterSet()).to_text()
        assert ADRESSE not in rendu
        assert "<ip>" in rendu

    def test_jeton(self, sensible):
        rendu = build_excerpt(sensible, FilterSet()).to_text()
        assert JETON not in rendu
        assert "<redacted>" in rendu

    def test_les_suites_aussi(self, rules):
        """Une trace de pile est du texte comme un autre : elle porte des chemins."""
        store = indexer(
            rules,
            [
                "2026-08-31 11:55:01.930 ERROR   SCRIPTING (Main): Mission script error",
                f"\tat {CHEMIN}",
            ],
        )
        excerpt = build_excerpt(store, FilterSet())
        assert "Alphonse Dupont" not in excerpt.to_text()
        assert excerpt.entries[0].continuations


class TestCategoriesExclues:
    """Le lecteur doit savoir ce qui manque : un journal filtre n'est pas un journal propre."""

    def test_en_tete_declare_les_categories_masquees(self, sensible):
        filters = FilterSet(levels={"WARNING": State.OFF}, sources={"ctld": State.OFF})
        entete = "\n".join(build_excerpt(sensible, filters).header_lines())
        assert "WARNING" in entete
        assert "ctld" in entete

    def test_en_tete_declare_les_categories_de_contexte(self, sensible):
        filters = FilterSet(levels={"INFO": State.CONTEXT})
        entete = "\n".join(build_excerpt(sensible, filters).header_lines())
        assert "contexte" in entete
        assert "INFO" in entete

    def test_masquer_une_gravite_declenche_un_avertissement(self, sensible):
        """Le piege du ticket : « aucune erreur » parce qu'on a decoche ERROR."""
        excerpt = build_excerpt(sensible, FilterSet(levels={"ERROR": State.OFF}))
        assert excerpt.hidden_severity == ["ERROR"]
        assert "ne prouve rien" in "\n".join(excerpt.header_lines())

    def test_masquer_une_categorie_anodine_n_avertit_pas(self, sensible):
        """Le contre-cas : sans lui, l'avertissement serait toujours la, donc muet."""
        excerpt = build_excerpt(sensible, FilterSet(levels={"INFO": State.OFF}))
        assert excerpt.hidden_severity == []
        assert "ne prouve rien" not in "\n".join(excerpt.header_lines())

    def test_les_criteres_de_recherche_sont_declares(self, sensible):
        filters = FilterSet(text_filters=[TextFilter(pattern="timed out")])
        assert "timed out" in "\n".join(build_excerpt(sensible, filters).header_lines())

    @pytest.mark.parametrize("famille", ["levels", "sources", "noise"])
    def test_les_trois_familles_sont_relevees(self, famille):
        """Enumere depuis le code : les trois familles d'un FilterSet, pas un echantillon."""
        filters = FilterSet()
        filters.set_state(famille, "cle", State.OFF)
        assert excluded_keys(filters) == {famille: ["cle"]}
        filters.set_state(famille, "cle", State.CONTEXT)
        assert context_keys(filters) == {famille: ["cle"]}
        assert excluded_keys(filters) == {}


class TestGardeDesCategoriesMasquees:
    """« Le piege d'a cote » : le contexte ne doit jamais ressusciter une categorie a ✕."""

    def test_le_contexte_de_recherche_ne_repeche_pas_un_niveau_masque(self, voisinage):
        """Bout en bout, par le chemin que suit l'interface."""
        filters = FilterSet(
            levels={"INFO": State.OFF},
            text_filters=[TextFilter(pattern="la panne cherchee")],
            search_context_lines=5,
        )
        rendu = build_excerpt(voisinage, filters).to_text()
        assert "la panne cherchee" in rendu
        assert "sans interet" not in rendu

    def test_un_index_masque_fourni_de_l_exterieur_est_rejete(self, voisinage):
        """La garde propre a `build_excerpt`, celle que le ticket exige.

        L'appelant passe ici **toutes** les entrees, y compris les INFO masquees
        — ce que fait n'importe quel producteur de selection autre que
        `evaluate`. Retirer le filtre `is_excluded` de `build_excerpt` fait
        echouer ce test, alors que le precedent continuerait de passer : ce sont
        deux gardes distinctes, et celle-ci n'est prouvee que par ici.
        """
        filters = FilterSet(levels={"INFO": State.OFF})
        excerpt = build_excerpt(voisinage, filters, visible=range(len(voisinage)))
        assert [entry.level for entry in excerpt.entries] == ["ERROR"]

    def test_is_excluded_couvre_les_trois_familles(self, rules):
        """Enumere depuis le code : niveau, source et famille de bruit."""
        store = indexer(
            rules,
            ["2026-08-31 11:50:40.872 ERROR   APP (Main): Error: Unit [F-14B]: Corrupt damage model."],
        )
        assert not is_excluded(store, FilterSet(), 0)
        assert is_excluded(store, FilterSet(levels={"ERROR": State.OFF}), 0)
        assert is_excluded(store, FilterSet(sources={"dcs": State.OFF}), 0)
        assert is_excluded(store, FilterSet(noise={"damage_model": State.OFF}), 0)

    def test_un_index_hors_bornes_ne_fait_pas_tomber_l_extrait(self, voisinage):
        excerpt = build_excerpt(voisinage, FilterSet(), visible=[-1, 1, 99])
        assert len(excerpt.entries) == 1


class TestPlafond:
    """Borne : elle porte sur le texte rendu, en-tete compris, et le dit."""

    @pytest.fixture
    def long_journal(self, rules) -> LogStore:
        lignes = [f"2026-08-31 12:00:{i % 60:02d}.000 ERROR   APP (Main): panne numero {i}" for i in range(400)]
        return indexer(rules, lignes)

    @pytest.mark.parametrize("plafond", [300, 900, 2000, DEFAULT_MAX_CHARS])
    def test_le_texte_rendu_tient_dans_le_plafond(self, long_journal, plafond):
        """L'en-tete et le marqueur d'omission sont dedans, pas en plus.

        C'est le defaut mesure sur le vrai dcs.log de 11 Mo : 16 143 caracteres
        rendus pour un budget de 16 000, parce que le budget ne payait que les
        entrees.
        """
        assert len(build_excerpt(long_journal, FilterSet(), max_chars=plafond).to_text()) <= plafond

    def test_l_omission_est_annoncee(self, long_journal):
        excerpt = build_excerpt(long_journal, FilterSet(), max_chars=900)
        assert excerpt.omitted > 0
        assert excerpt.selected == 400
        assert f"{excerpt.omitted} entrées omises" in excerpt.to_text()
        assert "omises par la limite de taille" in "\n".join(excerpt.header_lines())

    def test_le_debut_et_la_fin_sont_gardes(self, long_journal):
        """La cause est en tete, le symptome en queue : une fenetre unique perd l'un des deux."""
        rendu = build_excerpt(long_journal, FilterSet(), max_chars=900).to_text()
        assert "panne numero 0" in rendu
        assert "panne numero 399" in rendu

    def test_un_budget_nul_ne_garde_rien(self, long_journal):
        excerpt = build_excerpt(long_journal, FilterSet(), max_chars=0)
        assert excerpt.entries == []
        assert excerpt.omitted == 400

    def test_rebound_resserre_et_cumule_les_omissions(self, long_journal):
        large = build_excerpt(long_journal, FilterSet(), max_chars=DEFAULT_MAX_CHARS)
        serre = large.rebound(600)
        assert len(serre.to_text()) <= 600
        assert serre.omitted >= large.omitted
        assert serre.omitted + len(serre.entries) == large.selected

    @pytest.mark.parametrize("plafond", [1, 40, 100, 142])
    def test_sous_l_en_tete_il_ne_reste_aucune_ligne(self, long_journal, plafond):
        """L'en-tete est le plancher, et c'est ce que `rebound` promet au lecteur.

        Il nomme les niveaux masques : le couper pour tenir un budget est la seule
        chose que ce module existe pour refuser. Donc un plafond que l'en-tete
        depasse deja ne rend aucun enregistrement, et *c'est* le signal que
        `build_report` lit pour lacher la section. Mesure sur le vrai dcs.log :
        143 caracteres pour un plafond de 100 sans aucun filtre, 529 pour un
        plafond de 200 avec 22 familles de bruit a ✕, deux niveaux masques et une
        recherche.
        """
        excerpt = build_excerpt(long_journal, FilterSet(), max_chars=plafond)
        assert excerpt.entries == []
        assert len(excerpt.to_text()) > plafond

    def test_un_extrait_vide_par_le_plafond_ne_se_lit_pas_comme_un_journal_calme(self, long_journal):
        """Contradiction mesuree : `87989 omises par la limite de taille` au-dessus
        de `aucune ligne retenue par les filtres courants`.

        Les filtres avaient bel et bien retenu ces lignes ; c'est le plafond qui
        les a prises. Dans un module dont le contrat est qu'un journal filtre ne
        doit jamais se lire comme un journal propre, les deux phrases doivent etre
        distinctes.
        """
        excerpt = build_excerpt(long_journal, FilterSet(), max_chars=100)
        rendu = excerpt.to_text()
        assert excerpt.entries == []
        assert excerpt.omitted == 400
        assert NOTHING_AFFORDED in rendu
        assert NOTHING_SELECTED not in rendu

    def test_un_extrait_vide_par_les_filtres_le_dit_toujours(self, rules):
        """Le cas voisin, qui ne doit pas avoir bouge : la, rien n'a ete retenu."""
        vide = indexer(rules, ["2026-08-31 12:00:00.000 INFO    APP (Main): tout va bien"])
        filtres = FilterSet(levels={"INFO": State.OFF})
        rendu = build_excerpt(vide, filtres).to_text()
        assert NOTHING_SELECTED in rendu
        assert NOTHING_AFFORDED not in rendu

    def test_une_trace_de_pile_est_ecourtee(self, rules):
        suites = [f"\tframe {i}" for i in range(MAX_CONTINUATION_LINES + 5)]
        store = indexer(
            rules,
            ["2026-08-31 11:55:01.930 ERROR   SCRIPTING (Main): Mission script error", *suites],
        )
        entry = build_excerpt(store, FilterSet()).entries[0]
        assert len(entry.continuations) == MAX_CONTINUATION_LINES + 1
        assert "lignes de trace omises" in entry.continuations[-1]

    def test_une_ligne_tres_longue_est_coupee_en_le_disant(self, rules):
        store = indexer(rules, ["2026-08-31 12:00:00.000 ERROR   APP (Main): " + "x" * 900])
        assert "[…]" in build_excerpt(store, FilterSet()).to_text()


class TestForme:
    """Structure : l'extrait garde l'horodatage, le niveau, la source, le sous-systeme."""

    def test_une_entree_garde_sa_forme(self, sensible):
        entry = build_excerpt(sensible, FilterSet()).entries[1]
        assert entry.level == "WARNING"
        assert entry.timestamp == "11:50:41.000"
        assert entry.source_id == "dcs"
        assert entry.subsystem == "NET"

    def test_le_denominateur_est_dit(self, sensible):
        excerpt = build_excerpt(sensible, FilterSet())
        assert excerpt.total_indexed == 3
        assert "sur 3 indexées" in excerpt.header_lines()[0]

    def test_une_selection_vide_le_dit(self, sensible):
        excerpt = build_excerpt(sensible, FilterSet(), visible=[])
        assert "aucune ligne retenue" in excerpt.to_text()

    def test_un_extrait_vide_a_quand_meme_un_en_tete(self):
        assert Excerpt().header_lines()
