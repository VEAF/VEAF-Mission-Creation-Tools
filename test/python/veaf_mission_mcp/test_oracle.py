"""Tests for the wave-5 domain-knowledge oracle (introspection actions)."""

from pathlib import Path

from veaf_mission_mcp.oracle import (
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
        "shilka" in " ".join(e["aliases"]).lower() or "shilka" in e["unitType"].lower()
        for e in filtered["units"]
    )


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
