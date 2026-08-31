"""Tests du catalogue applique par l'index : sources, niveaux, familles de bruit.

Les cas viennent tous de journaux DCS reels. Ils passent par `LogStore`,
c'est-a-dire par le chemin reellement emprunte par l'application.
"""

from __future__ import annotations

import pytest
from veaf_logs.buffer import BytesBuffer
from veaf_logs.store import LogStore

HEAD = "2026-08-31 11:50:46.140 INFO    SCRIPTING (Main): "


def indexer(rules, *lignes) -> LogStore:
    data = ("\n".join(lignes) + "\n").encode("utf-8")
    store = LogStore(rules, BytesBuffer(data))
    store.index_new()
    return store


def une(rules, ligne):
    store = indexer(rules, ligne)
    assert len(store) == 1, f"attendu 1 entree, obtenu {len(store)}"
    return store.entry(0)


class TestEnTete:
    def test_ligne_standard(self, rules):
        entry = une(
            rules,
            "2026-08-31 11:50:40.872 ERROR   DX11BACKEND (20628): Unknown DLSS preset 'L', use default preset 'C'",
        )
        assert entry.timestamp == "2026-08-31 11:50:40.872"
        assert entry.level == "ERROR"
        assert entry.subsystem == "DX11BACKEND"
        assert entry.message.startswith("Unknown DLSS preset")

    def test_thread_principal(self, rules):
        entry = une(rules, "2026-08-31 11:49:47.842 INFO    APP (Main): Build number: 554")
        assert entry.message == "Build number: 554"

    def test_sous_systeme_avec_deux_points(self, rules):
        entry = une(
            rules,
            "2026-08-31 11:55:18.131 INFO    MissionScripting::initialize (Main): "
            "[dcs-fiddle-server] - Handling Request",
        )
        assert entry.subsystem == "MissionScripting::initialize"

    def test_niveau_error_once(self, rules):
        entry = une(
            rules,
            "2026-01-16 10:37:11.100 ERROR_ONCE DX11BACKEND (1234): render target 'uiTargetDepth' not found",
        )
        assert entry.level == "ERROR_ONCE"

    def test_niveau_alert(self, rules):
        entry = une(
            rules,
            "2026-01-16 10:37:11.100 ALERT   APP (Main): MiG-21PD MISMATCH DESCRIPTOR TYPE !!!!",
        )
        assert entry.level == "ALERT"

    def test_niveau_inconnu(self, rules):
        entry = une(rules, "2026-01-16 10:37:11.100 BIZARRE APP (Main): quelque chose")
        assert entry.level == "UNKNOWN"

    def test_message_vide(self, rules):
        """Releve tel quel dans un journal : sous-systeme absent, message vide."""
        entry = une(rules, "2026-01-16 10:37:11.100 ERROR_ONCE  ():")
        assert entry.level == "ERROR_ONCE"
        assert entry.message == ""

    def test_ligne_d_ouverture_du_journal(self, rules):
        entry = une(rules, "=== Log opened UTC 2026-08-31 11:49:46")
        assert entry.level == "INFO"
        assert entry.timestamp == ""


class TestSources:
    @pytest.mark.parametrize(
        "message,source,label",
        [
            ("VEAF|I|5390: Loading version 6.16.5", "veaf", "VEAF"),
            ("VEAF-GRASS|I|123: bearing", "veaf", "VEAF"),
            ("VEAF-DYNAMICLOADER: D:/dev/_VEAF/", "veaf-dynamicloader", "VEAF"),
            ("[CTLD][INFO] CTLDSceneManager: initialized", "ctld", "CTLD"),
            (" I - CSAR - Loading version 2024.07.11.01-VEAF", "csar", "CSAR"),
            ("AIEN|I|4047: loading desanitized function", "aien", "AIEN"),
            ("--- SKYNET VERSION: 3.4.0RP-VEAF ---", "skynet", "Skynet"),
            ("Slmod: no config file detected.", "slmod", "Slmod"),
            ("[dcs-bridge] no connection for 5s", "dcs-bridge", "dcs-bridge"),
        ],
    )
    def test_identification(self, rules, message, source, label):
        entry = une(rules, HEAD + message)
        assert entry.source == source
        assert entry.source_label == label

    def test_module(self, rules):
        assert une(rules, HEAD + "VEAF-GRASS|I|123: buildFarp").module == "GRASS"

    def test_sans_module(self, rules):
        assert une(rules, HEAD + "VEAF|I|5390: version").module == ""

    def test_sous_systeme_natif(self, rules):
        entry = une(rules, "2026-08-31 11:50:40.872 ERROR   DX11BACKEND (20628): rien")
        assert entry.source == "dcs"
        assert entry.source_label == "DX11BACKEND"


class TestNiveauAffine:
    """DCS journalise tout le Lua en INFO ; le vrai niveau est dans le prefixe."""

    def test_avertissement_veaf_sous_un_info_dcs(self, rules):
        entry = une(rules, HEAD + "VEAF|W|log|123: CTLDCoreManager: extractable not found")
        assert entry.level == "WARNING", "le W de VEAF doit primer sur le INFO de DCS"

    @pytest.mark.parametrize(
        "prefixe,niveau",
        [
            ("VEAF-SHORTCUTS|D|42: x", "DEBUG"),
            ("VEAF-RADIO|T|42: x", "TRACE"),
            ("VEAF|E|42: x", "ERROR"),
            ("VEAF|I|42: x", "INFO"),
        ],
    )
    def test_niveaux_veaf(self, rules, prefixe, niveau):
        assert une(rules, HEAD + prefixe).level == niveau

    def test_niveau_ctld_nomme(self, rules):
        assert une(rules, HEAD + "[CTLD][WARNING] souci").level == "WARNING"

    def test_lettre_inconnue_ignoree(self, rules):
        """Un prefixe inattendu ne doit pas ecraser le niveau de DCS."""
        assert une(rules, HEAD + "VEAF|X|42: x").level == "INFO"

    def test_niveau_dcs_conserve_hors_script(self, rules):
        entry = une(
            rules,
            "2026-08-31 11:50:40.872 ERROR   APP (Main): Error: Unit [F-14B]: Corrupt damage model.",
        )
        assert entry.level == "ERROR"


class TestBruit:
    @pytest.mark.parametrize(
        "ligne,famille",
        [
            ("ERROR   APP (Main): Error: Unit [F-14B]: Corrupt damage model.", "damage_model"),
            ("ALERT   APP (Main): MiG-21PD MISMATCH DESCRIPTOR TYPE !!!!", "invalid_unit_module"),
            ('ERROR   wInfo (Main): negative weight of payload "{X}"', "payload_weight"),
            ('ERROR   wInfo (Main): negative drag of payload "{X}"', "payload_weight"),
            ("WARNING LOG (27444): 16 duplicate message(s) skipped.", "duplicate_skipped"),
            ("ERROR   DX11BACKEND (1): Unknown DLSS preset 'L'", "dlss_preset"),
            ("WARNING FLIGHT (Main): No taxiroad found on Batumi from 1 to 2", "taxiroad"),
            ("WARNING SECURITYCONTROL (Main): IC fail: /textures/x", "ic_fail"),
            ("WARNING SCENE (Main): Scene was removed with 4 alive objects", "scene_alive"),
            ("WARNING EDTERRAIN4 (1): Removed degenerate triangle in collision 'x'", "degenerate_triangle"),
            ("ERROR_ONCE DX11BACKEND (1): render target 'uiTargetDepth' not found", "render_target"),
            ("WARNING GRAPHICSCORE (Main): already registered Renderer callback", "renderer_callback"),
            ("WARNING WORLD (Main): ModelTimeQuantizer: ANTIFREEZE ENABLED", "antifreeze"),
            ("WARNING EDCORE (Main): hypervisor is active", "hypervisor"),
        ],
    )
    def test_famille_reconnue(self, rules, ligne, famille):
        store = indexer(rules, f"2026-08-31 11:50:40.872 {ligne}")
        assert famille in store.noise_of(0)

    def test_ligne_utile_jamais_marquee(self, rules):
        store = indexer(
            rules,
            "2026-08-31 11:55:01.930 ERROR   SCRIPTING (Main): Mission script error: "
            "[string \"l10n/DEFAULT/CSAR.lua\"]:2213: attempt to call field 'x'",
        )
        assert store.noise_of(0) == (), "une vraie erreur de script n'est pas du bruit"

    def test_famille_ancree_sur_le_message(self, rules):
        """`verbose_veaf_debug` porte sur le message, pas sur la ligne entiere."""
        store = indexer(rules, HEAD + "VEAF-SHORTCUTS|D|42: bla")
        assert "verbose_veaf_debug" in store.noise_of(0)

    def test_bruit_d_une_continuation_remonte(self, rules):
        """Le bruit trouve dans une suite marque l'entree qui la porte."""
        store = indexer(
            rules,
            "2026-08-31 11:50:00.000 INFO    DCS (Main): CPU info:",
            "hypervisor is active",
        )
        assert len(store) == 1
        assert "hypervisor" in store.noise_of(0)

    def test_familles_masquees_par_defaut(self, rules):
        hidden = rules.default_hidden_noise()
        assert "damage_model" in hidden
        assert "verbose_veaf_debug" not in hidden, "les traces VEAF restent visibles"


class TestCatalogue:
    def test_charge(self, rules):
        assert rules.sources and rules.noise and rules.levels

    def test_niveaux_ordonnes(self, rules):
        assert rules.level_order("ERROR") < rules.level_order("INFO")

    def test_couleurs(self, rules):
        assert rules.source_color("veaf").startswith("#")
        assert rules.source_color("inconnue") == "#8b949e"

    def test_libelles_de_source(self, rules):
        labels = rules.source_labels()
        assert labels["veaf"] == "VEAF"
        assert labels["dcs"] == "DCS"

    def test_style_de_niveau_inconnu(self, rules):
        assert rules.level_style("PAS_UN_NIVEAU").color.startswith("#")


class TestSousSysteme:
    """Le sous-systeme est releve meme quand la source affichee est un script."""

    def test_script_reconnu_garde_son_sous_systeme(self, rules):
        entry = une(rules, HEAD + "VEAF|I|1: x")
        assert entry.subsystem == "SCRIPTING"
        assert entry.source_label == "VEAF", "la colonne Source montre le script"

    def test_ligne_native(self, rules):
        entry = une(rules, "2026-08-31 11:50:00.000 ERROR   EDCORE (Main): boum")
        assert entry.subsystem == "EDCORE"
        assert entry.source_label == "EDCORE"
