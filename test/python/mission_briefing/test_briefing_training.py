"""Tests for the training pages of the mission briefing (FEAT-TRAINING-BRIEFING-PAGES)."""

from __future__ import annotations

from pathlib import Path

import luadata
import yaml
from mission_briefing.briefing_training import training_pages
from training_fixtures import night_mission, night_yaml
from veaf_libs.i18n import t


def _folder(tmp_path: Path, config: dict) -> Path:
    (tmp_path / "src" / "mission").mkdir(parents=True)
    (tmp_path / "src" / "mission" / "mission").write_text(
        "mission = " + luadata.serialize(night_mission()), encoding="utf-8"
    )
    (tmp_path / "mission.yaml").write_text(yaml.safe_dump(config, allow_unicode=True), encoding="utf-8")
    return tmp_path


def _rows(page) -> dict[str, tuple[str, str]]:
    return {row[0]: (row[1], row[2]) for row in page.tables[0].rows}


def test_one_page_per_version_in_build_order(tmp_path: Path) -> None:
    warnings: list[str] = []
    pages = training_pages(_folder(tmp_path, night_yaml()), warnings)
    assert warnings == []
    assert [page.title for page in pages] == [
        t(f"mission_briefing.training.title.{role}") for role in ("A2G", "CAP", "SEAD", "ALL")
    ]
    assert t("mission_briefing.training.file", suffix="TRAINING_SEAD") in pages[2].after[0].paragraphs


def test_the_rows_say_what_the_build_does(tmp_path: Path) -> None:
    config = night_yaml()
    config["training"]["randomize"].append(
        {"name": "tanks", "replaces": ["Factory-Tanks"], "pool": [{"group": "Factory-Tanks"}, {"command": "-armor"}]}
    )
    a2g, cap, sead, common = training_pages(_folder(tmp_path, config), [])
    status = lambda key: t(f"mission_briefing.training.status.{key}")  # noqa: E731
    assert _rows(a2g)["SA-10 Gudauta"][1] == status("removed")
    assert _rows(cap)["SA-10 Gudauta"][1] == status("kept")
    assert _rows(cap)["Factory"][1] == status("targets_out")
    assert _rows(sead)["Factory"][1] == status("removed")
    assert _rows(cap)["CAP"][1] == status("kept")  # an on-demand CAP is named by its menu name
    tanks = t("mission_briefing.training.draw", count="1", candidates="Factory-Tanks, -armor")
    defences = t(
        "mission_briefing.training.draw",
        count="1-2",
        candidates="Factory-SA-8 #1, -sa15, " + t("mission_briefing.training.units", count=2, type="Strela-10M3"),
    )
    assert _rows(a2g)[tanks][1] == status("drawn")
    assert _rows(sead)[tanks][1] == status("draw_removed")
    assert _rows(sead)[defences][1] == status("drawn")
    assert all(row[2] != status("removed") for row in common.tables[0].rows)


def test_no_block_no_page(tmp_path: Path) -> None:
    config = night_yaml()
    del config["training"]
    assert training_pages(_folder(tmp_path, config), []) == []


def test_a_block_the_build_refuses_is_a_warning(tmp_path: Path) -> None:
    config = night_yaml()
    config["training"]["elements"].append({"qra": "Nope", "kind": "qra"})
    warnings: list[str] = []
    assert training_pages(_folder(tmp_path, config), warnings) == []
    assert len(warnings) == 1 and "Nope" in warnings[0]


def test_labels_name_the_elements_for_a_pilot(tmp_path: Path) -> None:
    config = night_yaml()
    config["training"]["elements"][5]["label"] = "SA-6 de l'usine"
    config["training"]["randomize"][0]["label"] = "Défenses autour de l'usine"
    a2g = training_pages(_folder(tmp_path, config), [])[0]
    rows = _rows(a2g)
    assert "SA-6 de l'usine" in rows
    named = t(
        "mission_briefing.training.draw_named",
        label="Défenses autour de l'usine",
        count=t("mission_briefing.training.range", low="1", high="2"),
        size=3,
    )
    assert named in rows


def test_an_empty_label_is_refused() -> None:
    from mission_builder.training_variants import parse_training

    plan, errors = parse_training({"elements": [{"groups": ["x"], "kind": "qra", "label": " "}]})
    assert plan is None and any("'label'" in error for error in errors)
    plan, errors = parse_training({"randomize": [{"name": "a", "replaces": "x", "pool": [{"group": "x"}], "label": 3}]})
    assert plan is None and any("'label'" in error for error in errors)


def test_a_target_the_version_keeps_reads_kept(tmp_path: Path) -> None:
    """CAP keeps an air defence declared a target (D7 of FEAT-ROLE-TRAINING-VARIANTS): the page must say so."""
    mission = night_mission()
    mission["coalition"]["red"]["country"][0]["vehicle"]["group"].append(
        {
            "name": "Lone Shilka",
            "x": 0,
            "y": 0,
            "units": [{"name": "Lone Shilka-1", "type": "ZSU-23-4 Shilka", "x": 0, "y": 0}],
        }
    )
    folder = _folder(tmp_path, {**night_yaml()})
    (folder / "src" / "mission" / "mission").write_text("mission = " + luadata.serialize(mission), encoding="utf-8")
    config = night_yaml()
    config["training"]["elements"].append({"groups": ["Lone Shilka"], "kind": "a2g_target"})
    (folder / "mission.yaml").write_text(yaml.safe_dump(config, allow_unicode=True), encoding="utf-8")
    _, cap, sead, _ = training_pages(folder, [])
    assert _rows(cap)["Lone Shilka"][1] == t("mission_briefing.training.status.kept")
    assert _rows(sead)["Lone Shilka"][1] == t("mission_briefing.training.status.removed")
