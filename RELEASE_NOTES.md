# VEAF Mission Creation Tools — 6.9.30-rc1 (pré-release de test)

> ⚠️ **Version de test, pas pour la production.** Elle ne remplace pas la version
> stable : `published-latest` reste en 6.9.2. Pour l'essayer, il faut la **cibler
> explicitement** — `veaf-tools-updater --tag published-v6.9.30-rc1`. But :
> éprouver le nouvel **assistant IA de création de missions** avant sa sortie officielle.

## 🤖 Créer et éditer une mission VEAF avec un assistant IA

Cette pré-release ouvre le **serveur MCP** : un assistant IA (Claude) peut construire
une mission VEAF **de bout en bout**, du dossier vide à la mission jouable, en langage
naturel.

- **Partir de zéro** — l'assistant initialise le dossier et pose une **carte blanche**
  prête à remplir pour le théâtre choisi (Caucasus, Syria, Persian Gulf, Normandy,
  Marianas, Sinaï, Germany CW, Afghanistan).
- **Placer par la géographie réelle** — « à 10 km au nord de Kobuleti », « près de
  Batumi » : les lieux réels sont convertis en coordonnées DCS.
- **Poser des éléments VEAF** — combat zones, QRA, CAP… l'assistant connaît les
  conventions de nommage, les types d'unités DCS et les **raccourcis de spawn**
  (`#command`, ex. `-samLR` pour une batterie SAM longue portée), qu'il **privilégie**
  désormais aux unités figées.
- **Gérer les bases** — « Mezzeh est bleu » : l'assistant colore l'aérodrome dans la
  bonne coalition **et** active ses **slots dynamiques** (Dynamic Spawn), remplis avec
  les avions dynamiques de la coalition.
- **Valider et construire** — l'assistant enchaîne `validate` puis `build` et produit
  le `.miz` jouable sans que vous quittiez la conversation.

## 🔧 Sous le capot

Nouveautés issues du test réel : **coloration d'aérodrome** (la couleur d'une base vit
dans les entrepôts, pas là où on posait les unités), **activation automatique des slots
dynamiques** sur les bases assignées, et un **guidage « alias d'abord »** pour que
l'assistant préfère les raccourcis VEAF (`-samLR`…) aux unités en dur.

## 🧪 Comment tester

1. `veaf-tools-updater --tag published-v6.9.30-rc1` dans un dossier de mission (ou
   laissez l'assistant scaffolder avec `tag="published-v6.9.30-rc1"`).
2. Demandez une mission à l'assistant en précisant le théâtre, puis « mets telle base
   en bleu » et construisez : la base doit être bleue et proposer des slots dynamiques.
3. Remontez tout accroc — c'est le but de cette pré-release.
