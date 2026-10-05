"""`add_combat_operation` — a combat operation declared in one call (FIX-DEMO-MISSION-FINDINGS 07).

The demo mission wrote its operation by hand in `mission.yaml`: no action knew `type: operation`.
An operation is a label over zones that already exist, so the action writes `mission.yaml` only and
refuses a task or a dependency naming a zone the mission does not declare — the generated
`GetZone()` would be `nil` at runtime.
"""

from pathlib import Path

import pytest
from mission_tools.mission_yaml_editor import load_yaml
from veaf_mission_mcp.composites import add_combat_operation

_YAML = """\
# mission config
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: "CZ-Alpha"   # first objective
      - type: zone
        zone_name: "CZ-Bravo"
"""


def _folder(tmp_path: Path) -> Path:
    (tmp_path / "mission.yaml").write_text(_YAML, encoding="utf-8")
    return tmp_path


def _zones(folder: Path) -> list:
    return list(load_yaml(folder / "mission.yaml")["modules"]["COMBATZONE"]["combat_zones"])


def test_the_operation_is_appended_with_its_tasks_and_dependencies(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    result = add_combat_operation(
        folder,
        zone_name="Op-Thunder",
        friendly_name="Operation Thunder",
        briefing="Take both villages.",
        tasking_orders=[{"zone_name": "CZ-Alpha"}, {"zone_name": "CZ-Bravo", "dependencies": ["CZ-Alpha"]}],
    )

    operation = _zones(folder)[-1]
    assert dict(operation) == {
        "type": "operation",
        "zone_name": "Op-Thunder",
        "friendly_name": "Operation Thunder",
        "briefing": "Take both villages.",
        "tasking_orders": [{"zone_name": "CZ-Alpha"}, {"zone_name": "CZ-Bravo", "dependencies": ["CZ-Alpha"]}],
    }
    assert result["zone_name"] == "Op-Thunder"


def test_active_at_start_is_written_only_when_asked(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    add_combat_operation(folder, zone_name="Op-A", tasking_orders=[{"zone_name": "CZ-Alpha"}])
    add_combat_operation(folder, zone_name="Op-B", tasking_orders=[{"zone_name": "CZ-Alpha"}], active_at_start=True)
    zones = _zones(folder)
    assert "active_at_start" not in zones[-2]
    assert zones[-1]["active_at_start"] is True


def test_the_existing_zones_and_comments_survive(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    add_combat_operation(folder, zone_name="Op-Thunder", tasking_orders=[{"zone_name": "CZ-Alpha"}])
    text = (folder / "mission.yaml").read_text(encoding="utf-8")
    assert "# first objective" in text
    assert [z["zone_name"] for z in _zones(folder)] == ["CZ-Alpha", "CZ-Bravo", "Op-Thunder"]


@pytest.mark.parametrize(
    "orders",
    [
        [{"zone_name": "CZ-Nowhere"}],
        [{"zone_name": "CZ-Alpha", "dependencies": ["CZ-Nowhere"]}],
    ],
)
def test_an_undeclared_zone_is_refused_by_name(tmp_path: Path, orders: list) -> None:
    folder = _folder(tmp_path)
    with pytest.raises(ValueError, match="CZ-Nowhere"):
        add_combat_operation(folder, zone_name="Op-Thunder", tasking_orders=orders)
    assert len(_zones(folder)) == 2, "nothing written on refusal"


def test_an_operation_cannot_be_a_task_of_another(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    add_combat_operation(folder, zone_name="Op-One", tasking_orders=[{"zone_name": "CZ-Alpha"}])
    with pytest.raises(ValueError, match="Op-One"):
        add_combat_operation(folder, zone_name="Op-Two", tasking_orders=[{"zone_name": "Op-One"}])


def test_a_name_already_taken_is_refused(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    with pytest.raises(ValueError, match="CZ-Alpha"):
        add_combat_operation(folder, zone_name="CZ-Alpha", tasking_orders=[{"zone_name": "CZ-Bravo"}])


def test_an_operation_needs_a_task(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="tasking_orders"):
        add_combat_operation(_folder(tmp_path), zone_name="Op-Empty", tasking_orders=[])


def test_the_action_is_registered(tmp_path: Path) -> None:
    from veaf_mission_mcp.server import CATALOG

    folder = _folder(tmp_path)
    CATALOG.run_action(
        "add_combat_operation",
        {"folder_path": str(folder), "zone_name": "Op-Thunder", "tasking_orders": [{"zone_name": "CZ-Alpha"}]},
    )
    assert _zones(folder)[-1]["zone_name"] == "Op-Thunder"
