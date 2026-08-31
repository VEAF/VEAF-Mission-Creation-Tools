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
  # Scripts communautaires : écrits même éteints — voir « Le piège » plus bas
  STTS: false
  CTLD: false         # configuré dans ctld-config.yaml, à côté de ce fichier
  CSAR: false
  AIEN: false
  SKYNET: false
```

C'est exactement ce que produit `prepare --template minimal`. Un module VEAF absent du bloc n'est
pas embarqué du tout — les scripts communautaires, eux, suivent la règle inverse, et c'est pourquoi
le fichier généré les écrit tous, même à `false`.

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

Et un piège de YAML : `MODULE:` (rien après le deux-points) et `MODULE: false` ne veulent pas dire
la même chose. Le premier est « infrastructure, active » ; le second, « éteinte ».

**Les cinq scripts communautaires *opt-out* marchent à l'envers des modules VEAF.** `STTS`, `CTLD`,
`AIEN`, `CSAR` et `SKYNET` sont **actifs quand on ne les mentionne pas** : leur absence du bloc
`modules:` vaut « garde ton état par défaut », et leur défaut est activé. Un module VEAF absent,
lui, n'est pas embarqué. C'est pour cette raison que tous les scaffolds (`prepare --template`,
`convert-v5`, le `mission.yaml` livré) les écrivent **explicitement**, `true` ou `false` : un
`false` se lit, une absence qui veut dire « activé » ne se lit pas. Si vous écrivez le fichier à la
main, faites de même — sinon le build embarquera CTLD dans une mission qui ne le nomme jamais.

## Pour aller plus loin {#more}

- [Référence `mission.yaml` — `modules:`](../../MISSION_YAML_REFERENCE.md#modules)
- [Guide complet — configurer les modules](../GUIDE.md#configuring-modules)
- [Guide complet — niveaux de sécurité](../GUIDE.md#security-tiers)
- [Catalogue des scripts](../scripts/README.md) — ce que fait chaque module
