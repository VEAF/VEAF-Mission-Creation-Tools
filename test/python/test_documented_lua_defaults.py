"""A default documented in `doc/LUA_API_REFERENCE*.md` must be the one the Lua actually sets.

`doc/LUA_API_REFERENCE.md` and its English twin list module constants as literal Lua assignments, so a
reader takes them for the real defaults. One of them was wrong: `veaf.HideNamesFromSpawnedGroups = false`
in both languages, while `veaf.lua:41` sets it to **true**. Since that flag replaces a spawned group's
zone and type with an invented name, the documentation told a mission maker the opposite of what his
missions were doing — and it went unnoticed until someone asked why his groups were named "Hydra Unit"
(2026-08-24).

Nothing compared the two, and nothing could have: the number was right in each file on its own. This is
the same shape as the backlog consistency gate — two sources that agree separately with a third and not
with each other.

Scope, deliberately narrow so the check stays trustworthy rather than noisy:

* only `veaf*.X = <literal>` lines inside fenced Lua blocks in the reference pages;
* only booleans and numbers. A string default is often illustrative (`"6.7.x+<sha>"`) rather than literal,
  and a table default has no single value to compare;
* a constant the docs mention but the scripts do not assign at top level is skipped, not failed — the
  documentation legitimately describes fields set at runtime.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[2]
SCRIPTS = ROOT / "src" / "scripts" / "veaf"
REFERENCES = (ROOT / "doc" / "LUA_API_REFERENCE.md", ROOT / "doc" / "LUA_API_REFERENCE.en.md")

#: `veafX.Y = value`, capturing the value up to a trailing Lua comment.
_ASSIGNMENT = re.compile(r"^\s*(veaf[A-Za-z0-9_]*\.[A-Za-z0-9_]+)\s*=\s*([^\n]+?)\s*(?:--.*)?$")

#: Only these are worth comparing; see the module docstring.
_COMPARABLE = re.compile(r"^(true|false|-?\d+(?:\.\d+)?)$")


def _fenced_lua_blocks(text: str) -> list[str]:
    """Every ```lua fenced block of a markdown page."""
    return re.findall(r"```lua\n(.*?)```", text, flags=re.S)


def _assignments(lines: list[str]) -> dict[str, str]:
    """Map `veafX.Y` to its literal value, keeping only comparable literals."""
    found: dict[str, str] = {}
    for line in lines:
        match = _ASSIGNMENT.match(line)
        if not match:
            continue
        name, value = match.group(1), match.group(2).rstrip(",")
        if _COMPARABLE.match(value):
            found.setdefault(name, value)
    return found


def _lua_defaults() -> dict[str, str]:
    """What the scripts assign at top level, which is what a mission starts with."""
    defaults: dict[str, str] = {}
    for path in sorted(SCRIPTS.glob("veaf*.lua")):
        lines = path.read_text(encoding="utf-8", errors="replace").split("\n")
        # top level only: an indented assignment runs inside a function, at some later moment
        defaults.update(_assignments([line for line in lines if line and not line[0].isspace()]))
    return defaults


class TestDocumentedDefaultsMatchTheCode(unittest.TestCase):
    def setUp(self) -> None:
        self.defaults = _lua_defaults()

    def test_the_sweep_reads_both_the_docs_and_the_scripts(self) -> None:
        """A check that silently scans nothing passes every assertion below."""
        self.assertGreater(len(self.defaults), 100, "far fewer Lua defaults than expected")
        for reference in REFERENCES:
            self.assertTrue(reference.is_file(), f"{reference.name} is missing")
            self.assertTrue(_fenced_lua_blocks(reference.read_text(encoding="utf-8")), reference.name)

    def test_every_documented_default_is_the_real_one(self) -> None:
        """The point of the file: a reader must be able to trust these numbers."""
        drift = []
        for reference in REFERENCES:
            blocks = _fenced_lua_blocks(reference.read_text(encoding="utf-8"))
            documented = _assignments([line for block in blocks for line in block.split("\n")])
            for name, value in documented.items():
                actual = self.defaults.get(name)
                if actual is None:
                    continue  # documented but not assigned at top level — set at runtime, fair enough
                if actual != value:
                    drift.append(f"{reference.name}: {name} documented {value}, code says {actual}")
        self.assertEqual(drift, [], "documented defaults disagree with the code:\n  " + "\n  ".join(drift))

    def test_the_two_languages_document_the_same_values(self) -> None:
        """A value corrected in one language and not the other is the next version of this bug."""
        per_language = [
            _assignments(
                [line for block in _fenced_lua_blocks(ref.read_text(encoding="utf-8")) for line in block.split("\n")]
            )
            for ref in REFERENCES
        ]
        # Every name in either page, not the intersection: comparing only shared keys means deleting a
        # documented default from one language drops it out of the comparison entirely and the test
        # still passes — the two pages then disagree in the one way this test exists to catch.
        # Raised by Sourcery on #795.
        every_name = set(per_language[0]) | set(per_language[1])
        missing = sorted(
            f"{name} documented only in {REFERENCES[0 if name in per_language[0] else 1].name}"
            for name in every_name
            if (name in per_language[0]) != (name in per_language[1])
        )
        mismatched = sorted(
            f"{name}: {REFERENCES[0].name} says {per_language[0][name]}, "
            f"{REFERENCES[1].name} says {per_language[1][name]}"
            for name in every_name
            if name in per_language[0] and name in per_language[1] and per_language[0][name] != per_language[1][name]
        )
        report = missing + mismatched
        self.assertEqual(
            report,
            [],
            "the two language references do not document the same defaults:\n  " + "\n  ".join(report),
        )


if __name__ == "__main__":
    unittest.main()
