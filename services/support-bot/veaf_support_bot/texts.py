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

#: The repository itself. Here rather than beside one of its callers: both flows link it — the
#: bug intake to its issue form, the suggestion flow to the feature request one — and neither of
#: those two modules can import the other.
REPOSITORY_URL: Final = "https://github.com/VEAF/VEAF-Mission-Creation-Tools"

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
        "bug.error.unexpected": (
            "Quelque chose s'est mal passé de mon côté pendant la préparation de ce rapport. "
            "Réessaie ; si ça se reproduit, signale-le sur le canal support."
        ),
        "bug.error.no_checkout": (
            "Je ne peux pas préparer de rapport pour le moment : ma copie du dépôt est "
            "indisponible. Signale-le sur le canal support — ça ne se règle pas en réessayant."
        ),
        # --- ticket 03, l'antériorité : proposée avec sa preuve, jamais appliquée -------------
        "priorart.checked": "-# 🔍 {checked}",
        "priorart.duplicate": (
            "🔁 **C'est peut-être déjà signalé.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "Si c'est bien le même problème, ton observation y sera ajoutée plutôt que d'ouvrir un "
            "second ticket. Si ce n'est pas le même, dis-le : ton rapport continue son chemin."
        ),
        "priorart.fixed": (
            "✅ **C'est peut-être déjà corrigé.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "Corrigé en **{version}** : si tu es sur une version antérieure, mets à jour et le "
            "problème devrait disparaître. Si tu l'as déjà, dis-le : ton rapport continue."
        ),
        "priorart.fixed_no_version": (
            "✅ **C'est peut-être déjà corrigé.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "Le ticket est fermé, mais le changelog ne cite aucune version : à vérifier. Si ton "
            "problème persiste, dis-le et ton rapport continue."
        ),
        "priorart.in_progress": (
            "🛠️ **Un lot travaille peut-être déjà dessus.** {reference} — *{title}*\n{evidence}\n"
            "{url}\nSi c'est bien ça, il n'y a rien à ouvrir. Sinon, dis-le et ton rapport continue."
        ),
        "priorart.rejected": "-# 👍 Compris, c'est autre chose : le rapport continue.",
        # --- ticket 05, le dépôt du ticket ---------------------------------------------------
        "filed.created": "✅ Ticket ouvert : {url}",
        "filed.reused": "✅ Ce rapport avait déjà été déposé : {url} (rien n'a été ouvert deux fois).",
        "filed.commented": "💬 Ton observation a été ajoutée au ticket existant : {url}",
        "filed.notes": "-# ⚠️ {notes}",
        "filed.error": (
            "❌ **Je n'ai pas réussi à déposer ce ticket.** Raison : {reason}\n"
            "Ton rapport n'est pas perdu — il est résumé ci-dessus. Signale-le sur le canal support, "
            "ou ouvre le ticket toi-même : {issue_url}"
        ),
        "filed.disabled": (
            "-# 📝 Aucun ticket n'a été ouvert : ce bot n'a pas encore d'identité GitHub configurée. "
            "Le rapport ci-dessus est complet et peut être copié tel quel dans un ticket."
        ),
        # --- ticket 04, l'aperçu et le clic qui dépose ----------------------------------------
        "draft.header": (
            "📋 **Voici le ticket tel qu'il sera déposé**, au nom du bot et pas au tien. "
            "Rien n'est publié tant que tu n'as pas cliqué."
        ),
        "draft.header_comment": (
            "📋 **Voici ce qui sera ajouté au ticket existant**, au nom du bot et pas au tien. "
            "Rien n'est publié tant que tu n'as pas cliqué."
        ),
        "draft.title": "**Titre :** {title}",
        "draft.truncated": (
            "-# ✂️ Aperçu coupé ici : {lines} lignes de plus ({chars} caractères) partiront dans "
            "le ticket. Rien n'est retiré du ticket lui-même."
        ),
        "draft.button.file": "Déposer le ticket",
        "draft.button.edit": "Corriger",
        "draft.button.cancel": "Annuler",
        "draft.cancelled": "🗑️ Annulé : rien n'a été déposé, et rien n'est conservé.",
        "draft.expired": (
            "⏳ **Cet aperçu a expiré** et rien n'a été déposé. Relance `/bug` quand tu veux — un "
            "brouillon abandonné ne devient jamais un ticket tout seul."
        ),
        "draft.editing": (
            "✏️ Le formulaire s'est rouvert avec tes réponses. Rien n'a été déposé : le nouvel "
            "aperçu remplacera celui-ci."
        ),
        "draft.no_consent": (
            "-# 📝 Aucun ticket n'a été ouvert : je n'ai personne à qui demander le clic. Un ticket "
            "n'est jamais déposé sans que son auteur l'ait vu — signale-le sur le canal support."
        ),
        # --- ticket 08, l'hypothèse automatique -------------------------------------------
        "hypothesis.added": "-# 🤖 Une hypothèse automatique a été ajoutée au ticket, signalée comme une supposition.",
        "hypothesis.absent.not_a_member": (
            "-# 🤖 Pas d'hypothèse automatique : c'est un bonus réservé aux membres VEAF. Ton "
            "rapport, lui, est complet."
        ),
        "hypothesis.absent.ceiling_reached": (
            "-# 🤖 Pas d'hypothèse automatique : le quota du jour est épuisé. Ton rapport, lui, est complet."
        ),
        "hypothesis.absent.model_unavailable": (
            "-# 🤖 Pas d'hypothèse automatique : le modèle n'a pas répondu. Ton rapport, lui, est complet."
        ),
        "hypothesis.absent.empty_answer": (
            "-# 🤖 Pas d'hypothèse automatique : le modèle n'a rien renvoyé d'exploitable. Ton "
            "rapport, lui, est complet."
        ),
        "hypothesis.absent.disabled": "-# 🤖 L'hypothèse automatique est désactivée sur ce déploiement.",
        # --- ticket 06, le retour de l'information vers le fil ------------------------------
        "relay.opened": (
            "🐞 **{title}**\nTicket ouvert : {url}\nC'est ici que je te rapporterai ce qui s'y "
            "passe. Pour ajouter quelque chose, écris dans ce fil : un mainteneur le reportera "
            "sur le ticket (le bot n'écrit pas de Discord vers GitHub)."
        ),
        "relay.thread_name": "🐞 {topic}",
        "relay.comment": "💬 **{author}** a répondu sur le ticket #{issue} ({url}) :",
        "relay.truncated": "-# ✂️ Message tronqué — la suite est sur le ticket : {url}",
        "relay.more": "-# 💬 Il y a d'autres messages sur le ticket, je les rapporterai au prochain passage : {url}",
        "relay.closed": (
            "✅ Le ticket #{issue} est **clos** : {url}\nSi ton problème persiste, dis-le ici — "
            "un mainteneur pourra le rouvrir."
        ),
        "match.button.same": "Oui, c'est ça",
        "match.button.different": "Non, le mien est différent",
        "escalate.button": "Signaler un bug",
        "escalate.happened": (
            "J'ai posé cette question au bot :\n{question}\n\nSa réponse ne règle pas mon problème :\n{answer}"
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
        "bug.error.unexpected": (
            "Something went wrong on my side while preparing this report. Try again; if it happens "
            "again, report it on the support channel."
        ),
        "bug.error.no_checkout": (
            "I cannot prepare a report right now: my copy of the repository is unavailable. Report "
            "it on the support channel — retrying will not help."
        ),
        # --- ticket 03, prior art: proposed with its evidence, never applied ------------------
        "priorart.checked": "-# 🔍 {checked}",
        "priorart.duplicate": (
            "🔁 **This may already be reported.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "If it is the same problem, your observation goes there instead of opening a second "
            "issue. If it is not, say so: your report carries on."
        ),
        "priorart.fixed": (
            "✅ **This may already be fixed.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "Fixed in **{version}**: if you are on an earlier version, update and it should be "
            "gone. If you already have it, say so and your report carries on."
        ),
        "priorart.fixed_no_version": (
            "✅ **This may already be fixed.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "The issue is closed, but the changelog names no version for it — worth checking. If "
            "your problem is still there, say so and your report carries on."
        ),
        "priorart.in_progress": (
            "🛠️ **A lot may already be on it.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "If that is it, there is nothing to open. If not, say so and your report carries on."
        ),
        "priorart.rejected": "-# 👍 Understood, it is something else: the report carries on.",
        # --- ticket 05, filing the issue -----------------------------------------------------
        "filed.created": "✅ Issue opened: {url}",
        "filed.reused": "✅ This report had already been filed: {url} (nothing was opened twice).",
        "filed.commented": "💬 Your observation was added to the existing issue: {url}",
        "filed.notes": "-# ⚠️ {notes}",
        "filed.error": (
            "❌ **I could not file this issue.** Reason: {reason}\n"
            "Your report is not lost — it is summarised above. Report this on the support channel, "
            "or open the issue yourself: {issue_url}"
        ),
        "filed.disabled": (
            "-# 📝 No issue was opened: this bot has no GitHub identity configured yet. The report "
            "above is complete and can be copied into an issue as it stands."
        ),
        # --- ticket 04, the preview and the click that files ----------------------------------
        "draft.header": (
            "📋 **This is the issue as it will be filed**, under the bot's name and not yours. "
            "Nothing is published until you click."
        ),
        "draft.header_comment": (
            "📋 **This is what will be added to the existing issue**, under the bot's name and not "
            "yours. Nothing is published until you click."
        ),
        "draft.title": "**Title:** {title}",
        "draft.truncated": (
            "-# ✂️ Preview cut here: {lines} more lines ({chars} characters) go into the issue. "
            "Nothing is removed from the issue itself."
        ),
        "draft.button.file": "File the issue",
        "draft.button.edit": "Edit",
        "draft.button.cancel": "Cancel",
        "draft.cancelled": "🗑️ Cancelled: nothing was filed, and nothing is kept.",
        "draft.expired": (
            "⏳ **This preview expired** and nothing was filed. Run `/bug` again whenever you want "
            "— an abandoned draft never turns into an issue on its own."
        ),
        "draft.editing": (
            "✏️ The form reopened with your answers. Nothing was filed: the new preview replaces this one."
        ),
        "draft.no_consent": (
            "-# 📝 No issue was opened: there is nobody I can ask for the click. An issue is never "
            "filed without its author having seen it — report this on the support channel."
        ),
        # --- ticket 08, the automatic hypothesis ------------------------------------------
        "hypothesis.added": "-# 🤖 An automatic hypothesis was added to the issue, labelled as a guess.",
        "hypothesis.absent.not_a_member": (
            "-# 🤖 No automatic hypothesis: it is a VEAF members' extra. Your report itself is complete."
        ),
        "hypothesis.absent.ceiling_reached": (
            "-# 🤖 No automatic hypothesis: the day's allowance is spent. Your report itself is complete."
        ),
        "hypothesis.absent.model_unavailable": (
            "-# 🤖 No automatic hypothesis: the model did not answer. Your report itself is complete."
        ),
        "hypothesis.absent.empty_answer": (
            "-# 🤖 No automatic hypothesis: the model returned nothing usable. Your report itself is complete."
        ),
        "hypothesis.absent.disabled": "-# 🤖 The automatic hypothesis is switched off on this deployment.",
        # --- ticket 06, carrying the answer back into the thread ----------------------------
        "relay.opened": (
            "🐞 **{title}**\nIssue opened: {url}\nThis is where I will report what happens on it. "
            "To add something, write in this thread and a maintainer will carry it over (the bot "
            "does not write from Discord to GitHub)."
        ),
        "relay.thread_name": "🐞 {topic}",
        "relay.comment": "💬 **{author}** replied on issue #{issue} ({url}):",
        "relay.truncated": "-# ✂️ Message truncated — the rest is on the issue: {url}",
        "relay.more": "-# 💬 There are more messages on the issue; I will bring them over next round: {url}",
        "relay.closed": (
            "✅ Issue #{issue} is **closed**: {url}\nIf your problem is still there, say so here — "
            "a maintainer can reopen it."
        ),
        "match.button.same": "Yes, that is it",
        "match.button.different": "No, mine is different",
        "escalate.button": "Report a bug",
        "escalate.happened": (
            "I asked the bot this question:\n{question}\n\nIts answer does not solve my problem:\n{answer}"
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
