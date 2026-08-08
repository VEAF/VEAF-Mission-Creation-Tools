"""FIX-RADIO-LAYOUT-GAPS ticket 01 — a radio-compass is not a comm radio.

`_classify_radio` returned None for anything that never reaches above the FM ceiling, and
`_assign_roles_by_position` handed every such radio the FM role. That is right for an actual
FM set, and wrong for an ADF: the Ka-50's ARK-22 and the MiG-29's ARK-19 sit entirely below
2 MHz, so a 30-channel FM list was projected onto a radio-compass. Every channel was then
reported out of range and dropped, and the kneeboard advertised a radio the aircraft has not.

The fix belongs in the default classification rather than in four per-type layout entries,
because an airframe added by a future DCS patch with an ADF would hit it again.
"""

from __future__ import annotations

import pytest
from presets_injector.presets_manager import _assign_roles_by_position, _classify_radio
from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec


def _radio(name: str, *ranges: tuple[float, float], modulation: str = "AM/FM") -> RadioSpec:
    return RadioSpec(
        name=name,
        ranges=[FrequencyRange(min_mhz=lo, max_mhz=hi, modulation=modulation) for lo, hi in ranges],
    )


# The real ranges, as `dcs-radio-specs.yaml` carries them.
_ARK_22 = _radio("ARK-22", (0.15, 1.75))  # Ka-50 / Ka-50_3
_ARK_19 = _radio("ARK-19", (0.15, 1.2995))  # MiG-29 Fulcrum
_ARK_15M = _radio("ARK-15M", (0.15, 1.3))  # Yak-52
_R_800 = _radio("R-800L1", (100.0, 400.0))  # a real comm radio, for contrast
_FM_RADIO = _radio("AN/ARC-186 FM", (30.0, 87.975), modulation="FM")


class TestClassification:
    @pytest.mark.parametrize("adf", [_ARK_22, _ARK_19, _ARK_15M], ids=["ARK-22", "ARK-19", "ARK-15M"])
    def test_an_adf_is_not_classified_as_a_comm_radio(self, adf: RadioSpec) -> None:
        assert _classify_radio(adf.ranges) == "non_comm"

    def test_a_real_fm_radio_is_still_fm(self) -> None:
        """The distinction has to be narrow: an FM set must keep attracting the FM role."""
        assert _classify_radio(_FM_RADIO.ranges) is None

    def test_a_vhf_uhf_radio_is_unaffected(self) -> None:
        assert _classify_radio(_R_800.ranges) in {"uhf", "vhf", "ambiguous"}


class TestRoleAssignment:
    def test_ka50_adf_gets_no_role_while_radio_one_keeps_its_own(self) -> None:
        roles = _assign_roles_by_position([_R_800, _ARK_22])
        assert 0 in roles, "the comm radio must still be assigned"
        assert 1 not in roles, "the ARK-22 is a radio-compass and must get no channel list"

    def test_mig29_adf_gets_no_role(self) -> None:
        roles = _assign_roles_by_position([_R_800, _ARK_19])
        assert 1 not in roles

    def test_an_fm_radio_still_gets_a_role(self) -> None:
        """Guards the blast radius: this fix must not silence genuine FM supplements."""
        roles = _assign_roles_by_position([_R_800, _FM_RADIO])
        assert 1 in roles
        assert "fm" in roles[1]

    def test_an_aircraft_whose_only_radio_is_an_adf_gets_nothing(self) -> None:
        assert _assign_roles_by_position([_ARK_15M]) == {}
