# Scripts personnalisés

## Ce que c'est {#what-it-is}

Le Lua qui ne se décrit pas en YAML. Il vit dans `src/scripts/` du dossier de mission et le build
l'embarque dans le `.miz`.

Deux cas :

- **`src/scripts/mission-script.lua`** — livré avec le dossier, chargé automatiquement, juste après
  `veaf-config.lua`. C'est là que va l'essentiel : alias personnalisés, fonctions utilitaires,
  réglages Lua de scripts tiers.
- **Vos autres `.lua`** — à déclarer dans `custom_scripts:` si vous voulez maîtriser l'ordre ou le
  moment du chargement.

## Le plus petit exemple qui marche {#minimal-example}

Rien à écrire dans `mission.yaml` : posez votre code dans `src/scripts/mission-script.lua` et
reconstruisez.

```lua
-- src/scripts/mission-script.lua
veafShortcuts.AddAlias(
  VeafAlias:new()
    :setName("-monalias")
    :setDescription("Mon spawn personnalisé")
    :setVeafCommand("_spawn group, name mon-groupe-custom")
)
```

`-monalias` devient utilisable comme marqueur sur la carte F10, au même titre que les alias
intégrés.

Pour un fichier supplémentaire :

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/MonOutillage.lua
```

## Décaler un chargement {#delay}

Un script qui inventorie le monde au démarrage doit passer **après** ceux qui créent les groupes :

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/MonOutillage.lua
    - path: src/scripts/AIEN.lua
      delay_seconds: 12
```

`delay_seconds` sort le script du déclencheur commun et lui en donne un à lui, armé au bout de
douze secondes.

## Le piège {#gotcha}

**C'est le délai qui décide de l'ordre, pas la position dans la liste.** Un script sans délai part
au démarrage, quel que soit son rang ; un script avec délai part à son heure. Déclarer un script
retardé avant un script immédiat produit un avertissement de build, parce que la lecture de la liste
suggère le contraire de ce qui va se passer.

Et `generate_load_trigger: false` n'exclut pas le fichier du `.miz` — il l'embarque **sans** le
charger. C'est à votre `mission-script.lua` de faire le `dofile`.

## Un fichier que le build a généré {#generated-artifacts}

Certains `.lua` de `src/scripts/` ne viennent de personne : c'est le build qui les fabrique et les
injecte dans la mission à chaque construction. Ils atterrissent dans le dossier de mission après
l'extraction d'une mission déjà construite.

| Fichier | Ce que c'est | Où se modifie le contenu |
|---|---|---|
| `veaf-spawn-data.lua` | la base de données de spawn (`_spawn unit` / `_spawn group`) | `src/spawn-groups.yaml` |
| `dcs-bridge.lua` | le pont d'exécution utilisé par l'outillage | rien à modifier, il est téléchargé |

Le build les laisse de côté et vous le signale : rien n'est cassé, votre mission reçoit la version
fraîche que la construction injecte. **Supprimez-les de votre dossier de mission** pour ne plus voir
le message.

Ne les déclarez pas dans `custom_scripts:` — cela figerait dans votre mission une copie périmée de
données que le build régénère.

## Pour aller plus loin {#more}

- [Référence `mission.yaml` — `custom_scripts:`](../../MISSION_YAML_REFERENCE.md#custom-scripts)
- [Guide complet — comment les scripts sont chargés](../GUIDE.md)
- [Référence de l'API Lua](../../LUA_API_REFERENCE.md)
