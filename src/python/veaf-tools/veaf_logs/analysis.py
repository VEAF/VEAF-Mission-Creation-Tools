"""*Explain*: the catalogue first, ignorance admitted, the model last.

The order between the two layers is the whole design.

1. **The catalogue answers first.** Every record matched by ``rules.json`` is rendered with its own
   verified wording, as it stands. No model, no cost, no network — this layer alone is a useful
   answer and it is the degraded mode the feature must survive in.
2. **The model puts it in context second.** It receives the bounded excerpt and the catalogue
   matches, and it chains: what happened first, what is a consequence of what, which line to act on.
   Where the catalogue is silent it is told to say *motif non catalogué* rather than propose a cause.

The rendering keeps the two apart **per block**, not with a disclaimer at the bottom that nobody
reads: the reader has to be able to tell a verified sentence from a generated one at a glance,
because the worst failure of this feature is not silence, it is a plausible wrong answer that costs
a pilot his evening and reads exactly like a right one.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field

from .catalogue import (
    CatalogueMatch,
    WorkerMatch,
    match_catalogue,
    render_catalogue,
    to_worker_matches,
    uncatalogued_entries,
)
from .excerpt import DEFAULT_MAX_CHARS, Excerpt, build_excerpt
from .filters import FilterSet
from .proposals import ProposedRule, propose_rules, render_proposals
from .rules import Rules
from .store import LogStore
from .worker_client import AnalysisUnavailable, analyse_excerpt

#: Heading of the verified section. The parenthesis names the source, so nobody has to be told twice
#: where the sentences came from.
CATALOGUE_HEADING = "── CATALOGUE VÉRIFIÉ (texte de rules.json, repris tel quel) ──"

#: Heading of the generated section, worded so that the reader knows what he is holding.
MODEL_HEADING = "── MISE EN CONTEXTE PAR LE MODÈLE (généré, à vérifier) ──"

#: Heading of the section listing what nothing explains.
UNCATALOGUED_HEADING = "── NON CATALOGUÉ ──"

#: Heading of the proposals section.
PROPOSALS_HEADING = "── PROPOSITIONS DE RÈGLES ──"

#: What the uncatalogued section says about a record. The phrase matches the one the Worker is told
#: to use, so the two layers do not contradict each other in wording.
UNCATALOGUED_MARK = "motif non catalogué"

#: How many uncatalogued records are listed. Past this the section stops being a list and becomes a
#: second copy of the excerpt.
MAX_UNCATALOGUED_SHOWN = 10


@dataclass(frozen=True)
class Analysis:
    """One *Explain* run: the excerpt, what the catalogue said, and what the model added."""

    excerpt: Excerpt
    matches: list[CatalogueMatch] = field(default_factory=list)
    uncatalogued: list[str] = field(default_factory=list)
    """Messages no catalogue entry covers, in log order, capped at
    :data:`MAX_UNCATALOGUED_SHOWN`."""

    uncatalogued_total: int = 0
    """How many records were uncatalogued, before the cap."""

    proposals: list[ProposedRule] = field(default_factory=list)
    commentary: str = ""
    """What the model said. Empty when the online layer did not run or could not answer."""

    model_error: str = ""
    """Why the model layer produced nothing. Empty when it answered."""

    def to_text(self) -> str:
        """Render the whole answer, verified material first and visually apart.

        Returns:
            The rendered analysis, without a trailing newline. Always non-empty: with no network and
            no catalogue match it still states the excerpt's own header and says what it does not
            know, which is an answer.
        """
        blocks = [self.excerpt.to_text(), CATALOGUE_HEADING, render_catalogue(self.matches)]
        if self.uncatalogued:
            listed = "\n".join(f"- {UNCATALOGUED_MARK} : {message}" for message in self.uncatalogued)
            hidden = self.uncatalogued_total - len(self.uncatalogued)
            if hidden > 0:
                listed += f"\n- … et {hidden} autres lignes non cataloguées"
            blocks.extend([UNCATALOGUED_HEADING, listed])
        blocks.append(MODEL_HEADING)
        blocks.append(self.commentary or self.model_error or "Analyse en ligne non demandée.")
        rendered = render_proposals(self.proposals)
        if rendered:
            blocks.extend([PROPOSALS_HEADING, rendered])
        return "\n\n".join(blocks)


#: The signature of the online layer, so a test can hand in something that does not use the network.
OnlineLayer = Callable[[str, list[WorkerMatch]], str]


def analyse(
    store: LogStore,
    rules: Rules,
    filters: FilterSet,
    visible: list[int] | None = None,
    online: OnlineLayer | None = None,
    max_chars: int = DEFAULT_MAX_CHARS,
) -> Analysis:
    """Explain the current view: catalogue layer always, model layer when asked and reachable.

    Args:
        store: The indexed log.
        rules: The loaded catalogue.
        filters: The filter set backing the current view.
        visible: The record indices the view holds; defaults to re-evaluating the filters.
        online: The online layer to call, or ``None`` to stay offline. Defaults to ``None`` so that
            nothing reaches the network unless a caller asked for it; pass
            :func:`default_online_layer` to use the Worker, and give it the user's question there.
        max_chars: Character ceiling of the excerpt.

    Returns:
        The analysis. **Never raises for a network reason**: an unreachable Worker fills
        ``model_error`` and leaves the catalogue layer intact, because that is the degraded mode the
        feature has to work in.
    """
    excerpt = build_excerpt(store, filters, visible=visible, max_chars=max_chars)
    matches = match_catalogue(rules, excerpt)
    unknown = uncatalogued_entries(rules, excerpt)
    proposals = propose_rules(rules, excerpt)

    commentary = ""
    error = ""
    if online is not None:
        try:
            commentary = online(excerpt.to_text(), to_worker_matches(matches)).strip()
        except AnalysisUnavailable as exc:
            error = str(exc)
        except Exception as exc:  # pragma: no cover - defensive: an online layer is third-party code
            error = f"Analyse en ligne indisponible : {exc}"
        if not commentary and not error:
            error = "Le service n'a rien renvoyé. Le catalogue ci-dessus reste valable."
    return Analysis(
        excerpt=excerpt,
        matches=matches,
        uncatalogued=[entry.message for entry in unknown[:MAX_UNCATALOGUED_SHOWN]],
        uncatalogued_total=len(unknown),
        proposals=proposals,
        commentary=commentary,
        model_error=error,
    )


def default_online_layer(question: str = "", lang: str = "fr") -> OnlineLayer:
    """Return the online layer that talks to the Worker.

    Args:
        question: An optional question from the user, sent alongside the excerpt.
        lang: ``"fr"`` or ``"en"``.

    Returns:
        A callable :func:`analyse` can use, which raises
        :class:`~veaf_logs.worker_client.AnalysisUnavailable` when the Worker cannot answer.
    """

    def layer(excerpt: str, matches: list[WorkerMatch]) -> str:
        return analyse_excerpt(excerpt, matches, question=question, lang=lang)

    return layer
