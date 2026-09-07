"""Turning a documentation page title into a link the reader can click.

## Why this module exists at all

An answer with no source is a claim. But the Worker streams **text and nothing else** — its RAG
retrieves passages carrying a ``title`` and a ``path``, injects them into the prompt and never tells
the caller which ones it used (``poc/doc-chatbot/worker/src/index.js``, ``retrieveContext``). So the
service cannot read the sources off the wire.

What it does instead, and the reason it is honest rather than a guess:

1. the question sent to the Worker is preceded by a short protocol turn (see
   :mod:`veaf_support_bot.answer`) asking the model to end its answer with the **titles** of the
   excerpts it actually used — the model is the only party that knows;
2. every declared title is looked up in the index below, built from the real ``doc/`` tree. A title
   the corpus does not have is **dropped**, never linked.

So the service never invents a source, and a hallucinated one cannot become a link. What it can do
is show fewer sources than the answer used, when the model forgets the trailer — which reads as
"no page cited" and routes the user to the support page. Under-citing is the safe direction.

The sturdier fix is Worker-side: one ``data: {"sources": [...]}`` event before the text, and this
whole module becomes a URL formatter. That is a change to a component this lot does not deploy, so
it is left as a follow-up.

## The index

:data:`PAGES_BY_TITLE` is **generated** from ``doc/`` by ``scripts/refresh_doc_pages.py`` and
checked in, so the container needs no copy of the documentation. ``tests/test_doc_pages.py``
rebuilds it from the real tree and fails when the two drift apart — which is also why the service's
CI workflow triggers on ``doc/**``.

The URL rule was verified against a real ``mkdocs build``: 142 built pages, zero mismatches. Both
``index.md`` and ``README.md`` render as their directory's page, English lives under ``/en/``.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Final

from veaf_support_bot.doc_pages_data import PAGES_BY_TITLE
from veaf_support_bot.texts import DOC_SITE_BASE

__all__ = ["PAGES_BY_TITLE", "build_index", "normalize_title", "page_url", "resolve_title"]

#: Directory names under ``doc/`` that hold no readable page.
_EXCLUDED_ROOTS: Final = ("assets",)

#: File stems MkDocs renders as their directory's page rather than as a page of their own.
_INDEX_STEMS: Final = ("index", "README")

#: Wrapping the model habitually puts around a title: quotes, backticks, bold, a trailing period.
_TRIM = " \t`*_\"'«»“”.,;:!?()[]"

_WHITESPACE_RE: Final = re.compile(r"\s+")
_HEADING_RE: Final = re.compile(r"^#\s+(.+)$", re.MULTILINE)


def normalize_title(title: str) -> str:
    """Reduce a page title to the form the index is keyed on.

    The model retypes a title rather than copying bytes, so the lookup must survive a different
    case, doubled spaces and the punctuation a sentence puts around a name. It must **not** survive
    a different title: normalisation only removes decoration.

    Args:
        title: A title as written by the model, or as read from a page's first heading.

    Returns:
        The normalised key: casefolded, whitespace collapsed, decoration stripped.
    """
    collapsed = _WHITESPACE_RE.sub(" ", title.replace(" ", " ")).strip(_TRIM)
    return collapsed.casefold()


def page_url(relative_path: str) -> str:
    """Return the published address of a documentation page.

    Args:
        relative_path: The page's path relative to ``doc/``, POSIX-style, e.g.
            ``"mission-maker/LOGS.en.md"``.

    Returns:
        Its URL on the documentation site.
    """
    if relative_path.endswith(".en.md"):
        prefix, stem = "en/", relative_path[: -len(".en.md")]
    else:
        prefix, stem = "", relative_path[: -len(".md")]
    parts = stem.split("/")
    if parts[-1] in _INDEX_STEMS:
        parts = parts[:-1]
    joined = "/".join(parts)
    return f"{DOC_SITE_BASE}/{prefix}{joined + '/' if joined else ''}"


def resolve_title(title: str, lang: str) -> str | None:
    """Return the URL of the documentation page carrying *title*, when there is one.

    Args:
        title: The title the model declared as a source.
        lang: ``"fr"`` or ``"en"``; a title is only looked up in the asker's own corpus, because the
            two languages share no titles and a cross-language hit would link the wrong page.

    Returns:
        The page URL, or ``None`` when the corpus has no page with that title — in which case the
        caller must show nothing rather than guess.
    """
    relative_path = PAGES_BY_TITLE.get(lang, {}).get(normalize_title(title))
    return page_url(relative_path) if relative_path else None


def build_index(doc_dir: Path) -> dict[str, dict[str, str]]:
    """Rebuild the title index from a real documentation tree.

    This is the generator behind :data:`PAGES_BY_TITLE`; the checked-in data is its output. The
    title of a page is its first level-one heading, which is exactly what the index builder feeds
    the model (``build-index.mjs``, ``titleOf``) — so the two agree by construction rather than by
    convention.

    Args:
        doc_dir: The repository's ``doc/`` directory.

    Returns:
        ``{"fr": {normalised title: path relative to doc/}, "en": {...}}``.

    Raises:
        ValueError: When two pages of the same language share a title. The index maps a title to one
            page; an ambiguous title would link the wrong one, so the generator refuses instead of
            picking.
    """
    index: dict[str, dict[str, str]] = {"fr": {}, "en": {}}
    collisions: list[str] = []
    for path in sorted(doc_dir.rglob("*.md")):
        relative = path.relative_to(doc_dir).as_posix()
        if relative.split("/", 1)[0] in _EXCLUDED_ROOTS:
            continue
        lang = "en" if relative.endswith(".en.md") else "fr"
        heading = _HEADING_RE.search(path.read_text(encoding="utf-8"))
        title = normalize_title(heading.group(1) if heading else Path(relative).stem)
        if title in index[lang]:
            collisions.append(f"{lang}: {title!r} in {index[lang][title]} and {relative}")
            continue
        index[lang][title] = relative
    if collisions:
        raise ValueError("two documentation pages share a title:\n  " + "\n  ".join(collisions))
    return index
