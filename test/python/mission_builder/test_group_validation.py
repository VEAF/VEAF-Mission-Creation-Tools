"""Build-time validation of config-declared groups (IMC2-004 / IMC2-004b)."""

from __future__ import annotations

from mission_builder.group_validation import (
    collect_declared_groups,
    collect_mission_group_names,
    find_missing_declared_groups,
)


def _mission(*group_names: str) -> dict:
    """Build a minimal mission_content with the given plane/helicopter group names."""
    return {
        "coalition": {
            "blue": {
                "country": [
                    {
                        "name": "USA",
                        "plane": {"group": [{"name": n} for n in group_names]},
                        "helicopter": {"group": []},
                    }
                ]
            }
        }
    }


class TestCollectMissionGroupNames:
    def test_collects_all_categories(self) -> None:
        content = {
            "coalition": {
                "red": {
                    "country": [
                        {
                            "name": "Russia",
                            "plane": {"group": [{"name": "Viper"}]},
                            "helicopter": {"group": [{"name": "Hip"}]},
                            "vehicle": {"group": [{"name": "Convoy"}]},
                            "ship": {"group": [{"name": "Carrier"}]},
                            "static": {"group": [{"name": "Depot"}]},
                        }
                    ]
                }
            }
        }
        assert collect_mission_group_names(content) == {"Viper", "Hip", "Convoy", "Carrier", "Depot"}

    def test_empty_mission(self) -> None:
        assert collect_mission_group_names({}) == set()


class TestCollectDeclaredGroups:
    def test_assets_name_and_linked(self) -> None:
        my = {"modules": {"ASSETS": {"enabled": True, "assets": [{"name": "Arco-1", "linked": ["Escort-1"]}]}}}
        assert ("ASSETS", "Arco-1") in collect_declared_groups(my)
        assert ("ASSETS.linked", "Escort-1") in collect_declared_groups(my)

    def test_qra_groups(self) -> None:
        my = {
            "modules": {
                "QRA": {
                    "enabled": True,
                    "definitions": [{"groups_by_enemy_count": [{"enemy_count": 1, "groups": ["MiG-29 QRA"]}]}],
                }
            }
        }
        assert ("QRA", "MiG-29 QRA") in collect_declared_groups(my)

    def test_cap_and_combat_missions(self) -> None:
        my = {
            "cap_missions": [{"group_name": "CAP Group"}],
            "combat_missions": [{"elements": [{"groups": ["Strike-1", "Strike-2"]}]}],
        }
        decl = collect_declared_groups(my)
        # cap_missions: the Lua addCapMission prefixes "OnDemand-" to the group name.
        assert ("cap_missions", "OnDemand-CAP Group") in decl
        # combat_missions: no prefix — groups referenced verbatim.
        assert ("combat_missions", "Strike-1") in decl
        assert ("combat_missions", "Strike-2") in decl

    def test_disabled_module_skipped(self) -> None:
        my = {"modules": {"ASSETS": {"enabled": False, "assets": [{"name": "Arco-1"}]}}}
        assert collect_declared_groups(my) == []


class TestFindMissingDeclaredGroups:
    def test_present_group_not_flagged(self) -> None:
        my = {"modules": {"ASSETS": {"enabled": True, "assets": [{"name": "Arco-1"}]}}}
        assert find_missing_declared_groups(my, _mission("Arco-1")) == []

    def test_missing_group_flagged(self) -> None:
        my = {"modules": {"ASSETS": {"enabled": True, "assets": [{"name": "Arco-1"}]}}}
        assert find_missing_declared_groups(my, _mission("OtherGroup")) == [("ASSETS", "Arco-1")]

    def test_cap_mission_matches_ondemand_prefixed_group(self) -> None:
        # FIX: addCapMission prefixes "OnDemand-", so cap_missions group_name "X"
        # matches a mission group named "OnDemand-X" (the maker's template), not "X".
        my = {"cap_missions": [{"group_name": "CAP-Maykop-1"}]}
        # template present under the OnDemand- name → no false warning
        assert find_missing_declared_groups(my, _mission("OnDemand-CAP-Maykop-1")) == []
        # genuinely absent → still flagged (under the OnDemand- name)
        assert find_missing_declared_groups(my, _mission("Else")) == [("cap_missions", "OnDemand-CAP-Maykop-1")]

    def test_deduplicates(self) -> None:
        my = {
            "cap_missions": [{"group_name": "Ghost"}],
            "combat_missions": [{"elements": [{"groups": ["Ghost"]}]}],
        }
        missing = find_missing_declared_groups(my, _mission())
        # "Ghost" referenced twice (different sections) → reported once
        assert [g for _, g in missing].count("Ghost") == 1
