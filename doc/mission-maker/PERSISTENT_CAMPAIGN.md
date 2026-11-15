# Campagne persistante

> Une seule mission qui tourne sur un serveur des semaines durant, dans l'esprit de Foothold : des zones qui changent de camp, un front qui bouge tout seul, l'aviation ennemie, des crédits à dépenser, et une sauvegarde qui reprend là où le serveur s'est arrêté.
> Tout est bâti sur les outils et les scripts VEAF, sans Moose.
> C'est l'autre mode de la [campagne multi-missions](CAMPAIGN.md) : même `campaign.yaml`, mêmes zones, mêmes garnisons, mais la campagne avance pendant le vol et non entre deux missions.

## Ce que voient les joueurs {#players}

- **La carte F10** montre chaque zone en cercle de la couleur de son camp, son nom et l'état de sa garnison, et les liaisons entre zones.
  Une zone ennemie affiche « force inconnue » tant qu'elle n'a pas été [reconnue](#intel).
- **Une zone ne change jamais de camp directement** : quand sa garnison est détruite, elle devient **neutre** (grise).
  Une zone neutre se prend en y tenant le terrain : des unités au sol d'un seul camp y restent `capture_seconds` (120 s par défaut) — troupes ou caisse CTLD 2, convoi, groupe `_spawn`, véhicule Combined Arms, hélicoptère **posé**.
  La nouvelle garnison apparaît aussitôt.
- **Les slots suivent les bases** : un aérodrome pris passe dans le camp du preneur, avec ses slots dynamiques.
- **Le front bouge tout seul** : l'ennemi [contre-attaque](#front), renforce ses zones par hélicoptère, et envoie CAP et frappes.
- **Le menu F10 → Autres → Campagne** donne la situation, les crédits, les tâches, le renseignement et la boutique.
- **La partie se termine** quand un camp ne tient plus aucune zone : victoire si c'est l'ennemi, défaite si c'est nous.
  C'est annoncé à tous, et la campagne repart de zéro au prochain chargement de la mission.

## Déclarer une campagne persistante {#declare}

C'est un `campaign.yaml` de [campagne multi-missions](CAMPAIGN.md#declare) avec `mode: persistent`, et, au besoin, un bloc `dynamic:`.
Les objectifs et le nombre de missions n'y servent pas : la victoire, c'est de tenir toutes les zones.

```yaml
campaign:
  name: Front de Géorgie
  theatre: Caucasus
  era: MODERN
  mode: persistent
  player_side: blue

zones:
  - { name: Kobuleti, at: { airfield: Kobuleti }, size: airfield, side: blue, radius: 3000 }
  - { name: Poti, at: { lat: 42.155, lon: 41.705 }, size: outpost, side: neutral }
  - { name: Senaki, at: { airfield: Senaki-Kolkhi }, size: airfield, side: red, radius: 3000 }

connections:
  - [Kobuleti, Poti]
  - [Poti, Senaki]

dynamic:            # tout est facultatif : chaque clé a sa valeur par défaut, ci-dessous
  wake_radius: 60000
  economy:
    start_credits: 500
```

Un exemple complet, prêt à copier, est livré avec les outils : [`src/defaults/campaign-folder-persistent/campaign.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/src/defaults/campaign-folder-persistent/campaign.yaml).

Sans bloc `sides:`, un camp ne compte pas de réserve : ses garnisons se tirent sans limite.
Avec une réserve, elle se vide comme en campagne multi-missions, et un camp à sec n'aligne plus que des garnisons symboliques.

### Construire la mission {#build}

```powershell
.\veaf-tools.exe campaign init C:\Campagnes\Georgie
.\veaf-tools.exe campaign next C:\Campagnes\Georgie
```

Puis on construit la mission du dossier `missions\mission-01\mission` comme n'importe quelle mission, et on la met sur le serveur.
`campaign next` relancé sur le même dossier la met à jour sans toucher au reste du travail fait dedans.
`campaign apply` n'a pas d'usage ici : il n'y a pas de « entre deux missions ».

`campaign next` ajoute aussi au `ctld-config.yaml` de la mission ce que les joueurs transportent pour la campagne : la caisse **« Zone supplies »** (une par camp) et le groupe de troupes **« Spy »** (un homme).

## La sauvegarde {#save}

La mission écrit son état toutes les `save_seconds` (60 s) et en fin de mission dans :

```text
<Saved Games>\DCS\Missions\Saves\<nom de la campagne>\persistent.state
```

Au démarrage, elle relit ce fichier : chaque zone reprend son camp, sa garnison avec ses pertes et sa capture en cours ; les crédits et le renseignement en cours reviennent aussi.
Une zone ajoutée à `campaign.yaml` depuis part de son état déclaré ; une zone retirée est ignorée, et le journal le dit.

Ce qui **n'est pas** repris après un redémarrage : les avions, hélicoptères et convois en route. Ils sont perdus, les zones et les garnisons non.

Le fichier est un tableau Lua lu sans aucun accès : il ne peut rien exécuter.
Il faut que `io` et `lfs` soient ouverts dans le `MissionScripting.lua` du serveur, ce qui est le cas sur les serveurs VEAF.
Sans eux, la campagne tourne quand même, mais ne se sauvegarde pas, et le dit une fois.

**Remettre à zéro** : F10 → Autres → Campagne → **Remettre la campagne à zéro (admin)**.
La campagne repart de son état déclaré au prochain chargement de la mission ; une victoire ou une défaite fait la même chose.

## Les zones en sommeil {#dormancy}

Loin des joueurs, une zone n'a aucune unité dans le monde : sa garnison n'est qu'une ligne de la sauvegarde, avec ses pertes.
Elle apparaît quand un avion de joueur arrive à moins de `wake_radius` (60 km) ou qu'une sortie la vise, exactement comme elle était, et disparaît quand personne n'est venu depuis `sleep_seconds` (600 s).
Au plus `max_awake_zones` (12) zones sont éveillées à la fois, les plus proches des joueurs d'abord, et une seule se réveille à chaque battement de 10 s, pour ne pas faire apparaître tout le front d'un coup.

## Un front qui bouge tout seul {#front}

- **Contre-attaques** : toutes les `attack_seconds` (900 s), un camp listé dans `attacks` (le rouge par défaut) envoie un convoi d'assaut contre la zone ennemie la plus faible qui le borde, `max_convoys` (2) sur la route au plus.
- **Ravitaillement** : une livraison dans une zone amie abîmée ramène au complet son premier groupe touché.
  Livrent : une caisse « Zone supplies » posée dans la zone, des troupes CTLD 2 déposées dans la zone, un hélicoptère de ravitaillement posé.
- **Hélicoptères IA** : toutes les `supply_seconds` (600 s), un camp listé dans `supply` (le rouge par défaut) envoie un hélicoptère (`helicopter`, Mi-8MT rouge, UH-1H bleu) vers une zone neutre qui le borde, qu'il prend en s'y posant, ou à défaut vers sa zone la plus abîmée, qu'il ravitaille ; `max_helicopters` (2) en vol au plus, et un hélicoptère qui ne s'est pas posé au bout de `helicopter_timeout` (1 200 s) est retiré.

## L'aviation ennemie {#air}

- **CAP** : l'ennemi tient en l'air une CAP par tranche de `air.cap_per_players` (3) joueurs du [niveau d'opposition](scripts/veafQraManager.md#opposition-level), au moins une, au-dessus de sa zone du front la plus proche des joueurs.
- **Frappes** : toutes les `air.strike_seconds` (900 s), une frappe CAS (sur la zone qui a le plus d'unités) ou SEAD (sur celle qui a le plus de défense antiaérienne), en alternance, sur une zone qui borde le territoire ennemi.
- Elles partent de l'aérodrome ennemi le plus proche ; sans aérodrome, pas de sortie.
  `air.max_flights` (4) vols en l'air au plus par camp.
- **Hunter** : un joueur qui enchaîne les victoires (entre 8 et 16 au sol, ou entre 4 et 8 en l'air, tiré une fois par vie) a ensuite 10 % de chances à chaque victoire de voir décoller deux chasseurs ennemis contre ce joueur ; son camp est prévenu.

Les avions se déclarent par type et chargement **par son nom** dans l'éditeur de mission ; les outils vérifient l'un et l'autre et en tirent les pylônes, si bien que la mission n'a besoin d'aucun modèle d'avion.

```yaml
dynamic:
  air:
    red:
      cap:  { type: MiG-29A, loadout: "R-73*2,R-60M*2,R-27R*2", count: 2 }
      cas:  { type: Su-25, loadout: "FAB-250*4,UB-13*2,R-60M*2,Fuel*2", count: 2 }
      sead: { type: MiG-27K, loadout: "Kh-25MPU*2,R-60M*2,Fuel", count: 2 }
    blue:
      cap:  { type: F-15C, loadout: "AIM-9*2,AIM-120*2,AIM-7*4,Fuel*3", count: 2 }
```

Ce sont les valeurs par défaut, faites pour l'ère `MODERN` : une campagne d'une autre ère déclare les siens.
Un chargement inconnu est refusé par `campaign validate`, avec la liste des chargements du type.

## Crédits et boutique {#shop}

La coalition des joueurs a un compte, sauvegardé avec la campagne : `economy.start_credits` (500) au départ.

| Gain | Réglage | Par défaut |
|---|---|---|
| un joueur détruit une unité au sol | `economy.kill_ground` | 10 |
| un joueur abat un aéronef | `economy.kill_air` | 30 |
| une zone prise | `economy.capture` | 200 |
| une livraison dans une zone amie | `economy.delivery` | 100 |
| une [tâche](#tasks) accomplie | `tasks.rewards` | 200 à 300 |

F10 → Autres → Campagne → **Boutique** : chaque article donne la liste des zones auxquelles il s'applique.
Un achat refusé (plus de cible, rien à portée) ne coûte rien.

| Article | Effet | Prix |
|---|---|---|
| Drone JTAC | un MQ-9 au-dessus d'une zone ennemie, qui désigne au laser (code 1688) ; la zone est aussi reconnue | 300 |
| Éclairage | des fusées éclairantes au-dessus d'une zone | 50 |
| Fumigènes sur cibles | de la fumée rouge sur trois unités d'une zone ennemie | 50 |
| Renseignement | la composition d'une zone ennemie pour une heure | 150 |
| CAP amie | une CAP de notre camp au-dessus d'une de nos zones | 400 |
| Hélico de capture | un hélicoptère qui va prendre une zone neutre | 250 |
| Hélico de ravitaillement | un hélicoptère qui va ravitailler une de nos zones abîmées | 200 |
| Ravitailleur | fait réapparaître le ravitailleur que nomme `economy.tanker` (un asset de la mission) ; absent sans lui | 300 |

Les prix se changent dans `economy.prices` (`jtac`, `illumination`, `smoke`, `intel`, `cap`, `capture`, `resupply`, `tanker`).

## Le tableau des tâches {#tasks}

F10 → Autres → Campagne → **Tâches** : `tasks.count` (3) tâches à la fois, tirées de la situation et complétées toutes les `tasks.refresh_seconds` (300 s), chacune marquée sur la carte de notre camp.

| Tâche | Accomplie quand | Récompense |
|---|---|---|
| Attaquer la zone ennemie la plus faible du front | elle n'est plus à l'ennemi | 300 |
| Prendre une zone neutre qui nous borde | elle est à nous | 300 |
| Ravitailler notre zone la plus abîmée | elle est au complet | 200 |
| Supériorité aérienne | `tasks.air_kills` (2) aéronefs abattus | 200 |

Une tâche dont la cible est passée à l'ennemi est retirée, sans récompense.

## Le renseignement {#intel}

La garnison d'une zone ennemie est **inconnue** des joueurs (« force inconnue » sur la carte) jusqu'à ce qu'elle soit reconnue, pour `intel.seconds` (une heure) :

- par un **survol** : un avion de joueur dans le cercle de la zone, à moins de `intel.overflight_altitude` (1 500 m) du sol ;
- par un **drone JTAC** ou du **renseignement** acheté à la boutique ;
- par une **équipe espion** : le groupe de troupes CTLD 2 « Spy » déposé à moins de `intel.spy_range` (5 km) d'une zone ennemie y marche tout seul, et la révèle en y entrant.

Une zone reconnue affiche sa force sur la carte, et F10 → Autres → Campagne → **Renseignement** donne sa composition, défense antiaérienne en tête.
`intel.hidden: false` montre toutes les garnisons à tout le monde.

## Contrôler une mission en jeu {#self-check}

F10 → Autres → Campagne → **Auto-contrôle (admin)** affiche une ligne `OK` ou `KO` par mécanisme : zones placées, sauvegarde relue et écrite, issue, dormance, captures, hélicoptères, aviation, crédits, tâches, renseignement.
Une ligne `KO` suffit à dire où regarder.

## Tous les réglages {#settings}

| Clé de `dynamic:` | Par défaut | Ce qu'elle règle |
|---|---|---|
| `save_seconds` | 60 | intervalle entre deux sauvegardes |
| `wake_radius` | 60000 | mètres : un joueur aussi près réveille une zone |
| `sleep_seconds` | 600 | une zone sans joueur près d'elle depuis ce temps se rendort |
| `max_awake_zones` | 12 | zones éveillées à la fois |
| `attacks` | `[red]` | les camps qui contre-attaquent seuls |
| `attack_seconds` | 900 | intervalle entre deux contre-attaques d'un camp |
| `max_convoys` | 2 | convois d'assaut d'un camp sur la route |
| `supply` | `[red]` | les camps dont les hélicoptères IA capturent et ravitaillent |
| `supply_seconds` | 600 | intervalle entre deux hélicoptères d'un camp |
| `max_helicopters` | 2 | hélicoptères de ravitaillement d'un camp en vol |
| `helicopter_timeout` | 1200 | un hélicoptère pas posé au bout de ce temps est retiré |
| `helicopter` | `{red: Mi-8MT, blue: UH-1H}` | le type de l'hélicoptère de chaque camp |
| `supply_crate` | `Zone supplies` | le nom de la caisse CTLD 2 qui ravitaille |
| `hunter` | `{enabled: true, ground_kills: 8, air_kills: 4, chance: 10}` | le Hunter |
| `air` | voir [l'aviation ennemie](#air) | `strike_seconds` (900), `max_flights` (4), `cap_per_players` (3), et les avions de chaque camp |
| `economy` | voir [la boutique](#shop) | `start_credits`, `kill_ground`, `kill_air`, `capture`, `delivery`, `prices`, `tanker` |
| `tasks` | voir [les tâches](#tasks) | `count`, `refresh_seconds`, `air_kills`, `rewards` (`attack`, `capture`, `resupply`, `air`) |
| `intel` | voir [le renseignement](#intel) | `hidden`, `seconds`, `overflight_altitude`, `spy_troops`, `spy_range` |

Les plafonds sont prudents par défaut ; ils se règleront d'après ce que tiennent les serveurs.

## Ce qui reste à vérifier en jeu {#to-verify}

Ces points sont écrits et testés hors de DCS, pas encore mesurés en jeu :

- un hélicoptère IA qui se pose dans une zone (les pièges connus de DCS sur un poser scripté sont dans [les pièges du runtime DCS](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/agents/dcs-runtime-traps.md)) ;
- les frappes CAS et SEAD lancées en l'air au-dessus de leur terrain, et leur retour ;
- l'équipe espion qui marche jusqu'à sa zone ;
- la disparition et la réapparition d'une garnison au passage d'un joueur.

Voir aussi la [référence du module `veafCampaign`](scripts/veafCampaign.md).
