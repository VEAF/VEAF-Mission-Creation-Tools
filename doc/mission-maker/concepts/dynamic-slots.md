# Slots dynamiques

## Ce que c'est {#what-it-is}

Le *dynamic spawn* de DCS : au lieu de choisir un slot placé à l'avance, le pilote choisit un
terrain et un type d'appareil, et DCS le fait apparaître au parking. Deux fichiers alimentent cela :

- `src/dynamic-slot-templates.yaml` — les **modèles** : un groupe par type d'appareil, marqué
  `dynSpawnTemplate: true`, qui décrit l'appareil servi (emport, livrée, fréquences) ;
- `src/warehouses.yaml` — **quels terrains** ouvrent des slots dynamiques, et avec quel stock.

Les deux sont livrés dans un dossier fraîchement créé : une centaine de modèles, et un
`warehouses.yaml` qui tient en une poignée de lignes utiles.

## Le plus petit exemple qui marche {#minimal-example}

C'est le fichier livré, et il suffit :

```yaml
blue:
  defaults:
    fuel: unlimited
    weapons: unlimited

red:
  defaults:
    fuel: unlimited
    weapons: unlimited
```

Pas de liste `airports:` : **tous** les terrains de la coalition sont concernés. Pas de liste
`aircrafts:` : le stock est déduit automatiquement des modèles présents dans la mission pour cette
coalition. C'est pour ça que le fichier est si court.

Le build met alors, sur chaque terrain retenu, `dynamicSpawn = true`, le démarrage moteur chaud, le
stock, et le lien vers le modèle de chaque type.

## Ce que vous devez faire dans l'éditeur DCS {#in-the-editor}

**Une seule chose : donner le terrain à une coalition.** Sans liste `airports:`, le build ne retient
que les aérodromes dont la coalition correspond au bloc — un aérodrome neutre est donc ignoré, par
décision. Le reste — `dynamicSpawn`, le démarrage à chaud, le stock, les liens vers les modèles —
est écrit par le build ; ne le réglez pas à la main, il serait réécrit.

## Restreindre, si vous voulez {#restrict}

```yaml
blue:
  defaults:
    fuel: unlimited
    weapons: unlimited
    hot_start: false          # démarrage froid uniquement
  airports:
    Senaki-Kolkhi: {}
    Kutaisi:
      aircrafts:
        A-10C_2: { amount: 50 }
```

Dès que `airports:` est là, seuls les terrains listés sont configurés — et leur coalition n'est plus
consultée, c'est votre liste qui décide. Dès qu'un terrain a une liste `aircrafts:`, elle remplace le
choix automatique pour ce terrain.

Le build annonce alors le résultat : « Warehouses : 2 aéroports configurés, 53 liens de modèle ».

## Le piège {#gotcha}

**Les modèles livrés sont un point de départ, pas un catalogue prêt à l'emploi.** DCS sert au pilote
l'appareil *tel que le modèle le décrit*. Sur les modèles fournis par défaut, une petite minorité
seulement porte un emport : un A-10C II sort armé et peint, un UH-1H ou un F/A-18C sortent **nus**.

Pour donner des appareils équipés : configurez-les une fois dans une mission, dans l'éditeur DCS,
puis régénérez le fichier depuis cette mission.

```powershell
veaf-tools.exe extract-aircraft-groups ma-mission.miz --kind dynamic-template
```

!!! note "Le stock est filtré par ce que le terrain peut garer"
    **DCS ne propose que ce que le terrain peut garer**, et le build en tient compte : le stock
    n'est rempli qu'avec ce que le parking de l'aérodrome accepte réellement. Un terrain qui n'a que
    des emplacements hélicoptères ne se voit plus attribuer 149 types d'avions qui n'apparaîtront
    jamais. Le build ne dit rien à ce sujet — ce n'est pas une erreur, c'est le stock qui devient
    juste. Ce filtrage ne s'applique que sur **Caucase, Golfe Persique et Syrie**, les seules cartes
    pour lesquelles les données de parking existent ; partout ailleurs le comportement est inchangé.

## Pour aller plus loin {#more}

- [Référence Pipeline — étape 4, warehouses](../../PIPELINE_REFERENCE.md#pipeline-step-4-warehouses)
- [Référence Pipeline — étape 3, groupes d'aéronefs](../../PIPELINE_REFERENCE.md#pipeline-step-3-aircraft-groups)
- [Référence CLI — `extract-aircraft-groups`](../../CLI_REFERENCE.md#extract-aircraft-groups)
- [Groupes spawnables](spawnables.md) — l'autre famille de groupes d'aéronefs
