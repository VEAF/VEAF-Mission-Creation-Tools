"""Every sentence the bot says to a user, in both documentation languages.

The service does not reuse ``veaf_libs.i18n``: that layer belongs to the shipped tools, loads its
catalogues from the tools' package tree and is not installed here. What is reused is the rule — a
user-facing string is never built by concatenating fragments in the code, and French and English are
written side by side so one cannot quietly fall behind. ``tests/test_texts.py`` asserts the two
catalogues hold exactly the same keys and the same placeholders.

Only *answers* follow the asker. The ``/ask`` command's own name and description are what Discord
shows in the command picker, and localising those needs an ``app_commands.Translator`` and a
round-trip through Discord's command registration; they stay in English, which is also the
repository's language for anything structural.
"""

from __future__ import annotations

import re
from typing import Any, Final

#: The two languages the documentation corpus is indexed in.
LANGUAGES: Final = ("fr", "en")

#: Fallback language, matching the documentation site's default locale.
DEFAULT_LANGUAGE: Final = "fr"

#: Published documentation site, development channel — the one the tools already link to
#: (``mission_builder/v5_converter.py``). English lives under ``/en/``, French at the root.
DOC_SITE_BASE: Final = "https://veaf.github.io/documentation/dev"

_TEXTS: Final[dict[str, dict[str, str]]] = {
    "fr": {
        # --- the exchange -------------------------------------------------------------------
        "ask.header": "**{user}** demande : {question}",
        "ask.thinking": "_Je cherche dans la documentation…_",
        "ask.streaming": "_▌_",
        "ask.thread_name": "❓ {topic}",
        "ask.sources": "-# 📄 Sources : {links}",
        "ask.no_sources": (
            "-# ❔ Aucune page de documentation n'a été citée : la question sort peut-être de ce que "
            "la documentation couvre. Où demander de l'aide : [Obtenir de l'aide]({support_url})"
        ),
        "ask.disclaimer": (
            "-# Réponse produite à partir de la documentation VEAF ; elle peut être fausse ou "
            "dépassée. Corrigez-la dans ce fil si c'est le cas."
        ),
        "ask.truncated": "-# ✂️ Réponse tronquée : elle dépassait ce qu'un message Discord peut porter.",
        # --- upstream failures --------------------------------------------------------------
        "ask.error.unavailable": (
            "Je n'arrive pas à joindre l'assistant de documentation pour le moment. Réessaie dans "
            "quelques minutes ; si ça dure, dis-le sur le canal support."
        ),
        "ask.error.rate_limited": (
            "L'assistant de documentation reçoit trop de questions en ce moment. Réessaie dans quelques minutes."
        ),
        "ask.error.timeout": (
            "L'assistant de documentation a mis trop de temps à répondre. Réessaie ; si ça se "
            "reproduit, pose la question sur le canal support."
        ),
        "ask.error.empty": (
            "L'assistant de documentation n'a renvoyé aucune réponse. Réessaie en reformulant la question."
        ),
        # Not a user error and not retryable: the Worker refuses this bot until its secret is
        # configured server-side. Saying "réessaie" would be a lie, so it says who can fix it.
        "ask.error.forbidden": (
            "L'assistant de documentation refuse les questions venant de ce bot : sa configuration "
            "côté serveur est incomplète. Signale-le sur le canal support — ça ne se règle pas en "
            "réessayant."
        ),
        "ask.error.no_thread": (
            "Je n'ai pas pu ouvrir de fil pour cette question — il me manque probablement la "
            "permission « Créer des fils publics ». Voici quand même la réponse."
        ),
        # Not an upstream failure: a bug on this side. It still gets a sentence, because the
        # alternative is a « le bot réfléchit » qui ne se résout jamais.
        "ask.error.unexpected": (
            "Quelque chose s'est mal passé de mon côté et je n'ai pas pu terminer cette réponse. "
            "Réessaie ; si ça se reproduit, signale-le sur le canal support."
        ),
        # --- local quota --------------------------------------------------------------------
        "quota.user-window": (
            "Tu as posé plusieurs questions coup sur coup. Réessaie {reset_relative} (vers {reset_time})."
        ),
        "quota.user-day": (
            "Tu as atteint ta limite de {limit} questions pour aujourd'hui. Elle se remet à zéro "
            "{reset_relative} (à {reset_time})."
        ),
        "quota.global-day": (
            "Le bot a atteint sa limite de {limit} questions pour aujourd'hui — elle protège le "
            "quota gratuit que partagent aussi le site et la ligne de commande. Elle se remet à "
            "zéro {reset_relative} (à {reset_time})."
        ),
        "quota.degraded": (
            "Le bot ne peut plus tenir ses compteurs à jour, il répond donc au ralenti par sécurité. "
            "Réessaie {reset_relative} (vers {reset_time})."
        ),
        "quota.degraded-day": (
            "Le bot ne peut plus tenir ses compteurs à jour : il s'est donc limité à {limit} "
            "questions pour aujourd'hui, par sécurité. Ça se remet à zéro {reset_relative} (à "
            "{reset_time}) — et signale-le sur le canal support, ça ne se répare pas tout seul."
        ),
        # --- /bug, the deterministic intake --------------------------------------------------
        "bug.received": "📥 Rapport reçu : **{title}**",
        "bug.facts": ("-# Version déclarée : {version} · Composant : {component}\n-# Dépôt consulté : {revision}"),
        "bug.located": "🔎 **Localisé dans le code** (d'après la trace, sans interprétation) :",
        "bug.location": "- `{path}:{line}`",
        "bug.in_function": "dans `{function}`",
        "bug.callers": "  ↳ {count} appel(s) : {listed}",
        "bug.not_located": (
            "🔎 Aucune trace d'erreur exploitable dans ce rapport : rien n'a été localisé dans le "
            "code. Ce n'est pas bloquant, ça retire juste une section."
        ),
        "bug.attached": "📎 {count} fichier(s) préparé(s) pour être joints au ticket.",
        "bug.notes": "⚠️ **Ce qui manque, et pourquoi** :",
        "bug.next": ("-# Rien n'a encore été publié : cette étape prépare le ticket, elle ne l'ouvre pas."),
        "bug.error.unexpected": (
            "Quelque chose s'est mal passé de mon côté pendant la préparation de ce rapport. "
            "Réessaie ; si ça se reproduit, signale-le sur le canal support."
        ),
        "bug.error.no_checkout": (
            "Je ne peux pas préparer de rapport pour le moment : ma copie du dépôt est "
            "indisponible. Signale-le sur le canal support — ça ne se règle pas en réessayant."
        ),
    },
    "en": {
        # --- the exchange -------------------------------------------------------------------
        "ask.header": "**{user}** asks: {question}",
        "ask.thinking": "_Looking through the documentation…_",
        "ask.streaming": "_▌_",
        "ask.thread_name": "❓ {topic}",
        "ask.sources": "-# 📄 Sources: {links}",
        "ask.no_sources": (
            "-# ❔ No documentation page was cited: the question may be outside what the "
            "documentation covers. Where to get help: [Getting help]({support_url})"
        ),
        "ask.disclaimer": (
            "-# Answered from the VEAF documentation; it can be wrong or out of date. Correct it in "
            "this thread if it is."
        ),
        "ask.truncated": "-# ✂️ Answer truncated: it was longer than a Discord message can carry.",
        # --- upstream failures --------------------------------------------------------------
        "ask.error.unavailable": (
            "I cannot reach the documentation assistant right now. Try again in a few minutes; if it "
            "lasts, say so on the support channel."
        ),
        "ask.error.rate_limited": (
            "The documentation assistant is taking too many questions right now. Try again in a few minutes."
        ),
        "ask.error.timeout": (
            "The documentation assistant took too long to answer. Try again; if it happens twice, "
            "ask on the support channel."
        ),
        "ask.error.empty": (
            "The documentation assistant returned nothing at all. Try again with a rephrased question."
        ),
        # Not a user error and not retryable: the Worker refuses this bot until its secret is
        # configured server-side. Saying "try again" would be a lie, so it says who can fix it.
        "ask.error.forbidden": (
            "The documentation assistant is refusing questions from this bot: its server-side "
            "configuration is incomplete. Report it on the support channel — retrying will not "
            "help."
        ),
        "ask.error.no_thread": (
            "I could not open a thread for this question — I am probably missing the "
            '"Create Public Threads" permission. Here is the answer anyway.'
        ),
        # Not an upstream failure: a bug on this side. It still gets a sentence, because the
        # alternative is a "the bot is thinking" that never resolves.
        "ask.error.unexpected": (
            "Something went wrong on my side and I could not finish this answer. Try again; if it "
            "happens twice, say so on the support channel."
        ),
        # --- local quota --------------------------------------------------------------------
        "quota.user-window": (
            "You asked several questions in a row. Try again {reset_relative} (around {reset_time})."
        ),
        "quota.user-day": (
            "You have reached your limit of {limit} questions for today. It resets {reset_relative} (at {reset_time})."
        ),
        "quota.global-day": (
            "The bot has reached its limit of {limit} questions for today — it protects the free "
            "quota the website and the command line share. It resets {reset_relative} (at "
            "{reset_time})."
        ),
        "quota.degraded": (
            "The bot can no longer keep its counters, so it is answering at a reduced rate as a "
            "precaution. Try again {reset_relative} (around {reset_time})."
        ),
        "quota.degraded-day": (
            "The bot can no longer keep its counters, so it has held itself to {limit} questions for "
            "today as a precaution. It resets {reset_relative} (at {reset_time}) — and please report "
            "it on the support channel, this one does not fix itself."
        ),
        # --- /bug, the deterministic intake --------------------------------------------------
        "bug.received": "📥 Report received: **{title}**",
        "bug.facts": ("-# Claimed version: {version} · Component: {component}\n-# Repository consulted: {revision}"),
        "bug.located": "🔎 **Located in the code** (from the trace, nothing inferred):",
        "bug.location": "- `{path}:{line}`",
        "bug.in_function": "in `{function}`",
        "bug.callers": "  ↳ {count} call site(s): {listed}",
        "bug.not_located": (
            "🔎 No usable error trace in this report, so nothing was located in the code. Not a "
            "blocker — it only removes one section."
        ),
        "bug.attached": "📎 {count} file(s) prepared for the issue.",
        "bug.notes": "⚠️ **What is missing, and why**:",
        "bug.next": "-# Nothing has been published yet: this step prepares the issue, it does not open it.",
        "bug.error.unexpected": (
            "Something went wrong on my side while preparing this report. Try again; if it happens "
            "again, report it on the support channel."
        ),
        "bug.error.no_checkout": (
            "I cannot prepare a report right now: my copy of the repository is unavailable. Report "
            "it on the support channel — retrying will not help."
        ),
    },
}

#: Placeholder names used by a template, e.g. ``{"limit", "reset_time"}``.
_PLACEHOLDER_RE: Final = re.compile(r"\{(\w+)\}")


def normalize_language(locale: str | None) -> str:
    """Reduce a Discord locale to one of the two documentation languages.

    Discord sends BCP-47-ish tags (``fr``, ``en-GB``, ``pt-BR``). The corpus only exists in French
    and English, and French is the site's default locale, so anything that is not recognisably
    English answers in French.

    Args:
        locale: The locale Discord reported for the interaction, or ``None``.

    Returns:
        ``"fr"`` or ``"en"``.
    """
    tag = (locale or "").strip().lower()
    return "en" if tag.split("-", 1)[0] == "en" else DEFAULT_LANGUAGE


def text(key: str, lang: str, **values: Any) -> str:
    """Return one localized sentence, with its placeholders filled in.

    Args:
        key: Catalogue key, e.g. ``"ask.thinking"``.
        lang: ``"fr"`` or ``"en"``; anything else falls back to :data:`DEFAULT_LANGUAGE`.
        **values: Placeholder values.

    Returns:
        The rendered sentence.

    Raises:
        KeyError: When *key* is not in the catalogue. Deliberately loud: a missing key is a bug to
            fix at the first run, not a blank the user has to interpret.
    """
    catalogue = _TEXTS.get(lang) or _TEXTS[DEFAULT_LANGUAGE]
    return catalogue[key].format(**values)


def placeholders(key: str, lang: str) -> frozenset[str]:
    """Return the placeholder names a template uses.

    Args:
        key: Catalogue key.
        lang: Catalogue language.

    Returns:
        The names between braces in the template.
    """
    return frozenset(_PLACEHOLDER_RE.findall(_TEXTS[lang][key]))


def keys(lang: str) -> frozenset[str]:
    """Return every key of one catalogue.

    Args:
        lang: Catalogue language.

    Returns:
        The catalogue's keys.
    """
    return frozenset(_TEXTS[lang])


def support_page_url(lang: str) -> str:
    """Return the published address of the *Getting help* page.

    Args:
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The page URL on the documentation site.
    """
    return f"{DOC_SITE_BASE}/{'en/' if lang == 'en' else ''}SUPPORT/"
