# VEAF Mission Creation Tools — 6.35.0

**Une Fat Cow qui se reprend, un briefing qui parle comme le cockpit, un journal de combat pour le debrief.**

La soirée du 29/10 sur « Marteau du Golan » a posé trois questions : les caps du briefing sont-ils vrais ou magnétiques, qui a tiré sur quoi, et pourquoi l'artillerie adverse n'a jamais riposté.
Cette version y répond, et embarque la dernière version de CTLD.

---

## 🐄 Fat Cow : CTLD 2.0.0-rc16

- **Une Fat Cow IA qui perd sa patrouille peut être reprise** : si sa patrouille est abattue ou que son dernier joueur part, elle rentre à sa base, et chaque patrouille d'hélicoptères de son camp sans Fat Cow est prévenue (où elle est, où elle va, ce qu'elle transporte).
  **F10 → CTLD → Fat Cow → Reprendre une Fat Cow** liste celles qui rentrent, la plus proche en premier : celle qu'on choisit rejoint la patrouille.
- **Libérer la Fat Cow**, à côté de **Rentre à la base** : elle quitte la patrouille et reste où elle est, FARP ouverte au sol ou en attente en vol, pour qu'une autre patrouille la reprenne.
- Une Fat Cow IA renvoyée à sa base depuis le sol ne disparaît plus sur place, et ne se pose plus dans les arbres.

Rien à changer dans une mission existante : pas de nouveau réglage, le catalogue de configuration reste en `2.3.0`.

---

## 🎯 Les leçons de « Marteau du Golan »

### Le briefing parle comme le cockpit

- **Les caps et les gisements sont magnétiques**, notés `°M`, comme les lisent les cockpits : branches du plan de vol, bullseye de chaque point, objectif et cible, cap du porte-avions, photos de reconnaissance, dans le dossier, le PDF, le kneeboard et le dossier de campagne.
  Ils étaient pris sur la grille de DCS, ni vraie ni magnétique : sur le Golan, 6,9° d'écart avec le cockpit.
- **Les distances sont mesurées sur l'ellipsoïde**, et non plus sur la grille, qui les gonflait (1 % à Tbilissi).
- **Les coordonnées d'une cible sont en degrés et minutes décimales (DDM) et en MGRS à dix chiffres**, plus jamais en degrés, minutes, secondes.
- Un groupe de véhicules qui se déplacent (chars, blindés, camions) est donné par le centre de sa zone, et n'est plus entouré sur une photo de reconnaissance.
- Le briefing garde au plus deux photos de reconnaissance par objectif.

### La mission

- **La contre-batterie d'AIEN n'est plus muette** : sur un groupe d'artillerie touché dès le début de la mission, elle se déclenchait 49 fois sans jamais tirer, faute de connaissance de la situation ; celle-ci est maintenant construite quand elle manque.
- **Le menu Opposition existe dès le premier vol** : le dossier de mission livré porte `opposition: { level: 0 }`, et une QRA créée par l'assistant IA suit le niveau d'opposition.
  Le Mission Maker peut couper la chasse adverse si les joueurs présents ne sont pas de taille, sans que la mission change au démarrage.
- **Un profil modifie les zones de combat par leur nom** (`modules.COMBATZONE.zone_edits`, `"*"` pour toutes), au lieu de recopier toute la liste `combat_zones`.
- L'assistant IA connaît de nouvelles règles de conception : SEAD et frappe sur des patrouilles séparées, météo calme avec des hélicoptères, couper la QRA ou les SAM longue portée à la demande.

---

## 📒 Un journal de combat pour le debrief

Un enregistrement Tacview ne nomme pas le tireur et ne montre pas le canon des hélicoptères.
Le nouveau module `COMBATLOG` écrit chaque tir, coup au but, destruction et rafale de canon dans un fichier `veaf-combat-log-….jsonl`, avec le tireur, son joueur, l'arme et la cible.

```powershell
.\veaf-tools.exe mission combat-log veaf-combat-log-20261029-211814.jsonl
```

donne le récap par pilote : armes tirées, obus, coups au but, destructions avec leur heure.
Il marche aussi sur les serveurs VEAF, qui retirent `os` aux scripts de mission.

---

## ⚠️ Points d'attention

- **Les valeurs du briefing changent** : caps en `°M` (6,9° d'écart avec l'ancien briefing sur le Golan, plus ou moins ailleurs), coordonnées en DDM et MGRS au lieu de DMS.
  Un briefing régénéré ne se compare pas ligne à ligne avec l'ancien.
- **`COMBATLOG` est actif dans le dossier de mission livré** : une nouvelle mission écrit un fichier par lancement, jamais effacé par l'outil.
  Sur un serveur qui relance souvent, faites le ménage de temps en temps, ou mettez `COMBATLOG: false`.

---

Merci aux pilotes de la soirée du 29/10 sur « Marteau du Golan » : leurs questions ont fait cette version.

📖 [Journal de combat](https://veaf.github.io/documentation/latest/mission-maker/scripts/veafCombatLog/) · [Commande `combat-log`](https://veaf.github.io/documentation/latest/CLI_REFERENCE/#combat-log)
