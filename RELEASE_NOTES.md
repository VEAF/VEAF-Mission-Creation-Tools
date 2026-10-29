# VEAF Mission Creation Tools — 6.34.0

**Le briefing d'une mission à objectifs, au niveau d'un briefing fait main.**

« Marteau du Golan » (Syrie) a été préparée avec l'assistant IA et les outils, puis finie à la main : un dossier de 52 pages, des cartes retravaillées, des photos de reconnaissance, une affiche.
Tout ce qui a été fait à la main est maintenant fait par les outils.

---

## 📋 Le briefing d'une mission à objectifs

### Les cartes

- **La vue d'ensemble est lisible** : cadrée sur la zone utile, tournée quand ça la resserre (avec une flèche du nord), en haute résolution, sa légende dessinée dedans.
- Elle montre les bases de départ, les bases de QRA ennemies, le niveau de vol des ravitailleurs, la ligne de front, et la route des hélicoptères à part.
- **Une carte de la zone des combats** suit la vue d'ensemble : les unités amies, le JTAC, les axes d'attaque et la portée de chaque menace.
- Chaque zoom d'objectif porte un encart qui le situe sur la vue d'ensemble.

### Les objectifs et le plan de vol

- **Des fiches au lieu de listes** : chaque cible est une fiche avec une vignette, ce qu'elle est, ses coordonnées en DMS et DDM, son altitude, son gisement et sa distance au bullseye.
- Les cibles sont nommées par unité quand c'est possible (le radar et les lanceurs d'un SA-6), sinon par leur type (`T-72B3`).
- Le plan de vol se lit pas à pas, comme sur le kneeboard de DCS : cap et distance, relief le plus haut, ce qu'on fait au point.
- Un objectif peut être **principal, secondaire ou préalable** : le SA-6 que les hélicoptères attendent est un préalable.
- Avec une opération dans `mission.yaml`, ses tâches sont les objectifs principaux, les autres zones les objectifs secondaires.

### L'ATO et les fréquences

- **Avec des slots dynamiques**, l'ATO ne liste plus les 61 types d'avions qu'offre une base : il dit « slot dynamique », la base et les patrouilles prévues (indicatif, appareil, nombre, tâche).
- Il donne le niveau de vol des ravitailleurs, et ce qui n'a pas de groupe dans la mission : un JTAC, la Fat Cow, un GCI.
- Le plan de fréquences suit les patrouilles : un bloc par plan radio, qui dit quelle patrouille l'a sur quelle radio.

### Les nouvelles pages

- Une page **situation stratégique**, une page **déploiement et coordination**, une page **mots de code**.
- Les photos de reconnaissance de chaque objectif, après son zoom (voir plus bas).
- Le texte d'une rubrique peut être de la prose, en paragraphes.

### Le kneeboard et le PDF

- Les cartes du kneeboard sont en portrait, **axe d'attaque vers le haut**.
- La fiche de vol est un tableau avec l'altitude de chaque point, sans le plan radio : les presets sont déjà dans les cockpits.
- Le briefing peut remplacer les pages de kneeboard faites à la main (elles sont gardées en sauvegarde).
- Le PDF suit la présentation, aligné à gauche, avec l'ATO, le déploiement et les mots de code en tableaux.

Tout est optionnel : les paramètres existants gardent leur sens, et une page dont le texte n'est pas donné n'apparaît pas.

---

## 📸 Photos de reconnaissance et contrôle de la mission, depuis DCS

Deux nouvelles commandes, pour un DCS lancé sur votre machine :

- **`.\veaf-tools.exe dcs recon-prepare`, `recon-plan`, `recon-shoot`, `recon-render`** : des photos de reconnaissance de chaque objectif, prises avec la caméra F11 dans l'axe d'attaque, en noir et blanc contrasté, les cibles entourées au feutre rouge.
  Le briefing les reprend toutes seules.
- **`.\veaf-tools.exe dcs mission-check-prepare` puis `mission-check`** : vérifie la mission qui tourne — chaque libellé du menu F10, chaque zone et mission de combat activée puis désactivée et ses unités comptées, chaque colonne vue en mouvement — et rend un verdict.

Elles passent par le **bridge VEAF**, comme la capture du terrain : `recon-prepare` et `mission-check-prepare` écrivent une copie de la mission qui l'embarque, et les commandes démarrent `dcs-serve` toutes seules.
`dcs-serve.exe` est livré dans le kit de capture des cartes (`veaf-map-capture-kit-6.34.0.zip`) : posez-le à côté de `veaf-tools.exe`, ou donnez son chemin avec `--dcs-serve`.
Il faut aussi avoir autorisé une fois les scripts de mission à communiquer (`MissionScripting.lua`), la même manipulation que pour la capture du terrain, à refaire après chaque mise à jour de DCS.
Elles n'agissent que sur une session DCS que vous avez lancée, jamais sur un serveur.

---

## 📣 Annoncer la mission

Avec l'assistant IA, une mission construite donne son **affiche** (16:9), sa **bannière pour le calendrier VEAF** et son **message Discord** (moins de 2 000 caractères).
La date, l'heure et les liens sont à donner : ils ne sont jamais inventés.

Le prompt de mission à objectifs fait valider le texte du briefing avant toute mise en page, sort les consignes du Mission Maker dans une fiche à part, et prévoit des solutions de repli quand peu de pilotes viennent.

---

## 🔧 Corrections

- **Une mission avec les templates de La-7 s'enregistre de nouveau dans l'éditeur de mission** : DCS 2.9.31 a passé la radio du La-7 en HF (3,7 à 6,06 MHz), et les templates de slots dynamiques gardaient 121,5 MHz (« Invalid frequency »). Ils sont maintenant à 3,7 MHz.
- **Une zone de combat membre d'une opération était enregistrée deux fois** : une boucle sur toutes les zones la faisait apparaître en double.
- Une CAP sans nom de menu faisait une entrée F10 vide : elle prend le nom de son groupe.
- `.\veaf-tools.exe mission validate` signale une clé que le build ne lit pas dans `cap_missions` (`friendly_name`).
- L'assistant IA connaît les scripts communautaires (CTLD, CSAR, MIST…) quand on lui demande de décrire un module.
- Une nouvelle limitation connue : une colonne sur route (« On Road ») sans chemin possible reste immobile, sans message.
- **La documentation** : un lien copié depuis le site suit la dernière version au lieu de rester sur un numéro.

---

## ⚠️ Points d'attention

- **Un build avec profil écrit son propre fichier** : `.\veaf-tools.exe mission build --profile TEST` écrit `<mission>_TEST.miz`, au lieu d'écraser le `.miz` du build normal.
- **Les templates de slots dynamiques d'un camp sans base à slots ne sont plus injectés.**
  Pour les garder : `pipeline.dynamic_slot_templates.all_sides: true`.
- **`smoke-test` demande une mission construite avec le bridge** (`dcs_bridge` dans `mission.yaml`), et ses options `--url` et `--fiddle-token` sont remplacées par `--serve-url`, `--api-key` et leurs voisines : le hook DCS Fiddle n'est plus utilisé nulle part.

---

📖 [Photos de reconnaissance](https://veaf.github.io/documentation/latest/CLI_REFERENCE/#recon-photos) · [Contrôle de la mission](https://veaf.github.io/documentation/latest/CLI_REFERENCE/#mission-check)
