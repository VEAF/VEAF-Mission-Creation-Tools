"""Every `veafX.y(...)` call must reach a function that exists somewhere in the scripts.

Written after a live report on 2026-08-22: dropping *any* map marker carrying text answered
"VEAF: your marker command failed". `veafRemote.initialize()` registered a marker command handler
calling `veafRemote.executeCommand`, and that function had been deleted on 2026-08-11 with the
shared-password mechanism it belonged to (9a20c50c, the security review). The registration was left
behind. `veafMarkers.onEvent` calls every registered handler under `pcall`, so the failure surfaced
to the pilot on every annotation for eleven days, and no test could see it: nothing here executes a
whole mission's startup.

Lua cannot catch this — a missing table field is `nil` until something calls it, and that call is a
runtime error in a `pcall` nobody reads. So the check is a static sweep, which is cheap and exact
enough to be worth having: 1166 defined symbols across the scripts and, at the time of writing, one
genuine offender left.

Scope, deliberately narrow to stay free of false positives:

* only `veaf*`-prefixed tables, and only those the scripts define somewhere — a call into MIST, CTLD
  or DCS itself is none of our business
* definitions are collected across **all** files, not per file, because one module legitimately
  spans several (`veafSpawn` lives in `veafSpawnCore`, `veafSpawnGround`, `veafSpawnAircraft`, …)
* strings and comments are stripped first. Three of the first five hits were log labels like
  `string.format("veaf.getAirbaseforCoalition(...)")` and code inside a `[[ ]]` block — text, not
  calls. A checker that cries wolf gets ignored, which is worse than not having it
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).parents[2] / "src" / "scripts" / "veaf"

#: `function veafX.y(` and `function veafX:y(`
_DEF_FUNCTION = re.compile(r"^\s*function\s+(veaf[A-Za-z0-9_]*)[.:]([A-Za-z0-9_]+)", re.M)

#: `veafX.y = ...`, which is how several modules publish a function or a constant
_DEF_ASSIGNMENT = re.compile(r"^\s*(veaf[A-Za-z0-9_]*)\.([A-Za-z0-9_]+)\s*=", re.M)

#: `veafX.y(` — a call, once strings and comments are gone
_CALL = re.compile(r"\b(veaf[A-Za-z0-9_]*)\.([A-Za-z0-9_]+)\s*\(")

#: Long-bracket strings, including `[==[ ]==]`. Non-greedy, and they may span lines.
_LONG_STRING = re.compile(r"\[(=*)\[.*?\]\1\]", re.S)

#: Known offenders, to erode and never to grow — the same ratchet the mypy and coverage gates use.
#:
#: `veafMissileGuardian.GetGuardian` is called by `ActivateGuardian` and `DesactivateGuardian` and
#: was never written. It is left listed rather than papered over: `AddGuardian` next to it does not
#: register anything either (it takes a guardian and returns it), so the module's storage was never
#: finished and inventing a getter would be a guess at what it should hold. Filed as
#: FIX-MISSILEGUARDIAN-NO-STORAGE.
KNOWN_MISSING = {
    "veafMissileGuardian.GetGuardian",
}


def _strip_strings_and_comments(text: str) -> str:
    """Return *text* with Lua strings and comments blanked out.

    Newlines are preserved so that reported line numbers stay true.

    Args:
        text: The Lua source.

    Returns:
        The source with string and comment content replaced by spaces.
    """

    def _blank(match: re.Match[str]) -> str:
        return re.sub(r"[^\n]", " ", match.group(0))

    text = _LONG_STRING.sub(_blank, text)
    out: list[str] = []
    for line in text.split("\n"):
        # a line comment kills the rest of the line
        line = re.sub(r"--.*$", "", line)
        # quoted strings, honouring backslash escapes
        line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
        line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
        out.append(line)
    return "\n".join(out)


def _defined_symbols() -> set[tuple[str, str]]:
    """Return every `(table, field)` the scripts define, across all files."""
    defined: set[tuple[str, str]] = set()
    for path in sorted(SCRIPTS.glob("veaf*.lua")):
        text = path.read_text(encoding="utf-8", errors="replace")
        for pattern in (_DEF_FUNCTION, _DEF_ASSIGNMENT):
            for match in pattern.finditer(text):
                defined.add((match.group(1), match.group(2)))
    return defined


class TestEveryModuleCallResolves(unittest.TestCase):
    """A call on a `veaf*` table must reach something that exists."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.defined = _defined_symbols()
        cls.tables = {table for table, _ in cls.defined}

    def test_the_sweep_actually_reads_the_scripts(self) -> None:
        """Guard against the checker silently scanning nothing.

        A sweep that finds no files passes every other assertion here, which is the failure mode
        this whole file exists to remove.
        """
        self.assertGreater(len(list(SCRIPTS.glob("veaf*.lua"))), 30)
        self.assertGreater(len(self.defined), 800, "far fewer symbols than expected")
        self.assertIn(("veafRemote", "executeCommandFromRemote"), self.defined)

    def test_strings_and_comments_are_not_read_as_calls(self) -> None:
        """The stripper is what keeps this check credible, so pin it directly."""
        source = "\n".join(
            [
                'local x = "veafFake.inAString(1)"',
                "-- veafFake.inAComment(2)",
                "local y = [[ veafFake.inALongString(3) ]]",
                "veafFake.realCall(4)",
            ]
        )
        found = {m.group(2) for m in _CALL.finditer(_strip_strings_and_comments(source))}
        self.assertEqual(found, {"realCall"})

    def test_no_call_reaches_a_function_that_does_not_exist(self) -> None:
        """The point of the file: a dead call is a runtime error waiting for a pilot."""
        missing: dict[str, list[str]] = {}
        for path in sorted(SCRIPTS.glob("veaf*.lua")):
            text = _strip_strings_and_comments(path.read_text(encoding="utf-8", errors="replace"))
            for number, line in enumerate(text.split("\n"), 1):
                for match in _CALL.finditer(line):
                    table, field = match.group(1), match.group(2)
                    if table not in self.tables or (table, field) in self.defined:
                        continue
                    name = f"{table}.{field}"
                    if name in KNOWN_MISSING:
                        continue
                    missing.setdefault(name, []).append(f"{path.name}:{number}")

        self.assertEqual(
            missing,
            {},
            "these calls reach nothing — they raise the moment they run:\n"
            + "\n".join(f"  {name} at {', '.join(sites)}" for name, sites in sorted(missing.items())),
        )

    def test_the_known_list_stays_accurate(self) -> None:
        """An entry that is no longer missing must leave the list, or the ratchet rusts open."""
        for name in KNOWN_MISSING:
            table, field = name.split(".", 1)
            self.assertNotIn(
                (table, field),
                self.defined,
                f"{name} exists now: remove it from KNOWN_MISSING",
            )


if __name__ == "__main__":
    unittest.main()
