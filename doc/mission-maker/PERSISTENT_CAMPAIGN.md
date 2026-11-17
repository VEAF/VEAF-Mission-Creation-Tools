# Campagne persistante

> Une seule mission qui tourne sur un serveur des semaines durant, dans l'esprit de Foothold : des zones qui changent de camp, un front qui bouge tout seul, l'aviation ennemie, des crédits à dépenser, et une sauvegarde qui reprend là où le serveur s'est arrêté.
> Tout est bâti sur les outils et les scripts VEAF, sans Moose.
> C'est l'autre mode de la [campagne multi-missions](CAMPAIGN.md) : même `campaign.yaml`, mêmes zones, mêmes garnisons, mais la campagne avance pendant le vol et non entre deux missions.

## Ce que voient les joueurs {#players}

- **La carte F10** montre chaque zone en cercle de la couleur de son camp, son nom, le numéro de son [waypoint](#waypoints) et l'état de sa garnison, et les liaisons entre zones.
  Une zone ennemie affiche « force inconnue » tant qu'elle n'a pas été [reconnue](#intel).
- **Une zone ne change jamais de camp directement** : quand sa garnison est détruite, elle devient **neutre** (grise).
  Une zone neutre se prend en y tenant le terrain : des unités au sol d'un seul camp y restent `capture_seconds` (120 s par défaut) — troupes ou caisse CTLD 2, convoi, groupe `_spawn`, véhicule Combined Arms, hélicoptère **posé**.
  Des hélicoptères posés, seuls, mettent `helicopter_capture_seconds` (600 s), et ne laissent qu'une garnison symbolique : ce qu'emporte un hélicoptère.
  La nouvelle garnison apparaît aussitôt.
- **Un pilote au sol après une éjection n'est l'ennemi de personne** : le rescapé que pose le module CSAR ne tient ni ne conteste une zone, ne réveille aucune zone et n'arrête aucun convoi, dans tous les scripts VEAF.
- **Les slots suivent les bases** : un aérodrome pris passe dans le camp du preneur, avec ses slots dynamiques.
  La campagne décide seule du camp d'un aérodrome : la prise native de DCS, par les unités qui l'entourent, est coupée sur tous les aérodromes de la carte.
- **Le front bouge tout seul** : l'ennemi [contre-attaque](#front), renforce ses zones par hélicoptère, et envoie CAP, frappes et [bombardiers](#bombers).
- **L'ennemi paie ce qu'il envoie** avec les [ressources](#resources) que font ses usines : détruire ses [usines](#zone-kinds) ou couper son [réseau d'approvisionnement](#network) finit par clouer sa CAP au sol.
- **La carte est teintée** par camp, chaque zone tenant le [territoire](#territory) le plus proche d'elle, et le front se lit entre les deux couleurs.
- **Chaque annonce dit qui parle** : « Commandement bleu : » (ou rouge) pour ce que fait ou subit un camp, « Renseignement : » pour ce qu'on apprend de l'ennemi — un convoi ou un hélicoptère qui part, un raid qui arrive.
- **Le menu F10 → Autres → Campagne** donne la situation, les crédits, les tâches, le renseignement et la boutique ; les commandes « (admin) » viennent en dernier.
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

Les briefings que `campaign next` et `campaign briefing` écrivent ([briefing de campagne](CAMPAIGN.md#briefing-deck), [briefing de mission](CAMPAIGN.md#mission-briefing), et le texte de situation stratégique qui devient le briefing DCS) parlent d'une campagne persistante : pas de nombre de missions, la victoire quand l'ennemi ne tient plus aucune zone, les tâches de `briefing.yaml` en ordres en cours, les usines à la place des réserves, une aviation ennemie active au départ de ses aérodromes, et une annexe sur le front vivant qui omet ce que `dynamic:` coupe (`attacks`, `supply`, `bombers.enabled`, `resources.enabled`).

`campaign next` ajoute aussi au `ctld-config.yaml` de la mission ce que les joueurs transportent pour la campagne : la caisse **« Zone supplies »** (une par camp), le groupe de troupes **« Spy »** (un homme) et le groupe **« Sappers »** (deux hommes, l'[équipe de démolition](#demolition)).
Il écrit les [waypoints](#waypoints) des joueurs, un par zone, et, quand il crée le dossier de la mission, son [plan radio](#radio-plan).
Il impose enfin la vue F10 « fog of war » (`mission.forced_options.f10_view: fog_of_war`) : un pilote ne voit que les ennemis que son camp a détectés, et la force d'une garnison s'apprend par la [reconnaissance](#intel). Une vue déjà choisie dans `mission.yaml` est gardée.

**Pas de commande d'interpréteur dans une campagne persistante.**
Une unité nommée `#veafInterpreter["…"]` dans l'éditeur refait apparaître ses unités à chaque démarrage de la mission : en campagne persistante, elles reviennent neuves après chaque redémarrage du serveur, leurs pertes oubliées, sans que personne les paie.
Ce que la campagne doit tenir se déclare dans `campaign.yaml`, en zone avec sa garnison (une liste explicite `garrison:` si la composition compte) : la zone est sauvegardée avec ses pertes, et le [réseau](#network) la reconstruit aux frais de son camp.
`campaign next` signale les commandes d'interpréteur qu'il trouve dans la mission.

**Ce dont `campaign validate` et `campaign next` avertissent**, chaque fois un défaut du premier soir joué :

- une zone posée par coordonnées à moins de 4 km d'un aérodrome, sans `kind:` : posez-la sur l'aérodrome (`at: { airfield: … }`), sinon DCS et la campagne prennent chacun leur objet ;
- aucun AWACS ni ravitailleur dans `dynamic.support.assets`, pas de `dynamic.economy.tanker`, ou l'un d'eux qui n'est aucun groupe de la mission template : les joueurs volent sans, et la boutique n'a pas de ravitailleur ;
- un canal du `src/presets.yaml` du template nommé d'après un aérodrome d'un autre théâtre : écrivez le plan de fréquences de la campagne pour son théâtre ;
- plus de [SAM longue portée](#long-range-sams) que permis, ou trop proches, est une erreur.

### Un waypoint par zone {#waypoints}

`campaign next` écrit dans `src/waypoints.yaml` un waypoint par zone de la campagne, en son centre, au sol, pour les avions et les hélicoptères des joueurs, les plus stratégiques d'abord : les zones du front (reliées à une zone d'un autre camp), puis les aérodromes, les usines, les dépôts et le reste, les plus proches de nos zones d'abord.
Un module qui tient moins de points qu'il n'y a de zones garde les premiers.
Chaque zone garde son numéro, celui qui suit le point de départ : l'étiquette F10, la situation, la boutique, le renseignement et chaque annonce la nomment « Taftanaz (WP 7) ».
L'ordre est celui de l'état de la campagne au moment de `campaign next` ; le build ajoute BULLSEYE après eux.
Un `waypoints.yaml` modifié à la main est laissé tel quel, comme pour une [campagne multi-missions](CAMPAIGN.md), et les numéros que lisent les joueurs sont ceux qu'il porte : une zone qu'il ne contient pas n'en affiche aucun.

### Le plan radio {#radio-plan}

Quand il crée le dossier de la mission, `campaign next` écrit le plan radio des joueurs dans `src/presets.yaml` ; modifié ensuite, il appartient au créateur de la mission.

| Radio | Canaux |
|---|---|
| VHF, la radio des aérodromes | 1 **Home Base**, que chaque pilote règle sur le terrain d'où il a décollé ; puis les aérodromes du camp des joueurs, avec les fréquences que DCS leur donne sur ce théâtre |
| UHF | les AWACS et ravitailleurs de `dynamic.support.assets` et `economy.tanker`, sur la fréquence de leur groupe ; **Air-Sol**, la fréquence air-sol commune (305,0) ; puis les vols VEAF, Archer en tête |

Un canal a besoin d'une fréquence pour que le build le garde sur la radio et la planchette : Home Base porte une fréquence d'attente qu'aucun aérodrome de DCS n'utilise (VHF 118,025, UHF 230,025), que le pilote remplace.
L'AWACS et les ravitailleurs doivent donc être dans le template avant le premier `campaign next`.

### Les SAM longue portée {#long-range-sams}

Un SAM longue portée appartient à une zone : `long_range_sam: true` sur la zone.
Deux SA-5 à 17 nautiques l'un de l'autre ont mis tout un front sous 240 km de portée de missile le premier soir joué ; `campaign validate` refuse donc plus de `long_range_sams.per_side` (2) par camp, et deux d'un même camp à moins de `long_range_sams.min_spacing` (120 km).
Réservez-les aux points clés du réseau : une grande base, une usine, un dépôt.

```yaml
long_range_sams: { per_side: 2, min_spacing: 120000 }
zones:
  - { name: Alep, at: { airfield: Aleppo }, size: airfield, side: red, long_range_sam: true }
```

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
Elle réapparaît exactement comme elle était :

- **toujours**, si elle est à moins de `front_depth` (40 km) de la ligne de front tracée sur la carte, ou si elle est reliée à une zone d'un autre camp, ou si une sortie la vise : l'ennemi qui contourne trouve du monde ;
- quand un **avion de joueur ennemi** arrive à moins de `wake_radius` (60 km), ou à portée de sa défense antiaérienne plus `reach_wake_margin` (20 km) quand cette portée va plus loin ;
- quand un **avion ennemi en vol**, IA comprise, arrive à portée de sa défense antiaérienne plus `reach_wake_margin` : un SAM longue portée se réveille donc bien plus tôt qu'une zone qui n'a que des canons ;
- quand un **groupe au sol ennemi** qui n'est pas une garnison (convoi, troupes déposées, spawn) arrive à moins de `ground_wake_radius` (10 km).

Seuls les ennemis d'une zone la réveillent ; les véhicules posés dans l'éditeur et les avions pas encore activés ne réveillent rien.
La portée d'une défense est celle de ses missiles, lue dans DCS pendant que la zone est éveillée et retenue dans la sauvegarde ; une zone jamais vue éveillée a une portée supposée (75 km avec un SAM longue portée, 20 km sinon).
Elle disparaît quand personne n'est venu depuis `sleep_seconds` (600 s), sauf près du front.

Au plus `max_awake_zones` (12) zones de l'arrière sont éveillées à la fois ; le front et les cibles de sorties ne comptent pas.
Quand la limite est atteinte, une zone voulue par un joueur prend la place d'une zone voulue seulement par une IA, ou d'une zone voulue par un joueur plus lointain ; entre zones voulues par des IA, la première garde sa place, pour que des avions qui passent ne fassent pas apparaître et disparaître les zones en boucle.
Une seule zone se réveille à chaque battement de 10 s, pour ne pas faire apparaître tout le front d'un coup.

## Un front qui bouge tout seul {#front}

- **Contre-attaques** : toutes les `attack_seconds` (900 s), un camp listé dans `attacks` (le rouge par défaut) envoie un convoi d'assaut contre la zone ennemie la plus faible qui le borde, `max_convoys` (2) sur la route au plus.
  Seuls ces camps envoient aussi d'eux-mêmes des convois vers une zone neutre ; le camp des joueurs achète les siens (F10 → Campagne → Assauts), et aucun convoi automatique ne part vers une zone qu'un convoi du même camp vise déjà.
- **Un convoi qui n'arrivera pas libère sa place** : dès que sa cible est à son camp (un hélicoptère l'a prise avant lui), ou après `convoy_timeout` (2 700 s) de route, il est retiré de la carte et le prix de ses survivants retourne à son camp.
- **L'autre camp est prévenu aussitôt** du départ d'un convoi, et voit son axe sur la carte.
- **Ravitaillement** : une livraison dans une zone amie abîmée ramène au complet son premier groupe touché.
  Livrent : une caisse « Zone supplies » posée dans la zone, des troupes CTLD 2 déposées dans la zone (sauf l'équipe espion et les équipes JTAC), un hélicoptère de ravitaillement posé.
- **Hélicoptères IA** : toutes les `supply_seconds` (600 s), un camp listé dans `supply` (le rouge par défaut) envoie un hélicoptère (`helicopter`, Mi-8MT rouge, UH-1H bleu) vers une zone neutre qui le borde, qu'il prend en s'y posant, ou à défaut vers sa zone la plus abîmée, qu'il ravitaille ; `max_helicopters` (2) en vol au plus, et un hélicoptère qui ne s'est pas posé au bout de `helicopter_timeout` (1 200 s) est retiré.
  L'autre camp est prévenu à son départ, pour l'intercepter.
  Un hélicoptère qui se repose loin de sa zone a échoué aussitôt, et `dcs.log` dit où il s'est posé.

## L'aviation ennemie {#air}

- **CAP** : l'ennemi tient en l'air une CAP par tranche de `air.cap_per_players` (3) joueurs du [niveau d'opposition](scripts/veafQraManager.md#opposition-level), au-dessus de sa zone du front la plus proche de nos chasseurs.
  Ce niveau suit les **chasseurs** en l'air : les joueurs qui emportent un missile air-air à guidage radar (le suivi `air_to_air`, mis d'office quand la mission ne suit rien d'autre). Hélicoptères et avions d'attaque (A-10, Su-25, AV-8B…) ne comptent pas : quand aucun chasseur ne vole, aucune CAP ne décolle.
  Son cercle de patrouille (40 km au plus) s'arrête 15 km avant la portée des défenses antiaériennes de nos zones ; quand même un cercle de 5 km serait à leur portée, elle prend la zone du front suivante, et ne part pas si aucune ne convient : elle ne vient pas se jeter dans nos SAM.
  Elle engage nos avions de combat ; un hélicoptère ou un avion d'attaque qu'elle détecte n'est engagé que sur un tirage de `air.cap_helicopter_chance` (25 %), fait une fois par appareil, comme l'option `InvisibleA10` de Foothold.
- **Frappes** : toutes les `air.strike_seconds` (900 s), une frappe CAS (sur la zone qui a le plus d'unités) ou SEAD (sur celle qui a le plus de défense antiaérienne), en alternance, sur une zone qui borde le territoire ennemi.
  Une frappe CAS laisse de côté une zone sous une défense antiaérienne mesurée de 15 km ou plus (un Hawk, un SA-6), la sienne ou celle d'une voisine : c'est le travail de la SEAD.
- Elles **décollent** de l'aérodrome ennemi le plus proche, moteur chaud sur des parkings libres (les abris d'abord, les places ouvertes ensuite ; un gros avion, bombardier ou transport, jamais dans un abri), ou de la piste quand il n'y en a pas assez ; sans aérodrome, pas de sortie. Il en va de même pour la CAP, la BARCAP et le Hunter.
  Rien ne décolle d'un aérodrome à moins de `takeoff_threat_range` (40 km) d'une défense antiaérienne ennemie dont la portée a été mesurée (un Patriot abattrait les avions pendant qu'ils montent) ; la portée que donne DCS est celle du missile contre une cible haute, bien plus longue que celle à laquelle le SAM voit un avion qui décolle, d'où ce plafond, une estimation à régler.
  Une **SEAD** décolle quand même : éteindre cette défense est son travail, et ce qu'elle détruit libère le terrain pour les frappes.
  Sinon la sortie part d'un autre aérodrome, ou ne part pas, et `dcs.log` le dit (`[CAMPAIGN DECISION] nothing of red takes off from [Senaki]: it is under the air defence of [Kobuleti]`).
  `air.max_flights` (4) vols en l'air au plus par camp.
- **Hunter** : un joueur en chasseur qui enchaîne les victoires (entre 8 et 16 au sol, ou entre 4 et 8 en l'air, tiré une fois par vie) a ensuite 10 % de chances à chaque victoire de voir décoller deux chasseurs ennemis contre ce joueur ; son camp est prévenu.

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

Une victoire d'un joueur paie en deux temps : `economy.landing_share` (50 %) en est gardé jusqu'à ce que le pilote se pose sur un aérodrome, une FARP ou un porte-avions ami, et perdu s'il s'éjecte, meurt ou s'écrase ; le reste est gagné aussitôt.
Les deux parts vont au compte de la coalition.
Les autres gains, qu'aucun pilote seul ne porte, sont payés en entier.

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
| Raid de bombardiers | un [raid combiné](#bombers) — BARCAP, SEAD, bombardier — sur une zone ennemie, ses bâtiments d'abord | 1300 |
| Escorte de mon groupe | deux chasseurs pour le groupe de l'acheteur, qui partent en l'air au-dessus de notre aérodrome le plus proche : un avion reçoit la tâche d'escorte de DCS ; un hélicoptère, trop lent pour des chasseurs, une CAP de 15 km au-dessus de lui, déplacée quand il a avancé de 8 km. Dans le menu de chaque pilote | 300 |
| Ravitailleur | fait réapparaître le ravitailleur que nomme `economy.tanker` (un asset de la mission), puis le [replace](#support) hors de portée ; absent sans lui | 300 |

La BARCAP se tient sur l'axe entre la zone ennemie et notre aérodrome le plus proche, au premier point hors de portée de **toutes** les défenses ennemies (pas seulement celles de la zone visée) plus 15 km, et garde un cercle de 15 km ; quand aucun point de l'axe n'est hors de portée, elle tient au-dessus de son aérodrome.
La portée se mesure sur les missiles que portent les unités de la zone quand elle est éveillée ; une zone endormie est supposée porter à 75 km si elle a un [SAM longue portée](#long-range-sams), 20 km sinon, et le message le dit.

Les prix se changent dans `economy.prices` (`jtac`, `illumination`, `smoke`, `intel`, `cap`, `barcap`, `capture`, `resupply`, `bomber`, `escort`, `tanker`, et `assault` pour l'ordre d'assaut de F10 → Campagne → Assaut, 300).
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

Chaque camp a **un stock de points de ressources** (`resources.start`, 1 000), sauvegardé avec la campagne, et **tout ce que l'IA met en jeu se paie dessus** au prix de ses unités : la garnison d'une zone prise, un renforcement par le [réseau](#network), un convoi d'assaut, un hélicoptère de ravitaillement, une CAP, une frappe, le Hunter, un [raid de bombardiers](#bombers).
Un stock vide n'envoie plus rien : une sortie ne part que si le stock reste au-dessus de `resources.reserve` (100) une fois payée, pour que l'IA garde de quoi relever ses zones.
Une zone prise que son camp ne peut pas payer reçoit une garnison symbolique, et une zone prise par des hélicoptères seuls aussi.
Un [spawn payé](#paid-spawns) peut faire passer le stock sous zéro : l'IA ne paie alors plus rien, sortie ni renfort, jusqu'à ce que la production le remonte.

**La production** s'ajoute à chaque battement : une production de fond, `resources.background_per_hour` (60 points par heure), même sans usine, de quoi tenir tout juste une base ; et chaque usine, `factory.per_hour` (180) multiplié par la part de ses bâtiments debout.
Ces trois valeurs ont été relevées après le premier soir joué : avec 500, 30 et 120, le rouge n'avait plus rien au bout d'1 h 20, ni CAP, ni frappe, ni raid.

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
- au prix **des unités qu'elle a fait apparaître**, une par une, au [barème des ressources](#resources) : une section blindée tirée au hasard coûte ce qu'elle a tiré, deux chars et un VCI font 6 + 6 + 4 = 16 points ;
- le camp des joueurs paie `economy.credits_per_point` (6) crédits par point : ces 16 points font 96 crédits ;
- le prix n'est connu qu'une fois les unités tirées : le spawn passe donc toujours **en entier** — multiplicateur compris — et se paie au prix exact, quitte à faire passer le camp **dans le rouge** ;
- un camp à zéro ou dans le rouge ne fait plus apparaître rien : la commande est refusée avant le spawn, avec son solde, jusqu'à ce que le solde repasse au-dessus de zéro ; un gain rembourse d'abord la dette.

Fumigènes, fusées, dessins, destruction, téléportation et mission master restent gratuits : ils ne mettent aucune unité en jeu.
Un alias en lot (`-arty1`) se paie comme ses alias : sa batterie est facturée, même si le mot de passe n'est vérifié qu'une fois.
Ce qu'un script fait apparaître (une combat zone, une commande que l'interpréteur lit dans un nom posé dans l'éditeur, les sorties de la campagne elle-même) n'est pas l'action d'une personne et ne se paie pas ici.

### Les commandes réservées {#reserved-commands}

Certaines commandes seraient de la triche dans une campagne persistante : elle les réserve au niveau **admin** (celui du fichier des pilotes VEAF), quel que soit leur niveau ailleurs.

| Réservées aux admins | Ce qu'elles font |
|---|---|
| `-shell`, `-cesar`, `-flak`, `_spawn bomb` | des explosions où l'on veut |
| `-destroy`, `_destroy` | détruire les unités autour du marqueur |
| `-tanker`, `-tankerhere`, `_teleport`, `_move … teleport` | téléporter un groupe ou le ravitailleur |
| `-zonestart`, `-zonestop`, `-airstart`, `-airstop` | activer ou arrêter une combat zone ou une vague aérienne |
| `-send`, `-play`, `_radio` | diffuser un message ou un son à tout le serveur |
| `-light`, `_spawn flare` | de l'éclairage gratuit, que la boutique vend |

**`-cas` est désactivée** : une zone CAS d'entraînement n'a pas de sens dans une campagne.
Le reste garde le niveau de son module : fumigènes, signaux, points nommés, balises, dessins, altitude du ravitailleur, commandes de l'artillerie posée.
La même règle vaut pour une commande qu'un pilote passe à distance.
Une mission dont la sécurité est coupée (une copie de test) laisse tout passer, sauf `-cas`.

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

Toutes les `bombers.seconds` (3 600 s), l'ennemi envoie un **raid combiné** sur la zone des joueurs qui a le plus à frapper : une usine d'abord, sinon la zone qui a le plus d'unités, parmi celles qu'un de ses aérodromes peut atteindre.
Tout **décolle** de l'aérodrome ennemi le plus proche de la cible qui en est au moins à `bombers.min_distance` (80 km), pour laisser aux joueurs le temps d'intercepter, comme tous les avions de la campagne :

1. une **BARCAP** tient l'axe, hors de portée de toutes les défenses antiaériennes ennemies (voir la [BARCAP](#shop)) ;
2. un vol **SEAD**, contre la zone dont la défense antiaérienne couvre la cible (s'il y en a une), et le **bombardier** se retrouvent sur un point d'attente, sur l'axe de la cible, au premier point hors de portée des défenses plus 15 km (au-dessus de leur aérodrome s'il n'y en a pas) ;
3. quand les deux y tournent, montés à leur altitude (à 1 000 m près) et à moins de 15 km du point (le rayon d'un cercle d'attente), la SEAD repart vers la cible, et le bombardier `bombers.package_delay` (30 s) derrière elle, sur le même axe ; si la SEAD a été abattue en route, le bombardier repart seul. Aucun ne tourne plus de 20 minutes au point d'attente.

Le bombardier vole à la vitesse de la SEAD, pour rester derrière elle, et largue tout son emport d'une passe, en tapis de 100 m sur la cible ; il ne réagit pas à la menace et ne largue pas ses bombes en secours : il va jusqu'à la cible.
Après la cible, il repart sur 20 km par l'axe d'où il est venu, celui que sa SEAD a dégagé, avant de rentrer à sa base.
Sans défense à éteindre, pas de SEAD ni d'attente : le bombardier va droit sur la cible.

Pas d'escorte par défaut : la BARCAP tient l'approche, et la fin du trajet est la fenêtre d'interception des joueurs ; `bombers.escort: true` lui en rend une.
Le paquet se paie tout entier, sur les ressources, ou ne part pas.
Les joueurs en sont prévenus aussitôt, et le [tableau des tâches](#tasks) affiche une tâche d'interception.
Un seul raid d'un camp en l'air à la fois.

Les joueurs achètent le même paquet à la [boutique](#shop) : **Raid de bombardiers**, sur une zone ennemie.

Les bombardiers se déclarent comme les autres avions, rôle `bomber` :

```yaml
dynamic:
  air:
    red:
      bomber: { type: Tu-22M3, loadout: "FAB-500*33", count: 1 }
    blue:
      bomber: { type: B-1B, loadout: "Mk-84*24", count: 1 }
```

## AWACS et ravitailleurs {#support}

Les AWACS et ravitailleurs nommés dans `support.assets` (des assets de la mission, avec une orbite dans l'éditeur) sont tenus hors des défenses ennemies :

- sur la ligne entre leur orbite de l'éditeur et la zone ennemie la plus proche, au premier point hors de portée de **toutes** les défenses antiaériennes ennemies plus `support.margin` (30 km), jamais en avant de la zone de leur camp la plus proche de cet ennemi ;
- réévalués toutes les `support.seconds` (300 s) : quand un SAM meurt, l'orbite se rapproche ; quand une nouvelle portée est mesurée, elle recule ;
- déplacés seulement quand la station a bougé de `support.min_move` (20 km) ou plus, leur branche (`support.leg`, 30 nautiques) posée en travers de l'axe ;
- chaque déplacement annoncé à leur camp : la nouvelle orbite en relèvement et distance du bullseye, fréquence inchangée.

```yaml
dynamic:
  support:
    assets: [ "AWACS Magic", "Tanker Texaco" ]
  economy:
    tanker: Tanker Texaco
```

La portée est celle qu'utilise [la BARCAP](#shop) : mesurée sur les missiles quand une zone est éveillée, supposée pour une zone jamais vue éveillée.

## Le territoire {#territory}

Chaque zone tient la part de la carte plus proche d'elle que de toute autre zone (sa cellule de Voronoï), teintée sur la carte F10 de la couleur de son camp, gris pour une zone neutre ; une ligne sombre court entre deux cellules de camps différents : c'est le front, souligné de chaque côté par de petites hachures obliques de la couleur du camp, bien visibles là où la teinte est pâle.
La carte ne se redessine que quand une zone change de camp.
`territory.margin` (70 km) prolonge les cellules au-delà des zones du bord ; `territory.hatch_spacing` (3 000 m) et `territory.hatch_length` (2 500 m) règlent l'écart et la longueur des hachures ; `territory.enabled: false` retire la teinte.

## Le journal de mise au point {#debug-log}

Pendant la mise au point, `dynamic.debug` (activé par défaut) écrit dans `dcs.log` ce que fait la campagne, en lignes faciles à chercher :

| Repère | Ce qu'il dit |
|---|---|
| `[CAMPAIGN DECISION]` | chaque décision de l'IA et sa raison : sortie envoyée, ou non (pas de cible, pas de terrain, plus de place, pas de quoi payer — avec le prix et le stock) ; composition d'un raid ; un refus réexaminé à chaque battement n'est dit qu'une fois, tant que sa raison ne change pas |
| `[CAMPAIGN FLIGHT]` | le sort de chaque avion de la campagne : largage (avec sa distance au point visé, la zone la plus proche et ce qu'il lui reste), victoire ou perte et par qui, atterrissage (sur un aérodrome, ou en campagne près d'une zone), départ d'un raid de son point d'attente ; une épave qui écrase le décor n'est pas une victoire |
| `[CAMPAIGN AIRDEF]` | toutes les `debug_status_seconds` (300 s) : pour chaque zone, ses unités de défense antiaérienne et les missiles qui leur restent, lanceurs vides compris |
| `[CAMPAIGN SUPPLY]` | livraisons du réseau commandées, arrivées, perdues |
| `[CAMPAIGN ZONE]` | zones prises et neutralisées |
| `[CAMPAIGN STATUS]` | toutes les `debug_status_seconds` (300 s) : par camp, zones, stock et production, livraisons en route, vols en l'air, raid en cours, et les crédits des joueurs |

`debug: false` l'éteint, une fois la campagne sûre.

## Contrôler une mission en jeu {#self-check}

F10 → Autres → Campagne → **Auto-contrôle (admin)** affiche une ligne `OK` ou `KO` par mécanisme : zones placées, sauvegarde relue et écrite, issue, dormance, captures, usines, territoire, ressources des deux camps, réseau (livraisons et zones coupées), spawns payants, sapeurs, entrepôts, hélicoptères, aviation, bombardiers, crédits, tâches, renseignement.
Une ligne `KO` suffit à dire où regarder.

## Tous les réglages {#settings}

| Clé de `dynamic:` | Par défaut | Ce qu'elle règle |
|---|---|---|
| `save_seconds` | 60 | intervalle entre deux sauvegardes |
| `wake_radius` | 60000 | mètres : un joueur ennemi aussi près réveille une zone |
| `ground_wake_radius` | 10000 | mètres : un groupe au sol ennemi qui n'est pas une garnison, aussi près, réveille une zone ; les véhicules posés dans l'éditeur ne réveillent rien |
| `reach_wake_margin` | 20000 | mètres : un avion ennemi aussi loin au-delà de la portée de la défense d'une zone la réveille |
| `takeoff_threat_range` | 40000 | mètres : rien d'autre qu'une SEAD ne décolle aussi près d'une défense ennemie mesurée |
| `front_depth` | 40000 | mètres : une zone aussi près de la ligne de front tracée sur la carte est toujours éveillée |
| `sleep_seconds` | 600 | une zone sans joueur près d'elle depuis ce temps se rendort |
| `max_awake_zones` | 12 | zones de l'arrière éveillées à la fois (le front et les cibles de sorties ne comptent pas) |
| `attacks` | `[red]` | les camps qui contre-attaquent seuls |
| `attack_seconds` | 900 | intervalle entre deux contre-attaques d'un camp |
| `max_convoys` | 2 | convois d'assaut d'un camp sur la route |
| `supply` | `[red]` | les camps dont les hélicoptères IA capturent et ravitaillent |
| `supply_seconds` | 600 | intervalle entre deux hélicoptères d'un camp |
| `max_helicopters` | 2 | hélicoptères de ravitaillement d'un camp en vol |
| `helicopter_timeout` | 1200 | un hélicoptère pas posé au bout de ce temps est retiré |
| `helicopter_capture_seconds` | 600 | une zone neutre tenue par des hélicoptères posés, seuls, est prise au bout de ce temps |
| `convoy_timeout` | 2700 | un convoi d'assaut pas arrivé au bout de ce temps est retiré de la carte, sa place libérée |
| `helicopter` | `{red: Mi-8MT, blue: UH-1H}` | le type de l'hélicoptère de chaque camp |
| `supply_crate` | `Zone supplies` | le nom de la caisse CTLD 2 qui ravitaille |
| `hunter` | `{enabled: true, ground_kills: 8, air_kills: 4, chance: 10}` | le Hunter |
| `air` | voir [l'aviation ennemie](#air) | `strike_seconds` (900), `max_flights` (4), `cap_per_players` (3), `cap_helicopter_chance` (25), et les avions de chaque camp |
| `economy` | voir [la boutique](#shop) | `start_credits`, `kill_ground`, `kill_air`, `capture`, `delivery`, `prices`, `tanker`, `credits_per_point` (6), `demolition` (50), `warehouse_delivery` (50), `landing_share` (50) |
| `tasks` | voir [les tâches](#tasks) | `count`, `refresh_seconds`, `air_kills`, `rewards` (`attack`, `capture`, `resupply`, `air`, `intercept`) |
| `intel` | voir [le renseignement](#intel) | `hidden`, `seconds`, `overflight_altitude`, `spy_troops`, `spy_range` |
| `resources` | voir [les ressources](#resources) | `enabled` (true), `start` (1000), `background_per_hour` (60), `reserve` (100), `prices` |
| `factory` | voir [les usines](#zone-kinds) | `buildings` (3), `per_hour` (180), `types` |
| `network` | voir [le réseau](#network) | `hop_seconds` (600), `isolated_seconds` (3600), `depot_store` (4), `max_deliveries` (3) |
| `demolition` | voir [la démolition](#demolition) | `troops` (`Sappers`), `range` (5000), `fuse` (120) |
| `warehouse` | voir [les stocks](#warehouses) | `enabled` (true), `load` (10) |
| `bombers` | voir [les bombardiers](#bombers) | `enabled` (true), `seconds` (3600), `min_distance` (80000), `escort` (false), `package_delay` (30) |
| `debug` | voir [le journal de mise au point](#debug-log) | `true` pendant les essais |
| `debug_status_seconds` | 300 | intervalle entre deux lignes d'état du journal |
| `territory` | voir [le territoire](#territory) | `enabled` (true), `margin` (70000), `hatch_spacing` (3000), `hatch_length` (2500) |
| `support` | voir [AWACS et ravitailleurs](#support) | `assets` (aucun), `margin` (30000), `seconds` (300), `min_move` (20000), `leg` (30, nautiques) |

Les plafonds sont prudents par défaut ; ils se règleront d'après ce que tiennent les serveurs.

## Ce qui reste à vérifier en jeu {#to-verify}

Ces points sont écrits et testés hors de DCS, pas encore mesurés en jeu :

- un hélicoptère IA qui se pose dans une zone (les pièges connus de DCS sur un poser scripté sont dans [les pièges du runtime DCS](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/agents/dcs-runtime-traps.md)) ;
- les frappes CAS et SEAD et leur retour ;
- l'équipe espion qui marche jusqu'à sa zone ;
- la disparition et la réapparition d'une garnison au passage d'un joueur ;
- les bâtiments d'une usine posés sur un terrain dégagé, et relevés sous le drapeau du preneur ;
- la tâche `CarpetBombing` du bombardier, ses options « pas de réaction à la menace » et « pas de largage de secours », et le point d'attente commun du raid combiné (drapeaux `campaign raid <n> sead` / `bomber`) ;
- les charges des sapeurs, assez fortes pour un bâtiment, et l'équipe hors de leur souffle ;
- les stocks d'un entrepôt illimité, que `getInventory` rapporte peut-être sans les compter ;
- la teinte du territoire, faite de triangles, sur la carte F10 ;
- un AWACS ou un ravitailleur déplacé hors de portée, et sa branche en travers de l'axe ;
- un hélicoptère de ravitaillement à qui il est dit de ne pas abandonner sa tâche sous une menace (deux fois le 16/11/2026, un Mi-8 envoyé d'Alep vers Afrin s'est reposé à Alep trois minutes après son départ : une cause probable, pas mesurée) ;
- les numéros des waypoints, tels que chaque module les montre.

Voir aussi la [référence du module `veafCampaign`](scripts/veafCampaign.md).
