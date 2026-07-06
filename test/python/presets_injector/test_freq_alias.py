"""Tests for the convert-v5 frequency→alias catalog and reverse-lookup."""

from __future__ import annotations

from presets_injector.freq_alias import (
    VEAF_GENERIC_CATALOG,
    alias_for,
    apply_aliasing,
    build_catalog,
    build_reverse_index,
    load_airfield_catalog,
)


def test_reverse_index_generic_channels():
    idx = build_reverse_index(VEAF_GENERIC_CATALOG)
    assert idx[("uhf", 243.0)] == "Guard"
    assert idx[("vhf", 120.0)] == "Archer"
    assert idx[("uhf", 390.0)] == "Archer"
    assert idx[("uhf", 290.1)] == "Texaco-1"


def test_alias_for_matches_and_misses():
    idx = build_reverse_index(VEAF_GENERIC_CATALOG)
    assert alias_for(idx, "uhf", 243.0) == "Guard"
    assert alias_for(idx, "uhf", 400.0) is None
    assert alias_for(idx, "fm", 243.0) is None  # right freq, wrong band


def test_load_airfield_catalog_caucasus():
    cat = load_airfield_catalog("Caucasus")
    assert cat["Gudauta"]["freqs"]["uhf"] == 259.0
    assert cat["Batumi"]["freqs"] == {"uhf": 260.0, "vhf": 131.0, "fm": 40.4}


def test_load_airfield_catalog_none_or_unknown():
    assert load_airfield_catalog(None) == {}
    assert load_airfield_catalog("NoSuchTheatre") == {}


def test_build_catalog_merges_airfields_and_generic():
    cat = build_catalog("Caucasus")
    assert "Guard" in cat and "Gudauta" in cat
    idx = build_reverse_index(cat)
    assert alias_for(idx, "uhf", 259.0) == "Gudauta"  # airfield
    assert alias_for(idx, "uhf", 243.0) == "Guard"  # generic


def test_apply_aliasing_radios_and_channel_lists_generic():
    output = {
        "radios_collection": {
            "blue_radios": {
                "radio_uhf_blue": {"title": "UHF", "type": "uhf", "channels": {1: 243.0, 2: 390.0, 3: 999.0}},
            }
        },
        "channel_lists": {"blue": {"primary_1": {"01": 243.0}, "primary_2": {"01": 120.0}}},
    }
    cc = apply_aliasing(output, None)
    chans = output["radios_collection"]["blue_radios"]["radio_uhf_blue"]["channels"]
    assert chans[1] == "Guard"
    assert chans[2] == "Archer"
    assert chans[3] == 999.0  # unmatched frequency stays raw
    cl = output["channel_lists"]["blue"]
    assert cl["primary_1"]["01"] == "Guard"
    assert cl["primary_2"]["01"] == "Archer"
    assert set(cc["aliases"]) == {"Guard", "Archer"}
    assert output["channels_collection"] == cc


def test_apply_aliasing_no_match_inserts_nothing():
    output = {"radios_collection": {"c": {"r": {"type": "uhf", "channels": {1: 999.0}}}}}
    assert apply_aliasing(output, None) == {}
    assert "channels_collection" not in output


def test_apply_aliasing_airfield_with_theatre():
    output = {"radios_collection": {"c": {"r": {"type": "uhf", "channels": {1: 259.0}}}}}
    cc = apply_aliasing(output, "Caucasus")
    assert output["radios_collection"]["c"]["r"]["channels"][1] == "Gudauta"
    assert "Gudauta" in cc["aliases"]
