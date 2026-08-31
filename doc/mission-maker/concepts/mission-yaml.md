# `mission.yaml` et ses modules

## Ce que c'est {#what-it-is}

Le fichier de configuration à la racine du dossier de mission. Deux choses y comptent avant tout :
le bloc `mission:` (l'identité) et le bloc `modules:` (**quelles fonctionnalités VEAF sont
actives**). Le build en dérive `src/scripts/veaf-config.lua`, qui est ce que les scripts lisent en
jeu.

## Le plus petit exemple qui marche {#minimal-example}

```yaml
mission:
  name: Ma-Mission

modules:
  # Infrastructure : obligatoire, aucune valeur après le deux-points
  UNITS:
  TIME:
  CACHE:
  EVENTS:
  MARKERS:
  COMMANDS:
  # Fonctionnalités : true pour activer
  RADIO: true         # le menu radio F10 VEAF
  SPAWN: true         # faire apparaître des unités depuis la carte F10
  SHORTCUTS: true     # les alias intégrés (-shilka, -sa2, …)
  INTERPRETER: true
```

C'est exactement ce que produit `prepare --template minimal`. Un module VEAF absent du bloc n'est
pas embarqué du tout — **les scripts communautaires font exception, voir [le piège](#gotcha)**.

## Les trois formes d'un module {#three-forms}

| Forme | Sens |
|---|---|
| `UNITS:` | module d'infrastructure, toujours actif, sans configuration |
| `RADIO: true` | activé avec sa configuration par défaut (`false` pour désactiver) |
| `RADIO:` puis un bloc indenté | activé **et** configuré ; `enabled: true` est implicite |

La forme longue sert dès qu'un module a des réglages :

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - zone_name: CZ-Alpha
        friendly_name: Zone Alpha
```

Certains modules **exigent** leur bloc (`ASSETS`, `SANCTUARY`, `COMBATZONE`, `QRA`, `AIRWAVES`) :
le `mission.yaml` livré les montre commentés, prêts à décommenter.

## Le piège {#gotcha}

**Les dépendances sont rajoutées d'office.** `COMBATZONE` a besoin de `SPAWN` ; `CASMISSION` a
besoin de `SPAWN` **et** de `GROUNDAI`. Si vous activez la fonctionnalité sans sa dépendance, le
build l'active pour vous et le dit dans un avertissement — même si vous l'aviez explicitement mise
à `false`. Le `modules:` que vous écrivez n'est donc pas exactement celui qui tourne : lisez les
avertissements du build.

**Les scripts communautaires sont là même si vous ne les nommez pas.** `STTS`, `CTLD`, `AIEN`,
`CSAR` et `SKYNET` sont *opt-out* : ils sont embarqués tant que vous n'écrivez pas `CTLD: false`.
Un `modules:` minimal, qui ne les mentionne nulle part, les embarque quand même — c'est pourquoi le
build peut vous parler de CTLD dans une mission où vous n'avez jamais écrit ce mot. Rien n'est
cassé ; pour vous en débarrasser, mettez-les explicitement à `false`. Les deux exceptions sont
`MIST` et `TUM`, *opt-in* : absents du bloc, ils restent éteints.

Et un piège de YAML : `MODULE:` (rien après le deux-points) et `MODULE: false` ne veulent pas dire
la même chose. Le premier est « infrastructure, active » ; le second, « éteinte ».

## Pour aller plus loin {#more}

- [Référence `mission.yaml` — `modules:`](../../MISSION_YAML_REFERENCE.md#modules)
- [Guide complet — configurer les modules](../GUIDE.md#configuring-modules)
- [Guide complet — niveaux de sécurité](../GUIDE.md#security-tiers)
- [Catalogue des scripts](../scripts/README.md) — ce que fait chaque module
