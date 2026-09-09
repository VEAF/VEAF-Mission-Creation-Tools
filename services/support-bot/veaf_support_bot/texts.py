"""Every sentence the bot says to a user, in both documentation languages.

The service does not reuse ``veaf_libs.i18n``: that layer belongs to the shipped tools, loads its
catalogues from the tools' package tree and is not installed here. What is reused is the rule — a
user-facing string is never built by concatenating fragments in the code, and French and English are
written side by side so one cannot quietly fall behind. ``tests/test_texts.py`` asserts the two
catalogues hold exactly the same keys and the same placeholders.

Two surfaces, and both are here since ticket 01. What the bot **says** follows the asker's own
locale, read off his interaction. What Discord **registers once** — the command descriptions and the
choice names in the component menu — cannot: they exist before any interaction does. Those go through
``app_commands.Translator``, whose table Discord stores per client language, and their keys live in
this same catalogue so the parity test covers them too.

What stays untranslated on purpose is a component's **value**: those are the options of the issue
templates, word for word, and a translated value is a component nobody can filter on.

## One register: the bot says *tu*

French has two ways of addressing somebody and a service that uses both reads as two services. This
one tutoie, everywhere — it is a squadron's Discord, not a bank. Measured 2026-09-07 while the
command descriptions were being written: 29 keys tutoyaient, 12 vouvoyaient, and the formal ones
were the most visible of all, in the command picker. The check is a reading, not a test: a lone
*vous* in a sentence is easy to see, and a rule nobody can state is a rule nobody follows.
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
            "dépassée. Corrige-la dans ce fil si c'est le cas."
        ),
        "ask.truncated": "-# ✂️ Réponse tronquée : elle dépassait ce qu'un message Discord peut porter.",
        "ask.continue": (
            "-# 💬 Une question complémentaire ? Mentionne-moi dans ce fil et je réponds avec ce qui "
            "précède en tête. Chaque relance compte comme une question."
        ),
        "ask.followup.forgotten": (
            "Je ne retrouve plus ce dont parlait ce fil — il est peut-être trop ancien, ou le service "
            "a été redémarré depuis. Repose la question avec `/ask` et j'ouvre un nouveau fil."
        ),
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
        "suggest.named_issue": (
            "🔎 **Ta demande ressemble à un ticket déjà ouvert :**\n"
            "> [#{issue} — {title}]({url})\n\n"
            "Ce rapprochement vient d'une lecture du sens, pas d'une comparaison de mots — deux "
            "personnes ne décrivent jamais le même besoin avec le même vocabulaire. Ouvre-le et "
            "dis-moi : c'est bien la même chose, ou pas ?"
        ),
        "suggest.no_title": "(sans titre)",
        "suggest.settled.named_issue": (
            "Entendu, rien de nouveau n'est ouvert : le ticket #{issue} porte déjà ce besoin."
        ),
        # --- ticket 01 : ce que les formulaires *montrent*, et pas seulement ce qu'ils disent ---
        # Ce que Discord enregistre une fois pour toutes : les descriptions de commandes et les
        # noms d'options, tels que le sélecteur les montre. C'est la première chose qu'un mission
        # maker voit du bot, avant même d'avoir tapé quoi que ce soit — et la seule surface qu'un
        # correctif par interaction ne peut pas atteindre, puisqu'elle existe avant toute
        # interaction. Traduites via `app_commands.Translator`, dont Discord stocke la table.
        "command.ask.description": "Poser une question sur la documentation des outils VEAF",
        "command.ask.question": "Que veux-tu savoir ?",
        "command.bug.description": "Signaler un bug — un formulaire court, et les fichiers que tu as",
        "command.bug.log": "Ton veaf-tools.log ou dcs.log, si tu en as un",
        "command.bug.mission": "Le .miz sur lequel le problème se produit",
        "command.bug.extra": "Autre chose : un mission.yaml, un fichier de configuration",
        "command.suggest.description": "Proposer une amélioration — confrontée à ce qui existe déjà",
        "command.suggest.component": "De quelle partie de la chaîne d'outils il s'agit",
        # Le service traduisait chaque phrase qu'il prononce et aucun libellé qu'il affiche. David a
        # basculé son client Discord en français pour vérifier, le 2026-09-07 : rien n'a bougé. Le
        # français est la langue par défaut du service, et sa surface la plus visible était
        # entièrement anglaise.
        "form.bug.title": "Signaler un bug",
        "form.bug.summary": "En une ligne, qu'est-ce qui ne va pas ?",
        "form.bug.happened": "Que s'est-il passé ?",
        "form.bug.expected": "À quoi t'attendais-tu ?",
        "form.bug.steps": "Comment le reproduire",
        "form.bug.doctor": "Colle la sortie de : veaf-tools doctor",
        "form.suggest.title": "Proposer une amélioration",
        "form.suggest.summary": "En une ligne, que souhaiterais-tu ?",
        "form.suggest.problem": "Quel problème cela résout-il ?",
        "form.suggest.problem.placeholder": "Ce qui est pénible aujourd'hui, et à quelle fréquence ça te coûte",
        "form.suggest.solution": "Que voudrais-tu qu'il se passe ?",
        "form.suggest.alternatives": "As-tu envisagé autre chose ?",
        "form.suggest.context": "Autre chose ? Exemples, liens",
        # --- ticket 07 : la seconde voix, consignée sur le ticket existant --------------------
        # Une demande est souhaitée ou non, et une seule personne tranche. *Quelqu'un d'autre qui
        # demande la même chose* est le seul signal de priorité qu'une demande portera jamais, et il
        # était jeté : on disait à l'auteur que le sujet est suivi ailleurs, et rien nulle part
        # n'enregistrait qu'une personne de plus en avait besoin.
        "suggest.observation.header": (
            "💬 **Voici ce qui serait ajouté au ticket**, sous ton nom Discord. Rien n'est publié "
            "tant que tu n'as pas cliqué."
        ),
        "suggest.observation.title": "Observation à ajouter au ticket #{issue}",
        "suggest.observation.body": (
            "**{asker}** a demandé la même chose sur le Discord VEAF. Le besoin, dans ses mots :\n\n"
            "{problem}\n\n"
            "-# Ajouté automatiquement par le bot de support VEAF, avec son accord explicite."
        ),
        "suggest.observation.recorded": "✅ C'est ajouté au ticket #{issue} : une voix de plus y est consignée.",
        "suggest.observation.declined": "D'accord, rien n'a été publié sur le ticket.",
        "suggest.observation.failed": (
            "Je n'ai pas réussi à écrire sur le ticket #{issue}. Rien n'est perdu de ton côté — tu "
            "peux commenter toi-même si tu as un compte GitHub."
        ),
        # --- ce qu'une pièce jointe devient dans le ticket ------------------------------------
        # Écrit dans le ticket, donc dans la langue du rapporteur. Les deux comptes ci-dessous
        # portent sur des choses différentes — les enregistrements que le profil garde, et les
        # lignes que l'extrait affiche — et se lisaient comme une contradiction quand ils se
        # suivaient sans être nommés (relevé sur #929 : « 1202 retenus » puis « 48 entrées ... 1202
        # retenues »).
        "attachment.log_digest": (
            "Journal réduit par le profil *Diagnostic* : **{kept}** enregistrements retenus sur "
            "{total}, dont {uncatalogued} sans correspondance au catalogue. Le décompte entre "
            "crochets plus bas porte sur les lignes **affichées dans l'extrait**, pas sur les "
            "enregistrements retenus."
        ),
        "attachment.too_large": (
            "{size} octets, au-delà des {limit} qu'un ticket peut porter — voir l'extrait ci-dessus"
        ),
        "attachment.binary": "fichier binaire ({kind}), qu'un ticket ne peut pas porter",
        "attachment.unreadable": "n'a pas pu être relu ({error})",
        "attachment.unsupported": "type de fichier non accepté ({suffix})",
        "attachment.too_large_for_the_limit": "trop volumineux ({size} ; la limite est {limit})",
        "attachment.budget_spent": "le rapport a déjà atteint {total} de fichiers",
        "attachment.over_what_is_left": "plus volumineux que les {left} restants pour ce rapport",
        "attachment.download_failed": "n'a pas pu être téléchargé ({error})",
        "attachment.not_summarised": "joint, mais non résumé : {error}",
        "attachment.file_unreadable": "joint, mais illisible : {error}",
        # --- l'antériorité telle qu'elle est consignée dans le ticket ------------------------
        # Trois réponses possibles et non deux : « il a dit que ce n'est pas pareil » est un avis
        # qu'un lecteur peut peser, « personne n'a répondu » n'en est pas un. Le protocole ne
        # renvoyait qu'un booléen, et les deux arrivaient ici comme la même chose.
        "priorart.proposed.duplicate": "un ticket ouvert proche a été proposé",
        "priorart.proposed.fixed": "un ticket déjà fermé a été proposé",
        "priorart.proposed.in_progress": "un chantier en cours a été proposé",
        "priorart.answer.same": "et le rapporteur l'a reconnu comme le sien",
        "priorart.answer.different": "et le rapporteur a dit que le sien est différent",
        "priorart.answer.unanswered": "et personne n'a répondu — ni accord, ni refus",
        "priorart.closest": "Correspondance la plus proche : {proposed}, {answer}.",
        "priorart.also_considered": "également envisagé :",
        "priorart.deterministic": "_Balayage déterministe : appariement de mots, aucun modèle._",
        "withheld.mission": (
            "résumée : seuls les champs listés plus haut sont publiés — ni les noms de groupes, "
            "ni le briefing, ni les déclencheurs"
        ),
        "withheld.log": "réduit par le profil *Diagnostic* : seul l'extrait ci-dessus est publié",
        "withheld.text": "cité en partie : seul l'extrait ci-dessus est publié",
        "withheld.archive": "listé seulement : le contenu des fichiers n'est pas publié",
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
        "filed.followup": "💬 Le suivi se passe ici : {url}",
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
        "relay.reopened": (
            "🔄 Le ticket #{issue} a été **rouvert** : {url}\nJe rapporte ici ce qui s'y est dit depuis."
        ),
        "match.button.same": "Oui, c'est ça",
        "match.button.different": "Non, le mien est différent",
        "escalate.button": "Signaler un bug",
        "escalate.happened": (
            "J'ai posé cette question au bot :\n{question}\n\nSa réponse ne règle pas mon problème :\n{answer}"
        ),
        # --- /suggest, l'idee confrontee a ce qui existe deja ---------------------------------
        # --- /suggest : l'antériorité, dite sans promettre ce que ce flux ne fait pas ---------
        "suggest.priorart.duplicate": (
            "🔁 **C'est peut-être déjà demandé.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "Si c'est bien la même demande, **aucun ticket ne sera ouvert** : le sujet est déjà "
            "suivi là-bas, et tu peux commenter ce ticket directement pour ajouter ton avis. Si ce "
            "n'est pas la même, dis-le : ta suggestion continue son chemin."
        ),
        "suggest.priorart.in_progress": (
            "🔁 **C'est peut-être déjà prévu.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "Si c'est bien ça, **aucun ticket ne sera ouvert** : le travail est déjà décrit là. Si "
            "ce n'est pas la même chose, dis-le : ta suggestion continue son chemin."
        ),
        "suggest.priorart.fixed": (
            "✅ **C'est peut-être déjà fait.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "Livré dans la **{version}** : si tu es sur une version antérieure, mets à jour. Si ce "
            "n'est pas ça, dis-le : ta suggestion continue son chemin."
        ),
        "suggest.priorart.fixed_no_version": (
            "✅ **C'est peut-être déjà fait.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "Le ticket est fermé, sans version identifiée. Si ce n'est pas ça, dis-le : ta "
            "suggestion continue son chemin."
        ),
        "suggest.missing": (
            "Il manque des champs obligatoires ({fields}). Relance `/suggest` : sans le problème "
            "que tu veux résoudre, personne ne peut arbitrer la demande."
        ),
        "suggest.documentation.question": (
            "\U0001f4d6 **La documentation semble déjà répondre à ta demande.** Voici ce qu'elle dit :\n\n"
            "{answer}\n\n"
            "Est-ce que ça répond à ce que tu voulais ? Si non, dis-le : ta suggestion continue son chemin."
        ),
        "suggest.documentation.pages": "-# \U0001f4c4 Pages citees : {links}",
        "suggest.settled.documentation": (
            "\u2705 Parfait — rien n'a été ouvert. Si la page est difficile à trouver, dis-le sur le "
            "canal support : c'est la documentation qu'on corrigera."
        ),
        "suggest.settled.prior_art": "\u2705 Rien n'a été ouvert : le sujet est déjà suivi là-bas.",
        "suggest.filed.reused": "\u2705 Cette suggestion avait déjà été déposée : {url} (rien n'a été ouvert deux fois).",
        "suggest.thread.name": "\U0001f4a1 {topic}",
        "suggest.thread.failed": (
            "\u274c Le d\u00e9p\u00f4t du ticket a \u00e9chou\u00e9 : ce fil reste ouvert mais ne renvoie \u00e0 aucun "
            "ticket. La demande n'est pas perdue \u2014 elle a \u00e9t\u00e9 montr\u00e9e \u00e0 son auteur, qui peut "
            "relancer `/suggest`."
        ),
        "suggest.error.after_filing": (
            "\u26a0\ufe0f Le ticket **a bien \u00e9t\u00e9 ouvert**, mais quelque chose a cass\u00e9 juste apr\u00e8s. Ne "
            "relance pas `/suggest` : tu ouvrirais un doublon. Regarde le fil ci-dessus, ou dis-le sur "
            "le canal support."
        ),
        "suggest.thread.opening": (
            "**{title}**\nSuggestion enregistrée : {url}\n"
            "-# Les réponses des mainteneurs sur ce ticket seront rapportées ici."
        ),
        "suggest.error.unexpected": (
            "\u274c Quelque chose a cassé pendant la préparation de ta suggestion. Rien n'a été "
            "ouvert. Réessaie, et si ça se reproduit dis-le sur le canal support."
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
        "ask.continue": (
            "-# 💬 A follow-up? Mention me in this thread and I answer with what came before in mind. "
            "Each follow-up counts as one question."
        ),
        "ask.followup.forgotten": (
            "I no longer have what this thread was about — it may be too old, or the service was "
            "restarted since. Ask again with `/ask` and I will open a new thread."
        ),
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
        "suggest.named_issue": (
            "🔎 **Your request looks like an issue that is already open:**\n"
            "> [#{issue} — {title}]({url})\n\n"
            "That match comes from reading the meaning, not from comparing words — no two people "
            "describe the same need with the same vocabulary. Open it and tell me: is it the same "
            "thing, or not?"
        ),
        "suggest.no_title": "(untitled)",
        "suggest.settled.named_issue": ("Understood, nothing new is opened: issue #{issue} already carries this need."),
        # --- ticket 01: what the forms *show*, and not only what they say --------------------
        "command.ask.description": "Ask a question about the VEAF Mission Creation Tools documentation",
        "command.ask.question": "What do you want to know?",
        "command.bug.description": "Report a bug — a short form, and the files you have",
        "command.bug.log": "Your veaf-tools.log or dcs.log, if you have one",
        "command.bug.mission": "The .miz the problem happens on",
        "command.bug.extra": "Anything else: a mission.yaml, a configuration file",
        "command.suggest.description": "Suggest an improvement — checked against what already exists",
        "command.suggest.component": "Which part of the toolchain this is about",
        "form.bug.title": "Report a bug",
        "form.bug.summary": "In one line, what is wrong?",
        "form.bug.happened": "What happened?",
        "form.bug.expected": "What did you expect?",
        "form.bug.steps": "Steps to reproduce",
        "form.bug.doctor": "Paste the output of: veaf-tools doctor",
        "form.suggest.title": "Suggest an improvement",
        "form.suggest.summary": "In one line, what would you like?",
        "form.suggest.problem": "What problem does this solve?",
        "form.suggest.problem.placeholder": "What is painful today, and how often it costs you",
        "form.suggest.solution": "What would you like to happen?",
        "form.suggest.alternatives": "Anything else you considered?",
        "form.suggest.context": "Anything else? Examples, links",
        # --- ticket 07: the second voice, recorded on the existing issue ---------------------
        "suggest.observation.header": (
            "💬 **This is what would be added to the issue**, under your Discord name. Nothing is "
            "published until you click."
        ),
        "suggest.observation.title": "Observation to add to issue #{issue}",
        "suggest.observation.body": (
            "**{asker}** asked for the same thing on the VEAF Discord. The need, in his words:\n\n"
            "{problem}\n\n"
            "-# Added automatically by the VEAF support bot, with his explicit consent."
        ),
        "suggest.observation.recorded": "✅ Added to issue #{issue}: one more voice is recorded there.",
        "suggest.observation.declined": "All right, nothing was published on the issue.",
        "suggest.observation.failed": (
            "I could not write to issue #{issue}. Nothing is lost on your side — you can comment "
            "yourself if you have a GitHub account."
        ),
        # --- what an attachment becomes in the issue ------------------------------------------
        "attachment.log_digest": (
            "Log reduced by the *Diagnostic* profile: **{kept}** records kept out of {total}, "
            "{uncatalogued} of them matching no catalogue entry. The bracketed count further down "
            "measures the lines **shown in the excerpt**, not the records kept."
        ),
        "attachment.too_large": "{size} bytes, past the {limit} an issue can carry — see the excerpt above",
        "attachment.binary": "binary file ({kind}), which an issue cannot hold",
        "attachment.unreadable": "could not be read back ({error})",
        "attachment.unsupported": "unsupported file type ({suffix})",
        "attachment.too_large_for_the_limit": "too large ({size}; the limit is {limit})",
        "attachment.budget_spent": "the report already reached {total} of files",
        "attachment.over_what_is_left": "larger than the {left} left for this report",
        "attachment.download_failed": "could not be downloaded ({error})",
        "attachment.not_summarised": "attached, but not summarised: {error}",
        "attachment.file_unreadable": "attached, but unreadable: {error}",
        # --- prior art, as the issue records it ----------------------------------------------
        "priorart.proposed.duplicate": "a similar open issue was proposed",
        "priorart.proposed.fixed": "a closed issue was proposed",
        "priorart.proposed.in_progress": "existing work was proposed",
        "priorart.answer.same": "and the reporter recognised it as his own",
        "priorart.answer.different": "and the reporter said his is different",
        "priorart.answer.unanswered": "and nobody answered — neither agreement nor refusal",
        "priorart.closest": "Closest match: {proposed}, {answer}.",
        "priorart.also_considered": "also considered:",
        "priorart.deterministic": "_Deterministic sweep: word matching, no model._",
        "withheld.mission": (
            "summarised: only the fields listed above are published — no group names, no briefing, no triggers"
        ),
        "withheld.log": "reduced by the *Diagnostic* profile: only the excerpt above is published",
        "withheld.text": "quoted in part: only the excerpt above is published",
        "withheld.archive": "listed only: the files' contents are not published",
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
        "filed.followup": "💬 The follow-up happens here: {url}",
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
        "relay.reopened": (
            "🔄 Issue #{issue} has been **reopened**: {url}\nI am bringing over what has been said on it since."
        ),
        "match.button.same": "Yes, that is it",
        "match.button.different": "No, mine is different",
        "escalate.button": "Report a bug",
        "escalate.happened": (
            "I asked the bot this question:\n{question}\n\nIts answer does not solve my problem:\n{answer}"
        ),
        # --- /suggest, the idea weighed against what already exists ---------------------------
        # --- /suggest: prior art, said without promising what this flow does not do -----------
        "suggest.priorart.duplicate": (
            "🔁 **This may already be asked for.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "If it is the same request, **no issue will be opened**: the subject is already tracked "
            "there, and you can comment on that issue yourself to add your view. If it is not the "
            "same, say so: your suggestion carries on."
        ),
        "suggest.priorart.in_progress": (
            "🔁 **This may already be planned.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "If that is it, **no issue will be opened**: the work is described there already. If it "
            "is not the same thing, say so: your suggestion carries on."
        ),
        "suggest.priorart.fixed": (
            "✅ **This may already be done.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "Shipped in **{version}**: if you are on an earlier version, update. If that is not it, "
            "say so: your suggestion carries on."
        ),
        "suggest.priorart.fixed_no_version": (
            "✅ **This may already be done.** {reference} — *{title}*\n{evidence}\n{url}\n"
            "The issue is closed, with no version identified. If that is not it, say so: your "
            "suggestion carries on."
        ),
        "suggest.missing": (
            "Required fields are missing ({fields}). Run `/suggest` again: without the problem you "
            "are trying to solve, nobody can weigh the request."
        ),
        "suggest.documentation.question": (
            "\U0001f4d6 **The documentation seems to answer this already.** Here is what it says:\n\n"
            "{answer}\n\n"
            "Is that what you were after? If not, say so: your suggestion carries on."
        ),
        "suggest.documentation.pages": "-# \U0001f4c4 Pages cited: {links}",
        "suggest.settled.documentation": (
            "\u2705 Good — nothing was opened. If that page is hard to find, say so on the support "
            "channel: the documentation is what we will fix."
        ),
        "suggest.settled.prior_art": "\u2705 Nothing was opened: the subject is already tracked there.",
        "suggest.filed.reused": "\u2705 This suggestion had already been filed: {url} (nothing was opened twice).",
        "suggest.thread.name": "\U0001f4a1 {topic}",
        "suggest.thread.failed": (
            "\u274c Filing the issue failed: this thread stays open but points at no issue. The "
            "request is not lost \u2014 it was shown to the person who made it, and `/suggest` can be "
            "run again."
        ),
        "suggest.error.after_filing": (
            "\u26a0\ufe0f The issue **was opened**, but something broke right after. Do not run "
            "`/suggest` again: you would open a duplicate. Check the thread above, or say so on the "
            "support channel."
        ),
        "suggest.thread.opening": (
            "**{title}**\nSuggestion recorded: {url}\n-# Maintainers' answers on that issue will be carried back here."
        ),
        "suggest.error.unexpected": (
            "\u274c Something broke while preparing your suggestion. Nothing was opened. Try again, "
            "and if it happens twice say so on the support channel."
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
