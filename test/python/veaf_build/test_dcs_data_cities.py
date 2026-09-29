"""Tests for the city lists generated from DCS installs (FIX-IN-GAME-TEST-FINDINGS 05).

GermanyCW-v6 logged `no cities in veafNamedPoints for theatre GermanyCW` (2026-09-28): the six
lists were typed into veafNamedPoints.lua once, and no theatre added since had one.
"""

from __future__ import annotations

from pathlib import Path

from veaf_build.dcs_data import cities as C

_TOWNS = (
    'local gettext = require("i_18n")\n'
    "towns = {\n"
    '["Berlin"] = { latitude = 52.517036, longitude = 13.388860, display_name = _("Berlin")},\n'
    '["Rostock"] = { latitude = 54.092444, longitude = 12.128612, display_name = _("Rostock")},\n'
    '["Rostock"] = { latitude = 54.1, longitude = -12.2, display_name = _("Rostock")},\n'
    "}\n"
)


def _install(root: Path, folder: str, self_id: str, towns: str = _TOWNS) -> Path:
    terrain = root / "Mods" / "terrains" / folder
    (terrain / "Map").mkdir(parents=True)
    (terrain / "entry.lua").write_text(
        f'local self_ID = "{self_id}";\ndeclare_plugin(self_ID, theatre);\n', encoding="utf-8"
    )
    (terrain / "Map" / "towns.lua").write_text(towns, encoding="utf-8")
    return root


def test_parse_keeps_the_last_duplicate_as_lua_does() -> None:
    towns = C.parse_towns(_TOWNS)
    assert towns["Berlin"] == (52.517036, 13.38886)
    assert towns["Rostock"] == (54.1, -12.2)


def test_the_theatre_is_the_terrain_self_id_not_its_folder(tmp_path: Path) -> None:
    root = _install(tmp_path, "GermanyColdWar", "GermanyCW")
    assert set(C.extract_cities(root)) == {"GermanyCW"}


def test_a_theatre_no_install_has_is_kept(tmp_path: Path) -> None:
    yaml_path, lua_path = tmp_path / "cities.yaml", tmp_path / "veafCities.lua"
    C.write_yaml({"Falklands": {"Stanley": (-51.69, -57.86)}}, yaml_path)
    replaced = C.generate([_install(tmp_path / "dcs", "GermanyColdWar", "GermanyCW")], yaml_path, lua_path)
    assert replaced == {"GermanyCW": 2}
    assert set(C.load_yaml(yaml_path)) == {"Falklands", "GermanyCW"}
    lua = lua_path.read_text(encoding="utf-8")
    assert 'veafCities["Falklands"]' in lua and 'veafCities["GermanyCW"]' in lua
    assert '["Berlin"] = { latitude = 52.517036, longitude = 13.388860, display_name = "Berlin" },' in lua


def test_the_committed_lua_is_the_render_of_the_committed_yaml() -> None:
    """The drift guard: veafCities.lua is never edited by hand."""
    assert C.DEFAULT_LUA.read_text(encoding="utf-8") == C.render_lua(C.load_yaml(C.DEFAULT_YAML))


def test_every_theatre_veaf_names_that_an_install_had_has_cities() -> None:
    theatres = C.load_yaml(C.DEFAULT_YAML)
    for theatre in ("Caucasus", "PersianGulf", "TheChannel", "Syria", "MarianaIslands", "Falklands"):
        assert theatres.get(theatre), f"{theatre} lost its cities"
    for theatre in ("GermanyCW", "SinaiMap", "Normandy", "Afghanistan"):
        assert theatres.get(theatre), f"{theatre} has no cities"
