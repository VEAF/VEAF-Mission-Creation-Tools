"""Turn what is on screen into a bounded, redacted, transmissible excerpt.

An 11 MB ``dcs.log`` — measured on the machine this was written for, 2026-09-05 — cannot be
uploaded to Discord, cannot enter a model's context and cannot be read by a human. But by the time
the user asks a question, ``veaf-logs`` has already done the reduction: the categories, the levels,
the noise families and the search context have brought the file down to the handful of records on
screen. This module is the missing step that turns *that view* into an artefact something else can
consume.

Three properties, and each one exists because its absence caused a specific failure.

**Bounded.** A hard ceiling in characters, applied after selection, with the drop stated
(``… 412 entrées omises …``) instead of silent. The head and the tail are both kept: the first
records carry the cause, the last ones carry the symptom, and a naive "keep the last N" throws away
half of every chain.

**Honest about what was hidden.** The header states which categories were set to ✕. A log filtered
down to "no errors" because the user unticked ``ERROR`` must not read as a clean log, so an excluded
severity is called out in as many words rather than left for the reader to deduce from a list.

**Redacted.** Through :func:`veaf_libs.redaction.redact`, applied here rather than reimplemented —
that module is deliberately the only set of patterns in the project.

The trap next door: **context lines must never resurrect an excluded category.** ``evaluate`` already
guarantees it (its search context can only re-open what the categories allowed *before* the text
criteria narrowed), but this module re-checks every selected index against the category states
anyway. The check is cheap, and the caller may hand in indices computed by something other than
``evaluate`` — the UI passes the rows its model happens to hold.
"""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field

from veaf_libs.redaction import redact

from .filters import FilterSet, State, evaluate
from .parser import Entry
from .store import LogStore

#: How many characters the rendered excerpt may occupy. The Worker's ``/analyze`` route truncates at
#: 40 000 and the ``logs`` client's body ceiling is 128 KiB, so this sits well inside both while
#: still holding a few hundred records — the point is a *readable* excerpt, not a second log file.
DEFAULT_MAX_CHARS = 16000

#: How wide one rendered record may be. Same reasoning as ``veaf_libs.diagnostics``: a single DCS
#: record quoting a rejected expression runs past 400 characters, and no record limit bounds that.
MAX_CHARS_PER_LINE = 300

#: How many continuation lines of one record survive. A Lua stack traceback is the most useful thing
#: in the file and the least useful thing to have in full: the top frames name the fault.
MAX_CONTINUATION_LINES = 8

#: Appended to a line cut at :data:`MAX_CHARS_PER_LINE`.
TRUNCATION_MARK = " […]"

#: Levels whose absence changes the meaning of the whole excerpt. Hiding one of these is what turns
#: a broken session into a clean-looking log, so it is stated rather than listed.
SEVERE_LEVELS: frozenset[str] = frozenset({"ALERT", "ERROR", "ERROR_ONCE"})

#: The three category families of a :class:`~veaf_logs.filters.FilterSet`, and the label the header
#: prints for each.
_KIND_LABELS: tuple[tuple[str, str], ...] = (
    ("levels", "niveaux"),
    ("sources", "sources"),
    ("noise", "familles de bruit"),
)


@dataclass(frozen=True)
class ExcerptEntry:
    """One record of the excerpt, already redacted and already capped.

    The shape is kept — timestamp, level, source, subsystem — rather than flattened to a line of
    text: the model needs it to chain events, and so does a human reading the report block later.
    """

    lineno: int
    timestamp: str
    level: str
    source: str
    """The display label — ``VEAF-GRASS``, ``DX11BACKEND``. What a reader recognises."""

    source_id: str
    """The catalogue's own id for the emitter (``veaf``, ``ctld``, ``dcs``). What code matches on:
    the label of a recognised source can itself contain a hyphen (``dcs-bridge``), so splitting the
    label to strip a module suffix is not a way to tell a script apart from a native subsystem."""

    subsystem: str
    message: str
    noise: tuple[str, ...] = ()
    continuations: tuple[str, ...] = ()

    def render(self) -> str:
        """Render this record as the excerpt shows it, continuation lines included."""
        head = f"{self.timestamp or '--:--:--':<12} {self.level:<10} {self.source:<12} {self.message}"
        lines = [_cap(head)]
        lines.extend(f"    {_cap(line)}" for line in self.continuations)
        return "\n".join(lines)


@dataclass(frozen=True)
class Excerpt:
    """A bounded, redacted view of a log, plus everything needed to read it honestly."""

    entries: list[ExcerptEntry] = field(default_factory=list)
    """The records kept, in log order."""

    total_indexed: int = 0
    """How many records the store held — the denominator the reader needs."""

    selected: int = 0
    """How many records the view held before the character ceiling applied."""

    omitted: int = 0
    """How many of those the ceiling dropped. Zero when everything fitted."""

    excluded: dict[str, list[str]] = field(default_factory=dict)
    """Category keys set to ✕, by family. These are the ones whose absence proves nothing."""

    context_only: dict[str, list[str]] = field(default_factory=dict)
    """Category keys set to ◐: present only next to a kept record."""

    searches: list[str] = field(default_factory=list)
    """The active text criteria, as the interface describes them."""

    @property
    def hidden_severity(self) -> list[str]:
        """Severe levels the user excluded, in :data:`SEVERE_LEVELS` order of appearance."""
        return [level for level in self.excluded.get("levels", ()) if level in SEVERE_LEVELS]

    def header_lines(self) -> list[str]:
        """Build the header: what this excerpt is, and above all what it is not.

        Returns:
            The header lines, without a trailing blank. Always at least one line, so an excerpt with
            no filter at all still states its own denominator.
        """
        lines = [f"[veaf-logs] {len(self.entries)} entrées sur {self.total_indexed} indexées"]
        if self.omitted:
            lines[0] += f" ({self.selected} retenues, {self.omitted} omises par la limite de taille)"
        for kind, label in _KIND_LABELS:
            keys = self.excluded.get(kind)
            if keys:
                lines.append(f"masqué (✕) — {label} : {', '.join(keys)}")
        for kind, label in _KIND_LABELS:
            keys = self.context_only.get(kind)
            if keys:
                lines.append(f"contexte (◐) — {label} : {', '.join(keys)}")
        if self.searches:
            lines.append(f"recherche : {' | '.join(self.searches)}")
        if self.hidden_severity:
            lines.append(
                f"ATTENTION : {', '.join(self.hidden_severity)} est masqué — "
                "l'absence de ces lignes dans cet extrait ne prouve rien."
            )
        return lines

    def to_text(self) -> str:
        """Render the whole excerpt: the header, then the records.

        Returns:
            The excerpt as it travels, without a trailing newline. Everything in it has already been
            redacted at construction, so a caller may publish it as it stands.
        """
        blocks = ["\n".join(self.header_lines())]
        if self.omitted and self.entries:
            body = [entry.render() for entry in self.entries]
            cut = _split_point(len(body))
            body.insert(cut, f"… {self.omitted} entrées omises …")
            blocks.append("\n".join(body))
        elif self.entries:
            blocks.append("\n".join(entry.render() for entry in self.entries))
        else:
            blocks.append("(aucune ligne retenue par les filtres courants)")
        return "\n".join(blocks)


def _cap(line: str) -> str:
    """Cut one rendered line to :data:`MAX_CHARS_PER_LINE`, marking what was dropped."""
    return line if len(line) <= MAX_CHARS_PER_LINE else line[:MAX_CHARS_PER_LINE] + TRUNCATION_MARK


def _split_point(count: int) -> int:
    """Where the omission marker goes: after the head half of *count* kept records."""
    return (count + 1) // 2


def excluded_keys(filters: FilterSet) -> dict[str, list[str]]:
    """List the category keys the user set to ✕, by family.

    Args:
        filters: The filter set backing the current view.

    Returns:
        A mapping of family name to sorted keys. A family with nothing excluded is absent, so the
        header prints nothing for it.
    """
    return _keys_in_state(filters, State.OFF)


def context_keys(filters: FilterSet) -> dict[str, list[str]]:
    """List the category keys the user set to ◐, by family.

    Args:
        filters: The filter set backing the current view.

    Returns:
        A mapping of family name to sorted keys, families with nothing in ◐ omitted.
    """
    return _keys_in_state(filters, State.CONTEXT)


def _keys_in_state(filters: FilterSet, wanted: State) -> dict[str, list[str]]:
    """Collect the keys of every family sitting in *wanted*."""
    found: dict[str, list[str]] = {}
    for kind, _label in _KIND_LABELS:
        table: dict[str, State] = getattr(filters, kind)
        keys = sorted(key for key, state in table.items() if state is wanted)
        if keys:
            found[kind] = keys
    return found


def is_excluded(store: LogStore, filters: FilterSet, index: int) -> bool:
    """Say whether a record belongs to a category the user set to ✕.

    This is the guard the ticket calls "the trap next door". ``evaluate`` already refuses to let a
    context line resurrect an excluded category, but the excerpt builder is downstream of it and may
    be handed indices from elsewhere; re-checking here means the promise holds whatever produced the
    selection.

    Args:
        store: The indexed log.
        filters: The filter set backing the current view.
        index: The record to test.

    Returns:
        ``True`` when the record's level, source or **any** of its noise families is ✕.
    """
    if filters.levels.get(store.level_of(index)) is State.OFF:
        return True
    if filters.sources.get(store.source_of(index)) is State.OFF:
        return True
    return any(filters.noise.get(family) is State.OFF for family in store.noise_of(index))


def _to_excerpt_entry(entry: Entry) -> ExcerptEntry:
    """Convert a store record into a redacted excerpt record."""
    trace = entry.continuations[:MAX_CONTINUATION_LINES]
    dropped = len(entry.continuations) - len(trace)
    if dropped > 0:
        trace = [*trace, f"… {dropped} lignes de trace omises …"]
    source = f"{entry.source_label}-{entry.module}" if entry.module else entry.source_label
    return ExcerptEntry(
        lineno=entry.lineno,
        # The timestamp and the level come from the record header, which DCS writes itself: they are
        # a clock reading and a keyword, and there is nothing in either for redaction to find.
        timestamp=entry.time_only,
        level=entry.level,
        source=redact(source),
        source_id=entry.source,
        subsystem=redact(entry.subsystem),
        message=redact(entry.message or entry.raw),
        noise=entry.noise,
        continuations=tuple(redact(line) for line in trace),
    )


def _fit(entries: Sequence[ExcerptEntry], max_chars: int) -> tuple[list[ExcerptEntry], int]:
    """Keep as many records as the ceiling allows, taking from both ends.

    The head carries the cause and the tail carries the symptom, so a budget is spent alternately on
    each rather than on a single window. A record whose own rendering already exceeds the whole
    budget is still kept when it is the only one — an excerpt of nothing is worse than a long line.

    Args:
        entries: The selected records, in log order.
        max_chars: The character ceiling for the rendered records.

    Returns:
        The kept records in log order, and how many were dropped.
    """
    if not entries:
        return [], 0
    budget = max_chars
    head: list[ExcerptEntry] = []
    tail: list[ExcerptEntry] = []
    low, high = 0, len(entries) - 1
    take_head = True
    while low <= high:
        index = low if take_head else high
        cost = len(entries[index].render()) + 1
        if cost > budget and (head or tail):
            break
        budget -= cost
        if take_head:
            head.append(entries[index])
            low += 1
        else:
            tail.append(entries[index])
            high -= 1
        take_head = not take_head
    kept = head + tail[::-1]
    return kept, len(entries) - len(kept)


def build_excerpt(
    store: LogStore,
    filters: FilterSet,
    visible: Iterable[int] | None = None,
    max_chars: int = DEFAULT_MAX_CHARS,
) -> Excerpt:
    """Produce the bounded, redacted, structured excerpt of the current view.

    This is the single entry point the three tickets downstream share: the analysis sends it to the
    Worker, the report block embeds it, and the rule proposer reads its messages.

    Args:
        store: The indexed log.
        filters: The filter set backing the current view; it supplies both the selection and the
            list of categories the header has to declare.
        visible: The record indices the view holds. Defaults to re-running
            :func:`~veaf_logs.filters.evaluate`, which is what the interface displays.
        max_chars: Character ceiling for the rendered records, header excluded.

    Returns:
        The excerpt. Every field is already redacted, and the header states what was excluded, so
        the result is safe to publish and honest about its own gaps.
    """
    indices = list(evaluate(store, filters) if visible is None else visible)
    # The guard: whatever produced the selection, a record of an excluded category never travels.
    allowed = [index for index in indices if 0 <= index < len(store) and not is_excluded(store, filters, index)]
    entries = [_to_excerpt_entry(store.entry(index)) for index in allowed]
    kept, omitted = _fit(entries, max_chars)
    return Excerpt(
        entries=kept,
        total_indexed=len(store),
        selected=len(entries),
        omitted=omitted,
        excluded=excluded_keys(filters),
        context_only=context_keys(filters),
        searches=[item.describe() for item in filters.text_filters if item.enabled and item.pattern],
    )
