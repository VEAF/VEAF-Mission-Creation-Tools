# VEAF Mission Creation Tools — 6.31.2

**Une version corrective de la 6.31.x, pour une IA qui construit une mission avec les seuls outils VEAF.**
Nous avons laissé une IA gratuite (OpenCode) créer une mission de bout en bout sur un PC neuf, avec rien d'autre que `veaf-tools`.
Elle a buté sur une mise à jour qui cassait les serveurs en marche, sur des fichiers qu'elle ne savait pas modifier, et sur des informations qu'elle devait aller fouiller dans l'exécutable : cette version corrige tout cela, et ajoute de quoi vérifier une mission construite.

> ### ⚠️ Ce qui change pour vous
>
> **Si vous utilisez une IA avec les outils VEAF** (Claude Desktop, Claude Code, Codex, Antigravity, Gemini CLI, OpenCode) : quand la 6.31.2 arrive, **fermez toutes vos IA, puis relancez-les**.
> Une IA en 6.31.0 ou 6.31.1 se met à jour une dernière fois « à l'ancienne », en remplaçant l'exécutable sous ses pieds ; si elle répond `Error -3 while decompressing data`, c'est ça : fermez-la et relancez-la.
>
> À partir de la 6.31.2, une mise à jour ne casse plus rien : elle attend à côté et prend le relais **au prochain démarrage d'une IA**, quand plus aucune autre ne tourne.
> Si vous gardez une IA ouverte plusieurs jours, fermez-les toutes de temps en temps pour prendre les mises à jour.

---

## 🛠️ Corrections

- **La mise à jour automatique ne casse plus les IA ouvertes.**
  Elle remplaçait `veaf-tools.exe` pendant que d'autres sessions s'en servaient, et leurs actions suivantes échouaient (`Error -3 while decompressing data`) ; l'IA du test a passé 80 minutes à chercher un fichier corrompu qui n'existait pas.
  La nouvelle version est maintenant téléchargée à côté (`veaf-tools.exe.staged`) et mise en place au démarrage suivant, seulement quand aucun autre `veaf-tools.exe` ne tourne.
  Relancer l'updater à la main reste possible : il vous prévient si un `veaf-tools.exe` tourne encore.
- **Une FARP seule dans sa mission reçoit enfin ses slots dynamiques.**
  Le build annonçait « 0 ships/FARPs » et la FARP restait sans hélicoptère à prendre ; c'était un piège de lecture de la table des entrepôts quand la mission n'a qu'une FARP.
- **Le dossier de mission créé par `prepare` est entièrement en fins de ligne Unix (LF)**, comme le reste du gabarit, et une IA modifie désormais un passage de plusieurs lignes même dans un fichier en fins de ligne Windows.

## ✨ Nouveautés pour les IA

- **`inspect_built_mission`** : après le build, l'IA vérifie ce que contient vraiment le `.miz` — slots dynamiques et templates de chaque base, FARP et navire, préréglages radio par appareil, bullseyes, météo de chaque variante, ravitailleurs et AWACS — sans jamais ouvrir l'archive à la main.
  Le guide et les prompts de mission lui disent de passer par là, et plus jamais par un shell.
- **Préparer un scénario avant qu'un dossier existe** : les places de parking et les fréquences ATC des aérodromes, les pays DCS, la conversion de coordonnées et la recherche d'un lieu réel se demandent maintenant pour une carte, sans mission ; l'IA peut aussi lire le gabarit que posera `scaffold_mission` (préréglages, templates de slots dynamiques).

## 🪶 Plus léger pour l'IA

Ce qu'une IA lit reste dans sa mémoire jusqu'à la fin de la session et lui est renvoyé à chaque tour : la liste des aérodromes de Syrie est presque deux fois plus courte, les limitations connues se lisent en liste courte puis une par une, et le prompt de mission « objectif » arrive en deux parties (le scénario d'abord, la construction une fois le scénario approuvé).

---

📖 Installer les outils pour une IA : [page d'installation](https://veaf.github.io/documentation/latest/mission-maker/AI_ASSISTANT_INSTALL/)
