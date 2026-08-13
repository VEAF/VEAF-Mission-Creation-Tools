# `veaf-mission-mcp` — serveur MCP d'édition de mission assistée par LLM

> **Public visé** : les développeurs qui font évoluer le serveur MCP d'édition de mission, ou
> qui branchent un client MCP (Claude Code, un agent) dessus.
>
> 🇬🇧 [`mission-editing-mcp.en.md`](mission-editing-mcp.en.md).
>
> 🎯 Côté Mission Maker (catalogue en langage courant) :
> [`mission-maker/AI_ASSISTANT_CATALOG.md`](../mission-maker/AI_ASSISTANT_CATALOG.md).

## Pourquoi ce serveur

Première phase de **NL-MISSION-GEN** (voir `ROADMAP.md` §4) : permettre à un LLM d'éditer une
mission DCS pour le compte d'un Mission Maker — et à terme, d'en générer une entière depuis un
prompt détaillé. Voir [ADR 0014](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0014-mission-editor-mcp-editor-parity-layer.md) pour la
décision d'architecture, et `CONTEXT.md` (section « LLM-assisted mission editing ») pour le
vocabulaire.

Deux familles d'actions, volontairement séparées :

- **Action editor-parity** — mute directement les tables Lua brutes du `.miz` source, exactement
  comme un Mission Maker le ferait à la main dans l'éditeur DCS (ajouter un groupe, un trigger,
  une zone). Ne passe jamais par `mission.yaml`. C'est tout le périmètre de ce serveur en v1.
- **Action VMCT** — passe par le pipeline déclaratif `mission.yaml` existant (`inject_presets`,
  `aircraft_groups`...). Depuis la **vague 4**, le serveur en expose une première brique : éditer
  le `mission.yaml` source (voir plus bas), en plus du pipeline CLI/config habituel.

## Lancer le serveur localement

```bash
poetry install
poetry run veaf-mission-mcp   # en dev
# ou, depuis le binaire livré (ce que le plugin Claude invoque) :
veaf-tools mcp
```

Démarre un serveur MCP sur `stdio` (transport par défaut du SDK `mcp`). Aucune configuration :
chaque action reçoit le chemin du `.miz` à éditer en paramètre. La sous-commande `veaf-tools mcp`
embarque le serveur dans le binaire `veaf-tools` déjà livré (pas de binaire séparé à builder) — c'est
elle que le plugin Claude déclare dans son `.mcp.json`.

## Catalogue d'actions (v1)

Le serveur n'expose **pas** un outil MCP par action métier. Il expose une surface de découverte
fixe, à l'image du serveur MCP `dcs-bridge` (pont vers une mission qui tourne) :

| Outil MCP | Rôle |
|-----------|------|
| `capabilities()` | Identité du serveur (nom, version). |
| `list_catalog()` | Liste les actions enregistrées (`name`, `description`, `parameters_schema`). |
| `describe_action(name)` | Détaille le schéma JSON des paramètres d'une action. |
| `run_action(name, params)` | Exécute une action enregistrée. |

Les actions elles-mêmes sont enregistrées par
`veaf_mission_mcp.actions.register_default_actions` (`src/python/veaf-tools/veaf_mission_mcp/actions.py`).

### `describe_mission`

Lecture seule. Liste les groupes (nom, coalition, pays, catégorie) et zones de déclenchement
(nom, position, rayon) déjà présents dans le `.miz` — pour que l'appelant vérifie l'état courant
avant d'écrire, comme un humain consulterait l'arborescence de l'éditeur avant d'ajouter quelque
chose. Réutilise le parseur pur-Python existant (`mission_tools.miz_tools.read_miz`) — aucun
nouveau parsing.

```json
{"miz_path": "chemin/vers/mission.miz"}
```

### `describe_units` (lot FEAT-MCP-MUTATION-ACTIONS)

Lecture seule. Le niveau de détail que `describe_mission` ne donne pas : les **unités** de chaque
groupe (type, `skill`, livrée, indicatif, numéro de flanc, position, cap, altitude, carburant,
leurres/canon), leur **emport** et la **route** du groupe avec les tâches de chaque point.

Trois choix de forme, chacun pour une raison mesurée sur une mission réelle (Foothold Caucasus
4.4.1, 357 unités armées) :

- **`pylons` est indexé par numéro de pylône, jamais positionnel.** DCS numérote les stations et
  les numéros ne sont **pas contigus** : un FA-18C réel porte les pylônes 1, 4, 5, 6 et 9. Dans
  cette mission, 170 unités sur 357 ont une disposition à trous, et le parseur Lua rend celles-ci
  en `dict` alors qu'il aplatit les contiguës en `list`. Un lecteur qui traiterait les pylônes
  comme une liste ordonnée aurait donc raison une fois sur deux et tort en silence le reste du
  temps — c'est ainsi qu'un futur *setter* accrocherait une arme sur la mauvaise station.
- **Les tâches automatiques de l'éditeur sont signalées et allégées.** Une tâche de point de
  passage est un `ComboTask` qui mélange la tâche voulue par l'auteur et les options que l'éditeur
  écrit tout seul (ROE, usage du radar, formation), toutes marquées `auto = true` : 1093 entrées
  automatiques contre 189 voulues sur cette mission. Les deux sont rapportées — les masquer
  fausserait la description — mais seules les tâches voulues portent leurs `params`.
- **Un plafond dont l'appelant est informé.** La mission entière fait 1,9 Mo de JSON, et un seul
  groupe de 62 points de passage en fait 18 ko. D'où les filtres (`group_name` par fragment,
  `coalition`, `category`), la limite par défaut de 50 groupes avec `truncated`/`matched` dans la
  réponse, et `include_route: false` qui **omet la clé** au lieu de renvoyer une liste vide (« pas
  demandé » n'est pas « ce groupe n'a pas de route »).

Les booléens sont rendus comme des booléens : DCS **omet** une clé qui vaut faux, et un appelant
qui lit `null` ne peut pas distinguer « désactivé » de « le lecteur n'a pas regardé ».

```json
{"miz_path": "chemin/vers/mission.miz", "group_name": "Colt", "include_route": false}
```

### `set_unit_properties` (lot FEAT-MCP-MUTATION-ACTIONS)

Écriture. La **première** action qui modifie un objet déjà présent dans la mission : toutes les
`set_*` livrées avant elle agissent sur la *configuration* (modules, sécurité, logs, coalition d'une
base). Sauvegarde horodatée avant écriture, comme ses sœurs.

Adresse l'unité par **nom exact** de groupe et **nom exact** d'unité — pas par fragment, contrairement
à `describe_units` : un fragment fait porter la modification au premier groupe qui correspond, ce qui
n'est pas rattrapable. Un nom introuvable liste ce qui existe, pour qu'un appelant réessaie sans
relire toute la mission.

Trois formes ont été **mesurées** sur de vraies missions plutôt que déduites, et deux contredisent le
ticket qui les demandait :

- **`skill` a sept valeurs, pas quatre.** `Average`, `Good`, `High`, `Excellent` et `Random` sont des
  niveaux d'IA ; `Client` et `Player` sont des **slots humains**. Franchir cette limite dans un sens
  ajoute une place à la liste multijoueur, dans l'autre la supprime — le bug pour lequel
  `FIX-TEMPLATE-SLOTS-VISIBLE` a été ouvert. Les deux sens sont donc refusés en nommant la raison,
  au lieu d'être honorés comme un réglage de compétence.
- **L'indicatif d'un appareil n'est pas un champ simple.** C'est une table
  `{1: famille, 2: vol, 3: numéro, name: "Colt11"}` où `name` est le mot de la famille suivi des deux
  indices (`{1:1, 2:1, 3:2}` se lit `Enfield12`). Écrire `name` seul désynchronise ce que DCS annonce
  à la radio de ce que montre l'éditeur : l'action modifie donc les indices et **reconstruit** `name`
  à partir du préfixe déjà présent. Changer la *famille* exige la table famille→mot de DCS, que ce
  dépôt n'embarque pas : c'est refusé sauf si l'appelant fournit lui-même le `name` résultant.
- **`heading` est en radians** alors qu'un créateur de mission parle en degrés — le piège que
  `resolve_coordinates` masque ailleurs. Le paramètre s'appelle `heading_deg` pour que l'unité soit
  impossible à confondre, et la valeur est normalisée sur un tour (−90 vaut 270).

Ce que l'action **ne valide pas**, faute des données pour le faire : le CLSID d'une arme face à
l'appareil qui la porte, et une livrée face aux peintures installées. DCS retire silencieusement une
arme impossible et affiche silencieusement la peinture par défaut, donc les deux limites sont
renvoyées comme `warnings` plutôt que sous-entendues par leur absence.

`pylons` est indexé **par numéro de station**, jamais positionnel, pour la raison mesurée dans
`describe_units`. `pylons` absent = « ne touche pas à l'emport » ; `{}` en mode `replace` = « ne porte
rien » ; en mode `merge`, un CLSID vide vide cette station.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "group_name": "Colt 1-1",
  "unit_name": "Colt 1-1-1",
  "skill": "Excellent",
  "heading_deg": 270,
  "pylons": {"4": ""},
  "pylons_mode": "merge"
}
```

La réponse porte `changed`, qui donne pour chaque champ touché sa valeur **précédente** et la
nouvelle : un appelant qui ne peut pas dire ce qu'il a remplacé ne peut pas le défaire.

### `set_group_properties` (lot FEAT-MCP-MUTATION-ACTIONS)

Écriture. Agit sur le groupe entier : déplacement, renommage, fréquence, modulation, et les trois
booléens (`lateActivation`, `hidden`, `uncontrolled`). Sauvegarde horodatée avant écriture.

**Le déplacement porte toute la conception de ce module, et ce n'est pas « écrire x et y ».** Un
groupe, ce sont des unités **en formation** plus éventuellement une **route**. La translation
s'applique donc à *toutes* les unités, *tous* les points de passage **et** l'ancre `x`/`y` du groupe,
d'un seul vecteur : autrement la formation se déforme, ou la route se détache des unités auxquelles
elle appartient — et aucun des deux ne se voit avant qu'on vole la mission. Le test du cisaillement
(déplacer les unités en laissant les points de passage) est écrit pour tomber sur toute
implémentation qui l'oublierait, et ça a été vérifié en cassant volontairement la translation.

Le vecteur vient de **l'offset géodésique** de `FEAT-GEO-PLACEMENT`
([ADR 0015](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0015-coordinate-projection-port.md)), pas d'une addition de mètres sur `x` : un théâtre
DCS est le monde réel projeté, donc « 5 km à l'est » est une question de latitude/longitude. Un
théâtre sans projection fait **refuser** la forme cap + distance, en invitant à passer `move_to`.

`frequency_mhz` est contrôlée face au `HumanRadio` de l'appareil, en réutilisant le validateur de
l'injecteur de presets plutôt qu'en le redérivant : `FIX-PRIMARY-FREQ-HUMANRADIO` a établi que
l'éditeur DCS **refuse d'enregistrer** une mission dont la fréquence primaire sort de cette plage.
**Tous** les types d'unités du groupe sont vérifiés, pas seulement le premier — un groupe hétérogène
passerait sinon sur son premier membre pour être refusé par l'éditeur à cause d'un autre.

Le renommage lance la vérification des conventions VEAF réservées (`validate_group_name`) et
**refuse par défaut** : un groupe renommé avec le nom de la zone de déclenchement d'une combat zone
est *despawné au démarrage*, en silence. Renommer *vers* une convention est une intention légitime,
d'où `acknowledge_conventions` — l'important est que ce soit délibéré. Les noms d'**unités** ne
suivent jamais : ils portent leurs propres marqueurs (`#command=`, `#veafInterpreter[...]`), qu'une
cascade réécrirait à l'aveugle.

Ce que l'action **ne peut pas** faire, mesuré et non oublié : vérifier la nature du sol à l'arrivée.
Il n'y a aucune donnée de terrain côté Python — `land.getSurfaceType` est une API d'exécution, seul
son schéma est livré ici — et c'est exactement pour cette raison que `FEAT-SCENERY-AWARE-SPAWN` a
résolu le problème à l'exécution. Le déplacement **avertit** donc qu'il n'a pas pu regarder, au lieu
de valider et de mentir.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "group_name": "Red SAM Battery",
  "move_bearing": 90,
  "move_distance_m": 5000,
  "late_activation": true
}
```

### `edit_route` (lot FEAT-MCP-MUTATION-ACTIONS)

Écriture. Deux couches : la **route** (`add`, `insert`, `remove`, `reorder`, `set`) est pour l'essentiel
une opération de liste sur `route.points` ; les **tâches** d'un point de passage (`add_task`,
`clear_tasks`) sont ce qui fait qu'un vol fait quelque chose.

**L'invariant qui en fait de la chirurgie et pas de l'édition de liste.**
`FIX-WAYPOINTS-ETA-LOCKED` a établi que DCS **refuse d'enregistrer** une mission dont une route n'a
aucun point de passage à heure verrouillée (« Route has no waypoints with locked time! »), et que sa
propre réparation consiste à verrouiller le premier. Supprimer ou réordonner peut donc produire une
mission que l'éditeur rejette, loin de l'édition qui l'a causée. Chaque opération rétablit l'invariant
et **le signale** quand elle a dû le faire.

**Unités.** La table de mission contient des mètres et des mètres par seconde ; un créateur de mission
parle en pieds et en nœuds. Comme pour le `heading_deg` de `set_unit_properties`, les paramètres portent
leur unité dans leur nom (`altitude_ft`, `speed_kt`) et la réponse donne les deux, pour que l'appelant
n'ait jamais à reconvertir.

**Les tâches sont un jeu nommé à signatures vérifiées, pas une table libre** — choix explicite du
ticket : une action générique « écris cette table de tâche » est un piège, parce qu'un agent produit une
table plausible, DCS l'ignore en silence, et le créateur de mission le découvre une heure plus tard.
L'échappatoire démarre **fermée**.

Chaque signature a été lue dans une vraie mission, et trois sont des pièges :

- **`SetFrequency` prend des hertz** (`31000000` pour 31 MHz) alors que la fréquence d'un *groupe* —
  `set_group_properties` — est en MHz. Deux unités pour la même notion, dans le même fichier. L'action
  prend des MHz et convertit.
- **`EngageTargetsInZone` duplique sa liste de cibles** dans une chaîne sérialisée `value`
  (`"Air;Cruise missiles;"`) à côté du tableau `targetTypes` ; n'écrire que le tableau laisse la mission
  porter deux versions de la même décision.
- **`SetFrequency` et `SwitchWaypoint` ne sont pas des tâches** mais des *actions*, portées dans une
  enveloppe `WrappedAction`. Écrite comme une tâche nue, DCS l'ignore.

Deux détails mesurés qui n'étaient pas dans le ticket : `type` et `action` d'un point de passage sont
une **paire** (« Land » va avec « Landing »), et un point ajouté **hérite** de l'altitude et de la
vitesse de son voisin — sinon il s'écrit à l'altitude 0 et le vol plonge au sol pour l'atteindre.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "group_name": "Colt 1-1",
  "operation": "add_task",
  "index": 2,
  "task": "orbit",
  "task_params": {"pattern": "Race-Track", "altitude_ft": 20000, "speed_kt": 300}
}
```

### `edit_zone` (lot FEAT-MCP-MUTATION-ACTIONS)

Écriture. `add_trigger_zone` ne crée que des zones **circulaires** et rien n'en modifiait une ensuite,
donc ajuster une combat zone VEAF — qui *est* une zone de déclenchement — imposait de la supprimer et
de la refaire.

**Deux mesures avant toute ligne de code**, comme le ticket l'exigeait :

- **La forme réelle d'une zone polygonale**, lue dans `veaf-demo-mission.miz` (`czBatumi`) : `type: 2`
  plus une liste `verticies` — l'orthographe de DCS, conservée telle quelle parce que corriger la
  coquille écrirait un champ que DCS ignore — tandis que `x`, `y` et `radius` **restent présents**. Un
  polygone n'est donc pas un cercle avec des champs en plus.
- **Ce que le runtime VEAF gère.** `veafCombatZone.lua` ne teste que deux types : `0` →
  `mist.getUnitsInZones`, `2` → `mist.getUnitsInPolygon(triggerZone.verticies)`. Il n'y a **pas de
  `else`**, donc une zone d'un autre type ne contiendrait aucune unité, en silence — pire que de ne pas
  proposer la forme. L'action n'écrit donc que 0 et 2.

**Décision de David sur le nombre de sommets (2026-08-12)** : accepter trois ou plus, puisque « suivre
la ligne de crête » est le cas d'usage réel et que mist gère un polygone quelconque — mais **avertir**
dès que le compte n'est pas quatre, l'éditeur DCS ne dessinant que des quadrilatères. Savoir s'il
préserve davantage est une question de jeu, qu'aucun test unitaire ne tranche.

Deux refus que le ticket laissait ouverts, décidés ici : un **lien vers une unité inexistante** est
refusé plutôt qu'averti (une zone liée à rien ne suit simplement jamais rien, sans bruit), et une
**collision de nom** est refusée (les zones sont référencées par nom depuis `mission.yaml`).

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "zone_name": "czBatumi",
  "vertices": [
    {"x": -359753.0, "y": 614918.0},
    {"x": -355602.0, "y": 622688.0},
    {"x": -352849.0, "y": 617192.0},
    {"x": -358731.0, "y": 614282.0}
  ]
}
```

### `add_map_drawing` / `edit_map_drawing` (lot FEAT-MCP-MUTATION-ACTIONS)

Écriture. Rien dans VMCT ne touchait aux dessins de la carte F10, donc une ligne de briefing, un couloir
d'entrée ou une boîte interdite se dessinait à la main dans l'éditeur — **et disparaissait dès que la
mission était reconstruite depuis son dossier**. C'est tout l'argument : un dessin posé par un agent
fait partie de la recette, un dessin fait à la main non.

**La mesure qui gouverne la conception**, lue dans les fixtures du dépôt :

> Les `points` sont **relatifs à l'ancre `mapX`/`mapY`** du dessin, le premier valant `{0, 0}`.

Un dessin écrit en coordonnées absolues atterrit à des centaines de kilomètres et **rien ne lève
d'erreur** — la même classe de panne silencieuse que confondre le `{x=nord, y=est}` de la table de
mission avec un vec3 d'exécution (voir `docs/agents/dcs-coordinates.md`). Les actions prennent donc les
coordonnées **absolues** dont l'appelant dispose et font l'ancrage elles-mêmes. Le bénéfice apparaît
dans `edit_map_drawing` : déplacer un dessin, c'est déplacer son ancre, et la forme suit gratuitement.

**Trois formes sont livrées parce que trois formes ont été mesurées** : `Line` (avec `lineMode`
`segment` ou `segments`, et `closed` pour une forme qui se referme — c'est ainsi qu'on délimite une
zone libre), `Polygon` en mode `rect` (`width`/`height`/`angle`, **aucun** point), et `TextBox`
(`text`/`font`/`fontSize`, pas de points non plus ; la police est reprise d'un vrai dessin, une police
absente de DCS ne s'affichant pas du tout).

Les autres `polygonMode` (`circle`, `oval`, `free`, `arrow`) et `primitiveType: "Icon"` sont **absents
de toutes les fixtures** du dépôt : leur structure est donc inconnue, et la règle du ticket est de lire
un vrai `.miz` plutôt que de supposer. Ils sont refusés en le disant — inventer une structure ici
produirait un dessin que l'éditeur supprime en silence, exactement ce que `FIX-MAPRESOURCE-KEY` et
`FIX-COMMUNITY-SOUNDS-PRUNED` ont déjà coûté. La mesure est inscrite dans `DCS-SESSION-TODO.md`.

La **couche** est un paramètre de première classe, jamais une valeur par défaut : un dessin sur la
mauvaise couche est invisible pour les pilotes qui en ont besoin et visible pour ceux qui ne devraient
pas le voir.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "layer": "Blue",
  "shape": "line",
  "name": "FSCL",
  "points": [{"x": -300000.0, "y": 600000.0}, {"x": -290000.0, "y": 610000.0}]
}
```

### `add_group`

Écriture. Insère un groupe terrestre/véhicule dans le `.miz` source, **en place**, avec une
sauvegarde horodatée systématique avant l'écriture
(`mission_tools.miz_backup.backup_before_write`, ex. `mission.20260712-143012.miz`). Une
collision sur la même seconde est désambiguïsée (`-2`, `-3`, ...), jamais silencieusement
écrasée.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "coalition": "red",
  "country_id": 0,
  "country_name": "Russia",
  "category": "vehicle",
  "name": "Red Armor Section",
  "position": {"x": 1000.0, "y": 2000.0},
  "units": [{"type": "T-72B", "count": 2}],
  "route": [{"x": 1000.0, "y": 2000.0}, {"x": 1200.0, "y": 2000.0}],
  "patrol": true
}
```

- `units` — le serveur ne fait **aucune** curation de catalogue d'unités : les types DCS
  concrets (`T-72B`, `BTR-80`...) sont la décision de l'appelant (LLM), pas de cette action.
  Chaque unité peut porter un `name` explicite (sinon auto-nommée). C'est **là** qu'on pose un
  marqueur de combat zone (le runtime les lit sur le **nom d'unité**) : `#command`, `#spawngroup`,
  `#spawnradius`, `#spawncount`, `#spawnchance`, `#spawndelay`. L'idiome classique = un groupe
  « fausse unité » dont le nom est `#command="-armor ..."` (alias `list_shortcuts`) : à
  l'activation de la zone, il spawne le groupe décrit. Ex. `units: [{"type": "Soldier M4",
  "name": "#command=\"-armor, spawnRadius 300\""}]`.
- `route` — optionnelle ; par défaut un unique point stationnaire à `position`. Avec
  `patrol: true` (et au moins 2 points), le dernier point boucle sur le premier via une tâche
  `GoToWaypoint` — une patrouille terrestre DCS classique.
- **Pas de déduplication** : appeler deux fois avec les mêmes paramètres crée deux groupes
  distincts, exactement comme deux clics dans l'éditeur DCS.
- Les `groupId`/`unitId` sont toujours frais (`mission_tools.group_insertion.max_ids`), y compris
  sur une mission aux plages d'ids déjà trouées.

**Intentions de nommage (vague 6).** L'appelant exprime l'*intention* et `add_group` produit un
nom conforme aux conventions VEAF lui-même (`veaf_mission_mcp.group_naming.resolve_group_name`) :

- `for_combat_zone: <zone>` — préfixe le nom par le nom de la trigger-zone (règle d'appartenance
  combat zone), idempotent et insensible à la casse ;
- `late_activation: true` — pose le drapeau DCS `lateActivation` (intercepteurs QRA, templates CAP) ;
- `as_spawn_template: true` — préfixe `veafSpawn-` (template d'avion spawnable).

`add_group` renvoie aussi un champ `warnings` (voir `validate_group_name` ci-dessous) : il **écrit
quand même**, mais signale toute collision de convention pour que l'appelant la relaie.

### `validate_group_name` (vague 6)

Lecture seule. Contrôle un nom proposé contre les motifs réservés (préfixes
`veafSpawn-`/`OnDemand-`/`VEAF-placeholder-`, marqueurs `#veafInterpreter[...]`/`#command=`,
syntaxe de déploiement QRA, noms CAS fixes) et, avec `miz_path`, le **piège de capture combat
zone** (nom commençant par une trigger-zone existante). `expected_combat_zone` supprime
l'avertissement pour la zone intentionnellement visée. Partage le module
`veaf_mission_mcp.group_naming` avec `add_group`.

```json
{"name": "combatZone_North-tanks", "miz_path": "chemin/vers/mission.miz"}
```

### `add_trigger_zone` (vague 2)

Écriture. Insère une **zone de déclenchement circulaire** nommée dans `mission.triggers.zones`,
avec un `zoneId` frais, en place et sauvegardée d'abord. C'est la zone qu'une combat zone VEAF
référence : combinée à `add_group`, elle permet de poser une combat zone complète (la trigger
zone que `group_validation` exige + les groupes à l'intérieur). Pas de déduplication.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "name": "combatZone_North",
  "position": {"x": 1000.0, "y": 2000.0},
  "radius": 3000,
  "hidden": false
}
```

### `add_startup_script_trigger` (vague 2)

Écriture. Ajoute un trigger **« au démarrage de la mission »** qui exécute un script — pour
outiller une mission **vanilla ou CTLD** avec du scripting sans passer par l'onglet Triggers de
l'éditeur DCS. Généralise `inject_dcs_bridge_trigger` et le chargement static/dynamic VEAF
([ADR 0004](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0004-dynamic-script-loading.md)). Contrairement à ce helper (qui insère en
position 1 et renumérote tout), cette action **ajoute à la fin** (index libre suivant) — aucun
trigger existant n'est renuméroté. Trois modes :

- **`inline`** — exécute du Lua fourni (`inline_lua`) via `a_do_script`.
- **`file_static`** — embarque un fichier `.lua` (`source_path`) dans le `.miz`
  (`l10n/DEFAULT/<nom>.lua` + entrée `mapResource`) et le charge via `a_do_script_file`.
- **`file_dynamic`** — charge un `.lua` depuis un chemin disque à l'exécution (`runtime_path`)
  via `loadfile`, sans rien embarquer.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "mode": "file_static",
  "comment": "load my script",
  "source_path": "C:/scripts/myscript.lua"
}
```

Sauvegarde horodatée avant écriture ; pas de déduplication.

## Édition des fichiers Lua embarqués (vague 3)

Troisième famille d'actions : éditer le **texte** des fichiers `.lua` embarqués dans le
`.miz` (`l10n/DEFAULT/**/*.lua`), **sans rebuild** — ni les tables brutes `mission.lua`
(editor-parity), ni le pipeline `mission.yaml` (action VMCT). Brique commune :
`mission_tools.rewrite_miz_members` recopie l'archive verbatim et ne remplace que les membres
ciblés (aucune re-sérialisation des tables Lua). Sauvegarde horodatée avant chaque écriture.

### `replace_in_mission_files` — search/replace générique

Remplacement texte ou regexp, **restreint à `l10n/DEFAULT/**/*.lua`** (jamais `mission`/
`options` ni les binaires). `files` est un glob appliqué au chemin relatif sous
`l10n/DEFAULT/`.

```json
{
  "miz_path": "chemin/vers/mission.miz",
  "search": "debug",
  "replace": "info",
  "files": "veaf-*.lua",
  "regex": false
}
```

Retourne `{files_changed, total_replacements}`.

### Réglages VMCT (`veaf-config.lua`)

Actions sémantiques qui éditent `l10n/DEFAULT/veaf-config.lua` (config VEAF générée au build).
Chacune **remplace la ligne si elle existe, sinon l'insère** en tête (avant l'init des
modules) :

- `set_log_level(level)` → `veaf.ForcedLogLevel = "<level>"` (parmi error/warning/info/debug/trace).
- `set_module_enabled(module_id, enabled)` → `veaf.setConfig("<MOD>", "enable", <bool>)`.
- `set_security_disabled(disabled)` → `veaf.SecurityDisabled = <bool>`.
- `set_veaf_config(key, value)` → `veaf.config.<key> = <scalaire Lua>`.

### Coalition d'un aérodrome

- `set_airbase_coalition(folder_path, name, coalition)` — assigne durablement un aérodrome DCS à une
  coalition, dans un **dossier de mission**.

> ⚠️ La coalition d'un aérodrome vit dans `warehouses.airports[<id>].coalition`, **pas** dans
> `mission.coalition`. Poser une unité à côté d'une base ne la fait donc jamais changer de camp :
> c'est cette action qu'il faut. Elle résout le nom de l'aérodrome en identifiant via le théâtre de
> la mission, pose la coalition, et **active les slots Dynamic Spawn** de la base (le build les
> approvisionne ensuite). Sauvegarde préalable, comme les autres actions d'édition.

> Les **hashes de mot de passe** (`veafSecurity.password_L9[...]` / `password_MM[...]`) — un cas
> multi-lignes — ne sont pas couverts pour l'instant : seul le drapeau `SecurityDisabled` l'est.

## Actions VMCT sur `mission.yaml` (vague 4)

Quatrième famille — la première vraiment **VMCT** : éditer le **source déclaratif**
`mission.yaml` (ce que le build consomme pour *générer* le `.miz`), au lieu de patcher un
artefact déjà construit. Brique commune : `mission_tools.mission_yaml_editor` (mode round-trip
`ruamel.yaml`) qui **préserve commentaires, ordre des clés et mise en forme** — indispensable
pour un fichier source très commenté, édité à la main et tenu en lockstep avec le défaut livré.
Sauvegarde horodatée avant chaque écriture.

### `describe_mission_config`

Lecture seule. Liste le bloc `modules:` et, par module, son état : `mandatory` (clé nue),
`scalar` (booléen `MODULE: true/false`) ou `extended` (bloc de config imbriqué type
`COMBATZONE`/`CTLD`). Le pendant VMCT de `describe_mission`.

```json
{"mission_yaml_path": "chemin/vers/mission.yaml"}
```

### `set_mission_module`

Écriture. Active/désactive un module ou pose son bloc de config étendu, en préservant les
commentaires. `value` est soit un booléen (forme scalaire), soit un objet (bloc étendu). La clé
est **remplacée si présente, insérée sinon**. Pas de déduplication.

```json
{
  "mission_yaml_path": "chemin/vers/mission.yaml",
  "module_id": "COMBATZONE",
  "value": {"enabled": true, "combat_zones": [{"type": "zone", "zone_name": "CZ-Alpha"}]}
}
```

> Périmètre volontairement **générique** (toggle + pose de mapping) — pas de validateur de
> schéma par module : la forme du bloc de config passé reste la responsabilité de l'appelant
> (LLM), comme les types d'unités pour `add_group`.

### Parité recette / construit (vague 7)

Chaque réglage éditable sur le `veaf-config.lua` construit (vague 3) a son pendant **source**
`mission.yaml`, pour que les deux cibles soient joignables. Actions séparées (cohérent avec
`set_mission_module`), sur la brique `mission_yaml_editor` :

| Réglage | Recette (`mission.yaml`) | Construit (`veaf-config.lua`) |
|---------|--------------------------|-------------------------------|
| Niveau de log | `set_mission_log_level` → `global_log_level` | `set_log_level` |
| Sécurité | `set_mission_security` → bloc `security:` (**+ hash de mots de passe**) | `set_security_disabled` |
| Paramètre arbitraire | `set_mission_setting` → `settings.<clé>` | `set_veaf_config` → `veaf.config.<clé>` |
| Activation de module | `set_mission_module` (vague 4) | `set_module_enabled` |

## Oracle de connaissance métier (vague 5)

Les actions ci-dessus sont les **mains** (écriture) et les **yeux** (`describe_*`) du LLM. La
vague 5 lui donne un **cerveau** : des actions de **lecture seule** exposant la connaissance
DCS + VEAF nécessaire pour éditer correctement. Toutes lisent depuis les **sources canoniques**
que le build utilise déjà, donc **sans dérive possible** :

- Données DCS générées (`update-dcs-data` → `veaf_libs/data/dcsUnits.yaml`, publiées sur le
  GitHub VEAF) ;
- alias VEAF (`veaf_libs/data/veaf-units.yaml`) ;
- artefacts vendorisés (`vendored.yaml`, `check-vendored`) ;
- repos de datamining en amont (provenance).

Implémentation : `veaf_mission_mcp/oracle.py`. Le pendant « prose / comment raisonner » vit dans
le skill Claude `veaf-mission-authoring` (`plugin/skills/veaf-mission-authoring/SKILL.md`, bundlé
par `bfr-claude-plugins`) — le plugin = mains MCP + cerveau skill.

### `list_unit_types`

Lecture seule. Types d'unités DCS depuis la base générée, filtrables par `category` et/ou
`name_contains`. Pour que le LLM choisisse des types concrets.

```json
{"category": "Plane", "name_contains": "su-27"}
```

### `list_shortcuts`

Lecture seule. Le vocabulaire d'alias VEAF (`shilka`, `sa8`…) — alias d'unités
(`_spawn unit <alias>`) et de groupes composites (`_spawn group <alias>` : sites SAM, convois).
Filtrable par `name_contains`.

### `describe_naming_conventions`

Lecture seule. Les **8 motifs de nommage réservés** (appartenance combat zone, préfixes
`veafSpawn-`/`OnDemand-`, marqueurs `#veafInterpreter[…]`/`#command=`, entrées de déploiement
QRA, noms CAS fixes…) avec, pour chacun, la règle et le module qui la consomme. À vérifier avant
un `add_group`.

### `describe_module`

Lecture seule. **Localisateur** (pas un validateur de schéma) : vérifie qu'un module VEAF existe
(via la liste canonique `lua_module_scanner`), renvoie sa page de doc, et — si `mission_yaml_path`
est fourni — son état activé. Les clés de config de chaque module vivent dans sa page de doc.

```json
{"module_id": "QRA", "mission_yaml_path": "chemin/vers/mission.yaml"}
```

## Composites — une passe, deux mondes (vague 8)

Actions haut niveau qui posent une **fonctionnalité complète** en un appel, sur un **dossier de
mission** : elles éditent la **source durable** (le `src/mission/` exploité — zones/groupes — via
`mission_folder`, **et** `mission.yaml`), sans déclencher de build (un `veaf-tools mission build` ultérieur
produit le `.miz`). Elles orchestrent les primitives des vagues 1-7 (`insert_trigger_zone`,
`insert_group_into_content`, l'éditeur `mission.yaml`). Implémentation : `veaf_mission_mcp/composites.py`.

### `create_combat_zone`

Zone de déclenchement + groupes placés dedans (noms auto-préfixés par la zone → capturés au
runtime, coalition indifférente) + bloc `modules.COMBATZONE.combat_zones[]` **ajouté** au yaml.

### `create_qra`

Zone + intercepteurs **Late Activation** (coalition significative) + entrée
`modules.QRA.definitions[]` référençant les groupes **par nom exact** (`simple_groups`). La
coalition est passée en minuscule pour le placement, majuscule dans la définition YAML.

### `create_cap_mission`

Groupe template **Late Activation** nommé `OnDemand-<nom>` + entrée `cap_missions[]`
(`group_name: <nom>`, sans préfixe — le build résout vers le groupe `OnDemand-`).

## Scaffolding d'un dossier de mission (vague 9)

Toutes les actions ci-dessus supposent qu'un dossier de mission **existe déjà**. La vague 9 fournit
l'amont : créer ce dossier depuis un **dossier vide**, en pilotant les vrais binaires VEAF comme le
ferait un Mission Maker à sa première installation.

### `scaffold_mission`

Écriture. Sur un dossier cible **vide** :

1. Résout l'asset updater de l'OS courant (`veaf-tools-updater.exe` sous Windows,
   `veaf-tools-updater-<os>-<arch>` sous Unix) et le télécharge depuis l'**URL de release stable**
   (`…/releases/download/<tag>/<asset>` — pas d'API GitHub, donc pas de rate-limit).
2. Lance l'updater dans le dossier (il télécharge et installe les outils VEAF + `published/`).
3. Lance `veaf-tools mission prepare --template <tier> --force` dans le dossier.

```json
{
  "target_folder": "chemin/vers/dossier-vide",
  "template": "standard",
  "github_token": "…",
  "tag": "published-latest"
}
```

- **Refuse un dossier non vide** — le scaffolding n'initialise qu'un dossier vide.
- `template` — `minimal` / `standard` / `full`. Le tier interactif `custom` n'est **pas** supporté
  ici (son sélecteur TUI n'a pas de TTY sous un sous-processus) ; c'est au LLM appelant de **poser
  la question du template** au Mission Maker et de le passer en paramètre.
- `theatre` — optionnel ; relayé à `prepare --theatre` pour déposer une **mission vierge
  synthétique** de cette carte DCS dans `src/mission/` (sans passer par DCS). Omis → `src/mission/`
  reste vide (le maker fournit son propre `.miz`).
- `github_token` — optionnel, relayé à l'updater (`--token`) pour contourner la limite de débit de l'API.
- Un code retour non nul de l'updater ou de `prepare`, ou l'absence de `veaf-tools`/`published/`
  après l'updater, remonte comme une erreur explicite.

C'est l'**étape 0** d'une mission créée de zéro, avant les composites de la vague 8.

## Carte & coordonnées (vague 10)

Les actions de placement prennent des **coordonnées locales DCS** (`x`/`y`, en mètres dans la
projection propre au théâtre) ; un Mission Maker raisonne plutôt en lat/long sur une carte. La vague
10 donne au LLM de quoi se repérer et convertir, en design-time (sans DCS lancé).

Socle : `veaf_libs.coordinates` — Transverse Mercator WGS84 pur-Python (pas de `pyproj`), dont les
constantes par théâtre viennent de la donnée vendorisée `data/dcs-maps.yaml` (export MIT de
[VEAF/dcs-maps](https://github.com/VEAF/dcs-maps), voir [ADR 0015](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0015-coordinate-projection-port.md))
— **tous les théâtres DCS** (Caucasus, Syria, PersianGulf, Marianas, Normandy, Nevada, SinaiMap,
GermanyCW, Kola, TheChannel, Falklands, Afghanistan, Iraq). Comme les cartes DCS **sont le monde
réel projeté**, ce socle relie `x/y DCS ↔ lat/lon réel`.

### `describe_map`

Lecture seule. Depuis un `.miz` **ou** un dossier de mission : renvoie le **théâtre**, les
**bullseyes** par coalition, et les zones/groupes existants comme **points de repère** — pour que le
LLM s'oriente sans DCS.

```json
{"mission_path": "chemin/vers/mission.miz-ou-dossier"}
```

### `resolve_coordinates`

Utilitaire. Convertit une position entre `{x, y}` (local DCS) et `{lat, lon}` (degrés décimaux) pour
le théâtre de la mission (lu depuis la mission — l'appelant ne fournit jamais de paramètres de
projection).

```json
{"mission_path": "…", "position": {"lat": 42.18, "lon": 41.68}}
```

### `geocode`

Lecture seule (lot `FEAT-GEO-PLACEMENT`). Résout un **nom de lieu réel** en coordonnées DCS pour le
théâtre de la mission — les cartes DCS étant le monde réel projeté. Géocodeur **enfichable** :
OpenStreetMap Nominatim par défaut (gratuit, sans clé ; attribution © OpenStreetMap requise), Google
Maps si `GOOGLE_MAPS_API_KEY` est défini. `bearing`+`distance_km` optionnels (« à 10 km au nord de
X »). Renvoie `{found, display_name, latlon, xy, in_theatre_bounds, warnings}` — approximatif, à
confirmer visuellement ; les lieux nommés marchent, le terrain vague non.

```json
{"mission_path": "…", "query": "Kobuleti", "bearing": 0, "distance_km": 10}
```

## Build & validation (vague 11)

Les actions précédentes créent, orientent et éditent un **dossier de mission**, mais rien ne
produisait le `.miz` jouable — le maker lançait `veaf-tools mission build` à la main. La vague 11 rend le
serveur **autonome de bout en bout** : dossier vide → scaffold → blank théâtre → composites/placement
→ **validation → build → `.miz` jouable**, sans quitter l'assistant.

### `validate_mission`

Lecture seule. Lint d'un **dossier** avant build : réutilise `veaf_libs.mission_validator` en
process. Renvoie `{ok, errors[], warnings[]}` (`ok = false` dès qu'une erreur). À lancer avant
`build_mission`.

```json
{"folder_path": "chemin/vers/dossier-mission"}
```

### `build_mission`

Écriture. Construit le dossier en `.miz` jouable en pilotant **`veaf-tools mission build`** dans le dossier
(le binaire installé par `scaffold_mission`, ou `veaf-tools` du PATH). L'orchestration du build vit
dans la commande CLI, on la réexécute telle quelle. Un échec de build est remonté (`RuntimeError`).

```json
{"folder_path": "chemin/vers/dossier-mission"}
```

## Prochaines vagues (hors périmètre)

- Un éditeur de triggers SI/ALORS générique (conditions/actions DCS arbitraires) — la vague 2
  se limite aux triggers de démarrage chargement-de-script / exécution-Lua.
- Un validateur de schéma par module pour `set_mission_module` (la vague 4 reste générique).
- Composites CAS (pur runtime, pas d'écriture) et génération end-to-end
  depuis un prompt (l'objectif NL-MISSION-GEN au-delà de ce lot).

Voir `.backlog/archive/FEAT-MCP-MISSION-EDITOR.md` pour le détail.
