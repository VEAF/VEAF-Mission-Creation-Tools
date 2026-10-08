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
├── briefing.yaml            le texte du briefing de campagne (voir plus bas) ; facultatif
├── campaign-state.yaml      ce que la campagne est devenue ; réécrit après chaque mission
├── template/                un dossier de mission ordinaire : chaque mission en part
└── missions/
    ├── mission-01/
    │   ├── mission/         le dossier de mission de la mission 1
    │   ├── mission-01.state le fichier d'état écrit par la mission
    │   ├── briefing-campagne.pptx / carte-strategique.png
    │   ├── briefing-mission.pptx / carte-tactique.png / zoom-<zone>.png
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
  start_date: 2016-06-01     # date de la première mission ; celle du template sinon
  start_time: sunrise+30*60  # heure de début : "06:30" ou expression solaire ; c'est le défaut
  players: 5-7               # effectif attendu de l'escadrille : un nombre (6) ou une fourchette
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
    display_name: Dépôt de Gudauta   # le nom que lisent les joueurs ; le nom reste la clé
    intel: Dépôt actif, gardé.       # ce que dit le renseignement, à la place du texte généré
    garrison: [sa8, shilka, T-72B]   # remplace le tirage, pour le camp qui le déclare
connections:
  - [Kobuleti, Senaki]
  - [Senaki, Gudauta depot]
sides:
  red: { reserve: { armor: 12, air_defense: 4, transport: 6 } }
rules:
  repairs_per_mission: 4
  assault_seconds: 600       # délai avant qu'un convoi d'assaut parte (voir « En vol »)
  intel_seconds: 1200        # délai avant que l'autre camp apprenne son départ ; 0 : tout de suite
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
  La zone prise reçoit aussitôt la garnison de son nouveau camp, payée sur sa réserve — sauf quand c'est un convoi d'assaut qui la prend : ses survivants deviennent la garnison.

### Les convois d'assaut {#assault-convoys}

Une zone neutre est la cible de chaque camp qui tient une zone voisine (connectée).
Après `rules.assault_seconds` (600 s par défaut, plus tôt quand le [niveau d'opposition](scripts/veafQraManager.md#opposition-level) dépasse 4 joueurs : moitié moins à 8), un convoi part par la route de la première voisine de ce camp vers la cible — à la mission qui démarre avec une zone neutre comme à la zone qui le devient en vol.
Un seul convoi à la fois par camp et par cible ; il ne part pas si sa zone de départ a changé de mains.
Il est fait de blindés à la mesure de la classe de taille de sa zone de départ et de quelques camions, **payés sur la réserve** de son camp, unité par unité ; une réserve vide n'envoie rien.
Ses blindés sont des chars et des véhicules de combat d'infanterie de son camp et de l'ère de la campagne — deux par niveau d'`armor` de la classe, plus deux : 4 depuis un `outpost`, 6 depuis un `airfield` —, tirés parmi les blindés des missions CAS, sans éclaireurs ni transports de troupes.
Il emmène deux camions et au plus un ou deux canons antiaériens (Vulcan, Gepard ; ZU-23, ZSU-57, Shilka), jamais de missiles, quelle que soit la défense aérienne de sa zone de départ.
Il se conduit comme tout convoi sous le feu ([veafGroundAI](scripts/veafGroundAI.md)) : il regarde devant lui, se scinde, appelle à l'aide, se replie.
Son camp est prévenu de son départ et voit aussitôt son axe sur la carte F10 : un trait à sa couleur, posé sur la liaison, jusqu'à ce qu'il arrive ou soit détruit.
L'autre camp l'apprend en renseignement, `rules.intel_seconds` plus tard (1 200 s, 20 minutes, par défaut ; 0 : tout de suite) : le message (« une colonne ennemie quitte Senaki en direction de Poti ») et le même trait sur sa carte arrivent ensemble, et un convoi détruit avant n'est jamais signalé.
Arrivé, il tient la zone comme toute unité au sol, et la prend au bout de `capture_seconds` : ses survivants dans la zone en deviennent la garnison, sans second tirage sur la réserve.
Les joueurs bleus en lancent aussi depuis le menu **Campagne → Assauts**, d'une zone bleue vers une voisine qui ne l'est pas, au niveau de sécurité de la mission.
`rules.assault_convoys: false` coupe la règle ; le menu reste.

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
| un convoi d'assaut encore en route à la fin du vol rend ses survivants à la réserve de son camp ; ses morts sont des pertes de la campagne | — | — |

Détruire un dépôt ennemi, c'est moins de réserve, donc moins de réparations et des garnisons plus maigres derrière : une réserve vide ne permet plus qu'une garnison minimale.

L'**intention** de l'ennemi — où il porte son effort, ce que la prochaine mission demande aux joueurs — n'est pas dans les règles : c'est Claude qui la décide en construisant la mission suivante, et qui l'écrit dans le briefing.

## L'opposition à la taille de l'escadrille {#players}

Ce qui s'adapte au nombre de joueurs, c'est la **chasse adverse** : les QRA et les CAP à la demande.
Les garnisons au sol, elles, sont les comptes de la campagne — réserves, pertes, réparations — et ne dépendent pas de qui est venu ce soir.

`players` de `campaign.yaml` dit l'effectif habituel ; `campaign next --players 6` dit celui de ce soir, et prime :

```powershell
.\veaf-tools.exe campaign next . --players 6
```

`campaign next` écrit alors le bloc [`opposition:`](scripts/veafQraManager.md#opposition-level) de la mission : un niveau égal au plus grand effectif attendu, qui suit ensuite les joueurs connectés du camp des joueurs — si l'escadrille vient à quatre, l'opposition redescend à quatre après quelques minutes.
Un second `campaign next` sur le même dossier ne change que le niveau : un mode de suivi ou un délai réglés depuis dans la mission sont gardés.
Sans `players` ni `--players`, le bloc de la mission n'est pas touché.

Les QRA ennemies de la mission doivent avoir des paliers jusqu'à cet effectif (`groups_by_enemy_count`) ; c'est ce que Claude écrit en concevant la mission.
Le briefing de mission le dit en renseignement — « la chasse adverse renforce son alerte face à un dispositif important » — jamais en paliers ni en nombres.
Il annonce de même une [contre-attaque terrestre attendue](#assault-convoys) vers une zone neutre que l'ennemi borde, sans sa force.

## Le débriefing {#debriefing}

`campaign apply` écrit aussi le débriefing de la mission jouée, en français et en anglais, dans `missions/mission-NN/` (`debriefing.fr.txt`, `debriefing.en.txt`) : le terrain qui a changé de mains, les pertes de chaque camp zone par zone et type d'unité par type d'unité, le décor détruit, ce que le tour a fait ensuite, et l'état des objectifs.
C'est un texte à lire après la soirée ou à poster tel quel ; l'assistant IA en fait le récit pour l'escadrille quand on le lui demande, en s'en tenant à ses faits.

## Le briefing stratégique {#strategic-briefing}

`campaign next` écrit, à la racine du dossier de mission, la partie factuelle du briefing stratégique en français et en anglais (`strategic-situation.fr.txt`, `strategic-situation.en.txt`) : le front, ce qui a changé à la dernière mission, la réserve et les garnisons ennemies, les objectifs et les missions restantes.
Le texte, dans la langue des outils, devient aussi le briefing de la mission à sa création, pour qu'une mission construite telle quelle ne parte pas sans briefing ; Claude y ajoute la partie narrative en concevant la mission, et un second `campaign next` sur le même dossier ne l'écrase pas.

## Date, heure et météo des missions {#mission-conditions}

Une mission de campagne est **une** mission : pas de variantes météo.
Le dossier que `campaign next` crée a `pipeline.weather: false` en dernier bloc de `mission.yaml` et pas de `src/versions.yaml` ; la date, l'heure et la météo sont **fixées dans la mission** elle-même.

- **La date avance avec la campagne** : la mission N+1 a lieu le lendemain de la mission N, dont `campaign apply` garde la date dans l'état de la campagne. La première prend `start_date` de `campaign.yaml`, ou la date du template.
- **L'heure sert la mission** : `start_time` de `campaign.yaml`, une heure (`"06:30"`) ou une expression solaire (`sunrise+30*60`, la valeur par défaut). L'expression est calculée pour le terrain de la campagne — le centre de ses zones — et la date de la mission, à l'heure du théâtre : le lever du soleil de la Colchide, pas celui de Damas que prend le `versions.yaml` livré.
- **La météo peut changer d'une mission à l'autre, le sol reste visible** : nuages absents, peu nombreux ou épars, base entre 1 500 et 3 500 m, visibilité de 8 km ou plus, ni brouillard ni pluie — CAVOK ou presque. Le tirage dépend du nom de la campagne et du numéro de la mission : la même mission retire le même ciel.

DCS ne fait pleuvoir que sous ses nuages « pluvieux », qui sont couvrants : une pluie légère sous un ciel dégagé n'existe pas, donc la météo d'une campagne n'a jamais de pluie.

Ce que `campaign next` a fixé est un point de départ : Claude, en préparant la mission, avance la date si l'histoire le demande et met l'heure que la mission veut (action `set_mission_date`), et peut changer la météo (`set_weather`) en gardant le sol visible.
Un second `campaign next` sur le même dossier garde ce qui a été réglé.
Le briefing DCS affiche la date, l'heure et la météo de la mission ; le briefing de mission les écrit aussi.

## Les waypoints des joueurs {#objective-waypoints}

`campaign next` écrit le `src/waypoints.yaml` de la mission à partir de ses objectifs, au lieu de garder l'exemple du template : un waypoint par zone que nomment les tâches de la mission dans `briefing.yaml` (à défaut, les objectifs de la campagne), au centre de la zone, dans l'ordre des tâches, pour le camp des joueurs.

- **Les avions** les reçoivent à 10 000 ft (`BARO`), **les hélicoptères** à 500 ft sol (`RADIO`) ; le cockpit affiche le même nom aux deux.
- **Le nom** est le premier mot de la zone, en majuscules et sans accent : *Khobi depot* devient `KHOBI`. Deux zones qui commencent par le même mot gardent leur nom entier (`SENAKI_NORTH`).
- **Le build ajoute `BULLSEYE`** à chaque plan de vol.

Une fois modifié, le fichier est à vous : il porte l'empreinte de ce que `campaign next` a écrit, et un second `campaign next` ne le réécrit que tant qu'elle correspond.
Un fichier écrit à la main dans un dossier déjà créé est gardé de même.
Le format du fichier est décrit dans la [référence du pipeline](../PIPELINE_REFERENCE.md#waypoints-by-key).

## Le document de briefing de campagne {#briefing-deck}

`campaign next` écrit aussi, dans `missions/mission-NN/`, le **briefing stratégique de la campagne** en PPTX (`briefing-campagne.pptx`) et sa carte (`carte-strategique.png`).
C'est un briefing de situation au format des briefings VEAF — 16:9, fond blanc, titre en gras en haut à gauche — qui s'importe tel quel dans Google Slides.
`.\veaf-tools.exe campaign briefing <dossier>` le régénère à tout moment, par exemple après avoir retouché le texte.

| Page | D'où elle vient |
|---|---|
| Situation stratégique — politique, économique | `briefing.yaml` |
| Situation militaire — forces ennemies, forces amies, terrain neutre | les outils, et le mode d'action ennemi de `briefing.yaml` |
| Carte stratégique | les outils : chaque zone à son rayon, dans la couleur de son propriétaire, et les axes |
| Mission et intention — mission, but, effet majeur, méthode, état final recherché | `briefing.yaml` |
| Objectifs de la campagne — politiques, militaires, économiques, conditions de victoire | `briefing.yaml`, et les objectifs de `campaign.yaml` |
| Concept d'opération — une phase par mission, points de vigilance | `briefing.yaml` |
| Règles d'engagement — ciblage, protection des civils et des infrastructures, autodéfense | `briefing.yaml` |
| Mission N — ses tâches | `briefing.yaml` |
| Annexe — Règles de la campagne | les outils, d'après les règles de `campaign.yaml` |

**Les faits sont générés, la prose est écrite.**
Les outils écrivent ce que la campagne sait ; la situation, l'intention, le concept et les règles d'engagement s'écrivent dans `briefing.yaml`, à côté de `campaign.yaml`, par Claude ou à la main.
Sans `briefing.yaml`, le document ne contient que la partie générée, et le dit ; `campaign validate` contrôle le fichier.
Seule l'annexe parle de la mécanique du jeu : le reste se lit comme un état-major parlerait.

**L'ennemi reste mystérieux.**
Le document ne donne jamais un effectif ennemi, ni sa réserve : seulement ce que le renseignement en dit, avec la fiabilité de sa source.
Un site fixe — le SAM longue portée d'une zone — est nommé dès que l'état de la campagne l'enregistre : sa batterie est tirée au démarrage de la mission, donc il est « probable, type non confirmé » avant la mission 1, puis nommé (« Batterie SA-10 confirmée ») à partir de la mission 2.
Une zone peut porter son propre texte de renseignement (`intel:`) et le nom que les joueurs lisent (`display_name: Dépôt de Khobi`).

```yaml
operation: Kolkhida
situation:
  political:
    - Il y a dix jours, les forces rouges ont franchi l'Inguri et pris pied dans la plaine de Colchide.
    - Une négociation s'ouvre ; chaque kilomètre tenu par l'adversaire à son ouverture lui sera acquis.
  economic: Le port de Poti ne tourne plus.
  enemy_course_of_action: Tenir Senaki sous sa défense aérienne, puis reprendre l'offensive.
mission: En 3 missions, la coalition reprend Senaki et détruit le dépôt de Khobi.
intent:
  purpose: Priver l'adversaire de sa capacité à reprendre l'offensive.
  main_effect: Priver Senaki de son soutien logistique.
  end_state: Senaki et Poti tenues, Khobi détruit, les villes épargnées.
objectives:
  political: [Rétablir l'autorité du gouvernement jusqu'à l'Inguri.]
  military: [Reprendre l'aérodrome de Senaki., Détruire le dépôt de Khobi.]
  economic: [Rouvrir le port de Poti, intact.]
concept:
  phases:
    - { title: "Phase 1 — mission 1 : la porte de Poti", text: Prendre Poti et commencer l'attrition de Khobi. }
  attention: [Zugdidi n'est pas un objectif.]
rules_of_engagement:
  targeting: [Identification positive de toute cible avant le tir.]
  civilians: [Pas de bombardement de zone dans les agglomérations.]
  self_defence: [Le droit de légitime défense n'est jamais restreint.]
missions:
  1:
    title: La porte de Poti
    tasks:
      - { title: Prendre Poti — priorité 1, text: Sécuriser le port avec des troupes héliportées. }
```

Chaque texte est une chaîne ou une liste de paragraphes.
Un texte qui contient « : » se met entre guillemets (`"Cibles autorisées : les unités rouges."`) : sans eux, YAML le lit comme une clé et sa valeur, et `campaign validate` le signale.
Après chaque mission, la page de la mission suivante et l'avancée du concept se réécrivent d'après le débriefing ; le reste se garde tant que la situation ne le change pas.

La carte est tracée sur les tuiles d'OpenStreetMap, gardées en cache dans `%LOCALAPPDATA%\veaf-tools\tiles` ; les outils s'identifient au serveur par leur adresse GitHub, et rien d'autre.
Sans réseau, la carte est tracée sur un fond uni et le document le signale : relancez `campaign briefing` une fois en ligne.

## Le briefing de mission {#mission-briefing}

À côté du briefing de campagne, chaque mission a son **briefing de mission** : `missions/mission-NN/briefing-mission.pptx`, au format du briefing de mission VEAF, avec sa carte tactique (`carte-tactique.png`) et un zoom par objectif (`zoom-<zone>.png`).
Il se lit dans la mission **construite** : `campaign briefing` l'écrit dès qu'un `.miz` existe dans `missions/mission-NN/mission` (à la racine ou dans `build/`), et dit sinon comment en obtenir un.
Relancez `campaign briefing` après chaque modification de la mission.

| Page | Ce qu'elle dit |
|---|---|
| Couverture | l'opération et le numéro de la mission, son titre (`briefing.yaml`), la date et l'heure |
| Situation générale | contexte, mission (les tâches), bullseye (DMS, relèvement et distance depuis une base amie), départs, menace (le renseignement, et l'alerte d'interception ennemie), météo et horaire **lus dans la mission** |
| ATO | les vols des joueurs (indicatif, type, nombre, base, lignes de pilotes, armement libre), les terrains à slots dynamiques, le soutien (AWACS, ravitailleurs) avec fréquence et TACAN, le contrôle (tour du porte-avions en VHF, terrains) |
| Situation tactique | zones, axes, zone d'alerte d'interception, porte-avions, orbite AWACS, hippodrome du ravitailleur, bullseye, les waypoints des joueurs numérotés comme au plan de navigation, échelle en nm |
| Une page par objectif | la zone à son rayon, son renseignement, la tâche qui la nomme |
| Déroulement mission | objectifs, opposition aérienne, défenses antiaériennes, autres informations (ravitaillement, dégagements, sauvetage) |
| Plan de fréquences | UHF puis VHF, la garde en tête |
| Plan de navigation | les waypoints que portent les avions puis les hélicoptères des joueurs après leur point de départ, `BULLSEYE` compris : nom, position en DMS, altitude et sa référence (`BARO`, ou `AGL` au-dessus du sol) ; les types d'appareil quand une catégorie porte plusieurs routes |
| Coordonnées des objectifs | le centre de chaque zone en DMS, et son altitude quand une grille de terrain a été relevée (`terrain-sweep`) |

Les objectifs sont les zones que nomment les titres des tâches de la mission dans `briefing.yaml` (« Frapper le dépôt de Khobi » nomme la zone *Dépôt de Khobi*), à défaut les objectifs de la campagne.
Les vols sont ceux des joueurs : ni les gabarits de slots dynamiques ni les modèles de spawn VEAF n'en sont ; un avion de soutien n'apparaît qu'une fois, selon sa tâche ; le vent se dit d'où il vient, comme le lit un pilote.

Le plan de navigation se lit dans les vols des joueurs et dans les gabarits de slots dynamiques, d'où partent les joueurs d'une campagne : ce sont les [waypoints](#objective-waypoints) que le build y a injectés.

**Pas de coordonnées de cible** : une garnison est tirée au démarrage de la mission, donc aucune position d'unité n'est connue quand le briefing s'écrit, et il le dit — les positions exactes se relèvent en vol.
Les étiquettes des cartes ne se chevauchent jamais, ni entre elles ni sur un symbole.

## Ce qui reste à vérifier en jeu {#to-verify}

Ces points sont écrits et testés hors de DCS, mais pas encore mesurés en jeu :

- l'effet de `Airbase.setCoalition` et `Airbase.autoCapture(false)` sur les slots dynamiques et les entrepôts d'une base qui change de camp ;
- l'exactitude du contenu des entrepôts lu en vol, et sa réécriture dans la mission suivante (pas encore faite) ;
- la possibilité de faire démarrer un SAM avec moins de missiles (le nombre restant est enregistré, pas encore rejoué) ;
- la façon de faire réapparaître détruit un pont ou un bâtiment (le décor détruit est enregistré, pas encore rejoué) ;
- la place des garnisons d'aérodrome, tirées autour du centre de la base.

Voir aussi la [référence du module `veafCampaign`](scripts/veafCampaign.md).
