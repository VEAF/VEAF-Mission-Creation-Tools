"""Tests for the airdrome name->id generator (parses terrain Beacons.lua)."""

from __future__ import annotations

from pathlib import Path

import yaml

from veaf_build.dcs_data import airdromes as A

_BEACONS = """\
beacons = {
{
    display_name = _('Batumi');
    beaconId = 'airfield22_0';
},
{
    display_name = _('Batumi');
    beaconId = 'airfield22_1';
},
{
    display_name = _('Kobuleti');
    beaconId = 'airfield24_0';
},
{
    display_name = _('Some VOR');
    beaconId = 'vor_kutaisi';
},
}
"""


def test_parse_beacons_dedups_by_name() -> None:
    result = A.parse_beacons(_BEACONS)
    assert result == {"Batumi": 22, "Kobuleti": 24}  # the non-airfield beacon is ignored


def test_parse_beacons_sorted_by_name() -> None:
    result = A.parse_beacons(_BEACONS)
    assert list(result.keys()) == ["Batumi", "Kobuleti"]


def test_extract_all_airdromes(tmp_path: Path) -> None:
    terrains = tmp_path / "Mods" / "terrains"
    (terrains / "Caucasus").mkdir(parents=True)
    (terrains / "Caucasus" / "Beacons.lua").write_text(_BEACONS, encoding="utf-8")
    (terrains / "Normandy").mkdir()
    (terrains / "Normandy" / "Beacons.lua").write_text("beacons = {}\n", encoding="utf-8")  # WW2: no airfields
    result = A.extract_all_airdromes(tmp_path)
    assert result["Caucasus"] == {"Batumi": 22, "Kobuleti": 24}
    assert result["Normandy"] == {}


def test_extract_missing_terrains_dir_raises(tmp_path: Path) -> None:
    import pytest

    with pytest.raises(FileNotFoundError):
        A.extract_all_airdromes(tmp_path)


def test_generate_writes_yaml(tmp_path: Path) -> None:
    terrains = tmp_path / "Mods" / "terrains"
    (terrains / "Caucasus").mkdir(parents=True)
    (terrains / "Caucasus" / "Beacons.lua").write_text(_BEACONS, encoding="utf-8")
    out = tmp_path / "airdromes.yaml"
    count = A.generate(tmp_path, out)
    assert count == 2
    data = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert data["theatres"]["Caucasus"]["Batumi"] == 22


def test_committed_airdromes_has_caucasus() -> None:
    """The committed artifact resolves a known Caucasus airfield."""
    path = Path(__file__).parents[3] / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "airdromes.yaml"
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert data["theatres"]["Caucasus"]["Batumi"] == 22
