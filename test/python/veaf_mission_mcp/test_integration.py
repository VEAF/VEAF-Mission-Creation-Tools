"""End-to-end scenario driving the full v1 action catalog against a real .miz."""

from pathlib import Path

from veaf_mission_mcp import server


def _add_group_params(miz_path: Path, name: str, y_offset: float) -> dict:
    return {
        "target": str(miz_path),
        "coalition": "red",
        "country_id": 0,
        "country_name": "Russia",
        "category": "vehicle",
        "name": name,
        "position": {"x": 1000.0, "y": 2000.0 + y_offset},
        "units": [{"type": "T-72B", "count": 2}],
        "route": [{"x": 1000.0, "y": 2000.0 + y_offset}, {"x": 1200.0, "y": 2000.0 + y_offset}],
        "patrol": True,
    }


def test_describe_then_add_group_twice_then_describe_again(sample_miz: Path) -> None:
    before = server.run_action("describe_mission", {"miz_path": str(sample_miz)})
    before_names = {g["name"] for g in before["groups"]}

    server.run_action("add_group", _add_group_params(sample_miz, "Red Armor Section 1", 0))
    server.run_action("add_group", _add_group_params(sample_miz, "Red Armor Section 2", 100))

    after = server.run_action("describe_mission", {"miz_path": str(sample_miz)})
    after_names = {g["name"] for g in after["groups"]}

    assert after_names - before_names == {"Red Armor Section 1", "Red Armor Section 2"}
    assert len(list(sample_miz.parent.glob("mission.*.miz"))) == 2
