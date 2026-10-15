"""The build warns about a catalogue template whose type DCS does not know (FIX-OPEN-TRAINING-MARIANAS-FINDINGS ticket 04).

`A-4E-C`, `Bronco-OV-10A` and `T-45` were shipped as dynamic slots: three community mods, offered to every
mission, which a pilot without them sees as an unflyable slot.
"""

from pathlib import Path

from aircrafts_injector.catalogue import unknown_unit_types
from veaf_tools.commands.build import warn_unknown_aircraft_types


def _catalogue(*types: str) -> dict:
    groups = {
        f"{unit_type} Template": {"units": {1: {"type": unit_type, "name": f"{unit_type} #01"}}} for unit_type in types
    }
    return {"airplanes": {"coalitions": {"blue": {"CJTF Blue": groups}}}}


def test_a_mod_is_named_and_a_known_type_is_not() -> None:
    assert unknown_unit_types(_catalogue("F-16C_50", "A-4E-C")) == [("A-4E-C Template", "A-4E-C")]


def test_a_catalogue_of_known_types_names_nothing() -> None:
    assert unknown_unit_types(_catalogue("F-16C_50", "J-11A")) == []


def test_the_build_warns_once_per_template(tmp_path: Path) -> None:
    path = tmp_path / "dynamic-slot-templates.yaml"
    path.write_text(
        "airplanes:\n  coalitions:\n    blue:\n      CJTF Blue:\n        T-45 Template:\n"
        "          units:\n            1:\n              type: T-45\n",
        encoding="utf-8",
    )
    warnings = warn_unknown_aircraft_types(path)
    assert len(warnings) == 1
    assert "T-45" in warnings[0] and "dynamic-slot-templates.yaml" in warnings[0]
