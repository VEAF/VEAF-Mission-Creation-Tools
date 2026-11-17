"""A one-shot mission's briefing is named after the mission (David, 2026-11-17), not ``briefing.pptx``."""

from __future__ import annotations

from pathlib import Path

from mission_briefing.mission_briefing_worker import briefing_files


def test_named_after_the_mission(tmp_path: Path) -> None:
    (tmp_path / "mission.yaml").write_text("mission:\n  name: Marteau de Khobi 01\n", encoding="utf-8")
    deck, pdf = briefing_files(tmp_path)
    assert deck == tmp_path / "docs" / "Marteau-de-Khobi-01_briefing.pptx"
    assert pdf == tmp_path / "docs" / "Marteau-de-Khobi-01_briefing.pdf"


def test_without_a_name_the_plain_one(tmp_path: Path) -> None:
    assert briefing_files(tmp_path) == (tmp_path / "docs" / "briefing.pptx", tmp_path / "docs" / "briefing.pdf")
    (tmp_path / "mission.yaml").write_text("mission: {}\n", encoding="utf-8")
    assert briefing_files(tmp_path)[0] == tmp_path / "docs" / "briefing.pptx"
