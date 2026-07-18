"""Tests for the wave-5 domain-knowledge oracle (introspection actions)."""

from pathlib import Path

from veaf_mission_mcp.oracle import (
    _command_category,
    describe_module,
    describe_naming_conventions,
    list_shortcuts,
    list_unit_types,
)


def test_list_unit_types_returns_dcs_units_from_canonical_data() -> None:
    units = list_unit_types()["units"]
    assert units, "expected a non-empty DCS unit list from the bundled dcsUnits.yaml"
    sample = units[0]
    assert sample["type"] and "category" in sample


def test_list_unit_types_filters_by_category() -> None:
    all_units = list_unit_types()["units"]
    category = all_units[0]["category"]
    filtered = list_unit_types(category=category)["units"]
    assert filtered
    assert all(u["category"] == category for u in filtered)


def test_list_unit_types_filters_by_name_substring() -> None:
    all_units = list_unit_types()["units"]
    needle = all_units[0]["type"][:3].lower()
    filtered = list_unit_types(name_contains=needle)["units"]
    assert filtered
    assert all(needle in (u["type"] + u["name"]).lower() for u in filtered)


def test_list_shortcuts_includes_known_unit_alias() -> None:
    shortcuts = list_shortcuts()
    assert any("shilka" in entry["aliases"] for entry in shortcuts["units"])


def test_list_shortcuts_includes_composite_groups() -> None:
    assert list_shortcuts()["groups"], "expected composite spawn groups from veaf-units.yaml"


def test_list_shortcuts_filters_by_substring() -> None:
    filtered = list_shortcuts(name_contains="shilka")
    assert any("shilka" in e["aliases"] for e in filtered["units"])
    assert all(
        "shilka" in " ".join(e["aliases"]).lower() or "shilka" in e["unitType"].lower() for e in filtered["units"]
    )


def test_list_shortcuts_includes_command_aliases() -> None:
    # The #command shortcuts from veafShortcuts.buildDefaultList() (regression: the LLM
    # invented `-lrsam` because the real `-samLR` was invisible to the oracle).
    names = [alias for entry in list_shortcuts()["commands"] for alias in entry["aliases"]]
    assert "-samLR" in names
    assert "-samSR" in names


def test_list_shortcuts_commands_filtered_by_substring() -> None:
    filtered = list_shortcuts(name_contains="samLR")
    names = [alias for entry in filtered["commands"] for alias in entry["aliases"]]
    assert "-samLR" in names
    assert "-samSR" not in names  # filtered out


def test_list_shortcuts_command_entries_have_shape() -> None:
    commands = list_shortcuts()["commands"]
    assert commands
    entry = commands[0]
    assert "aliases" in entry and "description" in entry and "veafCommand" in entry


def test_describe_naming_conventions_lists_the_reserved_patterns() -> None:
    conventions = describe_naming_conventions()["conventions"]
    assert len(conventions) >= 8
    ids = {c["id"] for c in conventions}
    assert "combat_zone_membership" in ids
    assert "spawn_template" in ids
    for convention in conventions:
        assert convention["rule"] and convention["module"]


def test_describe_module_known_returns_doc_page() -> None:
    result = describe_module("QRA")
    assert result["known"] is True
    assert result["doc_page"].endswith(".md")


def test_describe_module_is_case_insensitive() -> None:
    assert describe_module("qra")["known"] is True


def test_describe_module_unknown() -> None:
    assert describe_module("NOSUCHMODULE")["known"] is False


def test_describe_module_reports_enabled_from_mission_yaml(tmp_path: Path) -> None:
    path = tmp_path / "mission.yaml"
    path.write_text("modules:\n  QRA: true\n  COMBATZONE: false\n", encoding="utf-8")
    assert describe_module("QRA", mission_yaml_path=path)["enabled"] is True
    assert describe_module("COMBATZONE", mission_yaml_path=path)["enabled"] is False


def test_command_category_classifies_known_families() -> None:
    assert _command_category(["-samLR"], "Random long range SAM battery") == "SAM"
    assert _command_category(["-aaa"], "Random AAA battery") == "AAA"
    assert _command_category(["-infantry"], "Dynamic infantry section") == "infantry"
    assert _command_category(["-armor"], "Random armor group") == "armor"
    assert _command_category(["-mortar"], "Mortar artillery team") == "artillery"


def test_command_category_falls_back_to_other() -> None:
    assert _command_category(["-zzz"], "something with no known family") == "other"


def test_list_shortcuts_commands_carry_a_category() -> None:
    commands = list_shortcuts()["commands"]
    assert commands, "expected a non-empty command alias list"
    assert all("category" in c for c in commands)
