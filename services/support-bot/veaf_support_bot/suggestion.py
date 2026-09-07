"""What a submitted idea becomes: a feature request shaped like the repository's own template.

``.github/ISSUE_TEMPLATE/feature_request.yml`` exists — component, problem, solution, alternatives,
context — and has never been filled in by a human. The machine fills it every time, in the asker's
language, so a maintainer reads the same shape whether the request came through GitHub or through
Discord.

## The field that makes a request decidable

The template asks *what problem does this solve?* first, and that is the field people skip: someone
who wants a feature describes the solution he imagined, not the pain behind it. A solution with no
problem cannot be weighed against anything, cannot be met a different way, and cannot be declined
for a reason anyone can state. So the form asks for it, and the issue prints it first.

## What is not here

No design sketch. The session that specified this weighed it and turned it down: a wrong sketch in a
public issue steers the discussion into a wall, durably, and it is expensive to unwind. The issue
states the problem, the request, and what was checked before opening it. Where it would fit is the
work of whoever opens the lot.

Every field is the asker's own text and is quoted as such — see :mod:`veaf_support_bot.untrusted`.
Nothing in it selects a code path here: the component comes from a Discord choice bound to the list
below, never from free text.
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass

from veaf_support_bot.existing import ABSENT, EXISTS, DocumentationCheck
from veaf_support_bot.issue_body import BODY_MAX_CHARS, marker_for
from veaf_support_bot.priorart import Sweep
from veaf_support_bot.untrusted import one_line, quote

#: Label the repository's own template puts on a feature request.
BASE_LABEL = "enhancement"

#: Longest issue title. The bug flow's bound, for the same reason: GitHub allows 256 and nobody
#: reads that far.
TITLE_MAX_CHARS = 110

#: Field lengths the modal enforces, mirrored here so the handler's bounds hold whatever calls it.
SUMMARY_MAX_CHARS = 200
PARAGRAPH_MAX_CHARS = 1200

#: The component options of ``.github/ISSUE_TEMPLATE/feature_request.yml``, in its order.
#: ``tests/test_suggestion.py`` asserts they still exist in that file: a renamed option would leave
#: the bot writing a component nobody can filter on, and nothing else would notice.
COMPONENTS: tuple[str, ...] = (
    "Lua runtime scripts (in-mission)",
    "veaf-tools.exe (Python CLI)",
    "veaf-build (build pipeline)",
    "Documentation",
    "DevContainer / tooling",
    "Other",
)

#: The option chosen when none was, which is the template's own catch-all.
UNKNOWN_COMPONENT = "Other"

#: Section headings, per language. The English ones are the template's field labels, word for word.
_HEADINGS: dict[str, dict[str, str]] = {
    "fr": {
        "component": "Composant",
        "problem": "Quel problème cela résout-il ?",
        "solution": "Solution proposée",
        "alternatives": "Alternatives envisagées",
        "context": "Contexte supplémentaire",
        "checked": "Ce qui a été vérifié avant d'ouvrir",
        "documentation_answered": (
            "La documentation a été interrogée et a répondu ; la demande a été maintenue malgré cette "
            "réponse — soit qu'elle ne réglait pas le besoin, soit qu'elle soit restée sans réponse. "
            "Ce que la documentation a répondu :"
        ),
        "documentation_unasked": (
            "La documentation a été interrogée et a répondu, mais la question n'a **pas** pu lui "
            "être posée : le temps imparti à l'échange ne le permettait plus. Personne n'a donc dit "
            "que ce n'était pas ça. Ce que la documentation a répondu :"
        ),
        "documentation_silent": (
            "La documentation a été interrogée : elle ne dit rien à ce sujet. **Si la fonctionnalité "
            "existe déjà**, c'est une lacune de documentation, pas une demande de fonctionnalité — "
            "et c'est le correctif le moins cher qui soit."
        ),
        "documentation_unknown": "La documentation n'a pas pu être interrogée, donc elle n'a pas été vérifiée.",
        "pages": "Pages citées :",
        "filed_by": "Proposé sur Discord par **{asker}** · déposé automatiquement par le bot de support VEAF.",
        "thread": "Fil d'origine : {url}",
        "no_thread": "Fil d'origine : (non enregistré)",
        "verbatim": "_Cité tel quel, ni traduit ni reformulé._",
        "no_sketch": (
            "_Aucune ébauche technique : le bot énonce le besoin et ce qui a été vérifié, pas la façon de le réaliser._"
        ),
    },
    "en": {
        "component": "Component",
        "problem": "What problem does this solve?",
        "solution": "Proposed solution",
        "alternatives": "Alternatives considered",
        "context": "Additional context",
        "checked": "What was checked before opening this",
        "documentation_answered": (
            "The documentation was asked and it answered; the request was maintained regardless — "
            "either the answer did not settle the need, or it went unanswered. What the "
            "documentation answered:"
        ),
        "documentation_unasked": (
            "The documentation was asked and it answered, but the question could **not** be put to "
            "the person who made the request: the exchange had no time left for it. So nobody said "
            "this was not it. What the documentation answered:"
        ),
        "documentation_silent": (
            "The documentation was asked: it says nothing about this. **If the feature already "
            "exists**, this is a documentation gap rather than a feature request — and the cheapest "
            "fix there is."
        ),
        "documentation_unknown": "The documentation could not be asked, so it was not checked.",
        "pages": "Pages cited:",
        "filed_by": "Suggested on Discord by **{asker}** · filed automatically by the VEAF support bot.",
        "thread": "Original thread: {url}",
        "no_thread": "Original thread: (not recorded)",
        "verbatim": "_Quoted verbatim, neither translated nor reworded._",
        "no_sketch": ("_No technical sketch: the bot states the need and what was checked, not how to build it._"),
    },
}


@dataclass(frozen=True)
class SuggestionForm:
    """What the asker typed, plus the component he picked from the command's own list.

    Attributes:
        summary: One line — becomes the issue title.
        problem: The pain behind the request. Required, and the reason the exchange exists.
        solution: What he would like to happen. Required.
        alternatives: Other approaches he considered.
        context: Anything else — examples, links, a mission that shows the need.
        component: One of :data:`COMPONENTS`.
        asker: How to credit him in the issue, already a display name.
        asker_id: His Discord id, for the relay and for the idempotency key.
        language: ``"fr"`` or ``"en"`` — the issue is written in his language.
    """

    summary: str
    problem: str
    solution: str
    alternatives: str = ""
    context: str = ""
    component: str = UNKNOWN_COMPONENT
    asker: str = ""
    asker_id: str = ""
    language: str = "fr"

    def all_text(self) -> str:
        """Return every free-text field joined.

        Returns:
            The fields in form order, newline-separated. This is what the documentation is asked
            about and what the sweep is run against.
        """
        return "\n".join((self.summary, self.problem, self.solution, self.alternatives, self.context))

    def missing_fields(self) -> tuple[str, ...]:
        """Name the required fields left empty.

        Discord enforces its own ``required`` flag, but a modal submitted through the API — or a
        field holding only spaces — reaches here empty all the same.

        Returns:
            The field names, in form order.
        """
        named = (("summary", self.summary), ("problem", self.problem), ("solution", self.solution))
        return tuple(name for name, value in named if not value.strip())


def heading(key: str, lang: str) -> str:
    """Return one section heading in the asker's language.

    Args:
        key: Heading key.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The heading text.
    """
    return _HEADINGS.get(lang, _HEADINGS["en"])[key]


def language_of(form: SuggestionForm) -> str:
    """Return the language the issue is written in.

    Args:
        form: The submitted form.

    Returns:
        ``"fr"`` or ``"en"`` — an unrecognised locale is written in English rather than refused.
    """
    return form.language if form.language in _HEADINGS else "en"


def suggestion_key(form: SuggestionForm) -> str:
    """Derive the stable identity of one suggestion.

    Built from what the asker supplied and nothing else — not from a timestamp, not from a random
    value — so the same suggestion submitted twice produces the same key and a restart can recompute
    it. It is what :meth:`~veaf_support_bot.filing.IssueFiler.file_prepared` deduplicates on.

    Args:
        form: The submitted form.

    Returns:
        A 32-character hex digest.
    """
    material = (form.asker_id, form.summary, form.problem, form.solution, form.alternatives, form.context)
    return hashlib.sha256("\x1f".join(material).encode("utf-8", errors="replace")).hexdigest()[:32]


def build_title(form: SuggestionForm) -> str:
    """Compose the issue title.

    Args:
        form: The submitted form.

    Returns:
        A single bounded line, the asker's own summary.
    """
    return one_line(form.summary, TITLE_MAX_CHARS) or "feature request with no summary"


def render_checked(check: DocumentationCheck, sweep: Sweep | None, lang: str, *, asked: bool = True) -> str:
    """Render what was consulted before the issue was opened.

    A reader three months later should not have to redo the search — and the difference between
    *the documentation is silent* and *the documentation was never reached* has to survive into the
    tracker, because only the first of the two is a finding.

    Args:
        check: What the documentation answered.
        sweep: What the issues, backlog and roadmap sweep found; ``None`` when no sweep ran.
        lang: ``"fr"`` or ``"en"``.
        asked: Whether the answer was actually put to the person who made the request. When it was
            not — the exchange ran out of token — the section says so instead of reporting a
            disagreement nobody expressed.

    Returns:
        The section body.
    """
    lines: list[str] = []
    if check.verdict == EXISTS:
        lines.append(heading("documentation_answered" if asked else "documentation_unasked", lang))
        lines.append(quote(check.answer))
        if check.links:
            lines.append(f"{heading('pages', lang)} " + ", ".join(check.links))
    elif check.verdict == ABSENT:
        lines.append(heading("documentation_silent", lang))
    else:
        lines.append(heading("documentation_unknown", lang))
        if check.problem:
            lines.append(f"- {check.problem}")
    if sweep is not None:
        lines.append(sweep.describe())
        if sweep.best is not None:
            lines.append(f"- {sweep.best.evidence()}")
            lines.extend(f"- {other.evidence()}" for other in sweep.alternatives)
    return "\n\n".join(line for line in lines if line)


def render_suggestion_body(
    form: SuggestionForm,
    key: str,
    *,
    check: DocumentationCheck,
    sweep: Sweep | None = None,
    thread_url: str = "",
    asked: bool = True,
) -> str:
    """Render the whole issue body, in the shape of the repository's feature request template.

    Args:
        form: The submitted form.
        key: The idempotency key, embedded as the hidden marker the recovery search greps for.
        check: What the documentation answered about the request.
        sweep: What the issues, backlog and roadmap sweep found.
        thread_url: Link back to the Discord thread, when there is one.
        asked: Whether the documentation's answer was put to the person who made the request.

    Returns:
        The Markdown body, bounded to what GitHub accepts.
    """
    lang = language_of(form)
    parts: list[str] = [marker_for(key)]
    parts.append(f"### {heading('component', lang)}\n\n{form.component}")
    parts.append(f"### {heading('problem', lang)}\n\n{quote(form.problem)}")
    parts.append(f"### {heading('solution', lang)}\n\n{quote(form.solution)}")
    if form.alternatives.strip():
        parts.append(f"### {heading('alternatives', lang)}\n\n{quote(form.alternatives)}")
    context = [heading("verbatim", lang)]
    if form.context.strip():
        context.insert(0, quote(form.context))
    parts.append(f"### {heading('context', lang)}\n\n" + "\n\n".join(context))
    parts.append(f"### {heading('checked', lang)}\n\n{render_checked(check, sweep, lang, asked=asked)}")
    parts.append(heading("no_sketch", lang))
    parts.append("---")
    parts.append(heading("filed_by", lang).format(asker=one_line(form.asker or "?", 80)))
    parts.append(heading("thread", lang).format(url=thread_url) if thread_url else heading("no_thread", lang))
    return "\n\n".join(parts)[:BODY_MAX_CHARS]
