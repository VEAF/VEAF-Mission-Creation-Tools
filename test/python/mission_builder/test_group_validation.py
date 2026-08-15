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
        # ...and the raw (unprefixed) name is NOT collected (no double-collection).
        assert ("cap_missions", "CAP Group") not in decl
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


# ---------------------------------------------------------------------------
# FEAT-BUILD-VALIDATE-REFS — trigger-zone / unit / airfield / sub-zone refs
# ---------------------------------------------------------------------------
from mission_builder.group_validation import (  # noqa: E402
    LEVEL_ERROR,
    LEVEL_WARNING,
    collect_mission_unit_names,
    collect_mission_zone_names,
    find_missing_sanctuary_units,
    find_missing_trigger_zone_refs,
    find_undeclared_operation_subzones,
    find_unknown_airport_links,
)


def _zones(*names: str) -> dict:
    """Build a mission_content with the given trigger-zone names."""
    return {"triggers": {"zones": [{"name": n} for n in names]}}


def _units(*names: str) -> dict:
    """Build a mission_content with the given unit names (one group, all units)."""
    return {
        "coalition": {
            "blue": {"country": [{"name": "USA", "vehicle": {"group": [{"units": [{"name": n} for n in names]}]}}]}
        }
    }


class TestCollectZoneAndUnitNames:
    def test_zone_names_from_list(self) -> None:
        assert collect_mission_zone_names(_zones("Z1", "Z2")) == {"Z1", "Z2"}

    def test_zone_names_from_dict(self) -> None:
        content = {"triggers": {"zones": {"1": {"name": "Za"}, "2": {"name": "Zb"}}}}
        assert collect_mission_zone_names(content) == {"Za", "Zb"}

    def test_zone_names_empty(self) -> None:
        assert collect_mission_zone_names({}) == set()

    def test_unit_names(self) -> None:
        assert collect_mission_unit_names(_units("Tank-1", "Tank-2")) == {"Tank-1", "Tank-2"}


class TestTriggerZoneRefs:
    def test_airwave_missing_with_fallback_is_warning(self) -> None:
        my = {
            "modules": {
                "AIRWAVES": {
                    "airwave_zones": [
                        {"name": "Z01", "trigger_zone_name": "AW-1", "zone_center_coordinates": "U37", "zone_radius": 9}
                    ]
                }
            }
        }
        assert find_missing_trigger_zone_refs(my, _zones()) == [("AIRWAVES", "AW-1", LEVEL_WARNING)]

    def test_airwave_missing_without_fallback_is_error(self) -> None:
        my = {"modules": {"AIRWAVES": {"airwave_zones": [{"name": "Z01", "trigger_zone_name": "AW-1"}]}}}
        assert find_missing_trigger_zone_refs(my, _zones()) == [("AIRWAVES", "AW-1", LEVEL_ERROR)]

    def test_airwave_present_is_clear(self) -> None:
        my = {"modules": {"AIRWAVES": {"airwave_zones": [{"trigger_zone_name": "AW-1"}]}}}
        assert find_missing_trigger_zone_refs(my, _zones("AW-1")) == []

    def test_qra_trigger_zone_missing_is_error(self) -> None:
        my = {"modules": {"QRA": {"definitions": [{"trigger_zone": "QRA zone"}]}}}
        assert find_missing_trigger_zone_refs(my, _zones()) == [("QRA", "QRA zone", LEVEL_ERROR)]

    def test_combatzone_missing_is_error_but_operation_is_not_checked(self) -> None:
        # A plain combat zone needs its trigger zone (VeafCombatZone:initialize errors
        # without it); an operation's zone_name is just a label — never validated.
        my = {
            "modules": {
                "COMBATZONE": {
                    "combat_zones": [
                        {"type": "zone", "zone_name": "subCombatZone_gori"},
                        {"type": "operation", "zone_name": "goriOperation"},
                    ]
                }
            }
        }
        issues = find_missing_trigger_zone_refs(my, _zones())
        assert issues == [("COMBATZONE", "subCombatZone_gori", LEVEL_ERROR)]
        assert all(ref != "goriOperation" for _, ref, _ in issues)

    def test_disabled_module_is_skipped(self) -> None:
        my = {"modules": {"QRA": {"enabled": False, "definitions": [{"trigger_zone": "Z"}]}}}
        assert find_missing_trigger_zone_refs(my, _zones()) == []


class TestSanctuaryUnits:
    def test_missing_polygon_unit_is_error(self) -> None:
        my = {"modules": {"SANCTUARY": {"sanctuary_zones": [{"name": "S", "polygon_units": ["U1", "U2"]}]}}}
        issues = find_missing_sanctuary_units(my, _units("U1"))
        assert issues == [("SANCTUARY", "U2", LEVEL_ERROR)]

    def test_all_present_is_clear(self) -> None:
        my = {"modules": {"SANCTUARY": {"sanctuary_zones": [{"polygon_units": ["U1"]}]}}}
        assert find_missing_sanctuary_units(my, _units("U1")) == []

    def test_a_group_name_is_accepted_like_the_runtime(self) -> None:
        # The runtime resolves each polygon name with Unit.getByName then Group.getByName:getUnit(1),
        # so a group name is valid even when its unit is named differently — the demo's
        # 'Sanctuary_Kutaisi_Polygon #001' group holds a unit 'Ground-1-1'. A unit-names-only check
        # flagged 16 working references as errors (MIGRATE-DEMO-MISSION-V6 ticket 02).
        content = {
            "coalition": {
                "blue": {
                    "country": [
                        {
                            "name": "USA",
                            "vehicle": {"group": [{"name": "Sanctuary_Poly #001", "units": [{"name": "Ground-1-1"}]}]},
                        }
                    ]
                }
            }
        }
        my = {"modules": {"SANCTUARY": {"sanctuary_zones": [{"polygon_units": ["Sanctuary_Poly #001"]}]}}}
        assert find_missing_sanctuary_units(my, content) == []


class TestAirportLinks:
    def test_unknown_airfield_is_error(self, monkeypatch) -> None:
        monkeypatch.setattr("veaf_libs.dcs_airdromes.airdromes_for_theatre", lambda t: {"batumi": 22})
        my = {"modules": {"QRA": {"definitions": [{"airport_link": "Nowhere"}]}}}
        assert find_unknown_airport_links(my, "Caucasus") == [("QRA.airport_link", "Nowhere", LEVEL_ERROR)]

    def test_known_airfield_is_clear(self, monkeypatch) -> None:
        monkeypatch.setattr("veaf_libs.dcs_airdromes.airdromes_for_theatre", lambda t: {"batumi": 22})
        my = {"modules": {"QRA": {"definitions": [{"airport_link": "Batumi"}]}}}
        assert find_unknown_airport_links(my, "Caucasus") == []

    def test_uncovered_theatre_is_skipped(self, monkeypatch) -> None:
        monkeypatch.setattr("veaf_libs.dcs_airdromes.airdromes_for_theatre", lambda t: {})
        my = {"modules": {"QRA": {"definitions": [{"airport_link": "Anything"}]}}}
        assert find_unknown_airport_links(my, "UnknownMap") == []

    def test_no_theatre_is_skipped(self) -> None:
        my = {"modules": {"QRA": {"definitions": [{"airport_link": "Batumi"}]}}}
        assert find_unknown_airport_links(my, None) == []


class TestOperationSubzones:
    def test_undeclared_subzone_and_dependency_are_errors(self) -> None:
        my = {
            "modules": {
                "COMBATZONE": {
                    "combat_zones": [
                        {"type": "zone", "zone_name": "subCombatZone_gori"},
                        {
                            "type": "operation",
                            "zone_name": "goriOperation",
                            "tasking_orders": [
                                {"zone_name": "subCombatZone_gori", "dependencies": ["subCombatZone_ghost"]},
                                {"zone_name": "subCombatZone_unknown"},
                            ],
                        },
                    ]
                }
            }
        }
        refs = [r for _, r, _ in find_undeclared_operation_subzones(my)]
        assert "subCombatZone_ghost" in refs
        assert "subCombatZone_unknown" in refs
        assert "subCombatZone_gori" not in refs  # declared → ok

    def test_all_declared_is_clear(self) -> None:
        my = {
            "modules": {
                "COMBATZONE": {
                    "combat_zones": [
                        {"type": "zone", "zone_name": "A"},
                        {"type": "operation", "zone_name": "Op", "tasking_orders": [{"zone_name": "A"}]},
                    ]
                }
            }
        }
        assert find_undeclared_operation_subzones(my) == []
