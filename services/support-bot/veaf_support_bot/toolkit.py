"""The one place the service reaches into ``veaf-tools``, and the rules that make it safe.

## The boundary, and why it is drawn here

The service is a separate Poetry project, deployed on its own cadence, with a container image that
carries nothing but ``veaf_support_bot`` and ``discord.py``. The tools live in
``src/python/veaf-tools/`` and drag a large dependency tree behind them. Those two facts made the
``/ask`` command generate a **checked-in snapshot** of the documentation index rather than import
anything: a copy plus a drift test, and no dependency at all.

That answer does not transfer to this lot, and the reason is not size — it is that
``FEAT-SUPPORT-BUG-INTAKE`` **already requires a live checkout**. Ticket 01 asks for the lines
around a stack trace's location and the callers of the function it sits in; ticket 03 sweeps
``.backlog/`` and ``ROADMAP.md``. So at run time the repository is on disk at a known path, kept
current by :mod:`veaf_support_bot.checkout`. Vendoring a copy of ``veaf_libs`` beside it would
create a **second source of truth about a tree the service is already reading live** — and the first
time the two disagreed, the service would quote line 412 out of one and parse the block with the
other.

So: the checkout is the dependency, and this module is the only door through it.

    ``<checkout>/src/python/veaf-tools`` is appended to ``sys.path`` — appended, not prepended, so
    an environment that really has ``veaf-tools`` installed keeps its own copy and this changes
    nothing.

## What this module guarantees to its callers

* **Nothing imports the tools directly.** Every use goes through a function here. That is what makes
  the boundary auditable: one ``grep`` for ``toolkit`` finds every crossing.
* **A missing or broken import is never fatal.** The tools' tree can be absent (a dry run, a test
  environment, a checkout that failed to refresh), and one of these capabilities can need a
  third-party package the service does not install. Each entry point raises
  :class:`ToolkitUnavailable`, which the intake reports as a missing section — the same treatment
  ticket 02 gives an unreadable attachment. The issue is still filed.
* **Everything that comes back is data.** ``parse_block`` reads text a stranger typed; the log
  excerpt is a stranger's log. Nothing here interprets any of it, and no value returned from these
  functions ever selects a code path by its content.

## The type-checking consequence, stated rather than hidden

``mypy`` runs in the service's own environment, where ``veaf_libs`` and ``veaf_logs`` do not exist.
``pyproject.toml`` therefore declares ``ignore_missing_imports`` for exactly those module trees, and
for nothing else. It is not a loosening of the service's strictness: it is the statement that these
names are resolved at run time from the checkout, which is the boundary this module is about.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path
from types import ModuleType
from typing import Any

from veaf_support_bot.logging_setup import get_logger

#: Where the tools' importable packages sit inside the repository.
TOOLS_PACKAGE_ROOT = Path("src") / "python" / "veaf-tools"

#: Characters of one log excerpt. Well below what a GitHub issue body holds, and matched to what a
#: reader will actually read: the excerpt is a pointer into the attached full log, not a copy of it.
DEFAULT_EXCERPT_CHARS = 12000


class ToolkitUnavailable(RuntimeError):
    """A capability that lives in ``veaf-tools`` cannot be reached from here.

    Always caught by the intake and turned into a missing section with a stated reason. It is never
    a reason to abandon a report: an issue without a log excerpt is still an issue somebody can act
    on, and an issue that was never filed is not.
    """


def install(root: Path) -> None:
    """Make the tools' packages importable from *root*, once.

    Args:
        root: The repository checkout root.
    """
    target = str((root / TOOLS_PACKAGE_ROOT).resolve())
    if target not in sys.path:
        sys.path.append(target)


def _unavailable(what: str, error: Exception, path: Path) -> str:
    """Say that something could not be read, naming the failure's **type** and never its message.

    A parser quotes the bytes it choked on. ``luadata`` copies the malformed region of a mission
    into its ``ValueError``, and that region is a stranger's mission — move the offset a few bytes
    and it is briefing prose instead of punctuation. The same holds of a log parser over a stranger's
    log. Since this text travels ``ToolkitUnavailable`` → ``Rejected.reason`` → ``MaterialNote`` →
    the published issue, the message is dropped from what is published and kept where a maintainer
    can still read it: the service's own log.

    Args:
        what: The sentence the reader gets, e.g. ``"the mission could not be read"``.
        error: The failure. Its type is published; its message is not.
        path: The file it was reading, for the server-side record.

    Returns:
        The publishable reason.
    """
    get_logger("toolkit").warning(
        what,
        extra={
            "event": "toolkit.unreadable",
            "error": type(error).__name__,
            # The detail is the point of logging this at all, and it is why it is not published.
            "detail": str(error),
            "file": path.name,
        },
    )
    return f"{what}: {type(error).__name__}"


def _module(root: Path, name: str) -> ModuleType:
    """Import one module out of the checkout, and check that it really came from there.

    The provenance check is not paranoia. ``sys.path`` is process-global, so once any root has been
    installed, an import succeeds whatever root is asked for — and a stray ``veaf_libs`` installed
    in the environment would be used while this function claimed to be reading the checkout. Since
    the whole point of the seam is *"the checkout is the dependency"*, a module that did not come
    from it is not the module the caller asked for.

    Args:
        root: The repository checkout root.
        name: Dotted module name, e.g. ``"veaf_libs.redaction"``.

    Returns:
        The imported module.

    Raises:
        ToolkitUnavailable: The module, or something it imports, is not there — or the module that
            answered lives somewhere other than *root*.
    """
    install(root)
    try:
        module = __import__(name, fromlist=["_"])
    except Exception as error:  # noqa: BLE001 - any import failure is the same answer to the caller
        raise ToolkitUnavailable(f"{name} could not be imported from the checkout: {type(error).__name__}") from error
    origin = getattr(module, "__file__", None)
    if origin is None or not Path(origin).resolve().is_relative_to((root / TOOLS_PACKAGE_ROOT).resolve()):
        raise ToolkitUnavailable(f"{name} was resolved from {origin}, which is not inside {root}")
    return module


# ---------------------------------------------------------------------------
# Redaction
# ---------------------------------------------------------------------------


def redact(root: Path, text: str) -> str:
    """Strip personal data out of *text*, using the tools' single implementation.

    Args:
        root: The repository checkout root.
        text: Anything about to be published.

    Returns:
        The redacted text.

    Raises:
        ToolkitUnavailable: ``veaf_libs.redaction`` is not reachable. The caller must **not** fall
            back to publishing the raw text: redaction failing open is how a home directory reaches
            a public issue.
    """
    return str(_module(root, "veaf_libs.redaction").redact(text))


# ---------------------------------------------------------------------------
# The doctor block
# ---------------------------------------------------------------------------

#: What a parsed block is missing when the reporter pasted nothing.
NO_BLOCK = "no doctor block was pasted"


@dataclass(frozen=True)
class DoctorFacts:
    """What the ``doctor`` block claims, kept apart from what the service measured.

    Every value here was typed or pasted by the reporter. The producer guarantees the block's
    *shape*; nobody guarantees its truth, and the naming says so — these are ``claims``, not
    readings.

    Attributes:
        present: Whether a complete block was found.
        problem: Why there are no facts, when :attr:`present` is false.
        schema: The block's declared format, verbatim.
        claims: Field name to value, exactly as the block stated them.
        recent_errors: The log records the block carried, oldest first.
    """

    present: bool = False
    problem: str = NO_BLOCK
    schema: str = ""
    claims: dict[str, str] = field(default_factory=dict)
    recent_errors: list[str] = field(default_factory=list)

    def claim(self, name: str) -> str:
        """Return one claimed field.

        Args:
            name: Field name, e.g. ``"tool.version"``.

        Returns:
            The value, or an empty string when the block did not carry the field.
        """
        return self.claims.get(name, "")


def parse_doctor_block(root: Path, text: str) -> DoctorFacts:
    """Read the ``doctor`` block out of free-form text.

    Missing is reported as missing and never guessed: an issue that states *"no doctor block was
    pasted"* costs a maintainer one question; an issue carrying an invented version costs him an
    afternoon.

    Args:
        root: The repository checkout root.
        text: The text the reporter typed, which may contain a block anywhere inside it.

    Returns:
        The facts, with :attr:`DoctorFacts.present` false and a stated reason when there is no
        usable block. This function does not raise: a missing parser is one more reason there are
        no facts, not a reason to lose the report.
    """
    if not text or not text.strip():
        return DoctorFacts()
    try:
        diagnostics = _module(root, "veaf_libs.diagnostics")
    except ToolkitUnavailable as error:
        return DoctorFacts(problem=str(error))
    try:
        report = diagnostics.parse_block(text)
    except ValueError as error:
        return DoctorFacts(problem=f"the pasted block could not be read: {error}")
    claims = {str(key): str(value) for key, value in dict(report.fields).items()}
    return DoctorFacts(
        present=True,
        problem="",
        schema=claims.get("schema", ""),
        claims=claims,
        recent_errors=[str(record) for record in report.recent_errors],
    )


def expected_schema(root: Path) -> str:
    """Return the block schema this repository currently writes.

    Args:
        root: The repository checkout root.

    Returns:
        The schema string, or an empty string when it cannot be read. Used to tell a reader that a
        pasted block came from a format the tools no longer write — a fact, unlike guessing which
        fields moved.
    """
    try:
        return str(_module(root, "veaf_libs.diagnostics").SCHEMA)
    except (ToolkitUnavailable, AttributeError):
        return ""


# ---------------------------------------------------------------------------
# The log excerpt
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class LogDigest:
    """A bounded, redacted reading of one attached log.

    Attributes:
        excerpt: The rendered excerpt, already redacted by the excerpt builder itself.
        catalogue: What ``rules.json`` recognised, rendered in the catalogue's own wording.
        total_records: How many records the whole file held.
        selected_records: How many the *Diagnostic* profile kept.
        uncatalogued: How many kept records the catalogue says nothing about.
    """

    excerpt: str
    catalogue: str
    total_records: int
    selected_records: int
    uncatalogued: int


def digest_log(root: Path, path: Path, *, max_chars: int = DEFAULT_EXCERPT_CHARS) -> LogDigest:
    """Reduce a whole log file to what a reader can hold in one screen.

    Reuses the tools' own pieces end to end — the ``rules.json`` catalogue, the *Diagnostic* filter
    profile, the bounded excerpt builder and its sacrifice order — rather than growing a second
    implementation that would drift from the one the log viewer shows a user.

    Args:
        root: The repository checkout root.
        path: The log file, already downloaded to local storage.
        max_chars: Ceiling on the rendered excerpt.

    Returns:
        The digest.

    Raises:
        ToolkitUnavailable: The log tooling is not reachable from the checkout, or the file could
            not be indexed. The caller attaches the file anyway and says the excerpt is missing.
    """
    # Checked before anything else: the buffer swallows a read failure and reports a size of zero,
    # so an unreadable file would otherwise produce a perfectly well-formed excerpt saying the log
    # held nothing — which a reader cannot tell from a log that really held nothing.
    try:
        if not path.is_file() or path.stat().st_size == 0:
            raise ToolkitUnavailable(f"{path.name} is empty or could not be read")
    except OSError as error:
        raise ToolkitUnavailable(f"{path.name} could not be read: {type(error).__name__}") from error

    rules_module = _module(root, "veaf_logs.rules")
    store_module = _module(root, "veaf_logs.store")
    buffer_module = _module(root, "veaf_logs.buffer")
    profiles_module = _module(root, "veaf_logs.profiles")
    excerpt_module = _module(root, "veaf_logs.excerpt")
    catalogue_module = _module(root, "veaf_logs.catalogue")

    try:
        rules = rules_module.Rules.load()
        store = store_module.LogStore(rules, buffer_module.FileBuffer(path))
        store.index_new()
        filters = _diagnostic_profile(profiles_module, rules)
        excerpt = excerpt_module.build_excerpt(store, filters, max_chars=max_chars)
        matches = catalogue_module.match_catalogue(rules, excerpt)
        uncatalogued = catalogue_module.uncatalogued_entries(rules, excerpt)
    except Exception as error:  # noqa: BLE001 - a malformed log must not take the report down
        raise ToolkitUnavailable(_unavailable("the log could not be reduced", error, path)) from error

    return LogDigest(
        excerpt=str(excerpt.to_text()),
        catalogue=str(catalogue_module.render_catalogue(matches)),
        total_records=int(excerpt.total_indexed),
        selected_records=int(excerpt.selected),
        uncatalogued=len(uncatalogued),
    )


def _diagnostic_profile(profiles_module: ModuleType, rules: Any) -> Any:
    """Return the built-in *Diagnostic* filter set.

    It is looked up by its declared behaviour — errors kept, everything else as context — rather
    than by trusting a display name that is French prose and could be reworded. The name is tried
    first because it is the profile the ticket names; the fallback keeps the digest working if it
    is ever retitled.

    Args:
        profiles_module: The imported ``veaf_logs.profiles``.
        rules: The loaded catalogue.

    Returns:
        The filter set.

    Raises:
        ToolkitUnavailable: No profile in the catalogue keeps errors and demotes the rest.
    """
    builtin = profiles_module.builtin_profiles(rules)
    for name, filters in builtin.items():
        if name.lower().startswith("diagnostic"):
            return filters
    for filters in builtin.values():
        if getattr(filters, "context_lines", 0) > 0:
            return filters
    raise ToolkitUnavailable("no diagnostic filter profile is available in the checkout")


# ---------------------------------------------------------------------------
# The mission summary
# ---------------------------------------------------------------------------

#: Mission fields the summary publishes, and nothing else.
#:
#: A ``.miz`` carries mission passwords, briefing text a squadron may not want public, and the whole
#: unit layout. Ticket 02 asks for the published set to be **decided explicitly**, so it is a
#: literal here rather than "whatever the export happened to produce": adding a field is a visible
#: edit to this tuple, in a diff a reviewer reads.
#: Notably **not** here: mission and briefing text (``descriptionText``, ``sortie``), which carry
#: squadron prose and sometimes real names; ``forcedOptions`` and ``pictureFileNameN``; and every
#: group, unit and waypoint *name*, which are a roster. What is published is the mission's shape.
PUBLISHED_MISSION_FIELDS: tuple[str, ...] = (
    "theatre",
    "version",
    "date",
    "start_time",
    "weather",
    "coalitions",
    "group_counts",
    "trigger_zone_count",
)


@dataclass(frozen=True)
class MissionSummary:
    """The handful of facts about a mission that help reproduce a bug.

    Attributes:
        fields: The published fields, keyed by :data:`PUBLISHED_MISSION_FIELDS`. Absent keys mean
            the mission did not state them.
        withheld: Names of the field groups the export produced and this summary deliberately
            dropped, so the issue can say what was left out rather than pretending it saw nothing.
    """

    fields: dict[str, Any] = field(default_factory=dict)
    withheld: tuple[str, ...] = ()


def summarise_mission(root: Path, path: Path) -> MissionSummary:
    """Describe a ``.miz`` through the tools' own parser, never by reading bytes.

    The export path parses the mission's Lua with ``luadata`` and executes nothing, which is both
    the safe way to read a stranger's mission and the only way to choose field by field what is
    published.

    Args:
        root: The repository checkout root.
        path: The ``.miz`` file, already downloaded.

    Returns:
        The summary, holding only :data:`PUBLISHED_MISSION_FIELDS`.

    Raises:
        ToolkitUnavailable: The mission tooling is not reachable — it needs third-party packages the
            service does not install — or the archive could not be parsed. Either way the caller
            says the mission was attached but not summarised.
    """
    miz_tools = _module(root, "mission_tools.miz_tools")
    try:
        mission = miz_tools.read_miz(path)
        table = _mission_table(mission)
    except Exception as error:  # noqa: BLE001 - a corrupt or hostile archive is a missing section
        raise ToolkitUnavailable(_unavailable("the mission could not be read", error, path)) from error
    return _select_published_fields(table)


def _mission_table(mission: Any) -> dict[str, Any]:
    """Pull the parsed ``mission`` table out of whatever the parser returned.

    Args:
        mission: The object ``read_miz`` produced.

    Returns:
        The mission table, or an empty mapping.
    """
    for attribute in ("mission_content", "mission", "data"):
        found = getattr(mission, attribute, None)
        if isinstance(found, dict):
            return found
    return mission if isinstance(mission, dict) else {}


def _select_published_fields(table: dict[str, Any]) -> MissionSummary:
    """Reduce a parsed mission to the published field set.

    Args:
        table: The parsed ``mission`` table.

    Returns:
        The summary.
    """
    fields: dict[str, Any] = {}
    if isinstance(table.get("theatre"), str):
        fields["theatre"] = table["theatre"]
    if table.get("version") is not None:
        fields["version"] = str(table["version"])
    if table.get("start_time") is not None:
        fields["start_time"] = str(table["start_time"])
    date = table.get("date")
    if isinstance(date, dict):
        fields["date"] = "-".join(str(date.get(part, "?")) for part in ("Year", "Month", "Day"))

    weather = table.get("weather")
    if isinstance(weather, dict):
        summary = {
            "temperature": weather.get("season", {}).get("temperature")
            if isinstance(weather.get("season"), dict)
            else None,
            "cloud_base": weather.get("clouds", {}).get("base") if isinstance(weather.get("clouds"), dict) else None,
            "cloud_preset": weather.get("clouds", {}).get("preset")
            if isinstance(weather.get("clouds"), dict)
            else None,
        }
        kept = {key: value for key, value in summary.items() if value is not None}
        if kept:
            fields["weather"] = kept

    coalitions = table.get("coalition")
    if isinstance(coalitions, dict):
        fields["coalitions"] = sorted(str(name) for name in coalitions)
        fields["group_counts"] = _count_groups(coalitions)

    triggers = table.get("triggers")
    if isinstance(triggers, dict):
        zones = triggers.get("zones")
        if isinstance(zones, list | dict):
            fields["trigger_zone_count"] = len(zones)

    withheld = tuple(sorted(str(key) for key in table if key not in {"theatre", "version", "start_time", "date"}))
    return MissionSummary(fields=fields, withheld=withheld)


def _count_groups(coalitions: dict[str, Any]) -> dict[str, int]:
    """Count groups per coalition and category, without naming any of them.

    Group names are written by mission makers and routinely carry squadron names, callsigns and
    in-jokes. A count reproduces the mission's shape; the names would publish a roster.

    Args:
        coalitions: The mission's ``coalition`` table.

    Returns:
        ``{"<coalition>/<category>": count}``, sorted by key.
    """
    counts: dict[str, int] = {}
    for side, content in coalitions.items():
        countries = content.get("country") if isinstance(content, dict) else None
        # A sequence table comes back as a list once the parser has closed its holes, and as a dict
        # when it never had contiguous keys. Both shapes are enumerated the same way here.
        for country in _values(countries):
            if not isinstance(country, dict):
                continue
            for category, holder in country.items():
                groups = holder.get("group") if isinstance(holder, dict) else None
                if isinstance(groups, list | dict):
                    key = f"{side}/{category}"
                    counts[key] = counts.get(key, 0) + len(groups)
    return dict(sorted(counts.items()))


def _values(container: Any) -> list[Any]:
    """Return the members of a Lua sequence table, whichever shape the parser produced.

    Args:
        container: A list, a dict, or anything else.

    Returns:
        The members, or an empty list.
    """
    if isinstance(container, dict):
        return list(container.values())
    return list(container) if isinstance(container, list) else []
