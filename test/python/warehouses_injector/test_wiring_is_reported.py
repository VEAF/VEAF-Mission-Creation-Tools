"""FIX-DYNSLOT-WIRING ticket 03 — the step says what the wiring achieved, not only what it wrote.

Every defect this lot fixes was found by writing a throwaway script. The step reported
``13 airport(s) configured, 832 template link(s)`` — a count of writes — and two failure shapes
went through it without a word:

1. **A link that points at nothing.** 65 distinct targets on ``test-import.miz``, not one of them a
   group the mission holds. DCS renders that as ``Group template: None``, which reads like a
   deliberate choice rather than a defect.
2. **Templates with nowhere to be offered from.** A mission built from
   ``prepare --theatre Caucasus --template standard`` injects 128 templates, then reports
   ``0 airport(s) configured``: every airfield of a blank mission is NEUTRAL, so no dynamic slot is
   playable and nothing says why.

A check that cannot fail is not a check, so each warning is proven to fire **and** to stay quiet.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pytest
from mission_tools.miz_tools import DcsMission
from warehouses_injector import apply_warehouses

_BLUE_FIELD = 24
_NEUTRAL_FIELD = 25


def _mission(*, coalition: str = "BLUE", stock: dict | None = None, templates: bool = True) -> DcsMission:
    """A mission with one blue helicopter template and one airfield of the given side."""
    groups = [{"groupId": 2114, "name": "UH-1H Template", "dynSpawnTemplate": True, "units": [{"type": "UH-1H"}]}]
    return DcsMission(
        file_path=Path("dummy.miz"),
        theatre_content="",
        mission_content={
            "coalition": {"blue": {"country": [{"name": "USA", "helicopter": {"group": groups if templates else []}}]}}
        },
        warehouses_content={
            "airports": {
                _BLUE_FIELD: {"coalition": coalition, "dynamicSpawn": False, "aircrafts": stock or {}},
                _NEUTRAL_FIELD: {"coalition": "NEUTRAL", "dynamicSpawn": False, "aircrafts": {}},
            }
        },
    )


class TestDeadLinksAreReported:
    """A link left over on a warehouse the config does not target is still counted."""

    def test_it_fires_on_a_link_pointing_at_nothing(self, caplog: pytest.LogCaptureFixture) -> None:
        mission = _mission(coalition="NEUTRAL", stock={"helicopters": {"UH-1H": {"linkDynTempl": 3853}}})
        with caplog.at_level(logging.WARNING):
            result = apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert result.dead_links == 1
        assert "3853" in caplog.text or "1" in caplog.text

    def test_it_stays_quiet_when_every_link_resolves(self, caplog: pytest.LogCaptureFixture) -> None:
        mission = _mission()
        with caplog.at_level(logging.WARNING):
            result = apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert result.dead_links == 0
        assert result.templates_linked == 1


class TestTemplatesWithNowhereToGo:
    """128 templates and no airfield of a side is the out-of-the-box state of a blank mission."""

    def test_it_fires_when_nothing_was_configured(self, caplog: pytest.LogCaptureFixture) -> None:
        mission = _mission(coalition="NEUTRAL")
        with caplog.at_level(logging.WARNING):
            result = apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert result.airports_configured == 0
        assert result.objects_configured == 0
        assert result.templates_available == 1
        assert caplog.records, "a mission carrying templates and offering none must say so"

    def test_it_stays_quiet_when_an_airfield_belongs_to_a_side(self, caplog: pytest.LogCaptureFixture) -> None:
        mission = _mission()
        with caplog.at_level(logging.WARNING):
            apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert not caplog.records

    def test_it_stays_quiet_when_the_mission_has_no_template_at_all(self, caplog: pytest.LogCaptureFixture) -> None:
        """Nothing was injected, so there is nothing to be unable to offer."""
        mission = _mission(coalition="NEUTRAL", templates=False)
        with caplog.at_level(logging.WARNING):
            result = apply_warehouses(mission, {"blue": {"defaults": {}}})
        assert result.templates_available == 0
        assert not caplog.records
