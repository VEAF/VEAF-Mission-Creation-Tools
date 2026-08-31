"""Internationalisation helpers for veaf-tools.

Language resolution order
-------------------------
1. ``set_language(lang)`` explicit call (e.g. from ``--lang`` CLI option)
2. ``VEAF_LANG`` environment variable (set before launch)
3. OS locale (``locale.getdefaultlocale()``)
4. ``"en"`` (hard fallback)

Usage::

    from veaf_libs.i18n import t, set_language

    # At runtime (from --lang callback):
    set_language("fr")

    # Translate a key:
    print(t("build.start", mission="demo"))

Catalog files live in ``veaf_libs/locales/<lang>.json``.
The ``en.json`` catalog is authoritative; all other locales fall back to it
for missing keys.
"""

from __future__ import annotations

import json
import locale
import os
import sys
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path


def _get_locales_dir() -> Path:
    """Return the locales directory, working both as a script and a PyInstaller bundle."""
    if hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS) / "veaf_libs" / "locales"  # type: ignore[attr-defined]
    return Path(__file__).parent / "locales"


_LOCALES_DIR = _get_locales_dir()

_lang: str = "en"
_catalog: dict[str, str] = {}
_en_catalog: dict[str, str] = {}


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


def _detect_lang() -> str:
    """Detect the active language.

    Resolution order:
    1. ``VEAF_LANG`` environment variable
    2. ``~/veafmct.yaml`` (or ``~/.veaf/config.yaml``) ``lang:`` key
    3. OS locale
    4. ``"en"`` fallback
    """
    env = os.environ.get("VEAF_LANG", "").strip()
    if env:
        return env[:2].lower()
    # User global config — lazy import to avoid circular dependency at init time.
    try:
        from veaf_libs.user_config import get_lang as _get_user_lang  # noqa: PLC0415

        user_lang = _get_user_lang()
        if user_lang:
            return user_lang
    except Exception:
        pass
    # Try OS locale; avoid the deprecated getdefaultlocale() (removed in 3.15).
    # Do NOT call locale.setlocale here — it has process-wide side effects.
    try:
        loc = locale.getlocale(locale.LC_CTYPE)[0]
        if loc:
            return loc[:2].lower()
    except Exception:
        pass
    # On Windows, locale.getlocale() returns None until setlocale() is called.
    # Use winreg to read the user's locale from the registry instead.
    if sys.platform == "win32":
        try:
            import winreg  # noqa: PLC0415

            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Control Panel\International") as key:
                locale_name = winreg.QueryValueEx(key, "LocaleName")[0]  # e.g. "fr-FR"
                if locale_name:
                    return locale_name[:2].lower()
        except Exception:
            pass
    # Last resort: parse LANG / LC_ALL env vars directly (Linux/macOS).
    for var in ("LC_ALL", "LC_CTYPE", "LANG"):
        val = os.environ.get(var, "").strip()
        if val and val != "C" and val != "POSIX":
            return val[:2].lower()
    return "en"


def _load_catalog(lang: str) -> dict[str, str]:
    path = _LOCALES_DIR / f"{lang}.json"
    if not path.exists():
        return {}
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except json.JSONDecodeError:
        import logging

        logging.getLogger(__name__).warning("Failed to load locale catalog '%s': invalid JSON", path)
        return {}


def _init() -> None:
    """Detect language and load catalog at import time."""
    global _lang, _catalog, _en_catalog
    _en_catalog = _load_catalog("en")
    _lang = _detect_lang()
    _catalog = _load_catalog(_lang) if _lang != "en" else _en_catalog


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def set_language(lang: str) -> None:
    """Override the active language at runtime (e.g. from ``--lang`` CLI option).

    Can be called multiple times; each call reloads the catalog.
    """
    global _lang, _catalog
    _lang = lang.strip().lower()[:2]
    _catalog = _load_catalog(_lang) if _lang != "en" else _en_catalog


def set_language_from_argv(argv: list[str] | None = None) -> None:
    """Apply a ``--lang`` passed on the command line, before anything reads a catalog.

    Typer cannot do this itself: ``--help`` is eager, so it renders before the app callback
    runs, and the ``help=`` strings are :func:`t` calls evaluated when their module is
    imported. The language therefore has to be set *before* the command modules load, which
    is earlier than any Typer machinery gets a turn — hence this hand-rolled scan.

    It lives here rather than in either entry point because both need it: the ``veaf-tools``
    console script (via :func:`veaf_tools.app.main`) and the frozen-executable entry script,
    which calls it before importing anything that translates.

    Args:
        argv: The full argument vector, program name included. Defaults to ``sys.argv``.
    """
    args = sys.argv if argv is None else argv
    for index, arg in enumerate(args[1:], start=1):
        if arg == "--lang" and index + 1 < len(args):
            set_language(args[index + 1])
            return
        if arg.startswith("--lang="):
            set_language(arg.split("=", 1)[1])
            return


def current_language() -> str:
    """Return the currently active language code (e.g. ``"en"``, ``"fr"``)."""
    return _lang


@contextmanager
def language(lang: str) -> Iterator[None]:
    """Temporarily switch the active language, restoring the previous one on exit.

    Usage::

        with language("fr"):
            ...  # t() returns French here
    """
    previous = current_language()
    set_language(lang)
    try:
        yield
    finally:
        set_language(previous)


def t(key: str, **kwargs: object) -> str:
    """Look up a translation key.

    Falls back to the EN catalog, then to the key itself if still not found.
    Formats the result with *kwargs* via ``str.format_map``; any formatting
    error returns the raw translated string.
    """
    text = _catalog.get(key) or _en_catalog.get(key, key)
    if kwargs:
        try:
            return text.format_map(kwargs)
        except (KeyError, ValueError):
            return text
    return text


def tn(key: str, count: int, **kwargs: object) -> str:
    """Look up a count-sensitive translation with a natural singular/plural.

    The catalog value uses the ``(s)`` optional-plural convention: each ``word(s)``
    marker becomes ``word`` when ``count == 1`` and ``words`` otherwise (covering the
    ``0``/``2+`` cases)::

        "{n} asset(s) extracted"   # -> "1 asset extracted" / "3 assets extracted"

    (Invariant nouns simply carry no marker — e.g. ``"{count} aircraft"``.)

    ``count`` is exposed to the template as ``{count}``; any extra *kwargs* are passed
    through to ``str.format_map`` (so a message using ``{n}`` is called as
    ``tn(key, value, n=value)``). Falls back to the EN catalog, then the key itself;
    a formatting error returns the resolved-but-unformatted text.
    """
    text = _catalog.get(key) or _en_catalog.get(key, key)
    resolved = text.replace("(s)", "" if count == 1 else "s")
    try:
        return resolved.format_map({"count": count, **kwargs})
    except (KeyError, ValueError):
        return resolved


# Initialise at import time so that module-level ``t()`` calls (e.g. inside
# ``help=`` strings) get the correct language immediately.
_init()
