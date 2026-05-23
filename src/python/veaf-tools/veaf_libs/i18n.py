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
    """Detect the active language from env var or OS locale."""
    env = os.environ.get("VEAF_LANG", "").strip()
    if env:
        return env[:2].lower()
    # Try OS locale; avoid the deprecated getdefaultlocale() (removed in 3.15).
    # Do NOT call locale.setlocale here — it has process-wide side effects.
    try:
        loc = locale.getlocale(locale.LC_CTYPE)[0]
        if loc:
            return loc[:2].lower()
    except Exception:
        pass
    # Last resort: parse LANG / LC_ALL env vars directly.
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


def current_language() -> str:
    """Return the currently active language code (e.g. ``"en"``, ``"fr"``)."""
    return _lang


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


# Initialise at import time so that module-level ``t()`` calls (e.g. inside
# ``help=`` strings) get the correct language immediately.
_init()
