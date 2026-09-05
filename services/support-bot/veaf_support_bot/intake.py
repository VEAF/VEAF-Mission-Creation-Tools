"""The ``/bug`` exchange: a form in, a filled report out, no model anywhere.

Written against a narrow protocol for the same reason ``/ask`` is: the bugs this ticket can ship are
in the **order** of the steps — acknowledge, download, assemble, hand over — and asserting on an
order needs the order to be observable without a Discord connection.

## The order, and why each step is where it is

1. **The modal is the response.** Discord closes an interaction after three seconds;
   ``send_modal`` *is* the acknowledgement, so opening the form costs nothing and cannot time out.
   The reporter then types for as long as he likes: the modal submission is a new interaction with
   its own three-second budget.
2. **Defer the submission, before any download.** Downloading an 11 MB log is not a three-second
   operation, and neither is walking a checkout for callers.
3. **Attachments first, then assembly.** A trace often appears only in the attached log, never in
   the form, so the log excerpt is scanned for locations along with the typed fields.
4. **The report goes to a sink.** Filing it is ticket 05's GitHub App and previewing it is
   ticket 04; this lot ends at a complete :class:`~veaf_support_bot.bugreport.BugReport` and a seam
   to hand it through. The default sink renders it back to the reporter, so the deterministic path
   is observable end to end before either of those exists.

## Attachments arrive on the command, not in the thread

The obvious design — open a thread and collect what the reporter drops in it — needs the bot to
receive messages, and ``discord.Intents.none()`` is a deliberate decision of the previous ticket:
this bot reads slash-command options and nothing else. Asking for the *message content* intent to
collect files would be a privileged permission bought for a convenience.

So ``/bug`` declares its attachments as **command options**. Discord uploads them before the
interaction is even created, the bot receives signed URLs in the option payload, and no intent is
involved. The ceiling on how many files one report can carry is then Discord's option limit, which
is a bound this service did not have to invent.

## Everything read here is data

The form's text, the log's lines, the mission's tables: none of it selects a code path. See
:mod:`veaf_support_bot.untrusted` for what that means concretely and
``tests/test_intake_hostile.py`` for the fixture that holds it in place.
"""

from __future__ import annotations

import tempfile
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from logging import Logger
from pathlib import Path
from shutil import rmtree
from typing import Protocol

from veaf_support_bot.attachments import AttachmentCollector, Harvest, Incoming
from veaf_support_bot.bugreport import BugForm, BugReport, MaterialNote, assemble, safe_redact
from veaf_support_bot.checkout import Checkout
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.texts import normalize_language, text
from veaf_support_bot.traces import Location
from veaf_support_bot.untrusted import one_line, quote

#: Longest preview posted back to the reporter. Discord's own message ceiling is 2000 characters.
PREVIEW_MAX_CHARS = 1900

#: Field lengths the modal enforces, mirrored here so the handler's bounds hold whatever calls it.
SUMMARY_MAX_CHARS = 200
PARAGRAPH_MAX_CHARS = 1200
DOCTOR_MAX_CHARS = 4000


@dataclass
class BugSubmission:
    """One submitted form, plus everything that came with the interaction.

    Attributes:
        form: What the reporter typed.
        attachments: The files declared as command options.
    """

    form: BugForm
    attachments: list[Incoming]


class BugExchange(Protocol):
    """What :meth:`BugIntake.handle` needs from Discord, and nothing more."""

    async def defer(self) -> None:
        """Acknowledge the modal submission, inside Discord's three-second budget."""

    async def post(self, content: str) -> None:
        """Show the reporter what the service made of his report.

        Args:
            content: The message content.
        """


#: What a finished report is handed to. Returns the sentence the reporter reads.
ReportSink = Callable[[BugReport], Awaitable[str]]


class BugIntake:
    """Runs one ``/bug`` exchange, from the submitted form to a filled report."""

    def __init__(
        self,
        checkout: Checkout,
        collector: AttachmentCollector,
        *,
        sink: ReportSink | None = None,
        logger: Logger | None = None,
        refresh: bool = True,
    ) -> None:
        """Initialize the intake.

        Args:
            checkout: The working copy every location is resolved against.
            collector: The attachment pass.
            sink: Where a finished report goes; defaults to rendering it back to the reporter.
            logger: Logger to use; defaults to the service's ``intake`` logger.
            refresh: Whether to refresh the checkout when the timer says it is due. Off in tests,
                which must not run ``git`` against a fixture.
        """
        self._checkout = checkout
        self._collector = collector
        self._sink = sink
        self._logger = logger or get_logger("intake")
        self._refresh = refresh

    async def handle(self, exchange: BugExchange, submission: BugSubmission) -> BugReport | None:
        """Run one report end to end.

        Args:
            exchange: The Discord side.
            submission: The form and its attachments.

        Returns:
            The assembled report, or ``None`` when the exchange failed after the acknowledgement —
            in which case the reporter has been told so rather than left on a placeholder.
        """
        lang = normalize_language(submission.form.language)
        await exchange.defer()
        try:
            report = await self.build(submission)
        except Exception as error:
            self._logger.exception(
                "the /bug exchange failed after the acknowledgement",
                extra={
                    "event": "intake.crashed",
                    "user": submission.form.reporter_id,
                    "error": type(error).__name__,
                },
            )
            await self._say(exchange, text("bug.error.unexpected", lang))
            return None

        message = await self._sink(report) if self._sink is not None else render_preview(report, lang)
        await self._say(exchange, message)
        self._logger.info(
            "bug report assembled",
            extra={
                "event": "intake.assembled",
                "user": submission.form.reporter_id,
                "component": report.component,
                "version": report.version,
                "locations": len(report.located),
                "unresolved": len(report.unresolved),
                "attachments": len(report.attachments),
                "notes": len(report.notes),
                "revision": report.freshness.revision,
                "stale": report.freshness.stale,
            },
        )
        return report

    async def build(self, submission: BugSubmission) -> BugReport:
        """Do the deterministic pass, attachments included.

        The temporary directory is removed whatever happens, including when the assembly raises: a
        service that leaks an 11 MB log per report fills its disk in a week, and the files have no
        use past the moment ticket 05 uploads them.

        Args:
            submission: The form and its attachments.

        Returns:
            The assembled report.
        """
        if self._refresh and self._checkout.due():
            self._checkout.refresh()
        workdir = Path(tempfile.mkdtemp(prefix="veaf-bug-"))
        try:
            harvest = await self._collector.collect(submission.attachments, workdir)
            return self._assemble(submission.form, harvest)
        finally:
            rmtree(workdir, ignore_errors=True)

    def _assemble(self, form: BugForm, harvest: Harvest) -> BugReport:
        """Fold the harvest into a report.

        Args:
            form: What the reporter typed.
            harvest: What the attachment pass produced.

        Returns:
            The report.
        """
        notes = [MaterialNote(item.filename, item.reason) for item in harvest.rejected]
        logs: list[str] = []
        missions: list[str] = []
        scanned: list[str] = []
        for item in harvest.prepared:
            if not item.rendered:
                continue
            if item.kind == "log":
                logs.append(f"**{item.filename}**\n{item.rendered}")
                scanned.append(item.rendered)
            elif item.kind == "mission":
                missions.append(f"**{item.filename}**\n{item.rendered}")
            else:
                logs.append(f"**{item.filename}**\n{item.rendered}")
            for withheld in item.withheld:
                notes.append(MaterialNote(item.filename, f"not published: {withheld}"))

        # The typed fields are redacted here rather than at render time: a home directory in "what
        # happened" is exactly as public as one in a log, and doing it once means no renderer can
        # forget. A redaction that cannot run withholds the text instead of publishing it raw.
        redacted, problem = safe_redact(self._checkout, form.all_text())
        if problem is not None:
            notes.append(problem)

        return assemble(
            _redacted_form(form, redacted),
            self._checkout,
            notes=tuple(notes),
            extra_text="\n".join(scanned),
            mission_summaries=tuple(missions),
            log_digests=tuple(logs),
            attachments=tuple(harvest.prepared),
        )

    async def _say(self, exchange: BugExchange, message: str) -> None:
        """Post to the reporter, best effort.

        Args:
            exchange: The Discord side.
            message: What to say.
        """
        try:
            await exchange.post(message[:PREVIEW_MAX_CHARS])
        except Exception as error:  # noqa: BLE001 - the last resort cannot have a resort of its own
            self._logger.error(
                "could not tell the reporter what happened to his report",
                extra={"event": "intake.reply_failed", "error": type(error).__name__},
            )


def _redacted_form(form: BugForm, redacted_text: str) -> BugForm:
    """Rebuild a form from the redacted rendering of all its fields.

    Redaction runs on the whole text at once — the account name is recognised wherever it appears,
    and splitting the text first would let a path straddling two fields through. The fields are then
    split back apart on the same boundaries.

    Args:
        form: The original form.
        redacted_text: What :meth:`BugForm.all_text` produced, redacted.

    Returns:
        The form with its five text fields replaced.

    Raises:
        ValueError: Redaction changed the number of lines, which would mis-assign the fields. It
            cannot happen — the helper substitutes within lines — and if it ever does, losing the
            report is better than filing one whose "expected" section holds someone's log.
    """
    original = form.all_text()
    if redacted_text == original:
        return form
    if redacted_text.count("\n") != original.count("\n"):
        raise ValueError("redaction changed the shape of the form; refusing to re-split it")
    summary, happened, expected, steps, doctor = _split_fields(form, redacted_text)
    return BugForm(
        summary=summary,
        happened=happened,
        expected=expected,
        steps=steps,
        doctor=doctor,
        reporter=form.reporter,
        reporter_id=form.reporter_id,
        language=form.language,
    )


def _split_fields(form: BugForm, redacted_text: str) -> tuple[str, str, str, str, str]:
    """Cut the redacted text back into the five fields, on the original line counts.

    Args:
        form: The original form, which states how many lines each field had.
        redacted_text: The redacted whole.

    Returns:
        The five fields.
    """
    lines = redacted_text.split("\n")
    out: list[str] = []
    cursor = 0
    for value in (form.summary, form.happened, form.expected, form.steps, form.doctor):
        count = value.count("\n") + 1
        out.append("\n".join(lines[cursor : cursor + count]))
        cursor += count
    return out[0], out[1], out[2], out[3], out[4]


def render_location(location: Location, lang: str) -> str:
    """Render one resolved location for the preview.

    Args:
        location: The location.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The rendered block.
    """
    head = text("bug.location", lang, path=location.relative, line=location.line)
    if location.function:
        head += " " + text("bug.in_function", lang, function=location.function)
    if location.caller_total:
        listed = ", ".join(location.callers)
        head += "\n" + text("bug.callers", lang, count=location.caller_total, listed=listed)
    return head


def render_preview(report: BugReport, lang: str) -> str:
    """Render what the deterministic pass produced, for the reporter to see.

    This is a **preview**, not the issue body: ticket 04 owns the body and the click that files it.
    What it proves today is that the pass ran and what it found — which is what makes the pipeline
    observable before a GitHub App exists.

    Args:
        report: The assembled report.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The message, bounded to what Discord accepts.
    """
    parts = [
        text("bug.received", lang, title=one_line(report.title, 120)),
        text(
            "bug.facts",
            lang,
            version=report.version,
            component=report.component,
            revision=report.freshness.describe(),
        ),
    ]
    if report.located:
        parts.append(
            text("bug.located", lang) + "\n" + "\n".join(render_location(item, lang) for item in report.located)
        )
    else:
        parts.append(text("bug.not_located", lang))
    if report.attachments:
        parts.append(text("bug.attached", lang, count=len(report.attachments)))
    if report.notes:
        listed = "\n".join(f"- {note.subject}: {note.reason}" for note in report.notes)
        parts.append(text("bug.notes", lang) + "\n" + quote(listed))
    parts.append(text("bug.next", lang))
    return "\n\n".join(parts)[:PREVIEW_MAX_CHARS]
