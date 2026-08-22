"""Substitute ``${VARIABLE}`` tokens in a mission's briefing text.

Why this exists (FEAT-BRIEFING-METAR, `#40 <https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/40>`_,
open since 2021): a mission is rebuilt from a compiled source every time, so anything typed into the
briefing by hand is overwritten on the next build. The weather the mission was *built with* is known at
build time and never reached the text a pilot reads.

**A mechanism, not a template engine.** The substitution takes a plain mapping of name to value, so the
next need — mission name, era, build date — is a new entry rather than new code. What it deliberately
does not have: expressions, conditionals, loops, or nesting.

**Where the text lives.** A ``.miz`` keeps its briefing in the l10n dictionary: ``mission`` holds a key
such as ``DictKey_descriptionText_1`` and ``l10n/DEFAULT/dictionary`` holds the prose. A substitution
pass that only looked at ``mission`` would find a key and replace nothing. Both shapes are handled,
because a hand-built or converted mission can carry the text inline.

**All four description fields**, not just the situation: ``descriptionText`` plus the three per-coalition
tasks. A mission maker who writes ``${METAR}`` in the blue task has no reason to expect it to behave
differently, and leaving three of the four unsubstituted is the kind of half-feature that reads as a bug.
"""

from __future__ import annotations

import re
from typing import TYPE_CHECKING

from veaf_libs.i18n import t
from veaf_libs.logger import logger

if TYPE_CHECKING:  # pragma: no cover - import cycle only matters for type checkers
    from mission_tools.miz_tools import DcsMission

#: The mission fields holding player-facing briefing prose, in the order DCS shows them.
BRIEFING_FIELDS: tuple[str, ...] = (
    "descriptionText",
    "descriptionBlueTask",
    "descriptionRedTask",
    "descriptionNeutralsTask",
)

#: A ``${NAME}`` token. Names are letters, digits and underscores — deliberately narrow, so that a
#: shell-ish ``${foo:-bar}`` or a stray ``${`` in prose is not mistaken for a variable and mangled.
_TOKEN = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")


def substitute(text: str, variables: dict[str, str]) -> str:
    """Replace every known ``${NAME}`` in *text*.

    Args:
        text: The prose to substitute into.
        variables: Name to replacement value. A name absent from this mapping is left untouched.

    Returns:
        The text with known tokens replaced.

    An **unknown token is left exactly as written**, never blanked. This is player-facing text: a
    briefing showing ``${METRA}`` tells a mission maker he mistyped something, while a briefing with a
    hole in it tells him nothing and looks like the build ate his prose. Same reasoning as the
    unknown-option report on marker commands — name what was not understood rather than swallow it.
    """
    if not text:
        return text

    def _replace(match: re.Match[str]) -> str:
        name = match.group(1)
        if name not in variables:
            return match.group(0)
        return variables[name]

    return _TOKEN.sub(_replace, text)


def substitute_in_mission(mission: DcsMission, variables: dict[str, str]) -> int:
    """Substitute *variables* in every briefing field of *mission*, in place.

    Args:
        mission: The mission to rewrite. Both ``mission_content`` and ``dictionary_content`` may be
            touched, depending on where each field's text actually lives.
        variables: Name to replacement value, as :func:`substitute`.

    Returns:
        How many fields were changed. Zero is a perfectly good answer — most missions carry no token —
        and it is returned rather than logged so a caller can say so at the right level.

    A field's value is either the prose itself or a dictionary key pointing at it. The key case is the
    normal one for a mission saved by the DCS editor, and the reason this function exists instead of a
    one-line ``str.replace`` over ``mission_content``.
    """
    content = mission.mission_content
    if not content:
        return 0
    dictionary = mission.dictionary_content

    changed = 0
    for field in BRIEFING_FIELDS:
        value = content.get(field)
        if not isinstance(value, str) or not value:
            continue
        # A dictionary key is a reference, not prose: substituting into the key itself would rename the
        # entry and lose the briefing entirely.
        if dictionary is not None and value in dictionary:
            original = dictionary[value]
            replaced = substitute(original, variables)
            if replaced != original:
                dictionary[value] = replaced
                changed += 1
            continue
        replaced = substitute(value, variables)
        if replaced != value:
            content[field] = replaced
            changed += 1
    return changed


def unknown_tokens(mission: DcsMission, variables: dict[str, str]) -> list[str]:
    """Names the briefing asks for that *variables* cannot supply.

    Args:
        mission: The mission to inspect. Read-only.
        variables: The names that can be supplied.

    Returns:
        Sorted unique token names left unsubstituted.

    Used to warn rather than to fail. A mission maker who wrote ``${METAR}`` in a variant built from
    individual weather parameters — where no METAR string exists to insert — gets told why his token
    survived, instead of finding it in the briefing and assuming the feature is broken.
    """
    content = mission.mission_content
    if not content:
        return []
    dictionary = mission.dictionary_content or {}

    found: set[str] = set()
    for field in BRIEFING_FIELDS:
        value = content.get(field)
        if not isinstance(value, str) or not value:
            continue
        text = dictionary.get(value, value)
        found.update(name for name in _TOKEN.findall(text) if name not in variables)
    return sorted(found)


def apply_and_report(mission: DcsMission, variables: dict[str, str], context: str = "") -> int:
    """Substitute, then say what could not be supplied.

    Args:
        mission: The mission to rewrite in place.
        variables: Name to replacement value.
        context: What is being built, for the warning — a variant name, typically.

    Returns:
        How many briefing fields changed.
    """
    leftover = unknown_tokens(mission, variables)
    changed = substitute_in_mission(mission, variables)
    where = f" ({context})" if context else ""
    if changed:
        logger.debug(t("briefing.variables_substituted", count=changed, context=where))
    for name in leftover:
        logger.warning(t("briefing.variable_unsupplied", name=name, context=where))
    return changed
