"""Tests for the wave-6 `add_group` naming intents."""

from pathlib import Path
from typing import Any

from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.add_group import add_group, resolve_group_name

_RED = {"coalition": "red", "country_id": 0, "country_name": "Russia", "category": "vehicle"}


def _values(node: Any) -> list[Any]:
    """DCS integer-keyed tables parse to lists; string-keyed ones to dicts."""
    if isinstance(node, dict):
        return list(node.values())
    if isinstance(node, list):
        return node
    return []


def _find_group(content: dict[str, Any], name: str) -> dict[str, Any] | None:
    for coalition in _values(content.get("coalition", {})):
        for country in _values(coalition.get("country", {})):
            for cat in (v for v in country.values() if isinstance(v, dict) and "group" in v):
                for group in _values(cat["group"]):
                    if isinstance(group, dict) and group.get("name") == name:
                        return group
    return None


# --- resolve_group_name (pure) -------------------------------------------------


def test_resolve_prefixes_combat_zone_name() -> None:
    assert resolve_group_name("armor", for_combat_zone="CZ-North") == "CZ-North-armor"


def test_resolve_combat_zone_is_idempotent() -> None:
    assert resolve_group_name("CZ-North-armor", for_combat_zone="CZ-North") == "CZ-North-armor"


def test_resolve_combat_zone_idempotent_is_case_insensitive() -> None:
    # combat-zone membership matches case-insensitively, so don't double-prefix
    assert resolve_group_name("cz-north-armor", for_combat_zone="CZ-North") == "cz-north-armor"


def test_resolve_spawn_template_prefix() -> None:
    assert resolve_group_name("Viper", as_spawn_template=True) == "veafSpawn-Viper"


def test_resolve_spawn_template_idempotent() -> None:
    assert resolve_group_name("veafSpawn-Viper", as_spawn_template=True) == "veafSpawn-Viper"


def test_resolve_no_intent_returns_name_unchanged() -> None:
    assert resolve_group_name("Plain Group") == "Plain Group"


# --- add_group integration -----------------------------------------------------


def test_add_group_for_combat_zone_names_and_returns_prefixed(sample_miz: Path) -> None:
    result = add_group(
        sample_miz,
        **_RED,
        name="armor",
        position={"x": 100.0, "y": 200.0},
        units=[{"type": "T-72B", "count": 2}],
        for_combat_zone="combatZone_Test",
    )
    assert result["name"] == "combatZone_Test-armor"
    group = _find_group(read_miz(sample_miz).mission_content or {}, "combatZone_Test-armor")
    assert group is not None


def test_add_group_late_activation_sets_flag(sample_miz: Path) -> None:
    add_group(
        sample_miz,
        **_RED,
        name="QRA Su-27",
        position={"x": 100.0, "y": 200.0},
        units=[{"type": "Su-27", "count": 1}],
        late_activation=True,
    )
    group = _find_group(read_miz(sample_miz).mission_content or {}, "QRA Su-27")
    assert group is not None
    assert group["lateActivation"] is True


def test_add_group_default_is_not_late_activation(sample_miz: Path) -> None:
    add_group(
        sample_miz,
        **_RED,
        name="Static Armor",
        position={"x": 100.0, "y": 200.0},
        units=[{"type": "T-72B", "count": 1}],
    )
    group = _find_group(read_miz(sample_miz).mission_content or {}, "Static Armor")
    assert group is not None
    assert group["lateActivation"] is False


def test_add_group_spawn_template_prefixes_name(sample_miz: Path) -> None:
    result = add_group(
        sample_miz,
        coalition="blue",
        country_id=2,
        country_name="USA",
        category="plane",
        name="Viper",
        position={"x": 100.0, "y": 200.0},
        units=[{"type": "F-16C_50", "count": 1}],
        as_spawn_template=True,
    )
    assert result["name"] == "veafSpawn-Viper"
