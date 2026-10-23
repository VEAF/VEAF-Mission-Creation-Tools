"""`build_mission_briefing` — the briefing of a one-shot mission, for an assistant with no shell (FEAT-MCP-MISSION-BRIEFING 05)."""

from __future__ import annotations

from pathlib import Path

import pytest
from objective_mission_fixture import objective_mission
from veaf_mission_mcp.actions import register_default_actions
from veaf_mission_mcp.catalog import ActionCatalog

PARAMS = {
    "title": "Marteau de Khobi",
    "context": ["Les dépôts de Khobi ravitaillent le front."],
    "mission_bullets": ["Détruire le dépôt"],
    "objectives": [{"zone": "Khobi", "title": "Détruire le dépôt de Khobi", "task": ["Le dépôt et son SA-8."]}],
    "threats": [{"name": "SA-6 Gori", "group": "SA-6 Site", "family": "SA-6", "engagement_nm": 13, "source": "jeu"}],
    "pilots": {"Kobuleti Viper": ["Zip"]},
}


@pytest.fixture
def catalog() -> ActionCatalog:
    catalog = ActionCatalog()
    register_default_actions(catalog)
    return catalog


def test_the_action_runs_through_the_catalog(catalog: ActionCatalog, tmp_path: Path) -> None:
    """The wiring, not the worker: what the assistant actually calls."""
    objective_mission(tmp_path)
    result = catalog.run_action("build_mission_briefing", {"mission_path": str(tmp_path), **PARAMS})
    assert Path(result["deck"]) == tmp_path / "docs" / "briefing.pptx" and Path(result["deck"]).is_file()
    assert result["pages"] == 9
    assert [Path(path).name for path in result["maps"]] == ["overview.png", "objective-khobi.png"]
    assert result["pictures"] == ["MCP_Briefing_overview", "MCP_Briefing_objective-khobi"]
    assert result["map_offline"] is True  # no network in the tests
    assert any("plain background" in warning for warning in result["warnings"])


def test_topo_is_a_basemap_and_anything_else_is_refused(catalog: ActionCatalog, tmp_path: Path) -> None:
    objective_mission(tmp_path)
    catalog.run_action("build_mission_briefing", {"mission_path": str(tmp_path), **PARAMS, "basemap": "topo"})
    with pytest.raises(ValueError, match="basemap"):
        catalog.run_action("build_mission_briefing", {"mission_path": str(tmp_path), **PARAMS, "basemap": "google"})


def test_an_unaccented_french_briefing_is_warned_and_an_accented_one_is_not(
    catalog: ActionCatalog, tmp_path: Path
) -> None:
    """FIX-DEMO-VIDEO-FINDINGS 06: the words a player reads keep their accents."""
    objective_mission(tmp_path)
    plain = {
        **PARAMS,
        "context": ["La colonne blindee a force le defile et elle est arretee faute de carburant, pres du noeud."],
    }
    result = catalog.run_action("build_mission_briefing", {"mission_path": str(tmp_path), **plain})
    assert any(warning.startswith("context:") and "accent" in warning for warning in result["warnings"])

    result = catalog.run_action("build_mission_briefing", {"mission_path": str(tmp_path), **PARAMS})
    assert not any("accent" in warning for warning in result["warnings"])


def test_the_inspection_shows_the_date_and_the_briefing_pictures(catalog: ActionCatalog, tmp_path: Path) -> None:
    """FIX-DEMO-VIDEO-FINDINGS 14: the AI opened the archive with a shell to see both."""
    from veaf_mission_mcp.inspect_built import inspect_built_mission

    objective_mission(tmp_path)
    before = inspect_built_mission(tmp_path)
    assert before["briefing_pictures"] == "absent"
    assert before["weather"][0].startswith("main: 20"), "the date comes first: YYYY-MM-DD HH:MM"

    catalog.run_action("build_mission_briefing", {"mission_path": str(tmp_path), **PARAMS})
    after = inspect_built_mission(tmp_path)
    assert any(
        line.startswith("MCP_Briefing_overview -> briefing-overview.jpg: in the archive, for blue, neutral")
        for line in after["briefing_pictures"]
    )
