"""Tests des formats d'en-tete autres que DCS.

Les lignes viennent des journaux du serveur dcs.veaf.org releves le 2026-09-29
(DCSServerBot, Real Weather, LotAtc), noms de joueurs et adresses retires. Elles
passent par `LogStore`, le chemin reellement emprunte par l'application.
"""

from __future__ import annotations

import pytest
from veaf_logs.buffer import BytesBuffer
from veaf_logs.catalogue import uncatalogued_entries
from veaf_logs.excerpt import build_excerpt
from veaf_logs.filters import FilterSet
from veaf_logs.store import LogStore

SERVER = "VEAF (www.veaf.org) [fr] - Public 1"


def indexer(rules, *lignes) -> LogStore:
    data = ("\n".join(lignes) + "\n").encode("utf-8")
    store = LogStore(rules, BytesBuffer(data))
    store.index_new()
    return store


def une(rules, ligne):
    store = indexer(rules, ligne)
    assert len(store) == 1, f"attendu 1 entree, obtenu {len(store)}"
    return store.entry(0)


class TestDcsServerBot:
    def test_ligne_principale(self, rules):
        entry = une(rules, "2026-09-29 18:02:44.490 WARNING\tNew update for DCSServerBot available!")
        assert entry.timestamp == "2026-09-29 18:02:44.490"
        assert entry.time_only == "18:02:44.490"
        assert entry.level == "WARNING"
        assert entry.source == "dcssb"
        assert entry.source_label == "DCSSB"
        assert entry.message == "New update for DCSServerBot available!"

    def test_journal_de_performances(self, rules):
        """Virgule avant les millisecondes, tabulation avant le niveau."""
        entry = une(rules, "2026-09-29 18:03:38,541\tINFO\t4.80s\tServerImpl.apply_mission_changes()")
        assert entry.timestamp == "2026-09-29 18:03:38.541"
        assert entry.level == "INFO"
        assert entry.source == "dcssb"
        assert entry.message == "4.80s\tServerImpl.apply_mission_changes()"

    def test_critical_est_une_alerte(self, rules):
        assert une(rules, "2026-09-29 18:02:44.490 CRITICAL\tboom").level == "ALERT"

    def test_prefixes_des_scripts_ignores(self, rules):
        """« SRS: » ne designe le script SRS que dans dcs.log."""
        entry = une(rules, "2026-09-29 18:04:38.123 DEBUG\tSRS: is NOT running (process)")
        assert entry.source == "dcssb"

    def test_chaque_ligne_est_une_entree(self, rules):
        """Le defaut d'origine : tout le fichier tenait en une seule entree."""
        store = indexer(
            rules,
            "2026-09-29 18:02:42.798 INFO\tDCSServerBot v3.0.4.22 starting up ...",
            "2026-09-29 18:02:44.490 WARNING\tNew update for DCSServerBot available!",
            "Use /node upgrade or enable autoupdate to apply it.",
            f"2026-09-29 18:09:52.501 DEBUG\tHOST->{SERVER}: " + '{"command": "getMissionUpdate"}',
        )
        assert len(store) == 3
        assert store.entry(1).continuations == ["Use /node upgrade or enable autoupdate to apply it."]

    def test_exceptions_asynchrones(self, rules):
        store = indexer(
            rules,
            "2026-05-26T00:47:56.023909: Task exception was never retrieved",
            "Traceback (most recent call last):",
            "TimeoutError",
            "==================================================",
            "2026-05-26T07:33:56.307607: Task exception was never retrieved",
        )
        assert len(store) == 2
        premiere = store.entry(0)
        assert premiere.level == "ERROR"
        assert premiere.source == "dcssb"
        assert premiere.time_only == "00:47:56.023909"
        assert premiere.continuations[:2] == ["Traceback (most recent call last):", "TimeoutError"]


class TestRealWeather:
    @pytest.mark.parametrize(
        "ecrit,niveau",
        [("INFO", "INFO"), ("WARN", "WARNING"), ("ERROR", "ERROR"), ("FATAL", "ALERT"), ("PANIC", "ALERT")],
    )
    def test_niveaux(self, rules, ecrit, niveau):
        entry = une(rules, f"2026-09-29T20:04:38.522+0200\t{ecrit}\tno weather data received")
        assert entry.level == niveau

    def test_ligne(self, rules):
        entry = une(rules, "2026-09-29T20:03:44.385+0200\tWARN\tno suitable weather preset for code=FEW and base=6561")
        assert entry.timestamp == "2026-09-29 20:03:44.385"
        assert entry.source == "realweather"
        assert entry.source_label == "Real Weather"
        assert entry.message.startswith("no suitable weather preset")

    def test_recopie_dans_le_journal_du_bot(self, rules):
        """Deux formats dans un meme fichier : la detection se fait ligne a ligne."""
        store = indexer(
            rules,
            "2026-09-29 18:04:38.647 ERROR\tError during RealWeather: 1 - 2026-09-29T20:04:38.169+0200"
            "\tINFO\tusing real weather v2.5.0",
            "2026-09-29T20:04:38.522+0200\tERROR\terror validating weather: no data to check",
            "2026-09-29T20:04:38.522+0200\tFATAL\tno weather data received",
        )
        assert [store.source_of(i) for i in range(len(store))] == ["dcssb", "realweather", "realweather"]
        assert [store.level_of(i) for i in range(len(store))] == ["ERROR", "ERROR", "ALERT"]


class TestLotAtc:
    def test_ligne(self, rules):
        entry = une(rules, "[2026-09-29 20:05:21 +02:00] [W] [clienthandler] Client deleted")
        assert entry.timestamp == "2026-09-29 20:05:21"
        assert entry.level == "WARNING"
        assert entry.source == "lotatc"
        assert entry.subsystem == "clienthandler"
        assert entry.message == "[clienthandler] Client deleted", "le composant donne son sens au message"

    def test_sans_composant(self, rules):
        entry = une(rules, "[2026-07-23 22:00:55 +02:00] [I] --------------------")
        assert entry.level == "INFO"
        assert entry.subsystem == ""
        assert entry.message == "--------------------"


class TestJournalDeScript:
    def test_horodatage_vide(self, rules):
        entry = une(rules, "[]  INFO    SCRIPTING: VEAF - I - ACTION  - Initializing module")
        assert entry.level == "INFO"
        assert entry.subsystem == "SCRIPTING"
        assert entry.timestamp == ""
        assert entry.message == "VEAF - I - ACTION  - Initializing module"


class TestFormatInconnu:
    def test_lu_ligne_a_ligne(self, rules):
        """Un fichier que rien ne reconnait ne se replie pas en une entree."""
        store = indexer(
            rules,
            'mission_file_path\t=\t"C:\\\\Missions\\\\VEAF_OpenTraining_Syria.miz"',
            'callsign\t=\t"<ME>"',
            "graveyard = \t{}",
        )
        assert len(store) == 3
        assert all(store.level_of(i) == "UNKNOWN" for i in range(3))

    def test_la_trace_reste_rattachee_a_son_erreur(self, rules):
        store = indexer(
            rules,
            "2026-08-31 11:50:46.140 ERROR   SCRIPTING (Main): Mission script error: [string]:12: attempt",
            "stack traceback:",
            "\t[C]: in function 'error'",
        )
        assert len(store) == 1
        assert len(store.entry(0).continuations) == 2

    def test_plus_de_suites_que_le_compteur_n_en_tient(self, rules):
        """L'async_errors.log de DCSServerBot en empilait 90 000 : l'indexation s'arretait."""
        store = indexer(
            rules,
            "2026-05-26T00:47:56.023909: Task exception was never retrieved",
            *(["  File x"] * 70_000),
        )
        assert len(store) == 2
        assert [store.level_of(i) for i in range(2)] == ["ERROR", "ERROR"], "la suite garde le niveau de l'erreur"
        assert store.source_of(1) == "dcssb"


class TestBruit:
    @pytest.mark.parametrize(
        "ligne,famille",
        [
            (
                f"2026-09-29 18:04:28.809 DEBUG\t{SERVER}->HOST: "
                '{"time": 0, "id": 58, "eventName": "S_EVENT_SIMULATION_UNFREEZE", "command": "onMissionEvent"}',
                "dcssb_mission_events",
            ),
            (
                f"2026-09-29 18:10:52.441 DEBUG\t{SERVER}->HOST: " + '{"command": "serverLoad", "cpu": 0.1}',
                "dcssb_polling",
            ),
            (
                f"2026-09-29 18:10:52.501 DEBUG\t{SERVER}->HOST: "
                '{"real_time": 410.7, "command": "getMissionUpdate", "pause": true}',
                "dcssb_polling",
            ),
            (f"2026-09-29 18:10:52.486 DEBUG\tHOST->{SERVER}: " + '{"command": "getMissionUpdate"}', "dcssb_polling"),
            (f"2026-09-29 18:09:52.973 DEBUG\tServer {SERVER} registered with the cloud.", "dcssb_polling"),
            ('[2026-07-23 21:25:24 +02:00] [I] [clientserver]   - "use_rcs" : "true"', "lotatc_config_dump"),
            (
                '[2026-09-29 20:05:13 +02:00] [I] [clientserver] Airport: 0 "North West Field" '
                "MapObject::COALITION_NEUTRAL",
                "lotatc_airports",
            ),
            ("[2026-09-29 20:05:21 +02:00] [W] [clienthandler] Init", "lotatc_client_cycle"),
            (
                '[2026-09-29 20:05:21 +02:00] [W] [clientserver] "[NetServerThread]" SOCKET ERROR '
                '"The remote host closed the connection"',
                "lotatc_client_cycle",
            ),
            (
                "[2026-09-29 20:05:21 +02:00] [I] [clientserver] [NetServer] Incoming connection  42",
                "lotatc_client_cycle",
            ),
        ],
    )
    def test_famille(self, rules, ligne, famille):
        assert famille in une(rules, ligne).noise

    @pytest.mark.parametrize(
        "ligne",
        [
            f"2026-09-29 18:09:52.501 DEBUG\tHOST->{SERVER}: " + '{"command": "ban", "ucid": "x"}',
            f"2026-09-29 18:09:52.501 DEBUG\tHOST->{SERVER}: " + '{"command": "loadParams"}',
            "[2026-07-23 22:00:55 +02:00] [W] [default] Error 415",
        ],
    )
    def test_ce_qui_reste_visible(self, rules, ligne):
        assert une(rules, ligne).noise == ()

    def test_une_famille_du_bot_ignore_dcs_log(self, rules):
        """`formats` borne la famille aux lignes de DCSServerBot, meme a texte identique."""
        ligne = "2026-08-31 11:50:46.140 INFO    SCRIPTING (Main): x->HOST: " + '{"command": "onMissionEvent"}'
        assert une(rules, ligne).noise == ()


class TestCommeAvant:
    """Ce que les journaux DCS faisaient deja et doivent continuer de faire."""

    def test_une_ligne_datee_hors_format_garde_son_heure(self, rules):
        entry = une(rules, "2026-01-16 10:37:11.100 bizarre sans parentheses")
        assert entry.level == "UNKNOWN"
        assert entry.timestamp == "2026-01-16 10:37:11.100"

    def test_ce_qui_suit_la_ligne_d_ouverture_s_y_rattache(self, rules):
        store = indexer(rules, "=== Log opened UTC 2026-08-31 11:49:46", "ligne sans en-tete")
        assert len(store) == 1
        assert store.level_of(0) == "INFO"


class TestCatalogue:
    def test_une_ligne_du_bot_reste_a_cataloguer(self, rules):
        """Connaitre l'emetteur d'un fichier ne dit rien d'une ligne : les propositions doivent la voir."""
        store = indexer(
            rules,
            "2026-09-29 18:04:01.673 ERROR	Sun never reaches 6 degrees below the horizon, at this location.",
            f"2026-09-29 18:09:52.441 DEBUG	{SERVER}->HOST: " + '{"command": "serverLoad", "cpu": 0.1}',
        )
        restantes = uncatalogued_entries(rules, build_excerpt(store, FilterSet()))
        assert [entry.message for entry in restantes] == [
            "Sun never reaches 6 degrees below the horizon, at this location."
        ]
