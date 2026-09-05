"""The issue the bot writes: the template's shape, the reporter's language, quotes untranslated.

## The shape is the repository's own form

``.github/ISSUE_TEMPLATE/bug_report.yml`` asks for six things — version, component, what happened,
what was expected, steps, additional context. **Zero of the last sixty issues used it.** A human
skips a form; a machine fills it every time, and filling *this* one means a maintainer reading a
bot-filed issue finds the fields exactly where he finds them in a hand-filed one.

The headings are therefore the template's labels, not invented ones, and
``tests/test_issue_body.py`` reads the YAML to prove they still match.

## The language is the reporter's, the evidence is nobody's

The repository writes English for technical content; this issue does not, and the departure is
deliberate — the regulars report in French and the tracker already contains French. So the
*headings and the sentences the bot writes* follow the reporter. What he typed, what his log said,
what his mission is called: **never translated, never reworded**, quoted verbatim inside a fence it
cannot escape. A translated log line is evidence somebody edited.

## What the body carries, and what it cannot

Everything the deterministic pass produced is inlined: the located file and line with the revision
it was resolved against, the log excerpt, the mission's shape, the prior-art sweep with what it
checked, and every note about what is missing and why.

The attached files are a different matter, and the limit is GitHub's, not this module's: **the REST
API has no endpoint that attaches a file to an issue** — the one the web interface uses is a session
endpoint, not an API. So a file that is text and fits is carried *inside* the issue, whole, where it
survives as long as the issue does; a file that is binary or too large is listed in the manifest
with its size and its SHA-256, and the issue says plainly that the bytes were not published. Nothing
is ever referenced by a Discord URL: those expire, and an issue whose evidence is a dead link is an
issue with no evidence.
"""

from __future__ import annotations

import hashlib
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

from veaf_support_bot.attachments import Prepared
from veaf_support_bot.bugreport import NOT_STATED, BugReport
from veaf_support_bot.priorart import DUPLICATE, FIXED, IN_PROGRESS, Sweep
from veaf_support_bot.untrusted import one_line, quote

#: Longest issue body GitHub accepts, with room left for the marker and the footer.
BODY_MAX_CHARS = 60000

#: Longest comment GitHub accepts, with the same room left.
COMMENT_MAX_CHARS = 60000

#: Largest text attachment carried whole inside the issue. Past it the file is described rather than
#: reproduced: a body that scrolls for ten minutes is a body nobody reads.
INLINE_MAX_CHARS = 24000

#: Marker embedded in every issue this service files, so a retry can find an issue it already opened
#: even after a restart lost every trace of the attempt. Machine-readable, invisible when rendered.
MARKER_PREFIX = "<!-- veaf-support-bot:report="

MARKER_SUFFIX = " -->"

#: Kinds of :data:`~veaf_support_bot.attachments.ACCEPTED_SUFFIXES` whose bytes are text and can
#: therefore be carried inside the issue. A ``mission`` is a zip and an ``archive`` is a zip;
#: neither survives being read as text.
INLINE_KINDS = ("log", "text")

#: Headings, in the two documentation languages. The English column is the template's own labels.
_HEADINGS = {
    "fr": {
        "version": "Version",
        "component": "Composant",
        "happened": "Ce qui s'est passé",
        "expected": "Ce qui était attendu",
        "steps": "Étapes pour reproduire",
        "context": "Contexte additionnel",
        "located": "Localisation dans le code",
        "mission": "Mission",
        "logs": "Extrait de journal",
        "files": "Fichiers joints",
        "priorart": "Antériorité",
        "missing": "Ce qui manque, et pourquoi",
        "no_hypothesis": (
            "_Aucune hypothèse : ce rapport a été rempli sans modèle. Tout ce qui précède est lu, "
            "analysé ou cité — rien n'est deviné._"
        ),
        "filed_by": "Rapporté sur Discord par **{reporter}** · déposé automatiquement par le bot de support VEAF.",
        "thread": "Fil d'origine : {url}",
        "no_thread": "Fil d'origine : (non enregistré)",
        "not_published": "non publié ici : {reason}",
        "carried": "carried in full below",
        "revision": "Dépôt consulté : {revision}",
        "verbatim": "_Cité tel quel, sans traduction ni reformulation._",
    },
    "en": {
        "version": "Version",
        "component": "Component",
        "happened": "What happened?",
        "expected": "What did you expect?",
        "steps": "Steps to reproduce",
        "context": "Additional context",
        "located": "Located in the code",
        "mission": "Mission",
        "logs": "Log excerpt",
        "files": "Attached files",
        "priorart": "Prior art",
        "missing": "What is missing, and why",
        "no_hypothesis": (
            "_No hypothesis: this report was filled in without a model. Everything above is read, "
            "parsed or quoted — none of it is guessed._"
        ),
        "filed_by": "Reported on Discord by **{reporter}** · filed automatically by the VEAF support bot.",
        "thread": "Original thread: {url}",
        "no_thread": "Original thread: (not recorded)",
        "not_published": "not published here: {reason}",
        "carried": "carried in full below",
        "revision": "Repository consulted: {revision}",
        "verbatim": "_Quoted verbatim, neither translated nor reworded._",
    },
}


def heading(key: str, lang: str) -> str:
    """Return one section heading in the reporter's language.

    Args:
        key: Heading key.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The heading text.
    """
    return _HEADINGS.get(lang, _HEADINGS["en"])[key]


def marker_for(key: str) -> str:
    """Return the hidden marker identifying one report.

    Args:
        key: The report's idempotency key.

    Returns:
        An HTML comment, invisible in the rendered issue and greppable through the API.
    """
    return f"{MARKER_PREFIX}{key}{MARKER_SUFFIX}"


def digest_of(path: Path) -> str:
    """Return the SHA-256 of a file, so a reader can check the copy he was sent.

    Args:
        path: The file.

    Returns:
        The hex digest, or an empty string when the file could not be read.
    """
    try:
        hasher = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                hasher.update(chunk)
    except OSError:
        return ""
    return hasher.hexdigest()


@dataclass(frozen=True)
class Carried:
    """One attachment, and what became of it.

    Attributes:
        prepared: The file as the attachment pass left it.
        text: Its content, when it is text small enough to carry whole. Empty otherwise.
        reason: Why the bytes are not here, when they are not.
        digest: SHA-256 of the file.
    """

    prepared: Prepared
    text: str = ""
    reason: str = ""
    digest: str = ""


def carry(prepared: Prepared, *, limit: int = INLINE_MAX_CHARS) -> Carried:
    """Decide how one attachment travels into the issue.

    Args:
        prepared: The file the attachment pass produced.
        limit: Longest text carried whole.

    Returns:
        The decision. Text that fits is read and carried; everything else is described, because the
        REST API cannot attach a file to an issue and a Discord URL is dead within days.
    """
    digest = digest_of(prepared.path)
    if prepared.kind not in INLINE_KINDS:
        return Carried(prepared, reason=f"binary file ({prepared.kind}), which an issue cannot hold", digest=digest)
    if prepared.size > limit:
        return Carried(
            prepared,
            reason=f"{prepared.size} bytes, past the {limit} an issue can carry — see the excerpt above",
            digest=digest,
        )
    try:
        content = prepared.path.read_text(encoding="utf-8", errors="replace")
    except OSError as error:
        return Carried(prepared, reason=f"could not be read back ({type(error).__name__})", digest=digest)
    return Carried(prepared, text=content, digest=digest)


def render_prior_art(sweep: Sweep, lang: str) -> str:
    """Render what the sweep checked and what it proposed.

    Recorded even when nothing matched: a reader who cannot see that the sweep ran has to run it
    again himself.

    Args:
        sweep: The finding.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The section body.
    """
    lines = [sweep.describe()]
    if sweep.best is not None:
        outcome = {
            DUPLICATE: "a similar open issue was proposed and the reporter said his is different",
            FIXED: "a closed issue was proposed and the reporter said his is different",
            IN_PROGRESS: "existing work was proposed and the reporter said his is different",
        }[sweep.verdict]
        lines.append(f"Closest match, **rejected by the reporter** ({outcome}):")
        lines.append(f"- {sweep.best.evidence()}")
        for other in sweep.alternatives:
            lines.append(f"- also considered: {other.evidence()}")
    if lang == "fr":
        lines.append("_Balayage déterministe : appariement de mots, aucun modèle._")
    return "\n".join(lines)


def render_body(report: BugReport, key: str, *, thread_url: str = "", carried: Iterable[Carried] = ()) -> str:
    """Render the whole issue body.

    Args:
        report: The assembled report.
        key: The idempotency key, embedded as the hidden marker.
        thread_url: Link back to the Discord thread, when there is one.
        carried: What became of each attachment.

    Returns:
        The Markdown body, bounded to what GitHub accepts.
    """
    lang = report.form.language if report.form.language in _HEADINGS else "en"
    parts: list[str] = [marker_for(key)]

    parts.append(f"### {heading('version', lang)}\n\n{report.version}")
    parts.append(f"### {heading('component', lang)}\n\n{report.component}")
    parts.append(f"### {heading('happened', lang)}\n\n{quote(report.form.happened)}")
    parts.append(f"### {heading('expected', lang)}\n\n{quote(report.form.expected)}")
    parts.append(f"### {heading('steps', lang)}\n\n{quote(report.form.steps)}")

    context: list[str] = [heading("verbatim", lang), "", heading("revision", lang).format(revision=report.freshness.describe())]
    if report.form.doctor.strip():
        context.append("\n<details><summary>veaf-tools doctor</summary>\n\n" + quote(report.form.doctor) + "\n</details>")
    parts.append(f"### {heading('context', lang)}\n\n" + "\n".join(context))

    located = _render_locations(report)
    if located:
        parts.append(f"### {heading('located', lang)}\n\n{located}")
    if report.mission_summaries:
        parts.append(f"### {heading('mission', lang)}\n\n" + "\n\n".join(report.mission_summaries))
    if report.log_digests:
        parts.append(f"### {heading('logs', lang)}\n\n" + "\n\n".join(report.log_digests))

    files = _render_manifest(carried, lang)
    if files:
        parts.append(f"### {heading('files', lang)}\n\n{files}")
    if report.prior_art is not None:
        parts.append(f"### {heading('priorart', lang)}\n\n{render_prior_art(report.prior_art, lang)}")
    if report.notes:
        listed = "\n".join(f"- **{note.subject}** — {note.reason}" for note in report.notes)
        parts.append(f"### {heading('missing', lang)}\n\n{listed}")

    parts.append(heading("no_hypothesis", lang))
    parts.append("---")
    parts.append(heading("filed_by", lang).format(reporter=one_line(report.form.reporter or "?", 80)))
    parts.append(heading("thread", lang).format(url=thread_url) if thread_url else heading("no_thread", lang))
    return "\n\n".join(parts)[:BODY_MAX_CHARS]


def _render_locations(report: BugReport) -> str:
    """Render the resolved locations, each with its callers.

    Args:
        report: The assembled report.

    Returns:
        The section body, or an empty string when nothing was located.
    """
    lines: list[str] = []
    for location in report.located:
        line = f"- `{location.relative}:{location.line}`"
        if location.function:
            line += f" in `{location.function}`"
        if location.caller_total:
            line += f" — {location.caller_total} call site(s): {', '.join(location.callers)}"
        lines.append(line)
    return "\n".join(lines)


def _render_manifest(carried: Iterable[Carried], lang: str) -> str:
    """Render one line per attachment, saying whether its bytes are in the issue.

    Args:
        carried: What became of each attachment.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The manifest, or an empty string when there were no attachments.
    """
    lines: list[str] = []
    for item in carried:
        state = heading("carried", lang) if item.text else heading("not_published", lang).format(reason=item.reason)
        digest = f" · `sha256:{item.digest[:16]}`" if item.digest else ""
        lines.append(f"- `{item.prepared.filename}` — {item.prepared.size} bytes{digest} — {state}")
    return "\n".join(lines)


def render_attachment_comments(carried: Iterable[Carried]) -> list[str]:
    """Render the follow-up comments that carry the text attachments whole.

    They are comments rather than more body: a body holding three files scrolls past everything a
    maintainer needs to read first, and a comment can be collapsed.

    Args:
        carried: What became of each attachment.

    Returns:
        One comment per carried file, in order.
    """
    comments: list[str] = []
    for item in carried:
        if not item.text:
            continue
        header = f"**`{item.prepared.filename}`** — {item.prepared.size} bytes"
        if item.digest:
            header += f", `sha256:{item.digest}`"
        comments.append(f"{header}\n\n{quote(item.text)}"[:COMMENT_MAX_CHARS])
    return comments


def render_duplicate_comment(report: BugReport, lang: str, thread_url: str = "") -> str:
    """Render what is added to an **existing** issue instead of opening a second one.

    Args:
        report: The assembled report.
        lang: ``"fr"`` or ``"en"``.
        thread_url: Link back to the Discord thread.

    Returns:
        The comment body.
    """
    parts = [
        f"**{one_line(report.title, 120)}**",
        heading("verbatim", lang),
        f"### {heading('happened', lang)}\n\n{quote(report.form.happened)}",
        f"### {heading('steps', lang)}\n\n{quote(report.form.steps)}",
        f"{heading('version', lang)}: {report.version or NOT_STATED} · {heading('component', lang)}: {report.component}",
        heading("filed_by", lang).format(reporter=one_line(report.form.reporter or "?", 80)),
    ]
    if thread_url:
        parts.append(heading("thread", lang).format(url=thread_url))
    return "\n\n".join(parts)[:COMMENT_MAX_CHARS]
