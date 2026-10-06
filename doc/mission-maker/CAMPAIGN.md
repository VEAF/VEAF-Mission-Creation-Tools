# Campagne multi-missions

> Une campagne pour l'escadrille, jouée mission après mission.
> Chaque mission part de ce que la précédente a laissé : un pont détruit reste détruit, une base libérée reste à nous, une garnison qui a perdu deux lanceurs les a perdus pour de bon.
> C'est une campagne **épisodique**, dans l'esprit de DCS Liberation : chaque mission est une session de vol bornée, et la campagne avance entre deux missions.

## La boucle {#loop}

| étape | qui | comment |
|---|---|---|
| déclarer la campagne | le mission maker, souvent avec Claude | un dossier de campagne et son `campaign.yaml` |
| démarrer | les outils | `campaign init` crée l'état de départ |
| construire la mission N | les outils, puis Claude | `campaign next` prépare le dossier de mission à partir de l'état ; Claude y conçoit la mission par le MCP |
| voler | l'escadrille | la mission écrit son **fichier d'état** pendant le vol et à la fin |
| récupérer le fichier d'état | le mission maker ou Claude | depuis le `Saved Games` du serveur |
| appliquer | les outils | `campaign apply` fusionne le fichier d'état et joue le tour entre les missions |

Puis on recommence à `campaign next`, jusqu'à ce que les objectifs soient atteints ou que les missions prévues soient jouées.

```powershell
.\veaf-tools.exe campaign init C:\Campagnes\Caucase
.\veaf-tools.exe campaign next C:\Campagnes\Caucase
# … la mission est conçue, construite, jouée …
.\veaf-tools.exe campaign apply "C:\Saved Games\DCS\Missions\Saves\Caucasus Front\mission-01.state" C:\Campagnes\Caucase
.\veaf-tools.exe campaign next C:\Campagnes\Caucase
```

Avec l'assistant IA, les mêmes étapes passent par les actions `campaign_status`, `campaign_apply` et `campaign_next` (voir le [catalogue](AI_ASSISTANT_CATALOG.md)).

## Le dossier de campagne {#campaign-folder}

```text
Caucase/
├── campaign.yaml            ce que vous déclarez ; les outils ne le réécrivent jamais
├── campaign-state.yaml      ce que la campagne est devenue ; réécrit après chaque mission
├── template/                un dossier de mission ordinaire : chaque mission en part
└── missions/
    ├── mission-01/
    │   ├── mission/         le dossier de mission de la mission 1
    │   ├── mission-01.state le fichier d'état écrit par la mission
    │   ├── debriefing.fr.txt / debriefing.en.txt
    │   ├── campaign-state.before.yaml
    │   └── campaign-state.after.yaml
    └── mission-02/
        └── mission/
```

`template/` se prépare une fois, comme n'importe quel dossier de mission (`.\veaf-tools.exe prepare`, ou l'action MCP `scaffold_mission`) : la carte, les slots, les presets, les scripts.
Chaque mission de la campagne commence comme une copie de ce dossier.

L'historique est gardé en entier : pour annuler une fusion, remettez `campaign-state.before.yaml` à la place de `campaign-state.yaml`.

## Déclarer une campagne {#declare}

```yaml
campaign:
  name: Caucasus Front
  theatre: Caucasus
  era: MODERN                # MODERN, COLD_WAR ou WW2 : ce que les garnisons tirent
  missions: 10               # les objectifs sont dimensionnés pour à peu près ce nombre
  player_side: blue          # le camp des joueurs ; blue par défaut
  capture_seconds: 120       # présence au sol pour prendre une zone neutre
  state_write_seconds: 60    # intervalle d'écriture du fichier d'état en vol
  objectives:
    - capture: [Senaki, Kutaisi]
    - destroy: { zone: Gudauta depot, kind: logistics }
size_classes:                # surcharge des classes livrées, ou nouvelles classes
  outpost: { size: 2 }
zones:
  - name: Kobuleti
    at: { airfield: Kobuleti }
    size: airfield
    side: blue
  - name: Senaki
    at: { airfield: Senaki-Kolkhi }
    size: airfield
    side: red
    radius: 3000             # en mètres ; 2000 par défaut
  - name: Gudauta depot
    at: { lat: 43.10, lon: 40.58 }
    size: outpost
    side: red
    kind: logistics          # alimente la réserve de son camp entre les missions
    garrison: [sa8, shilka, T-72B]   # remplace le tirage, pour le camp qui le déclare
connections:
  - [Kobuleti, Senaki]
  - [Senaki, Gudauta depot]
sides:
  red: { reserve: { armor: 12, air_defense: 4, transport: 6 } }
rules:
  repairs_per_mission: 4
```

Une campagne complète, prête à copier — la Géorgie occidentale en 12 zones et 10 missions — est livrée avec les outils : [`src/defaults/campaign-folder/campaign.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/src/defaults/campaign-folder/campaign.yaml).

Une zone est **sur un aérodrome** (`at: { airfield: <nom DCS> }`) ou **à des coordonnées** (`at: { lat, lon }`).
Une zone d'aérodrome donne sa base à son propriétaire : slots dynamiques pour son camp, aucun pour une base neutre.

Un objectif `capture` est atteint quand le camp des joueurs tient toutes les zones qu'il nomme.
Un objectif `destroy` l'est quand l'ennemi ne tient plus la zone : garnison détruite, ou zone prise.

`.\veaf-tools.exe campaign validate <dossier>` contrôle le fichier, et l'état par rapport à lui : aérodrome inconnu, zone en double, connexion vers une zone inconnue, graphe en morceaux, objectif sur une zone inconnue, alias de garnison inconnu, paramètre hors bornes.
Une zone renommée ou supprimée dans `campaign.yaml` après le démarrage est signalée, jamais oubliée en silence.

## Les garnisons {#garrisons}

Une garnison est tirée **une fois** par les générateurs des missions CAS (`veafCasMission`), pour le camp qui tient la zone et l'ère de la campagne.
Sa composition est enregistrée, et chaque mission suivante la fait réapparaître **moins ses pertes** : un site SAM qui a perdu deux lanceurs démarre sans eux.
Une zone qui perd toute sa garnison devient **neutre**, et peut être prise.

### Les classes de taille {#size-classes}

Une classe de taille est un jeu de paramètres des générateurs CAS : la garnison compte autant de sections d'infanterie, de pelotons blindés et de groupes de défense aérienne qu'une mission CAS de la même taille, **sans sa compagnie de transport** — une garnison n'a que faire de quinze camions.

| classe livrée | `size` | `defense` | `armor` | SAM longue portée | unités (moyenne, min – max) |
|---|---|---|---|---|---|
| `outpost` | 1 | 1 | 1 | non | 23 (12 – 36) |
| `airfield` | 1 | 3 | 2 | oui | 51 (35 – 74), dont ≈ 20 pour le SAM |

Mesuré sur 40 tirages, le 2026-10-06 ; la campagne d'exemple compte ainsi environ 470 unités au sol.

`size` va de 1 à 5, `defense` et `armor` de 0 à 5, comme pour un marqueur `_cas`.
Une classe nouvelle doit fixer `size`, `defense` et `armor`.

### Avant la première mission {#first-mission}

Les garnisons de départ sont tirées par la mission 1 elle-même, en jeu.
Le premier briefing parle donc en termes de renseignement (« force estimée ») ; les chiffres réels arrivent avec le fichier d'état de la mission 1.

## En vol {#in-flight}

- La **carte F10** montre chaque zone en cercle de la couleur de son propriétaire, avec son nom et la force de sa garnison, et les connexions en pointillés.
- Le menu radio **Campagne → Situation** donne les zones, les objectifs et le numéro de la mission.
- **Prendre une zone neutre** : des unités au sol d'un seul camp y restent `capture_seconds` (120 s par défaut) — troupes ou véhicules CTLD 2, convoi, groupe `_spawn`, véhicule Combined Arms, hélicoptère **posé**, caisse CTLD 2.
  Les deux camps présents arrêtent le compteur ; tout le monde parti l'annule.
  Un avion en vol ne compte jamais, une épave non plus.
  Le journal DCS (`dcs.log`) note, à chaque changement, qui tient une zone neutre et par quelle unité : c'est là qu'on lit pourquoi une prise ne démarre pas.
  La zone prise reçoit aussitôt la garnison de son nouveau camp, payée sur sa réserve.

## Le fichier d'état {#state-file}

La mission écrit tout ce dont la suivante dépend — propriétaire de chaque zone, garnisons et pertes, réserves, décor détruit, missiles restant aux SAM, contenu des entrepôts — dans :

```text
<Saved Games>\DCS\Missions\Saves\<nom de la campagne>\mission-NN.state
```

Elle l'écrit toutes les `state_write_seconds` pendant le vol, et à la fin de la mission : un serveur qui plante ne perd qu'un intervalle.
Chaque écriture commence par un temporaire complet (`mission-NN.state.tmp`).
Quand `os` est disponible, le temporaire remplace le fichier ; sinon le fichier est écrit à son tour.
Dans les deux cas, une écriture coupée laisse un fichier entier, et `campaign apply` se rabat sur le temporaire quand le fichier lui-même est tronqué.

Il faut `io` et `lfs` dans l'environnement des scripts de mission (`MissionScripting.lua` non assaini sur ces deux-là).
C'est le cas des serveurs VEAF, qui n'assainissent que `os` et `loadlib` (mesuré le 2026-10-03).
Sans `io` ou `lfs`, la mission le dit une fois et tourne quand même : la campagne ne peut simplement pas l'enregistrer.

### Récupérer le fichier sur un serveur {#fetch-state}

Le fichier est dans le `Saved Games` de l'instance DCS qui a fait tourner la mission : sur dcs.veaf.org, `C:/Users/veaf/Saved Games/<instance>_server/Missions/Saves/<nom de la campagne>/`, accessible en SFTP.
Copiez `mission-NN.state` sur votre poste — avec son `.tmp` s'il y en a un — puis passez son chemin à `campaign apply`.

## Entre les missions {#between-missions}

`campaign apply` refuse un fichier déjà appliqué, celui d'une autre campagne, ou celui qui saute une mission ; dans ces cas rien n'est écrit.
Sinon il fusionne le fichier, puis joue le **tour** avec des règles fixes, pour les deux camps :

| règle | réglage | défaut |
|---|---|---|
| chaque zone `logistics` tenue alimente la réserve de son camp | `rules.logistics_output` | `{armor: 2, air_defense: 1, transport: 1}` |
| les unités perdues sont remplacées sur la réserve, catégorie par catégorie | `rules.repairs_per_mission` | 4 unités par camp |
| une zone neutre bordée par un seul camp est reprise par lui | `rules.counter_attack` | `true` |

Détruire un dépôt ennemi, c'est moins de réserve, donc moins de réparations et des garnisons plus maigres derrière : une réserve vide ne permet plus qu'une garnison minimale.

L'**intention** de l'ennemi — où il porte son effort, ce que la prochaine mission demande aux joueurs — n'est pas dans les règles : c'est Claude qui la décide en construisant la mission suivante, et qui l'écrit dans le briefing.

## Le débriefing {#debriefing}

`campaign apply` écrit aussi le débriefing de la mission jouée, en français et en anglais, dans `missions/mission-NN/` (`debriefing.fr.txt`, `debriefing.en.txt`) : le terrain qui a changé de mains, les pertes de chaque camp zone par zone et type d'unité par type d'unité, le décor détruit, ce que le tour a fait ensuite, et l'état des objectifs.
C'est un texte à lire après la soirée ou à poster tel quel ; l'assistant IA en fait le récit pour l'escadrille quand on le lui demande, en s'en tenant à ses faits.

## Le briefing stratégique {#strategic-briefing}

`campaign next` écrit, à la racine du dossier de mission, la partie factuelle du briefing stratégique en français et en anglais (`strategic-situation.fr.txt`, `strategic-situation.en.txt`) : le front, ce qui a changé à la dernière mission, la réserve et les garnisons ennemies, les objectifs et les missions restantes.
Le texte, dans la langue des outils, devient aussi le briefing de la mission à sa création, pour qu'une mission construite telle quelle ne parte pas sans briefing ; Claude y ajoute la partie narrative en concevant la mission, et un second `campaign next` sur le même dossier ne l'écrase pas.

## Ce qui reste à vérifier en jeu {#to-verify}

Ces points sont écrits et testés hors de DCS, mais pas encore mesurés en jeu :

- l'effet de `Airbase.setCoalition` et `Airbase.autoCapture(false)` sur les slots dynamiques et les entrepôts d'une base qui change de camp ;
- l'exactitude du contenu des entrepôts lu en vol, et sa réécriture dans la mission suivante (pas encore faite) ;
- la possibilité de faire démarrer un SAM avec moins de missiles (le nombre restant est enregistré, pas encore rejoué) ;
- la façon de faire réapparaître détruit un pont ou un bâtiment (le décor détruit est enregistré, pas encore rejoué) ;
- la place des garnisons d'aérodrome, tirées autour du centre de la base.

Voir aussi la [référence du module `veafCampaign`](scripts/veafCampaign.md).
