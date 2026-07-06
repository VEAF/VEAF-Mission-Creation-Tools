"""Tests for the airfield ATC-frequency generator (parses terrain Radio.lua)."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from veaf_build.dcs_data import airfield_freqs as A

# Two real Caucasus entries (values verified against the shipped Radio.lua).
_RADIO = """\
radioTableFormat = 3
radio = {
\t{
\t\t-- Anapa
\t\tradioId = 'airfield12_0';
\t\trole = {"ground", "tower", "approach"};
\t\tcallsign = {{["common"] = {_("Anapa"), "Anapa"}}};
\t\tfrequency = {[HF] = {MODULATIONTYPE_AM, 3750000.000000}, [UHF] = {MODULATIONTYPE_AM, 250000000.000000}, [VHF_HI] = {MODULATIONTYPE_AM, 121000000.000000}, [VHF_LOW] = {MODULATIONTYPE_AM, 38400000.000000}};
\t\tsceneObjects = {'t:35192994'};
\t};
\t{
\t\t-- Batumi
\t\tradioId = 'airfield22_0';
\t\trole = {"ground", "tower", "approach"};
\t\tcallsign = {{["nato"] = {_("Batumi"), "Batumi"}}, {["ussr"] = {_("Druzhinnik"), "Druzhinnik"}}};
\t\tfrequency = {[HF] = {MODULATIONTYPE_AM, 4250000.000000}, [UHF] = {MODULATIONTYPE_AM, 260000000.000000}, [VHF_HI] = {MODULATIONTYPE_AM, 131000000.000000}, [VHF_LOW] = {MODULATIONTYPE_AM, 40400000.000000}};
\t\tsceneObjects = {'t:15247557'};
\t};
}
"""


def test_parse_radio_maps_bands_to_mhz() -> None:
    result = A.parse_radio(_RADIO)
    assert result["Batumi"] == {"uhf": 260.0, "vhf": 131.0, "fm": 40.4}
    assert result["Anapa"] == {"uhf": 250.0, "vhf": 121.0, "fm": 38.4}


def test_parse_radio_drops_hf_and_sorts_by_name() -> None:
    result = A.parse_radio(_RADIO)
    assert list(result.keys()) == ["Anapa", "Batumi"]  # sorted; HF absent from every entry
    assert "hf" not in result["Batumi"]


def test_parse_radio_uses_first_callsign_name() -> None:
    # Batumi (nato) wins over the ussr callsign Druzhinnik.
    assert "Druzhinnik" not in A.parse_radio(_RADIO)


def test_extract_all_airfield_freqs(tmp_path: Path) -> None:
    terrains = tmp_path / "Mods" / "terrains"
    (terrains / "Caucasus").mkdir(parents=True)
    (terrains / "Caucasus" / "Radio.lua").write_text(_RADIO, encoding="utf-8")
    (terrains / "Normandy").mkdir()
    (terrains / "Normandy" / "Radio.lua").write_text("radio = {}\n", encoding="utf-8")
    result = A.extract_all_airfield_freqs(tmp_path)
    assert result["Caucasus"]["Batumi"] == {"uhf": 260.0, "vhf": 131.0, "fm": 40.4}
    assert result["Normandy"] == {}


def test_extract_missing_terrains_dir_raises(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        A.extract_all_airfield_freqs(tmp_path)


def test_generate_writes_yaml(tmp_path: Path) -> None:
    terrains = tmp_path / "Mods" / "terrains"
    (terrains / "Caucasus").mkdir(parents=True)
    (terrains / "Caucasus" / "Radio.lua").write_text(_RADIO, encoding="utf-8")
    out = tmp_path / "airfield-frequencies.yaml"
    count = A.generate(tmp_path, out)
    assert count == 2
    data = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert data["theatres"]["Caucasus"]["Batumi"]["uhf"] == 260.0
