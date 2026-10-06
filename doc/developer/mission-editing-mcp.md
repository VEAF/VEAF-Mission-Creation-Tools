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

!!! note "La mission se nomme `mission_path`, partout (FIX-OPEN-TRAINING-PROMPT-FINDINGS, ticket 05)"

    42 des 47 actions prenaient la mission sous cinq noms : `miz_path` (17), `target` (9),
    `folder_path` (6), `mission_path` (4) et `mission_yaml_path` (6). Le catalogue publie désormais
    **`mission_path`** (un dossier de mission ou un `.miz`) pour toutes, et le traduit vers la clé que
    le gestionnaire lit : les trois anciens noms restent acceptés comme alias, les exemples ci-dessous
    qui les emploient restent valides. `mission_yaml_path` est gardé, puisqu'il désigne un autre fichier ;
    un `mission_path` donné à sa place (un dossier) est lu comme `<dossier>/mission.yaml`. Un test du
    catalogue échoue si une nouvelle action introduit un sixième nom.

!!! note "`miz_path` accepte aussi un **dossier** de mission (lot FIX-MCP-AUTHORING-GAPS, ticket 03)"

    Toutes les actions d'édition — `edit_route`, `set_group_properties`, `set_unit_properties`,
    `edit_zone`, `add_trigger_zone`, `add_map_drawing`, `edit_map_drawing` — prennent soit un `.miz`,
    soit un **dossier de mission**, exactement comme le `target` de `add_group`. Le compromis est le
    même : une édition dans un dossier est **durable** (elle va dans `src/mission/`, donc elle survit
    au `veaf-tools build` suivant), une édition dans un `.miz` est transitoire (le build suivant
    l'écrase). Chaque action renvoie désormais `durable` pour le dire. Sauvegarde horodatée dans les
    deux cas.

    Avant, elles n'acceptaient qu'un `.miz` : un groupe pouvait être **créé** durablement mais pas
    **modifié** durablement, et pointer `edit_route` sur le dossier échouait sur un
    `[Errno 13] Permission denied` (lire un répertoire comme une archive zip). Un dossier qui n'est pas
    un dossier de mission est maintenant refusé avec un message qui le dit.

Le serveur n'expose **pas** un outil MCP par action métier. Il expose une surface de découverte
fixe, à l'image du serveur MCP `dcs-bridge` (pont vers une mission qui tourne) :

| Outil MCP | Rôle |
|-----------|------|
| `capabilities()` | Identité du serveur (nom, version). |
| `list_catalog(full=False)` | Liste les actions enregistrées en `{name, summary}` — la première phrase de la description, une dizaine de ko pour toutes ; `full=true` rend chaque `description` et `parameters_schema` (quelque 70 ko, qu'un client range dans un fichier au lieu de les montrer). `describe_action` en donne une en entier. |
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

> Depuis `FIX-SCRATCH-MISSION-FINDINGS` ticket 19, elle **renomme** (`new_name`, refusé si une autre
> unité porte déjà ce nom : DCS les veut uniques dans toute la mission) et **déplace** (`position`)
> une unité seule ; l'ancre et la route du groupe ne bougent pas. Pour un avion, dont la place tient
> à la route, un avertissement le signale.

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
  impossible à confondre, et la valeur est normalisée sur un tour (−90 vaut 270). **Sur un appareil en
  vol** (catégorie avion/hélico, route de 2+ points, premier waypoint en l'air), l'action **avertit** :
  DCS recalcule le cap depuis le premier segment de la route à la sauvegarde, donc le cap posé a une
  durée de vie d'une sauvegarde (`FIX-MCP-EDITOR-ROUNDTRIP`, mesuré 2026-08-15). Pour orienter un
  appareil en vol, on règle la route, pas le cap. Le cap est **quand même écrit** — l'avertissement
  informe, il ne refuse pas ; un appareil parké ou une unité au sol ne déclenchent pas l'avertissement.

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

**Route ou hors route.** Sur un groupe **terrestre**, `road: true` écrit l'action `On Road` d'un `Turning Point` (les véhicules suivent les routes), `road: false` écrit `Off Road` ; pour `add`, `insert` et `set`.
Refusé sur un autre groupe et sur un autre type de point.
Tous les points étaient écrits `Turning Point`, et le convoi de la mission de démo coupait à travers champs (FIX-DEMO-MISSION-FINDINGS 07).

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
vitesse de son voisin — sinon il s'écrit à l'altitude 0 et le vol plonge au sol pour l'atteindre —
**sauf si `altitude_ft`/`speed_kt` sont fournis à `add`/`insert`**, auquel cas ils sont écrits
(`FIX-MCP-EDITOR-ROUNDTRIP` : ils étaient acceptés puis silencieusement ignorés, l'héritage écrasant la
valeur demandée).

**Les tâches d'attaque doivent porter le jeu de champs complet que l'éditeur conserve.**
`FIX-MCP-EDITOR-ROUNDTRIP` a mesuré (2026-08-15) qu'un `Bombing` écrit sans `weaponType` est **jeté par
l'éditeur à la sauvegarde** — un dispositif d'attaque qui ne largue rien. `Bombing` et `AttackGroup`
portent donc désormais `weaponType` (défaut « Auto » mesuré : 2032 pour Bombing, 9659482112 pour
AttackGroup, surchargeable via `weapon_type`), les paires `altitude`/`altitudeEnabled` et
`direction`/`directionEnabled` **présentes mais désactivées** par défaut (activées si l'appelant passe
`altitude_ft`/`direction_deg`), et l'ensemble `expend`/`attackQty`/`groupAttack`. `EngageTargetsInZone`
porte aussi `noTargetTypes` (liste d'exclusion, vide par défaut).

**L'ordre des tâches compte.** DCS les exécute par `number`, et une tâche placée après une orbite sans
fin n'est jamais atteinte. `add_task` ajoute à la fin par défaut ; `task_position` (1-based) l'insère à
une place donnée et renumérote les autres — pour mettre un engagement **avant** l'orbite
(`FIX-SCRATCH-MISSION-FINDINGS` ticket 17).

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
- **Ce que le runtime VEAF gère.** À l'époque, `veafCombatZone.lua` ne testait que deux types : `0` →
  `mist.getUnitsInZones`, `2` → `mist.getUnitsInPolygon(triggerZone.verticies)`. Il n'y avait **pas de
  `else`**, donc une zone d'un autre type ne contenait aucune unité, en silence — pire que de ne pas
  proposer la forme. L'action n'écrit donc que 0 et 2. Depuis `DROP-MIST`, le test vit dans
  `veaf.getUnitsInTriggerZone` et appelle les fonctions VEAF `veaf.getUnitsInCircularZone` /
  `veaf.getUnitsInPolygon` ; il n'accepte toujours que 0 et 2, mais un type inattendu journalise
  désormais une erreur et renvoie `nil` au lieu d'une liste vide : le silence a disparu. La règle de
  l'action est inchangée.

**Décision de David sur le nombre de sommets (2026-08-12)** : accepter trois ou plus, puisque « suivre
la ligne de crête » est le cas d'usage réel et que mist gère un polygone quelconque — mais **avertir**
dès que le compte n'est pas quatre, l'éditeur DCS n'ayant aucun outil pour dessiner ou remodeler une
zone non quadrilatère. La question ouverte de savoir s'il **préserve** une telle zone a été tranchée en
jeu le 2026-08-15 (`FIX-MCP-EDITOR-ROUNDTRIP`) : une zone à 6 sommets est revenue identique après
sauvegarde. L'action **ne refuse donc pas** au-delà de quatre ; l'avertissement énonce une limite
connue (on ne peut pas éditer la forme à la main dans l'éditeur), plus un risque inconnu.

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

**Six formes sont livrées parce que six formes ont été mesurées** : `Line` (avec `lineMode`
`segment` ou `segments`, et `closed` pour une forme qui se referme), `Polygon` en mode `rect`
(`width`/`height`/`angle`, **aucun** point), `TextBox` (`text`/`font`/`fontSize` ; la police est reprise
d'un vrai dessin, une police absente de DCS ne s'affichant pas du tout), et — ajoutés le 2026-08-15
depuis `bridge-Syria-editeur.miz` (ticket 10) — `Polygon` en mode `circle` (`radius`, aucun point ni
angle), `oval` (`r1`/`r2`/`angle`) et `free` (des `points` relatifs à l'ancre comme une `Line`, une
zone libre remplie, au moins trois points).

`arrow` et `icon` ont été mesurés mais restent **refusés, avec une raison** plutôt qu'une supposition :
un `arrow` stocke un contour calculé de 8 points **en plus** de ses `length`/`angle`, donc écrire les
seuls paramètres demande un aller-retour en jeu pour savoir si DCS recalcule le contour (son propre
ticket) ; un `icon` réclame un `file` du jeu d'icônes de l'éditeur (p. ex. `P91000007.png`), qu'aucune
donnée du dépôt n'énumère, et un nom non validé ne s'affiche pas. `chevron` a été retiré : il n'existe
pas dans l'éditeur DCS.

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
  `#spawnradius`, `#spawncount`, `#spawnchance`, `#spawndelay`, `#alarm`. L'idiome classique = un groupe
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

**Terrain dégagé (lot FEAT-CLEAR-GROUND-AT-AUTHORING).** Quand c'est l'outil qui choisit la position,
un groupe de véhicules **immobile** (sans `route`) est posé sur un terrain mesuré dégagé des arbres et
des bâtiments, à 1 km au plus de la position demandée, en translatant le groupe d'un bloc. La mesure
vient du **catalogue de terrain dégagé** du théâtre, balayé une fois dans DCS avec
`veaf-tools dcs clear-ground-sweep` (le Caucase est livré ; sinon, celui balayé sur le poste). La place
nécessaire est l'étendue des unités écrites ; pour un **marqueur** `#command`, c'est le pire cas du
groupe que le runtime dessinera (calculé depuis `veaf-units.yaml`, rayon d'apparition compris : environ
214 m pour `-sa10`). Un `warnings` dit toujours ce qui s'est passé : déplacé de N m, rien d'assez grand
dans le rayon cherché, zone non couverte par le catalogue (avec la commande pour la balayer), ou groupe
dont la taille n'est connue qu'à l'apparition (`-armor`, `-infantry`…), laissé au runtime. Le groupe
n'est **jamais refusé** : faute de mieux, il reste où il était demandé.

- `keep_position: true` — la position est celle que **l'utilisateur** a donnée : le groupe n'est
  jamais déplacé. Même paramètre sur les groupes de `create_combat_zone`.

### `add_player_slot` (lot FIX-SCRATCH-MISSION-PLAYABLE)

Écriture. Crée une **place joueur** — un groupe avion jouable — que `add_group` (terrestre) ne sait
pas produire et sans laquelle une mission bâtie de zéro n'est pas jouable. Sauvegarde horodatée avant
écriture. Cible un **dossier** (durable) ou un `.miz` (transitoire).

```json
{
  "target": "chemin/vers/dossier-mission",
  "coalition": "blue",
  "country_id": 2,
  "country_name": "USA",
  "name": "Player Viper",
  "unit_type": "F-16C_50",
  "position": {"x": 1000.0, "y": 2000.0},
  "start": "ground-cold",
  "parking": "43",
  "parking_id": "16",
  "airdrome_id": 24
}
```

- **`skill: Client`** — la compétence de slot multijoueur, jouable aussi en solo. Cette action ne
  modifie **pas** la compétence d'une unité existante : `set_unit_properties` refuse `Client`/`Player`
  et ceci n'en est pas une porte dérobée.
- **`dynSpawnTemplate` est mis à `false`.** Ce drapeau marque un template de spawn dynamique, qui
  exige une base configurée pour ça ; laissé actif (comme sur une copie d'un template) le slot existe
  dans le fichier mais n'apparaît **pas** dans la liste des places — le défaut trouvé en jeu le
  2026-08-14.
- `start` — `"air"` (position + `altitude_ft` + `speed_kt` + `heading_deg`, aucune donnée runtime),
  `"ground-cold"` ou `"ground-hot"`. Un départ au sol **exige** `parking`, `parking_id` et
  `airdrome_id` ; sans eux il est **refusé** (message nommant la donnée capturée par
  `FEAT-MCP-MUTATION-ACTIONS` ticket 09), jamais deviné. La paire `type`/`action` du premier waypoint
  est écrite selon le mode.
- **`frequency_mhz`** est écrite (radio de groupe active) plutôt qu'héritée d'un `communication: false`.
- **Le plein interne par défaut.** `fuel` (kg) et `fuel_fraction` (]0, 1]) laissent choisir la
  charge ; sans eux, l'appareil reçoit la capacité interne de son type, lue dans la base d'unités
  livrée (`dcsUnits.yaml`, champ `fuel_capacity` issu du `M_fuel_max` du datamine). Ces deux actions
  écrivaient `fuel = 0` jusqu'à la 6.15.1, ce qui veut dire **aucun carburant** : mesuré en jeu le
  2026-08-18, un KC-135 et ses deux F-15C d'escorte créés à 20 000 ft piquaient au sol dès leur
  apparition, réacteurs éteints. Un départ au parking masquait le défaut, DCS remplissant les
  réservoirs d'un appareil garé depuis le stock de la base. Un type inconnu de la base — un mod tiers
  — est créé **sans clé `fuel`** (DCS applique alors son propre défaut) et l'appelant est **averti**,
  plutôt que de se voir inventer un chiffre.
- Assigne le pays à son camp dans `coalitions` (voir `add_group`), donc la mission reste chargeable.

### `add_air_group` (lot FEAT-MCP-MUTATION-ACTIONS, ticket 09)

Écriture. Pose un **vol** (un ou plusieurs appareils) au parking en **résolvant lui-même les places**
depuis un **nom** d'aérodrome — le cas *« un deux-ship de F-16 à Incirlik »* que `add_player_slot` (un
appareil, place fournie) ne couvre pas. Sauvegarde horodatée avant écriture. Cible un dossier (durable)
ou un `.miz` (transitoire).

```json
{
  "target": "chemin/vers/dossier-mission",
  "coalition": "blue", "country_id": 2, "country_name": "USA",
  "name": "Viper", "unit_type": "F-16C_50", "count": 2,
  "start": "parking-cold", "airfield": "Kobuleti"
}
```

- **Résolution des places.** Le nom d'aérodrome est résolu en id (`veaf_libs.dcs_airdromes`), puis en
  places libres via la capture allégée bundlée (`veaf_libs.dcs_parking`, générée par
  `veaf-build update-dcs-data --parking`). L'action prend `count` places libres, **les plus proches de
  la piste d'abord**, et pose chaque appareil à la **position exacte** du stand.
- **`parking_id` = `parking`.** Établi en jeu le 2026-08-15 : `parking` est le `Term_Index` de la
  capture, l'appareil se cale sur la position exacte, et le `parking_id` propre à l'éditeur — absent de
  la capture — n'est **pas** porteur. Il est donc écrit égal à `parking`.
- **Seuls les types de terminal 68, 72 et 104** sont proposés comme parking — le masque
  `FighterAircraft` (244) de DCS lui-même. Le `100` (SmallSizeFighter) est exclu volontairement : DCS
  le documente comme une place étroite réservée aux petits appareils, et il ne débloque aucun
  aérodrome que les trois autres ne couvrent pas déjà. Un aérodrome sans place d'aucun de ces trois
  types est **refusé** plutôt que de poser un appareil sur un seuil de piste ou une hélisurface. La
  mesure qui fonde cet ensemble, et les sept aérodromes qu'elle a débloqués, sont consignées à côté de
  `AIRCRAFT_STAND_TYPES` dans `veaf_libs/dcs_parking.py`.
- **Collision refusée.** Une place déjà occupée dans la mission (un groupe avion dont le premier
  waypoint vise cet aérodrome et dont une unité déclare cette place) est refusée **en nommant** le
  groupe qui la tient ; la sélection automatique **saute** les places occupées.
- **Départs.** `parking-cold` / `parking-hot` (exigent `airfield`), `runway` (exige `airfield`, ancré
  sur le terrain, pas de place consommée), `air` (exige `position`). La paire `type`/`action` et le
  verrou `ETA_locked` du premier waypoint sont écrits pour l'appelant.
- **`skill`** vaut un niveau d'IA par défaut (`High`) — un vol au parking est IA sauf demande de
  `Client`/`Player`. `parking` accepte une liste explicite de places qui court-circuite la sélection.
- **Le plein interne par défaut.** `fuel` (kg) et `fuel_fraction` (]0, 1]) laissent choisir la
  charge ; sans eux, l'appareil reçoit la capacité interne de son type, lue dans la base d'unités
  livrée (`dcsUnits.yaml`, champ `fuel_capacity` issu du `M_fuel_max` du datamine). Ces deux actions
  écrivaient `fuel = 0` jusqu'à la 6.15.1, ce qui veut dire **aucun carburant** : mesuré en jeu le
  2026-08-18, un KC-135 et ses deux F-15C d'escorte créés à 20 000 ft piquaient au sol dès leur
  apparition, réacteurs éteints. Un départ au parking masquait le défaut, DCS remplissant les
  réservoirs d'un appareil garé depuis le stock de la base. Un type inconnu de la base — un mod tiers
  — est créé **sans clé `fuel`** (DCS applique alors son propre défaut) et l'appelant est **averti**,
  plutôt que de se voir inventer un chiffre.
- Un théâtre sans capture, un aérodrome inconnu, ou trop peu de places libres sont refusés en nommant
  la cause. Assigne le pays à son camp dans `coalitions`.

### `remove_group` (lot FIX-MCP-AUTHORING-GAPS, ticket 02)

Écriture. **Retire un groupe** de la mission — la seule édition au niveau groupe qui manquait au
catalogue, alors qu'`edit_zone` et `edit_map_drawing` ont tous deux un `remove: true`. Cible un
dossier (durable) ou un `.miz` (transitoire), sauvegarde horodatée avant écriture.

```json
{"target": "chemin/vers/dossier-mission", "group_name": "Texaco"}
```

- **Renumérote ce qu'il laisse derrière.** C'est la raison d'être de l'action : supprimer un bloc Lua
  à la main laisse la liste englobante numérotée `1,3,4`, ce que Lua charge sans broncher et sur quoi
  le **build** meurt (`AttributeError: 'int' object has no attribute 'get'`), à une ligne qui ne
  désigne pas l'édition. Trois builds corrompus le 2026-08-18 venaient de là — et la rustine de
  l'époque, une regex de renumérotation calée sur la seule indentation, a aussi renuméroté `units` et
  `route.points`. Les survivants gardent leur ordre et sont ré-indexés à partir de 1.
- **Le dernier groupe d'une catégorie fait disparaître la clé `group`**, au lieu de laisser un
  conteneur vide — la forme exacte qu'un lecteur en aval prend pour une liste
  (`FIX-GROUP-CONTAINER-SHAPE`).
- **Nom exact exigé.** Un fragment est refusé, comme pour `set_group_properties` : une suppression
  qui atterrit sur le premier groupe correspondant n'est pas rattrapable. Un nom introuvable liste ce
  qui existe, et **rien n'est écrit**.
- **Nomme ce qu'il casse, sans refuser** — le créateur de mission veut peut-être précisément ça :
  une combat zone qui capture le groupe par préfixe de nom, une tâche `Escort` qui pointe son
  `groupId` (y compris imbriquée dans un `ComboTask`, la forme réelle de DCS), et une entrée
  `modules.ASSETS.assets` de `mission.yaml` qui le nomme. Cette dernière n'est vérifiable que sur une
  cible **dossier** : un `.miz` ne porte pas de `mission.yaml`.

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

- `set_airbase_coalition(folder_path, name, coalition, dynamic_spawn=True)` — assigne durablement un
  aérodrome DCS à une coalition, dans un **dossier de mission** ; `dynamic_spawn=False` laisse ses
  slots dynamiques fermés (une base ennemie).

> ⚠️ La coalition d'un aérodrome vit dans `warehouses.airports[<id>].coalition`, **pas** dans
> `mission.coalition`. Poser une unité à côté d'une base ne la fait donc jamais changer de camp :
> c'est cette action qu'il faut. Elle résout le nom de l'aérodrome en identifiant via le théâtre de
> la mission, pose la coalition, et **active les slots Dynamic Spawn** de la base (le build les
> approvisionne ensuite), sauf si `dynamic_spawn` est faux. Sauvegarde préalable, comme les autres
> actions d'édition.
>
> `dynamic_spawn: false` inscrit aussi la base sous `<camp>.exclude_airports` dans
> `src/warehouses.yaml`, et `true` l'en retire : le build ouvrait toute base d'un camp déclaré sans
> liste `airports:`, `dynamicSpawn = false` ou pas (`FIX-SCRATCH-MISSION-FINDINGS` ticket 15). Rien
> n'est écrit si le fichier manque (l'étape ne tourne pas) ou si le camp n'y est pas déclaré (le
> déclarer ouvrirait toutes ses bases).

### Campagne multi-missions

- `campaign_status(campaign_folder)` — où en est la campagne : missions appliquées, propriétaire, force de garnison, type et voisins de chaque zone, réserves, objectifs atteints ou non, changements de la dernière mission. Lecture seule.
- `campaign_apply(campaign_folder, state_file)` — fusionne le fichier d'état d'une mission jouée, joue le tour entre les missions, juge les objectifs ; refuse un fichier déjà appliqué, d'une autre campagne ou qui saute une mission, sans rien écrire.
- `campaign_next(campaign_folder)` — crée (copie de `template/`) ou rafraîchit `missions/mission-NN/mission` : aérodromes à leur propriétaire par `set_airbase_coalition`, `src/campaign-data.yaml`, module `CAMPAIGN` dans `mission.yaml` ; rend le dossier et la partie factuelle du briefing stratégique en FR et EN.

Chacune est la commande `veaf-tools campaign` correspondante (`campaign_manager.CampaignWorker`), qui rend des données au lieu de les afficher. Voir [Campagne multi-missions](../mission-maker/CAMPAIGN.md).

### FARP

- `add_farp(target, name, position, coalition, country_id, country_name, farp_type="FARP",
  frequency_mhz=127.5, modulation="AM", callsign_id=1, ammo_dump=True)` — un FARP **complet** : le statique
  d'héliport (`category = "Heliports"`, `shape_name` du type), sa radio et son indicatif, et l'entrée
  d'entrepôt `warehouses.warehouses[<unitId>]` qui permet de s'y ravitailler. `add_group` en `static`
  ne posait que l'objet (ticket 19). Forme mesurée sur les 372 héliports des missions de
  `D:\dev\_VEAF`. Le `farps:` de `warehouses.yaml` l'approvisionne ensuite au build, comme une base.
  Par défaut, son **dépôt de munitions** (`FARP Ammo Dump Coating`, `<nom> - Ammo`, 120 m à l'est,
  `Fortifications` / `SetkaKP` comme les 68 des missions OT) que CTLD prend comme point de chargement ;
  `ammo_dump=False` s'en passe (`FIX-OPEN-TRAINING-SYRIA-FINDINGS` ticket 05). Un héliport en mer
  (sol à 0 m sur la grille d'altitude) est signalé (ticket 04).

### Groupe aéronaval, slots sur le pont, sons (FIX-OPEN-TRAINING-PROMPT-FINDINGS)

- `add_carrier_group(mission_path, coalition, country_id, country_name, name, position, heading_deg,
  speed_kt, carrier_type="Stennis", carrier_name, escorts, tower_mhz, tacan_channel, tacan_callsign,
  icls_channel, link4_mhz, recovery_tanker, tanker_*, rescue_helicopter)` — le porte-avions (et ses
  escorteurs) en route, sa radio sur l'unité (hertz), `ActivateBeacon` (TACAN, `system` 3),
  `ActivateICLS`, et sur un pont à brins d'arrêt `ActivateLink4` + `ActivateACLS` ; les groupes
  `<unité> S3B-Tanker` (tâche `Tanker` + TACAN Y) et `<unité> Pedro` que `veafCarrierOperations`
  cherche par leur nom ; l'entrée `warehouses.warehouses[<unitId>]`. Les tâches ATC sont écrites **au
  premier point de route et dans le `tasks` du groupe** : sur 218 groupes mesurés, 120 les rangent au
  groupe, 55 sur la route, 43 aux deux, et `veafCarrierOperations` ne lit que le groupe ; lequel des
  deux DCS exécute n'a pas été mesuré.
- `add_air_group(..., start="deck-cold"|"deck-hot", carrier=<unité navire>)` — premier point lié au
  navire (`linkUnit` = `helipadId` = son `unitId`), places de pont numérotées à la suite ; refusé si
  l'appareil ne peut pas à la fois décoller de ce pont et y apponter (`TakeOffRWCategories` /
  `LandRWCategories`, capturés dans `dcsUnits.yaml`).
- `add_sound(mission_path, sound_path, resource_name)` — copie un `.ogg`/`.wav` dans `l10n/DEFAULT` et
  le déclare dans `mapResource` sous `MCP_Sound_<nom>` ; `edit_route` `transmit_message` le diffuse
  (`TransmitMessage` enveloppé, `file` = la clé, `loop`, `duration`, `subtitle` écrit au dictionnaire).
- `set_briefing_picture(mission_path, source_path, side, resource_name)` — copie un `.png`/`.jpg` dans `l10n/DEFAULT`, le déclare dans `mapResource` sous `MCP_Picture_<nom>` et ajoute la clé au `pictureFileNameB` / `R` / `N` du camp, en gardant les images qu'il avait (FIX-DEMO-MISSION-FINDINGS 07).

### Open Training Syrie (FIX-OPEN-TRAINING-SYRIA-FINDINGS)

- **Indicatif tiré du nom** : un vol occidental nommé comme son indicatif (`Texaco 2`, `Magic 1`) reçoit
  cet indicatif (`Texaco21`) si la famille convient à la tâche et que le vol est libre ; sinon la règle
  d'avant (première famille libre) et un avertissement qui dit pourquoi. Un vol d'IA à tâche de combat
  (`Escort`, `CAP`, `CAS`, `SEAD`…) sans `pylons` est signalé (ticket 01).
- `set_unit_properties` : `callsign.name` sans chiffres est complété (`Texaco` → `Texaco21`) ; `pylons`
  prend `{station: CLSID}` comme `{station: {CLSID: …}}` et refuse tout autre valeur en nommant la
  station (ticket 02).
- `create_qra` n'écrit plus `simple_groups` quand `groups_by_enemy_count` est donné : à côté de paliers,
  ils ne décollent jamais (ticket 03, mesuré dans `test_veafQraManager.lua`).
- **Contrôle de surface** : `add_group`, `create_combat_zone`, `add_farp` et le déplacement de
  `set_group_properties` signalent un véhicule, un statique ou un FARP à 0 m (en mer) et un navire au-dessus
  de 0 m (à terre), là où le théâtre a une grille d'altitude ; sinon « surface not checked ». 3 m est de la
  terre : DCS ne descend jamais sous 0 (ticket 04).
- `add_air_group(task="AFAC")` — un **drone laser** comme ceux de GermanyCW-v6 : premier point avec
  `SetUnlimitedFuel` puis une orbite `Circle` à l'altitude et la vitesse du groupe. Le marquage est celui de
  CTLD, par l'entrée `modules.ASSETS` (`jtac`, `freq`, `mod`) ; CTLD le remonte à `JTAC_droneAltitude`, il ne
  désigne que des véhicules, à 10 km (ticket 06).
- `geocode` : une requête par seconde au plus (Nominatim) ; un 429 attend ce que demande `Retry-After`
  (30 s au plus) une fois, puis le refus revient en `found: false` dit en clair. Cinq candidats demandés, un
  lieu nommé préféré à une route ou une région ; `osm_class` / `osm_type` dans la réponse, et un
  avertissement quand c'est une route ou une région (« Al-Kiswah » → une rue d'Amman) (ticket 07).
- `list_unit_types` donne `threat_range_m` / `detection_range_m` (mètres, `ThreatRange` / `DetectionRange`
  du datamine, les cercles de l'éditeur) pour chaque unité qui en a ; `dcsUnits.yaml` les porte, régénéré
  par `veaf-build update-dcs-data --units` (ticket 08).
- **Emports DCS par nom** : `add_air_group`, `create_qra` (par groupe) et `create_cap_mission` prennent
  `payload`, le nom d'un emport que l'éditeur propose (`list_payloads`), à côté de `pylons` et
  `loadout_from` — un seul des trois. Source : `MissionEditor/data/scripts/UnitPayloads` d'une
  installation (613 emports, 45 types), le datamine n'ayant pas ces fichiers (ticket 09).
- `repair_static_shapes(target)` — complète le `shape_name` de chaque statique posé sans (avant 6.26)
  depuis la base d'unités, dit ce qu'il a complété et les statiques dont le type n'a pas de forme connue ;
  n'écrit rien s'il n'y a rien à compléter. Le message de `validate` le nomme (ticket 17).
- Les sauvegardes d'un fichier de `src/mission/l10n/DEFAULT/` vont dans `.veaf-backups/` (elles restaient
  à côté et partaient dans le `.miz`), et une sauvegarde de dossier réécrit `mapResource` (tickets 15, 16).

### Réglages de la mission (FIX-SCRATCH-MISSION-FINDINGS ticket 07)

Ce que l'éditeur règle hors de tout groupe, et que GermanyCW-v6 a dû patcher par un sérialiseur Lua.
Chaque action vise un dossier de mission (durable) ou un `.miz`, sauvegardé avant écriture.

- `set_mission_date(target, date?, start_time?)` — `mission.date` (`AAAA-MM-JJ`) et
  `mission.start_time` (`HH:MM[:SS]`, l'horloge du théâtre). Les variantes météo gardent la main sur
  les deux.
- `set_bullseye(target, coalition, position)` — `mission.coalition.<camp>.bullseye`, d'où vient le
  waypoint BULLSEYE de chaque plan de vol.
- `set_briefing(target, sortie?, situation?, blue_task?, red_task?, neutrals_task?)` — les textes du
  briefing. Quand la table de mission porte une référence `DictKey_…`, le texte va dans
  `l10n/DEFAULT/dictionary` derrière elle, et la référence reste valide ; `write_mission_folder`
  réécrit désormais ce dictionnaire, seulement s'il change.
- `set_weather(target, metar?, temperature?, wind_speed?, wind_direction?, visibility?, cloud_type?,
  cloud_height?, precipitation?, fog_enabled?, clearsky?)` — la météo de la mission **de base**, dans
  les champs que DCS lit (ticket 19 : la mission vierge a ses nuages au sol, `Preset1` à 0 m). Même
  vocabulaire et même convertisseur que `versions[].weather`, donc un METAR marche aussi ; les
  variantes gardent la main au build.

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

### `list_payloads`

Lecture seule. Les emports par défaut que l'éditeur de mission propose pour un type d'avion d'IA, par
nom (« R-40T*2,R-33*4 » pour un MiG-31), avec leurs pylônes — ce que prend `payload` dans
`add_air_group`, `create_qra` et `create_cap_mission`. Sans `unit_type`, la liste des types qui en ont.
Lus dans `veaf_libs/data/payloads.yaml`, généré depuis une installation DCS
(`veaf-build update-dcs-data --payloads --dcs-path <DCS>`) : le datamine n'a pas ces fichiers.

```json
{"unit_type": "MiG-31"}
```

### `list_shortcuts`

Lecture seule. Le vocabulaire d'alias VEAF (`shilka`, `sa8`…) — alias d'unités
(`_spawn unit <alias>`) et de groupes composites (`_spawn group <alias>` : sites SAM, convois),
plus les raccourcis `#command` (`-samLR`, `-armor`…) avec `randomParameters` : la plage
`{min, max}` de chaque paramètre tiré à chaque usage — `-samLR` et `-samSR` lancent la même
commande et ne diffèrent que par leur plage `defense`. Filtrable par `name_contains`.

### `describe_known_limitations`

Lecture seule. Pour la version de veaf-tools en cours, les entrées de
`veaf_libs/data/known-limitations.yaml` : les limites des outils pas encore corrigées
(`kind: tool`, retirées à partir de la version de leur `fixed_in`) et les comportements de DCS qui
ne lèvent aucune erreur (`kind: dcs`, toujours renvoyés, avec la date de leur mesure). Chaque
entrée : `id`, `kind`, `area`, `title`, `symptom`, `workaround`, éventuellement `cost`. Filtre
`kind` optionnel. Le fichier est la seule source : `docs/agents/dcs-runtime-traps.md` en est
généré.

```json
{"kind": "dcs"}
```

### `offer_clear_ground_check` (lot FEAT-CLEAR-GROUND-AT-AUTHORING)

Lecture seule, et **ne lance rien**. Sur un `.miz` construit, renvoie de quoi **proposer** à
l'utilisateur une vérification en jeu : la commande `veaf-tools dcs clear-ground-check` à lancer (elle
demande DCS), ce qu'elle fera, le nombre de véhicules et de marqueurs, et le critère de comptage. La
vérification sonde la position de chaque véhicule sur la mission d'arpentage **vide** : aucun véhicule
n'y existe, donc aucun n'est compté comme bloqué par ses voisins — le piège qui a faussé trois chiffres
publiés. Elle compare ensuite chaque réponse à ce que le catalogue avait prédit.

```json
{"miz_path": "chemin/vers/mission.miz"}
```

### `offer_scenery_lookup` (lot FEAT-OBJECTIVE-MISSION-PROMPT)

Lecture seule, et **ne lance rien**. Pour prendre un objet de la carte (un pont, un bâtiment de la
carte elle-même) comme objectif d'une zone de combat, il faut son identifiant DCS — le
`scenery_targets` de la zone n'accepte que ça, et ces identifiants n'existent que dans DCS. L'action
renvoie de quoi **proposer** à l'utilisateur la commande `veaf-tools dcs scenery-objects` (elle demande
DCS), qui liste les objets autour de chaque point avec leur identifiant, leur type et leur distance.
Rayon par défaut : 150 m.

```json
{"theatre": "Syria", "points": [{"x": -64230.0, "y": 352140.0, "radius": 100}]}
```

### `terrain_elevation` (lot FEAT-TERRAIN-ELEVATION)

Lecture seule, **sans DCS** : répond depuis la grille d'altitudes du théâtre, relevée une fois par
[`veaf-tools dcs terrain-sweep`](../CLI_REFERENCE.md#terrain-sweep). Quatre questions, combinables
dans un même appel :

- `points` — l'altitude du sol en chaque point, en mètres et en pieds (l'altitude d'une cible) ;
- `route` — le sol le plus haut de chaque branche (le plancher d'une route basse altitude) ;
- `route` + `observers` — combien de mètres de chaque branche chaque radar ou SAM voit au-dessus du
  relief, dans sa portée, horizon radar de la Terre aux 4/3. Chaque point de la route doit alors
  porter son `alt` : une branche entre deux points `RADIO` (au-dessus du sol) suit le relief, toute
  autre va en ligne droite entre les deux altitudes ;
- `area` — le sol le plus haut par carré MGRS de 10 km (la grille F10) ou par quadrilatère de 30′.

**Relief seul** — ni bâtiments, ni pylônes, ni arbres — et interpolé entre deux échantillons : chaque
réponse porte le pas de la grille et cette mise en garde. Un point hors de la grille vaut `null`,
jamais 0. Sans grille pour le théâtre, la réponse est `available: false` avec la commande qui la
relève.

```json
{"theatre": "Caucasus",
 "route": [{"x": -281000, "y": 647000, "alt": 60, "alt_type": "RADIO"},
           {"x": -262000, "y": 690000, "alt": 60, "alt_type": "RADIO"}],
 "observers": [{"name": "SA-6 Kutaisi", "x": -284500, "y": 683500, "range": 25000}]}
```

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
Chaque groupe accepte `route` et `patrol`, de la même forme qu'`add_group` : un convoi qui traverse la
zone est un groupe de la zone, pas un appel séparé. En catégorie `ship`, les navires sont espacés de
600 m (ceux d'un véhicule, 20 m, les faisaient se percuter à l'apparition).

### `add_combat_operation`

Écrit dans `mission.yaml` seulement une entrée `combat_zones[]` de type `operation` : `tasking_orders` (chaque tâche, ses `dependencies`), `friendly_name`, `briefing`, `active_at_start`.
Le nom d'une opération est une étiquette, pas une zone de déclenchement : rien n'est écrit dans `src/mission/`.
Refuse une tâche ou une dépendance qui ne nomme pas une zone de combat déclarée (ou qui nomme une autre opération) : le `GetZone()` généré vaudrait `nil` au runtime (FIX-DEMO-MISSION-FINDINGS 07).
Activer l'opération fait apparaître toutes ses zones d'un coup ; les `dependencies` ne décident que du moment où une tâche devient l'objectif en cours.

### `create_qra`

Zone + intercepteurs **Late Activation** (coalition significative) + entrée
`modules.QRA.definitions[]` référençant les groupes **par nom exact** (`simple_groups`). La
coalition est passée en minuscule pour le placement, majuscule dans la définition YAML. Chaque intercepteur a **un seul point, sans tâche**, à dessein : au décollage, le module QRA donne à un groupe
`CAP`/`Intercept` dont la route n'engage aucun aéronef une patrouille sur la zone
([ce que fait un groupe décollé](../mission-maker/scripts/veafQraManager.md#scrambled-group-task)).

### `create_cap_mission`

Groupe template **Late Activation** nommé `OnDemand-<nom>` + entrée `cap_missions[]`
(`group_name: <nom>`, sans préfixe — le build résout vers le groupe `OnDemand-`). Le premier point
porte la tâche `EngageTargets` (cibles `Air`) que l'éditeur ajoute de lui-même à une tâche CAP, numérotée
**avant** l'orbite : sans elle, le vol patrouille et n'engage jamais.

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
Chaque zone porte son `x`/`y`/`radius`, chaque groupe son `x`/`y` et son nombre d'unités (`units`).

```json
{"mission_path": "chemin/vers/mission.miz-ou-dossier"}
```

### `list_airfields`

Lecture seule. Liste les bases d'un théâtre — nom, id d'aérodrome DCS, lat/lon, et `x`/`y` DCS quand
la projection du théâtre est connue — depuis la donnée livrée avec les outils
(`veaf_libs/data/airdrome-positions.yaml`, générée avec `airdromes.yaml` depuis les dumps runtime par
`veaf-build update-dcs-data --airdromes`). Avec `mission_path`, le théâtre de la mission ; sans
mission, `theatre`.

```json
{"theatre": "GermanyCW"}
```

### `describe_airfield_channels`

Lecture seule. Liste, pour un **dossier** de mission, les aérodromes qu'elle utilise — camp (depuis
`warehouses`), slots dynamiques une fois `src/warehouses.yaml` appliqué, slots posés au parking — avec
les fréquences ATC et le TACAN que DCS leur donne (`veaf_libs/data/airfield-frequencies.yaml`), et
l'alias que chacun a déjà dans la collection `bases`. Classés : tenus avec slots, tenus sans, puis
(`include_neutral`) neutres. C'est la proposition à soumettre à l'auteur de la mission avant
`set_airfield_channels` : une radio DCS tient une vingtaine de canaux. Même code que
`veaf-tools content airfield-channels`.

```json
{"folder_path": "…", "include_neutral": false}
```

### `set_airfield_channels`

Écrit les aérodromes choisis dans la collection de canaux `bases` du `src/presets.yaml` du dossier,
avec les fréquences de DCS ; refuse un aérodrome que DCS ne déclare pas. Un aérodrome déjà dans
`bases` garde son alias et l'orthographe de son titre (`Büchel` pour le `Buchel` de DCS), un nouveau prend l'alias `Base-<nom DCS>`, et une entrée qui ne correspond à aucun
aérodrome choisi (un FARP, un navire) est laissée telle quelle et signalée dans `untouched`. Seule
`bases` change ; `not_on_a_radio` liste les canaux écrits qu'aucune entrée de `channel_lists`
n'utilise encore. Idempotent.

```json
{"folder_path": "…", "airfields": ["Batumi", "Kutaisi", 31]}
```

### `resolve_coordinates`

Utilitaire. Convertit une position entre `{x, y}` (local DCS) et `{lat, lon}` (degrés décimaux) pour
le théâtre de la mission (lu depuis la mission — l'appelant ne fournit jamais de paramètres de
projection).

```json
{"mission_path": "…", "position": {"lat": 42.18, "lon": 41.68}}
```

Pour convertir plusieurs points en un appel, `positions` (une liste) à la place de `position` : la
réponse est `{theatre, points}`, dans l'ordre donné, et une position incomplète est nommée par son
index.

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
`profile` (optionnel) est passé en `--profile` — `LOCAL_TEST` pour un build de test local.

```json
{"folder_path": "chemin/vers/dossier-mission", "profile": "LOCAL_TEST"}
```

## Prochaines vagues (hors périmètre)

- Un éditeur de triggers SI/ALORS générique (conditions/actions DCS arbitraires) — la vague 2
  se limite aux triggers de démarrage chargement-de-script / exécution-Lua.
- Un validateur de schéma par module pour `set_mission_module` (la vague 4 reste générique).
- Composites CAS (pur runtime, pas d'écriture) et génération end-to-end
  depuis un prompt (l'objectif NL-MISSION-GEN au-delà de ce lot).

Voir `.backlog/archive/FEAT-MCP-MISSION-EDITOR.md` pour le détail.
