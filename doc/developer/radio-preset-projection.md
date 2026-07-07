# Projection des presets radio par type d'aéronef

> **Public : développeurs.** Comment le build projette les listes de canaux
> (`channel_lists`, le « mode plan » de `presets.yaml`) sur les radios physiques
> de chaque type d'aéronef, en tenant compte de ses particularités matérielles
> (canal 0, slots réservés, canaux spéciaux en dur, fusion de radios…).
>
> Décision d'architecture : [ADR 0010](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/docs/adr/0010-per-type-radio-preset-projection.md)
> (étend [ADR 0003](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/docs/adr/0003-presets-fidelity.md)).
> Analyse amont : [exploration](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/docs/exploration/RADIO-PRESETS-PER-TYPE-PROJECTION.md).
> Côté mission-maker : [format `presets.yaml`](../PIPELINE_REFERENCE.md#deux-formats-dauteur).

---

## Le modèle en bref

Le mission-maker déclare, une fois par coalition, des **listes de canaux par
rôle radio fonctionnel** (`channel_lists`) — pas par radio physique. Au build,
un **packer** lit les radios réelles de chaque type depuis les specs DCS et
**projette** chaque liste sur la bonne radio, en appliquant la règle de *layout*
propre au type.

```text
channel_lists (mission-maker, par rôle)
        │
        ▼
   packer  ──lit──►  dcs-radio-specs.yaml   (bandes/modulation par radio, auto-généré)
        │      ──lit──►  dcs-radio-layouts.yaml (particularités par type, maintenu à la main)
        ▼
   PresetDefinition  ──►  injecteur existant  ──►  unit["Radio"] + kneeboard
```

Le packer produit des objets `PresetDefinition` et réutilise tel quel
l'injecteur, la validation de bande et la génération de kneeboard existants. Une
affectation explicite dans `presets_assignments` (format historique) reste la
voie de **surcharge manuelle** : elle l'emporte toujours sur le packer.

## Fichiers source

| Fichier | Rôle |
|---|---|
| [`dcs-radio-layouts.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/src/python/veaf-tools/presets_injector/data/dcs-radio-layouts.yaml) | **Source de vérité des particularités par type.** Maintenu à la main. Chaque primitive y est documentée en tête de fichier. |
| [`dcs-radio-specs.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/src/python/veaf-tools/presets_injector/data/dcs-radio-specs.yaml) | Plages de fréquences / modulation par radio physique. **Auto-généré** (`poetry run update-radio-specs`), ne jamais éditer à la main. |
| [`presets_manager.py`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/src/python/veaf-tools/presets_injector/presets_manager.py) | Le packer et ses règles : `_assign_roles_by_position` (défaut par bande), `_check_layout_radio_count` (garde de comptage), `_channel_list_for_role` (résolution de rôle). |

## Rôles radio (vocabulaire fixe)

Le rôle porte la bande de fréquence ; un canal sans cette bande est retiré de la
liste (signalé sous `validate`, silencieux sous `build`).

| Rôle | Sens |
|---|---|
| `primary_1` | 1re radio V/UHF (bande UHF) |
| `primary_2` | 2e radio V/UHF (bande VHF) ; aussi la radio unique des warbirds |
| `fm_substitute` | FM comme 2e radio (hélicoptères à une seule V/UHF) |
| `fm_supplement` | FM en plus de deux V/UHF (avions d'attaque) |
| `fm_secondary` | 2e FM supplémentaire (ex. OH-58D) ; par défaut = copie de `fm_supplement` |

## Défaut par bande (types sans entrée de layout)

Un type absent de `dcs-radio-layouts.yaml` passe par le défaut
`_assign_roles_by_position` : chaque radio physique est classée par ses plages
de fréquences, les radios sans ambiguïté (mono-bande) sont affectées
directement — donc un ordre volontairement inversé (la VHF en radio 1 de l'A-10)
se résout sans entrée explicite —, et l'ordre physique ne sert de repli que pour
les radios combo réellement ambiguës (les deux ARC-210 identiques du F/A-18).

C'est pourquoi **A-10C et A-10C_2 sont volontairement absents** du fichier de
layout : leur ordre VHF-first et la largeur de bande de l'ARC-210 sont déjà
résolus correctement par le défaut.

## Primitives de particularité

Déclarées par radio physique (index 1-based, ordre des specs / du `.miz`) dans
`dcs-radio-layouts.yaml` :

| Primitive | Effet |
|---|---|
| `rotate_last_to_head: true` | **Rotation « canal 0 »** : la dernière entrée de la liste passe en tête (slot 1), le reste suit en 2..N. |
| `fuse: [role_a, role_b, …]` | **Fusion de radios** : concatène les listes de plusieurs rôles dans une seule radio physique, renumérotées à partir du slot 1. |
| `leading_dummy: {freq, mod}` | **Slot 1 réservé en dur** (constante d'airframe, sans entrée de liste) ; le reste décale en slot 2. |
| `trailing_specials: [{freq, mod}, …]` | **Canaux spéciaux en dur** ajoutés en fin de radio (constantes d'airframe, surchargeable par le mission-maker). |
| `reserved_head_slots: [idx, …]` | **Slot(s) de tête réservé(s)** alimentés par un index de la liste (slot « M » / « C »). `[20]` = dernière entrée déplacée en tête ; `[1, 20]` = 1re dupliquée en tête puis dernière déplacée. Exclusif avec `rotate_last_to_head`. |
| `capacity: <int>` | **Capacité physique** de la radio : l'excédent est tronqué en fin de liste (silencieux, log debug). |

**Ordre de composition** quand plusieurs primitives coexistent sur une radio :
fusion (ou liste de rôle) → rotation *ou* slots de tête réservés (mutuellement
exclusifs) → insertion du `leading_dummy` en slot 1 → ajout des
`trailing_specials` → troncature à la `capacity`.

Le packer vérifie aussi le nombre de radios déclarées contre les specs réelles
et logue un `WARNING` en cas de dérive (`_check_layout_radio_count`) — utile
après un patch DCS qui change le nombre de radios d'un appareil.

## Types à particularité (état courant)

Ces types ont une entrée explicite dans `dcs-radio-layouts.yaml` ; tous les
autres passent par le défaut par bande.

| Type | Radios | Particularité |
|---|---|---|
| **Mi-24P** | 2 (R-863 V/UHF + R-828 FM) | Radio 1 `primary_1` avec **rotation canal 0** ; radio 2 `fm_substitute` standard. |
| **CH-47Fbl1** | 3 (ARC-186 + ARC-164 + ARC-201D) | Radio 1 `fm_substitute` **avec rotation** (bande AM secondaire trompe le classement par bande → entrée explicite requise) ; radio 2 `primary_1` avec rotation ; radio 3 `fm_secondary`. |
| **OH58D** | 4 (UHF, VHF, FM1, FM2) | Radios 1-2 : slot « M » réservé (`reserved_head_slots: [20]`). Radios 3-4 : slots « C » + « M » (`[1, 20]`). |
| **AJS37** (Viggen) | 1 (V/UHF, 47 slots) | L'entrée la plus complexe : **fusion** `primary_1`+`primary_2` + **`leading_dummy`** (« canal 100 » à 0) + **7 `trailing_specials`** FR22/FR24 (dont GUARD 243). |

Le détail slot-par-slot de chaque type (avec les commentaires expliquant le
pourquoi de chaque choix) vit directement dans
[`dcs-radio-layouts.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/src/python/veaf-tools/presets_injector/data/dcs-radio-layouts.yaml).

## Ajouter ou corriger un type

1. Identifier les radios physiques de l'appareil dans
   [`dcs-radio-specs.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/src/python/veaf-tools/presets_injector/data/dcs-radio-specs.yaml)
   (index, bandes) — voir aussi la table lisible
   [`dcs-radio-specs.md`](../mission-maker/dcs-radio-specs.md).
2. Vérifier si le défaut par bande suffit (souvent oui). Si non, ajouter une
   entrée dans `dcs-radio-layouts.yaml` avec le mapping index → rôle et les
   primitives nécessaires ; commenter chaque radio (nom + bande).
3. Couvrir le comportement par un test dans
   [`test/python/presets_injector/`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/tree/develop-v6/test/python/presets_injector)
   (fidélité de layout, capacité, cas AJS-37…).
