"""What the form becomes, computed without a single model call.

The lot's floor is that **the issue is worth reading with no model in it**. This module is that
floor: it takes the five fields of the modal, the attachments the thread carried, and a fresh
checkout, and produces a filled report — version, component, location, catalogue matches, mission
shape — every part of which is a parse, a lookup or a search.

## The decisions, and why none of them is a judgement call

| Decision | How it is made |
|---|---|
| version | ``tool.version`` claimed by the ``doctor`` block, or *not stated* |
| component | the location's path, matched against :data:`COMPONENT_RULES` — a table in this file |
| location | the trace names it (:mod:`veaf_support_bot.traces`) |
| what is known about the log | ``rules.json``, rendered in the catalogue's own wording |
| labels | ``bug``, plus the component's label from the same table |

Nothing in that column reads free text to choose a branch. That is what makes the hostile-fixture
test meaningful rather than decorative: there is no branch for a hostile line to take.

## Missing is stated, never filled in

A version nobody pasted is *"not stated — no ``doctor`` block in the report"*, a trace whose file no
longer exists says so with the revision it was checked against, and an attachment that could not be
read is listed with the reason. The measurement that opened this programme is that reports fail on
mechanical facts; an invented one is worse than an absent one, because a maintainer cannot tell it
from a real one.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import PurePosixPath

from veaf_support_bot.checkout import Checkout, Freshness
from veaf_support_bot.toolkit import DoctorFacts, ToolkitUnavailable, parse_doctor_block, redact
from veaf_support_bot.traces import Location, TraceReading, Unresolved, read_trace
from veaf_support_bot.untrusted import one_line

#: Longest issue title. GitHub allows 256; a title that long is not read.
TITLE_MAX_CHARS = 110

#: What the report says instead of a value nobody supplied.
NOT_STATED = "not stated"

#: Label every issue this service files carries, matching the repository's own bug template.
BASE_LABEL = "bug"

#: Component of last resort, when nothing located the fault. The issue template's own catch-all.
UNKNOWN_COMPONENT = "Other"

#: Path prefix to component name and extra label, longest prefix first.
#:
#: This table is the whole of the component decision. The names on the right are the options of
#: ``.github/ISSUE_TEMPLATE/bug_report.yml``, so the filed issue reads like a hand-filled one, and
#: ``tests/test_bugreport.py`` asserts they still exist in that file — a renamed dropdown option
#: would otherwise leave the bot writing a component nobody can filter on.
COMPONENT_RULES: tuple[tuple[str, str, str], ...] = (
    ("src/scripts/veaf/", "Lua runtime scripts (in-mission)", "lua"),
    ("test/lua/", "Lua runtime scripts (in-mission)", "lua"),
    ("veaf_build/", "veaf-build (build pipeline)", "build"),
    ("doc/", "Documentation", "documentation"),
    ("services/support-bot/", "Other", "support-bot"),
    ("src/python/veaf-tools/veaf-tools-updater.py", "veaf-tools-updater.exe", "updater"),
    ("src/python/veaf-tools/", "veaf-tools.exe (Python CLI)", "python"),
    ("test/python/", "veaf-tools.exe (Python CLI)", "python"),
)


@dataclass(frozen=True)
class BugForm:
    """The five fields of the modal, exactly as the reporter typed them.

    Nothing here has been cleaned, redacted or interpreted. Keeping the raw form separate from the
    assembled report is what lets a test feed a hostile version of it and compare the decisions.

    Attributes:
        summary: One line, required — becomes the issue title.
        happened: What happened, required.
        expected: What was expected, required.
        steps: Steps to reproduce, required.
        doctor: The ``doctor`` block, pasted or not.
        reporter: How to credit the reporter in the issue, already a display name.
        reporter_id: The reporter's Discord id, for the relay ticket 06 builds.
        language: ``"fr"`` or ``"en"`` — the issue is written in the reporter's language.
    """

    summary: str
    happened: str
    expected: str
    steps: str
    doctor: str = ""
    reporter: str = ""
    reporter_id: str = ""
    language: str = "fr"

    def all_text(self) -> str:
        """Return every free-text field joined, for scanning.

        Returns:
            The fields in the order the form asks them, newline-separated.
        """
        return "\n".join((self.summary, self.happened, self.expected, self.steps, self.doctor))

    def missing_fields(self) -> tuple[str, ...]:
        """Name the required fields the reporter left empty.

        Discord enforces its own ``required`` flag, but a modal submitted through the API — or a
        field holding only spaces — reaches here empty all the same, and the issue must say so
        rather than show a blank heading.

        Returns:
            The field names, in form order.
        """
        named = (
            ("summary", self.summary),
            ("happened", self.happened),
            ("expected", self.expected),
            ("steps", self.steps),
        )
        return tuple(name for name, value in named if not value.strip())


@dataclass(frozen=True)
class MaterialNote:
    """One thing the report could not do, said out loud.

    Attributes:
        subject: What it is about, e.g. a file name or ``"log excerpt"``.
        reason: Why it is not there.
    """

    subject: str
    reason: str


@dataclass(frozen=True)
class BugReport:
    """A filled report, ready for the issue body ticket 04 renders and ticket 05 files.

    Attributes:
        form: The raw form, kept whole.
        facts: What the ``doctor`` block claimed.
        trace: What the deterministic pass found in the code.
        freshness: The revision every location was resolved against.
        version: The claimed tool version, or :data:`NOT_STATED`.
        component: One of the issue template's component options.
        labels: The labels the issue is opened with.
        title: The issue title.
        notes: Everything that is missing, and why.
        attachments: Prepared files, redacted, ready to be uploaded to the issue.
        mission_summaries: Rendered mission shapes, one per ``.miz`` that could be read.
        log_digests: Rendered log excerpts with their catalogue matches.
        quoted_files: Everything else that was small enough to quote — a `mission.yaml`, a
            configuration file, an archive listing — kept apart from the two above so a renderer
            cannot file a configuration file under a *log excerpts* heading.
    """

    form: BugForm
    facts: DoctorFacts
    trace: TraceReading
    freshness: Freshness
    version: str
    component: str
    labels: tuple[str, ...]
    title: str
    notes: tuple[MaterialNote, ...] = ()
    attachments: tuple[object, ...] = ()
    mission_summaries: tuple[str, ...] = ()
    log_digests: tuple[str, ...] = ()
    quoted_files: tuple[str, ...] = ()

    @property
    def located(self) -> tuple[Location, ...]:
        """Locations the checkout could resolve.

        Returns:
            The resolved locations, innermost first.
        """
        return self.trace.locations

    @property
    def unresolved(self) -> tuple[Unresolved, ...]:
        """Locations the checkout could not resolve.

        Returns:
            The unresolved locations.
        """
        return self.trace.unresolved


def component_for(relative: str) -> tuple[str, str]:
    """Map a repository-relative path to a component and its label.

    Args:
        relative: A path relative to the repository root, forward slashes.

    Returns:
        A ``(component, label)`` pair; the label is an empty string for the catch-all.
    """
    for prefix, component, label in COMPONENT_RULES:
        if relative.startswith(prefix):
            return component, label
    return UNKNOWN_COMPONENT, ""


def build_title(form: BugForm, version: str) -> str:
    """Compose the issue title from the summary line and the claimed version.

    Args:
        form: The submitted form.
        version: The claimed version, or :data:`NOT_STATED`.

    Returns:
        A single bounded line. The version is prefixed only when there is one: ``[not stated]`` in a
        title is noise, and the body already says it.
    """
    prefix = f"[{version}] " if version != NOT_STATED else ""
    summary = one_line(form.summary, TITLE_MAX_CHARS - len(prefix)) or "bug report with no summary"
    return f"{prefix}{summary}"


def assemble(
    form: BugForm,
    checkout: Checkout,
    *,
    notes: tuple[MaterialNote, ...] = (),
    extra_text: str = "",
    mission_summaries: tuple[str, ...] = (),
    log_digests: tuple[str, ...] = (),
    quoted_files: tuple[str, ...] = (),
    attachments: tuple[object, ...] = (),
) -> BugReport:
    """Turn a submitted form into a filled report, using no model.

    Args:
        form: What the reporter typed.
        checkout: The working copy locations are resolved against.
        notes: Everything the attachment pass could not do.
        extra_text: More text to scan for a trace — a log excerpt, typically, so a trace that only
            appears in the attached log is located too.
        mission_summaries: Rendered mission shapes.
        log_digests: Rendered log excerpts.
        quoted_files: Everything else small enough to quote.
        attachments: Prepared files to upload with the issue.

    Returns:
        The report.
    """
    facts = parse_doctor_block(checkout.root, form.doctor)
    scanned = "\n".join(part for part in (form.all_text(), "\n".join(facts.recent_errors), extra_text) if part)
    trace = read_trace(checkout, scanned)

    version = facts.claim("tool.version") or NOT_STATED
    component, label = component_for(trace.locations[0].relative) if trace.locations else (UNKNOWN_COMPONENT, "")
    labels = (BASE_LABEL, label) if label else (BASE_LABEL,)

    collected = list(notes)
    if not facts.present:
        collected.append(MaterialNote("doctor block", facts.problem))
    for name in form.missing_fields():
        collected.append(MaterialNote(f"form field “{name}”", "left empty by the reporter"))
    for missing in trace.unresolved:
        basename = PurePosixPath(missing.raw.replace("\\", "/")).name
        collected.append(
            MaterialNote(
                f"{basename}:{missing.line}",
                f"named by the trace, absent from the checkout at {checkout.freshness().revision}",
            )
        )

    return BugReport(
        form=form,
        facts=facts,
        trace=trace,
        freshness=checkout.freshness(),
        version=version,
        component=component,
        labels=labels,
        title=build_title(form, version),
        notes=tuple(collected),
        attachments=attachments,
        mission_summaries=mission_summaries,
        log_digests=log_digests,
        quoted_files=quoted_files,
    )


def safe_redact(checkout: Checkout, text: str) -> tuple[str, MaterialNote | None]:
    """Redact text, and say plainly when redaction is not available.

    Redaction must never fail open: publishing a home directory because a module could not be
    imported is exactly the accident the shared helper exists to prevent. So a failure returns a
    placeholder, not the original.

    Args:
        checkout: The working copy the helper is imported from.
        text: The text about to be published.

    Returns:
        A pair of the publishable text and, when redaction failed, the note explaining what was
        dropped.
    """
    if not text:
        return "", None
    try:
        return redact(checkout.root, text), None
    except ToolkitUnavailable as error:
        return (
            "(withheld: this text could not be redacted, so it was not published)",
            MaterialNote("redaction", str(error)),
        )
