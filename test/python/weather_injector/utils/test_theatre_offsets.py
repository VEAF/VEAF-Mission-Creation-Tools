"""Tests for the DCS theatre clock offsets used to place solar times.

Why this exists (FIX-SCRATCH-MISSION-FINDINGS ticket 02): DCS reads ``mission.start_time`` as the
theatre's local clock, and solar times were computed in UTC. Caucasus v6 ``dawn-broken`` started at
01:28, pitch dark in DCS.
"""

from __future__ import annotations

import re
import unittest
from datetime import date as dt_date
from pathlib import Path

from weather_injector.utils.theatre_offsets import THEATRE_UTC_OFFSETS, theatre_utc_offset

_REPO_ROOT = Path(__file__).resolve().parents[4]


class TestTheatreUtcOffset(unittest.TestCase):
    JUNE = dt_date(1980, 6, 1)

    def test_known_theatre_uses_the_fixed_table(self) -> None:
        self.assertEqual(theatre_utc_offset("Caucasus", "Asia/Tbilisi", self.JUNE), 4)

    def test_germany_cold_war_is_utc_plus_two(self) -> None:
        # Measured in DCS on 2026-09-24 (dawn at 04:58 on 1980-06-01 at Ramstein, sunrise 03:28 UTC)
        self.assertEqual(theatre_utc_offset("GermanyCW", "Europe/Berlin", self.JUNE), 2)

    def test_known_theatre_ignores_the_declared_timezone(self) -> None:
        # DCS keeps a fixed offset; the IANA zone's daylight saving time must not leak in
        self.assertEqual(theatre_utc_offset("Nevada", "America/Los_Angeles", self.JUNE), -8)

    def test_unknown_theatre_falls_back_to_the_declared_timezone(self) -> None:
        self.assertEqual(theatre_utc_offset("Iraq", "Asia/Baghdad", dt_date(2024, 1, 15)), 3)

    def test_no_theatre_falls_back_to_the_declared_timezone(self) -> None:
        self.assertEqual(theatre_utc_offset(None, "Asia/Tbilisi", self.JUNE), 4)

    def test_unknown_theatre_and_bad_timezone_gives_utc(self) -> None:
        self.assertEqual(theatre_utc_offset(None, "Not/AZone", self.JUNE), 0)


class TestTableMatchesTheLuaRuntime(unittest.TestCase):
    """The build and the in-game scripts must agree on each theatre's clock."""

    def test_python_table_equals_veaf_time_get_timezone(self) -> None:
        veaf_lua = (_REPO_ROOT / "src/scripts/veaf/veaf.lua").read_text(encoding="utf-8")
        time_lua = (_REPO_ROOT / "src/scripts/veaf/veafTime.lua").read_text(encoding="utf-8")
        names_block = re.search(r"veaf\.theatreName = \{(.*?)\n\}", veaf_lua, re.S)
        assert names_block is not None
        names = dict(re.findall(r'(\w+) = "(\w+)"', names_block.group(1)))
        branches = re.findall(
            r"sTheatre == veaf\.theatreName\.(\w+) then\s+nTimezoneOffset = (-?[\d.]+)",
            time_lua,
        )
        lua_offsets = {names[key]: float(value) for key, value in branches}
        self.assertEqual(lua_offsets, {k: float(v) for k, v in THEATRE_UTC_OFFSETS.items()})


if __name__ == "__main__":
    unittest.main()
