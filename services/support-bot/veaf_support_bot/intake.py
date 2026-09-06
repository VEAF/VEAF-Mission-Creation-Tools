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
4. **Sweep, show, then file — in that order.** The prior-art sweep runs before anything is opened;
   the issue is then rendered *as it will be filed* and put to the reporter with three buttons; and
   only a press of *File the issue* reaches GitHub. Every other answer — edit, cancel, a silence —
   leaves the tracker untouched and says which one it was. A deployment with no GitHub App at all
   still shows the deterministic pass, so the pipeline stays observable end to end.

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

import asyncio
import tempfile
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, replace
from logging import Logger
from pathlib import Path
from shutil import rmtree
from typing import Protocol

from veaf_support_bot.attachments import AttachmentCollector, Harvest, Incoming
from veaf_support_bot.bugreport import BugForm, BugReport, MaterialNote, assemble, safe_redact
from veaf_support_bot.checkout import Checkout
from veaf_support_bot.draft import CANCEL, EDIT, EXPIRED, FILE, Draft
from veaf_support_bot.enrichment import DISABLED, Enricher
from veaf_support_bot.filing import Outcome
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.priorart import DUPLICATE, FIXED, IN_PROGRESS, PriorArtGate, Sweep
from veaf_support_bot.texts import normalize_language, text
from veaf_support_bot.traces import Location
from veaf_support_bot.untrusted import one_line, quote

#: Longest preview posted back to the reporter. Discord's own message ceiling is 2000 characters.
PREVIEW_MAX_CHARS = 1900

#: Where a reporter is sent when the bot could not file for him. Never a dead end: the report is
#: already rendered above the link, so it can be pasted straight into the form.
REPOSITORY_URL = "https://github.com/VEAF/VEAF-Mission-Creation-Tools"

#: Field lengths the modal enforces, mirrored here so the handler's bounds hold whatever calls it.
SUMMARY_MAX_CHARS = 200
PARAGRAPH_MAX_CHARS = 1200
DOCTOR_MAX_CHARS = 4000

#: How much of an escalated ``/ask`` exchange is carried into the form. Discord **refuses** a modal
#: whose pre-filled value is longer than the field, so an unsatisfying answer of two thousand
#: characters would not produce a truncated form — it would produce no form at all. The two bounds
#: leave room for the sentence that introduces them.
ESCALATED_QUESTION_CHARS = 300
ESCALATED_ANSWER_CHARS = 700

#: Longest follow-up thread name. Discord's own ceiling is 100 characters.
THREAD_NAME_MAX_CHARS = 90

#: Longest title echoed into the opening message of that thread.
TITLE_IN_THREAD_MAX_CHARS = 200


@dataclass
class BugSubmission:
    """One submitted form, plus everything that came with the interaction.

    Attributes:
        form: What the reporter typed.
        attachments: The files declared as command options.
        thread_url: Where this report was made, so the issue can point back at it. Ticket 06 fills
            it; until then the issue says the thread was not recorded rather than inventing a link.
        roles: Discord role ids the reporter holds, read off the interaction. They gate the
            automatic hypothesis and nothing else — the report itself is the same for everybody.
            Read from the interaction rather than asked for: it costs nothing and cannot be forged.
    """

    form: BugForm
    attachments: list[Incoming]
    thread_url: str = ""
    roles: tuple[str, ...] = ()


class BugExchange(Protocol):
    """What :meth:`BugIntake.handle` needs from Discord, and nothing more."""

    async def defer(self) -> None:
        """Acknowledge the modal submission, inside Discord's three-second budget."""

    async def post(self, content: str) -> None:
        """Show the reporter what the service made of his report.

        Args:
            content: The message content.
        """

    async def decide(self, content: str, lang: str) -> str:
        """Show the draft and return what the reporter chose to do with it.

        This is the step that publishes, or does not. It lives on the exchange rather than on the
        service because the buttons hang off *this* reporter's own message: a consent object built
        once at start-up would have nowhere to draw them.

        Args:
            content: The draft, rendered and bounded.
            lang: ``"fr"`` or ``"en"``, for the button labels.

        Returns:
            One of :data:`~veaf_support_bot.draft.CHOICES`. Anything that is not
            :data:`~veaf_support_bot.draft.FILE` leaves the tracker untouched, so a silence, a
            refusal and a Discord failure are all safe answers.
        """

    async def confirm(self, content: str, lang: str) -> bool:
        """Show a prior-art match with its evidence and return whether the reporter recognised it.

        Args:
            content: The proposal, with the evidence it was computed from.
            lang: ``"fr"`` or ``"en"``, for the button labels.

        Returns:
            ``True`` only when he says it is the same subject. Everything else — *mine is
            different*, a silence, a failure — answers ``False`` and the report carries on, because
            a machine's unanswered guess must never silence a real bug.
        """

    async def open_followup_thread(self, name: str) -> ThreadHandle:
        """Open the public thread the issue's news will come back into.

        The exchange itself is ephemeral: the preparation concerns the reporter and nobody else.
        What is public is the report, once he has decided to file it — and it needs a room a
        maintainer's answer can be carried into, because the issue is filed under a machine account
        the reporter is subscribed to nothing on.

        Args:
            name: The thread name.

        Returns:
            Where it was opened. An empty handle means no thread could be opened — a missing
            permission, a channel that holds none — and the report is filed anyway, saying the
            thread was not recorded rather than inventing a link.
        """

    async def post_in_thread(self, handle: ThreadHandle, content: str) -> None:
        """Post the opening message once the issue exists and can be linked to.

        Args:
            handle: The thread opened by :meth:`open_followup_thread`.
            content: What to post.
        """


@dataclass(frozen=True)
class ThreadHandle:
    """Where a report's follow-up thread lives, or nothing.

    Attributes:
        channel_id: The channel it belongs to. Kept alongside the thread id so a restart can reach
            it without a warm Discord cache.
        thread_id: The thread.
        url: Its address, which is what the issue links back to.
        handle: The library object the thread was opened from, kept so posting into it needs no
            cache lookup. The bot runs on ``Intents.none()``, so a freshly created thread is
            routinely absent from the cache: resolving it by id right after creating it is a
            silent way to lose the message that carries the issue's address.
    """

    channel_id: int = 0
    thread_id: int = 0
    url: str = ""
    handle: object | None = None

    @property
    def opened(self) -> bool:
        """Say whether there is a thread to answer in.

        Returns:
            ``True`` when one was opened.
        """
        return self.thread_id > 0


class ReportTracker(Protocol):
    """What the intake needs from :mod:`veaf_support_bot.relay`, and nothing more."""

    def remember(self, issue: int, *, channel_id: int, thread_id: int, lang: str) -> None:
        """Record that one issue must report back into one thread.

        Args:
            issue: The issue that was filed.
            channel_id: Channel the thread lives in.
            thread_id: The thread.
            lang: Language the reporter was answered in.
        """


class _AskTheReporter:
    """The :class:`~veaf_support_bot.priorart.MatchConfirmation` protocol, over the exchange.

    The sweep speaks in :class:`~veaf_support_bot.priorart.Sweep` objects and the exchange speaks in
    strings, so the rendering — which is where the *evidence* is put in front of the reporter —
    happens here, on this side of the seam. Discord never sees a sweep, and the intake never draws a
    button.

    Attributes:
        exchange: Who gets asked.
    """

    def __init__(self, exchange: BugExchange) -> None:
        """Initialize the adapter.

        Args:
            exchange: The Discord side.
        """
        self._exchange = exchange

    async def confirm(self, sweep: Sweep, lang: str) -> bool:
        """Put the match, with its evidence, to the reporter.

        Args:
            sweep: The finding.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            Whether he recognised it as the same subject.
        """
        return await self._exchange.confirm(render_match(sweep, lang), lang)


#: What a finished report is handed to. Returns the sentence the reporter reads.
ReportSink = Callable[[BugReport], Awaitable[str]]

#: What the reporter is told for each answer that is not "file it". Written as a table rather than
#: as branches so a new answer cannot be added without a sentence to go with it — a decision the
#: reporter makes and the bot does not acknowledge reads exactly like a bot that crashed.
DECLINED: dict[str, str] = {
    EDIT: "draft.editing",
    CANCEL: "draft.cancelled",
    EXPIRED: "draft.expired",
}


class ReportFiler(Protocol):
    """What the intake needs from :mod:`veaf_support_bot.filing`, and nothing more.

    A protocol so the whole exchange — sweep, proposal, refusal, filing — is asserted without a
    GitHub App, which does not exist yet.
    """

    async def file(self, report: BugReport, *, thread_url: str = "") -> Outcome:
        """Open the issue for a report, exactly once.

        Args:
            report: The assembled report.
            thread_url: Link back to the Discord thread.

        Returns:
            What became of it.
        """

    async def comment_on(self, number: int, report: BugReport, *, thread_url: str = "") -> Outcome:
        """Add the observation to an existing issue instead of opening a second one.

        Args:
            number: The issue to comment on.
            report: The assembled report.
            thread_url: Link back to the Discord thread.

        Returns:
            What became of it.
        """

    def draft_of(self, report: BugReport, *, thread_url: str = "") -> Draft:
        """Render the issue exactly as :meth:`file` would create it.

        Args:
            report: The assembled report.
            thread_url: Link back to the Discord thread.

        Returns:
            The title and body that would be sent.
        """

    def comment_draft_of(self, report: BugReport, *, thread_url: str = "") -> Draft:
        """Render what :meth:`comment_on` would add to an existing issue.

        Args:
            report: The assembled report.
            thread_url: Link back to the Discord thread.

        Returns:
            The comment as it would be posted.
        """

    async def add_comment(self, number: int, body: str) -> Outcome:
        """Add one comment to an issue this service filed.

        Args:
            number: The issue.
            body: The comment body, already rendered and redacted.

        Returns:
            What became of it.
        """


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
        prior_art: PriorArtGate | None = None,
        filer: ReportFiler | None = None,
        enricher: Enricher | None = None,
        tracker: ReportTracker | None = None,
    ) -> None:
        """Initialize the intake.

        Args:
            checkout: The working copy every location is resolved against.
            collector: The attachment pass.
            sink: Where a finished report goes; defaults to rendering it back to the reporter.
            logger: Logger to use; defaults to the service's ``intake`` logger.
            refresh: Whether to refresh the checkout when the timer says it is due. Off in tests,
                which must not run ``git`` against a fixture.
            prior_art: The four-source sweep and the step that lets the reporter refuse it. ``None``
                skips the sweep entirely, and the issue then says nothing was checked rather than
                implying it was.
            filer: Where an accepted report is filed. ``None`` means this deployment has no GitHub
                App yet: the report is prepared and shown, and the reporter is told plainly that
                nothing was opened.
            enricher: The one model call, run **after** the issue exists. ``None`` files reports
                with no hypothesis section at all, which is what a deployment without the paid path
                looks like — not a degraded one.
            tracker: What remembers which thread an issue must answer in. ``None`` files the report
                and opens the thread all the same; what is lost is the follow-up, not the report.
        """
        self._checkout = checkout
        self._collector = collector
        self._sink = sink
        self._logger = logger or get_logger("intake")
        self._refresh = refresh
        self._prior_art = prior_art
        self._filer = filer
        self._enricher = enricher
        self._tracker = tracker

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
        # The downloaded files live until the sink has had them. Ticket 05 uploads them to the
        # issue, and a cleanup inside `build` would hand it paths that no longer exist — the exact
        # shape of bug where the report is complete and the evidence is gone.
        workdir = Path(tempfile.mkdtemp(prefix="veaf-bug-"))
        try:
            try:
                report = await self.build(submission, workdir)
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

            report, message = await self._decide(exchange, report, lang, submission)
            await self._say(exchange, message)
        finally:
            rmtree(workdir, ignore_errors=True)
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

    async def _decide(
        self, exchange: BugExchange, report: BugReport, lang: str, submission: BugSubmission
    ) -> tuple[BugReport, str]:
        """Run the prior-art step, then either act on it or file the report.

        The order is the whole of ticket 03: the sweep happens **before** anything is opened, and
        its conclusion is never applied on its own — :class:`~veaf_support_bot.priorart.PriorArtGate`
        returns whether the reporter accepted it, and a gate with nobody to ask returns ``False``.

        Args:
            report: The assembled report.
            lang: ``"fr"`` or ``"en"``.
            submission: The form, its attachments, the thread it came from and the reporter's
                roles — everything the steps below need that the report itself does not carry.

        Returns:
            A pair of the report, now carrying the finding, and what the reporter is told.
        """
        sweep, accepted = await self._sweep(exchange, report, lang)
        report = replace(report, prior_art=sweep)
        if accepted and sweep is not None:
            return report, await self._act_on(exchange, sweep, report, lang, submission)
        if self._sink is not None:
            return report, await self._sink(report)
        return report, await self._file(exchange, report, lang, submission)

    async def _sweep(self, exchange: BugExchange, report: BugReport, lang: str) -> tuple[Sweep | None, bool]:
        """Compare the report against everything already recorded.

        Args:
            report: The assembled report.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            A pair of the finding — ``None`` when no sweep is configured — and whether the reporter
            accepted the proposed match.
        """
        if self._prior_art is None:
            return None, False
        sweep, accepted = await self._prior_art.run(sweep_query(report), lang, confirmation=_AskTheReporter(exchange))
        self._logger.info(
            "prior art swept",
            extra={
                "event": "intake.prior_art",
                "verdict": sweep.verdict,
                "accepted": accepted,
                "reference": sweep.best.candidate.reference if sweep.best else "",
                "score": sweep.best.score if sweep.best else 0.0,
                "problems": list(sweep.problems),
            },
        )
        return sweep, accepted

    async def _act_on(
        self, exchange: BugExchange, sweep: Sweep, report: BugReport, lang: str, submission: BugSubmission
    ) -> str:
        """Do what an accepted match asks for, which for three of the four verdicts is nothing.

        The fourth — a duplicate — writes a **comment on a public tracker**, carrying the same
        material an issue would: his words, his environment, what was extracted on his behalf.
        Recognising an issue as his is not the same act as agreeing to publish twenty lines under
        it, so this goes through the same click as the issue does.

        Args:
            exchange: The Discord side, which is who gets asked.
            sweep: The accepted finding.
            report: The assembled report.
            lang: ``"fr"`` or ``"en"``.
            submission: What came in with the report, for the thread link.

        Returns:
            What the reporter is told.
        """
        proposal = render_match(sweep, lang)
        if sweep.verdict != DUPLICATE or self._filer is None:
            return proposal
        number = _issue_number(sweep)
        if number == 0:
            return proposal
        draft = self._filer.comment_draft_of(report, thread_url=submission.thread_url)
        choice = await exchange.decide(draft.render(lang, header="draft.header_comment"), lang)
        self._logger.info(
            "the reporter decided what to do with his observation",
            extra={"event": "intake.decided_comment", "user": report.form.reporter_id, "choice": choice},
        )
        if choice != FILE:
            return text(DECLINED.get(choice, "draft.cancelled"), lang)
        outcome = await self._filer.comment_on(number, report, thread_url=submission.thread_url)
        return proposal + "\n\n" + _render_outcome(outcome, lang, report)

    async def _file(self, exchange: BugExchange, report: BugReport, lang: str, submission: BugSubmission) -> str:
        """Show the issue, wait for the click, and file it — or say why nothing was filed.

        The order is ticket 04's whole point: the reporter sees the body that will be published,
        under a machine account that does not carry his name, and nothing reaches GitHub until he
        says so. Every path that is not a click leaves the tracker untouched and says which one it
        was, because a draft nobody acted on must never become an issue later.

        Args:
            report: The assembled report.
            lang: ``"fr"`` or ``"en"``.
            submission: What came in with the report: the thread link, and the roles that decide
                whether the filed issue also gets an automatic hypothesis.

        Returns:
            What the reporter is told.
        """
        if self._filer is None:
            return render_preview(report, lang) + "\n\n" + text("filed.disabled", lang)
        draft = self._filer.draft_of(report, thread_url=submission.thread_url)
        choice = await exchange.decide(draft.render(lang), lang)
        self._logger.info(
            "the reporter decided what to do with his draft",
            extra={"event": "intake.decided", "user": report.form.reporter_id, "choice": choice},
        )
        if choice != FILE:
            return text(DECLINED.get(choice, "draft.cancelled"), lang)
        # The thread is opened *after* the click and *before* the filing: after, because an
        # abandoned draft must not leave a public thread about a report nobody filed; before,
        # because the issue carries its link and rewriting an issue body afterwards is a second
        # write that can fail on its own.
        handle = await self._open_thread(exchange, report, lang)
        thread_url = handle.url or submission.thread_url
        outcome = await self._filer.file(report, thread_url=thread_url)
        message = _render_outcome(outcome, lang, report)
        # `reused` is an issue that already exists — a re-submission, or a retry after a restart.
        # Gating this on `created` alone left the reporter with a public thread nobody had linked to
        # an issue, and no follow-up on an issue that was perfectly real.
        if outcome.action in ("created", "reused") and outcome.number:
            self._track(outcome.number, handle, lang)
            if handle.opened:
                # Posted after the filing, not at the opening: the message carries the issue's own
                # address, and a thread announcing a link that does not exist yet is worse than one
                # that arrives a second later.
                await exchange.post_in_thread(
                    handle,
                    text(
                        "relay.opened",
                        lang,
                        title=one_line(report.title, TITLE_IN_THREAD_MAX_CHARS),
                        url=outcome.url or f"#{outcome.number}",
                    ),
                )
            message += await self._add_hypothesis(report, draft.body, outcome.number, lang, submission.roles)
        return message

    async def _open_thread(self, exchange: BugExchange, report: BugReport, lang: str) -> ThreadHandle:
        """Open the public thread this report's answers come back into.

        Args:
            exchange: The Discord side.
            report: The report being filed.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            Where it was opened, or an empty handle. A thread that could not be opened is a
            follow-up that will not happen — never a report that does not get filed.
        """
        name = text("relay.thread_name", lang, topic=one_line(report.title, THREAD_NAME_MAX_CHARS))
        handle = await exchange.open_followup_thread(name)
        if not handle.opened:
            self._logger.warning(
                "no follow-up thread was opened for a filed report",
                extra={"event": "intake.no_thread", "user": report.form.reporter_id},
            )
        return handle

    def _track(self, issue: int, handle: ThreadHandle, lang: str) -> None:
        """Record that this issue must answer in this thread.

        Args:
            issue: The issue that was created.
            handle: Where its thread is.
            lang: The language it was answered in.
        """
        if self._tracker is None or not handle.opened:
            return
        self._tracker.remember(issue, channel_id=handle.channel_id, thread_id=handle.thread_id, lang=lang)

    async def _add_hypothesis(
        self,
        report: BugReport,
        context: str,
        number: int,
        lang: str,
        roles: tuple[str, ...],
    ) -> str:
        """Add the machine's guess — or the sentence saying there is none — to the filed issue.

        It runs **after** the issue exists, and it is the only place in this flow that spends a
        model call. So every refusal, every failure and every empty answer costs one paragraph and
        nothing else: the report the reporter spent five minutes on is already on the tracker with
        his link to it.

        The prepared context is the issue body itself. Everything a model would go looking for is
        in it — the location, the surrounding code, the callers, the catalogue matches, the prior
        art, the mission's shape — which is what turns an investigation into one call.

        Args:
            report: The filed report.
            context: The issue body, which is the prepared file the model concludes on.
            number: The issue that was just created.
            lang: ``"fr"`` or ``"en"``.
            roles: Discord role ids the reporter holds.

        Returns:
            One line for the reporter, or an empty string when there is nothing worth saying to him.
        """
        if self._enricher is None or self._filer is None:
            return ""
        enrichment = await self._enricher.enrich(report, context, lang, roles=roles)
        if enrichment.reason == DISABLED:
            # Nothing to say and nothing to publish: a deployment that never enriches would
            # otherwise stamp every issue it files with a paragraph about a feature it does not have.
            return ""
        outcome = await self._filer.add_comment(number, enrichment.body)
        self._logger.info(
            "hypothesis section settled",
            extra={
                "event": "intake.enriched",
                "issue": number,
                "enriched": enrichment.enriched,
                "reason": enrichment.reason,
                "calls": enrichment.calls,
                "posted": outcome.filed,
            },
        )
        key = "hypothesis.added" if enrichment.enriched else f"hypothesis.absent.{enrichment.reason}"
        return "\n" + text(key, lang)

    async def build(self, submission: BugSubmission, workdir: Path) -> BugReport:
        """Do the deterministic pass, attachments included.

        Args:
            submission: The form and its attachments.
            workdir: A directory the **caller** owns and removes. The prepared attachments point
                into it, so it must outlive whatever consumes them — see :meth:`handle`.

        Returns:
            The assembled report.
        """
        # Everything below is blocking, and this coroutine shares its loop with `/ask` and with the
        # gateway's heartbeat. `Checkout.refresh` says so itself — *"call it from a worker thread,
        # never on the event loop"* — and a hung `fetch` holds it for `GIT_TIMEOUT_SECONDS` per
        # command against a heartbeat of ~41 s, which is a disconnect and then a not-ready service.
        # The reduction is not innocent either: measured against the real repository, one ordinary
        # `/bug` with an 8 MB mission attached spends ~6 s in `summarise_mission`, the checkout walk
        # and the caller search. None of it awaits anything, so none of it yields.
        if self._refresh and self._checkout.due():
            await asyncio.to_thread(self._checkout.refresh)
        harvest = await self._collector.collect(submission.attachments, workdir)
        return await asyncio.to_thread(self._assemble, submission.form, harvest)

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
        others: list[str] = []
        scanned: list[str] = []
        # Three buckets, not two. A quoted `mission.yaml` filed under "log excerpts" would come out
        # of ticket 04's renderer under a heading it does not belong to, and nobody would notice
        # until a reader wondered why his configuration file was being called a log.
        for item in harvest.prepared:
            if not item.rendered:
                continue
            rendered = f"**{item.filename}**\n{item.rendered}"
            if item.kind == "log":
                logs.append(rendered)
                # Only a log is re-scanned for a trace: it is the one attachment that routinely
                # carries the traceback the reporter did not think to copy into the form.
                scanned.append(item.rendered)
            elif item.kind == "mission":
                missions.append(rendered)
            else:
                others.append(rendered)
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
            quoted_files=tuple(others),
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


def escalation_form(
    question: str,
    answer: str,
    *,
    reporter: str,
    reporter_id: str,
    language: str,
) -> BugForm:
    """Turn an unsatisfying ``/ask`` exchange into the start of a report.

    What it fills is *what happened*: the question and the answer are the observation, not the
    diagnosis. *What was expected* and *the steps* are deliberately left empty — the form still
    requires them, so escalating remains a report somebody wrote rather than a transcript nobody
    read.

    Args:
        question: What was asked.
        answer: What the bot replied.
        reporter: The asker's display name.
        reporter_id: The asker's Discord id.
        language: The language of the exchange.

    Returns:
        The pre-filled form.
    """
    return BugForm(
        summary=one_line(question, SUMMARY_MAX_CHARS),
        happened=text(
            "escalate.happened",
            normalize_language(language),
            question=one_line(question, ESCALATED_QUESTION_CHARS),
            answer=one_line(answer, ESCALATED_ANSWER_CHARS),
        )[:PARAGRAPH_MAX_CHARS],
        expected="",
        steps="",
        doctor="",
        reporter=reporter,
        reporter_id=reporter_id,
        language=language,
    )


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


def sweep_query(report: BugReport) -> str:
    """Build the text the prior-art sweep matches on.

    The reporter's own words plus what the trace named, and **not** the attached log: a log shares
    hundreds of words with every other log, so including it would match a report against everything
    and turn the sweep into noise a reporter learns to dismiss.

    Args:
        report: The assembled report.

    Returns:
        The query.
    """
    form = report.form
    located = " ".join(f"{item.relative} {item.function}" for item in report.located)
    return "\n".join((form.summary, form.happened, form.expected, located))


def _issue_number(sweep: Sweep) -> int:
    """Read the issue number out of a matched ``#123`` reference.

    Args:
        sweep: The finding.

    Returns:
        The number, or ``0`` when the match is not an issue.
    """
    if sweep.best is None:
        return 0
    reference = sweep.best.candidate.reference
    return int(reference[1:]) if reference.startswith("#") and reference[1:].isdigit() else 0


def render_match(sweep: Sweep, lang: str) -> str:
    """Render a proposed match **with its evidence**, so it can be disagreed with.

    A proposal with no evidence is an assertion, and an assertion is what silences a real bug: the
    reporter has no way to tell a good match from a bad one, concludes the desk already knows, and
    goes away. So the shared words, the score and the reference are all printed.

    Args:
        sweep: The finding.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The message, or an empty string when there is nothing to propose.
    """
    if sweep.best is None:
        return ""
    match = sweep.best
    key = {
        DUPLICATE: "priorart.duplicate",
        FIXED: "priorart.fixed" if match.candidate.detail else "priorart.fixed_no_version",
        IN_PROGRESS: "priorart.in_progress",
    }[sweep.verdict]
    values = {
        "reference": match.candidate.reference,
        "title": one_line(match.candidate.title, 140),
        "evidence": "-# " + match.evidence(),
        "url": match.candidate.url,
    }
    if key == "priorart.fixed":
        values["version"] = match.candidate.detail
    return text(key, lang, **values)


def _render_outcome(outcome: Outcome, lang: str, report: BugReport) -> str:
    """Render what became of the filing attempt.

    A failure is a sentence the reporter reads, never a silence: he has spent five minutes on this
    and must not walk away believing an issue exists.

    Args:
        outcome: What the filer returned.
        lang: ``"fr"`` or ``"en"``.
        report: The assembled report, for the fallback link.

    Returns:
        The message.
    """
    if outcome.action == "failed":
        return text(
            "filed.error",
            lang,
            reason=one_line(outcome.error, 300),
            issue_url=f"{REPOSITORY_URL}/issues/new?template=bug_report.yml",
        )
    key = {"created": "filed.created", "reused": "filed.reused", "commented": "filed.commented"}[outcome.action]
    message = text(key, lang, url=outcome.url or f"#{outcome.number}")
    if outcome.notes:
        message += "\n" + text("filed.notes", lang, notes="; ".join(outcome.notes))
    return message


def render_preview(report: BugReport, lang: str) -> str:
    """Render what the deterministic pass produced, for a deployment that files nothing.

    This is a **summary of the pass**, not the issue body — the body, and the click that publishes
    it, are :class:`~veaf_support_bot.draft.Draft`. It is what a service with no GitHub App shows:
    proof that the pass ran and what it found, so the pipeline stays observable without a tracker
    to write to.

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
    if report.prior_art is not None:
        parts.append(text("priorart.checked", lang, checked=report.prior_art.describe()))
        proposal = render_match(report.prior_art, lang)
        if proposal:
            parts.append(proposal)
    if report.notes:
        listed = "\n".join(f"- {note.subject}: {note.reason}" for note in report.notes)
        parts.append(text("bug.notes", lang) + "\n" + quote(listed))
    return "\n\n".join(parts)[:PREVIEW_MAX_CHARS]
