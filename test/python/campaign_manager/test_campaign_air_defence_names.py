"""A briefing names an air defence the way a pilot does, never by its template's alias (David, 2026-11-17)."""

from __future__ import annotations

from campaign_manager.air_defence_names import describe_garrison_entry
from veaf_libs.i18n import language


class TestTheNames:
    def test_a_named_system_with_its_reach(self) -> None:
        with language("fr"):
            assert describe_garrison_entry("hawk") == "Hawk (SAM moyenne portée)"
            assert describe_garrison_entry("avenger_squad") == "Avenger (SAM courte portée)"
            assert describe_garrison_entry("stinger_squad") == "Stinger (missiles portables)"
        with language("en"):
            assert describe_garrison_entry("hawk") == "Hawk (medium-range SAM)"

    def test_a_generated_defence_says_its_level_and_what_it_holds(self) -> None:
        with language("fr"):
            text = describe_garrison_entry("generateAirDefenseGroup-BLUE-3")
        assert text == "défense rapprochée de niveau 3 sur 5 (Gepard, Linebacker, Avenger)"
        with language("fr"):
            red = describe_garrison_entry("generateAirDefenseGroup-RED-5")
        assert red.startswith("défense rapprochée de niveau 5 sur 5 (")
        assert "SA-15" in red and "Ural" not in red and "Dog Ear" not in red

    def test_no_alias_and_no_dcs_type_left_in_what_it_says(self) -> None:
        with language("fr"):
            for entry in ("hawk", "avenger_squad", "stinger_squad", "generateAirDefenseGroup-RED-3", "sa10", "nasams"):
                text = describe_garrison_entry(entry)
                assert "_" not in text and "generateAirDefenseGroup" not in text, text

    def test_the_tor_m2_and_the_pantsir_by_their_names(self) -> None:
        """FEAT-CAMPAIGN-AIR-DEFENCE-VARIETY 01: the Currenthill pack's systems, as pilots call them."""
        with language("fr"):
            assert describe_garrison_entry("sa15m2_squad") == "SA-15 Tor M2 (SAM courte portée)"
            assert describe_garrison_entry("sa22_squad") == "SA-22 Pantsir (SAM courte portée)"

    def test_the_iris_t_and_the_rapier_by_their_names(self) -> None:
        """FEAT-CAMPAIGN-AIR-DEFENCE-VARIETY 03: blue's IRIS-T SLM and Rapier."""
        with language("fr"):
            assert describe_garrison_entry("iristslm") == "IRIS-T SLM (SAM moyenne portée)"
            assert describe_garrison_entry("iris-t") == "IRIS-T SLM (SAM moyenne portée)"
            assert describe_garrison_entry("rapier_radar") == "Rapier (SAM courte portée)"

    def test_an_entry_it_does_not_know_is_left_as_written(self) -> None:
        assert describe_garrison_entry("my-own-group") == "my-own-group"
