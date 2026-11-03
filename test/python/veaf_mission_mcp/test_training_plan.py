"""Tests for propose_training_plan / set_training_plan (FEAT-ROLE-TRAINING-VARIANTS 06)."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import luadata
import pytest
import yaml
from mission_builder.training_variants import check_training
from veaf_mission_mcp.actions import register_default_actions
from veaf_mission_mcp.catalog import ActionCatalog
from veaf_mission_mcp.training_plan import propose_training_plan, set_training_plan


def _unit(name: str, unit_type: str, x: float, y: float, skill: str = "Average") -> dict[str, Any]:
    return {"name": name, "type": unit_type, "x": x, "y": y, "unitId": 1, "skill": skill}


def _group(name: str, units: list[dict[str, Any]], **extra: Any) -> dict[str, Any]:
    return {"name": name, "groupId": 1, "x": units[0]["x"], "y": units[0]["y"], "units": units, **extra}


def _folder(tmp_path: Path) -> Path:
    mission = {
        "coalition": {
            "blue": {
                "country": [
                    {
                        "id": 2,
                        "name": "USA",
                        "plane": {"group": [_group("Viper 1", [_unit("Viper 1-1", "F-16C_50", -90000, 0, "Client")])]},
                    }
                ]
            },
            "red": {
                "country": [
                    {
                        "id": 0,
                        "name": "Russia",
                        "plane": {
                            "group": [
                                _group("Red CAP", [_unit("Red CAP-1", "MiG-29S", 60000, 0)], task="CAP"),
                                _group(
                                    "QRA-MiG",
                                    [_unit("QRA-MiG-1", "MiG-29S", 61000, 0)],
                                    task="CAP",
                                    lateActivation=True,
                                ),
                                _group("Bomber", [_unit("Bomber-1", "Tu-22M3", 62000, 0)], task="Ground Attack"),
                            ]
                        },
                        "vehicle": {
                            "group": [
                                _group("SA-10", [_unit("SA-10-1", "S-300PS 40B6M tr", -50000, 20000)]),
                                _group("Factory-Tanks", [_unit("Factory-Tanks-1", "T-72B", 1000, 1000)]),
                                _group("Factory-SA-6", [_unit("Factory-SA-6-1", "Kub 2P25 ln", 1200, 900)]),
                                _group("Lonely SA-8", [_unit("Lonely SA-8-1", "Osa 9A33 ln", 300000, 300000)]),
                            ]
                        },
                    }
                ]
            },
        },
        "triggers": {"zones": [{"name": "Factory", "x": 1000, "y": 1000, "radius": 3000, "zoneId": 1}]},
        "trig": {},
        "trigrules": {},
    }
    (tmp_path / "src" / "mission").mkdir(parents=True)
    (tmp_path / "src" / "mission" / "mission").write_text("mission = " + luadata.serialize(mission), encoding="utf-8")
    config = {
        "modules": {
            "COMBATZONE": {"enabled": True, "combat_zones": [{"zone_name": "Factory"}]},
            "QRA": {"enabled": True, "definitions": [{"name": "QRA-North", "coalition": "RED"}]},
        },
        "cap_missions": [{"group_name": "CAP-Red"}],
    }
    (tmp_path / "mission.yaml").write_text("# the night\n" + yaml.safe_dump(config), encoding="utf-8")
    return tmp_path


def test_the_draft_classifies_what_the_data_tells(tmp_path: Path) -> None:
    result = propose_training_plan(_folder(tmp_path))
    elements = result["training"]["elements"]
    assert result["enemy_coalition"] == "red"
    assert elements == [
        {"groups": ["Red CAP"], "kind": "enemy_cap"},
        {"groups": ["SA-10"], "kind": "sam_lr"},
        {"groups": ["Factory-SA-6"], "kind": "sam_threat"},
        {"zone": "Factory", "kind": "a2g_target"},
        {"cap_mission": "CAP-Red", "kind": "enemy_cap"},
        {"qra": "QRA-North", "kind": "qra"},
    ]
    assert len(result["reasons"]) == len(elements)
    assert "LR SAM" in result["reasons"][1]
    assert "randomize" in result["note"]


def test_set_writes_the_block_and_keeps_the_comments(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    training = {"elements": [{"groups": ["SA-10"], "kind": "sam_lr"}]}
    result = set_training_plan(folder, training)
    text = (folder / "mission.yaml").read_text(encoding="utf-8")
    assert text.startswith("# the night")
    assert yaml.safe_load(text)["training"] == training
    assert result["versions"] == ["_TRAINING_A2G", "_TRAINING_CAP", "_TRAINING_SEAD", "_TRAINING_ALL"]
    assert Path(result["backup"]).exists()


def test_set_refuses_a_block_the_build_would_refuse(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    before = (folder / "mission.yaml").read_text(encoding="utf-8")
    with pytest.raises(ValueError, match="no group of the mission matches 'Nothing'"):
        set_training_plan(folder, {"elements": [{"groups": ["Nothing"], "kind": "sam_lr"}]})
    assert (folder / "mission.yaml").read_text(encoding="utf-8") == before


def test_the_draft_is_accepted_by_the_build_checks(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    draft = propose_training_plan(folder)["training"]
    set_training_plan(folder, draft)
    config = yaml.safe_load((folder / "mission.yaml").read_text(encoding="utf-8"))
    assert config["training"] == draft
    assert check_training(config, None, [])[0] == []


def test_both_actions_are_registered() -> None:
    catalog = ActionCatalog()
    register_default_actions(catalog)
    names = {spec.name for spec in catalog.list_catalog()}
    assert {"propose_training_plan", "set_training_plan"} <= names
