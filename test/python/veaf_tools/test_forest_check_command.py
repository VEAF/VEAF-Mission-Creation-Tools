"""`veaf-tools dcs forest-check`, on a mission and a map file built in the test."""

import json
import sys
from pathlib import Path

from typer.testing import CliRunner

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "veaf_libs"))
from test_dcs_forests import _forest_mission  # noqa: E402


def test_the_command_lists_the_groups_in_a_forest_and_writes_the_report(tmp_path: Path) -> None:
    from veaf_tools.app import app
    from veaf_tools.commands import forest_check  # noqa: F401  (registers the command)

    miz, dcs = _forest_mission(tmp_path)
    report = tmp_path / "report.json"
    result = CliRunner().invoke(app, ["forest-check", str(miz), "--dcs-dir", str(dcs), "--report", str(report)])
    assert result.exit_code == 0, result.output
    assert "in-the-wood" in result.output
    assert "in-the-open" not in result.output
    assert json.loads(report.read_text(encoding="utf-8"))["groups_in_forest"] == {"in-the-wood": 2}


def test_a_map_not_installed_is_an_error_naming_the_option(tmp_path: Path) -> None:
    from veaf_tools.app import app
    from veaf_tools.commands import forest_check  # noqa: F401  (registers the command)

    miz, _dcs = _forest_mission(tmp_path)
    result = CliRunner().invoke(app, ["forest-check", str(miz), "--dcs-dir", str(tmp_path / "nowhere")])
    assert result.exit_code == 1
    assert "--dcs-dir" in result.output
