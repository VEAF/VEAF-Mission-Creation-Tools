# VEAF Mission Creation Tools — 6.7.2

Version de **corrections ciblées remontées du terrain** (autour des **slots dynamiques DCS**) et de **lisibilité de la sortie console**. Aucune nouvelle configuration : les missions existantes n'ont rien à changer.

## 🐛 Corrections

### Slots dynamiques

- **La QRA réagit de nouveau aux avions en slot dynamique** ([#299](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/299)) — un avion pris en slot dynamique ne déclenchait la QRA que si `react_on_helicopters` valait `true`. En cause : la catégorie de l'intrus était mal lue (tout slot dynamique passait pour un hélicoptère). Désormais un avion slot-dyn déclenche la QRA quel que soit `react_on_helicopters`. Au passage, `:setReactOnHelicopters(false)` est enfin respecté (il forçait `true`).
- **Plus de menu radio CTLD en double sur un hélico en slot dynamique posé sur une FARP spawnée** — prendre un slot dynamique sur une FARP créée en jeu dupliquait tout le menu CTLD (chaque entrée en double, clics sans effet), à cause d'un plantage Lua interne. Le menu est maintenant construit une seule fois et fonctionne.
- **`convert-v5` convertit enfin les avions spawnables au format « à plat »** — selon la génération de l'éditeur d'avions spawnables v5, le `settings.lua` pouvait être dans un format que `convert-v5` ne lisait pas → `spawnables.yaml` vide, tous les avions perdus. Les deux formats sont désormais gérés (vérifié : 41 groupes récupérés là où il y en avait 0).

### Conversion v5 → v6

- **`convert-v5` ne décrit plus des éditions d'un `missionConfig.lua` qu'il supprime** — le rapport et la console listaient une dizaine de lignes « ligne N : … mis en commentaire / encapsulé » sur un fichier en réalité sauvegardé puis remplacé par `mission-script.lua`. Ce bruit trompeur est retiré ; seuls les éléments réellement utiles (modules détectés) restent.

## 🎨 Sortie console plus lisible

- **Pluriels naturels partout** — fini les `1 truc injecté(s)` : la sortie affiche `1 avion injecté` / `5 avions injectés`, en français comme en anglais.
- **Étapes de build indentées** — chaque étape garde son en-tête `Pipeline : …` et son détail est désormais indenté en dessous.
- **Les comptes « 0 » ne ressemblent plus à des erreurs** — l'étape « données de spawn » nomme son fichier (`spawn-groups.yaml`) comme les autres ; les avions déjà présents sont signalés `N déjà présent(s) (ignoré(s))` au lieu d'un `0 injecté` sec ; idem préréglages/waypoints sans correspondance.

## 🙏 Remerciements

Merci à **Tripack** pour ses signalements précis et reproductibles (QRA, CTLD, conversion des avions spawnables sur slots dynamiques).
