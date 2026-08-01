"""Read the Lua runtime translation catalogue from the design-time tools.

The in-game messages live in ``veafI18n.lua`` as ``veaf.i18nCatalog`` — a Lua table of
``["key"] = { fr = "…", en = "…" }`` entries, resolved at runtime by ``veaf.t()``
(see ``docs/adr/0006-lua-runtime-i18n.md``). That catalogue is normally none of Python's
business, but anything the build **bakes into an artifact** — a checklist image, whose
text is pixels by the time DCS sees it — has to resolve the same keys, in the same
language, or the picture and the pilot's messages disagree.

This is a reader, never a writer: the catalogue stays authored in Lua.
"""

from __future__ import annotations

import re
from pathlib import Path

#: Ultimate fallback of ``veaf.t()`` — ``veaf.I18N_DEFAULT_LANGUAGE`` in ``veaf.lua``.
RUNTIME_DEFAULT_LANGUAGE = "fr"

#: One ``["key"] = { … }`` entry. The catalogue holds no nested table and no long
#: string, so matching a brace-free body is enough and keeps the reader trivial.
_ENTRY_RE = re.compile(r'\["([^"]+)"\]\s*=\s*\{([^{}]*)\}', re.DOTALL)

#: One ``lang = "text"`` pair inside an entry, tolerating escaped quotes.
_VALUE_RE = re.compile(r'(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"')

#: Lua escapes that appear in the catalogue, longest first so ``\\`` wins over ``\``.
_UNESCAPES = (("\\\\", "\\"), ('\\"', '"'), ("\\n", "\n"), ("\\t", "\t"))


def _unescape(text: str) -> str:
    """Turn a Lua string literal's body into the text it denotes."""
    for escaped, plain in _UNESCAPES:
        text = text.replace(escaped, plain)
    return text


def parse_runtime_catalog(lua_text: str) -> dict[str, dict[str, str]]:
    """Parse the ``veaf.i18nCatalog`` entries out of a ``veafI18n.lua`` source.

    Args:
        lua_text: The full text of the module.

    Returns:
        ``{key: {language: text}}``. Empty when the file holds no entry.
    """
    catalog: dict[str, dict[str, str]] = {}
    for key, body in _ENTRY_RE.findall(lua_text):
        translations = {lang: _unescape(text) for lang, text in _VALUE_RE.findall(body)}
        if translations:
            catalog[key] = translations
    return catalog


def find_runtime_catalog(scripts_folder: Path) -> Path | None:
    """Locate ``veafI18n.lua`` under *scripts_folder*.

    Args:
        scripts_folder: Root of the published VEAF scripts.

    Returns:
        The catalogue path, or ``None`` when the folder ships no such module.
    """
    return next(iter(sorted(scripts_folder.rglob("veafI18n.lua"))), None)


def load_runtime_catalog(scripts_folder: Path) -> dict[str, dict[str, str]]:
    """Read the runtime catalogue shipped under *scripts_folder*.

    Args:
        scripts_folder: Root of the published VEAF scripts.

    Returns:
        ``{key: {language: text}}``, empty when the module is absent or unreadable —
        callers then fall back to emitting the keys, which is what ``veaf.t()`` does
        too, so nothing breaks.
    """
    path = find_runtime_catalog(scripts_folder)
    if path is None:
        return {}
    try:
        return parse_runtime_catalog(path.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        return {}


def translate(catalog: dict[str, dict[str, str]], key: str, language: str) -> str:
    """Resolve *key* the way ``veaf.t()`` does at runtime.

    Fallback order: the requested language, then the runtime default (French), then the
    key itself — so a literal string written instead of a key comes back unchanged, which
    is what lets a mission maker skip the catalogue entirely.

    Args:
        catalog: The parsed catalogue.
        key: Catalog key, or a literal string.
        language: Two-letter language code.

    Returns:
        The translated text, or *key* when it resolves to nothing.
    """
    entry = catalog.get(key)
    if not entry:
        return key
    return entry.get(language) or entry.get(RUNTIME_DEFAULT_LANGUAGE) or key
