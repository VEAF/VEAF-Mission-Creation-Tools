# veafCombatLog — Journal de combat pour le debrief

**Module ID:** `COMBATLOG` | **Fichier:** `veafCombatLog.lua`

---

## Objectif

Écrit chaque tir, chaque coup au but et chaque destruction de la mission dans un fichier, une ligne JSON par événement, pour un debrief qui sait qui a tiré quoi sur qui.
Un enregistrement Tacview ne le dit pas : il ne nomme pas le tireur, ne note pas les destructions, et ne montre pas le canon des hélicoptères (soirée du 29/10/2026 sur *Marteau du Golan*).

---

## Activation

Dans `mission.yaml`, actif par défaut dans le dossier de mission livré :

```yaml
modules:
  COMBATLOG: true
```

Le fichier s'écrit seulement si l'environnement de script de DCS garde `io` et `lfs`, comme sur les serveurs VEAF (qui retirent `os`).
Sinon le module le dit une fois dans `dcs.log` et n'écrit rien : la mission tourne normalement.

---

## Le fichier

`veaf-combat-log-<date>-<heure>.jsonl`, dans le dossier `VEAF_EXPORT_DIR` s'il est défini, sinon dans le dossier d'écriture de DCS (`Saved Games\DCS…`).
Là où l'environnement de script retire `os`, comme sur les serveurs VEAF, la date réelle est inconnue : le fichier s'appelle `veaf-combat-log-<date de la mission>-<n>.jsonl`, dans le dossier d'écriture de DCS, `<n>` étant le premier numéro libre (`-1`, puis `-2` après une relance…).
Un fichier par lancement de mission, jamais effacé par l'outil : sur un serveur qui relance souvent, faites le ménage de temps en temps.
Le fichier est écrit sur disque toutes les 10 secondes (un plantage perd au plus ces 10 secondes), pas à chaque ligne : un passage canon lève un événement par obus.

| `event` | Événement DCS | Ce que la ligne donne |
|---|---|---|
| `start` | lancement | carte, date, heure de début, heure réelle |
| `shot` | `S_EVENT_SHOT` | tireur, arme, cible visée (arme guidée) |
| `hit` | `S_EVENT_HIT` | tireur, arme, cible touchée |
| `kill` | `S_EVENT_KILL` | tireur, arme, cible détruite |
| `shooting_start` / `shooting_end` | rafale de canon | tireur, canon ; à la fin, `rounds`, les obus tirés |

Le tireur et la cible portent leur nom d'unité, leur type, leur coalition, leur groupe et le nom du joueur.
`t` est le temps de mission en secondes.
`weapon_object` et `weapon_name` disent ce que DCS a fourni : un obus de canon arrive parfois sans objet arme, ce qui se mesure dans le fichier lui-même.

---

## Le récap par pilote

```powershell
.\veaf-tools.exe mission combat-log veaf-combat-log-20261029-211814.jsonl
```

Un tableau par pilote : armes tirées, obus, coups au but, destructions avec leur heure (⚠ sur un tir fratricide).
`--ai` ajoute les tireurs IA, `--json` sort le récap en JSON.
Voir la [référence des commandes](../../CLI_REFERENCE.md#combat-log).

---

## Voir aussi

- [Référence de mission.yaml](../../MISSION_YAML_REFERENCE.md) — les modules et leurs options
