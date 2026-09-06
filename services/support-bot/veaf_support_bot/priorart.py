"""Has this already been reported, already fixed, or is a lot already on it?

Four places are consulted before anything is filed, and **none of them costs a model call**. The
corpus is tiny — nine open issues, a directory of lots, one roadmap — so the sweep is text matching
over material the service already has on disk or one API page away.

| Source | Answers | Verdict it can produce |
|---|---|---|
| Open issues | is this already reported? | :data:`DUPLICATE` |
| Recently closed issues | was this fixed in a version the user does not have? | :data:`FIXED` |
| ``.backlog/<LOT>/`` | is a lot already working on it? | :data:`IN_PROGRESS` |
| ``ROADMAP.md`` | is it deliberately parked or cancelled? | :data:`IN_PROGRESS` |

``CONTRIBUTING.md`` is explicit that issues are an intake desk and the real work lives in lots, so a
sweep over issues alone would miss most of the answer — which is why the last two rows are here and
why they read the **checkout**, not the API.

## The failure mode this module is shaped around

A wrong *"this is a duplicate"* silences a real bug, and the reporter will not insist — he will
conclude the desk already knows and go away. So nothing here decides anything:

* a match is **proposed**, never applied. :class:`Sweep` is a finding; acting on it is the caller's
  job, and :class:`PriorArtGate` makes the acceptance an explicit, refusable step;
* a match always carries its **evidence** — which source, which reference, and the exact words the
  two texts share, so a reader can see *why* the machine thought so and disagree with it;
* a rejection is not a dead end. The flow continues and the issue is filed, with what was checked
  recorded in it.

## Why the matching is this simple

Every discriminating word in a bug report is a *token nobody uses in ordinary prose*:
``v5_converter``, ``airdromes.yaml``, ``KeyError``, ``FEAT-SUPPORT-BUG-INTAKE``. Weighting those
above ordinary words is the whole algorithm, and it is deliberate that it is legible: the score is
printed with the match, and a maintainer who thinks it is wrong can read the shared words and see
the mistake. A similarity model would score better and explain nothing.

Nothing in a report selects a code path here either: the query is tokenised, and tokens are compared
to tokens. See :mod:`veaf_support_bot.untrusted`.
"""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Protocol

#: No source found anything worth proposing.
NONE = "none"

#: An open issue already describes this.
DUPLICATE = "duplicate"

#: A closed issue describes this, and a released version carries the fix.
FIXED = "fixed"

#: A backlog lot or a roadmap section already covers it.
IN_PROGRESS = "in-progress"

#: Source names, as they appear in the evidence a reader sees.
SOURCE_OPEN_ISSUE = "open issue"
SOURCE_CLOSED_ISSUE = "closed issue"
SOURCE_BACKLOG = "backlog lot"
SOURCE_ROADMAP = "roadmap"

#: Which verdict each source produces when it wins.
_VERDICT_OF_SOURCE = {
    SOURCE_OPEN_ISSUE: DUPLICATE,
    SOURCE_CLOSED_ISSUE: FIXED,
    SOURCE_BACKLOG: IN_PROGRESS,
    SOURCE_ROADMAP: IN_PROGRESS,
}

#: Order used to break a tie between two candidates that scored the same. *Already fixed* first
#: because it is the only outcome that unblocks the reporter on the spot.
_VERDICT_RANK = (FIXED, DUPLICATE, IN_PROGRESS)

#: Lowest score worth proposing at all. Below it the match is not shown: a weak proposal is the
#: silencing failure mode with extra steps.
MATCH_MIN_SCORE = 0.34

#: A proposal must additionally share at least one *signal* token — an identifier, a file name, an
#: exception class — or this many ordinary words. Two reports that share only ``mission`` and
#: ``error`` are not the same report.
MATCH_MIN_ORDINARY = 5

#: Weight of a signal token against an ordinary one.
SIGNAL_WEIGHT = 3

#: How many matches, besides the best one, are shown as alternatives.
MAX_ALTERNATIVES = 2

#: Longest candidate text kept. A PRD runs to pages; the words that identify it are at the top.
CANDIDATE_MAX_CHARS = 6000

#: How many shared words the evidence lists.
EVIDENCE_MAX_TOKENS = 8

#: Statuses of a backlog lot that mean the lot is *not* an answer to a new report.
CLOSED_LOT_STATUSES = ("✅", "🚫")

#: Words carrying no discriminating power in a French or English bug report. Deliberately short: the
#: scoring already down-weights common words by counting signal tokens triple, and a long stop list
#: is a place for a real term to get lost.
_STOPWORDS = frozenset(
    """
    a ai aller alors an and any are as at au aussi autre aux avec avoir be been but by
    ca can ce cela ces cest cet cette comme could dans de des deux do does donc dont du
    each elle en encore est et etait etc ete etre eu faire fait for from get had has have he
    her his how il ils in is it its je la le les leur lui ma mais me mes moi mon my ne
    no nos not notre nous of on ont or ou our out par pas peut peux plus por posso pour
    pourquoi qu quand que quel quelle qui quoi sa sans se ses si soit son sont sous sur
    ta te tes that the their them then there these they this to toi ton tous tout toute
    toutes tres tu un une va vais vas veut veux vous was we were what when which who will
    with would you your
    """.split()
)

#: What a token has to look like to be *ordinary*: a word of letters only, short enough to be
#: everyday vocabulary. Everything else — anything with a digit, an underscore, a dot, or simply
#: long — is a signal token.
_ORDINARY = re.compile(r"^[a-z]{1,7}$")

#: How text is cut into tokens. Dots and underscores are kept inside a token so ``mission.yaml`` and
#: ``v5_converter`` survive as one discriminating word instead of three common ones.
_TOKEN = re.compile(r"[a-z0-9]+(?:[._-][a-z0-9]+)*")

#: A ``## [6.19.0] — 2026-09-02`` heading in ``CHANGELOG.md``.
_CHANGELOG_HEADING = re.compile(r"^##\s*\[([^\]]+)\]")

#: The ``Status: ⬜ ready`` line of a lot's PRD.
_STATUS_LINE = re.compile(r"^Status:\s*(.+)$", re.MULTILINE)


def fold(text: str) -> str:
    """Lowercase text and strip its accents.

    Args:
        text: Any text.

    Returns:
        The folded text, so ``Problème`` and ``probleme`` are the same word.
    """
    decomposed = unicodedata.normalize("NFKD", text.lower())
    return "".join(character for character in decomposed if not unicodedata.combining(character))


def tokenize(text: str) -> tuple[frozenset[str], frozenset[str]]:
    """Cut text into the two kinds of word the score distinguishes.

    Args:
        text: Any text.

    Returns:
        A pair ``(signal, ordinary)``. Signal tokens are identifiers, file names, versions and long
        words; ordinary tokens are everyday vocabulary minus the stop list.
    """
    signal: set[str] = set()
    ordinary: set[str] = set()
    for match in _TOKEN.finditer(fold(text)):
        token = match.group()
        if _ORDINARY.match(token):
            if token not in _STOPWORDS:
                ordinary.add(token)
        elif token not in _STOPWORDS:
            signal.add(token)
    return frozenset(signal), frozenset(ordinary)


@dataclass(frozen=True)
class IssueRecord:
    """One issue as the tracker described it.

    Attributes:
        number: The issue number.
        title: Its title.
        body: Its body, which may be empty.
        url: Its address on GitHub.
        state: ``"open"`` or ``"closed"``.
        closed_at: ISO timestamp, empty while the issue is open.
        labels: Its labels.
    """

    number: int
    title: str
    body: str = ""
    url: str = ""
    state: str = "open"
    closed_at: str = ""
    labels: tuple[str, ...] = ()


class IssueSource(Protocol):
    """Where the two issue halves of the corpus come from.

    A protocol rather than the GitHub client, so the sweep is tested against a handful of records
    instead of against a network.
    """

    async def open_issues(self) -> Sequence[IssueRecord]:
        """Return every open issue.

        Returns:
            The open issues.
        """

    async def recently_closed_issues(self) -> Sequence[IssueRecord]:
        """Return the issues closed recently enough to still be an answer.

        Returns:
            The closed issues, newest first.
        """


@dataclass(frozen=True)
class Candidate:
    """One piece of prior work the report is compared against.

    Attributes:
        source: One of the ``SOURCE_*`` constants.
        reference: How a human names it — ``"#712"``, ``"FEAT-SUPPORT-BUG-INTAKE"``.
        title: Its one-line title.
        text: The text that is matched against, already bounded.
        url: Where to read it, when there is an address.
        detail: One extra fact the outcome needs — the version that carries the fix, the lot's
            status, the roadmap section's state. Empty when there is none.
    """

    source: str
    reference: str
    title: str
    text: str = ""
    url: str = ""
    detail: str = ""


@dataclass(frozen=True)
class Match:
    """A candidate the sweep thinks is the same subject, and why it thinks so.

    Attributes:
        candidate: What was matched.
        score: Between 0 and 1. Printed, so a reader can weigh the proposal.
        shared: The words the two texts have in common, signal words first — this is the evidence.
    """

    candidate: Candidate
    score: float
    shared: tuple[str, ...] = ()

    @property
    def verdict(self) -> str:
        """Return the verdict this match produces.

        Returns:
            One of :data:`DUPLICATE`, :data:`FIXED`, :data:`IN_PROGRESS`.
        """
        return _VERDICT_OF_SOURCE[self.candidate.source]

    def evidence(self) -> str:
        """Render the one line that justifies the proposal.

        Returns:
            A sentence naming the source, the reference and the shared words.
        """
        words = ", ".join(self.shared) if self.shared else "no distinctive word"
        return f"{self.candidate.source} {self.candidate.reference} — {self.score:.0%} match on: {words}"


@dataclass(frozen=True)
class Sweep:
    """What the four sources answered, and what the caller may propose.

    Nothing here has been acted on. :attr:`verdict` is a *finding*.

    Attributes:
        verdict: :data:`NONE`, :data:`DUPLICATE`, :data:`FIXED` or :data:`IN_PROGRESS`.
        best: The strongest match, or ``None`` when nothing scored high enough.
        alternatives: Weaker matches, so a reader can see the second-best rather than trust the
            first.
        checked: What was consulted, source by source, with how many items each held. Recorded in
            the draft so a reader knows the sweep happened even when it found nothing.
        problems: Sources that could not be consulted, each with its reason. A sweep that could not
            read the issues is not a sweep that found nothing, and the difference has to be visible.
    """

    verdict: str = NONE
    best: Match | None = None
    alternatives: tuple[Match, ...] = ()
    checked: tuple[str, ...] = ()
    problems: tuple[str, ...] = ()

    @property
    def found(self) -> bool:
        """Say whether there is a match to propose.

        Returns:
            ``True`` when a candidate scored above the threshold.
        """
        return self.best is not None

    def describe(self) -> str:
        """Render what was checked, for the issue body and the draft.

        Returns:
            A one-line summary of the sweep, never empty.
        """
        checked = "; ".join(self.checked) if self.checked else "nothing could be consulted"
        line = f"Prior art checked: {checked}."
        if self.problems:
            line += " Not consulted: " + "; ".join(self.problems) + "."
        return line


def score_against(
    query_signal: frozenset[str],
    query_ordinary: frozenset[str],
    candidate: Candidate,
) -> Match | None:
    """Score one candidate against the tokenised report.

    Args:
        query_signal: The report's signal tokens.
        query_ordinary: The report's ordinary tokens.
        candidate: The candidate to score.

    Returns:
        The match, or ``None`` when it is below the threshold or shares nothing distinctive.
    """
    signal, ordinary = tokenize(f"{candidate.title}\n{candidate.text}")
    shared_signal = sorted(query_signal & signal)
    shared_ordinary = sorted(query_ordinary & ordinary)
    if not shared_signal and len(shared_ordinary) < MATCH_MIN_ORDINARY:
        return None

    total = SIGNAL_WEIGHT * len(query_signal) + len(query_ordinary)
    if total == 0:
        return None
    hit = SIGNAL_WEIGHT * len(shared_signal) + len(shared_ordinary)
    score = hit / total
    if score < MATCH_MIN_SCORE:
        return None
    return Match(
        candidate=candidate,
        score=round(score, 4),
        shared=tuple((shared_signal + shared_ordinary)[:EVIDENCE_MAX_TOKENS]),
    )


def rank(matches: Iterable[Match]) -> list[Match]:
    """Order matches best first, with a stable tie-break.

    Args:
        matches: The matches to order.

    Returns:
        The matches, strongest first. Equal scores are broken by :data:`_VERDICT_RANK` and then by
        reference, so the same corpus always produces the same proposal.
    """
    return sorted(
        matches,
        key=lambda match: (-match.score, _VERDICT_RANK.index(match.verdict), match.candidate.reference),
    )


# ---------------------------------------------------------------------------
# The two halves of the corpus that live in the checkout
# ---------------------------------------------------------------------------


def read_backlog(root: Path) -> tuple[list[Candidate], str, list[str]]:
    """Read the open lots out of ``.backlog/``.

    Only lots that are still open are candidates: a closed lot answers nothing, and proposing one
    would tell a reporter his bug is being worked on when it was shipped or dropped months ago.

    Args:
        root: The checkout root.

    Returns:
        A triple of the candidates, a problem describing why the **directory** could not be read
        (empty on success), and one problem per lot whose ``PRD.md`` could not be read. The two are
        separate because they mean different things to the reader of the issue: the first says the
        backlog was not swept at all, the second says it was swept minus these lots — and a lot
        turned into an all-but-empty :class:`Candidate`, which is what this used to do, is worse than
        either. It cannot match anything, so it silently reads as *"swept, nothing found"*.
    """
    backlog = root / ".backlog"
    if not backlog.is_dir():
        return [], f"{backlog} is not a directory", []
    candidates: list[Candidate] = []
    unreadable: list[str] = []
    for prd in sorted(backlog.glob("*/PRD.md")):
        try:
            content = prd.read_text(encoding="utf-8", errors="replace")
        except OSError as error:
            unreadable.append(f"`.backlog/{prd.parent.name}/PRD.md` could not be read ({type(error).__name__})")
            continue
        status = _status_of(content)
        if any(glyph in status for glyph in CLOSED_LOT_STATUSES):
            continue
        candidates.append(
            Candidate(
                source=SOURCE_BACKLOG,
                reference=prd.parent.name,
                title=_first_heading(content) or prd.parent.name,
                text=content[:CANDIDATE_MAX_CHARS],
                url=f".backlog/{prd.parent.name}/PRD.md",
                detail=status,
            )
        )
    return candidates, "", unreadable


def read_roadmap(root: Path) -> tuple[list[Candidate], str]:
    """Read ``ROADMAP.md`` as one candidate per section.

    Args:
        root: The checkout root.

    Returns:
        A pair of the candidates and a problem description, empty on success.
    """
    path = root / "ROADMAP.md"
    if not path.is_file():
        return [], f"{path} is missing"
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError as error:
        return [], f"ROADMAP.md could not be read ({type(error).__name__})"
    candidates: list[Candidate] = []
    for block in content.split("\n## ")[1:]:
        heading, _, body = block.partition("\n")
        heading = heading.strip()
        if not heading:
            continue
        candidates.append(
            Candidate(
                source=SOURCE_ROADMAP,
                reference=heading,
                title=heading,
                text=body[:CANDIDATE_MAX_CHARS],
                url="ROADMAP.md",
            )
        )
    return candidates, ""


def fix_version(root: Path, number: int) -> str:
    """Find the released version whose changelog entry cites an issue.

    The changelog cites issues as ``[#123](…/issues/123)``, so the version that carries a fix is a
    lookup, not a guess: the nearest ``## [x.y.z]`` heading above the citation.

    Args:
        root: The checkout root.
        number: The issue number.

    Returns:
        The version, or an empty string when the changelog does not mention the issue — including
        when it cannot be read at all, since a version stated on a guess is worse than none.
    """
    path = root / "CHANGELOG.md"
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    citation = re.compile(rf"#{number}\b")
    heading = ""
    for line in content.splitlines():
        found = _CHANGELOG_HEADING.match(line)
        if found:
            heading = found.group(1).strip()
            continue
        if citation.search(line) and heading and heading.lower() != "unreleased":
            return heading
    return ""


def _status_of(content: str) -> str:
    """Return the ``Status:`` line of a PRD.

    Args:
        content: The PRD's text.

    Returns:
        The status, or an empty string.
    """
    found = _STATUS_LINE.search(content)
    return found.group(1).strip() if found else ""


def _first_heading(content: str) -> str:
    """Return the first ``# `` heading of a document.

    Args:
        content: The document's text.

    Returns:
        The heading text, or an empty string.
    """
    for line in content.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return ""


# ---------------------------------------------------------------------------
# The sweep itself
# ---------------------------------------------------------------------------


@dataclass
class PriorArtSweeper:
    """Runs the four-source sweep for one report.

    Attributes:
        root: The checkout root the two file sources are read from.
        issues: Where the issue halves come from; ``None`` sweeps the checkout only, which is what a
            deployment with no GitHub credentials does.
    """

    root: Path
    issues: IssueSource | None = None
    _problems: list[str] = field(default_factory=list, init=False, repr=False)

    async def sweep(self, query: str) -> Sweep:
        """Compare a report against everything already recorded.

        Args:
            query: The report's own words — its summary, what happened, what was expected, and the
                locations the trace named. Deliberately not the attached log: a log shares hundreds
                of words with every other log and would match everything.

        Returns:
            The finding. Never raises: a source that cannot be read becomes a line in
            :attr:`Sweep.problems`, because *"the sweep could not run"* and *"the sweep found
            nothing"* must not look the same to a reader.
        """
        self._problems = []
        signal, ordinary = tokenize(query)
        checked: list[str] = []
        candidates: list[Candidate] = []

        open_records, closed_records, tracker_read = await self._issue_records()
        candidates += [_from_issue(record, SOURCE_OPEN_ISSUE) for record in open_records]
        candidates += [_from_issue(record, SOURCE_CLOSED_ISSUE, self.root) for record in closed_records]
        if tracker_read:
            checked.append(f"{len(open_records)} open issue(s)")
            checked.append(f"{len(closed_records)} recently closed issue(s)")

        lots, problem, unreadable = read_backlog(self.root)
        self._note(problem, "`.backlog/`")
        # Per file, not per source: the sweep really did read the other lots, so the count below is
        # still true and still worth showing. What must not happen is the missing ones going unsaid.
        self._problems.extend(unreadable)
        if not problem:
            checked.append(f"{len(lots)} open backlog lot(s)")
        candidates += lots

        sections, problem = read_roadmap(self.root)
        self._note(problem, "`ROADMAP.md`")
        if not problem:
            checked.append(f"{len(sections)} roadmap section(s)")
        candidates += sections

        scored = rank(
            match for match in (score_against(signal, ordinary, candidate) for candidate in candidates) if match
        )
        best = scored[0] if scored else None
        return Sweep(
            verdict=best.verdict if best else NONE,
            best=best,
            alternatives=tuple(scored[1 : 1 + MAX_ALTERNATIVES]),
            checked=tuple(checked),
            problems=tuple(self._problems),
        )

    async def _issue_records(self) -> tuple[Sequence[IssueRecord], Sequence[IssueRecord], bool]:
        """Fetch both issue halves, turning a failure into a recorded problem.

        Returns:
            The open issues, the recently closed ones, and whether the tracker answered at all. The
            third value is what keeps *"nine issues, none of them yours"* distinguishable from
            *"the tracker was down"*.
        """
        if self.issues is None:
            self._problems.append("the issue tracker (no GitHub credentials are configured)")
            return (), (), False
        try:
            return await self.issues.open_issues(), await self.issues.recently_closed_issues(), True
        except Exception as error:  # noqa: BLE001 - any tracker failure is one line, never a lost report
            self._problems.append(f"the issue tracker ({type(error).__name__})")
            return (), (), False

    def _note(self, problem: str, subject: str) -> None:
        """Record a source that could not be consulted.

        Args:
            problem: The failure, or an empty string when there was none.
            subject: What could not be read.
        """
        if problem:
            self._problems.append(f"{subject} ({problem})")


def _from_issue(record: IssueRecord, source: str, root: Path | None = None) -> Candidate:
    """Turn an issue into a candidate.

    Args:
        record: The issue.
        source: :data:`SOURCE_OPEN_ISSUE` or :data:`SOURCE_CLOSED_ISSUE`.
        root: Checkout root, for looking up the version that carries the fix.

    Returns:
        The candidate.
    """
    detail = ""
    if source == SOURCE_CLOSED_ISSUE and root is not None:
        detail = fix_version(root, record.number)
    return Candidate(
        source=source,
        reference=f"#{record.number}",
        title=record.title,
        text=record.body[:CANDIDATE_MAX_CHARS],
        url=record.url,
        detail=detail,
    )


# ---------------------------------------------------------------------------
# Proposing the match, and being refused
# ---------------------------------------------------------------------------


class MatchConfirmation(Protocol):
    """Asks the reporter whether a proposed match really is his bug."""

    async def confirm(self, sweep: Sweep, lang: str) -> bool:
        """Show the match with its evidence and return the reporter's answer.

        Args:
            sweep: The finding, with the evidence to display.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            ``True`` when the reporter agrees it is the same subject — nothing is opened. ``False``
            when he says his is different, and the report goes on being filed.
        """


@dataclass(frozen=True)
class PriorArtGate:
    """The sweep, plus the step that lets the reporter refuse its conclusion.

    Attributes:
        sweeper: What runs the sweep.
        confirmation: Who is asked. ``None`` means **nobody can be asked**, and the gate then always
            returns "rejected": with no way to obtain consent, silencing a report on a machine's
            unverified guess is the one outcome this ticket exists to prevent. The finding is still
            attached to the report and printed with its evidence.
    """

    sweeper: PriorArtSweeper
    confirmation: MatchConfirmation | None = None

    async def run(self, query: str, lang: str) -> tuple[Sweep, bool]:
        """Sweep, and find out whether the match is accepted.

        Args:
            query: The report's own words.
            lang: ``"fr"`` or ``"en"``.

        Returns:
            A pair of the finding and whether it was **accepted** — ``True`` stops the flow, and the
            caller acts on :attr:`Sweep.verdict` instead of filing.
        """
        sweep = await self.sweeper.sweep(query)
        if not sweep.found or self.confirmation is None:
            return sweep, False
        return sweep, bool(await self.confirmation.confirm(sweep, lang))
