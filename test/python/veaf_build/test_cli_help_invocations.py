"""The veaf-build CLI's own help must not name invocations nobody can type.

`veaf-tools-updater` is a bare `typer.run(main)`: it has **no subcommands**, so
`veaf-tools-updater update --tag …` — which two help strings told the user to run — fails
immediately. `doc/TOOLS_REFERENCE.md` had it right (`veaf-tools-updater.exe --tag …`); the
code's own help was the stale side, which is the worse of the two since it is what a
release manager reads at the moment they need it (FIX-DOCAUDIT-CODE 03).
"""

from __future__ import annotations

import inspect
import re
from pathlib import Path

from veaf_build.cli import app

#: An invented subcommand announces itself as a bare word between the binary and its first
#: option. Matching that shape rather than any following word keeps prose out of it
#: ("also builds the veaf-tools-updater binary" is not an invocation).
INVENTED_SUBCOMMAND = re.compile(r"veaf-tools-updater(?:\.exe)?\s+([a-z][\w-]*)\s+--")

UPDATER_SOURCE = Path(__file__).resolve().parents[3] / "src" / "python" / "veaf-tools" / "veaf-tools-updater.py"


def _help_texts() -> list[tuple[str, str]]:
    """Every help string the CLI can display, with where it comes from.

    Enumerated from the typer registration rather than listed by hand, so a help string
    added tomorrow is covered without touching this test.

    Returns:
        Pairs of (location label, help text).
    """
    texts: list[tuple[str, str]] = []
    for command in app.registered_commands:
        callback = command.callback
        if callback is None:
            continue
        name = getattr(callback, "__name__", "<anonymous>")
        if command.help:
            texts.append((f"{name} (help)", command.help))
        if callback.__doc__:
            texts.append((f"{name} (docstring)", callback.__doc__))
        for param in inspect.signature(callback).parameters.values():
            option_help = getattr(param.default, "help", None)
            if isinstance(option_help, str):
                texts.append((f"{name} --{param.name}", option_help))
    return texts


def test_the_help_inventory_is_not_empty() -> None:
    # A guard on the harness: if typer's registration shape changed, the sweep below would
    # pass by finding nothing to look at.
    texts = _help_texts()
    assert len(texts) > 20, "the CLI declares more help strings than this"


def test_no_help_text_invents_an_updater_subcommand() -> None:
    offenders = [
        (where, f"veaf-tools-updater {found} --...")
        for where, text in _help_texts()
        for found in INVENTED_SUBCOMMAND.findall(text)
    ]
    assert offenders == [], f"help strings naming a subcommand the updater does not have: {offenders}"


def test_the_updater_really_has_no_subcommands() -> None:
    # The premise the test above rests on, pinned at the source: a `typer.run(main)` entry
    # point exposes options only. If the updater ever grows a command group, this fails and
    # the rule above has to be revisited rather than silently over-reporting.
    source = UPDATER_SOURCE.read_text(encoding="utf-8")
    assert "typer.run(main)" in source
    assert "@app.command" not in source
