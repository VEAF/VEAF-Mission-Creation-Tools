"""MODULES-UNIFY — the unified ``modules:`` block is the single source of truth.

SKYNET / CTLD / CSAR / QRA carry their config nested under their ``modules:``
entry; ``_normalize_mission_yaml`` translates that into the generator's internal
``external_modules`` / ``qra`` representation. There is no top-level
``external_modules:`` / ``qra:`` any more.
"""

from __future__ import annotations

from mission_builder.mission_builder_worker import _normalize_mission_yaml


class TestSkynetTranslation:
    def test_nested_skynet_config_maps_to_external_modules(self) -> None:
        result = _normalize_mission_yaml(
            {"modules": {"SKYNET": {"enabled": True, "include_red_in_radio": True, "debug_red": True}}}
        )
        assert result["external_modules"]["skynet"] == {
            "enabled": True,
            "include_red_in_radio": True,
            "debug_red": True,
        }

    def test_shorthand_true_enables_skynet(self) -> None:
        result = _normalize_mission_yaml({"modules": {"SKYNET": True}})
        assert result["external_modules"]["skynet"] == {"enabled": True}

    def test_shorthand_false_disables_skynet(self) -> None:
        result = _normalize_mission_yaml({"modules": {"SKYNET": False}})
        assert result["external_modules"]["skynet"] == {"enabled": False}


class TestCtldCsarTranslation:
    def test_ctld_settings_subblock_is_flattened(self) -> None:
        result = _normalize_mission_yaml(
            {"modules": {"CTLD": {"enabled": True, "settings": {"hoverPickup": True, "maximumDistanceLimit": 200}}}}
        )
        assert result["external_modules"]["ctld"] == {
            "enabled": True,
            "hoverPickup": True,
            "maximumDistanceLimit": 200,
        }

    def test_csar_without_settings(self) -> None:
        result = _normalize_mission_yaml({"modules": {"CSAR": {"enabled": True}}})
        assert result["external_modules"]["csar"] == {"enabled": True}


class TestQraTranslation:
    def test_qra_config_maps_to_qra_section(self) -> None:
        definitions = [{"name": "Base QRA", "coalition": "RED"}]
        result = _normalize_mission_yaml(
            {"modules": {"QRA": {"enabled": True, "silence_all": True, "definitions": definitions}}}
        )
        assert result["qra"] == {"silence_all": True, "definitions": definitions}

    def test_qra_specific_keys_stripped_from_lua_module(self) -> None:
        result = _normalize_mission_yaml(
            {"modules": {"QRA": {"enabled": True, "silence_all": True, "definitions": []}}}
        )
        qra_mod = result["lua_modules"]["QRA"]
        assert "silence_all" not in qra_mod
        assert "definitions" not in qra_mod
        assert qra_mod == {"enabled": True}

    def test_no_qra_section_when_absent(self) -> None:
        result = _normalize_mission_yaml({"modules": {"RADIO": True}})
        assert "qra" not in result


class TestSplitStillWorks:
    def test_veaf_and_community_split_preserved(self) -> None:
        result = _normalize_mission_yaml({"modules": {"RADIO": True, "MIST": True, "CTLD": True}})
        assert "RADIO" in result["lua_modules"]
        assert "mist" in result["community_scripts"]
        assert "ctld" in result["community_scripts"]
