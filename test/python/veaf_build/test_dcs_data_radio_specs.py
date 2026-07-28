"""Unit tests for the DCS radio-specs extractor (veaf_build.radio_specs_updater).

Focus: the ``HumanRadio`` block, which bounds a group's *primary* frequency and is a
distinct — sometimes far narrower — constraint than ``panelRadio.range``
(FIX-PRIMARY-FREQ-HUMANRADIO).
"""

from veaf_build.radio_specs_updater import (
    AircraftRadio,
    AircraftSpec,
    FrequencyRange,
    HumanRadio,
    _primary_frequency_section,
    parse_human_radio,
    specs_to_yaml_dict,
)

# Verbatim from the datamine dump of FW-190A8: a 38-156 MHz preset range against a
# 38.4-42.4 MHz primary. Promoting a 134 MHz preset channel here makes DCS refuse to save.
_FW190_LUA = """
return {
    Name = "FW-190A8",
    HumanRadio = {
        editable = true,
        frequency = 38.4,
        maxFrequency = 42.4,
        minFrequency = 38.4,
        modulation = 0
    },
    panelRadio = { {
        ID = "FuG16",
        name = "FuG 16 Z",
        range = { max = 156, min = 38 }
    } }
}
"""

_NO_HUMAN_RADIO_LUA = """
return {
    Name = "SomeAiOnlyPlane",
    panelRadio = { { name = "R-800", range = { max = 156, min = 100 } } }
}
"""

_UNBOUNDED_LUA = """
return {
    Name = "Unbounded",
    HumanRadio = {
        editable = true,
        frequency = 251.0,
        modulation = 0
    }
}
"""

_FM_LUA = """
return {
    HumanRadio = {
        frequency = 30.0,
        maxFrequency = 87.975,
        minFrequency = 30.0,
        modulation = 1
    }
}
"""


class TestParseHumanRadio:
    def test_extracts_bounds_default_and_modulation(self) -> None:
        human_radio = parse_human_radio(_FW190_LUA)
        assert human_radio == HumanRadio(min_mhz=38.4, max_mhz=42.4, default_mhz=38.4, modulation="AM")

    def test_default_frequency_is_not_confused_with_bounds(self) -> None:
        # `frequency` must not greedily match `maxFrequency` / `minFrequency`.
        human_radio = parse_human_radio(_FW190_LUA)
        assert human_radio is not None
        assert human_radio.default_mhz == 38.4

    def test_modulation_one_maps_to_fm(self) -> None:
        human_radio = parse_human_radio(_FM_LUA)
        assert human_radio is not None
        assert human_radio.modulation == "FM"

    def test_absent_block_returns_none(self) -> None:
        assert parse_human_radio(_NO_HUMAN_RADIO_LUA) is None

    def test_block_without_bounds_returns_none(self) -> None:
        # No min/max means the airframe sets no primary bound — nothing to enforce.
        assert parse_human_radio(_UNBOUNDED_LUA) is None


def _spec(dcs_id: str, radio_range: tuple[float, float], human: HumanRadio | None) -> AircraftSpec:
    return AircraftSpec(
        dcs_id=dcs_id,
        display_name=dcs_id,
        category="plane",
        radios=[AircraftRadio(name="R", ranges=[FrequencyRange(min_mhz=radio_range[0], max_mhz=radio_range[1])])],
        human_radio=human,
    )


class TestSpecsToYamlDict:
    def test_human_radio_is_emitted_when_present(self) -> None:
        spec = _spec("FW-190A8", (38.0, 156.0), HumanRadio(38.4, 42.4, 38.4, "AM"))
        entry = specs_to_yaml_dict([spec])["FW-190A8"]
        assert entry["human_radio"] == {
            "min_mhz": 38.4,
            "max_mhz": 42.4,
            "default_mhz": 38.4,
            "modulation": "AM",
        }

    def test_key_is_omitted_when_absent(self) -> None:
        entry = specs_to_yaml_dict([_spec("NoBound", (100.0, 150.0), None)])["NoBound"]
        assert "human_radio" not in entry


class TestPrimaryFrequencySection:
    def test_lists_only_aircraft_narrower_than_their_preset_range(self) -> None:
        specs = [
            _spec("FW-190A8", (38.0, 156.0), HumanRadio(38.4, 42.4, 38.4, "AM")),
            _spec("F-16C_50", (225.0, 399.975), HumanRadio(30.0, 399.975, 305.0, "AM")),
            _spec("NoBound", (100.0, 150.0), None),
        ]
        section = "\n".join(_primary_frequency_section(specs))
        assert "FW-190A8" in section
        assert "F-16C_50" not in section
        assert "NoBound" not in section

    def test_notes_when_nothing_is_restricted(self) -> None:
        section = "\n".join(_primary_frequency_section([_spec("NoBound", (100.0, 150.0), None)]))
        assert "No aircraft in this dataset restricts its primary frequency." in section
