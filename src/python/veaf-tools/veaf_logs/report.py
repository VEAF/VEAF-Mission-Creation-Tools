"""The report block: what the user pastes into ``/bug``, and the contract the intake flow reads.

The moment the analyser says *motif non catalogué* is the moment the user is both most motivated to
report and best equipped to do it — the log is open, the filter is applied, and he has just learned
the problem is unknown. Making him start again from a blank Discord message throws all of that away.

So this module assembles, in one block: the ``veaf-tools doctor`` output, the bounded and redacted
excerpt, the catalogue matches, and what the analysis could not explain. Producer
(:func:`build_report`) and reader (:func:`parse_report_block`) live here together, for the same
reason ``veaf_libs.diagnostics`` keeps its own two halves in one file: they cannot drift if they
cannot be edited apart.

**It is a paste, not a transmission.** Sending it straight to the service would mean pairing a
desktop install with a Discord account — an authentication mechanism the project does not have and
that this programme deliberately does not build.

**It is bounded to a Discord message, and says so when it does not fit.** A block silently cut at
the boundary is worse than a short one: the reader cannot tell a truncated log from a quiet one.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import UTC, datetime

from veaf_libs.diagnostics import BLOCK_END as DOCTOR_END
from veaf_libs.diagnostics import BLOCK_START as DOCTOR_START
from veaf_libs.diagnostics import DiagnosticReport
from veaf_libs.redaction import redact

from .analysis import Analysis
from .catalogue import render_catalogue

#: Identifies the block's format. A consumer checks it before parsing: a block carrying an unknown
#: schema is a block whose fields it cannot assume anything about.
SCHEMA = "veaf-logs-report/1"

#: Delimiters, deliberately unmistakable — the block travels inside prose and code fences and has to
#: be found again. They differ from the doctor block's so a nested doctor block never confuses a
#: reader looking for either one.
BLOCK_START = "=== VEAF-LOGS REPORT BEGIN ==="
BLOCK_END = "=== VEAF-LOGS REPORT END ==="

#: The free-text sections, each delimited by its own pair.
SECTIONS: tuple[str, ...] = ("doctor", "excerpt", "catalogue", "analysis", "proposals")

#: The fields, in the order the block writes them. **This tuple is the contract.** Adding a field is
#: backwards compatible; removing or renaming one bumps :data:`SCHEMA`.
FIELD_ORDER: tuple[str, ...] = (
    "schema",
    "generated",
    "excerpt.shown",
    "excerpt.selected",
    "excerpt.total",
    "excerpt.omitted",
    "excerpt.excluded",
    "catalogue.matched",
    "catalogue.uncatalogued",
    "proposals.count",
    "truncated",
)

#: How long a Discord message may be. The block is built to fit inside one, code fence included.
DISCORD_MESSAGE_LIMIT = 2000

#: What the fence costs. The block is pasted inside ```` ```text ```` so Discord does not reflow it.
FENCE_OPEN = "```text"
FENCE_CLOSE = "```"

#: What a triple backtick inside the content becomes. Left alone it would close the fence early and
#: spill the rest of the block into Discord's Markdown renderer.
FENCE_ESCAPE = "'''"

#: Every line break inside a field name or value: one field is one line, and a value carrying a
#: newline would come back as two fields, the second of them forged.
_LINE_BREAK = re.compile(r"[\r\n]+")

#: Order in which content is dropped when the block does not fit, least useful first. The excerpt is
#: absent from it: it is *shrunk* into whatever the rest leaves, and only dropped below
#: :data:`MIN_EXCERPT_CHARS`. The doctor's **fields** are absent too — they are the half of the
#: report nobody can reconstruct afterwards, and they stay whatever happens.
#:
#: ``doctor.recent-errors`` sits in the middle of the list, and that placement is measured rather
#: than guessed. On the machine this was written for, the doctor block ran to ~1 500 characters of a
#: 1 988-character budget, almost all of it Python tracebacks from unrelated ``veaf-tools`` runs —
#: and it pushed the excerpt, the catalogue and the proposals *all* out of a report about a DCS log.
#: A stack trace from another tool is worth less here than the lines the user came to report.
_DROP_ORDER: tuple[str, ...] = ("proposals", "analysis", "doctor.recent-errors", "catalogue")

#: The smallest excerpt worth keeping. Below this the section is dropped like any other, because a
#: header plus two records is not an excerpt, it is a claim that one existed.
#:
#: This is why the excerpt is not simply on the drop list. Measured against the real 11 MB
#: ``dcs.log`` on 2026-09-05: the default excerpt renders to ~16 000 characters and a Discord message
#: holds 2 000, so an excerpt dropped whole would have been dropped in **every** real report — the
#: block would have carried the machine's description and nothing about the problem it describes.
MIN_EXCERPT_CHARS = 200

#: How much room the excerpt is worth freeing droppable sections for. Without it the drop loop stops
#: as soon as the *rest* fits, which on the same real report left 100 characters — under the minimum,
#: so the excerpt was dropped while the catalogue section survived. That trade is backwards: the
#: catalogue's ids are already in the ``catalogue.matched`` field and its wording is one lookup away
#: in ``rules.json``, whereas the log lines exist nowhere else.
TARGET_EXCERPT_CHARS = 500

#: What ``truncated`` names when the excerpt was kept but made smaller. A block whose excerpt was cut
#: from 157 records to 7 has been truncated, whatever the fact that no section disappeared, and a
#: ``truncated: non`` over it would be a straight untruth.
EXCERPT_SHRUNK = "excerpt (réduit)"

#: How many times the block is recomposed before its own ``truncated`` field stops moving. The field
#: is *inside* the block it describes, so writing it changes the length it was measured from. Two
#: passes settle every case measured on the real ``dcs.log``; the third is there so that a
#: pathological one terminates rather than loops.
_MAX_RECOMPOSITIONS = 3


@dataclass(frozen=True)
class ReportBlock:
    """A parsed report block: the fields, plus each free-text section as it was written."""

    fields: dict[str, str] = field(default_factory=dict)
    sections: dict[str, str] = field(default_factory=dict)

    @property
    def doctor(self) -> DiagnosticReport | None:
        """Parse the embedded doctor block, or ``None`` when there is none to parse.

        Returns:
            The diagnostic report the block carried. ``None`` when the section is absent or does not
            hold a complete doctor block — a truncated paste, which the caller must be able to tell
            from a complete one.
        """
        from veaf_libs.diagnostics import parse_block

        text = self.sections.get("doctor", "")
        if DOCTOR_START not in text or DOCTOR_END not in text:
            return None
        try:
            return parse_block(text)
        except ValueError:
            return None


def _one_line(value: str) -> str:
    """Collapse *value* onto a single line, so one field stays one line of the block."""
    return _LINE_BREAK.sub(" ", value).strip()


def _fence_safe(text: str) -> str:
    """Neutralise anything that would close the code fence the block travels in."""
    return text.replace("```", FENCE_ESCAPE)


def _section(name: str, body: str) -> list[str]:
    """Render one delimited free-text section."""
    return [f"--- {name} ---", *body.splitlines(), f"--- {name} end ---"]


def _section_overhead(name: str) -> int:
    """Characters one section costs on top of its body: its two delimiters and their line breaks."""
    return len(f"--- {name} ---") + len(f"--- {name} end ---") + 2


def _describe_excluded(analysis: Analysis) -> str:
    """Summarise the excluded categories on one line, for the field section."""
    parts = [f"{kind}={','.join(keys)}" for kind, keys in analysis.excerpt.excluded.items()]
    return "; ".join(parts) if parts else "aucune"


def _compose(fields: dict[str, str], bodies: dict[str, str]) -> str:
    """Assemble a block from its fields and its sections, in the declared order."""
    lines = [BLOCK_START]
    ordered = [name for name in FIELD_ORDER if name in fields]
    extras = [name for name in fields if name not in FIELD_ORDER]
    for name in ordered + extras:
        lines.append(f"{_one_line(name)}: {_one_line(fields[name])}")
    for name in SECTIONS:
        body = bodies.get(name, "")
        if body:
            lines.extend(_section(name, body))
    lines.append(BLOCK_END)
    return "\n".join(lines)


def build_report(
    analysis: Analysis,
    doctor: DiagnosticReport | None = None,
    max_chars: int = DISCORD_MESSAGE_LIMIT,
) -> str:
    """Assemble the report block, bounded to one Discord message.

    Args:
        analysis: The *Explain* run to report on.
        doctor: The diagnostic report to embed. ``None`` embeds nothing — the block is still valid,
            and the field section says so by carrying no doctor section.
        max_chars: The ceiling, code fence included. Defaults to :data:`DISCORD_MESSAGE_LIMIT`.

    Returns:
        The block, **without** the code fence — :func:`to_clipboard_text` adds that — already
        redacted as a whole, so an assembled value that slipped through a part is still caught.
        When it does not fit: the commentary and the proposals are dropped whole in
        :data:`_DROP_ORDER` first, then the excerpt is *shrunk* to whatever room is left, and
        the ``truncated`` field names what went — never a cut at the boundary, which reads to the
        receiver exactly like a complete block.
    """
    fields: dict[str, str] = {
        "schema": SCHEMA,
        "generated": datetime.now(tz=UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "excerpt.shown": str(len(analysis.excerpt.entries)),
        "excerpt.selected": str(analysis.excerpt.selected),
        "excerpt.total": str(analysis.excerpt.total_indexed),
        "excerpt.omitted": str(analysis.excerpt.omitted),
        "excerpt.excluded": _describe_excluded(analysis),
        "catalogue.matched": ",".join(item.id for item in analysis.matches) or "aucun",
        "catalogue.uncatalogued": str(analysis.uncatalogued_total),
        "proposals.count": str(len(analysis.proposals)),
    }
    bodies = {
        "doctor": doctor.to_block() if doctor is not None else "",
        "excerpt": analysis.excerpt.to_text(),
        "catalogue": render_catalogue(analysis.matches),
        "analysis": analysis.commentary or analysis.model_error,
        "proposals": "\n".join(f"{item.id}: {item.match}" for item in analysis.proposals),
    }
    bodies = {name: _fence_safe(body) for name, body in bodies.items()}

    budget = max_chars - len(FENCE_OPEN) - len(FENCE_CLOSE) - 2
    dropped: list[str] = []
    fields["truncated"] = "non"

    def note_dropped(names: list[str]) -> None:
        """Write what went. **Before** the room is measured, never after: this field is part of the
        block, so a value written afterwards makes the block outgrow the room just computed for it —
        which is how a 2 000-character ceiling returned 2 010 characters."""
        fields["truncated"] = "retiré pour tenir dans un message : " + ", ".join(names)

    def without_excerpt() -> int:
        """Length of the block as it stands with no excerpt section."""
        return len(redact(_compose(fields, {**bodies, "excerpt": ""})))

    def room_for_excerpt() -> int:
        """Characters the excerpt section's *body* may use. An empty body renders no section at all,
        so the two delimiter lines it is about to cost are subtracted here."""
        return budget - without_excerpt() - _section_overhead("excerpt")

    def drop(name: str) -> bool:
        """Remove one droppable piece by name; say whether there was anything to remove."""
        if name == "doctor.recent-errors":
            if doctor is None or not doctor.recent_errors or "--- recent-errors ---" not in bodies["doctor"]:
                return False
            bodies["doctor"] = _fence_safe(DiagnosticReport(fields=doctor.fields).to_block())
            return True
        if not bodies.get(name):
            return False
        bodies[name] = ""
        return True

    # Free room *before* sizing the excerpt, not after: an excerpt sized against a block that still
    # carried what is about to be dropped would be shorter than the one that actually fits. The loop
    # keeps going until the excerpt has a decent share, not merely until the rest fits.
    for name in _DROP_ORDER:
        if room_for_excerpt() >= TARGET_EXCERPT_CHARS:
            break
        if drop(name):
            dropped.append(name)
            note_dropped(dropped)

    # The excerpt takes what is left rather than being dropped whole. The fields the shrink is about
    # to write — ``truncated``, ``excerpt.shown``, ``excerpt.omitted`` — are themselves part of the
    # block, so each pass writes them first and measures the room afterwards, and repeats until the
    # room stops moving. Measuring once and growing after left the block 22 characters past a limit
    # it had just been sized against, in 30 of 240 swept sizes on the real ``dcs.log``.
    if len(bodies["excerpt"]) > room_for_excerpt():
        note_dropped([*dropped, EXCERPT_SHRUNK])
        shrunk = None
        for _ in range(_MAX_RECOMPOSITIONS):
            room = room_for_excerpt()
            candidate = analysis.excerpt.rebound(room) if room >= MIN_EXCERPT_CHARS else None
            if candidate is None or not candidate.entries:
                shrunk = None
                break
            shrunk = candidate
            bodies["excerpt"] = _fence_safe(candidate.to_text())
            # The fields describe the block, not the analysis it came from. Leaving them at their
            # pre-shrink values would announce 157 records over a section holding 7 — and a consumer
            # has no way to catch that, since it is reading the field precisely to avoid counting.
            fields["excerpt.shown"] = str(len(candidate.entries))
            fields["excerpt.omitted"] = str(candidate.omitted)
            if len(redact(_compose(fields, bodies))) <= budget:
                break
        # A header saying "0 records shown" is not an excerpt, it is a claim that one existed. When
        # the room only pays for the header, the section goes and the field says so.
        if shrunk is not None:
            dropped.append(EXCERPT_SHRUNK)
        else:
            bodies["excerpt"] = ""
            fields["excerpt.shown"] = "0"
            fields["excerpt.omitted"] = str(analysis.excerpt.selected)
            dropped.append("excerpt")
        note_dropped(dropped)

    def composed() -> str:
        return redact(_compose(fields, bodies))

    # Still over? Keep dropping. The first loop stops as soon as the excerpt has a decent share —
    # the right trade for a block that fits, and no reason at all to hand back one that does not.
    for name in _DROP_ORDER:
        if len(composed()) <= budget:
            break
        if drop(name):
            dropped.append(name)
            note_dropped(dropped)

    block = composed()
    if len(block) > budget:
        # Nothing left to drop but the fields themselves. Saying so beats cutting at the boundary:
        # a block cut mid-line reads like a complete one to whoever receives it.
        block = _announce_overflow(fields, bodies, budget, dropped)
    return block


def _overflow_note(length: int, budget: int, dropped: list[str]) -> str:
    """Word the "does not fit" notice.

    It carries what was dropped as well as the size, for two reasons. The reader still needs to know
    what is missing from a block that overflowed — that information used to be overwritten by this
    very notice. And it makes the notice strictly longer than the one it replaces, which is what
    keeps it true: a shorter replacement could bring the block back under the limit, leaving it
    fitting while announcing that it does not. Measured before this, on 59 of 240 swept sizes.

    Args:
        length: The length the block actually has.
        budget: The ceiling it is measured against, fence excluded.
        dropped: What was already removed, in the order it went.

    Returns:
        The value for the ``truncated`` field.
    """
    note = f"OUI — {length} caractères pour une limite de {budget} : à coller en deux messages"
    return f"{note} ; retiré : {', '.join(dropped)}" if dropped else note


def _announce_overflow(fields: dict[str, str], bodies: dict[str, str], budget: int, dropped: list[str]) -> str:
    """Write the overflow notice, and make the number in it describe the block actually returned.

    The notice lives inside the block it measures, so writing it changes that measurement. Composing
    once left every announcement wrong: understated by exactly 21 — the growth of the field itself —
    on the real ``dcs.log``.

    Args:
        fields: The block's fields; ``truncated`` is written here.
        bodies: The block's sections, already final.
        budget: The ceiling the block is measured against, fence excluded.
        dropped: What was already removed, named in the notice.

    Returns:
        The composed block, whose ``truncated`` field states its own exact length. The iteration
        settles: the notice only varies by the number of digits in a length, and a longer block can
        never carry a shorter number, so there is no pair of values for it to alternate between.
    """
    block = redact(_compose(fields, bodies))
    for _ in range(_MAX_RECOMPOSITIONS):
        fields["truncated"] = _overflow_note(len(block), budget, dropped)
        recomposed = redact(_compose(fields, bodies))
        if len(recomposed) == len(block):
            return recomposed
        block = recomposed
    return block


def to_clipboard_text(block: str) -> str:
    """Wrap a block in the code fence it travels in.

    Args:
        block: The block from :func:`build_report`.

    Returns:
        The fenced text, ready to paste into Discord or a GitHub issue without being reflowed.
    """
    return f"{FENCE_OPEN}\n{block}\n{FENCE_CLOSE}"


def parse_report_block(text: str) -> ReportBlock:
    """Read a report block back — the inverse of :func:`build_report`.

    The intake flow receives this block inside a free-form message, wrapped in a code fence and
    surrounded by prose, so the parser locates the delimiters rather than assuming the block starts
    at the first line.

    **What comes back is untrusted.** Anyone can type a block by hand into a public issue. The
    producer guarantees the *shape* — one field per line — never the truth of a value.

    Args:
        text: Any text containing exactly one block.

    Returns:
        The parsed block: its fields, and each free-text section under its own name.

    Raises:
        ValueError: No block, or a block missing its end delimiter — a truncated paste, which must
            be reported rather than half-parsed.
    """
    lines = text.splitlines()
    try:
        start = next(i for i, line in enumerate(lines) if line.strip() == BLOCK_START)
        end = next(i for i, line in enumerate(lines) if i > start and line.strip() == BLOCK_END)
    except StopIteration as exc:
        raise ValueError(f"no complete {SCHEMA} block found") from exc

    fields: dict[str, str] = {}
    sections: dict[str, str] = {}
    current: str | None = None
    body: list[str] = []
    for line in lines[start + 1 : end]:
        stripped = line.strip()
        opened = _section_name(stripped, " ---")
        closed = _section_name(stripped, " end ---")
        if current is None and opened in SECTIONS:
            current = opened
            body = []
            continue
        if current is not None and closed == current:
            sections[current] = "\n".join(body)
            current = None
            continue
        if current is not None:
            body.append(line)
            continue
        name, separator, value = line.partition(":")
        if separator:
            fields[name.strip()] = value.strip()
    if current is not None:
        # An unterminated section: keep what was read rather than losing it, and let the caller see
        # the missing fields for what they are.
        sections[current] = "\n".join(body)
    return ReportBlock(fields=fields, sections=sections)


def _section_name(line: str, suffix: str) -> str:
    """Return the section name a delimiter line carries, or an empty string."""
    if line.startswith("--- ") and line.endswith(suffix):
        return line[len("--- ") : -len(suffix)]
    return ""
