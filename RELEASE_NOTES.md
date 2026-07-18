# VEAF Mission Creation Tools — 6.10.0

Première version **stable et officielle** de la ligne v6. Elle remplace la v5 et
devient la version installée par défaut (`published-latest`).

## 🚀 Une nouvelle chaîne de création de missions

La v6 décrit une mission de façon **déclarative** dans un simple `mission.yaml`, puis
la construit :

- **Migrer depuis la v5** — `convert-v5` reprend une mission v5 existante et produit son
  équivalent v6, presets radio et données de spawn compris.
- **Partir d'un modèle** — `prepare --template` pose un dossier de mission prêt à remplir.
- **Valider puis construire** — `validate` vérifie la cohérence (références, fréquences,
  types d'unités) et `build` assemble le `.miz` jouable.
- **Presets radio & kneeboards** — projection des presets par type d'appareil, planchettes
  générées automatiquement.

## 🤖 Créer une mission avec un assistant IA

La v6 ouvre un **serveur MCP** livré comme **plugin Claude** : un assistant IA construit
une mission VEAF **de bout en bout**, du dossier vide au `.miz` jouable, en langage naturel.

- **Partir de zéro** — carte blanche prête à remplir pour le théâtre choisi (Caucasus,
  Syria, Persian Gulf, Normandy, Marianas, Sinaï, Germany CW, Afghanistan).
- **Placer par la géographie réelle** — « à 10 km au nord de Kobuleti », « près de Batumi ».
- **Poser des éléments VEAF** — combat zones, QRA, CAP ; l'assistant connaît les conventions
  de nommage et privilégie les **raccourcis de spawn** (`#command`, ex. `-samLR`).
- **Gérer les bases** — « Mezzeh est bleu » colore l'aérodrome et active ses slots dynamiques.

## 🛠️ Runtime DCS

- **Pagination automatique** des menus radio F10 (fini le débordement de la limite des 10).
- **Combat zones** : regroupement et préfixe de menu radio pilotables depuis le YAML.
- **QRA / slots dynamiques** : réactions correctes sur les appareils en slot dynamique.
- **Server hook** déployable par simple copie (flags OFF par défaut) — **à redéployer**.

## 🌍 Multi-théâtres & multi-plateformes

- Conversion de coordonnées et **placement géographique sur les 14 théâtres DCS**.
- Binaires standalone **Linux / macOS** en plus de Windows.

## ⚠️ Notes de migration pour les mission makers

- Une mission **v5** se convertit avec `convert-v5` (ne pas éditer un dossier v6 à la main
  comme en v5).
- Le **server hook** doit être redéployé (nouveau contrat de callbacks).
- `MISSILEGUARDIAN` n'est plus activé par le tier `full` — il est désormais **opt-in**.
- L'**AJS-37** rompt l'iso-fonctionnalité des presets radio (agencement dédié Viggen).

## 🙏 Remerciements

Merci à tous les **mission makers** et **mission programmers** de la VEAF qui ont essuyé
les plâtres de la v6 et fait remonter retours, tests et correctifs — avec une pensée
spéciale pour **Dup**, **Flogas**, **Reaper** et **Tripack**. Merci également à **Mitch**
pour les données dcs-maps.
