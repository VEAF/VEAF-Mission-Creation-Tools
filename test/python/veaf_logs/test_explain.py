"""Tests d'« Expliquer » : le catalogue d'abord, l'ignorance avouee, le modele ensuite.

Deux exigences dominent ce lot et se testent ici.

La premiere est que le texte du catalogue soit **repris tel quel**. On ne
l'echantillonne pas : les 22 familles de bruit de `rules.json` sont enumerees
depuis le fichier, et chacune doit ressortir mot pour mot.

La seconde est que le modele ne soit jamais confondu avec le catalogue, ni sur
la page ni dans l'ordre — et que son absence ne casse rien.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
import requests
from veaf_logs.analysis import (
    CATALOGUE_HEADING,
    MODEL_HEADING,
    UNCATALOGUED_HEADING,
    UNCATALOGUED_MARK,
    analyse,
    default_online_layer,
)
from veaf_logs.buffer import BytesBuffer
from veaf_logs.catalogue import (
    KIND_NOISE,
    CatalogueMatch,
    match_catalogue,
    render_catalogue,
    subsystem_family,
    to_worker_matches,
    uncatalogued_entries,
)
from veaf_logs.excerpt import build_excerpt
from veaf_logs.filters import FilterSet
from veaf_logs.proposals import (
    _PLACEHOLDER_PATTERNS,
    MIN_LITERAL_CHARS,
    PLACEHOLDER_HELP,
    literal_chars,
    normalise,
    pattern_from,
    propose_rules,
    render_proposals,
    validate_pattern,
)
from veaf_logs.rules import DEFAULT_RULES_PATH, Rules
from veaf_logs.store import LogStore
from veaf_logs.worker_client import AnalysisUnavailable, analyse_excerpt

# Une ligne par famille de bruit ne serait pas tenable a la main ; on prend les
# quelques familles dont le motif est un texte simple, et on verifie l'exactitude
# du rendu sur *toutes* par le chemin de `render_catalogue`.
JOURNAL = [
    "2026-08-31 11:50:40.872 ERROR   APP (Main): Error: Unit [F-14B]: Corrupt damage model.",
    "2026-08-31 11:50:41.000 WARNING EDCORE (Main): hypervisor is active",
    "2026-08-31 11:50:42.000 WARNING RENDERER (Main): Unknown DLSS preset 'L'",
    "2026-08-31 11:50:43.000 INFO    SCRIPTING (Main): VEAF|I|5390: Loading version 6.16.5",
    "2026-08-31 11:50:44.000 ERROR   APP (Main): quelque chose que personne n'a jamais catalogue",
]

# Le meme incident, avec un identifiant different a chaque fois : c'est ce que la
# normalisation doit ramener a un seul motif.
RECURRENT = [
    f"2026-08-31 12:00:{i:02d}.000 ERROR   APP (Main): Error: Unit [{nom}]: Effect presets records are empty."
    for i, nom in enumerate(("QF-4E", "F-14B", "MiG-29S", "Su-27"))
]


def indexer(rules, lignes) -> LogStore:
    store = LogStore(rules, BytesBuffer(("\n".join(lignes) + "\n").encode("utf-8")))
    store.index_new()
    return store


@pytest.fixture
def journal(rules) -> LogStore:
    return indexer(rules, JOURNAL)


@pytest.fixture
def recurrent(rules) -> LogStore:
    return indexer(rules, RECURRENT)


class TestCatalogueVerbatim:
    """Le catalogue est l'autorite : son texte sort tel quel, jamais reformule."""

    @pytest.mark.parametrize("famille", json.loads(DEFAULT_RULES_PATH.read_text(encoding="utf-8"))["noise"])
    def test_chaque_famille_est_rendue_mot_pour_mot(self, famille):
        """Enumere depuis rules.json : les 22 familles, pas trois choisies a la main.

        Le test tombe des qu'une famille perd son `help`, ou que le rendu se met
        a paraphraser au lieu de citer.
        """
        assert famille["help"], f"{famille['id']} n'a pas de texte a citer"
        match = CatalogueMatch(
            id=famille["id"],
            label=famille["label"],
            help=famille["help"],
            kind=KIND_NOISE,
            count=1,
        )
        rendu = render_catalogue([match])
        assert famille["help"] in rendu
        assert famille["label"] in rendu
        assert famille["id"] in rendu

    def test_le_texte_vient_du_fichier_et_pas_du_code(self, rules, journal):
        """Le `help` rendu est celui de rules.json, lu ici independamment."""
        data = json.loads(DEFAULT_RULES_PATH.read_text(encoding="utf-8"))
        attendu = next(item["help"] for item in data["noise"] if item["id"] == "damage_model")
        excerpt = build_excerpt(journal, FilterSet())
        assert attendu in render_catalogue(match_catalogue(rules, excerpt))

    def test_les_motifs_reconnus_sont_comptes(self, rules, journal):
        excerpt = build_excerpt(journal, FilterSet())
        trouves = {item.id: item.count for item in match_catalogue(rules, excerpt)}
        assert trouves["damage_model"] == 1
        assert trouves["hypervisor"] == 1
        assert trouves["dlss_preset"] == 1

    def test_un_extrait_sans_motif_connu_le_dit(self, rules):
        assert "ne reconnaît aucun motif" in render_catalogue([])

    def test_la_famille_de_sous_systeme_vient_du_catalogue(self, rules):
        assert subsystem_family(rules, "DX11BACKEND") == "Graphismes"
        assert subsystem_family(rules, "INEXISTANT") == ""
        assert subsystem_family(rules, "") == ""


class TestIgnoranceAvouee:
    """Le pire echec n'est pas le silence, c'est une cause plausible et fausse."""

    def test_une_ligne_inconnue_est_listee_comme_non_cataloguee(self, rules, journal):
        excerpt = build_excerpt(journal, FilterSet())
        inconnues = uncatalogued_entries(rules, excerpt)
        assert any("jamais catalogue" in entry.message for entry in inconnues)

    def test_une_ligne_de_script_reconnu_n_est_pas_non_cataloguee(self, rules, journal):
        excerpt = build_excerpt(journal, FilterSet())
        assert all(entry.source_id != "veaf" for entry in uncatalogued_entries(rules, excerpt))

    def test_la_mention_apparait_dans_le_rendu(self, rules, journal):
        rendu = analyse(indexer(rules, JOURNAL), rules, FilterSet()).to_text()
        assert UNCATALOGUED_MARK in rendu
        assert UNCATALOGUED_HEADING in rendu

    def test_seules_les_entrees_expliquees_partent_au_modele(self, rules, journal):
        """Un emetteur sans `help` n'apporte rien au prompt, mais invite a broder."""
        excerpt = build_excerpt(journal, FilterSet())
        matches = match_catalogue(rules, excerpt)
        assert any(item.kind != KIND_NOISE for item in matches)
        envoyes = to_worker_matches(matches)
        assert envoyes and all(item["help"] for item in envoyes)


class TestOrdreDesCouches:
    """Le catalogue avant le modele, et separes par bloc — pas par un avertissement en bas."""

    def test_le_catalogue_precede_le_modele(self, rules):
        rendu = analyse(indexer(rules, JOURNAL), rules, FilterSet(), online=lambda *_: "commentaire").to_text()
        assert rendu.index(CATALOGUE_HEADING) < rendu.index(MODEL_HEADING)

    def test_les_deux_sections_sont_titrees(self, rules):
        rendu = analyse(indexer(rules, JOURNAL), rules, FilterSet(), online=lambda *_: "commentaire").to_text()
        assert CATALOGUE_HEADING in rendu
        assert MODEL_HEADING in rendu
        assert "généré" in MODEL_HEADING
        assert "rules.json" in CATALOGUE_HEADING

    def test_le_commentaire_du_modele_est_repris(self, rules):
        analysis = analyse(indexer(rules, JOURNAL), rules, FilterSet(), online=lambda *_: "  chaine de causes  ")
        assert analysis.commentary == "chaine de causes"
        assert "chaine de causes" in analysis.to_text()


class TestModeDegrade:
    """Sans reseau, la couche catalogue est une reponse complete."""

    def test_sans_couche_en_ligne_le_catalogue_repond_seul(self, rules):
        analysis = analyse(indexer(rules, JOURNAL), rules, FilterSet())
        assert analysis.commentary == ""
        assert analysis.model_error == ""
        assert analysis.matches
        assert "non demandée" in analysis.to_text()

    def test_un_service_injoignable_ne_leve_pas(self, rules):
        def tombe(*_):
            raise AnalysisUnavailable("service injoignable")

        analysis = analyse(indexer(rules, JOURNAL), rules, FilterSet(), online=tombe)
        assert analysis.model_error == "service injoignable"
        assert analysis.matches
        assert "service injoignable" in analysis.to_text()

    def test_une_panne_imprevue_ne_leve_pas_non_plus(self, rules):
        def explose(*_):
            raise RuntimeError("boum")

        analysis = analyse(indexer(rules, JOURNAL), rules, FilterSet(), online=explose)
        assert "boum" in analysis.model_error
        assert analysis.matches

    def test_une_reponse_vide_est_signalee(self, rules):
        analysis = analyse(indexer(rules, JOURNAL), rules, FilterSet(), online=lambda *_: "   ")
        assert "n'a rien renvoyé" in analysis.model_error

    def test_une_selection_vide_produit_quand_meme_une_reponse(self, rules):
        analysis = analyse(indexer(rules, JOURNAL), rules, FilterSet(), visible=[])
        assert analysis.to_text()
        assert "aucune ligne retenue" in analysis.to_text()


class _Reponse:
    """Reponse SSE minimale, telle que le Worker la rend."""

    def __init__(self, lignes, status=200) -> None:
        self._lignes = lignes
        self.status_code = status

    def iter_lines(self, decode_unicode=False):
        yield from self._lignes

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False


class _Session:
    def __init__(self, reponse) -> None:
        self.reponse = reponse
        self.calls: list[dict] = []

    def post(self, url, **kwargs):
        self.calls.append({"url": url, **kwargs})
        if isinstance(self.reponse, Exception):
            raise self.reponse
        return self.reponse


class TestClientDuWorker:
    """La couche en ligne : ce qui part, ce qui revient, et ce qui echoue proprement."""

    def test_les_fragments_sont_rassembles(self):
        session = _Session(_Reponse(['data: {"text": "une "}', 'data: {"text": "reponse"}', "data: [DONE]"]))
        assert analyse_excerpt("extrait", [], session=session) == "une reponse"

    def test_le_mode_logs_est_declare(self):
        session = _Session(_Reponse(['data: {"text": "x"}']))
        analyse_excerpt("extrait", [{"id": "a", "label": "A", "help": "h", "count": 2}], session=session)
        appel = session.calls[0]
        assert appel["headers"]["X-VEAF-Client"] == "logs"
        assert appel["json"]["excerpt"] == "extrait"
        assert appel["json"]["matches"][0]["id"] == "a"
        assert appel["json"]["lang"] == "fr"

    def test_la_langue_est_bornee_a_deux_valeurs(self):
        session = _Session(_Reponse(['data: {"text": "x"}']))
        analyse_excerpt("e", [], lang="de", session=session)
        assert session.calls[0]["json"]["lang"] == "fr"

    def test_une_erreur_dans_le_flux_est_remontee(self):
        session = _Session(_Reponse(['data: {"error": "trop de requetes"}']))
        with pytest.raises(AnalysisUnavailable, match="trop de requetes"):
            analyse_excerpt("extrait", [], session=session)

    def test_un_code_http_non_200_est_remonte(self):
        session = _Session(_Reponse([], status=403))
        with pytest.raises(AnalysisUnavailable, match="403"):
            analyse_excerpt("extrait", [], session=session)

    def test_un_reseau_absent_est_remonte(self):
        session = _Session(requests.ConnectionError("pas de route"))
        with pytest.raises(AnalysisUnavailable, match="indisponible"):
            analyse_excerpt("extrait", [], session=session)

    def test_un_fragment_illisible_ne_perd_pas_les_autres(self):
        session = _Session(_Reponse(["data: pas du json", 'data: {"text": "garde"}']))
        assert analyse_excerpt("extrait", [], session=session) == "garde"

    def test_les_lignes_en_octets_sont_decodees(self):
        session = _Session(_Reponse([b'data: {"text": "octets"}']))
        assert analyse_excerpt("extrait", [], session=session) == "octets"

    def test_la_couche_par_defaut_transmet_la_question(self, monkeypatch):
        vus: dict = {}

        def faux(excerpt, matches, question="", lang="fr", **_):
            vus.update(question=question, lang=lang)
            return "ok"

        monkeypatch.setattr("veaf_logs.analysis.analyse_excerpt", faux)
        assert default_online_layer("pourquoi ?", "en")("extrait", []) == "ok"
        assert vus == {"question": "pourquoi ?", "lang": "en"}


class TestPropositionsDeRegles:
    """Un motif qui revient et que rien n'explique est une entree manquante."""

    def test_le_meme_incident_sous_des_identifiants_differents_est_reconnu(self, rules, recurrent):
        excerpt = build_excerpt(recurrent, FilterSet())
        propositions = propose_rules(rules, excerpt)
        assert len(propositions) == 1
        assert propositions[0].count == 4

    def test_la_proposition_a_la_forme_de_rules_json(self, rules, recurrent):
        entree = propose_rules(rules, build_excerpt(recurrent, FilterSet()))[0].to_entry()
        assert set(entree) == {"id", "label", "help", "default_hidden", "match", "regex"}
        assert entree["regex"] is True
        # Une regle que personne n'a relue ne doit pas commencer sa vie en masquant.
        assert entree["default_hidden"] is False
        assert entree["help"] == PLACEHOLDER_HELP

    def test_le_motif_genere_retrouve_les_lignes_dont_il_sort(self, rules, recurrent):
        import re

        proposition = propose_rules(rules, build_excerpt(recurrent, FilterSet()))[0]
        motif = re.compile(proposition.match)
        assert all(motif.search(ligne.split("): ", 1)[1]) for ligne in RECURRENT)

    def test_l_identifiant_ne_collisionne_pas_avec_le_catalogue(self, rules, recurrent):
        pris = {famille.id for famille in rules.noise} | {source.id for source in rules.sources}
        assert propose_rules(rules, build_excerpt(recurrent, FilterSet()))[0].id not in pris

    def test_un_incident_isole_n_est_pas_propose(self, rules, journal):
        """Deux fois est une coincidence : le seuil existe pour ca."""
        assert propose_rules(rules, build_excerpt(journal, FilterSet())) == []

    def test_une_ligne_deja_cataloguee_n_est_jamais_proposee(self, rules):
        connu = [f"2026-08-31 12:00:{i:02d}.000 WARNING EDCORE (Main): hypervisor is active" for i in range(6)]
        assert propose_rules(rules, build_excerpt(indexer(rules, connu), FilterSet())) == []

    def test_rien_n_est_ecrit_dans_rules_json(self, rules, recurrent):
        """La garantie du ticket : le catalogue reste ecrit a la main."""
        avant = Path(DEFAULT_RULES_PATH).read_bytes()
        propose_rules(rules, build_excerpt(recurrent, FilterSet()))
        assert Path(DEFAULT_RULES_PATH).read_bytes() == avant

    def test_le_rendu_annonce_ce_qu_il_est(self, rules, recurrent):
        rendu = render_proposals(propose_rules(rules, build_excerpt(recurrent, FilterSet())))
        assert "à relire" in rendu
        assert "exemple :" in rendu

    def test_sans_proposition_la_section_disparait(self):
        assert render_proposals([]) == ""


class TestValidationDesMotifs:
    """Un motif inutilisable coute plus cher au mainteneur qu'un motif manquant."""

    @pytest.mark.parametrize("fragment", sorted(set(_PLACEHOLDER_PATTERNS.values())))
    def test_un_motif_qui_commence_par_un_joker_est_refuse(self, fragment):
        """Enumere depuis le code : chaque forme de joker, pas une choisie a la main."""
        motif = fragment + "un texte litteral assez long pour passer le seuil"
        assert "non ancré" in validate_pattern(motif, "n'importe quoi")

    def test_un_motif_trop_general_est_refuse(self):
        assert "littéral" in validate_pattern(r"abc\S+", "abc x")

    def test_un_quantificateur_imbrique_est_refuse(self):
        motif = "Erreur de chargement du module (a+)+ dans la mission"
        assert "imbriqué" in validate_pattern(motif, "x")

    @pytest.mark.parametrize("joker", [r"\S+\S+", r"[0-9A-Fa-f]+[\d.]+", r"\S+[\d.]+"])
    def test_deux_jokers_illimites_cote_a_cote_sont_refuses(self, joker):
        """La garde des quantificateurs imbriques ne voyait pas la forme reellement generee.

        Elle exige un groupe parenthese ; `pattern_from` n'en produit jamais. Ce
        que le module produit, c'est des quantificateurs illimites adjacents —
        mesure sur `dcs.log-20250814-120017.zip` : `\\S+\\S+\\S+` coutait 1,9 s
        sur une ligne de 1 600 caracteres qui echoue de peu.
        """
        motif = "Erreur de chargement du module " + joker
        assert "côte à côte" in validate_pattern(motif, "x")

    def test_un_motif_invalide_est_refuse(self):
        assert "invalide" in validate_pattern("Erreur de chargement [non fermee", "x")

    def test_un_motif_vide_est_refuse(self):
        assert validate_pattern("", "x") == "motif vide"

    def test_un_motif_qui_ne_retrouve_pas_sa_ligne_est_refuse(self):
        assert "ne retrouve pas" in validate_pattern(re_escape("Erreur de chargement du module"), "autre chose")

    def test_un_bon_motif_passe(self):
        assert validate_pattern(re_escape("Erreur de chargement du module"), "Erreur de chargement du module X") == ""

    def test_le_compte_de_litteraux_ignore_les_jokers(self):
        assert literal_chars(r"\S+") == 0
        assert literal_chars(re_escape("abcdefghijkl")) == MIN_LITERAL_CHARS


class TestNormalisation:
    """Ce qui fait passer le meme message pour cinquante messages differents."""

    @pytest.mark.parametrize(
        ("brut", "attendu"),
        [
            ("Unit [F-14B] failed", "Unit <b> failed"),
            ("preset 'L' unknown", "preset <q> unknown"),
            ("failed after 42 tries", "failed after <n> tries"),
            ("at address 0xDEADBEEF", "at address <hex>"),
            ("cannot open /textures/x.dds", "cannot open <path>"),
        ],
    )
    def test_les_parties_variables_sont_remplacees(self, brut, attendu):
        assert normalise(brut) == attendu

    def test_le_reste_de_la_phrase_survit_a_un_chemin(self):
        """Defaut mesure sur le vrai dcs.log : le chemin avalait la fin de la phrase."""
        brut = "Source coremods/tech/x/textures is already mounted to the same mount /textures/."
        assert normalise(brut) == "Source coremods<path> is already mounted to the same mount <path>"

    def test_le_motif_reconstruit_garde_les_mots(self):
        motif = pattern_from(normalise("Source coremods/x/y is already mounted to the same mount /z/."))
        assert "already" in motif
        assert "mounted" in motif

    @pytest.mark.parametrize(
        ("brut", "attendu"),
        [
            (
                "can't load destroyed model 'Ural-375_p_1' for '1L13 EWR'",
                "can't load destroyed model <q> for <q>",
            ),
            (
                "Can't load image '/textures/x.dds'. Reason: The parameter is incorrect.",
                "Can't load image <q>. Reason: The parameter is incorrect.",
            ),
            ("doesn't know the preset 'L'", "doesn't know the preset <q>"),
        ],
    )
    def test_l_apostrophe_d_une_contraction_n_ouvre_pas_une_paire_de_guillemets(self, brut, attendu):
        """Mesure sur `dcs.log-20250916-100236.zip` : la regle etait a l'envers.

        `'[^']*'` demarrait sur le `'` de `can't` et se fermait sur le guillemet
        *ouvrant* de la vraie valeur : le texte variable restait litteral et les
        mots qui identifient la plainte devenaient des jokers.
        """
        assert normalise(brut) == attendu

    def test_le_motif_d_une_contraction_garde_les_mots_qui_identifient_la_plainte(self):
        """Le motif genere ×95 sur les archives reelles avait perdu `load image`.

        Il attrapait alors une plainte differente — `Can't open file '…'. Reason:
        The parameter is incorrect.` — et son libelle etait illisible.
        """
        import re

        brut = "Can't load image '/textures/x.dds'. Reason: The parameter is incorrect."
        motif = pattern_from(normalise(brut))
        assert "load" in motif
        assert "image" in motif
        assert re.search(motif, brut)
        assert not re.search(motif, "Can't open file '/a/b'. Reason: The parameter is incorrect.")

    def test_un_decimal_long_reste_un_nombre(self):
        """Un decimal de 8 chiffres est une chaine hexadecimale valide.

        Sur les archives reelles, le meme message se normalisait donc en deux
        formes selon l'ordre de grandeur de son nombre : `More out of memory in
        SharedBuffer for N bytes` sortait ×71 au lieu de ×95.
        """
        gros = normalise("More out of memory in SharedBuffer for 22369776 bytes.")
        petit = normalise("More out of memory in SharedBuffer for 8388736 bytes.")
        assert gros == petit
        assert "<n>" in gros

    @pytest.mark.parametrize("brut", ["at address 0xDEADBEEF", "handle DEADBEEF12 released"])
    def test_un_vrai_identifiant_hexadecimal_reste_un_hexadecimal(self, brut):
        assert "<hex>" in normalise(brut)

    def test_les_jokers_identiques_qui_se_touchent_sont_fusionnes(self):
        """Un chemin Windows fait tirer `<path>` trois fois de suite.

        Mesure sur `dcs.log-20250814-120017.zip` : `Added sound path: \\S+\\S+\\S+
        Games\\S+`, accepte par `validate_pattern`, coutait 1,9 s sur une ligne de
        1 600 caracteres qui echoue de peu — contre 0,006 ms une fois fusionne.
        """
        motif = pattern_from(normalise(r"Added sound path: C:\Users\<user>\Saved Games\DCS\Sounds"))
        assert r"\S+\S+" not in motif
        assert validate_pattern(motif, r"Added sound path: C:\Users\<user>\Saved Games\DCS\Sounds") == ""


def re_escape(text: str) -> str:
    import re

    return re.escape(text)
