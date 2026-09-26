"""What the guide teaches about CSAR settings must be what `CSAR.lua` actually accepts.

The guide's own YAML-first example read::

    settings:
      enableAllslots: true
      useprefix: true
      csarPrefix: "MEDEVAC"

`CSAR.lua:32` defaults `csarPrefix` to a **table**, and `CSAR.lua:1916` walks it with `pairs`
inside the `useprefix == true` branch — the branch the example turns on. Measured on Lua 5.1.5,
`pairs("MEDEVAC")` raises *bad argument #1 to 'pairs' (table expected, got string)*. Copying the
documented block was enough to break CSAR at runtime, from the page teaching the simple path.

Nothing could have caught it: the YAML is valid, the generated Lua parses, and the only reader that
disagrees is DCS, at mission time. So this file compares the two sources nobody was comparing — the
documented examples and the script's own defaults — on the one property that mattered: the **Lua
type** a value arrives as.

Two directions, because each catches a different drift:

* every setting a documented example writes must exist in `CSAR.lua` and keep its default's type;
* every setting `CSAR.lua` offers must appear in the guide, in both languages. That is the ratchet
  behind the table added by FIX-CSAR-YAML-SETTINGS ticket 03 — a setting added upstream and left
  undocumented is how the guide got down to naming 3 of 34.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest
import yaml
from veaf_libs.lua_config_generator import generate_config_lua

ROOT = Path(__file__).parents[2]
CSAR_LUA = ROOT / "src" / "scripts" / "community" / "CSAR.lua"
GUIDES = (ROOT / "doc" / "mission-maker" / "GUIDE.md", ROOT / "doc" / "mission-maker" / "GUIDE.en.md")

#: `csar.<name> = <value>` at the start of a line, value up to a trailing Lua comment.
_ASSIGNMENT = re.compile(r"^csar\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$", re.MULTILINE)

#: Script metadata, not something a mission sets.
_METADATA = frozenset({"Version", "Id"})

#: Runtime bookkeeping the script initialises to an empty table and fills as it runs — a mission
#: writing one of these would be overwriting state, not configuring anything.
_RUNTIME_STATE_MARKER = "{}"

#: The one setting that is a *keyed* table: `csar.aircraftType["UH-1H"] = 8`. It cannot be written
#: as a YAML list, so it stays on the Lua callback and the guide says so in as many words.
_KEYED = frozenset({"aircraftType"})


def _strip_comment(raw: str) -> str:
    """Return the literal in *raw*, with any trailing ``--`` comment removed.

    A quoted default is taken up to its closing quote, so a comment is never confused with the
    two dashes inside a string.
    """
    raw = raw.strip()
    if raw.startswith('"'):
        end = raw.find('"', 1)
        return raw[: end + 1] if end != -1 else raw
    return raw.split("--", 1)[0].strip()


def _lua_type(value: str) -> str:
    """Return the Lua type of a literal as written in ``CSAR.lua``."""
    value = _strip_comment(value)
    if value.startswith("{"):
        return "table"
    if value.startswith('"'):
        return "string"
    if value in ("true", "false"):
        return "boolean"
    if re.fullmatch(r"-?\d+(?:\.\d+)?", value):
        return "number"
    return "other"


def _csar_defaults() -> dict[str, str]:
    """Return ``{setting: lua type}`` for every setting a mission may configure."""
    text = CSAR_LUA.read_text(encoding="utf-8", errors="replace")
    defaults: dict[str, str] = {}
    for name, raw in _ASSIGNMENT.findall(text):
        if name in _METADATA or name in defaults:
            continue
        kind = _lua_type(raw)
        if kind == "other":
            continue  # a function, not a setting
        if kind == "table" and _strip_comment(raw).startswith(_RUNTIME_STATE_MARKER):
            continue  # runtime bookkeeping, or the keyed table filled just below
        defaults[name] = kind
    return defaults


def _documented_examples() -> list[tuple[Path, dict]]:
    """Return every ``modules.CSAR.settings`` mapping written in a guide's YAML blocks."""
    found: list[tuple[Path, dict]] = []
    for guide in GUIDES:
        for block in re.findall(r"```yaml\n(.*?)```", guide.read_text(encoding="utf-8"), re.DOTALL):
            parsed = yaml.safe_load(block)
            if not isinstance(parsed, dict):
                continue
            settings = ((parsed.get("modules") or {}).get("CSAR") or {}).get("settings")
            if isinstance(settings, dict):
                found.append((guide, settings))
    return found


def _generated_value(key: str, value: object) -> str:
    """Return the Lua literal the generator writes for ``csar.<key> = <value>``."""
    lua = generate_config_lua({"external_modules": {"csar": {"enabled": True, key: value}}})
    match = re.search(rf"^\s*csar\.{re.escape(key)} = (.*)$", lua, re.MULTILINE)
    assert match, f"the generator wrote nothing for {key}"
    return match.group(1).strip()


def test_the_enumeration_found_the_settings() -> None:
    """A regex that stops matching would turn every test below into a silent pass."""
    defaults = _csar_defaults()
    assert len(defaults) >= 34, sorted(defaults)
    assert defaults["csarPrefix"] == "table"
    assert defaults["enableAllslots"] == "boolean"
    assert _documented_examples(), "no documented CSAR settings block found in the guides"


def test_every_documented_example_names_a_real_setting() -> None:
    defaults = _csar_defaults()
    for guide, settings in _documented_examples():
        unknown = sorted(set(settings) - set(defaults) - _KEYED)
        assert not unknown, f"{guide.name}: settings CSAR.lua does not define: {unknown}"


def test_every_documented_example_generates_the_type_csar_expects() -> None:
    """The defect this file exists for: a string written where the script iterates a table."""
    defaults = _csar_defaults()
    for guide, settings in _documented_examples():
        for key, value in settings.items():
            expected = defaults.get(key)
            if expected is None:
                continue
            generated = _generated_value(key, value)
            actual = _lua_type(generated)
            assert actual == expected, (
                f"{guide.name}: `{key}: {value!r}` generates `{generated}` ({actual}), "
                f"but CSAR.lua defaults it to a {expected}"
            )


def _settings_section(guide: Path) -> str:
    """Return the guide's CSAR settings section, from its anchor to the next same-level heading.

    Scoped rather than searched whole: ``weight``, ``max_units`` and friends are ordinary words that
    appear in code spans elsewhere in a 1 000-line guide, so a whole-file search would report a
    setting as documented because something unrelated mentions it.
    """
    text = guide.read_text(encoding="utf-8")
    start = text.index("{#csar-settings}")
    rest = text[start:]
    end = rest.find("\n### ")
    return rest if end == -1 else rest[:end]


@pytest.mark.parametrize("guide", GUIDES, ids=lambda path: path.name)
def test_every_csar_setting_is_documented(guide: Path) -> None:
    """The ratchet: a setting CSAR gains upstream must reach the guide, in both languages."""
    section = _settings_section(guide)
    missing = sorted(name for name in _csar_defaults() if f"`{name}`" not in section)
    assert not missing, f"{guide.name}: settings absent from the CSAR settings section: {missing}"
