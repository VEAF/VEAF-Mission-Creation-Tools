"""The air-defense levels follow the mission's era (FIX-SCRATCH-MISSION-FINDINGS ticket 12).

``veafCasMission.generateAirDefenseGroup`` looks up ``generateAirDefenseGroup-<SIDE>-<ERA>-<N>`` first
and falls back to the generic ``generateAirDefenseGroup-<SIDE>-<N>``. These tests resolve every
(side, era, level) the way the runtime does and sweep what it would place: enumerated, not sampled, so
a later edit to a generic level cannot slip a 1990s launcher back into a 1980 mission unseen.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import pytest
import yaml
from spawn_data_injector.spawn_data_emitter import load_framework_spawn_data

SIDES = ("BLUE", "RED")
LEVELS = range(6)

# Types entering service after the COLD_WAR reference (around 1980, the armor tables' cut-off).
# Service dates are estimates, not sourced — the list David validated on 2026-09-24.
AFTER_1980 = {
    "M1097 Avenger",
    "M6 Linebacker",
    "Tor 9A331",
    "2S6 Tunguska",
    "HQ-7_LN_EO",
    "HQ-7_LN_SP",
    "SA-18 Igla-S comm",
    "SA-18 Igla-S manpad",
}

WW2_TYPES = {
    "M45_Quadmount",
    "M1_37mm",
    "bofors40",
    "QF_37_AA",
    "CCKW_353",
    "flak18",
    "flak30",
    "flak36",
    "flak37",
    "flak38",
    "flak41",
    "KDO_Mod40",
    "Flakscheinwerfer_37",
    "Maschinensatz_33",
    "Sd_Kfz_7",
    "Blitz_36-6700A",
}


@pytest.fixture(scope="module")
def groups() -> dict[str, dict[str, Any]]:
    return {alias: g for g in load_framework_spawn_data()["groups"] for alias in g["aliases"]}


def _resolve(groups: dict[str, dict[str, Any]], side: str, era: str, level: int) -> dict[str, Any]:
    return (
        groups.get(f"generateAirDefenseGroup-{side}-{era}-{level}") or groups[f"generateAirDefenseGroup-{side}-{level}"]
    )


def _types(group: dict[str, Any]) -> set[str]:
    return {unit["type"] for unit in group["units"]}


@pytest.mark.parametrize("side", SIDES)
@pytest.mark.parametrize("level", LEVELS)
def test_a_cold_war_level_places_nothing_from_after_1980(groups: dict, side: str, level: int) -> None:
    assert _types(_resolve(groups, side, "COLD_WAR", level)) & AFTER_1980 == set()


@pytest.mark.parametrize("side", SIDES)
@pytest.mark.parametrize("level", LEVELS)
def test_a_ww2_level_places_flak_only(groups: dict, side: str, level: int) -> None:
    # its own variant, never the modern fallback
    assert f"generateAirDefenseGroup-{side}-WW2-{level}" in groups
    assert _types(_resolve(groups, side, "WW2", level)) <= WW2_TYPES


def test_the_modern_levels_are_unchanged(groups: dict) -> None:
    """MODERN has no variant: it is the generic level, which a mission may already override."""
    assert not [alias for alias in groups if "-MODERN-" in alias]
    assert "M6 Linebacker" in _types(_resolve(groups, "BLUE", "MODERN", 3))


def test_every_era_variant_type_is_known_to_dcs(groups: dict) -> None:
    root = Path(__file__).parents[3]
    dcs = yaml.safe_load((root / "src/python/veaf-tools/veaf_libs/data/dcsUnits.yaml").read_text(encoding="utf-8"))
    known = {entry["type"] for entry in dcs["units"]}
    variants = [g for alias, g in groups.items() if "-COLD_WAR-" in alias or "-WW2-" in alias]
    assert len(variants) == 16
    unknown = {t for g in variants for t in _types(g)} - known
    assert unknown == set()


def _long_range_aliases() -> set[str]:
    """Every group alias named in veafCasMission.LONG_RANGE_AIR_DEFENSE_GROUPS, read from the Lua source."""
    root = Path(__file__).parents[3]
    source = (root / "src/scripts/veaf/veafCasMission.lua").read_text(encoding="utf-8")
    start = source.index("veafCasMission.LONG_RANGE_AIR_DEFENSE_GROUPS = {")
    block = source[start : source.index("\n}\n", start)]
    return set(re.findall(r'"([^"]+)"', block))


def test_every_long_range_battery_the_runtime_draws_exists(groups: dict) -> None:
    aliases = _long_range_aliases()
    assert {"patriot", "hawk", "sa2", "sa5", "sa10"} <= aliases
    assert aliases - set(groups) == set()


def test_the_patriot_battery_is_a_whole_fire_unit(groups: dict) -> None:
    r"""The template `-samVLR` draws for a modern blue side (in veaf-units.yaml since 2019). The core
    measured on the 159 Patriot groups of the .miz under D:\dev\_VEAF on 2026-09-24: STR, ECS, CP
    and AMG, most often with the EPP, and 4 to 7 launchers."""
    units = [u["type"] for u in groups["patriot"]["units"]]
    for core in ("Patriot str", "Patriot ECS", "Patriot EPP", "Patriot cp", "Patriot AMG"):
        assert units.count(core) == 1, core
    assert units.count("Patriot ln") >= 4
