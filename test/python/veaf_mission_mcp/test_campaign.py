"""The campaign actions of the MCP (FEAT-MULTI-MISSION-CAMPAIGN ticket 09)."""

from __future__ import annotations

import copy
from pathlib import Path

import pytest
import yaml
from campaign_fixture import VALID
from campaign_manager.campaign_worker import CAMPAIGN_FILE, STATE_FILE, CampaignWorker
from veaf_libs.blank_mission import generate_blank_mission
from veaf_mission_mcp.actions import register_default_actions
from veaf_mission_mcp.campaign import campaign_apply, campaign_next, campaign_status
from veaf_mission_mcp.catalog import ActionCatalog


def _campaign_folder(tmp_path: Path) -> Path:
    (tmp_path / CAMPAIGN_FILE).write_text(yaml.safe_dump(copy.deepcopy(VALID)), encoding="utf-8")
    template = tmp_path / "template"
    for relative, content in generate_blank_mission("Caucasus").items():
        path = template / "src" / "mission" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    (template / "mission.yaml").write_text("mission:\n  name: m\n", encoding="utf-8")
    CampaignWorker(tmp_path).init()
    return tmp_path


def _state_file(folder: Path, mission: int = 1) -> Path:
    from luadata.io.write import write

    current = yaml.safe_load((folder / STATE_FILE).read_text(encoding="utf-8"))
    current["mission"] = mission
    current["zones"]["Senaki"]["owner"] = "blue"
    for zone in current["zones"].values():
        for key in [k for k, v in zone.items() if v is None]:
            del zone[key]
    path = folder / f"mission-{mission:02d}.state"
    write(str(path), current, prefix="return ")
    return path


def test_the_three_actions_run_through_the_catalog(tmp_path: Path) -> None:
    """The wiring, not the handlers: what Claude actually calls."""
    catalog = ActionCatalog()
    register_default_actions(catalog)
    folder = _campaign_folder(tmp_path)
    assert catalog.run_action("campaign_status", {"campaign_folder": str(folder)})["mission"] == 0
    applied = catalog.run_action(
        "campaign_apply", {"campaign_folder": str(folder), "state_file": str(_state_file(folder))}
    )
    assert applied["mission"] == 1
    assert catalog.run_action("campaign_next", {"campaign_folder": str(folder)})["mission"] == 2


def test_status_reads_the_campaign(tmp_path: Path) -> None:
    status = campaign_status(_campaign_folder(tmp_path))
    assert (status["campaign"], status["mission"], status["missions"], status["outcome"]) == (
        "Caucasus Front",
        0,
        8,
        "running",
    )
    assert status["zones"]["Senaki"] == {
        "owner": "red",
        "strength_percent": None,
        "kind": None,
        "neighbours": ["Kobuleti", "Gudauta depot"],
    }
    assert status["objectives"][0] == {"kind": "capture", "zones": ["Senaki"], "met": False}
    assert status["last_mission"] is None


def test_status_before_init_is_refused(tmp_path: Path) -> None:
    (tmp_path / CAMPAIGN_FILE).write_text(yaml.safe_dump(copy.deepcopy(VALID)), encoding="utf-8")
    with pytest.raises(ValueError, match="campaign init"):
        campaign_status(tmp_path)


def test_apply_then_status_tells_what_changed(tmp_path: Path) -> None:
    folder = _campaign_folder(tmp_path)
    result = campaign_apply(folder, _state_file(folder))
    assert result["mission"] == 1
    assert result["objectives"][0]["met"] is True
    assert any("Senaki" in change for change in result["changes"])
    assert result["debriefing"]["en"].startswith("DEBRIEFING — Caucasus Front, mission 1 of 8")
    status = campaign_status(folder)
    assert status["mission"] == 1
    assert status["last_mission"]["mission"] == 1


def test_apply_twice_is_refused(tmp_path: Path) -> None:
    folder = _campaign_folder(tmp_path)
    path = _state_file(folder)
    campaign_apply(folder, path)
    with pytest.raises(ValueError):
        campaign_apply(folder, path)


def test_next_returns_the_folder_and_both_briefings(tmp_path: Path) -> None:
    folder = _campaign_folder(tmp_path)
    result = campaign_next(folder)
    assert result["mission"] == 1
    assert result["created"] is True
    assert Path(result["folder"]) == folder / "missions" / "mission-01" / "mission"
    assert result["airbases"] == ["Kobuleti", "Senaki-Kolkhi"]
    assert "SITUATION STRATÉGIQUE" in result["strategic_situation"]["fr"]
    assert "STRATEGIC SITUATION" in result["strategic_situation"]["en"]


def test_next_without_a_template_is_refused(tmp_path: Path) -> None:
    folder = _campaign_folder(tmp_path)
    import shutil

    shutil.rmtree(folder / "template")
    with pytest.raises(ValueError, match="template"):
        campaign_next(folder)
