"""Regenerate ``veaf_support_bot/doc_pages_data.py`` from the repository's ``doc/`` tree.

The service links the documentation pages an answer cites, and it must do so without carrying a copy
of the documentation into the container. So the title index is generated here and checked in.

Run it from anywhere after adding, renaming or retitling a documentation page::

    poetry run python scripts/refresh_doc_pages.py

``tests/test_doc_pages.py`` rebuilds the same index from the real tree and fails when the checked-in
file has drifted, so forgetting this script is a red test rather than a silently wrong link. That is
also why the service's CI workflow triggers on ``doc/**``.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

SERVICE_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVICE_ROOT))

from veaf_support_bot.doc_pages import build_index  # noqa: E402

#: Where the repository's documentation lives, relative to this service.
DOC_DIR = SERVICE_ROOT.parents[1] / "doc"

#: The generated module.
TARGET = SERVICE_ROOT / "veaf_support_bot" / "doc_pages_data.py"

_HEADER = '''"""Documentation page titles, mapped to their path under ``doc/``. **Generated file.**

Do not edit by hand: run ``poetry run python scripts/refresh_doc_pages.py`` from
``services/support-bot/``. ``tests/test_doc_pages.py`` rebuilds this from the real ``doc/`` tree and
fails when the two have drifted.

Keys are titles normalised by :func:`veaf_support_bot.doc_pages.normalize_title`; values are paths
relative to ``doc/``, which :func:`veaf_support_bot.doc_pages.page_url` turns into site addresses.
"""

from __future__ import annotations

from typing import Final

#: ``{language: {normalised title: path relative to doc/}}``.
PAGES_BY_TITLE: Final[dict[str, dict[str, str]]] = {
'''


def _quote(value: str) -> str:
    """Render a string the way ``ruff format`` writes one: with double quotes.

    ``repr`` picks single quotes, which the formatter then rewrites — so every
    regeneration produced a file that failed ``ruff format --check``. Double quotes
    everywhere, except where the value itself holds one and no apostrophe: there the
    formatter switches to single quotes rather than escape, and so does this.

    Args:
        value: The string to quote.

    Returns:
        The value as a double-quoted Python literal.
    """
    if '"' in value and "'" not in value:
        # What the formatter does: single quotes rather than escaping the double ones.
        return "'" + value + "'"
    return json.dumps(value, ensure_ascii=False)


def render(index: dict[str, dict[str, str]]) -> str:
    """Render the index as the source of the generated module.

    Args:
        index: The index as :func:`veaf_support_bot.doc_pages.build_index` returns it.

    Returns:
        The full text of ``doc_pages_data.py``, formatted the way ``ruff format`` leaves it.
    """
    lines = [_HEADER]
    for lang in sorted(index):
        lines.append(f'    "{lang}": {{\n')
        for title, path in sorted(index[lang].items()):
            lines.append(f"        {_quote(title)}: {_quote(path)},\n")
        lines.append("    },\n")
    lines.append("}\n")
    return "".join(lines)


def main() -> int:
    """Rewrite the generated module from the documentation tree.

    Returns:
        ``0`` on success.
    """
    text = render(build_index(DOC_DIR))
    TARGET.write_text(text, encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
