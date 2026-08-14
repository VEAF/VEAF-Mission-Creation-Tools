"""No radio-menu label may be a hard-coded string (FIX-RADIO-MENU-I18N).

90 labels drifted into English literals precisely because nothing forbade the 91st. These checks
**enumerate** every menu call and every root-name declaration from the Lua sources rather than
sampling them, the rule that made `FIX-MARKER-PARAM-CRASHES-2`'s sweep trustworthy.

They also pin the two facts that make the fix correct rather than merely applied:

- every key a menu uses exists in the catalogue, in **both** languages;
- no label is resolved at *load* time. `veaf.config.language` is assigned after the module files
  load and before `initialize()`, so a `veaf.t(...)` sitting on a declaration line would freeze every
  server to French with no error — the failure mode is a wrong language, not a crash.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

VEAF_LUA = Path(__file__).resolve().parents[3] / "src" / "scripts" / "veaf"

#: The four menu-building calls, matched with their first argument.
#:
#: **Multi-line by necessity**: stylua wraps most of these calls, so the first argument usually sits
#: on the line *after* the call. A line-by-line version of this sweep saw 46 of the 77 literals and
#: would have reported a clean run with 31 English labels still in place.
MENU_CALL = re.compile(
    r"veafRadio\.(?:addMenu|addSubMenu|addCommandToSubmenu|addSecuredCommandToSubmenu)\s*\(\s*"
    r"""("[^"\n]*"|'[^'\n]*')""",
    re.DOTALL,
)

#: `<module>.RadioMenuName* = <value>` at column 0 — a declaration, evaluated at load time.
ROOT_DECL = re.compile(r"^(\w+\.RadioMenuName\w*)\s*=\s*(.+)$", re.MULTILINE)

#: An i18n catalogue entry with both languages.
CATALOGUE_ENTRY = re.compile(
    r'\["([^"]+)"\]\s*=\s*\{\s*fr\s*=\s*(.+?),\s*en\s*=\s*(.+?),?\s*\}',
    re.DOTALL,
)


def _modules() -> list[Path]:
    return sorted(VEAF_LUA.glob("*.lua"))


def _catalogue_keys() -> set[str]:
    text = (VEAF_LUA / "veafI18n.lua").read_text(encoding="utf-8")
    return {m.group(1) for m in CATALOGUE_ENTRY.finditer(text)}


def test_the_sweep_reaches_across_lines() -> None:
    # A guard on the harness, and on the bug this sweep itself had: a wrapped call must be seen.
    wrapped = 'veafRadio.addCommandToSubmenu(\n      "HELP",\n      path\n    )'
    assert MENU_CALL.search(wrapped), "the sweep must match a wrapped call, or it under-reports"


def test_no_menu_label_is_a_hard_coded_string() -> None:
    offenders: list[str] = []
    for path in _modules():
        text = path.read_text(encoding="utf-8")
        for match in MENU_CALL.finditer(text):
            line_no = text[: match.start()].count("\n") + 1
            offenders.append(f"{path.name}:{line_no}: {match.group(1)[:50]}")
    assert offenders == [], "menu labels a pilot reads in one language only:\n  " + "\n  ".join(offenders)


def test_every_root_menu_name_is_a_catalogue_key() -> None:
    keys = _catalogue_keys()
    problems: list[str] = []
    for path in _modules():
        for field, value in ROOT_DECL.findall(path.read_text(encoding="utf-8")):
            value = value.strip().rstrip(",")
            if not (value.startswith('"') and value.strip('"').startswith("menu.")):
                problems.append(f"{path.name}: {field} = {value[:40]} is not a menu.* key")
            elif value.strip('"') not in keys:
                problems.append(f"{path.name}: {field} names {value}, absent from the catalogue")
    assert problems == [], "\n  ".join(problems)


def test_no_label_is_resolved_at_load_time() -> None:
    # A `veaf.t(...)` on a declaration line resolves before the mission's language is known.
    offenders = [
        f"{path.name}: {field}"
        for path in _modules()
        for field, value in ROOT_DECL.findall(path.read_text(encoding="utf-8"))
        if "veaf.t(" in value
    ]
    assert offenders == [], (
        "these resolve at load time, before veaf.config.language is set, so they would always be "
        "French:\n  " + "\n  ".join(offenders)
    )


@pytest.mark.parametrize("language", ["fr", "en"])
def test_every_menu_key_has_that_language(language: str) -> None:
    text = (VEAF_LUA / "veafI18n.lua").read_text(encoding="utf-8")
    menu_entries = {m.group(1): m for m in CATALOGUE_ENTRY.finditer(text) if m.group(1).startswith("menu.")}
    assert menu_entries, "no menu.* key in the catalogue at all"
    group = 2 if language == "fr" else 3
    missing = [key for key, m in menu_entries.items() if not m.group(group).strip().strip('"')]
    assert missing == [], f"menu keys with no {language} text: {missing}"
