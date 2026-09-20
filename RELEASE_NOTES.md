# VEAF Mission Creation Tools — 6.23.1

**Cette version ne change rien à vos missions — elle change ce que les outils vous expliquent.**

**Merci à Tripack**, dont le retour est à l'origine de tout ce qui suit. Il a construit sa mission et
reçu ceci :

> Camp 'red' : les pays **[68]** possèdent des unités mais ne figurent pas dans coalitions.red

Il n'avait aucun moyen de savoir que 68 est l'URSS. Il a supposé que ses objets statiques neutres
étaient en cause — ils ne l'étaient pas — et a fini par demander à l'assistant de documentation, qui
lui a conseillé de modifier une clé que `mission.yaml` ne contient pas.

Trois choses étaient cassées d'un coup : le message ne donnait pas de quoi agir, la documentation ne
disait rien de ce cas, et l'assistant inventait plutôt que d'admettre qu'il ne savait pas. Tout ce
qui suit vient de là.

C'est le genre de retour qui vaut de l'or : signaler qu'un message est incompréhensible est beaucoup
plus utile qu'on ne le croit, et personne d'autre que celui qui le reçoit ne peut le dire.

> **Aucun script Lua n'a changé.** Rien ne se comporte différemment en vol. Reconstruire vos missions
> avec cette version est utile, mais rien ne presse.

---

## 📖 Une nouvelle section de documentation : « Les messages du build »

La question la plus fréquente que reçoit le projet est *« le build a affiché ça, je fais quoi ? »*.
Les outils peuvent afficher une centaine de messages différents ; **un seul** avait son texte quelque
part dans la documentation.

Six pages neuves, en français et en anglais, dans le menu **Créateur de Mission** :

| Page | Ce qu'elle couvre |
|---|---|
| **Coalitions et pays** | l'écran *CHANGING COALITIONS*, et la table complète des pays DCS |
| **Références manquantes** | un groupe, une zone, une unité ou un aérodrome que `mission.yaml` nomme et que la mission n'a pas |
| **Les fichiers Lua du dossier** | pourquoi le build parle d'un `.lua` « inattendu » dans `src/scripts/` — page née d'un autre signalement de Tripack |
| **Routes et tables** | les routes que l'éditeur DCS refuse d'enregistrer, et les tables trouées |
| **Modules et scripts communautaires** | CTLD, TUM, profils de conversion, sections dépréciées |

Chaque message y est traité de la même façon : **ce qu'il veut dire dans l'éditeur DCS**, comment
retrouver la situation, les issues possibles avec leur compromis — et surtout **ce qu'il ne veut
pas dire**, parce que c'est là que part le temps.

La page d'accueil de la section répond d'abord à la question que tout le monde se pose : *est-ce que
le build a échoué ?* La réponse est presque toujours non, et un message jaune ne vous empêche pas de
voler.

---

## 🔢 Les messages nomment les pays au lieu de vous donner un numéro

Le message d'origine devient :

> Camp 'red' : les pays **[68 (USSR)]** possèdent des unités mais ne figurent pas dans
> coalitions.red (**[0 (Russia), 81 (Combined Joint Task Forces Red)]**)

**Les deux listes** sont nommées, pas seulement celle qui manque : choisir entre *ajouter le pays au
camp* et *réaffecter les objets à un pays déjà présent* suppose de comparer les deux. Le message
précise aussi d'écrire **le nombre seul** — `68`, jamais `68 (USSR)`.

Un identifiant que DCS ne connaît pas reste affiché tel quel, sans nom. C'est déjà une information :
la mission contient un pays qui n'existe pas dans cette version du jeu.

---

## 🤖 L'assistant de documentation sait dire qu'il ne sait pas

Il répondait à partir de ses six meilleurs résultats de recherche, **sans aucun seuil de
pertinence**. Quelle que soit la question — y compris hors sujet — six extraits lui arrivaient
présentés comme « la documentation pertinente », avec la consigne de répondre à partir d'eux. La
consigne « si la réponse n'y est pas, dis-le » ne pouvait pas s'appliquer : rien ne lui signalait
jamais que les extraits étaient mauvais.

Désormais il écarte les passages trop éloignés, on lui dit que les extraits sont des résultats de
recherche qui peuvent avoir manqué leur cible, et il vous renvoie vers le Discord plutôt que
d'inventer.

**Et il répondait depuis un index figé début août.** Le mécanisme qui le reconstruit signalait un
succès à chaque passage sans jamais rien envoyer : six semaines de documentation lui étaient
invisibles. C'est réparé, et le mécanisme vérifie maintenant ce qu'il a écrit au lieu de l'annoncer.

---

## Comment mettre à jour

1. Téléchargez `veaf-tools.exe` ci-dessous.
2. Reconstruisez vos missions.

Rien d'autre : pas de migration, pas de changement de configuration, et aucun réglage à revoir.

---

## Un message vous laisse perplexe ?

Dites-le. Les six pages ci-dessus existent parce que quelqu'un a signalé qu'il ne comprenait pas ce
qu'on lui affichait — et il reste une bonne soixantaine de messages que la documentation ne couvre
pas encore. Le canal `#support` du [Discord VEAF](https://www.veaf.org/discord) est le plus rapide,
et la commande `/ask` y cherche dans ces pages.
