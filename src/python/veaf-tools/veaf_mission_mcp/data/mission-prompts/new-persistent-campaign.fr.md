# Prompt — construire une campagne persistante VEAF

> Servi par l'action `describe_mission_prompt` (`kind: persistent-campaign`) quand un utilisateur demande une campagne persistante.
> La campagne se construit dans un **dossier à elle** : demander à l'utilisateur où la créer (par exemple `Documents\VEAF\Campagnes\<nom>`).

---

Tu vas construire **de zéro** une **campagne persistante** VEAF pour DCS World, avec les outils VEAF Mission Creation Tools v6 et le serveur MCP `veaf-mission-mcp`.

Une campagne persistante est **une seule mission** qui tourne sur un serveur des semaines durant, dans l'esprit de Foothold : des zones qui changent de camp, un front qui bouge tout seul, l'aviation ennemie, des crédits à dépenser, et une sauvegarde qui reprend là où le serveur s'est arrêté.
Tout part d'un fichier `campaign.yaml` (`mode: persistent`) et d'une mission modèle, `template/`.
L'utilisateur n'a peut-être ni terminal ni dépôt : tout se fait par les actions MCP.

## 0. Avant tout

1. **Lis le guide de création VEAF** (`describe_authoring_guide`) et suis-le, en particulier ses paragraphes **« A campaign mission »** et **« A persistent campaign »** : ce sont les règles apprises sur la première campagne persistante (*Bouclier de l'Oronte*, Syrie). Ce prompt ne les recopie pas : il dit **quand** les appliquer.
2. Appelle `capabilities` et lis les **limitations connues** (`describe_known_limitations`, liste courte, puis en entier les seules entrées que la campagne rencontre).
3. **Ce qui manque ou ne marche pas dans les outils, tu le signales** dans un bloc **« Retours pour VMCT »** de ton rapport final (quoi, où, comment tu l'as vu, ce que tu as fait à la place).
4. Réponds en français, concis. Pose tes questions **une par une**, avec des choix et ta reco.
   La mission prend la langue de l'utilisateur (`mission.language: fr` dans le `mission.yaml` du template).

## 1. Les questions à poser (et seulement celles-là)

Une par une :

1. **Le théâtre et l'époque** (moderne, Guerre froide avec une année, WW2). L'époque décide des matériels des garnisons.
2. **Le camp des joueurs** (`player_side`, bleu par défaut) et **le nom de la campagne**.
   Propose aussi un **nom de fichier fixe** pour la mission (`mission_file`, par exemple `Campagne_Oronte`) : le navigateur de serveurs l'affiche, et un redéploiement remplace simplement le fichier.
3. **Le front** : où il passe, et combien de zones (reco : 8 à 14 pour une première campagne).
   Propose une carte des zones : aérodromes de chaque camp (`list_airfields`), avant-postes entre eux (villes, carrefours, cols : `geocode`), une ou deux zones neutres au milieu, et les liaisons qui forment le front.
   Montre-la en tableau (nom, emplacement, camp de départ, classe `airfield` ou `outpost`), et fais-la valider avant d'écrire.
4. **Usines et dépôts** (`kind: factory` / `kind: depot`) : reco, une usine loin derrière les lignes et un dépôt sur la route du front, pour chaque camp. Ils font et acheminent les ressources que l'IA dépense.
5. **Les SAM longue et moyenne portée** : sur quelles zones-clés (une grande base arrière, une usine, un dépôt), deux longue portée par camp au plus, à 120 km l'un de l'autre au moins.
6. **Ce que fait l'IA ennemie** : par défaut elle contre-attaque et ravitaille (`dynamic.attacks: [red]`, `dynamic.supply: [red]`), avec les valeurs livrées. Ne propose de changer l'économie (`dynamic.economy`, `dynamic.resources`) que si l'utilisateur le demande : le guide dit pourquoi les valeurs livrées tiennent.

Tout le reste, tu le décides avec le guide et l'exemple livré, et tu l'annonces.

## 2. Méthode

- **Rien de mémoire.** Aérodromes → `list_airfields` ; lieux → `geocode` (affiche le point trouvé) ; coordonnées → `resolve_coordinates` ; types d'unités → `list_unit_types`.
- **Une zone sur un aérodrome se déclare sur l'aérodrome** (`at: { airfield: … }`), jamais à des coordonnées à côté.
- **Les fichiers de la campagne s'écrivent par `read_mission_file` et `edit_mission_file`**, avec le **dossier de campagne** comme `mission_path` : ils y atteignent `campaign.yaml` et `briefing.yaml`.
  `edit_mission_file` remplace un passage exact : lis d'abord, puis remplace bloc par bloc (le bloc `campaign:`, la liste `zones:`, la liste `connections:`). Un `search` **vide** crée un fichier qui n'existe pas encore (`briefing.yaml`).
- **`campaign_validate` après chaque changement** de `campaign.yaml` ou du template. Un avertissement est un défaut que le premier soir sur le serveur montrerait : corrige-le, ne te contente pas de le citer.

## 3. Ordre de travail

1. **L'exemple** : `campaign_init` avec `example: persistent` sur le dossier choisi. Il y copie l'exemple livré (le front de Géorgie, 11 zones) sans encore démarrer la campagne.
2. **`campaign.yaml`** : lis-le en entier (`read_mission_file`) ; ses commentaires expliquent chaque clé. Réécris-le pour la campagne validée en 1 :
   - le bloc `campaign:` (`name`, `theatre`, `era`, `mode: persistent`, `player_side`, `mission_file`) ;
   - `zones:` et `connections:` ;
   - dans `dynamic:`, garde les valeurs livrées ; adapte `support.assets` et `economy.tanker` aux noms des groupes que tu poseras dans le template (étape 3).
   Puis `campaign_validate`. À ce stade, il signale le template manquant ; le reste doit être propre.
3. **Le template** : `scaffold_mission` dans `<dossier de campagne>\template`, avec le `theatre` de la campagne (gabarit `standard`).
   Applique ensuite le guide, paragraphes « A campaign mission » et « A persistent campaign » : un AWACS et deux ravitailleurs (une perche, un panier) en orbite au-dessus de vos arrières, leurs canaux dans `src/presets.yaml`, `modules.ASSETS`, les noms exacts repris dans `dynamic.support.assets` et `dynamic.economy.tanker`.
   **Aucune unité `#veafInterpreter`** dans le template : ce que la campagne doit tenir se déclare en zone.
4. **`campaign_validate` jusqu'à zéro erreur et zéro avertissement.**
5. **`briefing.yaml`** : crée-le (`edit_mission_file`, `search` vide) avec `operation`, `subtitle`, `situation` et les **axes d'effort** sous `axes:` (un `title` et un `text` chacun), dans la langue des pilotes. Un texte qui contient « : » se met entre guillemets. Puis `campaign_validate`.
6. **Démarrer** : `campaign_init` **sans** `example`. Il écrit `campaign-state.yaml`.
   Change les zones **avant** cette étape : après, une zone ajoutée ou renommée est une erreur de `campaign_validate`. Pour une campagne persistante, la sortie est sans perte : l'utilisateur supprime `campaign-state.yaml` dans l'Explorateur, et tu relances `campaign_init`.
7. **La mission** : `campaign_next`. Il pose `missions\mission-01\mission`, les waypoints des joueurs, le plan radio, le briefing DCS, le dossier de théâtre et les pages de planchette. Lis chaque avertissement qu'il rend et corrige-le dans le template ou `campaign.yaml`, puis relance `campaign_next` : il met à jour sans écraser le travail fait.
8. **Construire** : `validate_mission` puis `build_mission` sur `missions\mission-01\mission`, puis `inspect_built_mission`. Le guide, section « Finish », dit quoi lire dans le résultat.

## 4. Ce que tu rends à l'utilisateur

- Le `.miz` construit (`<mission_file>.miz` dans `missions\mission-01\mission`) : c'est lui qui va sur le serveur, dans son dossier `Missions`.
- Le **dossier de théâtre** (PPTX et PDF) et les **pages de planchette**, à côté du dossier de mission : à partager avec les pilotes.
- Ce que le serveur doit avoir, en clair :
  - `io` et `lfs` ouverts dans son `MissionScripting.lua`, sinon la campagne tourne mais ne se sauvegarde pas (c'est le cas sur les serveurs VEAF) ;
  - la sauvegarde est écrite dans `Saved Games\DCS\Missions\Saves\<nom de la campagne>\persistent.state` ;
  - la météo et l'heure viennent du serveur (MizEdit, RealWeather) : la mission n'en fixe aucune ;
  - une remise à zéro se fait en jeu : F10 → Autres → VEAF → Campagne → Remettre la campagne à zéro (admin).
- Pour une **mise à jour** plus tard : modifier `campaign.yaml` ou le template, `campaign_validate`, `campaign_next`, reconstruire, redéployer le même fichier. Une campagne déjà en cours garde ce que sa sauvegarde a tiré (le guide dit quoi en dire).
- Le bloc **« Retours pour VMCT »**.

## 5. Vérification avant de dire « c'est prêt »

- `campaign_validate` : zéro erreur, zéro avertissement.
- La construction a réussi, et `inspect_built_mission` montre l'AWACS et les ravitailleurs avec leurs tâches et fréquences.
- Dis ce que tu as vérifié, et ce qui ne se vérifie qu'en jeu, sur le serveur.
