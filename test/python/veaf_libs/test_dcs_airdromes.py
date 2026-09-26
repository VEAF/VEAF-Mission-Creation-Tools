"""Tests for the airdrome name->id resolver (reads the committed airdromes.yaml)."""

from __future__ import annotations

from veaf_libs import dcs_airdromes


def setup_function() -> None:
    # The table is lru_cached; clear it so each test reads fresh.
    dcs_airdromes._table.cache_clear()


def test_resolves_known_airfield() -> None:
    assert dcs_airdromes.airdrome_id_for_name("Caucasus", "Batumi") == 22


def test_case_insensitive() -> None:
    assert dcs_airdromes.airdrome_id_for_name("caucasus", "batumi") == 22


def test_unknown_name_returns_none() -> None:
    assert dcs_airdromes.airdrome_id_for_name("Caucasus", "Nowhere") is None


def test_unknown_theatre_returns_none() -> None:
    assert dcs_airdromes.airdrome_id_for_name("Atlantis", "Batumi") is None


def test_empty_args_return_none() -> None:
    assert dcs_airdromes.airdrome_id_for_name("", "Batumi") is None
    assert dcs_airdromes.airdrome_id_for_name("Caucasus", "") is None


def test_airdromes_for_theatre_nonempty() -> None:
    caucasus = dcs_airdromes.airdromes_for_theatre("Caucasus")
    assert caucasus.get("batumi") == 22
    assert len(caucasus) > 10


def test_airdromes_for_unknown_theatre_empty() -> None:
    assert dcs_airdromes.airdromes_for_theatre("Atlantis") == {}


def test_airfields_for_theatre_carries_positions() -> None:
    """FIX-SCRATCH-MISSION-FINDINGS ticket 19: the positions come shipped, not from veaf_build."""
    ramstein = next(a for a in dcs_airdromes.airfields_for_theatre("germanycw") if a["name"] == "Ramstein")
    assert set(ramstein) == {"name", "id", "lat", "lon"}
    assert 49 < ramstein["lat"] < 50 and 7 < ramstein["lon"] < 8


def test_airfields_for_unknown_theatre_empty() -> None:
    assert dcs_airdromes.airfields_for_theatre("Atlantis") == []
