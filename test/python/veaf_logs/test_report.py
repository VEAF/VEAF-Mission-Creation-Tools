"""Tests du bloc de rapport : le contrat entre ce lot et la reprise des bugs.

Ce bloc voyage dans un message Discord, colle a la main, par quelqu'un qui ne le
relira pas. Trois choses doivent donc tenir : il rentre dans un message ou il dit
qu'il n'y rentre pas, il se relit, et rien de personnel n'en sort — y compris ce
qui n'apparait qu'une fois les morceaux assembles.
"""

from __future__ import annotations

import pytest
from veaf_libs.diagnostics import SCHEMA as DOCTOR_SCHEMA
from veaf_libs.diagnostics import DiagnosticReport
from veaf_logs.analysis import Analysis, analyse
from veaf_logs.buffer import BytesBuffer
from veaf_logs.excerpt import build_excerpt
from veaf_logs.filters import FilterSet
from veaf_logs.report import (
    BLOCK_END,
    BLOCK_START,
    DISCORD_MESSAGE_LIMIT,
    FENCE_CLOSE,
    FENCE_OPEN,
    FIELD_ORDER,
    SCHEMA,
    SECTIONS,
    build_report,
    parse_report_block,
    to_clipboard_text,
)
from veaf_logs.store import LogStore

CHEMIN = r"C:\Users\Alphonse Dupont\Saved Games\DCS"
ADRESSE = "192.168.1.42"

JOURNAL = [
    "2026-08-31 11:50:40.872 ERROR   APP (Main): Error: Unit [F-14B]: Corrupt damage model.",
    "2026-08-31 11:50:41.000 WARNING EDCORE (Main): hypervisor is active",
    "2026-08-31 11:50:42.000 ERROR   APP (Main): quelque chose que personne n'a jamais catalogue",
]

# Un journal assez long pour que l'extrait complet depasse largement un message
# Discord : c'est le cas reel, mesure a ~16 000 caracteres sur le dcs.log de David.
GROS = [f"2026-08-31 12:00:{i % 60:02d}.000 ERROR   APP (Main): panne numero {i} sur le terrain" for i in range(400)]

# Un journal qui porte les cinq sections du bloc, propositions comprises : le
# meme message inconnu revient assez souvent pour franchir MIN_OCCURRENCES.
COMPLET = [
    *JOURNAL,
    *[
        f"2026-08-31 11:51:{i:02d}.000 ERROR   APP (Main): impossible de charger le decor numero {i} du terrain"
        for i in range(4)
    ],
]


def indexer(rules, lignes) -> LogStore:
    store = LogStore(rules, BytesBuffer(("\n".join(lignes) + "\n").encode("utf-8")))
    store.index_new()
    return store


def analyse_de(rules, lignes, **kwargs) -> Analysis:
    return analyse(indexer(rules, lignes), rules, FilterSet(), **kwargs)


@pytest.fixture
def analysis(rules) -> Analysis:
    return analyse_de(rules, JOURNAL)


@pytest.fixture
def doctor() -> DiagnosticReport:
    return DiagnosticReport(
        fields={
            "schema": DOCTOR_SCHEMA,
            "tool.version": "6.19.0",
            "dcs.detected": "yes",
            "dcs.version": "2.9.29.27278",
        },
        recent_errors=["2026-09-05 12:00:00,123 - veaf-tools - ERROR - boum\nTraceback (most recent call last):"],
    )


def doctor_de_taille(caracteres: int) -> DiagnosticReport:
    """Un rapport dont la section `recent-errors` fait a peu pres *caracteres*.

    Le defaut du bloc n'apparaissait qu'a certaines tailles : c'est la ou le
    champ `truncated` grossissait juste apres que la place avait ete mesuree.
    """
    lignes: list[str] = []
    total = 0
    while total < caracteres:
        ligne = f'  File "veaf_libs/module_{len(lignes)}.py", line {len(lignes) * 17}, in fonction_appelante'
        lignes.append(ligne)
        total += len(ligne) + 1
    return DiagnosticReport(
        fields={"schema": DOCTOR_SCHEMA, "tool.version": "6.19.0", "dcs.detected": "yes"},
        recent_errors=["\n".join(lignes)] if lignes else [],
    )


@pytest.fixture
def gros_doctor() -> DiagnosticReport:
    """Un rapport de la taille d'un vrai : ses traces pesaient ~700 caracteres sur la machine mesuree."""
    trace = "\n".join(
        [
            "2026-09-05 12:00:00,123 - veaf-tools - ERROR - Failed to evaluate time expression",
            "Traceback (most recent call last):",
            *[f'  File "veaf_libs/module_{i}.py", line {i * 17}, in fonction_appelante' for i in range(8)],
            "ValueError: unsupported expression element: Call",
        ]
    )
    return DiagnosticReport(
        fields={
            "schema": DOCTOR_SCHEMA,
            "tool.version": "6.19.0",
            "tool.executable": r"C:\Users\<user>\AppData\Local\pypoetry\Cache\virtualenvs\veaf-py3.13\python.exe",
            "machine.os": "Windows-11-10.0.26200-SP0",
            "dcs.detected": "yes",
            "dcs.version": "2.9.29.27278",
            "dcs.write_dir": r"C:\Users\<user>\Saved Games\DCS",
        },
        recent_errors=[trace, trace],
    )


class TestAssemblage:
    """Le bloc porte les quatre morceaux que le ticket enumere."""

    def test_les_sections_attendues_sont_la(self, analysis, doctor):
        bloc = build_report(analysis, doctor, max_chars=20000)
        for nom in ("doctor", "excerpt", "catalogue"):
            assert f"--- {nom} ---" in bloc

    def test_le_bloc_est_versionne(self, analysis):
        assert f"schema: {SCHEMA}" in build_report(analysis)

    def test_les_delimiteurs_encadrent_le_bloc(self, analysis):
        bloc = build_report(analysis)
        assert bloc.startswith(BLOCK_START)
        assert bloc.endswith(BLOCK_END)

    def test_le_bloc_du_doctor_survit_a_l_imbrication(self, analysis, doctor):
        """Deux blocs delimites differemment : celui du doctor ne doit pas fermer l'autre."""
        relu = parse_report_block(build_report(analysis, doctor, max_chars=20000))
        rapport = relu.doctor
        assert rapport is not None
        assert rapport.fields["tool.version"] == "6.19.0"
        assert rapport.recent_errors and "boum" in rapport.recent_errors[0]

    def test_sans_doctor_le_bloc_reste_valide(self, analysis):
        relu = parse_report_block(build_report(analysis, None))
        assert relu.fields["schema"] == SCHEMA
        assert relu.doctor is None

    def test_les_champs_declares_sont_tous_ecrits(self, analysis, doctor):
        """Enumere depuis FIELD_ORDER, qui *est* le contrat."""
        relu = parse_report_block(build_report(analysis, doctor, max_chars=20000))
        assert set(FIELD_ORDER) <= set(relu.fields)


class TestAllerRetour:
    """Le lot de reprise des bugs relit ce bloc : il doit y retrouver ses champs."""

    def test_les_compteurs_de_l_extrait_reviennent(self, rules):
        analysis = analyse_de(rules, GROS)
        relu = parse_report_block(build_report(analysis, max_chars=20000))
        assert relu.fields["excerpt.total"] == str(analysis.excerpt.total_indexed)
        assert relu.fields["excerpt.selected"] == str(analysis.excerpt.selected)

    def test_les_motifs_du_catalogue_reviennent(self, rules, analysis):
        relu = parse_report_block(build_report(analysis, max_chars=20000))
        assert "damage_model" in relu.fields["catalogue.matched"]
        assert relu.fields["catalogue.uncatalogued"] == str(analysis.uncatalogued_total)

    @pytest.mark.parametrize("section", SECTIONS)
    def test_chaque_section_declaree_se_relit(self, rules, doctor, section):
        """Enumere depuis SECTIONS : aucune n'est perdue par le lecteur.

        Sans garde `if`, et sur un journal qui produit les cinq. Le journal court
        n'offrait aucune proposition, donc la parametrisation `proposals`
        n'assertait rien : elle passait sur un bloc qui ne portait pas la section.
        """
        analysis = analyse_de(rules, COMPLET, online=lambda *_: "commentaire du modele")
        assert analysis.proposals, "le journal doit produire une proposition, sinon le cas n'est pas couvert"
        bloc = build_report(analysis, doctor, max_chars=20000)
        assert f"--- {section} ---" in bloc
        assert section in parse_report_block(bloc).sections

    def test_le_bloc_se_retrouve_au_milieu_d_un_message(self, analysis):
        entoure = f"Salut, voila mon souci :\n\n{to_clipboard_text(build_report(analysis))}\n\nMerci !"
        assert parse_report_block(entoure).fields["schema"] == SCHEMA

    def test_un_bloc_tronque_est_signale(self, analysis):
        bloc = build_report(analysis)
        with pytest.raises(ValueError, match="no complete"):
            parse_report_block(bloc.replace(BLOCK_END, ""))

    def test_un_texte_sans_bloc_est_signale(self):
        with pytest.raises(ValueError, match="no complete"):
            parse_report_block("juste un message")


class TestCaviardageDeLAssemblage:
    """Verifie sur le bloc assemble, pas seulement sur ses morceaux."""

    def test_le_commentaire_du_modele_est_caviarde(self, rules):
        """Le commentaire n'est caviarde nulle part ailleurs : il arrive du reseau.

        Retirer le `redact` de `build_report` fait tomber ce test, et lui seul —
        l'extrait, lui, est deja caviarde a la construction.
        """
        commentaire = f"Le service {ADRESSE} refuse la connexion depuis {CHEMIN}"
        analysis = analyse_de(rules, JOURNAL, online=lambda *_: commentaire)
        assert ADRESSE in analysis.commentary
        bloc = build_report(analysis, max_chars=20000)
        assert ADRESSE not in bloc
        assert "Alphonse Dupont" not in bloc
        assert "<ip>" in bloc

    def test_le_bloc_du_doctor_reste_caviarde(self, rules, analysis):
        doctor = DiagnosticReport(fields={"schema": DOCTOR_SCHEMA, "veaf.home": f"{CHEMIN}\\.veaf"})
        assert "Alphonse Dupont" not in build_report(analysis, doctor, max_chars=20000)

    def test_le_caviardage_est_stable(self, rules, analysis, doctor):
        """Un second passage ne doit pas ronger les marqueurs du premier."""
        bloc = build_report(analysis, doctor, max_chars=20000)
        assert "<<user>>" not in bloc
        assert "<<ip>>" not in bloc


class TestBornes:
    """Il rentre dans un message, ou il dit ce qu'il a retire."""

    def test_le_texte_colle_tient_dans_un_message_discord(self, rules, doctor):
        analysis = analyse_de(rules, GROS, online=lambda *_: "commentaire " * 200)
        colle = to_clipboard_text(build_report(analysis, doctor))
        assert len(colle) <= DISCORD_MESSAGE_LIMIT

    def test_ce_qui_a_ete_retire_est_nomme(self, rules, doctor):
        analysis = analyse_de(rules, GROS, online=lambda *_: "commentaire " * 200)
        relu = parse_report_block(build_report(analysis, doctor))
        assert relu.fields["truncated"] != "non"
        assert "analysis" in relu.fields["truncated"]

    def test_l_extrait_survit_a_la_contrainte_discord(self, rules, doctor):
        """Le defaut corrige : l'extrait etait jete en entier, donc dans tous les cas reels.

        L'extrait complet fait plus de dix fois la taille d'un message ; il doit
        etre *reduit*, pas supprime — sinon le rapport ne decrit plus que la
        machine et plus du tout le probleme.
        """
        analysis = analyse_de(rules, GROS)
        assert len(analysis.excerpt.to_text()) > DISCORD_MESSAGE_LIMIT * 5
        relu = parse_report_block(build_report(analysis, doctor))
        assert "excerpt" in relu.sections
        assert relu.sections["excerpt"].strip()
        assert "panne numero" in relu.sections["excerpt"]

    def test_les_enregistrements_du_doctor_partent_avant_l_extrait(self, rules, gros_doctor):
        """Mesuré : les traces de `veaf-tools` mangeaient tout le message.

        Une trace de pile d'un autre outil vaut moins, dans un rapport sur un
        journal DCS, que les lignes que l'utilisateur vient signaler.
        """
        relu = parse_report_block(build_report(analyse_de(rules, GROS), gros_doctor))
        assert "doctor.recent-errors" in relu.fields["truncated"]
        rapport = relu.doctor
        assert rapport is not None
        assert rapport.recent_errors == []
        assert rapport.fields["tool.version"] == "6.19.0"
        assert "excerpt" in relu.sections

    def test_le_champ_decrit_le_bloc_et_pas_l_analyse(self, rules, doctor):
        """Un champ qui annonce 157 entrees au-dessus d'une section qui en porte 7 ment.

        Le consommateur lit ce champ *pour ne pas avoir a compter* : il n'a aucun
        moyen d'attraper l'ecart.
        """
        bloc = build_report(analyse_de(rules, GROS), doctor)
        relu = parse_report_block(bloc)
        lignes = [ligne for ligne in relu.sections["excerpt"].splitlines() if " ERROR " in ligne]
        assert int(relu.fields["excerpt.shown"]) == len(lignes)
        assert int(relu.fields["excerpt.shown"]) + int(relu.fields["excerpt.omitted"]) == int(
            relu.fields["excerpt.selected"]
        )

    def test_un_rapport_court_n_est_pas_annonce_comme_tronque(self, analysis):
        assert parse_report_block(build_report(analysis, max_chars=20000)).fields["truncated"] == "non"

    def test_l_extrait_est_lache_quand_il_ne_reste_plus_de_place(self, rules, doctor):
        """En dessous d'un plancher, un extrait n'est plus un extrait."""
        analysis = analyse_de(rules, GROS)
        relu = parse_report_block(build_report(analysis, doctor, max_chars=800))
        assert "excerpt" not in relu.sections
        assert "excerpt" in relu.fields["truncated"]

    def test_un_plafond_intenable_est_annonce_plutot_que_subi(self, analysis, doctor):
        """Coupe au ras du bord, un bloc incomplet se lit comme un bloc complet."""
        relu = parse_report_block(build_report(analysis, doctor, max_chars=200))
        assert relu.fields["truncated"].startswith("OUI")
        assert "deux messages" in relu.fields["truncated"]

    @pytest.mark.parametrize("taille_du_doctor", [0, 10, 120, 240, 360, 480, 590])
    def test_le_bloc_rendu_ne_depasse_jamais_le_plafond(self, rules, taille_du_doctor):
        """Mesure : 30 des 240 tailles balayees rendaient un bloc au-dessus de sa limite.

        La cause etait en amont du plafond : le champ `truncated` etait ecrit
        *apres* que la place de l'extrait avait ete mesuree, donc le bloc
        grossissait au-dela de la place calculee pour lui.
        """
        analysis = analyse_de(rules, GROS, online=lambda *_: "commentaire " * 200)
        bloc = build_report(analysis, doctor_de_taille(taille_du_doctor))
        assert len(to_clipboard_text(bloc)) <= DISCORD_MESSAGE_LIMIT

    @pytest.mark.parametrize("plafond", [200, 260, 320, 400, 480])
    def test_le_chiffre_annonce_est_celui_du_bloc_rendu(self, rules, doctor, plafond):
        """Chaque `OUI — N caracteres` etait decale de 21 : la croissance du champ lui-meme.

        Le champ est *dans* le bloc qu'il mesure, donc l'ecrire change la
        longueur dont il a ete tire.
        """
        bloc = build_report(analyse_de(rules, GROS), doctor, max_chars=plafond)
        annonce = parse_report_block(bloc).fields["truncated"]
        assert annonce.startswith("OUI")
        chiffre = int(annonce.split("—")[1].split("caractères")[0].strip())
        assert chiffre == len(bloc)

    def test_un_bloc_qui_rentre_n_est_jamais_annonce_comme_trop_grand(self, rules, doctor):
        """L'erreur allait dans les deux sens : 59 des 240 cas annoncaient `OUI` en rentrant.

        Balaye tout le domaine ou le bloc bascule, plutot qu'un plafond choisi :
        c'est a la frontiere que le champ mentait.
        """
        analysis = analyse_de(rules, GROS, online=lambda *_: "commentaire " * 200)
        for plafond in range(200, 2400, 13):
            bloc = build_report(analysis, doctor, max_chars=plafond)
            budget = plafond - len(FENCE_OPEN) - len(FENCE_CLOSE) - 2
            if parse_report_block(bloc).fields["truncated"].startswith("OUI"):
                assert len(bloc) > budget, f"annonce OUI a {plafond} alors que le bloc rentre"
            else:
                assert len(bloc) <= budget, f"bloc de {len(bloc)} pour {budget} sans le dire, a {plafond}"

    def test_ce_qui_a_ete_retire_survit_a_l_annonce_de_depassement(self, rules, doctor):
        """Le `OUI` ecrasait la liste de ce qui manquait ; le lecteur en a besoin."""
        annonce = parse_report_block(build_report(analyse_de(rules, GROS), doctor, max_chars=260)).fields["truncated"]
        assert annonce.startswith("OUI")
        assert "excerpt" in annonce


class TestPressePapier:
    """Le bloc traverse le Markdown de Discord sans se defaire."""

    def test_le_bloc_est_entoure_d_une_cloture(self, analysis):
        colle = to_clipboard_text(build_report(analysis))
        assert colle.startswith(FENCE_OPEN)
        assert colle.endswith(FENCE_CLOSE)

    def test_une_cloture_dans_le_contenu_est_neutralisee(self, rules):
        """Sans ca, trois accents graves dans un message ferment la cloture trop tot."""
        analysis = analyse_de(rules, JOURNAL, online=lambda *_: "voici du code ``` et la suite")
        bloc = build_report(analysis, max_chars=20000)
        assert "```" not in bloc
        assert "'''" in bloc


class TestPlancherDeLExtrait:
    """Le plancher se prouve des deux cotes, sinon il n'est pas prouve.

    L'assertion precedente — `MIN_EXCERPT_CHARS > 0` — portait sur une constante :
    elle restait verte que `build_report` consulte le plancher ou non, qu'il vaille
    200 ou 20 000, et que l'extrait soit garde ou jete. Meme forme que le
    `redact("veafCombatMission")` du lot precedent et que `test_defaultSpawnRadii`.

    Le cote « en dessous, la section part » est couvert par
    `test_l_extrait_est_lache_quand_il_ne_reste_plus_de_place` ; c'est le
    contre-cas qui manquait.
    """

    def test_au_dessus_du_plancher_la_section_garde_des_lignes(self, rules, doctor):
        """Le contre-cas manquant : il tombe si le plancher monte ou si le test s'inverse.

        Cherche le plus petit plafond qui laisse a l'extrait une place au-dessus
        du plancher, plutot qu'un chiffre choisi a la main qui se decalerait au
        premier changement de format du bloc.
        """
        analysis = analyse_de(rules, GROS)
        garde = [
            plafond
            for plafond in range(800, 2400, 4)
            if "excerpt" in parse_report_block(build_report(analysis, doctor, max_chars=plafond)).sections
        ]
        assert garde, "aucun plafond ne garde l'extrait : le plancher ne peut plus etre franchi"
        relu = parse_report_block(build_report(analysis, doctor, max_chars=garde[0]))
        assert int(relu.fields["excerpt.shown"]) > 0
        assert "panne numero" in relu.sections["excerpt"]

    def test_un_en_tete_seul_n_entre_jamais_dans_le_bloc(self, rules, doctor):
        """`rebound` rend l'en-tete quel que soit le budget ; le bloc ne le colle pas.

        C'est la moitie du contrat qui est du cote de l'appelant, et elle se teste
        ici : un extrait sans enregistrement n'est pas un extrait, il n'entre donc
        pas dans le bloc — et le champ dit qu'il est parti.
        """
        relu = parse_report_block(build_report(analyse_de(rules, GROS), doctor, max_chars=700))
        assert "excerpt" not in relu.sections
        assert relu.fields["excerpt.shown"] == "0"
        assert "excerpt" in relu.fields["truncated"]
