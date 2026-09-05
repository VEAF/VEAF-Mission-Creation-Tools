"""What ``rules.json`` already knows, said out loud.

The catalogue is not a filter. It carries **13 recognised sources**, **8 families of native DCS
subsystems** and **22 known-noise patterns**, and every noise family holds a ``help`` string written
for a user — *"Modules tiers dont le modèle de dégâts n'est pas au format attendu. Cosmétique."*
Until now that text only drove colouring and hiding; nobody was ever shown it as an answer.

This module renders it. Two rules govern what comes out.

**The wording is reproduced as it stands.** A catalogue entry is a verified explanation someone
wrote and reviewed; paraphrasing it turns a fact back into a guess. So the ``help`` text travels
verbatim, and the only thing this module adds around it is a count.

**Silence is reported as silence.** A record matching no entry is listed as *uncatalogued*, never
explained. The worst failure of the whole feature is a plausible wrong cause — *"it comes from your
module X"* when it does not — because the reader cannot tell it from a right one and will spend his
evening on it. Counting what the catalogue does not cover is also what feeds
:mod:`veaf_logs.proposals`: an uncatalogued pattern that recurs is a missing entry.
"""

from __future__ import annotations

from dataclasses import dataclass

from .excerpt import Excerpt, ExcerptEntry
from .rules import NATIVE_SOURCE, Rules

#: What a match is: a noise family (which carries an explanation), the emitting source, or the
#: family of native DCS subsystems the record belongs to.
KIND_NOISE = "noise"
KIND_SOURCE = "source"
KIND_SUBSYSTEM = "subsystem"


@dataclass(frozen=True)
class CatalogueMatch:
    """One catalogue entry the excerpt matched, with how often it did."""

    id: str
    label: str
    help: str
    kind: str
    count: int

    def render(self) -> str:
        """Render this match the way the catalogue states it, plus its count."""
        head = f"{self.label} ({self.id}) ×{self.count}"
        return f"- {head} : {self.help}" if self.help else f"- {head}"


def subsystem_family(rules: Rules, subsystem: str) -> str:
    """Name the family a native DCS subsystem belongs to.

    Args:
        rules: The loaded catalogue.
        subsystem: The subsystem token from a record header (``DX11BACKEND``, ``TERRAIN``…).

    Returns:
        The family name declared in ``subsystem_families``, or an empty string when the subsystem is
        absent from the catalogue — which is the honest answer, not a fallback family.
    """
    if not subsystem:
        return ""
    for family, members in rules.subsystem_families.items():
        if subsystem in members:
            return family
    return ""


def is_catalogued(rules: Rules, entry: ExcerptEntry) -> bool:
    """Say whether the catalogue has anything to say about a record.

    A record is catalogued when a noise family matched it, or when it came from a recognised script
    source. A bare native DCS line the catalogue never named is not.

    Args:
        rules: The loaded catalogue.
        entry: One excerpt record.

    Returns:
        ``True`` when at least one catalogue entry covers the record.
    """
    if entry.noise:
        return True
    return entry.source_id != NATIVE_SOURCE and any(source.id == entry.source_id for source in rules.sources)


def match_catalogue(rules: Rules, excerpt: Excerpt) -> list[CatalogueMatch]:
    """Collect every catalogue entry the excerpt matched, most frequent first.

    Args:
        rules: The loaded catalogue.
        excerpt: The bounded excerpt to explain.

    Returns:
        The matches, ordered by descending count then by id so two runs on the same excerpt render
        identically. Noise families come with their verbatim ``help``; a source or a subsystem
        family carries none, because the catalogue does not write one — stating the emitter is a
        fact, inventing an explanation for it would not be.
    """
    noise_counts: dict[str, int] = {}
    source_counts: dict[str, int] = {}
    family_counts: dict[str, int] = {}
    for entry in excerpt.entries:
        for family in entry.noise:
            noise_counts[family] = noise_counts.get(family, 0) + 1
        if entry.source_id:
            source_counts[entry.source_id] = source_counts.get(entry.source_id, 0) + 1
        family = subsystem_family(rules, entry.subsystem)
        if family:
            family_counts[family] = family_counts.get(family, 0) + 1

    matches: list[CatalogueMatch] = []
    known = {family.id: family for family in rules.noise}
    for identifier, count in noise_counts.items():
        found = known.get(identifier)
        if found is not None:
            matches.append(
                CatalogueMatch(id=found.id, label=found.label, help=found.help, kind=KIND_NOISE, count=count)
            )
    labels = rules.source_labels()
    for identifier, count in source_counts.items():
        matches.append(
            CatalogueMatch(
                id=identifier,
                label=labels.get(identifier, identifier),
                help="",
                kind=KIND_SOURCE,
                count=count,
            )
        )
    for family, count in family_counts.items():
        matches.append(CatalogueMatch(id=family, label=family, help="", kind=KIND_SUBSYSTEM, count=count))
    return sorted(matches, key=lambda item: (-item.count, item.kind, item.id))


def uncatalogued_entries(rules: Rules, excerpt: Excerpt) -> list[ExcerptEntry]:
    """Return the excerpt records the catalogue says nothing about.

    Args:
        rules: The loaded catalogue.
        excerpt: The bounded excerpt.

    Returns:
        The records in log order. This list is the honest half of the answer, and the input of
        :func:`veaf_logs.proposals.propose_rules`.
    """
    return [entry for entry in excerpt.entries if not is_catalogued(rules, entry)]


def render_catalogue(matches: list[CatalogueMatch]) -> str:
    """Render the catalogue layer: verified text, grouped by what it is.

    Args:
        matches: The matches from :func:`match_catalogue`.

    Returns:
        The rendered block. When nothing matched it says so rather than returning an empty string:
        "the catalogue recognised nothing here" is itself an answer, and a blank section reads as a
        bug.
    """
    explained = [item for item in matches if item.kind == KIND_NOISE]
    emitters = [item for item in matches if item.kind != KIND_NOISE]
    blocks: list[str] = []
    if explained:
        blocks.append("Motifs connus (texte du catalogue, tel quel) :\n" + "\n".join(m.render() for m in explained))
    if emitters:
        blocks.append("Émetteurs reconnus :\n" + "\n".join(m.render() for m in emitters))
    if not blocks:
        return "Le catalogue ne reconnaît aucun motif dans cet extrait."
    return "\n\n".join(blocks)


def to_worker_matches(matches: list[CatalogueMatch]) -> list[dict[str, object]]:
    """Shape the matches the way the Worker's ``/analyze`` route reads them.

    Args:
        matches: The matches from :func:`match_catalogue`.

    Returns:
        One ``{"id", "label", "help", "count"}`` mapping per match. Only entries the catalogue
        actually explains are sent: an emitter with no ``help`` adds nothing to the prompt but
        invites the model to fill the blank itself.
    """
    return [
        {"id": item.id, "label": item.label, "help": item.help, "count": item.count}
        for item in matches
        if item.kind == KIND_NOISE
    ]
