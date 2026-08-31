# Préréglages radio

## Ce que c'est {#what-it-is}

`src/presets.yaml` décrit les canaux radio **une fois par coalition**, et le build les projette sur
les radios physiques de chaque appareil joueur. Il en produit aussi une planchette PNG par type
d'appareil, embarquée dans le `.miz`.

Fini le réglage canal par canal, appareil par appareil, dans l'éditeur DCS.

## Le plus petit exemple qui marche {#minimal-example}

```yaml
channels_collection:
  common:
    Guard:
      title: Guard
      freqs:
        uhf: 243.0
        vhf: 121.5

channel_lists:
  blue:
    primary_1:
      01: Guard
```

- `channels_collection` donne un **nom** à une fréquence, avec une valeur par bande.
- `channel_lists` déclare, par coalition et par **rôle de radio**, quel canal va sur quel numéro.

Une fréquence littérale se passe de `channels_collection` :

```yaml
channel_lists:
  blue:
    primary_1:
      01: 251.0
```

## Les rôles de radio {#radio-roles}

| Rôle | Bande | Sert à |
|---|---|---|
| `primary_1` | UHF | la première radio V/UHF |
| `primary_2` | VHF | la seconde V/UHF ; aussi la radio unique des warbirds |
| `fm_supplement` | FM | la FM en plus de deux V/UHF (A-10C…) |
| `fm_substitute` | FM | la FM à la place d'une V/UHF |
| `fm_secondary` | FM | une seconde FM |

Le build regarde les radios réelles de chaque type d'appareil et leur attribue le rôle qui
correspond. Un rôle inconnu fait échouer le build.

## Le piège {#gotcha}

**Un canal sans fréquence dans la bande du rôle est retiré, sans bruit.** Un canal qui ne déclare
qu'une `uhf:` placé dans `primary_2` (VHF) disparaît de la liste projetée — le numéro de canal reste
vide sur la radio. Une fréquence littérale, elle, n'est jamais retirée.

Symptôme à surveiller : `presets-validation-report.md` apparaît à la racine du dossier de mission
après un build. Il n'est écrit que s'il y a un problème, et supprimé quand il n'y en a plus.

## Aller plus loin {#more}

- Une affectation explicite par type d'appareil, dans `presets_assignments:`, **gagne toujours**
  contre la projection automatique — y compris `none`, qui laisse les radios du groupe intactes.
- Pour ne garder que l'injection radio, sans les planchettes :

  ```yaml
  pipeline:
    presets:
      enabled: true
      kneeboards: false
  ```

- [Référence Pipeline — étape 1, préréglages radio](../../PIPELINE_REFERENCE.md#pipeline-step-1-presets)
- [Référence Pipeline — les deux formats d'auteur](../../PIPELINE_REFERENCE.md#two-authoring-formats)
- [Spécifications radio DCS](../dcs-radio-specs.md) — ce que chaque appareil possède réellement
