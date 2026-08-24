"""Tests for veaf_libs.briefing_variables — FEAT-BRIEFING-METAR (#40, open since 2021).

A briefing cannot show the weather the mission was built with, because the mission is rebuilt from a
compiled source each time and anything typed by hand is overwritten. These cover the substitution pass
that closes that gap, and in particular the two things the lot said to check first: **which** briefing
(the text lives in the l10n dictionary, not in ``mission``) and **per build variant**.
"""

from __future__ import annotations

from pathlib import Path

from mission_tools.miz_tools import DcsMission
from veaf_libs import briefing_variables as bv


def _mission(fields: dict[str, str], dictionary: dict[str, str] | None = None) -> DcsMission:
    """A mission carrying the given description fields, and optionally a dictionary."""
    return DcsMission(
        file_path=Path("unused.miz"),
        mission_content=dict(fields),
        dictionary_content=dict(dictionary) if dictionary is not None else None,
    )


class TestSubstitute:
    def test_a_known_token_is_replaced(self):
        assert bv.substitute("Weather: ${METAR}", {"METAR": "LFRS 121030Z 22015KT"}) == "Weather: LFRS 121030Z 22015KT"

    def test_several_occurrences_are_all_replaced(self):
        out = bv.substitute("${A} then ${A}", {"A": "x"})
        assert out == "x then x"

    def test_an_unknown_token_is_left_exactly_as_written(self):
        # Player-facing text: `${METRA}` tells a mission maker he mistyped, a hole tells him nothing and
        # looks like the build ate his prose.
        assert bv.substitute("Weather: ${METRA}", {"METAR": "x"}) == "Weather: ${METRA}"

    def test_prose_with_no_token_is_untouched(self):
        assert bv.substitute("Take off at dawn.", {"METAR": "x"}) == "Take off at dawn."

    def test_empty_text_is_returned_as_is(self):
        assert bv.substitute("", {"METAR": "x"}) == ""

    def test_a_stray_brace_is_not_mistaken_for_a_variable(self):
        # A narrow name pattern on purpose: a shell-ish default or an unclosed brace in prose must not be
        # mangled, because there is no way to tell the mission maker it happened.
        for text in ("${", "${}", "$ {METAR}", "${foo:-bar}", "{METAR}", "${1BAD}"):
            assert bv.substitute(text, {"METAR": "x", "foo": "y"}) == text, text

    def test_a_replacement_containing_a_token_is_not_re_expanded(self):
        # No nesting, deliberately: a METAR is data, and data that happens to contain `${` must not be
        # interpreted. re.sub replaces in one pass, and this pins that.
        assert bv.substitute("${A}", {"A": "${B}", "B": "boom"}) == "${B}"


class TestSubstituteInMission:
    def test_inline_prose_is_substituted(self):
        m = _mission({"descriptionText": "METAR: ${METAR}"})
        assert bv.substitute_in_mission(m, {"METAR": "LFRS 22015KT"}) == 1
        assert m.mission_content["descriptionText"] == "METAR: LFRS 22015KT"

    def test_the_dictionary_is_where_a_saved_mission_keeps_its_briefing(self):
        # The lot's first "check this first": `mission` holds a key, the prose is in l10n/DEFAULT.
        # A pass that only looked at `mission` would find the key and replace nothing at all.
        m = _mission(
            {"descriptionText": "DictKey_descriptionText_1"},
            {"DictKey_descriptionText_1": "Weather: ${METAR}"},
        )
        assert bv.substitute_in_mission(m, {"METAR": "LFRS 22015KT"}) == 1
        assert m.dictionary_content["DictKey_descriptionText_1"] == "Weather: LFRS 22015KT"

    def test_the_dictionary_key_itself_is_never_rewritten(self):
        # Substituting into the key would rename the entry and lose the briefing outright.
        m = _mission(
            {"descriptionText": "DictKey_descriptionText_1"},
            {"DictKey_descriptionText_1": "Weather: ${METAR}"},
        )
        bv.substitute_in_mission(m, {"METAR": "x"})
        assert m.mission_content["descriptionText"] == "DictKey_descriptionText_1"

    def test_all_four_description_fields_are_covered(self):
        # A mission maker writing ${METAR} in the blue task has no reason to expect different behaviour,
        # and three fields out of four reads as a bug rather than a scope decision.
        m = _mission({field: "w: ${METAR}" for field in bv.BRIEFING_FIELDS})
        assert bv.substitute_in_mission(m, {"METAR": "ok"}) == 4
        for field in bv.BRIEFING_FIELDS:
            assert m.mission_content[field] == "w: ok"

    def test_a_mixed_mission_substitutes_both_shapes(self):
        m = _mission(
            {"descriptionText": "DictKey_descriptionText_1", "descriptionBlueTask": "blue ${METAR}"},
            {"DictKey_descriptionText_1": "situation ${METAR}"},
        )
        assert bv.substitute_in_mission(m, {"METAR": "ok"}) == 2
        assert m.dictionary_content["DictKey_descriptionText_1"] == "situation ok"
        assert m.mission_content["descriptionBlueTask"] == "blue ok"

    def test_nothing_to_do_reports_zero_rather_than_touching_anything(self):
        m = _mission({"descriptionText": "no tokens here"})
        assert bv.substitute_in_mission(m, {"METAR": "x"}) == 0
        assert m.mission_content["descriptionText"] == "no tokens here"

    def test_a_mission_with_no_content_is_not_a_crash(self):
        m = DcsMission(file_path=Path("unused.miz"), mission_content=None)
        assert bv.substitute_in_mission(m, {"METAR": "x"}) == 0

    def test_a_mission_with_no_dictionary_still_substitutes_inline_text(self):
        m = _mission({"descriptionText": "w ${METAR}"}, dictionary=None)
        assert bv.substitute_in_mission(m, {"METAR": "ok"}) == 1

    def test_a_non_string_field_is_skipped_rather_than_raising(self):
        m = _mission({"descriptionText": "w ${METAR}"})
        m.mission_content["descriptionBlueTask"] = None  # type: ignore[assignment]
        m.mission_content["descriptionRedTask"] = 42  # type: ignore[assignment]
        assert bv.substitute_in_mission(m, {"METAR": "ok"}) == 1


class TestUnknownTokens:
    def test_it_names_what_could_not_be_supplied(self):
        m = _mission({"descriptionText": "${METAR} ${ERA}"})
        assert bv.unknown_tokens(m, {"METAR": "x"}) == ["ERA"]

    def test_it_looks_through_the_dictionary_too(self):
        m = _mission({"descriptionText": "K"}, {"K": "${ERA}"})
        assert bv.unknown_tokens(m, {}) == ["ERA"]

    def test_it_reports_each_name_once_sorted(self):
        m = _mission({"descriptionText": "${B} ${A} ${B}"})
        assert bv.unknown_tokens(m, {}) == ["A", "B"]

    def test_a_fully_supplied_briefing_reports_nothing(self):
        m = _mission({"descriptionText": "${METAR}"})
        assert bv.unknown_tokens(m, {"METAR": "x"}) == []


class TestApplyAndReport:
    def test_it_warns_about_what_it_could_not_supply(self, caplog):
        # The case that will actually happen: a variant built from individual weather parameters has no
        # METAR string to insert, so the token survives. Saying why beats letting the mission maker find
        # it in the briefing and conclude the feature is broken.
        m = _mission({"descriptionText": "${METAR}"})
        with caplog.at_level("WARNING"):
            assert bv.apply_and_report(m, {}, context="night") == 0
        assert "METAR" in caplog.text
        assert "night" in caplog.text

    def test_it_says_nothing_when_everything_resolved(self, caplog):
        m = _mission({"descriptionText": "${METAR}"})
        with caplog.at_level("WARNING"):
            assert bv.apply_and_report(m, {"METAR": "ok"}, context="day") == 1
        assert "could not be supplied" not in caplog.text

    def test_the_leftovers_are_computed_before_substituting(self):
        # Order matters: computing them afterwards would find nothing, because a supplied token is gone
        # by then and an unsupplied one is indistinguishable from prose that always said `${X}`.
        m = _mission({"descriptionText": "${METAR} ${ERA}"})
        bv.apply_and_report(m, {"METAR": "ok"})
        assert m.mission_content["descriptionText"] == "ok ${ERA}"
