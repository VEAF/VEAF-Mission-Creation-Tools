# VEAF Mission Creation Tools — 6.37.0

**Les retours des pilotes des Open Training : les menus dans l'ordre où on s'en sert, le QNH dans les deux unités, chacun qui range ce qu'il a fait apparaître, et le Kiowa qui ne plante plus le client.**

---

## 📻 Menus F10 et météo

- **Les menus VEAF suivent l'ordre d'usage, dans toutes les langues** : campagne, zones de combat, météo et ATC, moyens, missions, porte-avions… ZONES DE COMBAT n'est plus en bas de la deuxième page d'une mission en français.
- **Le menu MISSION CAS reste entier toute la mission** : sans mission CAS en cours, ses entrées le disent au lieu d'être supprimées et recréées (en français, elles s'empilaient).
- **Le QNH et le QFE en hPa et en inHg pour tout le monde** : message d'arrivée en cabine, bulletin météo, ATIS, ATIS porte-avions, météo des zones de combat. Les appareils de l'Est gardent aussi les mmHg.

---

## 🧹 Chacun range ses spawns

- **F10 › VEAF › APPARITION › Page suivante › Mes spawns** retire ce que les marqueurs d'un pilote ont fait apparaître (`-sa6`, `-armor`, `-convoy`, `-farp`, `-cas`, `_spawn`…), tout d'un coup ou marqueur par marqueur.
- Seul l'auteur du marqueur voit ses spawns ; ce qui est détruit sort de la liste tout seul, une FARP part avec ses tentes et son escorte. `-destroy` reste réservé aux membres de confiance.

---

## 📡 Presets radio : jamais plus que ce que la radio contient

- **L'OH-58D ne fait plus planter le client DCS à l'apparition** : ses radios FM recevaient 32 presets pour 21 places.
- Chaque radio de chaque appareil (87 types) s'arrête au nombre de presets que son module connaît ; le build signale en un seul avertissement ce qu'il a coupé, et les kneeboards ne listent plus de canaux introuvables en cabine.
- Le `fm_supplement` livré passe de 30 à 20 entrées.

---

## 🎓 Open Training

- **Le briefing d'une OT devient des pages de kneeboard** dans la mission (`build_mission_briefing` avec `kneeboard_only` et `sheets`) : fiche mission, fiche de conduite, fiche des commandes, carte, un zoom par zone. Les pages pèsent trois fois moins qu'avant.
- Le prompt Open Training place les défenses de chaque camp de son côté du front, les véhicules hors des arbres, et suit la convention radio : VHF pour les terrains, UHF pour les moyens puis les vols.
- **Nouvelle commande `.\veaf-tools.exe dcs forest-check 'mission.miz'`** : elle liste en quelques secondes, sans lancer DCS, les véhicules au sol posés en forêt, en lisant les forêts dans les fichiers de carte de ton installation. Elle voit les forêts de Syria (Akamas, Ceyhan) que `clear-ground-check` ne voit pas.

---

## 🔧 Corrections

L'assistant de build propose la mission du dossier où il tourne · un alias s'exécute au niveau de sécurité de la commande qu'il lance · `-cas` ne demande plus le mot de passe à un pilote VEAF connu · la page Skynet ne demande plus de télécharger Skynet à part (il est livré et injecté par le build).

---

## ⚠️ Points d'attention

- **Certains alias demandent maintenant un niveau de sécurité** : `-send` et `-play` un membre de confiance ; `-ai_set`, les `-arty*`, les alias ravitailleur et AFAC (`-tankerlow`, `-tankerhigh`, `-tankerhere`, `-tanker`, `-afachere`) un pilote VEAF. Ils marchaient avant pour n'importe quel joueur.
- **Les fichiers d'une mission construite sont écrits comme l'éditeur de mission les écrit** (`["coalition"] = {`, tabulations). DCS lit les deux ; un dossier de mission ne change que quand une action MCP l'édite, mais le premier diff sera gros.
- **Les listes radio partagées sont coupées à la capacité de chaque radio** : un warbird garde 4 ou 5 presets, une radio d'AH-64D 10.
---

📖 [Mes spawns, côté pilote](https://veaf.github.io/documentation/latest/pilot/GUIDE/#remove-your-spawns) · [Mes spawns, côté créateur de mission](https://veaf.github.io/documentation/latest/mission-maker/scripts/veafSpawn/) · [dcs-hotload, pour les développeurs](https://veaf.github.io/documentation/latest/developer/hotload/)
