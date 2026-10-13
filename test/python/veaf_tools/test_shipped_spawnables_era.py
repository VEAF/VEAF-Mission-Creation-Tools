"""The shipped spawnables catalogue is filtered by the mission's era (FIX-OPEN-TRAINING-NORMANDY-FINDINGS ticket 03).

A WW2 mission built with an empty `src/spawnables.yaml` was given the 51 modern jets of the shipped catalogue —
F-15C, MiG-25, Mirage F1, MQ-9 — in its `-cap`, `-escort` and `_spawn` templates.
"""

import json
from pathlib import Path
from tempfile import TemporaryDirectory

import yaml
from aircrafts_injector.catalogue import AIRCRAFT_ERAS, filter_by_era, iter_groups, load_catalogue
from veaf_tools.commands.build import era_filtered_catalogue

SHIPPED = Path(__file__).parents[3] / "src" / "defaults" / "mission-folder" / "src" / "spawnables.yaml"


def _types(catalogue: dict) -> set[str]:
    found = set()
    for _ref, group in iter_groups(catalogue):
        units = group["units"]
        found.add(next(iter(units.values() if isinstance(units, dict) else units))["type"])
    return found


def test_every_type_of_the_shipped_catalogue_has_its_eras() -> None:
    """Enumerated, not sampled: a type added to the catalogue and not here would pass into every era."""
    assert _types(load_catalogue(SHIPPED)) <= set(AIRCRAFT_ERAS)


def test_ww2_keeps_none_of_the_shipped_jets() -> None:
    filtered, removed = filter_by_era(load_catalogue(SHIPPED), "WW2")
    assert removed == 51
    assert _types(filtered) == set()


def test_the_cold_war_keeps_the_jets_and_drops_the_drone() -> None:
    filtered, removed = filter_by_era(load_catalogue(SHIPPED), "COLD_WAR")
    assert "MQ-9 Reaper" not in _types(filtered)
    assert {"F-15C", "MiG-25PD", "Mirage-F1EE"} <= _types(filtered)
    assert removed == 1


def test_a_modern_mission_drops_nothing() -> None:
    _filtered, removed = filter_by_era(load_catalogue(SHIPPED), "MODERN")
    assert removed == 0


def test_a_type_the_table_does_not_know_is_kept_in_every_era() -> None:
    catalogue = {"airplanes": {"coalitions": {"blue": {"CJTF Blue": {"g": {"units": {1: {"type": "SomeMod"}}}}}}}}
    assert filter_by_era(catalogue, "WW2")[1] == 0


def test_the_input_catalogue_is_not_modified() -> None:
    catalogue = load_catalogue(SHIPPED)
    before = json.dumps(catalogue, default=str)
    filter_by_era(catalogue, "WW2")
    assert json.dumps(catalogue, default=str) == before


class TestEraFilteredCatalogue:
    def test_ww2_has_nothing_to_inject(self) -> None:
        with TemporaryDirectory() as tmp:
            assert era_filtered_catalogue(SHIPPED, "WW2", Path(tmp)) == (None, 51)

    def test_modern_and_unknown_eras_inject_the_catalogue_as_it_is(self) -> None:
        with TemporaryDirectory() as tmp:
            assert era_filtered_catalogue(SHIPPED, "MODERN", Path(tmp)) == (SHIPPED, 0)
            assert era_filtered_catalogue(SHIPPED, None, Path(tmp)) == (SHIPPED, 0)

    def test_the_cold_war_injects_a_filtered_copy(self) -> None:
        with TemporaryDirectory() as tmp:
            path, removed = era_filtered_catalogue(SHIPPED, "COLD_WAR", Path(tmp))
            assert removed == 1 and path is not None and path.parent == Path(tmp)
            assert "MQ-9 Reaper" not in _types(yaml.safe_load(path.read_text(encoding="utf-8")))

    def test_an_unreadable_file_is_left_to_the_validator(self) -> None:
        with TemporaryDirectory() as tmp:
            broken = Path(tmp) / "spawnables.yaml"
            broken.write_text('airplanes:\n  coalitions:\n    blue:\n      "unterminated\n', encoding="utf-8")
            assert era_filtered_catalogue(broken, "WW2", Path(tmp)) == (broken, 0)

    def test_only_the_shipped_catalogue_is_ever_filtered(self) -> None:
        """`resolve_aircraft_catalogue` reports a maker's own file as not shipped, and the build leaves it as written."""
        build = Path(__file__).parents[3] / "src" / "python" / "veaf-tools" / "veaf_tools" / "commands" / "build.py"
        assert 'if is_shipped and step_key == "spawnable_aircrafts":' in build.read_text(encoding="utf-8")
