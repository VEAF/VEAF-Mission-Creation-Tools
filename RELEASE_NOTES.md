# VEAF Mission Creation Tools — 6.36.0

**Des versions d'entraînement pour chaque rôle, le vent que les pilotes vont vraiment rencontrer, et la Fat Cow pilotée qui laisse sa FARP derrière elle.**

Sur « Marteau du Golan », 17 kt annoncés au briefing sont devenus 24 kt au sol et 36 kt à 1 000 ft : DCS ne simule pas le vent qu'on lui donne.
Cette version écrit le vent voulu, l'annonce tel que DCS le simulera, et permet de s'entraîner sur le cadre d'une soirée avant de la voler.

---

## 🎓 Des versions d'entraînement, une par rôle

- Un bloc `training:` dans `mission.yaml` fait écrire au build, à côté du `.miz` de la soirée, `_TRAINING_A2G`, `_TRAINING_CAP`, `_TRAINING_SEAD` et `_TRAINING_ALL` : même théâtre, même heure, même météo, même briefing.
- Chaque version retire ce que son rôle suppose déjà fait (CAP adverse, QRA, SAM longue portée, cibles A2G) ; la version CAP garde toute la défense aérienne et arme la QRA dès le départ.
- Ce que le briefing décrit vaguement est **retiré au sort à chaque lancement** : on s'entraîne sans apprendre la mission par cœur.
- Le dossier de briefing ajoute une page par version (ce que devient chaque élément, ce qui est tiré au sort, la mission à charger), et `label:` nomme un élément pour les pilotes.
- Un profil de build peut retirer des groupes de l'éditeur de mission (`remove_groups:`), et l'assistant IA sait proposer et écrire le bloc `training:`.

---

## 🌬️ Le vent que les pilotes rencontreront

- **Le vent se donne tel qu'on le veut, à 10 m au-dessus d'un aérodrome de référence** (`set_weather`, variantes météo, conversion METAR), et l'outil écrit le réglage qui le produit — DCS multiplie le vent au sol de l'éditeur jusqu'à 2,1 fois dans les terres.
- **La rafale d'un METAR n'est plus perdue** : elle devient de la turbulence au sol.
- **Le briefing annonce le vent simulé par couche** (surface, 1 000 et 3 000 ft sol, FL100, FL250), et non plus le réglage ; la règle hélicoptère (20 kt, ou 15 kt de plus qu'en surface, de 0 à 600 m sol) remplace « 10 kt ou moins au sol ».
- **`.\veaf-tools.exe dcs mission-check`** vérifie le vent du briefing contre le modèle sur la mission construite, sans DCS.
- L'ATIS arrondit ses vitesses au lieu de les tronquer, et ajoute une ligne « vent max 0-2000 ft » quand la couche basse souffle nettement plus que la surface.

---

## 🐄 Fat Cow : CTLD 2.0.0-rc17

- **Une Fat Cow pilotée laisse sa FARP ouverte** quand elle décolle, est abattue ou que son pilote part ; **Replier la FARP Fat Cow**, depuis n'importe quel CH-47 piloté posé à moins de 150 m, dépose ce qui reste en caisses au sol.
- **Charger** un chargement pose ses caisses à côté du CH-47, à embarquer comme toute caisse CTLD ; chaque FARP ouverte a son nom, un pilote peut en ouvrir plusieurs.
- Un avion n'a plus le menu Fat Cow.
- Le JTAC écrit son code laser et chaque désignation dans `dcs.log`.

Rien à changer dans une mission existante : pas de nouveau réglage, catalogue de configuration toujours en `2.3.0`.

---

## 🔧 Corrections

Un menu F10 réservé à certains groupes ou découpé par pilote, placé sous un autre menu du même genre, garde son propre filtre · `add_group` prévient de nouveau quand un statique est posé sur une autre unité · `set_route` accepte un retour au point de départ (`HOME, IP, TGT, HOME`).

---

## ⚠️ Points d'attention

- **`RADIO.init.help_menus` change de sens** : il était passé tel quel à `skipHelpMenus`, donc `true` *cachait* les entrées « Aide ». Par défaut rien ne change (les entrées restent cachées) ; une mission qui avait écrit `help_menus: true` va maintenant les **afficher**.
- **Le vent écrit par l'outil change** : une mission dont la météo vient de `set_weather`, d'une variante ou d'un METAR, reconstruite, aura un réglage de vent plus faible au sol et un vent en altitude recalculé, pour que le vent simulé soit celui demandé.

---

📖 [Versions d'entraînement](https://veaf.github.io/documentation/latest/mission-maker/TRAINING_VERSIONS/) · [Le vent](https://veaf.github.io/documentation/latest/mission-maker/concepts/weather-variants/#wind) · [`mission-check`](https://veaf.github.io/documentation/latest/CLI_REFERENCE/#mission-check)
