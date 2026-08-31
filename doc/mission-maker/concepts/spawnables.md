# Groupes spawnables

## Ce que c'est {#what-it-is}

Deux familles de « choses à faire apparaître en jeu », qui ne se déclarent pas au même endroit.

| | Fichier | Ce que c'est | Comment on l'appelle |
|---|---|---|---|
| **Aéronefs** | `src/spawnables.yaml` | des groupes d'aéronefs modèles, préfixés `veafSpawn-` | commandes du menu radio / marqueurs |
| **Sol et mer** | `src/spawn-groups.yaml` | des alias vers des compositions d'unités | `_spawn unit <alias>` / `_spawn group <alias>` |

## Le plus petit exemple qui marche — sol et mer {#minimal-example}

`src/spawn-groups.yaml` est livré entièrement commenté : tel quel, il n'ajoute rien. Décommentez et
adaptez :

```yaml
units:                              # -> `_spawn unit <alias>`
  - aliases: [myaaa]
    unitType: ZSU-23-4 Shilka

groups:                             # -> `_spawn group <alias>`
  - aliases: [mysam]
    disposition: {h: 3, w: 3}       # grille de placement, en cellules de 10 m
    units:
      - {type: ZSU-23-4 Shilka, cell: 1}
      - {type: Ural-375, random: true}
      - {type: Soldier M4, number: {min: 2, max: 4}, random: true}
    description: Mon site SAM
    groupName: MySAM
```

En jeu, un marqueur sur la carte F10 portant `_spawn group, name mysam` fait apparaître la
composition à cet endroit. La syntaxe des marqueurs est dans les [alias](../../ALIASES.md).

## Le plus petit exemple qui marche — aéronefs {#aircraft-example}

Celui-là ne s'écrit pas à la main : un groupe d'aéronefs DCS fait des centaines de lignes. On le
construit dans l'éditeur DCS, on le nomme avec le préfixe `veafSpawn-`, puis on l'extrait :

```powershell
veaf-tools.exe extract-aircraft-groups ma-mission.miz --kind spawnable
```

Le fichier `src/spawnables.yaml` est réécrit avec vos groupes. Le prochain build les réinjecte.

## Le piège {#gotcha}

**C'est le préfixe du nom qui décide de la famille**, pas le fichier. Un groupe d'aéronefs nommé
`veafSpawn-…` va dans `spawnables.yaml` ; un groupe marqué `dynSpawnTemplate: true` va dans
`dynamic-slot-templates.yaml` — et le marqueur `dynSpawnTemplate` gagne contre le préfixe si un
groupe porte les deux.

Deuxième piège : une entrée de `spawn-groups.yaml` qui reprend un alias déjà connu du framework le
**remplace**. C'est utile pour redéfinir un groupe standard, et surprenant si c'était involontaire.

## Pour aller plus loin {#more}

- [Référence Pipeline — étape 3, groupes d'aéronefs](../../PIPELINE_REFERENCE.md#pipeline-step-3-aircraft-groups)
- [Référence Pipeline — étape 5, données de spawn](../../PIPELINE_REFERENCE.md#pipeline-step-5-spawn-data)
- [veafSpawn](../scripts/veafSpawn.md) — les commandes en jeu
- [Alias de marqueurs](../../ALIASES.md)
- [Slots dynamiques](dynamic-slots.md) — la troisième famille de groupes d'aéronefs
