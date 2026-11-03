# Versions d'entraînement par rôle

Une soirée de mission est plus courte quand les pilotes ont déjà volé le cadre.
Avec un bloc `training:` dans `mission.yaml`, le build produit, à côté de la mission de la soirée, des versions d'entraînement sur **le même cadre** : même théâtre, même date et heure, même météo et même vent, mêmes événements scriptés, mêmes plans de vol et mêmes slots.
Chaque version met la mission dans l'état « les autres rôles ont fait leur travail », et ce que le briefing ne précise pas y change à chaque lancement : on s'entraîne sans apprendre par cœur la mission du soir.

## Ce que produit le build {#outputs}

| Fichier | Pour qui | Ce qui change par rapport à la soirée |
|---|---|---|
| `<mission>.miz` | la soirée | rien : c'est la mission définitive |
| `<mission>_TRAINING_A2G.miz` | les pilotes air-sol | ni CAP ennemie, ni QRA, ni SAM longue portée |
| `<mission>_TRAINING_CAP.miz` | les pilotes air-air | plus de cibles A2G, mais toutes leurs défenses aériennes restent ; la QRA est armée dès le départ |
| `<mission>_TRAINING_SEAD.miz` | les pilotes SEAD | ni CAP ennemie, ni QRA, plus de cibles A2G ; les SAM longue portée restent |
| `<mission>_TRAINING_ALL.miz` | l'entraînement commun | rien n'est retiré |

Le briefing est le même pour toutes.
Dans les versions d'entraînement qui les gardent, les éléments décrits de façon vague par le briefing sont tirés au sort à chaque lancement (voir [plus bas](#draws)).

## Classer la mission : `elements` {#elements}

Chaque entrée dit **ce qu'est** un élément de la soirée, avec exactement un sélecteur :

| Sélecteur | Désigne |
|---|---|
| `groups` | des groupes de l'éditeur, par nom exact ou par motif (`"SA-10 *"`) |
| `zone` | une combat zone déclarée dans `modules.COMBATZONE`, avec tous les groupes qu'elle capture |
| `qra` | une QRA déclarée dans `modules.QRA.definitions`, par son `name` |
| `cap_mission` | une CAP à la demande de `cap_missions`, par son `group_name` |

Et un `kind` parmi :

| `kind` | A2G | CAP | SEAD | Commun |
|---|---|---|---|---|
| `enemy_cap` — CAP ennemie, vol IA ou CAP à la demande | retirée | gardée | retirée | gardée |
| `qra` | retirée | gardée et armée | retirée | gardée |
| `sam_lr` — SAM longue portée | retiré | gardé | gardé | gardé |
| `a2g_target` — cible air-sol | gardée | retirée | retirée | gardée |
| `sam_threat` — SAM qui protège une zone A2G, ou objectif secondaire SEAD | gardé | gardé | gardé | gardé |

Un élément que personne ne déclare reste dans toutes les versions.
En CAP, **toute** défense aérienne reste — SAM, radar ou AAA, déclarée ou non, même dans une zone `a2g_target` : une CAP traverse les SAM de la zone quoi qu'aient fait les avions d'attaque.
Un groupe compte comme défense aérienne quand toutes ses unités sont antiaériennes ou de soutien (radar, camion de ravitaillement) : une colonne de chars escortée d'un Tunguska est une cible, et part.
En SEAD, seuls les SAM déclarés restent (`sam_lr`, `sam_threat`) : les autres groupes d'une zone `a2g_target` partent avec ses cibles.

## Les éléments vagues : `randomize` {#draws}

Ce que le briefing précise (type **et** nombre : « 4 chars protégés par un SA-8 ») reste tel quel.
Ce qu'il décrit vaguement (« un SA-6 avec des défenses autour », « une colonne de blindés ») se déclare dans `randomize` : dans les versions d'entraînement, les groupes qu'il remplace quittent leur place, et une combat zone tire à chaque lancement parmi ses candidats.

```yaml
training:
  elements:
    - groups: ["SA-10 Gudauta"]
      kind: sam_lr
    - zone: Factory
      kind: a2g_target
    - groups: ["Factory-SA-6"]
      kind: sam_threat
  randomize:
    - name: factory-def                 # lettres, chiffres, - et _
      replaces: ["Factory-SA-8 *"]      # les groupes figés de la soirée
      pool:
        - group: "Factory-SA-8 #1"      # un groupe de la soirée, repris tel quel
        - command: -sa15                # un raccourci VEAF (list_shortcuts)
        - units: [{type: Strela-10M3, count: 2}]   # un groupe créé à partir de types DCS
      count: 1-2                        # combien en tirer : un nombre ou min-max
      radius: 500-2000                  # dispersion autour de leur position, en mètres
```

Trois sortes de candidats :

- `group` : un des groupes remplacés, **repris tel quel** — type, unités, emport, niveau.
  Il doit figurer dans `replaces`.
- `command` : un raccourci VEAF, porté par une unité du même genre que les groupes remplacés (un SA-8 pour `-sa15`), pour que l'éditeur dessine le bon cercle de menace ; `carrier: <type DCS>` en choisit une autre.
- `units` : un groupe au sol que le build crée à partir de types DCS.

Le tirage se fait **au lancement de la mission**, par les marqueurs de combat zone (`#spawngroup`, `#spawncount`, `#spawnradius`) que le build écrit dans le nom des unités : chaque lancement donne un autre résultat.
Si les groupes remplacés appartiennent déjà à une combat zone de la soirée, le tirage se fait dans cette zone ; sinon le build pose une zone `TRAINING-<name>` autour d'eux, active dès le départ, sans menu radio.
`at: {x, y}` place le tirage ailleurs que sur les groupes remplacés.

Un tirage **est ce qu'il tire**, et suit les règles de ce type d'élément : des blindés tirés dans une zone `a2g_target` sont des cibles A2G, et disparaissent des versions CAP et SEAD avec les groupes qu'ils remplacent.
Par défaut, un tirage prend le type de la combat zone où il vit ; s'il ne remplace que des défenses aériennes (« des défenses autour du SA-6 »), c'est une menace (`sam_threat`) et il reste partout ; hors de toute zone, il reste partout.
`kind:` sur l'entrée donne le type soi-même.

## Ce qui est refusé, et pourquoi {#refusals}

Le build et `validate_mission` refusent le bloc, en nommant chaque problème :

- un sélecteur qui ne désigne rien, une zone, une QRA ou une CAP inconnue ;
- un groupe déclaré deux fois avec deux `kind` différents, ou à la fois classé et tiré au sort ;
- un candidat `group` absent de `replaces`, un raccourci inconnu, un type DCS inconnu ou qui n'est pas une unité au sol ;
- un `count` plus grand que le nombre de candidats ;
- un groupe repris dans un tirage **et nommé ailleurs** — par un script de trigger, un module de `mission.yaml` ou un script de la mission.
  Pour que la zone le capture, le build doit le renommer, ce qui casserait cette référence sans aucun message de DCS ; le garder figé, ou le remplacer par de nouveaux candidats ;
- un groupe repris qui porte un `#veafInterpreter` : sa commande s'exécute une fois au démarrage, il ne reste rien à tirer ;
- `training:` à côté de `build_variants:` : la combinaison donnerait huit missions que personne n'a demandées.

## Construire {#build}

Rien de plus que le build habituel, depuis le dossier de la mission :

```powershell
.\veaf-tools.exe build
```

Le build annonce les cinq missions, puis, pour chaque version d'entraînement, combien de groupes il a retirés et combien de tirages il a posés.
Pour une seule version : `.\veaf-tools.exe build --profile TRAINING_SEAD`.

## Avec l'assistant IA {#with-the-ai}

Dis-lui *« génère aussi les versions d'entraînement »*.
Il propose un classement à partir des données de la mission (`propose_training_plan`), le confronte au briefing pour séparer le précis du vague, te le montre, puis l'écrit (`set_training_plan`) et construit.
Voir le [catalogue des actions](AI_ASSISTANT_CATALOG.md#training-versions).
