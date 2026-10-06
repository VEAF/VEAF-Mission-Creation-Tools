# VEAF Mission Creation Tools — 6.28.0

**Cette version est celle de la mission de démo v6.**
[VEAF-Demo-Mission-v6](https://github.com/VEAF/VEAF-Demo-Mission-v6) montre chaque fonctionnalité en jeu, avec une visite guidée, et sert désormais de recette avant chaque release.
La construire, puis la dérouler comme recette, a fait remonter une quinzaine de défauts que rien ne signalait — un menu radio `lua` qui arrêtait toute la configuration, un menu « MISSIONS » vide, un commentaire qui cassait CTLD, des navires qui cherchaient leur place sur la terre ferme — et ils sont corrigés ici.
À côté, les QRA et les vagues aériennes reposent maintenant sur une même base, et gagnent ce que plusieurs issues demandaient : suivre un porte-avions, dépendre d'autre chose qu'un aérodrome, défendre des groupes amis.

> ### ⚠️ Ce qui change dans vos missions
>
> **1. Une QRA liée à un navire s'arrête quand il coule.**
> Une QRA dont l'`airport_link` est un navire attendait jusqu'ici, pour toujours, un aérodrome qui ne pouvait pas revenir.
> Elle s'arrête désormais pour de bon quand le navire est coulé.
>
> **2. `_destroy, name X` ne détruit plus que X.**
> La commande ne lisait que `unitname` : avec `name`, X survivait et **tout** ce qui se trouvait à moins de 150 m du marqueur était détruit.
> `name` est maintenant accepté comme `unitname` (qui l'emporte si les deux sont écrits).
>
> **3. Une CAP choisit ses cibles autrement.**
> À distance égale, un avion qui vient vers la patrouille passe avant un avion qui la croise, et celui-ci avant un avion qui s'éloigne.
> Un avion qui s'éloigne à plus de 40 km de la patrouille n'est plus engagé : la CAP reste sur sa zone.
> Face à plusieurs cibles, chaque avion de la patrouille reçoit la sienne, la plus importante d'abord.
> Les seuils et la coupure à 40 km sont des estimations à régler en jeu, et la répartition par avion reste à confirmer en vol : vos retours sont bienvenus.

---

## 🎬 La mission de démo v6, et ce qu'elle a trouvé

[VEAF-Demo-Mission-v6](https://github.com/VEAF/VEAF-Demo-Mission-v6) remplace l'ancienne mission de démo.
Chaque page de module de la documentation dit quelle étape de la visite le montre.
Le guide du mission maker ne dit plus de forker l'ancienne démo pour commencer : `mission prepare` le fait.

Ce que sa construction et sa recette ont fait corriger :

- **Une action `lua` dans un menu radio n'arrête plus toute la configuration VEAF.**
  Elle était évaluée au chargement de `veaf-config.lua`, avant que `mission-script.lua` ne définisse la fonction, et tout ce qui suivait dans la configuration ne s'exécutait jamais.
  La fonction est maintenant cherchée au clic.
- **L'erreur d'initialisation d'un module n'emporte plus les autres.**
  Chaque module démarre dans son propre bloc protégé : l'échec est journalisé (`<MODULE> init failed: …`) et le module suivant démarre.
- **Un commentaire en fin de ligne dans `ctld-config.yaml` ne casse plus CTLD**, et le `.miz` embarque bien la configuration CTLD du build qui l'a produit — un ancien `src/scripts/CTLD_userConfig.lua` pouvait l'emporter sur celui qui venait d'être généré.
- **`-cargoships`, `-escortedcargoships` et `-combatships` spawnent en mer.**
  La position d'un groupe de navires était cherchée sur terre ; un spawn qui ne trouve aucune position le journalise maintenant.
- **Une opération de combat s'active et se désactive depuis son propre menu radio**, avec les règles d'une zone de combat (sécurisé, sauf en entraînement).
  La désactiver désactive ses zones, et l'activer laisse tranquille une zone qui tourne déjà au lieu de la spawner une seconde fois.
- **Un marqueur `#veafInterpreter` reçoit la place que demande sa commande** : un site SA-11 porté par une seule unité recevait la place d'un seul véhicule.
- **Le menu F10 « MISSIONS » apparaît au démarrage dans une mission qui déclare des `cap_missions` ou des `combat_missions`.**
  La configuration générée initialisait le module avant d'y ajouter ses missions : le menu était construit sur une liste vide et jamais reconstruit.
- **`_destroy, radius …` détruit toutes les unités du cercle.**
  Les unités trouvées étaient recherchées une seconde fois par leur nom, et DCS ne répond rien pour certaines (le pack de véhicules « [CH] ») : `-menage` laissait un peloton entier debout.
  La même recherche pouvait faire manquer à `_tanker` un ravitailleur sous le marqueur.
- **Un groupe CAS porte le nom de son camp** : après une première CAS bleue, tous les groupes suivants, rouges compris, s'appelaient « Blue CAS Group ».
- **`mission build` garde son code de sortie** quand sa sortie part vers `/dev/null` : la pause de fin le prenait pour un double-clic et transformait un build réussi en échec.
- **Petites vérités** : la documentation spawne un `T-80UD` (`T-80` ne correspond à aucun type DCS), le modèle `waypoints.yaml` dit que le build ajoute un waypoint `BULLSEYE`, et les commandes « start air operations » du porte-avions comme celles du brouillard du menu météo sont traduites.
  La liste des noms `_spawn unit` du guide pilote proposait deux avions (refusés par la commande), une batterie (`SA-6`, qui est un groupe) et un `M1 Abrams` mal écrit ; elle affirmait aussi que les noms étaient sensibles à la casse, ce qu'ils ne sont pas.

---

## ✈️ QRA et vagues aériennes

Les QRA et les vagues aériennes restent deux comportements distincts — une QRA défend son terrain en boucle, une vague mène une partie qui se termine — mais la mécanique commune (zone, filtre d'altitude, tirage des groupes, spawn, dessin) est maintenant écrite une seule fois.
Leurs clés `mission.yaml`, leurs méthodes et leurs messages aux pilotes ne changent pas.

Ce qu'elles y gagnent :

- **Dépendre de plus qu'un aérodrome** (#183) : `links:` liste les aérodromes, FARP, navires, groupes ou statiques dont la zone dépend.
  Un aérodrome ou une FARP perdu la met en pause jusqu'à sa reprise, comme `airport_link` l'a toujours fait ; un navire, un groupe ou un statique détruit l'arrête pour de bon.
- **Suivre un porte-avions** (#186) : `follow_unit:` fait suivre une unité à la zone, et une trigger zone liée à une unité dans l'éditeur de mission la suit aussi.
- **Des groupes amis à défendre** (#182, #176) : les `friendly_groups` d'une vague spawnent avec elle pour le camp des joueurs, et la zone est perdue quand ils sont tous morts.
  Ses `support_groups` spawnent avec elle et ne comptent pas.
- **« Mort, c'est mort »** (#179) : `closed_once_active: true` renvoie, une fois la zone lancée, tout joueur absent à l'activation ou revenu dans le slot d'un avion abattu — averti, puis flak, puis détruit, au bout de `max_seconds_outside_players`, que `mission.yaml` peut maintenant régler.
- **Le stock et le ravitaillement d'une QRA dans `mission.yaml`** : le bloc `logistics:` (`groups_available`, `max_ready`, `resupply_delay`, `resupply_amount`, `max_resupplies`, `resupply_below`) règle ce que seul du Lua écrit à la main pouvait régler ; `validate` signale une clé qu'il ne connaît pas.

Et ce qui ne marchait pas :

- **Une QRA ou une vague dont la commande spawne en différé n'est plus perdue en route** (#1078).
  Une commande `delayed` ou `repeat` rendait la main avant de spawner : la CAP gardait la mauvaise zone, la vague était déclarée morte au tick suivant, et le groupe devenait indestructible.
- **Les vagues par commande d'une zone de vagues spawnent dans le camp opposé aux joueurs** ; elles n'avaient reçu aucun camp, ce qui donnait des ennemis rouges à des joueurs rouges.
- **Arrêter une zone de vagues efface son dessin** de la carte F10.

---

## 🛰️ Au marqueur : AWACS, escorte

- **`-awacs`** pose un E-3A (bleu) ou un A-50 (rouge) en hippodrome depuis le marqueur, sans template ; `type`, `alt`, `hdg`, `dist`, `speed` et `freq` l'ajustent (#188).
  Il rejoint le réseau Skynet de son camp et allume son datalink par défaut (`skynet false`, `eplrs false` pour s'en passer), et `escort <template>` lui ajoute une escorte de chasseurs.
- **`-escort f15-fox3`** escorte l'avion ami ou neutre le plus proche du marqueur, à moins de 10 NM : les chasseurs apparaissent 3 km derrière lui avec la tâche DCS `Escort`, autorisés à tirer (#189).
  Un pilote peut aussi demander sa propre escorte depuis *F10 → VEAF → SPAWN → +Escort me*.
- **Une CAP qui se pose ou qui est détruite ne reste plus en mémoire** pour le reste de la session (#1079).

---

## 📻 La fréquence de la tour, dans le briefing et l'ATIS

Un pilote qui prend un slot, ou qui demande l'ATIS depuis le menu F10, lit maintenant les fréquences UHF / VHF / FM de la tour et son TACAN, celles de la fiche de l'aérodrome dans la vue F10 : `Tower 260.000 UHF / 131.000 VHF / 40.400 FM — TACAN 16X`.
Quand la collection `bases` de la mission donne à l'aérodrome son propre canal, différent de la tour DCS, une seconde ligne le donne aussi, sous son titre.
Quand la mission coupe l'ATC, un aérodrome qui a un canal de mission ne donne que celui-là.
Un porte-avions, une FARP ou un aérodrome absent de la référence n'a pas de ligne.

---

## 🛠️ Ce que l'assistant sait faire de plus

- **`add_combat_operation`** déclare une opération sur des zones que la mission a déjà, et refuse une tâche qui nomme une zone inexistante.
- **`set_briefing_picture`** ajoute une image au briefing d'un camp en un seul appel.
- **`edit_route`** accepte `road: true|false` sur le waypoint d'un groupe terrestre, et **`describe_map`** donne la position et le nombre d'unités de chaque groupe.
- **Un nouveau piège DCS documenté** (`describe_known_limitations`) : un contact AWACS peut rester marqué `DLINK` plusieurs minutes avant de passer `RADAR`, et Skynet, qui ne lit que `RADAR`, l'ignore jusque-là.
- **Un second piège DCS documenté** : `Unit.getByName` peut répondre `nil` pour une unité qui existe et porte bien ce nom — mesuré sur les véhicules du pack « [CH] ».
  Une fois l'objet en main, il faut agir dessus plutôt que le rechercher par son nom.

---

## 💬 Sur Discord et dans la documentation

- **Un fil `/ask` devient un rapport de bug ou une suggestion sans rien retaper** : mentionner le bot avec le seul mot `bug` ou `suggest` ouvre le formulaire `/bug` ou `/suggest` prérempli depuis le fil, et rien n'est déposé sans la confirmation habituelle.
  Le bouton *Report a bug* sous une réponse emporte maintenant tout le fil.
- **L'assistant de la documentation continue de répondre** quand son premier modèle a épuisé sa journée : la question passe au modèle suivant, chacun avec sa propre allocation gratuite.
  Le message « revient demain matin » n'apparaît plus qu'une fois toute la chaîne épuisée.

---

## 📦 Téléchargements

Il n'y a plus de binaire macOS Intel (`x86_64`) dans les releases ; aucun n'avait jamais été publié.
Linux x86_64 et macOS arm64 (Apple Silicon) ne changent pas.
