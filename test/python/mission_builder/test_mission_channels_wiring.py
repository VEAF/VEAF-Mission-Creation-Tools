"""FEAT-AIRFIELD-FREQS-IN-ATIS 03 — the build hands the mission's base channels to the scripts."""

from __future__ import annotations

from pathlib import Path

from mission_builder.mission_builder_worker import MissionBuilderWorker

_PRESETS = """\
channels_collection:
  bases:
    Base-Batumi:
      title: Batumi / 16X
      freqs: { uhf: 270.3, vhf: 130.3 }
"""


def _worker(folder: Path, presets: str | None) -> MissionBuilderWorker:
    (folder / "src" / "mission").mkdir(parents=True)
    (folder / "src" / "mission" / "theatre").write_text("Caucasus", encoding="utf-8")
    if presets is not None:
        (folder / "src" / "presets.yaml").write_text(presets, encoding="utf-8")
    (folder / "mission.yaml").write_text("mission:\n  name: Test\n  era: MODERN\n", encoding="utf-8")
    return MissionBuilderWorker(mission_folder=folder, output_mission=folder / "out.miz", dynamic_mode=None)


def _config(folder: Path) -> str:
    return (folder / "src" / "scripts" / "veaf-config.lua").read_text(encoding="utf-8")


def test_the_bases_channel_of_an_airfield_reaches_veaf_config(tmp_path: Path) -> None:
    _worker(tmp_path, _PRESETS).write_config_lua()
    assert '[22] = { alias = "Base-Batumi", title = "Batumi / 16X", uhf = 270.3, vhf = 130.3 },' in _config(tmp_path)


def test_a_mission_without_bases_gets_no_table(tmp_path: Path) -> None:
    _worker(tmp_path, None).write_config_lua()
    assert "MissionChannels" not in _config(tmp_path)
