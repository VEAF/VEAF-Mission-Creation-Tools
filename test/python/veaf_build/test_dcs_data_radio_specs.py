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
    apply_overrides,
    build_primary_block,
    load_overrides,
    parse_display_name,
    parse_human_radio,
    specs_to_yaml_dict,
)

# Condensed from the real datamine dump of F-16C_50 at the pinned ref, keeping the shape that
# matters: the file is one big table indented by a single tab, the **engine** block carries its own
# `type` deeper in, and it appears ~600 lines *before* the top-level one. So a `^\s*type` search
# with re.MULTILINE finds "TurboFan" first — which is how 72 of the reference table's 88 rows came
# to hold engine types under an "Aircraft" heading (FIX-DOCAUDIT-CODE 06).
_F16_LUA = """_G["db"]["Units"]["Planes"]["Plane"]["#Index"] = {
\tAOA_take_off = 0.16,
\tDisplayName = "F-16CM bl.50",
\tEngines = {
\t\tEngine = {
\t\t\thMaxEng = 19,
\t\t\ttype = "TurboFan"
\t\t}
\t},
\tPylons = { {
\t\t\tDisplayName = "5"
\t\t} },
\ttype = "F-16C_50",
\twing_area = 28
}
"""

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


class TestParseDisplayName:
    """The aircraft's readable name, which is `DisplayName` and never `type`.

    Measured over all 170 datamine unit files at the pinned ref: every one carries a
    `DisplayName` at the outermost indentation, and the top-level `type` is the **DCS id**
    (identical to the file name in 168 of them) rather than a display name — so the old
    comment claiming otherwise was wrong twice over.
    """

    def test_the_engine_type_is_not_taken_for_the_aircraft_name(self) -> None:
        assert parse_display_name(_F16_LUA) == "F-16CM bl.50"

    def test_a_nested_display_name_is_not_taken_either(self) -> None:
        # A pylon carries `DisplayName = "5"`, deeper in. Only the outermost one is the aircraft.
        assert parse_display_name(_F16_LUA) != "5"

    def test_the_dcs_id_is_the_last_resort_not_the_first(self) -> None:
        # A dump with neither DisplayName nor Name still yields something usable rather than "".
        assert parse_display_name('return {\n\ttype = "SomeJet"\n}\n') == "SomeJet"

    def test_nothing_recognisable_returns_empty(self) -> None:
        # The caller falls back to the DCS id, so an empty answer must stay distinguishable.
        assert parse_display_name("return {}") == ""


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
        section = "\n".join(build_primary_block(specs, "en"))
        assert "FW-190A8" in section
        assert "F-16C_50" not in section
        assert "NoBound" not in section

    def test_notes_when_nothing_is_restricted(self) -> None:
        section = "\n".join(build_primary_block([_spec("NoBound", (100.0, 150.0), None)], "en"))
        assert "No aircraft has a primary frequency narrower than its preset channels." in section

    def test_the_table_is_localised(self) -> None:
        # The block is data, but its heading and column names are prose: they belong to the page's
        # language. Writing the English wording into the French page is the defect this lot removes.
        specs = [_spec("FW-190A8", (38.0, 156.0), HumanRadio(38.4, 42.4, 38.4, "AM"))]
        assert "Appareils dont la fréquence principale est bridée" in "\n".join(build_primary_block(specs, "fr"))
        assert "Aircraft whose primary frequency is restricted" in "\n".join(build_primary_block(specs, "en"))


class TestOverrides:
    """The overlay the datamine cannot provide (FIX-RADIO-LAYOUT-GAPS ticket 02).

    Two kinds of correction live here, and neither survived a regeneration before: a radio DCS
    accepts but the datamine does not model, and the ``dcs_rejects_on_load`` flag that used to be
    re-applied by hand after every pin bump.
    """

    def test_extra_band_joins_the_named_radio_without_creating_one(self) -> None:
        # A second *radio* would contradict the layout, which declares one -- DCS keeps the whole
        # Viggen fit in a single 47-slot table. So the correction is a band, like A-10C_2's five.
        spec = _spec("AJS37", (103.0, 400.0), None)
        apply_overrides(
            [spec], {"AJS37": {"add_ranges": [{"radio": "R", "min_mhz": 30.0, "max_mhz": 34.0, "modulation": "FM"}]}}
        )
        assert len(spec.radios) == 1
        assert spec.radios[0].ranges[-1] == FrequencyRange(min_mhz=30.0, max_mhz=34.0, modulation="FM")

    def test_band_on_an_unknown_radio_raises(self) -> None:
        import pytest

        with pytest.raises(KeyError, match="NoSuchRadio"):
            apply_overrides(
                [_spec("AJS37", (103.0, 400.0), None)],
                {"AJS37": {"add_ranges": [{"radio": "NoSuchRadio", "min_mhz": 1.0, "max_mhz": 2.0}]}},
            )

    def test_rejects_on_load_flag_is_set_and_emitted(self) -> None:
        spec = _spec("MiG-15bis", (3.75, 5.0), None)
        apply_overrides([spec], {"MiG-15bis": {"dcs_rejects_on_load": True}})
        assert specs_to_yaml_dict([spec])["MiG-15bis"]["dcs_rejects_on_load"] is True

    def test_flag_absent_by_default(self) -> None:
        assert "dcs_rejects_on_load" not in specs_to_yaml_dict([_spec("F-16C_50", (225.0, 400.0), None)])["F-16C_50"]

    def test_whole_aircraft_can_be_declared_when_the_datamine_has_none(self) -> None:
        # The MiG-15bis case: DCS flies it, the datamine models no radio for it, so the entry is
        # ours end to end. It used to live directly in the generated file and was deleted by the
        # first regeneration that ran without it here.
        specs = [_spec("F-16C_50", (225.0, 400.0), None)]
        apply_overrides(
            specs,
            {
                "MiG-15bis": {
                    "add_aircraft": {
                        "name": "RSI-6K",
                        "category": "plane",
                        "radios": [
                            {"name": "RSI-6K", "ranges": [{"min_mhz": 3.75, "max_mhz": 5.0, "modulation": "AM"}]}
                        ],
                    },
                    "dcs_rejects_on_load": True,
                }
            },
        )
        added = next(s for s in specs if s.dcs_id == "MiG-15bis")
        assert added.display_name == "RSI-6K"
        assert added.dcs_rejects_on_load is True
        assert added.radios[0].ranges == [FrequencyRange(min_mhz=3.75, max_mhz=5.0, modulation="AM")]

    def test_shipped_overlay_still_declares_both_mig15bis_entries(self) -> None:
        # Regression guard for the loss this lot found: they are not in the datamine, so nothing
        # else in the pipeline would notice them disappearing.
        overrides = load_overrides()
        for dcs_id in ("MiG-15bis", "MiG-15bis_FC"):
            assert "add_aircraft" in overrides.get(dcs_id, {}), f"{dcs_id} must be declared in full"

    def test_unknown_aircraft_raises_rather_than_passing_silently(self) -> None:
        # A typo in the overlay must not be swallowed: silently doing nothing is how an
        # overlay rots into a lie about data it no longer touches.
        import pytest

        with pytest.raises(KeyError, match="NotAnAircraft"):
            apply_overrides([_spec("F-16C_50", (225.0, 400.0), None)], {"NotAnAircraft": {"dcs_rejects_on_load": True}})

    def test_shipped_overlay_covers_the_ajs37_fm_set(self) -> None:
        overrides = load_overrides()
        assert "AJS37" in overrides, "the AJS-37 FM correction is the reason this file exists"
        bands = overrides["AJS37"]["add_ranges"]
        assert any(b["min_mhz"] <= 33.0 and b["max_mhz"] >= 34.0 for b in bands), (
            "E (33 MHz) and F (34 MHz) must fall inside the declared band"
        )
