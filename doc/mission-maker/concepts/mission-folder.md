# Le dossier de mission

## Ce que c'est {#what-it-is}

Un dossier versionnable qui contient **tout** : la mission DCS décompressée, votre configuration,
vos scripts, et les outils. C'est votre unité de travail — le `.miz` n'est plus qu'un produit du
build.

## Le créer {#create-it}

```powershell
veaf-tools.exe prepare --template minimal --theatre Caucasus
```

Douze fichiers apparaissent :

```
ma-mission/
├── mission.yaml                     # la configuration de build
├── src/
│   ├── mission/                     # la mission DCS décompressée (extract l'écrit ici)
│   ├── options                      # la table d'options DCS injectée dans le .miz
│   ├── scripts/
│   │   ├── mission-script.lua       # votre Lua
│   │   └── veafDynamicConfig.lua    # chargement dynamique (dev/test)
│   ├── presets.yaml                 # préréglages radio
│   ├── waypoints.yaml               # plans de vol nommés
│   ├── spawnables.yaml              # groupes d'aéronefs spawnables
│   ├── dynamic-slot-templates.yaml  # modèles de slots dynamiques
│   ├── warehouses.yaml              # stock et slots dynamiques par terrain
│   ├── spawn-groups.yaml            # groupes sol/mer pour `_spawn`
│   └── versions.yaml                # variantes météo/horaire
├── published/                       # scripts et outils VEAF (posés par l'updater)
└── .gitignore
```

`--theatre` pose une mission vierge synthétique dans `src/mission` : le dossier se construit sans
passer par DCS. Sans elle, `src/mission` reste vide et il faut y extraire un `.miz`.

`--template` choisit le jeu de modules du `mission.yaml` généré : `minimal`, `standard`, `full`, ou
`custom` (choix interactif). Sans `--template`, le `mission.yaml` livré par défaut est copié tel
quel.

## Le remplir depuis un `.miz` existant {#from-a-miz}

```powershell
veaf-tools.exe extract ma-mission.miz
```

Le `.miz` est décompressé dans `src/mission/`. L'aller-retour est **rejouable** : ouvrir le `.miz`
construit dans l'éditeur DCS, sauvegarder, ré-extraire, reconstruire ne duplique pas les
déclencheurs VEAF — le build les retire avant de les réinjecter.

## Le piège {#gotcha}

**Le `.miz` produit et les scripts sont résolus depuis le dossier courant, pas depuis l'argument.**
Lancez toujours `veaf-tools.exe` **depuis** le dossier de mission ; lancé d'ailleurs avec le dossier
en argument, il cherche `published/` au mauvais endroit et écrit le `.miz` à côté.

Et `.gitignore` n'est **jamais** écrasé, même avec `--force` : c'est votre fichier.

## Pour aller plus loin {#more}

- [Guide complet — créer une nouvelle mission](../GUIDE.md)
- [Référence CLI — `prepare`](../../CLI_REFERENCE.md#prepare) et [`extract`](../../CLI_REFERENCE.md#extract)
