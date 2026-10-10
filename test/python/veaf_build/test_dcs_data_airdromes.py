"""Tests for the airdrome name->id generator (merges runtime JSON dumps into the YAML)."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import yaml

from veaf_build.dcs_data import airdromes as A

_DUMP = {
    "theatre": "Syria",
    "airbases": [
        {"id": 39, "name": "Tiyas", "lat": 34.5, "lon": 37.6, "coalition": 0},
        {"id": 1, "name": "Abu al-Duhur", "lat": 35.7, "lon": 37.1, "coalition": 0},
        {"id": 23, "name": "Marj Ruhayyil", "lat": 33.2, "lon": 36.4, "coalition": 0},
    ],
}


def test_names_to_ids_projects_and_sorts_by_name() -> None:
    result = A.names_to_ids(_DUMP["airbases"])
    assert result == {"Abu al-Duhur": 1, "Marj Ruhayyil": 23, "Tiyas": 39}
    assert list(result.keys()) == sorted(result.keys())


def test_load_dumps_reads_one_json_per_theatre(tmp_path: Path) -> None:
    (tmp_path / "Syria.json").write_text(json.dumps(_DUMP), encoding="utf-8")
    (tmp_path / "Caucasus.json").write_text(
        json.dumps({"theatre": "Caucasus", "airbases": [{"id": 22, "name": "Batumi"}]}), encoding="utf-8"
    )
    result = A.load_dumps(tmp_path)
    assert result["Caucasus"] == {"Batumi": 22}
    assert result["Syria"]["Tiyas"] == 39


def test_generate_replaces_dumped_theatre_and_preserves_others(tmp_path: Path) -> None:
    """A dumped theatre is regenerated from the dump; a theatre with no dump is kept."""
    out = tmp_path / "airdromes.yaml"
    out.write_text(
        yaml.safe_dump({"theatres": {"Syria": {"WRONG": 99}, "Normandy": {"Carpiquet": 5}}}),
        encoding="utf-8",
    )
    dumps = tmp_path / "dumps"
    dumps.mkdir()
    (dumps / "Syria.json").write_text(json.dumps(_DUMP), encoding="utf-8")

    count = A.generate(dumps, out)

    data = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert data["theatres"]["Syria"] == {"Abu al-Duhur": 1, "Marj Ruhayyil": 23, "Tiyas": 39}
    assert "WRONG" not in data["theatres"]["Syria"]
    assert data["theatres"]["Normandy"] == {"Carpiquet": 5}  # untouched (no dump)
    assert count == 4


def test_generate_drops_legacy_folder_named_duplicate(tmp_path: Path) -> None:
    """A retired Beacons.lua key (folder-named) is dropped once its canonical theatre is dumped."""
    out = tmp_path / "airdromes.yaml"
    out.write_text(
        yaml.safe_dump({"theatres": {"Sinai": {"BEACON_LABEL": 7}, "Normandy": {"Carpiquet": 5}}}),
        encoding="utf-8",
    )
    dumps = tmp_path / "dumps"
    dumps.mkdir()
    (dumps / "SinaiMap.json").write_text(
        json.dumps({"theatre": "SinaiMap", "airbases": [{"id": 12, "name": "Ramon Airbase"}]}), encoding="utf-8"
    )

    A.generate(dumps, out)

    data = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert "Sinai" not in data["theatres"]  # legacy duplicate gone
    assert data["theatres"]["SinaiMap"] == {"Ramon Airbase": 12}
    assert data["theatres"]["Normandy"] == {"Carpiquet": 5}  # unrelated theatre untouched


def test_generate_keeps_legacy_key_until_canonical_is_captured(tmp_path: Path) -> None:
    """The legacy key survives while its canonical theatre has no dump yet (no data loss)."""
    out = tmp_path / "airdromes.yaml"
    out.write_text(yaml.safe_dump({"theatres": {"Sinai": {"SOMETHING": 7}}}), encoding="utf-8")
    dumps = tmp_path / "dumps"
    dumps.mkdir()

    A.generate(dumps, out)

    data = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert data["theatres"]["Sinai"] == {"SOMETHING": 7}


def test_committed_airdromes_has_no_legacy_duplicates() -> None:
    """The committed artifact carries no folder-named leftover for a captured theatre."""
    path = Path(__file__).parents[3] / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "airdromes.yaml"
    theatres = yaml.safe_load(path.read_text(encoding="utf-8"))["theatres"]
    for legacy, canonical in A.LEGACY_THEATRE_ALIASES.items():
        if canonical in theatres:
            assert legacy not in theatres, f"{legacy} duplicates {canonical}"


def test_committed_airdromes_has_caucasus() -> None:
    """The committed artifact resolves a known Caucasus airfield (preserved theatre)."""
    path = Path(__file__).parents[3] / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "airdromes.yaml"
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert data["theatres"]["Caucasus"]["Batumi"] == 22


def test_committed_airdromes_syria_uses_exact_runtime_names() -> None:
    """Syria is sourced from the runtime dump: exact Airbase:getName() values."""
    path = Path(__file__).parents[3] / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "airdromes.yaml"
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    syria = data["theatres"]["Syria"]
    assert syria["Abu al-Duhur"] == 1
    assert syria["Al-Dumayr"] == 9
    assert syria["Tiyas"] == 39


# FIX-SCRATCH-MISSION-FINDINGS ticket 19: no action listed a theatre's airfields with their positions,
# and the dumps that carry them are not shipped — so the generator writes them next to the name table.


def test_generate_writes_the_positions_next_to_the_table(tmp_path: Path) -> None:
    out = tmp_path / "airdromes.yaml"
    dumps = tmp_path / "dumps"
    dumps.mkdir()
    (dumps / "Syria.json").write_text(json.dumps(_DUMP), encoding="utf-8")

    A.generate(dumps, out)

    data = yaml.safe_load((tmp_path / "airdrome-positions.yaml").read_text(encoding="utf-8"))
    assert data["theatres"]["Syria"] == [
        {"name": "Abu al-Duhur", "id": 1, "lat": 35.7, "lon": 37.1},
        {"name": "Marj Ruhayyil", "id": 23, "lat": 33.2, "lon": 36.4},
        {"name": "Tiyas", "id": 39, "lat": 34.5, "lon": 37.6},
    ]


def test_a_record_without_a_position_is_left_out(tmp_path: Path) -> None:
    assert A.positions([{"id": 22, "name": "Batumi"}, {"id": 1, "name": "X", "lat": 1.0, "lon": 2.0}]) == [
        {"name": "X", "id": 1, "lat": 1.0, "lon": 2.0}
    ]


def test_committed_positions_cover_every_dumped_theatre() -> None:
    path = (
        Path(__file__).parents[3] / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "airdrome-positions.yaml"
    )
    theatres = yaml.safe_load(path.read_text(encoding="utf-8"))["theatres"]
    assert set(theatres) == set(A.load_dumps())
    ramstein = next(a for a in theatres["GermanyCW"] if a["name"] == "Ramstein")
    assert isinstance(ramstein["id"], int)


# FEAT-DCS-REFERENCE-DATA ticket 01: the dcs-world-schema reference database carries every airbase of
# 13 theatres with the same names and ids as the runtime dumps, and a reference point that is the
# runways' centre where `Airbase:getPoint()` lands about a kilometre away.


def _reference(*rows: tuple[str, int, str, float, float]) -> sqlite3.Connection:
    """An in-memory reference database holding the given ``(theatre, id, name, lat, lon)`` airbases."""
    connection = sqlite3.connect(":memory:")
    connection.execute("create table airbases (theatre text, airdromeId integer, name text, referencePoint text)")
    connection.executemany(
        "insert into airbases values (?, ?, ?, ?)",
        [(t, i, n, json.dumps({"latitude": lat, "longitude": lon, "x": 0, "z": 0})) for t, i, n, lat, lon in rows],
    )
    return connection


def test_the_reference_airbases_are_read_per_theatre_with_their_reference_point() -> None:
    connection = _reference(("Caucasus", 24, "Kobuleti", 41.9299189, 41.8632749), ("Syria", 39, "Tiyas", 34.5, 37.6))
    result = A.reference_airbases(connection)
    assert result == {
        "Caucasus": [{"id": 24, "name": "Kobuleti", "lat": 41.929919, "lon": 41.863275}],
        "Syria": [{"id": 39, "name": "Tiyas", "lat": 34.5, "lon": 37.6}],
    }


def test_the_reference_wins_over_a_dump_and_a_dump_fills_a_theatre_it_lacks(tmp_path: Path) -> None:
    out = tmp_path / "airdromes.yaml"
    dumps = tmp_path / "dumps"
    dumps.mkdir()
    (dumps / "Syria.json").write_text(json.dumps(_DUMP), encoding="utf-8")
    (dumps / "TheChannel.json").write_text(
        json.dumps(
            {"theatre": "TheChannel", "airbases": [{"id": 1, "name": "Abbeville Drucat", "lat": 50.1, "lon": 1.8}]}
        ),
        encoding="utf-8",
    )
    reference = A.reference_airbases(_reference(("Syria", 39, "Tiyas", 34.6, 37.7)))

    count = A.generate(dumps, out, reference=reference)

    table = yaml.safe_load(out.read_text(encoding="utf-8"))["theatres"]
    assert table["Syria"] == {"Tiyas": 39}
    assert table["TheChannel"] == {"Abbeville Drucat": 1}
    positions = yaml.safe_load((tmp_path / "airdrome-positions.yaml").read_text(encoding="utf-8"))["theatres"]
    assert positions["Syria"] == [{"name": "Tiyas", "id": 39, "lat": 34.6, "lon": 37.7}]
    assert positions["TheChannel"] == [{"name": "Abbeville Drucat", "id": 1, "lat": 50.1, "lon": 1.8}]
    assert count == 2


def test_committed_positions_are_the_reference_points() -> None:
    """Kobuleti sits on its runways' centre (reference point), not on `getPoint()` about 1.2 km away."""
    path = (
        Path(__file__).parents[3] / "src" / "python" / "veaf-tools" / "veaf_libs" / "data" / "airdrome-positions.yaml"
    )
    theatres = yaml.safe_load(path.read_text(encoding="utf-8"))["theatres"]
    kobuleti = next(a for a in theatres["Caucasus"] if a["name"] == "Kobuleti")
    assert (kobuleti["lat"], kobuleti["lon"]) == (41.929919, 41.863275)
    assert any(a["name"] == "Abbeville Drucat" for a in theatres["TheChannel"])
