"""Names the VEAF scripts call must exist where they are looked up.

Two defects found in game on 2026-10-03 (FIX-IN-GAME-SESSION-2026-10-03), both invisible to the Lua
suite because the mocks or the call paths agreed with the mistake:

* **DCS colour enums.** DCS names its colours `trigger.smokeColor.Red`, `.Green`, `.White`,
  `.Orange`, `.Blue` and `trigger.flareColor.Green`, `.Red`, `.White`, `.Yellow` — capitalised, not
  upper case (read in game: `Blue=4 Green=0 Orange=3 Red=1 White=2`, `Green=0 Red=1 White=2
  Yellow=3`). Eleven sites wrote `RED`, `GREEN`, `WHITE`…, which is `nil`: every smoke and coloured
  flare asked from a map marker or a FARP died in `trigger.action.smoke` with "Parameter #2 (color)
  missed". The parser test compared `nil` to `trigger.smokeColor.RED`, itself `nil`, and passed.
* **Logger methods.** `veaf.Logger` has `warn`, not `warning`. Two call sites used `warning`; the one
  in AirWaves sits in the branch that reports a failed wave deployment, so the report itself raised,
  and the raise stopped the zone's check loop for good.

The check is a static sweep over `src/scripts/veaf/` with comments and strings stripped, the same
approach as `test_lua_module_calls_resolve.py`.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).parents[2] / "src" / "scripts" / "veaf"
VEAF_LUA = SCRIPTS / "veaf.lua"

#: What DCS answers, measured in game on 2026-10-03.
DCS_ENUMS = {
    "smokeColor": {"Green", "Red", "White", "Orange", "Blue"},
    "flareColor": {"Green", "Red", "White", "Yellow"},
}

_ENUM_USE = re.compile(r"\btrigger\.(smokeColor|flareColor)\.([A-Za-z_]+)")
_LOGGER_METHOD_DEF = re.compile(r"^\s*function\s+veaf\.Logger:([A-Za-z_]+)\s*\(", re.M)
_LOGGER_CALL = re.compile(r"veaf\.loggers\s*\.get\([^()]*(?:\([^()]*\)[^()]*)*\)\s*:([A-Za-z_]+)\s*\(")
#: `local logger = veaf.loggers.get(...)`: the alias, whose calls are then checked by name
_LOGGER_ALIAS = re.compile(r"\blocal\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*veaf\.loggers\s*\.get\(")


def _logger_calls(lua: str) -> list[str]:
    """Every method called on a logger, directly or through a local holding one."""
    methods = _LOGGER_CALL.findall(lua)
    for alias in set(_LOGGER_ALIAS.findall(lua)):
        methods += re.findall(r"\b" + re.escape(alias) + r"\s*:([A-Za-z_]+)\s*\(", lua)
    return methods


def _strip(lua: str) -> str:
    """Remove Lua comments and string literals, so text that mentions a name is not a use of it."""
    lua = re.sub(r"--\[(=*)\[.*?\]\1\]", "", lua, flags=re.S)
    lua = re.sub(r"\[(=*)\[.*?\]\1\]", '""', lua, flags=re.S)
    lua = re.sub(r"--[^\n]*", "", lua)
    lua = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', lua)
    return re.sub(r"'(?:\\.|[^'\\\n])*'", "''", lua)


def _sources() -> dict[str, str]:
    return {p.name: _strip(p.read_text(encoding="utf-8")) for p in sorted(SCRIPTS.glob("*.lua"))}


class TestLuaNamesThatExist(unittest.TestCase):
    """Every DCS enum key and every logger method the scripts use is one that exists."""

    def test_dcs_colour_keys_are_the_ones_dcs_defines(self) -> None:
        """A `trigger.smokeColor.X` / `trigger.flareColor.X` must name a key DCS has."""
        offenders = [
            f"{name}: trigger.{enum}.{key}"
            for name, lua in _sources().items()
            for enum, key in _ENUM_USE.findall(lua)
            if key not in DCS_ENUMS[enum]
        ]
        self.assertEqual(offenders, [])

    def test_logger_methods_are_defined_by_veaf_logger(self) -> None:
        """A `veaf.loggers.get(...):m(` must call a method `veaf.Logger` defines."""
        defined = set(_LOGGER_METHOD_DEF.findall(VEAF_LUA.read_text(encoding="utf-8")))
        self.assertIn("warn", defined)
        offenders = sorted(
            {
                f"{name}: :{method}("
                for name, lua in _sources().items()
                for method in _logger_calls(lua)
                if method not in defined
            }
        )
        self.assertEqual(offenders, [])


if __name__ == "__main__":
    unittest.main()
