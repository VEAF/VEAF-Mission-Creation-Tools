# Slots dynamiques

## Ce que c'est {#what-it-is}

Le *dynamic spawn* de DCS : au lieu de choisir un slot placé à l'avance, le pilote choisit un
terrain et un type d'appareil, et DCS le fait apparaître au parking. Deux fichiers alimentent cela :

- `src/dynamic-slot-templates.yaml` — les **modèles** : un groupe par type d'appareil, marqué
  `dynSpawnTemplate: true`, qui décrit l'appareil servi (emport, livrée, fréquences) ;
- `src/warehouses.yaml` — **quels terrains** ouvrent des slots dynamiques, et avec quel stock.

Le `warehouses.yaml` tient en une poignée de lignes utiles, et il est livré dans un dossier
fraîchement créé. Le catalogue de modèles, lui, n'a pas besoin d'être dans votre dossier : voir
juste en dessous.

## D'où vient le catalogue de modèles {#shipped-catalogue}

Un catalogue de modèles est livré avec veaf-tools, et il grossit à chaque version. Votre dossier
de mission n'en reçoit **pas de copie** : il reçoit un `src/dynamic-slot-templates.yaml` vide, et
le build va lire le catalogue livré. Vous profitez donc automatiquement des modèles ajoutés
depuis, simplement en mettant l'outil à jour.

Trois situations, et une seule règle :

| Votre `src/dynamic-slot-templates.yaml` | Ce que le build injecte |
|---|---|
| absent, ou vide | le catalogue livré, en entier — et le build le dit dans son compte rendu |
| contenant au moins un groupe | **le vôtre, seul** : le catalogue livré n'est plus consulté |
| n'importe lequel des deux, avec `dynamic_slot_templates: false` dans `mission.yaml` | rien |

Autrement dit, un fichier vide veut dire « je n'ajoute rien au catalogue livré », et **pas** « je
ne veux pas de slots dynamiques ». Pour ne rien injecter du tout, c'est `dynamic_slot_templates:
false` sous la clé `pipeline:` de `mission.yaml`, et rien d'autre.

Dès que vous écrivez un seul groupe dans votre fichier, il fait foi tout seul. Rien n'est fusionné
dans votre dos : vos réglages restent exactement ceux que vous avez écrits, même quand une nouvelle
version de l'outil livre un modèle du même nom.

### Récupérer les nouveaux modèles, à la carte {#pull-new-templates}

C'est la contrepartie : votre fichier ne bougera plus jamais tout seul, donc il faut un geste pour
aller chercher les nouveautés. Il est sélectif — vous prenez ce que vous voulez, pas tout.

D'abord voir ce qui manque, ce qui n'écrit rien :

```powershell
.\veaf-tools.exe content pull-aircraft-groups
```

Puis prendre un modèle nommément, ou tous ceux qui manquent :

```powershell
.\veaf-tools.exe content pull-aircraft-groups --add "F-14BU Template"
.\veaf-tools.exe content pull-aircraft-groups --add-new
```

**Un modèle que vous avez déjà n'est jamais remplacé**, même si le catalogue livré en a une version
différente — c'est bien pour ça que la commande existe plutôt qu'une fusion automatique. Le compte
rendu les liste comme conservés, pour que vous sachiez ce qui a été laissé de côté et pourquoi.
Et un modèle que vous avez supprimé exprès reste supprimé tant que vous ne le redemandez pas.

Le même mécanisme vaut pour [les groupes spawnables](spawnables.md) : c'est le même catalogue livré
et la même commande, avec `--kind spawnable`.

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

**Les navires et les FARP sont traités de la même façon**, sans rien écrire de plus : un
porte-avions, un bâtiment porte-hélicoptères ou un FARP de la coalition ouvre ses slots dynamiques
comme un terrain. Chacun reçoit ce qu'il peut réellement accueillir — un porte-avions les avions et
les hélicoptères, un FARP ou une frégate les hélicoptères seuls — et un navire sans pont d'envol,
un pétrolier par exemple, n'est pas touché.

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

Les navires et les FARP se restreignent pareil, avec `ships:` et `farps:`. On les désigne par le
**nom de l'unité** tel qu'il apparaît dans l'éditeur, ou par son identifiant :

```yaml
blue:
  defaults:
    fuel: unlimited
  ships:
    CSG-74 Stennis: {}
  farps:
    FARP Kaspi MM54:
      aircrafts:
        UH-1H: { amount: 20 }
```

**Les trois listes sont indépendantes** : nommer un navire ne dit rien des FARP, qui gardent le
comportement « tous ceux de la coalition ». Si vous voulez restreindre les uns sans ouvrir les
autres, écrivez la liste vide : `farps: {}`.

Le build annonce alors le résultat : « Warehouses : 2 aéroports configurés, 3 navires/FARP, 53 liens
de modèle ».

## Le piège {#gotcha}

**Les modèles livrés sont un point de départ, pas un catalogue prêt à l'emploi.** DCS sert au pilote
l'appareil *tel que le modèle le décrit*. Sur les modèles fournis par défaut, un quart seulement
porte un emport : un A-10C II ou un F/A-18C sortent armés et peints, un UH-1H ou un AV-8B sortent
**nus**.

Pour donner des appareils équipés : configurez-les une fois dans une mission, dans l'éditeur DCS,
puis régénérez le fichier depuis cette mission.

```powershell
.\veaf-tools.exe extract-aircraft-groups ma-mission.miz --kind dynamic-template
```

À partir de là, votre fichier n'est plus vide : il fait foi seul, et le catalogue livré n'est plus
consulté pour cette mission. C'est voulu — vos emports sont vos emports — et
[`pull-aircraft-groups`](#pull-new-templates) est là pour aller rechercher ce qui vous manque.

!!! warning "Deux avertissements à lire"
    Le build signale désormais deux situations qui ne cassent rien et rendent pourtant les slots
    inutilisables. **Un lien de modèle qui ne mène nulle part** : DCS l'affiche en *Group template:
    None* dans le Resource Manager, ce qui ressemble à un choix délibéré. Ils sont le reste d'une
    construction plus ancienne, sur un entrepôt que votre configuration ne cible pas — déclarez la
    coalition concernée, ou nettoyez-les dans l'éditeur. **Des modèles sans nulle part où les
    proposer** : si la mission contient des modèles et qu'aucun terrain, navire ou FARP n'appartient
    à une coalition, aucun slot dynamique ne sortira. C'est le cas d'une mission toute neuve, dont
    tous les aérodromes sont neutres.

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
- [Référence CLI — `pull-aircraft-groups`](../../CLI_REFERENCE.md#pull-aircraft-groups)
- [Groupes spawnables](spawnables.md) — l'autre famille de groupes d'aéronefs
