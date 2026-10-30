"""Tests for the combat log reader and its recap per pilot (FEAT-COMBAT-LOG)."""

import json
from pathlib import Path

from typer.testing import CliRunner
from veaf_libs.combat_log import clock, pilot_recaps, read_combat_log

_MARTINHO = {"name": "Hornet-1", "type": "FA-18C_hornet", "coalition": 2, "player": "Martinho"}
_PALUCHE = {"name": "Apache-1", "type": "AH-64D_BLK_II", "coalition": 2, "player": "Paluche"}
_MIG = {"name": "QRA-Khalkhalah-MiG23-1", "type": "MiG-23MLD", "coalition": 1}
_BMP = {"name": "Sasa BMP #2", "type": "BMP-2", "coalition": 1}

_LINES = [
    {"t": 0, "event": "start", "theatre": "Syria", "start_time": 75600},
    {"t": 600, "event": "shot", "shooter": _MARTINHO, "target": _MIG, "weapon": "AIM_120C", "weapon_object": True},
    {"t": 610, "event": "shot", "shooter": _MARTINHO, "target": _MIG, "weapon": "AIM_120C", "weapon_object": True},
    {"t": 615, "event": "hit", "shooter": _MARTINHO, "target": _MIG, "weapon": "AIM_120C", "weapon_object": True},
    {"t": 615, "event": "kill", "shooter": _MARTINHO, "target": _MIG, "weapon": "AIM_120C", "weapon_object": True},
    {"t": 900, "event": "shooting_start", "shooter": _PALUCHE, "weapon_name": "M230", "weapon_object": False},
    {"t": 903, "event": "shooting_end", "shooter": _PALUCHE, "weapon": "M230", "rounds": 90},
    {"t": 902, "event": "hit", "shooter": _PALUCHE, "target": _BMP, "weapon": "M230", "weapon_object": False},
    {"t": 905, "event": "kill", "shooter": _PALUCHE, "target": _PALUCHE | {"name": "Apache-2"}, "weapon": "M230"},
    {"t": 950, "event": "shot", "shooter": _MIG, "target": _PALUCHE, "weapon": "R-73", "weapon_object": True},
]


def _log(tmp_path: Path, extra: str = "") -> Path:
    path = tmp_path / "veaf-combat-log-20261029-211814.jsonl"
    path.write_text("\n".join(json.dumps(line) for line in _LINES) + "\n" + extra, encoding="utf-8")
    return path


def test_the_recap_counts_shots_rounds_hits_and_kills_per_player(tmp_path: Path) -> None:
    log = read_combat_log(_log(tmp_path))
    martinho, paluche = pilot_recaps(log)
    assert (martinho.pilot, martinho.aircraft) == ("Martinho", "FA-18C_hornet")
    assert martinho.shots == {"AIM_120C": 2}
    assert martinho.hits == {"AIM_120C": 1}
    assert [(k.target, k.weapon, k.friendly) for k in martinho.kills] == [("MiG-23MLD", "AIM_120C", False)]
    assert paluche.rounds == {"M230": 90} and paluche.bursts == 1
    assert paluche.kills[0].friendly  # a blue Apache killed by a blue Apache


def test_ai_shooters_only_when_asked(tmp_path: Path) -> None:
    log = read_combat_log(_log(tmp_path))
    assert [r.pilot for r in pilot_recaps(log)] == ["Martinho", "Paluche"]
    assert [r.pilot for r in pilot_recaps(log, include_ai=True)][-1] == "QRA-Khalkhalah-MiG23-1"


def test_a_line_cut_short_by_a_crash_is_skipped_and_counted(tmp_path: Path) -> None:
    log = read_combat_log(_log(tmp_path, '{"t": 990, "event": "sh'))
    assert log.skipped == 1
    assert len(log.records) == len(_LINES) - 1
    assert log.start["theatre"] == "Syria"


def test_the_clock_is_the_missions(tmp_path: Path) -> None:
    log = read_combat_log(_log(tmp_path))
    assert clock(log, 615) == "21:10"  # 21:00 start + 10 min 15 s


def test_the_command_prints_the_table_and_the_json(tmp_path: Path) -> None:
    import veaf_tools.commands  # noqa: F401
    from veaf_tools.app import app

    path = _log(tmp_path)
    table = CliRunner().invoke(app, ["--lang", "en", "combat-log", str(path)])
    assert table.exit_code == 0, table.output
    assert "Martinho" in table.output and "2 × AIM_120C" in table.output and "90 × M230" in table.output
    as_json = CliRunner().invoke(app, ["combat-log", str(path), "--json"])
    assert as_json.exit_code == 0, as_json.output
    assert [r["pilot"] for r in json.loads(as_json.output)] == ["Martinho", "Paluche"]
