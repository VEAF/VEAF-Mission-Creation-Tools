# veafAssets — Ravitailleurs, AWACS et porte-avions

**Module ID:** `ASSETS` | **Fichier:** `veafAssets.lua`

---

## Objectif

Gère les ressources persistantes d'une mission — ravitailleurs, AWACS, JTAC. Fournit des entrées dans le menu radio F10 pour chaque ressource : informations (position, TACAN, fréquence), réapparition après perte, et désactivation optionnelle.

---

## Dépendances

- `veafRadio` — menu F10
- `veafDcsSpawner` / `veafMissionDb` — la réapparition (`veafAssets.respawn`) reconstruit le groupe avec `VeafGroupSpawn`, à partir de la fiche de mission que VEAF indexe au démarrage. MiST n'est **pas** nécessaire (il l'était, via `mist.respawnGroup`).

> ⚠️ **Les assets doivent être des groupes placés dans le Mission Editor.** Le `name` de chaque asset doit correspondre exactement à un groupe présent dans le `.miz` (et chaque entrée `linked`). Un asset spawné dynamiquement ou mal nommé n'est pas dans la base de mission construite par VEAF au démarrage (`veaf.getGroupRecord`) → la réapparition échoue silencieusement en jeu. Le build émet désormais un **avertissement** si un groupe déclaré (ASSETS, QRA, …) est absent de la mission.

---

## Activation

```lua
veafAssets.initialize()
```

Doit être appelé après avoir défini `veafAssets.Assets`.

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

```yaml
modules:
  ASSETS:
    enabled: true          # défaut : true
    logLevel: info        # surcharge optionnelle du niveau de log
    assets:               # liste des ressources persistantes à gérer
      - sort: 1                         # ordre de tri dans le menu F10 (plus petit = premier)
        name: "Texaco"                  # identifiant interne
        description: "Texaco (KC-135)" # libellé affiché dans le menu F10
        information: 'Tacan 51Y\nU251.00 (21)'  # guillemets simples : \n est conservé tel quel → échappement Lua valide
        linked: null                    # nom d'une ressource liée (optionnel)
        jtac: 1688                      # code laser — la ressource est un JTAC qui illumine avec ce code (optionnel)
        freq: null                      # fréquence de remplacement pour l'affichage infos (optionnel)
        mod: null                       # modulation radio (AM | FM, optionnel)
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `enabled` | booléen | `true` | Non | Activer ou désactiver le module |
| `logLevel` | string | *(global)* | Non | Surcharge du niveau de log par module |
| `assets` | objet[] | `[]` | Non | Liste des ressources à gérer |
| `assets[].sort` | entier | `0` | Non | Ordre de tri dans le menu F10 (croissant) |
| `assets[].name` | string | — | Oui | Identifiant interne |
| `assets[].description` | string | — | Oui | Libellé affiché dans le menu F10 |
| `assets[].information` | string | — | Non | Texte d'info affiché aux joueurs — utiliser du YAML entre guillemets simples `'ligne1\nligné2'` ou `"ligne1\\nligne2"` (double-quoté) pour obtenir un `\n` Lua valide |
| `assets[].linked` | string | `null` | Non | Nom d'un groupe à faire réapparaître en même temps que la ressource. ⚠️ Ce n'est **pas** ce qui déclare une escorte — voir [Escorter une ressource](#escorting-an-asset) |
| `assets[].jtac` | nombre | `null` | Non | Code laser : la ressource est un JTAC qui illumine automatiquement avec ce code (nécessite CTLD) |
| `assets[].freq` | nombre | `null` | Non | Fréquence de remplacement pour l'affichage infos (MHz) |
| `assets[].mod` | string | `null` | Non | Modulation radio de remplacement (`AM` ou `FM`) |

> Le groupe DCS référencé par `name` doit exister dans l'éditeur de mission.

### Exemple minimal

```yaml
modules:
  ASSETS:
    enabled: true
    assets:
      - sort: 1
        name: "Texaco"
        description: "Texaco (KC-135)"
        information: "Tacan 51Y\nU251.00 (21)"
      - sort: 2
        name: "Overlord"
        description: "Overlord (E-3A)"
        information: "SRS 251.00"
```

---

## Définir les ressources

Remplir `veafAssets.Assets` avant d'appeler `initialize()` :

```lua
veafAssets.Assets = {
  {
    name        = "KC-135 Texaco",       -- nom du groupe DCS dans la mission
    description = "Texaco (KC-135)",
    information = "Tacan 51Y\nU251.00 (21)",  -- texte des Infos (truthy → ajoute le bouton Infos)
    disposable  = false,   -- permettre aux joueurs de le désactiver
  },
  {
    name        = "KC-130 Arco",
    description = "Arco (KC-130)",
    information = "Tacan 50Y\nU251.50 (22)",
    disposable  = false,
  },
  {
    name        = "E-3A Overlord",
    description = "Overlord (E-3A)",
    information = "SRS 251.00",
    disposable  = false,
  },
}
```

### Champs de la table de ressource

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `name` | string | Oui | Nom du groupe DCS dans la mission (sert aussi d'identifiant interne) |
| `description` | string | Oui | Libellé affiché dans le menu F10 |
| `information` | string | Non | Texte des infos affiché aux joueurs ; non vide → ajoute le bouton Infos |
| `disposable` | boolean | Non | Permettre aux joueurs autorisés de désactiver la ressource |

> Les porte-avions sont gérés par le module séparé [veafCarrierOperations](veafCarrierOperations.md), pas par `veafAssets`.

---

## Escorter une ressource {#escorting-an-asset}

L'escorte d'une ressource est le groupe nommé **`<nom de la ressource> escort`**. Ce nom n'est pas
décoratif : c'est ce qui permet au framework de retrouver l'escorte pour **réparer sa tâche
`Escort`**, que DCS invalide chaque fois que le groupe escorté est recréé — réapparition
(*Respawn*) comme téléportation (`_move tanker … teleport`).

Concrètement : configurez la tâche `Escort` sur **n'importe quel waypoint** de la route de l'escorte,
dans l'éditeur de mission, comme d'habitude. Le reste est automatique.

### Ce que fait une réapparition à une escorte {#respawn-and-escorts}

Faire réapparaître une ressource (**F10 → ASSETS → Respawn**) fait **aussi réapparaître son
escorte**, puis répare la tâche `Escort`. Les deux moitiés sont nécessaires, et aucune ne remplace
l'autre :

- **L'escorte revient avec sa protégée**, parce que la ressource, elle, réapparaît là où l'éditeur de
  mission l'avait posée pendant que son escorte a continué à voler. Mesuré en jeu le 28/08/2026 sur
  le ravitailleur de la mission de démonstration, quelques minutes après une réapparition :
  **78 km et 82 km** entre les deux, une escorte déjà posée au sol — alors que la tâche `Escort`
  déclare un `engagementDistMax` de **60 km**. Réparer la tâche seule ne servait donc à rien : elle
  confiait à l'escorte une protégée hors de sa propre portée d'engagement.
- **La tâche est réparée malgré tout**, parce que ce qui la casse est le changement d'identifiant du
  groupe **escorté**, pas celui de l'escorte.

À savoir : l'escorte qui revient est **neuve**. Une escorte engagée, endommagée ou à court de
carburant est remplacée, exactement comme la ressource elle-même — et une escorte abattue revient
aussi.

> ⚠️ **`linked` n'est pas ce qui fait d'un groupe une escorte.** Les deux mécanismes restent déclarés
> séparément : `linked` liste des groupes quelconques à faire réapparaître en même temps que la
> ressource, alors que la convention de nom est ce qui identifie l'escorte. Une escorte n'a donc pas
> besoin d'être listée dans `linked` : elle réapparaît de toute façon avec sa protégée, et sa tâche
> est réparée. Les deux finissent par avoir le même effet sur l'escorte au moment de la réapparition,
> mais c'est bien la convention de nom — et elle seule — qui permet de réparer la tâche `Escort`.

**Symptôme si le nom ne suit pas la convention** : l'escorte décolle avec sa protégée, tient un
moment, puis **part atterrir au bout d'une dizaine de minutes**. Ce n'est pas un abandon de l'IA :
c'est une escorte dont la tâche pointe vers un groupe qui n'existe plus, qui vole donc sa route
jusqu'au bout puis rentre.

---

## Menu radio F10

Les ressources apparaissent sous **F10 → ASSETS** (les libellés sont en anglais). Une ressource sans `information` ni `disposable` est une simple commande **Respawn [description]** ; sinon un sous-menu est créé avec :

- **Respawn [description]** — fait réapparaître le groupe à sa position d'origine
- **Get info on [description]** — affiche le texte d'information (si `information` est renseigné)
- **Dispose of [description]** — désactive la ressource (si `disposable = true`, commande sécurisée)

---

## Notes

- Le groupe DCS doit exister dans l'éditeur de mission avec exactement le nom utilisé dans `name`
- Les informations du ravitailleur (TACAN, fréquence) sont lues depuis les paramètres de route/waypoint du groupe DCS

---

## Voir aussi

- [veafCarrierOperations](veafCarrierOperations.md) — gestion des récupérations sur porte-avions
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafAssets`
