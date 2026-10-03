"""Tests for the airfield ATC-frequency generator (runtime dumps + Beacons.lua TACAN)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
import yaml

from veaf_build.dcs_data import airfield_freqs as A

# Two real Caucasus TACAN entries and a VOR that must be ignored (Beacons.lua shape).
_BEACONS = """\
beacons = {
\t{
\t\tdisplay_name = _('Batumi');
\t\tbeaconId = 'airfield22_2';
\t\ttype = BEACON_TYPE_TACAN;
\t\tcallsign = 'BTM';
\t\tfrequency = 977000000.000000;
\t\tchannel = 16;
\t\tposition = { -355664.406250, 10.044037, 617386.812500 };
\t\tpositionGeo = { latitude = 41.610899, longitude = 41.600419 };
\t};
\t{
\t\tdisplay_name = _('Kutaisi');
\t\tbeaconId = 'airfield25_3';
\t\ttype = BEACON_TYPE_TACAN;
\t\tcallsign = 'KTS';
\t\tfrequency = 1005000000.000000;
\t\tchannel = 44;
\t};
\t{
\t\tdisplay_name = _('Kutaisi');
\t\tbeaconId = 'airfield25_0';
\t\ttype = BEACON_TYPE_VOR;
\t\tcallsign = 'KT';
\t\tfrequency = 113600000.000000;
\t};
\t{
\t\tdisplay_name = _('AlDhafra');
\t\tbeaconId = 'airfield4_8';
\t\ttype = BEACON_TYPE_VORTAC;
\t\tchannel = 96;
\t};
\t{
\t\tdisplay_name = _('Kobuleti');
\t\tbeaconId = 'world_beacon_1';
\t\ttype = BEACON_TYPE_TACAN;
\t\tchannel = 67;
\t};
}
"""

# What the hook returns for one theatre (Al Dhafra as the ME shows it on 2026-10-01).
_CAPTURE = {
    "theatre": "PersianGulf",
    "airdromes": [
        {
            "id": 4,
            "name": "Al Dhafra AFB",
            "source": "terrain",
            "freqs": [[39500000, 0], [126500000, 0], [251100000, 0], [4300000, 0]],
        },
        {"id": 21, "name": "Bandar-e-Jask", "source": "none", "freqs": []},
    ],
}


def test_band_of_classifies_each_atc_band() -> None:
    assert A.band_of(4.3) == "hf"
    assert A.band_of(39.5) == "fm"
    assert A.band_of(126.5) == "vhf"
    assert A.band_of(251.1) == "uhf"
    assert A.band_of(100.0) is None  # FM broadcast band: no aircraft radio tunes ATC there


def test_parse_tacans_keeps_airfield_tacans_only() -> None:
    assert A.parse_tacans(_BEACONS) == {4: "96X", 22: "16X", 25: "44X"}


def test_parse_capture_returns_theatre_and_records() -> None:
    theatre, records = A.parse_capture(_CAPTURE)
    assert theatre == "PersianGulf"
    assert records[0] == {"id": 4, "name": "Al Dhafra AFB", "source": "terrain", "freqs": [39.5, 126.5, 251.1, 4.3]}


def test_parse_capture_accepts_the_json_string_the_hook_may_return() -> None:
    theatre, records = A.parse_capture(json.dumps(_CAPTURE))
    assert theatre == "PersianGulf" and len(records) == 2


@pytest.mark.parametrize(
    "payload",
    [
        "[string \"x\"]:1: attempt to index global 'Terrain' (a nil value)",
        {"airdromes": []},
        {"theatre": "Caucasus", "airdromes": []},
        {"error": "Terrain.GetTerrainConfig unavailable"},
    ],
)
def test_parse_capture_refuses_what_is_not_a_capture(payload: object) -> None:
    with pytest.raises(ValueError):
        A.parse_capture(payload)


def test_write_dump_folds_tacan_in_and_sorts_by_id(tmp_path: Path) -> None:
    _theatre, records = A.parse_capture(_CAPTURE)
    path = A.write_dump("PersianGulf", records, {4: "96X"}, tmp_path)
    dump = json.loads(path.read_text(encoding="utf-8"))
    assert path.name == "PersianGulf.json"
    assert [a["id"] for a in dump["airdromes"]] == [4, 21]
    assert dump["airdromes"][0]["tacan"] == "96X"
    assert "tacan" not in dump["airdromes"][1]


def test_reference_takes_one_frequency_per_band_and_the_runtime_name() -> None:
    dumps = {
        "PersianGulf": [
            {"id": 4, "name": "Al Dhafra", "freqs": [39.5, 126.5, 251.1, 4.3, 252.0], "tacan": "96X"},
            {"id": 21, "name": "Jask", "freqs": []},
        ]
    }
    ref = A.reference_from_dumps(dumps, {"PersianGulf": {4: "Al Dhafra AFB"}})
    assert ref == {
        "PersianGulf": {4: {"name": "Al Dhafra AFB", "uhf": 251.1, "vhf": 126.5, "fm": 39.5, "tacan": "96X"}}
    }


def test_reference_falls_back_to_the_terrain_name_without_an_airbase_dump() -> None:
    ref = A.reference_from_dumps({"Caucasus": [{"id": 22, "name": "Batumi", "freqs": [260.0]}]}, {})
    assert ref["Caucasus"][22]["name"] == "Batumi"


def test_collections_are_named_per_theatre_and_titled_with_tacan() -> None:
    ref = {
        "Caucasus": {
            22: {"name": "Batumi", "uhf": 260.0, "vhf": 131.0, "fm": 40.4, "tacan": "16X"},
            12: {"name": "Anapa-Vityazevo", "uhf": 250.0, "vhf": 121.0, "fm": 38.4},
        },
        "PersianGulf": {4: {"name": "Al Dhafra AFB", "vhf": 126.5}},
    }
    cols = A.collections_from_reference(ref)
    assert list(cols) == ["airports-caucasus", "airports-persian-gulf"]
    assert list(cols["airports-caucasus"]) == ["Anapa-Vityazevo", "Batumi"]  # sorted by name
    assert cols["airports-caucasus"]["Batumi"] == {
        "title": "Batumi / 16X",
        "freqs": {"uhf": 260.0, "vhf": 131.0, "fm": 40.4},
    }
    assert cols["airports-persian-gulf"]["Al Dhafra AFB"] == {"title": "Al Dhafra AFB", "freqs": {"vhf": 126.5}}


def test_a_name_on_two_theatres_is_qualified_so_no_alias_resolves_to_the_wrong_map() -> None:
    ref = {
        "SinaiMap": {1: {"name": "Hatzor", "uhf": 250.6}, 2: {"name": "Kedem", "uhf": 250.15}},
        "Syria": {3: {"name": "Hatzor", "uhf": 250.75}, 4: {"name": "Damascus", "uhf": 251.0}},
    }
    cols = A.collections_from_reference(ref)
    assert list(cols["airports-sinai"]) == ["Hatzor (SinaiMap)", "Kedem"]
    assert list(cols["airports-syria"]) == ["Damascus", "Hatzor (Syria)"]
    assert cols["airports-syria"]["Hatzor (Syria)"]["title"] == "Hatzor"


def test_collection_name_has_a_readable_form_for_every_theatre() -> None:
    assert A.collection_name("GermanyCW") == "airports-germany-cold-war"
    assert A.collection_name("SinaiMap") == "airports-sinai"
    assert A.collection_name("MarianaIslands") == "airports-mariana-islands"
    assert A.collection_name("SomeNewMap") == "airports-some-new-map"


def test_replace_generated_block_keeps_everything_around_it() -> None:
    text = "a: 1\n    # >>> airfield channels\n    old: x\n    # <<< airfield channels\nb: 2\n"
    out = A.replace_generated_block(text, "    new: y\n")
    assert out == "a: 1\n    # >>> airfield channels\n    new: y\n    # <<< airfield channels\nb: 2\n"


def test_replace_generated_block_refuses_a_file_without_markers() -> None:
    with pytest.raises(ValueError):
        A.replace_generated_block("a: 1\n", "x: 2\n")


def test_rendered_block_loads_back_to_the_same_collections() -> None:
    cols = {"airports-caucasus": {"Batumi": {"title": "Batumi / 16X", "freqs": {"uhf": 260.0, "vhf": 131.0}}}}
    text = "channels_collection:\n" + A.render_collections(cols)
    assert yaml.safe_load(text)["channels_collection"] == cols


def _write_fixture(tmp_path: Path) -> tuple[Path, Path, Path, Path]:
    dumps = tmp_path / "dumps"
    airbases = tmp_path / "airbases"
    dumps.mkdir()
    airbases.mkdir()
    (dumps / "Caucasus.json").write_text(
        json.dumps({"theatre": "Caucasus", "airdromes": [{"id": 22, "name": "Batumi", "freqs": [260.0, 131.0]}]}),
        encoding="utf-8",
    )
    (airbases / "Caucasus.json").write_text(
        json.dumps({"theatre": "Caucasus", "airbases": [{"id": 22, "name": "Batumi"}]}), encoding="utf-8"
    )
    presets = tmp_path / "presets.yaml"
    presets.write_text(
        f"channels_collection:\n    tactical: {{}}\n{A.BLOCK_START}\n    stale: {{}}\n{A.BLOCK_END}\n",
        encoding="utf-8",
    )
    return dumps, airbases, presets, tmp_path / "airfield-frequencies.yaml"


def test_generate_writes_reference_and_collections_and_is_idempotent(tmp_path: Path) -> None:
    dumps, airbases, presets, output = _write_fixture(tmp_path)
    count = A.generate(output=output, presets=presets, dumps_dir=dumps, airbase_dumps_dir=airbases)
    assert count == 1
    first = (output.read_text(encoding="utf-8"), presets.read_text(encoding="utf-8"))
    data = yaml.safe_load(presets.read_text(encoding="utf-8"))["channels_collection"]
    assert data["airports-caucasus"]["Batumi"]["freqs"] == {"uhf": 260.0, "vhf": 131.0}
    assert "stale" not in data and "tactical" in data
    assert yaml.safe_load(first[0])["theatres"]["Caucasus"][22]["uhf"] == 260.0

    A.generate(output=output, presets=presets, dumps_dir=dumps, airbase_dumps_dir=airbases)
    assert (output.read_text(encoding="utf-8"), presets.read_text(encoding="utf-8")) == first


def test_generate_refuses_to_run_without_any_dump(tmp_path: Path) -> None:
    _dumps, airbases, presets, output = _write_fixture(tmp_path)
    with pytest.raises(FileNotFoundError):
        A.generate(output=output, presets=presets, dumps_dir=tmp_path / "nothing", airbase_dumps_dir=airbases)


def test_terrain_folder_maps_runtime_theatre_names_to_install_folders() -> None:
    assert A.terrain_folder("GermanyCW") == "GermanyColdWar"
    assert A.terrain_folder("SinaiMap") == "Sinai"
    assert A.terrain_folder("Caucasus") == "Caucasus"


# --- the committed artifacts ---------------------------------------------------------------------


def test_committed_reference_and_default_collections_derive_from_the_committed_dumps() -> None:
    """The drift this lot ends: the shipped channels must be exactly what the dumps say.

    Offline: it recomputes from the committed dumps, so it needs no DCS. A frequency typed by hand
    into the defaults, or a dump captured without regenerating, turns this red.
    """
    if not any(A.DUMPS_DIR.glob("*.json")):
        pytest.skip("no airfield-frequency dump committed yet")
    reference = A.reference_from_dumps(A.load_dumps(), A.load_airbase_names())
    committed_ref = yaml.safe_load(A.DEFAULT_OUTPUT.read_text(encoding="utf-8"))["theatres"]
    assert committed_ref == reference
    committed = yaml.safe_load(A.DEFAULT_PRESETS.read_text(encoding="utf-8"))["channels_collection"]
    for name, collection in A.collections_from_reference(reference).items():
        assert committed[name] == collection, name
    aliases = [alias for name, col in committed.items() if name.startswith("airports-") for alias in col]
    assert len(aliases) == len(set(aliases)), "an alias held by two collections resolves to the first one"


def test_two_fields_sharing_a_name_in_one_theatre_both_keep_a_channel() -> None:
    ref = {"Normandy": {7: {"name": "LeMolay", "vhf": 118.0}, 9: {"name": "LeMolay", "vhf": 119.0}}}
    assert A.collections_from_reference(ref)["airports-normandy"] == {
        "LeMolay [7]": {"title": "LeMolay", "freqs": {"vhf": 118.0}},
        "LeMolay [9]": {"title": "LeMolay", "freqs": {"vhf": 119.0}},
    }
