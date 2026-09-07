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
message is either so specific it never fires again or so general it swallows the log; one that opens
on a wildcard is not recognising a message at all; and a quantifier nested in a quantified group is
the classic shape that makes a regular expression take exponential time on a line that nearly
matches. :func:`validate_pattern` refuses all four — and a fifth, measured rather than anticipated:
two *adjacent* unbounded quantifiers, which is the shape this module actually emits and which the
nested-quantifier check cannot see, because nothing here ever emits a parenthesised group.
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

#: Why :func:`validate_pattern` refuses a candidate. Constants rather than literals in the ``return``
#: statements: the interface shows these to the user, and a returned literal is exactly what
#: ``test_no_hardcoded_english_prose`` flags across the whole shipped package.
REJECT_EMPTY = "motif vide"
REJECT_TOO_LONG = "motif trop long"
REJECT_NESTED_QUANTIFIER = "quantificateur imbriqué (risque d'explosion combinatoire)"
REJECT_ADJACENT_QUANTIFIERS = "deux jokers illimités côte à côte (risque d'explosion combinatoire)"
REJECT_UNANCHORED = "motif non ancré : il commence par un joker et se retrouverait n'importe où"
REJECT_TOO_GENERAL = "trop peu de texte littéral : le motif attraperait n'importe quoi"
REJECT_INVALID = "motif invalide"
REJECT_NO_SELF_MATCH = "le motif ne retrouve pas la ligne dont il est issu"

#: The ``help`` every proposal carries. It deliberately explains **nothing**: the value of a
#: catalogue entry is that a human wrote and reviewed its wording, and a generated sentence dressed
#: up as one would destroy exactly that.
PLACEHOLDER_HELP = "Proposition automatique, non vérifiée : reformuler cette explication avant d'ajouter la règle."

#: The variable parts of a message, and the placeholder each becomes. Order matters: quoted and
#: bracketed spans are consumed before the numbers inside them are.
_NORMALISERS: tuple[tuple[re.Pattern[str], str], ...] = (
    # The lookbehind protects the apostrophe of a contraction, and it is the same class of defect
    # the ``<path>`` rule below was already corrected for. Without it, ``'[^']*'`` opened on the
    # ``'`` of ``can't`` and closed on the *opening* quote of the first real value, so every pairing
    # after it was offset by one. Measured on ``dcs.log-20250916-100236.zip``:
    # ``can't load destroyed model 'Ural-375_p_1' for '1L13 EWR'`` produced
    # ``can'[^']*'Ural\-375_p_1'[^']*'1L13\ EWR'`` — the unit names, which are the *variable* part,
    # baked in as literals, while ``load destroyed model`` and ``for``, which identify the
    # complaint, became wildcards. The rule could never fire on another model, and
    # ``validate_pattern`` accepted it. Contractions are at least as common in DCS messages as
    # paths: ``can't``, ``don't``, ``doesn't``, ``isn't``.
    (re.compile(r"(?<![A-Za-z0-9])'[^']*'"), "<q>"),
    (re.compile(r'"[^"]*"'), "<q>"),
    (re.compile(r"\[[^\]]*\]"), "<b>"),
    # No space in the class, deliberately. With one, this rule swallowed the rest of the sentence:
    # measured on the real ``dcs.log``, ``Source coremods/tech/… is already mounted to the same
    # mount /textures/.`` normalised to ``Source coremods<path>`` and the proposed rule lost the
    # very words that identify the complaint.
    (re.compile(r"(?:[A-Za-z]:)?[\\/][\w.\\/+-]{3,}"), "<path>"),
    (re.compile(r"\b0[xX][0-9A-Fa-f]+\b"), "<hex>"),
    # Not a run of digits, however long. A decimal is a valid hex string, so this rule used to
    # swallow one and leave a shorter one to the ``<n>`` rule below — and the *same* message then
    # normalised two different ways depending on the magnitude of its number. Measured on
    # ``dcs.log-20250909-093710.zip``: ``More out of memory in SharedBuffer for N bytes`` produced
    # two of the five offered proposals, ×9 and ×3, where a maintainer should have seen one
    # recurrence of 12. A run that carries no ``a``-``f`` is a number, not an identifier.
    (re.compile(r"\b(?![0-9]+\b)[0-9A-Fa-f]{8,}\b"), "<hex>"),
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

#: The wildcard fragments, as they appear in a generated pattern. A rule that *starts* with one of
#: them is the unanchored kind the ticket refuses: it begins by matching anything, so what follows
#: can be found anywhere in any line. This is what "anchored" means for this catalogue — not a
#: leading ``^``: 21 of the 22 hand-curated ``rules.json`` noise patterns have no ``^`` and are
#: perfectly sound, because every one of them opens on literal text.
_WILDCARD_FRAGMENTS: frozenset[str] = frozenset(_PLACEHOLDER_PATTERNS.values())

#: A quantifier applied to a group that already contains one — the shape that backtracks
#: exponentially. Nothing generated here produces it: :func:`pattern_from` emits no parenthesised
#: group at all. It is checked because :func:`validate_pattern` also guards patterns that did not
#: come from here.
_NESTED_QUANTIFIER = re.compile(r"\([^()]*[*+][^()]*\)\s*[*+{]")

#: One unbounded repetition, in the shapes this module emits: a character class or a class escape,
#: followed by ``*`` or ``+``.
_UNBOUNDED = r"(?:\[(?:[^\]\\]|\\.)*\]|\\[dDsSwW]|\.)[*+]"

#: Two unbounded repetitions with nothing between them — the shape that *is* generated here, and the
#: one the nested-quantifier guard cannot see. A Windows path makes ``<path>`` fire three times in a
#: row: measured on ``dcs.log-20250814-120017.zip``, ``Removed C:\\Users\\<user>\\Saved
#: Games\\DCS\\Logs\\dcs.…crash`` produced ``Removed\\ \\S+\\S+\\S+\\ Games\\S+``, which
#: ``validate_pattern`` accepted. Every character the first repetition gives up the second takes, so
#: a line that nearly matches walks the product: 0.5 ms at 100 characters, 262 ms at 800, 2.0 s at
#: 1 600 — and a ``rules.json`` pattern is applied to every line of an 11 MB log.
_ADJACENT_QUANTIFIERS = re.compile(_UNBOUNDED + _UNBOUNDED)

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

        Placeholders that touch and come back as the same fragment are emitted once. Several of them
        share ``\\S+`` — ``<path>``, ``<user>``, ``<ip>`` — and a Windows path makes ``<path>`` fire
        three times running, so the naive rendering was ``\\S+\\S+\\S+``: the same language as a
        single ``\\S+``, matched by walking every way of splitting the text between the three. The
        collapse is what makes the pattern linear; :data:`_ADJACENT_QUANTIFIERS` refuses the cases it
        cannot merge, such as a ``<hex>`` next to a ``<n>``.
    """
    out: list[str] = []
    length = 0
    for piece in _PLACEHOLDER_SPLIT.split(normalised):
        if not piece:
            continue
        fragment = _PLACEHOLDER_PATTERNS.get(piece) or re.escape(piece)
        if out and fragment == out[-1] and piece in _PLACEHOLDER_PATTERNS:
            continue
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
        return REJECT_EMPTY
    if len(pattern) > MAX_PATTERN_CHARS:
        return REJECT_TOO_LONG
    if _NESTED_QUANTIFIER.search(pattern):
        return REJECT_NESTED_QUANTIFIER
    if _ADJACENT_QUANTIFIERS.search(pattern):
        return REJECT_ADJACENT_QUANTIFIERS
    if any(pattern.startswith(fragment) for fragment in _WILDCARD_FRAGMENTS):
        return REJECT_UNANCHORED
    if literal_chars(pattern) < MIN_LITERAL_CHARS:
        return REJECT_TOO_GENERAL
    try:
        compiled = re.compile(pattern)
    except re.error as exc:
        return f"{REJECT_INVALID} : {exc}"
    if not compiled.search(sample):
        return REJECT_NO_SELF_MATCH
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
