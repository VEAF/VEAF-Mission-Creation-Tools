## Documentation Utilisateur des Commandes de Spawn et Alias (spawn.md)

Ce document liste et décrit les commandes disponibles pour les joueurs dans DCS World via les marqueurs F10, ainsi que les alias qui simplifient leur utilisation.

**Comment utiliser les commandes :**

1.  Ouvrez la carte F10 en jeu.
2.  Cliquez sur l'icône "Ajouter un marqueur" (généralement un crayon).
3.  Cliquez sur la carte à l'endroit où vous souhaitez exécuter la commande.
4.  Dans la boîte de texte du marqueur, saisissez la commande ou l'alias, suivie de ses paramètres.
5.  Appuyez sur Entrée. Le marqueur devrait disparaître après l'exécution de la commande.

**Format général des commandes :**

*   **Commandes directes :** `_spawn <type_de_spawn>, <paramètre> <valeur>, ...`
*   **Alias :** `-<nom_alias>#<coordonnées>!<délai>, <paramètre> <valeur>, ...`
    *   `<coordonnées>` (optionnel) : Nom d'un point nommé, d'une zone de déclenchement, ou coordonnées au format MGRS/LatLong (ex: `EG12345678`, `N42 30.123 E045 15.456`). Si omis, la position du marqueur est utilisée.
    *   `<délai>` (optionnel) : Délai en secondes avant l'exécution de la commande.
    *   Les paramètres sont séparés par des virgules.

**Paramètres communs :**

*   `radius <m>`: Rayon en mètres autour du marqueur pour le spawn ou l'effet.
*   `name <nom>`: Nom de l'unité/groupe/dessin/drapeau.
*   `country <pays>`: Pays de l'unité/groupe (ex: `USA`, `RUSSIA`, `FRANCE`).
*   `side <côté>`: Coalition (`BLUE` ou `RED`).
*   `alt <m>`: Altitude en mètres AGL (Above Ground Level).
*   `hdg <degrés>`: Cap en degrés (0-359).
*   `password <mot_de_passe>`: Mot de passe pour les commandes protégées.
*   `repeat <nombre>`: Nombre de fois que la commande doit se répéter.
*   `delay <secondes>`: Délai en secondes entre chaque répétition.
*   `delayed <secondes>`: Délai en secondes avant la première exécution de la commande.
*   `silent`: Ne pas afficher de message de confirmation en jeu.
*   `showmfd`: Afficher l'unité/groupe sur les MFD des avions.

---

### Commandes de Spawn (`_spawn`)

Ces commandes permettent de faire apparaître des entités spécifiques.

*   **`_spawn unit, name <type_unité>, ...`**
    *   **Description :** Fait apparaître une unité individuelle.
    *   **Paramètres spécifiques :**
        *   `unitname <nom_spécifique>`: Nom unique pour l'unité (si non spécifié, un nom par défaut est généré).
        *   `role jtac`: Fait apparaître un JTAC (Joint Terminal Attack Controller).
            *   `laser <code_laser>`: Code laser (ex: `1688`).
            *   `freq <fréquence>`: Fréquence radio (ex: `226.300`).
            *   `mod <modulation>`: Modulation radio (`fm` ou `am`).
        *   `role tacan`: Fait apparaître une balise TACAN.
            *   `channel <canal>`: Canal TACAN (ex: `99`).
            *   `band <bande>`: Bande TACAN (`X` ou `Y`).
            *   `code <code_tacan>`: Code TACAN (ex: `T99`).
        *   `static`: Force l'unité à être statique (non mobile).
    *   **Exemple :** `_spawn unit, name M1A2 Abrams, country USA, radius 100`
    *   **Exemple JTAC :** `_spawn unit, role jtac, laser 1688, freq 226.300, mod fm`
    *   **Exemple TACAN :** `_spawn unit, role tacan, channel 99, band X`

*   **`_spawn group, name <nom_groupe>, ...`**
    *   **Description :** Fait apparaître un groupe d'unités prédéfini.
    *   **Paramètres spécifiques :**
        *   `czname <nom_cz>`: Nom de la zone de combat à ajouter au nom du groupe.
        *   `spacing <m>`: Espacement entre les unités du groupe.
        *   `skynet <true/false/nom_reseau>`: Ajoute le groupe au réseau Skynet IADS.
        *   `ewr`: Force le groupe à être un EWR (Early Warning Radar) pour Skynet.
        *   `pointdefense`: Ajoute le groupe comme défense ponctuelle au site SAM IADS le plus proche.
        *   `alarm <0/1/2>`: État d'alerte de l'IA (0=AUTO, 1=VERT, 2=ROUGE).
        *   `disperse <secondes>`: Temps de dispersion des groupes sous attaque.
    *   **Exemple :** `_spawn group, name sa10, country RUSSIA, skynet true`

*   **`_spawn cap, name <nom_cap>, ...`**
    *   **Description :** Fait apparaître une patrouille aérienne de combat (CAP).
    *   **Paramètres spécifiques :**
        *   `distance <m>`: Distance de la CAP par rapport au point de spawn.
        *   `capradius <m>`: Rayon de la zone de patrouille de la CAP.
    *   **Exemple :** `_spawn cap, name MyCAP, country USA, alt 6000, speed 500`

*   **`_spawn afac, name <nom_afac>, ...`**
    *   **Description :** Fait apparaître un AFAC (Airborne Forward Air Controller).
    *   **Paramètres spécifiques :**
        *   `immortal`: Rend l'AFAC immortel.
    *   **Exemple :** `_spawn afac, name MyAFAC, country USA, freq 255.000, mod am`

*   **`_spawn farp, name <nom_farp>, ...`**
    *   **Description :** Crée un point de ravitaillement et de réarmement avancé (FARP).
    *   **Paramètres spécifiques :**
        *   `type <type_farp>`: Type de FARP (`quad`, `single`, `pad`, `invisible`).
        *   `nofarpmarkers`: Ne pas afficher les véhicules spéciaux qui marquent la position du FARP.
        *   `tacanChannel <canal>`, `tacanCode <code_tacan>`, `tacanBand <bande>`: Configure une balise TACAN pour le FARP.
    *   **Exemple :** `_spawn farp, name MyFARP, country USA, type quad`

*   **`_spawn fob, name <nom_fob>, ...`**
    *   **Description :** Crée une base d'opérations avancée (FOB). Nécessite le module CTLD.
    *   **Exemple :** `_spawn fob, name MyFOB, country USA`

*   **`_spawn convoy, dest <point_nommé_ou_coords>, ...`**
    *   **Description :** Fait apparaître un convoi terrestre qui se déplace vers une destination.
    *   **Paramètres spécifiques :**
        *   `dest <point_nommé_ou_coords>`: Point nommé ou coordonnées de destination. **Obligatoire.**
        *   `patrol`: Le convoi patrouille entre le point de spawn et la destination.
        *   `offroad`: Le convoi ne suit pas les routes.
        *   `size <nombre>`: Nombre d'unités dans le convoi.
        *   `defense <1-5>`: Force de défense du convoi.
        *   `armor <1-5>`: Force de blindage du convoi.
    *   **Exemple :** `_spawn convoy, dest MyDestination, country RUSSIA, size 10, speed 50`

*   **`_spawn infantrygroup, ...`**
    *   **Description :** Fait apparaître un groupe d'infanterie dynamique.
    *   **Paramètres spécifiques :**
        *   `size <nombre>`: Nombre d'unités d'infanterie.
        *   `defense <1-5>`: Force de défense.
        *   `armor <1-5>`: Force de blindage.
    *   **Exemple :** `_spawn infantrygroup, country USA, size 8, defense 3`

*   **`_spawn armorgroup, ...`**
    *   **Description :** Fait apparaître un peloton blindé dynamique.
    *   **Paramètres spécifiques :**
        *   `size <nombre>`: Nombre d'unités blindées.
        *   `defense <1-5>`: Force de défense.
        *   `armor <1-5>`: Force de blindage.
    *   **Exemple :** `_spawn armorgroup, country RUSSIA, size 5, armor 4`

*   **`_spawn samgroup, ...`**
    *   **Description :** Fait apparaître une batterie de défense aérienne dynamique.
    *   **Paramètres spécifiques :**
        *   `defense <1-5>`: Force de défense (détermine le type de SAM).
    *   **Exemple :** `_spawn samgroup, country RUSSIA, defense 5`

*   **`_spawn transportgroup, ...`**
    *   **Description :** Fait apparaître une compagnie de transport dynamique.
    *   **Paramètres spécifiques :**
        *   `size <nombre>`: Nombre de véhicules de transport.
        *   `defense <1-5>`: Force de défense.
    *   **Exemple :** `_spawn transportgroup, country USA, size 15`

*   **`_spawn combatgroup, ...`**
    *   **Description :** Fait apparaître un groupe de combat complet dynamique (mélange d'infanterie, blindés, etc.).
    *   **Paramètres spécifiques :**
        *   `size <nombre>`: Taille du groupe.
        *   `defense <1-5>`: Force de défense.
        *   `armor <1-5>`: Force de blindage.
    *   **Exemple :** `_spawn combatgroup, country RUSSIA, size 3, defense 4, armor 3`

*   **`_spawn cargo, type <type_cargaison>, ...`**
    *   **Description :** Fait apparaître une cargaison pour héliportage.
    *   **Paramètres spécifiques :**
        *   `type <type_cargaison>`: Type de cargaison (ex: `container_cargo`).
        *   `weight <0-5>`: Biais de poids de la cargaison (0=léger, 5=lourd).
        *   `smoke`: Marque la cargaison avec de la fumée verte.
    *   **Exemple :** `_spawn cargo, type container_cargo, weight 3, smoke`

*   **`_spawn logistic, ...`**
    *   **Description :** Fait apparaître une unité logistique pour CTLD.
    *   **Exemple :** `_spawn logistic, country USA`

*   **`_spawn bomb, power <puissance>, shells <nombre>, ...`**
    *   **Description :** Simule un tir d'artillerie.
    *   **Paramètres spécifiques :**
        *   `power <puissance>`: Puissance de l'explosion.
        *   `shells <nombre>`: Nombre d'obus.
        *   `alt <m>`: Altitude de l'explosion.
        *   `altdelta <m>`: Variation d'altitude pour les explosions.
    *   **Exemple :** `_spawn bomb, power 100, shells 5, radius 50`

*   **`_spawn smoke, color <couleur>, shells <nombre>, ...`**
    *   **Description :** Fait apparaître de la fumée.
    *   **Paramètres spécifiques :**
        *   `color <couleur>`: Couleur de la fumée (`red`, `green`, `orange`, `blue`, `white`).
        *   `shells <nombre>`: Nombre de panaches de fumée.
    *   **Exemple :** `_spawn smoke, color white, shells 1`

*   **`_spawn flare, power <puissance>, shells <nombre>, ...`**
    *   **Description :** Fait apparaître des fusées éclairantes d'illumination.
    *   **Paramètres spécifiques :**
        *   `power <puissance>`: Puissance de la lumière.
        *   `shells <nombre>`: Nombre de fusées.
        *   `alt <m>`: Altitude de déploiement.
    *   **Exemple :** `_spawn flare, power 500, shells 3, alt 1500`

*   **`_spawn signal, color <couleur>, shells <nombre>, ...`**
    *   **Description :** Fait apparaître des fusées de signalisation.
    *   **Paramètres spécifiques :**
        *   `color <couleur>`: Couleur de la fusée (`red`, `green`, `orange`, `blue`, `white`).
        *   `shells <nombre>`: Nombre de fusées.
    *   **Exemple :** `_spawn signal, color green, shells 1`

---

### Commandes de Gestion des Entités

*   **`_destroy, radius <m>, unitname <nom_unité_ou_groupe>`**
    *   **Description :** Détruit les unités ou groupes dans le rayon spécifié, ou une unité/groupe spécifique par son nom.
    *   **Paramètres spécifiques :**
        *   `radius <m>`: Rayon de destruction autour du marqueur.
        *   `unitname <nom>`: Nom exact de l'unité ou du groupe à détruire.
    *   **Exemple :** `_destroy, radius 100` (détruit tout dans un rayon de 100m)
    *   **Exemple :** `_destroy, unitname MyGroup` (détruit le groupe nommé "MyGroup")

*   **`_teleport, name <nom_groupe>`**
    *   **Description :** Téléporte un groupe nommé à la position du marqueur.
    *   **Paramètres spécifiques :**
        *   `name <nom_groupe>`: Nom du groupe à téléporter.
    *   **Exemple :** `_teleport, name MyConvoy`

---

### Commandes de Dessin sur la Carte (`_drawing`)

Ces commandes permettent de dessiner des formes sur la carte F10.

*   **`_drawing add, name <nom_dessin>, ...`**
    *   **Description :** Ajoute un point à un dessin existant ou commence un nouveau polygone.
    *   **Paramètres spécifiques :**
        *   `name <nom_dessin>`: Nom du dessin (obligatoire).
        *   `color <couleur>`: Couleur de la ligne (ex: `red`, `blue`, `green`).
        *   `fill <couleur_remplissage>`: Couleur de remplissage (pour les formes fermées).
        *   `arrow`: Dessine une flèche.
    *   **Exemple :** `_drawing add, name MyRoute, color blue` (ajoutez plusieurs marqueurs pour former un polygone)

*   **`_drawing square, name <nom_dessin>, radius <côté>, ...`**
    *   **Description :** Dessine un carré sur la carte.
    *   **Paramètres spécifiques :**
        *   `name <nom_dessin>`: Nom du dessin (obligatoire).
        *   `radius <m>`: Longueur du côté du carré.
        *   `color <couleur>`: Couleur de la ligne.
        *   `fill <couleur_remplissage>`: Couleur de remplissage.
    *   **Exemple :** `_drawing square, name MySquare, radius 5000, color red, fill green`

*   **`_drawing circle, name <nom_dessin>, radius <rayon>, ...`**
    *   **Description :** Dessine un cercle sur la carte.
    *   **Paramètres spécifiques :**
        *   `name <nom_dessin>`: Nom du dessin (obligatoire).
        *   `radius <m>`: Rayon du cercle.
        *   `color <couleur>`: Couleur de la ligne.
        *   `fill <couleur_remplissage>`: Couleur de remplissage.
    *   **Exemple :** `_drawing circle, name MyCircle, radius 10000, color blue`

*   **`_drawing erase, name <nom_dessin>`**
    *   **Description :** Efface un dessin de la carte.
    *   **Paramètres spécifiques :**
        *   `name <nom_dessin>`: Nom du dessin à effacer (obligatoire).
    *   **Exemple :** `_drawing erase, name MyRoute`

---

### Commandes Mission Master (`_mm`)

Ces commandes interagissent avec le système de drapeaux et de "runnables" du Mission Master.

*   **`_mm flagon, name <nom_drapeau>`**
    *   **Description :** Active un drapeau du Mission Master.
    *   **Exemple :** `_mm flagon, name MyFlag`

*   **`_mm flagoff, name <nom_drapeau>`**
    *   **Description :** Désactive un drapeau du Mission Master.
    *   **Exemple :** `_mm flagoff, name MyFlag`

*   **`_mm getflag, name <nom_drapeau>`**
    *   **Description :** Affiche la valeur d'un drapeau du Mission Master.
    *   **Exemple :** `_mm getflag, name MyFlag`

*   **`_mm run, name <nom_runnable>`**
    *   **Description :** Exécute un "runnable" du Mission Master.
    *   **Exemple :** `_mm run, name MyRunnable`

---

### Alias de Commandes (`-`)

Ces alias simplifient l'utilisation des commandes `_spawn` et d'autres commandes VEAF.

*   **Alias Génériques de SAM :**
    *   `-samLR`: Batterie SAM longue portée aléatoire.
    *   `-samSR`: Batterie SAM courte portée aléatoire.
    *   `-sam`: Batterie SAM aléatoire (portée variable).
    *   `-aaa`: Batterie AAA aléatoire.

*   **Alias de Défenses Aériennes Spécifiques :**
    *   `-hq7`, `-hq7_single`, `-hq7noew`, `-hq7eo`, `-hq7eo_single`, `-hq7eo_noew`: Batteries HQ-7 (Red Banner).
    *   `-sa2`, `-sa3`, `-sa5`, `-sa6`, `-sa8`, `-sa9`, `-sa9_squad`, `-sa10`, `-sa11`, `-sa13`, `-sa13_squad`, `-sa15`, `-insurgent_manpad`, `-sa18`, `-sa18s`, `-sa19`: Systèmes SAM russes/insurgés.
    *   `-shilka`, `-zu23`: Véhicules AAA.
    *   `-manpads`: Plusieurs soldats MANPADS dispersés.
    *   `-rapier`, `-roland`, `-rolandnoew`, `-nasams`, `-nasams_b`, `-hawk`, `-patriot`, `-stinger`, `-avenger`, `-avenger_squad`: Systèmes SAM occidentaux.
    *   `-dogear`, `-blue_ewr`, `-ewr`: Radars EWR.

*   **Alias d'Unités Navales :**
    *   `-burke`: Destroyer USS Arleigh Burke IIa.
    *   `-perry`: Destroyer O.H. Perry.
    *   `-ticonderoga`: Frégate Ticonderoga.
    *   `-rezky`: Frégate FF 1135M Rezky.
    *   `-pyotr`: CGN 1144.2 Pyotr Velikiy.

*   **Alias de Convois :**
    *   `-hv_convoy_red`: Convoi d'attaque rouge de grande valeur.
    *   `-attack_convoy_red`: Convoi d'attaque rouge.
    *   `-QRC_red`: Convoi de réaction rapide rouge.
    *   `-civilian_convoy_red`: Convoi civil rouge.
    *   `-QRC_blue`: Convoi de réaction rapide bleu.
    *   `-convoy, dest <point_nommé_ou_coords>`: Convoi dynamique (nécessite une destination).

*   **Alias de Commandes Générales :**
    *   `-point <nom_point>`: Nomme un point sur la carte.
    *   `-destroy`: Détruit toute unité dans un rayon de 100m.
    *   `-login <mot_de_passe>`: Déverrouille le système (pour les commandes protégées).
    *   `-logout`: Verrouille le système.
    *   `-send, message <message>`: Envoie un message radio.
    *   `-play, path <chemin_fichier_son>`: Joue un fichier son sur la radio.

*   **Alias de Groupes Terrestres Spécifiques :**
    *   `-mortar`: Équipe de mortier.
    *   `-arty`: Batterie d'artillerie M-109.
    *   `-msta`: Batterie d'artillerie Msta.
    *   `-plz05`: Batterie d'artillerie PLZ-05.
    *   `-mlrs`: Batterie d'artillerie MLRS.
    *   `-smerch_he`, `-smerch_cm`: Batteries d'artillerie Smerch.
    *   `-uragan`: Batterie d'artillerie Uragan.
    *   `-grad`: Batterie d'artillerie Grad.
    *   `-cargoships`: Navires de cargaison sans défense.
    *   `-escortedcargoships`: Navires de cargaison escortés.
    *   `-combatships`: Navires de combat.

*   **Alias de Groupes Dynamiques :**
    *   `-armor`: Groupe blindé dynamique.
    *   `-infantry`: Section d'infanterie dynamique.
    *   `-transport`: Compagnie de transport dynamique.
    *   `-combat`: Groupe de combat dynamique.

*   **Alias CAS/Cargaison :**
    *   `-cas`: Génère un groupe CAS aléatoire pour l'entraînement.
    *   `-cargo`: Génère une cargaison pour héliportage.
    *   `-refuel`: Fait apparaître un groupe de ravitaillement US.

*   **Alias JTAC/AFAC :**
    *   `-jtac`: JTAC Humvee.
    *   `-afac`: AFAC MQ-9 Reaper.
    *   `-afachere, name <nom_afac>, ...`: Déplace un AFAC à une position spécifique.

*   **Alias d'Artillerie (ARTY-1, ARTY-2, ARTY-3) :**
    *   `-arty1`, `-arty2`, `-arty3`: Fait apparaître une batterie d'artillerie nommée.
    *   `-arty1_aim, target <point_cible>`: Ordonne à ARTY-1 de tirer pour l'ajustement.
    *   `-arty1_fire, target <point_cible>`: Ordonne à ARTY-1 de tirer pour l'effet.
    *   `-arty1_stop`: Ordonne à ARTY-1 d'arrêter d'écouter les ordres.
    *   `-arty1_start`: Ordonne à ARTY-1 de commencer à écouter les ordres.
    *   (Idem pour `-arty2_...` et `-arty3_...`)

*   **Alias d'Effets et de Bombardements :**
    *   `-cesar`: Bombardement d'artillerie de précision (faible rendement).
    *   `-shell`: Bombardement d'artillerie d'une petite zone (beaucoup d'obus).
    *   `-flak`: Bombardement anti-aérien (flak).
    *   `-light`: Illumination par tir d'artillerie.
    *   `-smoke`: Fait apparaître une fumée blanche.
    *   `-longsmoke`: Fait apparaître une fumée blanche renouvelée toutes les 5 minutes pendant 30 minutes.
    *   `-signal`: Fait apparaître une fusée de signalisation.

*   **Alias de Ravitailleur :**
    *   `-tankerhere, name <nom_tanker>, ...`: Déplace un ravitailleur à une position spécifique.
    *   `-tanker`: Alias pour `-tankerhere`.
    *   `-tankerlow`: Règle le ravitailleur le plus proche à FL120 (12000 pieds) et 200 KIAS.
    *   `-tankerhigh`: Règle le ravitailleur le plus proche à FL220 (22000 pieds) et 300 KIAS.

*   **Alias TACAN :**
    *   `-tacan`: Crée une balise TACAN portable.

*   **Alias FARP/FOB :**
    *   `-farp, name <nom_farp>`: Crée un nouveau FARP.
    *   `-farpNoMarker, name <nom_farp>`: Crée un FARP invisible sans marqueurs spéciaux.
    *   `-fob`: Crée une nouvelle FOB.

*   **Alias de Dessin :**
    *   `-draw, name <nom_dessin>`: Commence un dessin ou ajoute un point à un dessin existant.
    *   `-arrow, name <nom_dessin>`: Commence un dessin de flèche ou ajoute un point à une flèche existante.
    *   `-square, name <nom_dessin>`: Ajoute un carré à la carte.
    *   `-circle, name <nom_dessin>`: Ajoute un cercle à la carte.
    *   `-erasedrawing, name <nom_dessin>`: Efface un dessin de la carte.

*   **Alias CAP :**
    *   `-cap, name <nom_cap>`: Patrouille aérienne de combat dynamique.

*   **Alias Mission Master :**
    *   `-flag, name <nom_drapeau>`: Affiche la valeur d'un drapeau Mission Master.
    *   `-flagon, name <nom_drapeau>`: Active un drapeau Mission Master.
    *   `-flagoff, name <nom_drapeau>`: Désactive un drapeau Mission Master.
    *   `-run, name <nom_runnable>`: Exécute un "runnable" Mission Master.

*   **Alias Mission/Zone de Combat :**
    *   `-airstart, name <nom_mission>`: Démarre une mission de combat.
    *   `-airstop, name <nom_mission>`: Arrête une mission de combat.
    *   `-zonestart, name <nom_zone>`: Active une zone de combat.
    *   `-zonestop, name <nom_zone>`: Désactive une zone de combat.
