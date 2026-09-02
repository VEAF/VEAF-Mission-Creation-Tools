"""The build's acknowledgement of the modules it read — FIX-TUTORIAL-FIRST-RUN ticket 04.

The build used to print one line about its configuration, ``Generated 'veaf-config.lua' from
mission.yaml``, which says nothing about what that configuration contains. A mission maker who
added a combat zone had no confirmation before launching DCS.
"""

from __future__ import annotations

import logging

from mission_builder.mission_builder_worker import MissionBuilderWorker


def _report(yaml_dict: dict, caplog) -> str:
    with caplog.at_level(logging.INFO):
        MissionBuilderWorker._report_active_modules(yaml_dict)
    return caplog.text


def test_the_modules_are_named(caplog) -> None:
    text = _report({"modules": {"SPAWN": True, "RADIO": True}}, caplog)
    assert "SPAWN" in text
    assert "RADIO" in text


def test_a_list_shaped_module_carries_its_count(caplog) -> None:
    text = _report(
        {"modules": {"COMBATZONE": {"enabled": True, "combat_zones": [{"zone_name": "CZ-Alpha"}]}}},
        caplog,
    )
    assert "COMBATZONE (1)" in text


def test_a_declared_but_empty_list_reports_zero(caplog) -> None:
    """The case the line exists for: today this is indistinguishable from a healthy build."""
    text = _report({"modules": {"COMBATZONE": {"enabled": True, "combat_zones": []}}}, caplog)
    assert "COMBATZONE (0)" in text


def test_a_module_without_a_list_carries_no_number(caplog) -> None:
    text = _report({"modules": {"SPAWN": True}}, caplog)
    assert "SPAWN" in text
    assert "SPAWN (" not in text


def test_a_disabled_module_is_not_named(caplog) -> None:
    text = _report({"modules": {"SPAWN": True, "CSAR": False}}, caplog)
    assert "SPAWN" in text
    assert "CSAR" not in text


def test_nothing_configured_says_nothing(caplog) -> None:
    """A message every build prints is a message nobody reads."""
    assert _report({"mission": {"name": "Alpha"}}, caplog) == ""


def test_the_count_matches_the_modules_listed(caplog) -> None:
    text = _report({"modules": {"SPAWN": True, "RADIO": True, "UNITS": None}}, caplog)
    assert "(3)" in text
