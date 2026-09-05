"""Turn what the catalogue does not know into a proposed catalogue entry.

The constraint on this whole flow was explicit: it must **not** create issues. That leaves the
question of how the tool ever gets better, because if nothing is captured every user pays for the
same *pattern not catalogued* answer for ever.

The answer is to capitalise on the catalogue rather than on the tracker. A message that recurs and
matches nothing in ``rules.json`` is a **missing entry**, and a proposed entry is worth more than an
issue: once merged, the next user gets a verified explanation with no model call, offline, for free.

Two rules keep it trustworthy.

**Nothing is applied.** A proposal is a proposal. ``rules.json`` stays hand-curated — that is
precisely what makes its wording quotable — so nothing here writes to it, and the generated ``help``
says outright that it is a placeholder rather than pretending to be an explanation.

**A generated regex is checked before it is offered.** Left alone, a pattern derived from one
message is either so specific it never fires again or so general it swallows the log; and a
quantifier nested in a quantified group is the classic shape that makes a regular expression take
exponential time on a line that nearly matches. :func:`validate_pattern` refuses all three.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .catalogue import subsystem_family, uncatalogued_entries
from .excerpt import Excerpt, ExcerptEntry
from .rules import Rules

#: How many times a normalised message must appear before it is worth proposing. Two occurrences is
#: a coincidence; three is the smallest number that says "this repeats".
MIN_OCCURRENCES = 3

#: How many proposals one analysis offers. A wall of candidates is a wall nobody reads.
MAX_PROPOSALS = 5

#: Longest generated pattern. Past this, the pattern is a transcription of one line, not a rule.
MAX_PATTERN_CHARS = 200

#: Literal characters a generated pattern must carry, outside its placeholders. Below this it is not
#: recognising a message, it is matching the shape of a sentence.
MIN_LITERAL_CHARS = 12

#: How long a generated label may be before it is elided.
MAX_LABEL_CHARS = 60

#: The ``help`` every proposal carries. It deliberately explains **nothing**: the value of a
#: catalogue entry is that a human wrote and reviewed its wording, and a generated sentence dressed
#: up as one would destroy exactly that.
PLACEHOLDER_HELP = "Proposition automatique, non vérifiée : reformuler cette explication avant d'ajouter la règle."

#: The variable parts of a message, and the placeholder each becomes. Order matters: quoted and
#: bracketed spans are consumed before the numbers inside them are.
_NORMALISERS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"'[^']*'"), "<q>"),
    (re.compile(r'"[^"]*"'), "<q>"),
    (re.compile(r"\[[^\]]*\]"), "<b>"),
    (re.compile(r"(?:[A-Za-z]:)?[\\/][\w .\\/+-]{3,}"), "<path>"),
    (re.compile(r"\b0[xX][0-9A-Fa-f]+\b"), "<hex>"),
    (re.compile(r"\b[0-9A-Fa-f]{8,}\b"), "<hex>"),
    (re.compile(r"\b\d+(?:\.\d+)*\b"), "<n>"),
)

#: How each placeholder comes back as a regular expression.
_PLACEHOLDER_PATTERNS: dict[str, str] = {
    "<q>": r"'[^']*'",
    "<b>": r"\[[^\]]*\]",
    "<path>": r"\S+",
    "<hex>": r"[0-9A-Fa-f]+",
    "<n>": r"[\d.]+",
    "<ip>": r"\S+",
    "<user>": r"\S+",
    "<email>": r"\S+",
    "<redacted>": r"\S+",
}

#: Splits a normalised message into placeholders and the literal text between them.
_PLACEHOLDER_SPLIT = re.compile("(" + "|".join(re.escape(name) for name in _PLACEHOLDER_PATTERNS) + ")")

#: A quantifier applied to a group that already contains one — the shape that backtracks
#: exponentially. Nothing generated here should produce it, which is exactly why it is checked.
_NESTED_QUANTIFIER = re.compile(r"\([^()]*[*+][^()]*\)\s*[*+{]")

#: Words worth keeping in a generated identifier.
_WORD = re.compile(r"[A-Za-z]{3,}")


@dataclass(frozen=True)
class ProposedRule:
    """A candidate ``rules.json`` noise entry, in the shape the file uses."""

    id: str
    label: str
    help: str
    match: str
    default_hidden: bool
    family: str
    count: int
    sample: str

    def to_entry(self) -> dict[str, object]:
        """Render the entry exactly as ``rules.json`` declares one.

        Returns:
            The mapping a maintainer can paste into the ``noise`` array. ``regex`` is stated
            explicitly even though it defaults to ``true``: the value is what the pattern *is*, and
            a reader pasting this should not have to know the default.
        """
        return {
            "id": self.id,
            "label": self.label,
            "help": self.help,
            "default_hidden": self.default_hidden,
            "match": self.match,
            "regex": True,
        }


def normalise(message: str) -> str:
    """Collapse the variable parts of a message so two occurrences of it look alike.

    Addresses, identifiers, unit names, paths and numbers are what make the same DCS complaint read
    as fifty different ones. Replacing them is the whole of the recurrence detection.

    Args:
        message: One record's message, already redacted.

    Returns:
        The message with its variable spans replaced by placeholders, whitespace collapsed.
    """
    text = message
    for pattern, placeholder in _NORMALISERS:
        text = pattern.sub(placeholder, text)
    return " ".join(text.split())


def pattern_from(normalised: str) -> str:
    """Build a regular expression that matches every message sharing this normalised form.

    Args:
        normalised: The output of :func:`normalise`.

    Returns:
        The pattern, escaped except for the placeholders, capped at :data:`MAX_PATTERN_CHARS`. The
        cap cuts at a placeholder boundary so the result is never half an escape sequence.
    """
    out: list[str] = []
    length = 0
    for piece in _PLACEHOLDER_SPLIT.split(normalised):
        if not piece:
            continue
        fragment = _PLACEHOLDER_PATTERNS.get(piece) or re.escape(piece)
        if length + len(fragment) > MAX_PATTERN_CHARS:
            break
        out.append(fragment)
        length += len(fragment)
    return "".join(out)


def literal_chars(pattern: str) -> int:
    """Count the literal characters a pattern carries, outside its placeholder fragments.

    Args:
        pattern: A generated regular expression.

    Returns:
        How many characters of real text the pattern demands. This is what separates a rule from a
        shape: ``\\S+ \\S+ [\\d.]+`` matches most of a log and says nothing.
    """
    stripped = pattern
    for fragment in set(_PLACEHOLDER_PATTERNS.values()):
        stripped = stripped.replace(fragment, " ")
    return len(re.sub(r"\\(.)", r"\1", stripped).replace(" ", ""))


def validate_pattern(pattern: str, sample: str) -> str:
    """Say why a generated pattern must not be offered, or return an empty string.

    Args:
        pattern: The candidate regular expression.
        sample: One real message the pattern is supposed to match.

    Returns:
        A reason, in French, or ``""`` when the pattern is fit to propose.
    """
    if not pattern:
        return "motif vide"
    if len(pattern) > MAX_PATTERN_CHARS:
        return "motif trop long"
    if _NESTED_QUANTIFIER.search(pattern):
        return "quantificateur imbriqué (risque d'explosion combinatoire)"
    if literal_chars(pattern) < MIN_LITERAL_CHARS:
        return "trop peu de texte littéral : le motif attraperait n'importe quoi"
    try:
        compiled = re.compile(pattern)
    except re.error as exc:
        return f"motif invalide : {exc}"
    if not compiled.search(sample):
        return "le motif ne retrouve pas la ligne dont il est issu"
    return ""


def _identifier(normalised: str, taken: set[str]) -> str:
    """Derive a free, readable ``rules.json`` id from a normalised message."""
    words = [word.lower() for word in _WORD.findall(normalised)][:3]
    base = "_".join(words) or "motif"
    candidate = base
    suffix = 2
    while candidate in taken:
        candidate = f"{base}_{suffix}"
        suffix += 1
    return candidate


def _label(normalised: str) -> str:
    """Shorten a normalised message into something readable in a list."""
    if len(normalised) <= MAX_LABEL_CHARS:
        return normalised
    return normalised[: MAX_LABEL_CHARS - 1].rstrip() + "…"


def propose_rules(
    rules: Rules,
    excerpt: Excerpt,
    min_occurrences: int = MIN_OCCURRENCES,
    limit: int = MAX_PROPOSALS,
) -> list[ProposedRule]:
    """Find the recurring messages the catalogue does not cover, and shape them as entries.

    Args:
        rules: The loaded catalogue; its existing ids are what a proposal must not collide with.
        excerpt: The bounded excerpt to mine.
        min_occurrences: How many times a normalised message must appear to be worth proposing.
        limit: How many proposals to return, most frequent first.

    Returns:
        The proposals, most frequent first. A candidate whose generated pattern fails
        :func:`validate_pattern` is dropped rather than offered — an unusable rule costs a
        maintainer more than a missing one.
    """
    groups: dict[str, list[ExcerptEntry]] = {}
    for entry in uncatalogued_entries(rules, excerpt):
        message = entry.message.strip()
        if not message:
            continue
        groups.setdefault(normalise(message), []).append(entry)

    taken = {family.id for family in rules.noise} | {source.id for source in rules.sources}
    proposals: list[ProposedRule] = []
    ranked = sorted(groups.items(), key=lambda item: (-len(item[1]), item[0]))
    for normalised, entries in ranked:
        if len(entries) < min_occurrences:
            continue
        sample = entries[0].message.strip()
        pattern = pattern_from(normalised)
        if validate_pattern(pattern, sample):
            continue
        identifier = _identifier(normalised, taken)
        taken.add(identifier)
        proposals.append(
            ProposedRule(
                id=identifier,
                label=_label(normalised),
                help=PLACEHOLDER_HELP,
                match=pattern,
                # A pattern nobody has verified must not start life hiding lines.
                default_hidden=False,
                family=subsystem_family(rules, entries[0].subsystem),
                count=len(entries),
                sample=sample,
            )
        )
        if len(proposals) >= limit:
            break
    return proposals


def render_proposals(proposals: list[ProposedRule]) -> str:
    """Render the proposals for a human who may paste one into ``rules.json``.

    Args:
        proposals: The proposals from :func:`propose_rules`.

    Returns:
        The rendered block, or an empty string when there is nothing to propose — this section is
        the only one in the output that is allowed to disappear, because "no missing entry found"
        is not information the reader needs.
    """
    if not proposals:
        return ""
    lines = [
        "Motifs récurrents non catalogués — propositions à relire avant tout ajout à rules.json :",
    ]
    for proposal in proposals:
        family = f", famille {proposal.family}" if proposal.family else ""
        lines.append(f'- {proposal.id} (×{proposal.count}{family}) : "{proposal.match}"')
        lines.append(f"    exemple : {proposal.sample}")
    return "\n".join(lines)
