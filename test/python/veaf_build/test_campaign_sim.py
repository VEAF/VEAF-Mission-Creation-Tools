"""The campaign economy simulator's fixtures follow their sources (FIX-CAMPAIGN-ECONOMY-BALANCE 04)."""

from __future__ import annotations

from veaf_build.campaign_sim import (
    CAMPAIGN_LUA,
    SPAWN_DATA_LUA,
    campaign_fixture_lua,
    spawn_data_fixture_lua,
)

_REFRESH = "stale: run `poetry run campaign-sim fixtures` and commit the result"


def test_the_campaign_fixture_is_its_yaml() -> None:
    assert CAMPAIGN_LUA.read_text(encoding="utf-8") == campaign_fixture_lua(), _REFRESH


def test_the_spawn_data_fixture_is_the_framework_s() -> None:
    assert SPAWN_DATA_LUA.read_text(encoding="utf-8") == spawn_data_fixture_lua(), _REFRESH


def test_the_campaign_fixture_places_every_airbase() -> None:
    text = campaign_fixture_lua()
    for airbase in ("Incirlik", "Taftanaz", "Aleppo", "Hama"):
        assert f'["{airbase}"]={{["lat"]=' in text, airbase
