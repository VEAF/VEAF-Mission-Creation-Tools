# VEAF Mission Creation Tools — 6.30.0

**Cette version est celle des Open Training v6.**
La construction des Open Training v6 de Marianas, Normandy, Falklands, Caucasus et Sinai a fait remonter ce qui manquait ou ce qui trompait : un FARP dans la jungle, des P-51D que l'éditeur de mission refusait d'enregistrer, un Bradley face à un Tiger, des intercepteurs qui allaient se poser au lieu de défendre leur zone.
Cette version corrige l'essentiel ; ce qui reste est documenté comme limitation connue.
Falklands devient un théâtre pris en charge, une mission WW2 reçoit enfin des unités de son époque, et Normandy et Sinai ont leurs données de parking.
Côté campagne, un convoi ne reste plus figé face à un ennemi que personne ne vise, et le lever du soleil se calcule sur la bonne carte.

> ### ⚠️ Ce qui change dans vos missions
>
> **1. Retirez la `position` de Damas de votre `versions.yaml`.**
> Le `versions.yaml` livré déclarait une `position` à Damas quelle que soit la carte : une variante `sunrise` sur le Caucase démarrait 24 minutes après le lever du soleil à Kobuleti (50 en juin).
> Sans `position`, le build calcule maintenant les heures solaires au point du théâtre de la mission (près de Batumi sur le Caucase, de Hama en Syrie…).
> Un dossier de mission créé avant cette version garde le bloc de Damas, et le build avertit qu'il est hors du théâtre : supprimez ce bloc pour profiter du calcul automatique.
>
> **2. Une mission WW2 ou guerre froide n'emporte plus tout le catalogue d'avions.**
> Avec `mission.era: WW2`, le build n'injecte plus aucun des 51 avions modernes du catalogue livré de spawnables, et le dit ; avec `COLD_WAR`, il retire le MQ-9.
> Un `src/spawnables.yaml` écrit par le mission maker est injecté tel quel.
>
> **3. Un groupe joueur ne peut plus recevoir une fréquence que son avion ne capte pas.**
> Une fréquence explicite hors de la bande d'un groupe `Client` ou `Player` est refusée ; pour un groupe IA, elle est signalée.
> `validate` signale aussi un groupe déjà écrit hors bande.

---

## 🌍 Falklands, Normandy, Sinai

- **Falklands est un théâtre pris en charge** : `scaffold_mission` le propose avec une mission vierge, `terrain-sweep Falklands` fonctionne, et le géocodeur est borné à la carte (il répondait « San Julian » dans la province de Jujuy).
  Les fréquences ATC de 26 aérodromes (Cullen n'en a pas), la collection de canaux `airports-falklands` et 350 places de parking sur 27 aérodromes sont livrées.
- **Données de parking pour Normandy** (3 716 places sur 90 aérodromes) **et Sinai** (3 614 places sur 56 aérodromes), relevées dans DCS : `add_air_group` et `create_qra` y font partir un vol du parking ou de la piste, et les entrepôts des slots dynamiques n'offrent à chaque aérodrome de Sinai que ce que son parking accepte.
- Neuf théâtres gagnent leurs limites géographiques : un `geocode` qui ne peut rien vérifier le dit, au lieu de renvoyer « Omaha Beach » depuis l'Iowa.

---

## ⚔️ Des missions WW2 cohérentes

- **Les tables WW2 de `veafCasMission` contiennent des unités WW2** : `-infantry`, `-combat` et la famille `_spawn infantrygroup` posaient un fantassin moderne ou un Bradley face à un Tiger ; ils tirent maintenant `soldier_wwii_us`, `soldier_mauser98`, `M8_Greyhound`, `Daimler_AC`…
- **Six raccourcis WW2** : `-freya`, `-wurzburg`, `-flak88`, `-lefh`, `-pak40` et `-wespe`, qui prennent la coalition de l'unité qui porte la commande.
- **`list_shortcuts` dit pour quelle époque un raccourci est juste**, et `validate` signale un raccourci d'après-guerre dans une mission WW2.
- **Un chasseur WW2 armé de ses canons n'est plus « désarmé »** : 25 avertissements sur l'Open Training Normandy en cachaient un vrai.
- **`list_payloads` connaît les avions des modules et les bombardiers WW2** : de 45 à 129 types, 2 164 emports ; le Ju-88A4 et le B-17G ont leurs charges de raid.
- **Une fréquence que l'avion peut capter** : `add_air_group` et `add_player_slot` écrivaient 251 MHz sur tout groupe, ce que l'éditeur de mission refuse pour un P-51D (100–156 MHz) ou un Fw 190 (38,4–42,4 MHz).
  Un groupe garde 251 MHz s'il peut le capter, et prend sinon la fréquence par défaut de son type.
- Un alias dont le `country` n'appartient à aucune coalition (`country germany` dans une mission qui tient le Troisième Reich) n'arrête plus une combat zone : le spawn prend la coalition de l'unité qui porte la commande, avec un avertissement.

---

## 🚁 Placer juste : FARP, slots, convois, QRA

- **`add_farp` ne pose plus un FARP dans les arbres ou sur une pente sans rien dire** : « FARP Merizo » était parti dans la jungle des Marianas.
  Là où le catalogue de terrain dégagé couvre l'endroit, le FARP et son dépôt de munitions se déplacent sur le terrain dégagé le plus proche, à 1 km au plus ; une pente de plus de 3 m sur 40 m est signalée.
  La nouvelle commande `veaf-tools dcs farp-spot <théâtre> --at x,y` trouve dans DCS les emplacements plats et dégagés près d'un point.
  Un FARP posé sur la fréquence d'une tour d'aérodrome est signalé.
- **Un slot joueur en vol suit le cap demandé** : DCS oriente un départ en vol vers son second waypoint, et un A-10 demandé au 180 partait au nord.
  Mesuré dans DCS : 180° demandés, 180,5° volés.
- **Un convoi créé par `add_group` ou `create_combat_zone` part sur la route à vitesse de convoi** (59 km/h, la médiane de 126 convois de 14 missions faites à la main), au lieu de partir en tout-terrain à 20 km/h.
- **Une QRA créée avec `task: "CAP"` défend sa zone** au lieu d'aller se poser au terrain le plus proche.
- **Le ravitailleur du porte-avions laisse les indicatifs des ravitailleurs aux ravitailleurs** : le S-3B prend la famille `Shell` depuis le vol 9, et vos `Texaco 1` ou `Arco 1` gardent le leur.
- **`validate_mission` signale un groupe nommé pour une combat zone mais hors de son cercle** : la zone ne le prend pas, et rien n'apparaît en jeu.
- **Nouveaux réglages** : `roe` et `disperse` sur un groupe au sol (un groupe qui ne tire pas et ne se disperse pas), `loadout_from` sur `add_air_group`, un style de trait sur `add_map_drawing` (`dash`, `dot`…).

---

## 🎛️ Slots de contrôle et CTLD

- **Game master, commandant tactique, JTAC et observateur se règlent dans `mission.yaml`** : `mission.ground_control` les pose à chaque build (`game_master: 5`, ou `{blue: 5, red: 0}`, et `pilot_control_vehicles`).
  Une mission v6 naissait sans aucun de ces slots, et seule une retouche de `src/mission/mission` pouvait y remédier.
- **`validate` signale une mise à jour du catalogue CTLD, et `veaf-tools mission ctld-upgrade` l'applique** : un `ctld-config.yaml` écrit pour le catalogue 2.0.0 n'était remarqué qu'en jeu, CTLD annonçant trois réglages manquants.
  La commande ajoute les réglages manquants à leur valeur par défaut et ne change aucune valeur existante.
- **Le briefing d'une combat zone donne l'altitude du sol en son centre**, sous la ligne du bullseye : `ELEVATION : 1352 ft / 412 m.` (`ÉLÉVATION` en français).

---

## 🗺️ Campagnes et convois

- **Un convoi arrêté face à un ennemi que personne ne vise ne reste plus là indéfiniment** : sur le test de *Kolkhida* du 10 octobre, le convoi d'assaut rouge est resté 40 minutes à 700-850 m de deux Bradley en vue, sans un tir de part et d'autre.
  Un convoi de combat arrêté avec un ennemi en vue, qui ne tire ni n'est touché pendant 2 minutes, fonce maintenant sur l'ennemi le plus proche, et recommence toutes les 2 minutes tant que personne ne tire.
- **`campaign next` annonce la visibilité réellement volée** : 10 000 m tirés étaient annoncés tels quels alors que la mission emportait 80 km.
  Toute visibilité de 9 000 m ou plus est écrite comme le maximum de DCS, comme le `9999` d'un METAR se lit « 10 km ou plus » ; pour un ciel brumeux, donner 8 999 m ou moins.

---

## 🔧 Autres correctifs

- **Le menu radio VEAF ne s'ouvre plus sur une liste d'entrées « Activate mission »**, une régression de la 6.29.0 : une mission de combat déclarée dans le `mission-script.lua` de la mission attend sa place sous MISSIONS.
- **Le sanctuaire ne plante plus sur une arme dont la cible n'a pas de méthode `isExist`** : douze tirs de joueurs de l'Open Training Sinai l'avaient déclenché le 12 octobre.
- **Un canal de preset qui n'a pas la bande de sa liste est signalé** : trois canaux UHF d'une liste VHF de Syria-v6 n'atteignaient aucun avion depuis huit jours.
- **Le rapport de validation des presets ne contient plus ni chemin de machine ni date**, et ne modifie donc plus un fichier versionné quand rien n'a changé.
- **Le catalogue livré de slots dynamiques ne propose plus de mod et arme ses J-11A**, et le build signale un template dont DCS ne connaît pas le type.
- **Les actions de lecture de l'assistant IA s'accordent avec les actions d'écriture** : `describe_mission` lit un dossier de mission, `describe_units` donne les identifiants de groupe et d'unité, `terrain_elevation` prend `mission_path`.
- **`describe_known_limitations` tient dans une réponse d'outil** : sans argument, une liste courte ; `area`, `kind`, `id`, `theatre` ou `full` donnent les entrées complètes.
- **La sonde de terrain nomme un `dcs-serve` qui s'est arrêté**, en quelques secondes au lieu d'attendre 15 minutes.

---

## 📘 Documentation

- **Le prompt de l'Open Training a une section pour les époques sans ravitailleur, sans hélicoptère ou sans SAM** : ce qu'on retire en WW2, ce qui le remplace et quels modules couper.
- **Le lien « Lire ce document en français » du README mène de nouveau à la moitié française.**
- **De nouveaux pièges DCS documentés**, consultables par `describe_known_limitations` : un départ en vol à un seul waypoint part au nord, la zone « SCENERY REMOVE OBJECTS ZONE » laisse la forêt debout, `weapon:getTarget()` peut renvoyer un objet sans `isExist`.

---

## 🙏 Merci

Aux copains de la VEAF qui ont volé les Open Training v6 et relevé ce qui n'allait pas — chaque théâtre a apporté sa part de cette version.
