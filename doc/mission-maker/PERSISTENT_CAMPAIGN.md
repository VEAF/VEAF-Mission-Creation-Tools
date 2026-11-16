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
- **Le front bouge tout seul** : l'ennemi [contre-attaque](#front), renforce ses zones par hélicoptère, et envoie CAP, frappes et [bombardiers](#bombers).
- **L'ennemi paie ce qu'il envoie** avec les [ressources](#resources) que font ses usines : détruire ses [usines](#zone-kinds) ou couper son [réseau d'approvisionnement](#network) finit par clouer sa CAP au sol.
- **La carte est teintée** par camp, chaque zone tenant le [territoire](#territory) le plus proche d'elle, et le front se lit entre les deux couleurs.
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

`campaign next` ajoute aussi au `ctld-config.yaml` de la mission ce que les joueurs transportent pour la campagne : la caisse **« Zone supplies »** (une par camp), le groupe de troupes **« Spy »** (un homme) et le groupe **« Sappers »** (deux hommes, l'[équipe de démolition](#demolition)).
Il impose enfin la vue F10 « fog of war » (`mission.forced_options.f10_view: fog_of_war`) : un pilote ne voit que les ennemis que son camp a détectés, et la force d'une garnison s'apprend par la [reconnaissance](#intel). Une vue déjà choisie dans `mission.yaml` est gardée.

**Pas de commande d'interpréteur dans une campagne persistante.**
Une unité nommée `#veafInterpreter["…"]` dans l'éditeur refait apparaître ses unités à chaque démarrage de la mission : en campagne persistante, elles reviennent neuves après chaque redémarrage du serveur, leurs pertes oubliées, sans que personne les paie.
Ce que la campagne doit tenir se déclare dans `campaign.yaml`, en zone avec sa garnison (une liste explicite `garrison:` si la composition compte) : la zone est sauvegardée avec ses pertes, et le [réseau](#network) la reconstruit aux frais de son camp.
`campaign next` signale les commandes d'interpréteur qu'il trouve dans la mission.

## La sauvegarde {#save}

La mission écrit son état toutes les `save_seconds` (60 s) et en fin de mission dans :

```text
<Saved Games>\DCS\Missions\Saves\<nom de la campagne>\persistent.state
```

Au démarrage, elle relit ce fichier : chaque zone reprend son camp, sa garnison avec ses pertes et sa capture en cours, une usine ses bâtiments debout ou détruits, un aérodrome ses stocks d'armement ; les crédits, les ressources de chaque camp et le renseignement en cours reviennent aussi.
Une zone ajoutée à `campaign.yaml` depuis part de son état déclaré ; une zone retirée est ignorée, et le journal le dit.

Ce qui **n'est pas** repris après un redémarrage : les avions, hélicoptères et convois en route. Ils sont perdus, les zones et les garnisons non ; les survivants d'un convoi payé sur une réserve y retournent.
Ce qui survit rentre au bercail : un convoi d'assaut, un spawn payé encore debout ou une livraison du réseau en route au moment de l'arrêt rendent leur prix aux ressources de leur camp au chargement suivant.

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
  Livrent : une caisse « Zone supplies » posée dans la zone, des troupes CTLD 2 déposées dans la zone (sauf l'équipe espion et les équipes JTAC), un hélicoptère de ravitaillement posé.
- **Hélicoptères IA** : toutes les `supply_seconds` (600 s), un camp listé dans `supply` (le rouge par défaut) envoie un hélicoptère (`helicopter`, Mi-8MT rouge, UH-1H bleu) vers une zone neutre qui le borde, qu'il prend en s'y posant, ou à défaut vers sa zone la plus abîmée, qu'il ravitaille ; `max_helicopters` (2) en vol au plus, et un hélicoptère qui ne s'est pas posé au bout de `helicopter_timeout` (1 200 s) est retiré.

## L'aviation ennemie {#air}

- **CAP** : l'ennemi tient en l'air une CAP par tranche de `air.cap_per_players` (3) joueurs du [niveau d'opposition](scripts/veafQraManager.md#opposition-level), au moins une, au-dessus de sa zone du front la plus proche des joueurs.
- **Frappes** : toutes les `air.strike_seconds` (900 s), une frappe CAS (sur la zone qui a le plus d'unités) ou SEAD (sur celle qui a le plus de défense antiaérienne), en alternance, sur une zone qui borde le territoire ennemi.
- Elles **décollent** de l'aérodrome ennemi le plus proche, moteur chaud sur des parkings libres, ou de la piste quand il n'y en a pas assez ; sans aérodrome, pas de sortie. Il en va de même pour la CAP, la BARCAP et le Hunter.
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
| BARCAP | une CAP de notre camp tenue devant une zone ennemie, hors de portée de ses défenses, pour couvrir les hélicoptères et les avions qui vont la frapper | 400 |
| Hélico de capture | un hélicoptère qui va prendre une zone neutre | 250 |
| Hélico de ravitaillement | un hélicoptère qui va ravitailler une de nos zones abîmées | 200 |
| Raid de bombardiers | un [bombardier](#bombers) escorté qui bombarde une zone ennemie, ses bâtiments d'abord | 1200 |
| Ravitailleur | fait réapparaître le ravitailleur que nomme `economy.tanker` (un asset de la mission) ; absent sans lui | 300 |

La BARCAP se tient sur l'axe entre la zone ennemie et notre aérodrome le plus proche, à la portée de ses défenses plus 15 km, et garde un cercle de 15 km.
La portée se mesure sur les missiles que portent les unités de la zone quand elle est éveillée ; une zone endormie est supposée porter à 75 km si sa classe a un SAM longue portée, 20 km sinon, et le message le dit.

Les prix se changent dans `economy.prices` (`jtac`, `illumination`, `smoke`, `intel`, `cap`, `barcap`, `capture`, `resupply`, `bomber`, `tanker`, et `assault` pour l'ordre d'assaut de F10 → Campagne → Assaut, 300).
Ce que les joueurs achètent se paie en crédits, jamais sur les [ressources](#resources).

## Le tableau des tâches {#tasks}

F10 → Autres → Campagne → **Tâches** : `tasks.count` (3) tâches à la fois, tirées de la situation et complétées toutes les `tasks.refresh_seconds` (300 s), chacune marquée sur la carte de notre camp.

| Tâche | Accomplie quand | Récompense |
|---|---|---|
| Attaquer la zone ennemie la plus faible du front | elle n'est plus à l'ennemi | 300 |
| Prendre une zone neutre qui nous borde | elle est à nous | 300 |
| Ravitailler notre zone la plus abîmée | elle est au complet | 200 |
| Supériorité aérienne | `tasks.air_kills` (2) aéronefs abattus | 200 |
| Intercepter les bombardiers ennemis en route | le bombardier est abattu ; retirée s'il rentre | 400 |

Une tâche dont la cible est passée à l'ennemi est retirée, sans récompense.

## Le renseignement {#intel}

La garnison d'une zone ennemie est **inconnue** des joueurs (« force inconnue » sur la carte) jusqu'à ce qu'elle soit reconnue, pour `intel.seconds` (une heure) :

- par un **survol** : un avion de joueur dans le cercle de la zone, à moins de `intel.overflight_altitude` (1 500 m) du sol ;
- par un **drone JTAC** ou du **renseignement** acheté à la boutique ;
- par une **équipe espion** : le groupe de troupes CTLD 2 « Spy » déposé à moins de `intel.spy_range` (5 km) d'une zone ennemie y marche tout seul, et la révèle en y entrant.

Une zone reconnue affiche sa force sur la carte, et F10 → Autres → Campagne → **Renseignement** donne sa composition, défense antiaérienne en tête.
`intel.hidden: false` montre toutes les garnisons à tout le monde.

## Usines et dépôts {#zone-kinds}

Une zone se déclare d'une sorte, `kind:`, en plus de son emplacement :

| Sorte | Comment elle se joue |
|---|---|
| aucune, sur un aérodrome | un **aérodrome** : il se prend, ses slots suivent |
| aucune, sur un point | un **avant-poste** : une garnison |
| `factory` | une **usine** : quelques bâtiments et une petite garnison ; elle fait les [ressources](#resources) de son camp tant que ses bâtiments tiennent |
| `depot` | un **dépôt** : il accélère le [réseau d'approvisionnement](#network) et en garde une réserve |

```yaml
zones:
  - { name: Tkibuli, at: { lat: 42.350, lon: 42.998 }, size: outpost, side: red, kind: factory }
  - { name: Samtredia, at: { lat: 42.165, lon: 42.335 }, size: outpost, side: red, kind: depot }
```

Les bâtiments d'une usine se tirent une fois, au premier démarrage : `factory.buildings` (3) parmi `factory.types` (`Workshop A`, `Tech combine`, `Tech hangar A`), alignés à 60 m l'un de l'autre sur un terrain dégagé de la zone.
Ce sont des statics : ils restent dans le monde même quand la zone dort.
La carte compte ceux qui tiennent, « usine 2/3 ».
On les détruit à la bombe ou avec l'[équipe de démolition](#demolition) ; une usine se prend aussi comme n'importe quelle zone, et ce qui en tient travaille alors pour son nouveau camp.
Une livraison (caisse, troupes, hélicoptère) dans une usine dont la garnison est complète relève un bâtiment.

## Les ressources de l'IA {#resources}

Chaque camp a **un stock de points de ressources** (`resources.start`, 500), sauvegardé avec la campagne, et **tout ce que l'IA met en jeu se paie dessus** au prix de ses unités : la garnison d'une zone prise, un renforcement par le [réseau](#network), un convoi d'assaut, un hélicoptère de ravitaillement, une CAP, une frappe, le Hunter, un [raid de bombardiers](#bombers).
Un stock vide n'envoie plus rien : une sortie ne part que si le stock reste au-dessus de `resources.reserve` (100) une fois payée, pour que l'IA garde de quoi relever ses zones.
Une zone prise que son camp ne peut pas payer reçoit une garnison symbolique.

**La production** s'ajoute à chaque battement : une production de fond, `resources.background_per_hour` (30 points par heure), même sans usine, de quoi tenir tout juste une base ; et chaque usine, `factory.per_hour` (120) multiplié par la part de ses bâtiments debout.

**Le prix d'une unité** se lit dans la base des unités de DCS, d'après ce qu'elle est :

| Unité | Points |
|---|---|
| fantassin | 1 |
| véhicule non armé | 2 |
| blindé de transport, véhicule de combat d'infanterie | 4 |
| char | 6 |
| artillerie | 5 |
| AAA, défense courte portée | 4 |
| SAM courte portée | 8 |
| élément de SAM moyenne ou longue portée | 15 |
| hélicoptère | 15 |
| avion | 30 |
| bombardier | 100 |
| tout le reste | 5 |

`resources.prices` change le prix d'un type : `{ "T-72B": 7 }`.
Ce sont des valeurs de départ, qui se régleront sur un serveur : une usine paie à peu près une contre-attaque et une CAP par heure.

Les crédits restent ceux des joueurs : ce qu'ils achètent ne sort pas des ressources, et ce qui survit d'un achat s'y ajoute au chargement suivant.
`resources.enabled: false` rend l'IA gratuite et illimitée, comme avant.

## Le réseau d'approvisionnement {#network}

Les usines d'un camp nourrissent ses zones de proche en proche, le long des liaisons, et seulement à travers les zones du camp : une zone ennemie ou neutre coupe le chemin, et le reste du réseau est servi par un détour, plus tard.

- **Un saut** d'une zone à la suivante prend `network.hop_seconds` (600 s) ; **un saut qui touche un dépôt** la moitié : usine → base → base fait deux sauts pleins, usine → dépôt → base un seul.
- **Un dépôt** garde une réserve de `network.depot_store` (4) livraisons, pleine tant qu'une usine l'atteint : coupé de ses usines, il nourrit encore les zones autour de lui le temps de la vider.
- **Une zone abîmée**, d'un camp comme de l'autre, commande une livraison, payée sur les ressources à la commande ; son premier groupe touché revient au complet après le délai de la zone ; `network.max_deliveries` (3) livraisons d'un camp en route à la fois. Une zone perdue entre-temps ne reçoit rien.
  Les joueurs qui font de la logistique vont plus vite : une caisse, des troupes ou un hélicoptère renforcent sur-le-champ, sans attendre le réseau ni le payer.
- **Une zone coupée** de toute usine et de tout dépôt est encore servie, sur la production de fond, au bout de `network.isolated_seconds` (3 600 s).

F10 → Campagne → **Réseau d'approvisionnement** donne aux joueurs leur stock, leur production, et pour chacune de leurs zones son délai ou « coupée du réseau ».

## Les spawns payants {#paid-spawns}

Dans une campagne persistante, toute commande de spawn VEAF qu'une personne pose en marqueur — `_spawn`, `-armor`, `-cap`, un convoi, une caisse, game masters compris — se paie :

- **en crédits** quand elle fait apparaître des unités pour le camp des joueurs ;
- **sur les ressources** de l'autre camp sinon ;
- au prix de sa catégorie, `economy.spawn_prices` ;
- refusée avec un message qui dit ce qu'elle coûte et ce qui reste quand le camp ne peut pas payer : rien n'est débité, rien n'apparaît.

| Commande | Prix | | Commande | Prix |
|---|---|---|---|---|
| `unit` | 100 | | `convoy` | 300 |
| `group` | 150 | | `cap` | 400 |
| `infantryGroup` | 50 | | `afac` | 300 |
| `armoredPlatoon` | 150 | | `awacs` | 500 |
| `airDefenseBattery` | 250 | | `escort` | 400 |
| `transportCompany` | 100 | | `farp` | 200 |
| `fullCombatGroup` | 400 | | `fob` | 300 |
| `cargo` | 50 | | `logistic` | 100 |

Fumigènes, fusées, dessins, destruction, téléportation et mission master restent gratuits ; une catégorie mise à 0 aussi.
Ce qu'un script fait apparaître (une combat zone, une commande que l'interpréteur lit dans un nom posé dans l'éditeur, les sorties de la campagne elle-même) n'est pas l'action d'une personne et ne se paie pas ici.

## L'équipe de démolition {#demolition}

Le groupe de troupes CTLD 2 **« Sappers »** (`demolition.troops`), déposé par le camp des joueurs, marche vers l'usine ennemie dont les bâtiments sont à moins de `demolition.range` (5 km) de son point de dépose.
Arrivé à 200 m des bâtiments, il pose ses charges sur tous ceux qui tiennent, le dit, et repart vers son point de dépose.
Les charges sautent `demolition.fuse` (120 s) plus tard, même si l'équipe a été tuée entre-temps.
Chaque bâtiment détruit rapporte `economy.demolition` (50) crédits, et l'usine produit d'autant moins.
Sans usine ennemie à portée, l'équipe le dit et reste sur place.

## Les stocks d'armement {#warehouses}

Les stocks d'armement de chaque aérodrome de la campagne, lus à chaque sauvegarde, sont remis à l'identique au redémarrage ; un stock illimité est laissé tel quel.
La campagne ne rend aucun entrepôt limité ni illimité : c'est le choix de l'éditeur de mission.

Les joueurs déplacent du stock d'un terrain à l'autre, en hélicoptère ou en avion de transport :

1. posé sur un aérodrome de la coalition, F10 → Campagne → Entrepôt → **Charger de l'armement** prend `warehouse.load` (10) de chaque arme de l'entrepôt (moins s'il en a moins) ;
2. posé sur un **autre** aérodrome de la coalition, **Décharger l'armement** dépose exactement ce qui est à bord, et rapporte `economy.warehouse_delivery` (50) crédits, une fois par terrain pour chaque vol ;
3. **Armement à bord** dit ce qu'on transporte.

Le chargement est perdu avec l'appareil, et avec le serveur : il n'est pas sauvegardé.
`warehouse.enabled: false` retire le menu et la remise des stocks.

## Les bombardiers stratégiques {#bombers}

Toutes les `bombers.seconds` (3 600 s), l'ennemi envoie un raid de bombardiers escorté, payé sur ses ressources, sur la zone des joueurs qui a le plus à frapper : une usine d'abord, sinon la zone qui a le plus d'unités.
Il part en vol de l'aérodrome ennemi le plus proche de la cible qui en est au moins à `bombers.min_distance` (80 km), pour laisser aux joueurs le temps d'intercepter ; l'escorte, ce sont ses avions de CAP.
Les joueurs en sont prévenus aussitôt, et le [tableau des tâches](#tasks) affiche une tâche d'interception.
Un seul raid d'un camp en l'air à la fois.

Les joueurs achètent le leur à la [boutique](#shop) : **Raid de bombardiers**, sur une zone ennemie.

Les bombardiers se déclarent comme les autres avions, rôle `bomber` :

```yaml
dynamic:
  air:
    red:
      bomber: { type: Tu-22M3, loadout: "FAB-250*33", count: 1 }
    blue:
      bomber: { type: B-1B, loadout: "Mk-82*84", count: 1 }
```

## Le territoire {#territory}

Chaque zone tient la part de la carte plus proche d'elle que de toute autre zone (sa cellule de Voronoï), teintée sur la carte F10 de la couleur de son camp, gris pour une zone neutre ; une ligne sombre court entre deux cellules de camps différents : c'est le front.
La carte ne se redessine que quand une zone change de camp.
`territory.margin` (70 km) prolonge les cellules au-delà des zones du bord ; `territory.enabled: false` retire la teinte.

## Contrôler une mission en jeu {#self-check}

F10 → Autres → Campagne → **Auto-contrôle (admin)** affiche une ligne `OK` ou `KO` par mécanisme : zones placées, sauvegarde relue et écrite, issue, dormance, captures, usines, territoire, ressources des deux camps, réseau (livraisons et zones coupées), spawns payants, sapeurs, entrepôts, hélicoptères, aviation, bombardiers, crédits, tâches, renseignement.
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
| `economy` | voir [la boutique](#shop) | `start_credits`, `kill_ground`, `kill_air`, `capture`, `delivery`, `prices`, `tanker`, `spawn_prices`, `demolition` (50), `warehouse_delivery` (50) |
| `tasks` | voir [les tâches](#tasks) | `count`, `refresh_seconds`, `air_kills`, `rewards` (`attack`, `capture`, `resupply`, `air`, `intercept`) |
| `intel` | voir [le renseignement](#intel) | `hidden`, `seconds`, `overflight_altitude`, `spy_troops`, `spy_range` |
| `resources` | voir [les ressources](#resources) | `enabled` (true), `start` (500), `background_per_hour` (30), `reserve` (100), `prices` |
| `factory` | voir [les usines](#zone-kinds) | `buildings` (3), `per_hour` (120), `types` |
| `network` | voir [le réseau](#network) | `hop_seconds` (600), `isolated_seconds` (3600), `depot_store` (4), `max_deliveries` (3) |
| `demolition` | voir [la démolition](#demolition) | `troops` (`Sappers`), `range` (5000), `fuse` (120) |
| `warehouse` | voir [les stocks](#warehouses) | `enabled` (true), `load` (10) |
| `bombers` | voir [les bombardiers](#bombers) | `enabled` (true), `seconds` (3600), `min_distance` (80000) |
| `territory` | voir [le territoire](#territory) | `enabled` (true), `margin` (70000) |

Les plafonds sont prudents par défaut ; ils se règleront d'après ce que tiennent les serveurs.

## Ce qui reste à vérifier en jeu {#to-verify}

Ces points sont écrits et testés hors de DCS, pas encore mesurés en jeu :

- un hélicoptère IA qui se pose dans une zone (les pièges connus de DCS sur un poser scripté sont dans [les pièges du runtime DCS](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/agents/dcs-runtime-traps.md)) ;
- les avions qui décollent d'un parking libre (le stand donné par `getParking()` est-il celui où DCS les pose ?) ;
- les frappes CAS et SEAD et leur retour ;
- l'équipe espion qui marche jusqu'à sa zone ;
- la disparition et la réapparition d'une garnison au passage d'un joueur ;
- les bâtiments d'une usine posés sur un terrain dégagé, et relevés sous le drapeau du preneur ;
- la tâche `Bombing` du bombardier et l'escorte qui le suit ;
- les charges des sapeurs, assez fortes pour un bâtiment, et l'équipe hors de leur souffle ;
- les stocks d'un entrepôt illimité, que `getInventory` rapporte peut-être sans les compter ;
- la teinte du territoire, faite de triangles, sur la carte F10.

Voir aussi la [référence du module `veafCampaign`](scripts/veafCampaign.md).
