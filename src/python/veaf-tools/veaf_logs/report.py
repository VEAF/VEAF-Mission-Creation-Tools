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

#: Order in which sections are dropped when the block does not fit. The doctor block is never
#: dropped — it is the half of the report a maintainer cannot reconstruct from anything else — and
#: neither is the excerpt, which is *shrunk* instead: see :data:`MIN_EXCERPT_CHARS`.
_SACRIFICE_ORDER: tuple[str, ...] = ("proposals", "analysis", "catalogue")

#: The smallest excerpt worth keeping. Below this the section is dropped like any other, because a
#: header plus two records is not an excerpt, it is a claim that one existed.
#:
#: This is why the excerpt is not simply on the sacrifice list. Measured against the real 11 MB
#: ``dcs.log`` on 2026-09-05: the default excerpt renders to ~16 000 characters and a Discord message
#: holds 2 000, so an excerpt dropped whole would have been dropped in **every** real report — the
#: block would have carried the machine's description and nothing about the problem it describes.
MIN_EXCERPT_CHARS = 200


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
        :data:`_SACRIFICE_ORDER` first, then the excerpt is *shrunk* to whatever room is left, and
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

    def note_dropped() -> None:
        fields["truncated"] = "sections retirées pour tenir dans un message : " + ", ".join(dropped)

    def without_excerpt() -> int:
        """Length of the block as it stands with no excerpt section — i.e. what the excerpt may use."""
        return len(redact(_compose(fields, {**bodies, "excerpt": ""})))

    # Free room *before* sizing the excerpt, not after: the commentary and the proposals are the
    # cheapest things to lose, and an excerpt sized against a block that still carried them would be
    # shorter than the one that fits.
    for name in _SACRIFICE_ORDER:
        if without_excerpt() <= budget:
            break
        if not bodies.get(name):
            continue
        bodies[name] = ""
        dropped.append(name)
        note_dropped()

    # The excerpt takes what is left rather than being dropped whole: measuring the block without it
    # gives the room exactly, so nothing has to be guessed about how long a header runs. An empty
    # body renders no section at all, so the two delimiter lines it will cost are subtracted here.
    room = budget - without_excerpt() - _section_overhead("excerpt")
    if len(bodies["excerpt"]) > room:
        shrunk = analysis.excerpt.rebound(room) if room >= MIN_EXCERPT_CHARS else None
        # A header saying "0 records shown" is not an excerpt, it is a claim that one existed. When
        # the room only pays for the header, the section goes and the field says so.
        if shrunk is not None and shrunk.entries:
            bodies["excerpt"] = _fence_safe(shrunk.to_text())
        else:
            bodies["excerpt"] = ""
            dropped.append("excerpt")
            note_dropped()

    block = redact(_compose(fields, bodies))
    if len(block) > budget and doctor is not None and doctor.recent_errors:
        # Last resort before giving up on the ceiling: the doctor's own error records. Its *fields*
        # are the half of the report nobody can reconstruct afterwards, so they stay whatever
        # happens; a stack trace can be pasted separately.
        bodies["doctor"] = _fence_safe(DiagnosticReport(fields=doctor.fields).to_block())
        dropped.append("doctor.recent-errors")
        note_dropped()
        block = redact(_compose(fields, bodies))
    if len(block) > budget:
        # Nothing left to drop but the fields themselves. Saying so beats cutting at the boundary:
        # a block cut mid-line reads like a complete one to whoever receives it.
        fields["truncated"] = f"OUI — {len(block)} caractères pour une limite de {budget} : à coller en deux messages"
        block = redact(_compose(fields, bodies))
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
