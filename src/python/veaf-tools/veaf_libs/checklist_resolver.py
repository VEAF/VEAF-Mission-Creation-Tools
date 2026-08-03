"""Turn an instructor's plain-words control into the technical fields a step needs.

An instructor writes ``control: main pwr sur batt``. A step needs
``element: PTR-ELEC-TMB-MPWR-510``, ``argument: 510`` and ``equals: 0.0``. This module
is what closes that gap, against the per-aircraft indexes
(:mod:`veaf_libs.cockpit_controls`) rather than a live DCS install.

**It refuses rather than guesses.** A wrong resolution is worse than no resolution: it
produces a checklist that looks finished and never ticks, and nobody finds out until a
pilot is sitting in a cockpit waiting for a line that will not go green. So a match has
to be clearly better than the runner-up, the position has to be one the control actually
has, and the value has to come from the aircraft's own input bindings — never from the
rank of a position in a hint, which is not value order.

See ``.backlog/FEAT-ASSIST-AUTHORING/tickets/03-resolver.md``.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from veaf_libs.bundled_data import bundled_dir
from veaf_libs.i18n import t

#: Folder of the committed per-aircraft indexes, under ``veaf_libs/data``.
CONTROL_INDEX_FOLDER = "cockpit-controls"

#: Words that carry no identifying weight, in either language. They are dropped from both
#: sides, so "bouton power" and "POWER Switch" meet in the middle on "power". Anything
#: naming a *kind* of control belongs here — an instructor calls the same thing a switch,
#: an interrupteur or a bouton, and the hint picks one of them.
_NOISE = frozenset(
    """
    a an the le la les un une du de des l d
    sur to on in at en dans position pos
    set put mettre place placer basculer tourner turn move
    bouton boutons button buttons switch switches interrupteur interrupteurs
    knob knobs lever leviers levier manette selector selecteur commande control
    """.split()
)

#: A match has to explain at least this much of a control's name to count at all.
_SCORE_FLOOR = 0.5

#: How much better than the runner-up the winner has to be. Two controls whose names are
#: near-identical — MAIN PWR and MAIN PWR Test — must produce a question, not a coin toss.
_MARGIN = 1.15


class ResolverError(ValueError):
    """Raised when the resolver cannot even start: no index for the aircraft."""


@dataclass(frozen=True)
class Candidate:
    """One control the text might mean, with how well it fits.

    Attributes:
        element: The cockpit element name.
        hint: Its hint, shown back to the instructor so a refusal is actionable.
        score: How much of the control's name the text accounts for.
    """

    element: str
    hint: str
    score: float


@dataclass(frozen=True)
class Resolution:
    """What the resolver decided about one ``control`` text.

    Attributes:
        fields: The technical fields to write, or empty when it refused. Never partial:
            half a step is worse than none.
        refusal: Why it refused, in one sentence an instructor can act on. Empty on
            success.
        note: Something the instructor should know about a *successful* resolution —
            today, that their control turned out to be pilot-confirmed rather than
            checked.
        candidates: The controls considered, best first.
    """

    fields: dict[str, Any] = field(default_factory=dict)
    refusal: str = ""
    note: str = ""
    candidates: list[Candidate] = field(default_factory=list)


def load_control_index(aircraft: str, index_dir: Path | None = None) -> dict[str, Any]:
    """Load the cockpit-control index of one aircraft.

    Args:
        aircraft: The DCS type name, e.g. ``F-16C_50``.
        index_dir: Where the indexes live. Defaults to the shipped folder.

    Returns:
        The parsed index.

    Raises:
        ResolverError: when the aircraft has no index, listing the ones that exist —
            "no index for Su-25T" is only useful next to what *is* indexed.
    """
    if index_dir is None:
        index_dir = bundled_dir("veaf_libs", "data", CONTROL_INDEX_FOLDER)
    path = index_dir / f"{aircraft}.yaml"
    if not path.is_file():
        known = sorted(p.stem for p in index_dir.glob("*.yaml")) if index_dir.is_dir() else []
        raise ResolverError(t("resolver.no_index", aircraft=aircraft, known=", ".join(known) or "none"))
    return dict(yaml.safe_load(path.read_text(encoding="utf-8")) or {})


def _words(text: str) -> list[str]:
    """Reduce a piece of text to its identifying words, in order.

    Lowercased, stripped of accents and punctuation, with the noise words dropped. The
    order is kept so a position can be looked for in what follows the control's name.
    """
    folded = unicodedata.normalize("NFKD", text.lower())
    folded = "".join(char for char in folded if not unicodedata.combining(char))
    return [word for word in re.split(r"[^a-z0-9]+", folded) if word and word not in _NOISE]


def _control_name(hint: str) -> str:
    """Return the part of a hint that names the control, without its positions."""
    return hint.split(",", 1)[0] if "," in hint else hint


def _score(text_words: list[str], name_words: list[str]) -> float:
    """Return how much of a control's name the instructor's text accounts for.

    Measured against the *name*, not the text: an instructor who writes three extra words
    should still match, while a control whose name is only half present should not. A
    consecutive run scores higher, so ``MAIN PWR`` beats ``MAIN PWR Test`` on
    ``main pwr`` only through the length penalty — which is exactly why that pair ends up
    ambiguous and gets refused.
    """
    if not name_words:
        return 0.0
    present = sum(1 for word in name_words if word in text_words)
    return present / len(name_words)


def _without(text_words: list[str], name_words: list[str]) -> list[str]:
    """Return *text_words* with one occurrence of each of *name_words* removed.

    The position has to be looked for in what is left once the control's own name is
    accounted for. Otherwise ``main pwr sur batt`` resolves to the MAIN PWR *position* —
    the switch is called MAIN PWR too — and the step checks the opposite of what the
    instructor asked for, silently.
    """
    remaining = list(text_words)
    for word in name_words:
        if word in remaining:
            remaining.remove(word)
    return remaining


def _find_position(text_words: list[str], positions: dict[str, float]) -> str | None:
    """Return the position of *positions* the text names, or ``None``.

    Longest first, so ``MAIN PWR`` is preferred over a bare ``PWR`` that happens to be
    another position of the same switch.
    """
    for name in sorted(positions, key=lambda item: -len(item)):
        name_words = _words(name)
        if name_words and all(word in text_words for word in name_words):
            return name
    return None


def resolve_control(text: str, index: dict[str, Any]) -> Resolution:
    """Resolve one instructor-written control description against an aircraft's index.

    Args:
        text: What the instructor wrote, e.g. ``main pwr sur batt``.
        index: The aircraft's index, from :func:`load_control_index`.

    Returns:
        The resolution: technical fields, or a refusal naming what it found.
    """
    text_words = _words(text)
    controls: dict[str, Any] = index.get("controls", {})

    scored = [
        Candidate(
            element=element,
            hint=entry.get("hint", ""),
            score=_score(text_words, _words(_control_name(entry.get("hint", "")))),
        )
        for element, entry in controls.items()
    ]
    ranked = sorted((candidate for candidate in scored if candidate.score >= _SCORE_FLOOR), key=lambda c: -c.score)

    if not ranked:
        best = sorted(scored, key=lambda c: -c.score)[:3]
        return Resolution(refusal=t("resolver.no_match", text=text), candidates=best)

    # Names that tie are not resolvable by scoring — only the instructor knows which one.
    tied = [candidate for candidate in ranked if candidate.score * _MARGIN >= ranked[0].score]
    if len(tied) > 1:
        listed = ", ".join(f"{candidate.element} ({candidate.hint})" for candidate in tied[:4])
        return Resolution(refusal=t("resolver.ambiguous", text=text, controls=listed), candidates=tied)

    winner = ranked[0]
    entry = controls[winner.element]

    if not entry.get("readable", True):
        # Not a refusal: a button genuinely has no position to poll, so pilot confirmation
        # is the only correct answer — but it is not the check that was asked for.
        return Resolution(
            fields={"element": winner.element, "confirm": True},
            note=t("resolver.unreadable", element=winner.element, hint=winner.hint),
            candidates=[winner],
        )

    values: dict[str, float] = entry.get("values") or {}
    if not values:
        named = ", ".join(entry.get("positions") or []) or "none"
        return Resolution(
            refusal=t("resolver.no_values", element=winner.element, hint=winner.hint, text=text, named=named),
            candidates=[winner],
        )

    position = _find_position(_without(text_words, _words(_control_name(winner.hint))), values)
    if position is None:
        return Resolution(
            refusal=t(
                "resolver.unknown_position",
                text=text,
                element=winner.element,
                hint=winner.hint,
                positions=", ".join(sorted(values)),
            ),
            candidates=[winner],
        )

    fields: dict[str, Any] = {
        "element": winner.element,
        "argument": entry["argument"],
        "equals": values[position],
    }
    return Resolution(fields=fields, candidates=[winner])


#: Fields the resolver owns. A re-resolution clears these before writing its own, so a
#: step that changes from a switch check to a confirm does not keep a stale `argument`.
RESOLVED_FIELDS = ("element", "argument", "equals", "confirm", "resolved_from")


@dataclass(frozen=True)
class StepOutcome:
    """What happened to one step of a file.

    Attributes:
        number: The step's 1-based position, as a pilot sees it.
        control: The text the instructor wrote.
        resolution: What the resolver made of it.
    """

    number: int
    control: str
    resolution: Resolution


def resolve_checklist_file(path: Path, index_dir: Path | None = None) -> list[StepOutcome]:
    """Resolve every stale step of a checklist file, without writing anything.

    Args:
        path: The checklist YAML.
        index_dir: Where the control indexes live. Defaults to the shipped folder.

    Returns:
        One outcome per step that needed resolving, in file order. A file whose steps are
        all up to date yields an empty list.

    Raises:
        ResolverError: when the file cannot be read as a checklist, or names no aircraft
            this project has indexed.
    """
    from veaf_libs.checklists import parse_checklist  # local: avoids a circular import

    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    checklist = parse_checklist(raw, str(path))
    index = _index_for(checklist.aircraft, index_dir)
    return [
        StepOutcome(number=number, control=step.control or "", resolution=resolve_control(step.control or "", index))
        for number, step in checklist.unresolved_steps()
    ]


def _index_for(aircraft: list[str], index_dir: Path | None) -> dict[str, Any]:
    """Return the index of the first aircraft of *aircraft* that has one.

    A checklist may list several types — an F-16C block 50 and its variants — and they
    share a cockpit, so the first indexed one answers for all of them.
    """
    problems: list[str] = []
    for type_name in aircraft:
        try:
            return load_control_index(type_name, index_dir)
        except ResolverError as error:
            problems.append(str(error))
    raise ResolverError(problems[0] if problems else t("resolver.no_aircraft"))


def apply_resolutions(path: Path, outcomes: list[StepOutcome]) -> int:
    """Write the resolved fields back into the checklist, in place.

    Comments and layout survive: the file belongs to the instructor, and a resolver that
    reformatted it — or dropped the notes explaining *why* a step exists — would make
    itself unusable after the first run.

    Args:
        path: The checklist YAML.
        outcomes: What :func:`resolve_checklist_file` returned.

    Returns:
        The number of steps written.

    Raises:
        ResolverError: if any outcome is a refusal. Nothing is written in that case: a
            half-resolved file is worse than an unresolved one, because it looks done.
    """
    refused = [outcome for outcome in outcomes if not outcome.resolution.fields]
    if refused:
        raise ResolverError(t("resolver.left_untouched", count=len(refused)))

    from ruamel.yaml import YAML

    editor = YAML()
    editor.preserve_quotes = True
    # Match how a checklist is actually written — `  - label:` — instead of ruamel's
    # flush-left default. Without this every run reindents the whole file, which turns a
    # two-line resolution into a diff the instructor cannot read.
    editor.indent(mapping=2, sequence=4, offset=2)
    editor.width = 4096
    with path.open(encoding="utf-8") as handle:
        document = editor.load(handle)

    steps = document["steps"]
    for outcome in outcomes:
        step = steps[outcome.number - 1]
        for name in RESOLVED_FIELDS:
            if name in step:
                del step[name]

        # The blank line separating two steps is attached to whichever key currently comes
        # last. Appending fields under it would move the separator inside the step, so it
        # is detached first and reattached to the new last key.
        existing = list(step.keys())
        trailing = step.ca.items.pop(existing[-1], None) if existing else None

        for name, value in outcome.resolution.fields.items():
            step[name] = value
        step["resolved_from"] = outcome.control

        if trailing is not None:
            step.ca.items["resolved_from"] = trailing

    with path.open("w", encoding="utf-8", newline="\n") as handle:
        editor.dump(document, handle)
    return len(outcomes)
