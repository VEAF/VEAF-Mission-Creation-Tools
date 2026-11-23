# VEAF Mission Creation Tools — 6.39.0

**La campagne persistante arrive dans les outils, CTLD passe en 2.1.0, et les missions v5 converties se comportent comme en v5.**

---

## 🌍 La campagne persistante

- **Une campagne dans l'esprit de Foothold, avec les seuls outils VEAF** : `mode: persistent` dans `campaign.yaml` fait de la campagne une seule mission qui se sauvegarde toute seule et repart où elle en était à chaque redémarrage.
- L'ennemi contre-attaque, capture et ravitaille ses zones, envoie des convois, des CAP, des frappes CAS et SEAD et des raids de bombardiers escortés, et paie tout ça sur une économie de guerre : usines, dépôts, ressources acheminées de zone en zone.
- Les joueurs gagnent des crédits (kills, captures, livraisons, tâches) et les dépensent dans une boutique : drone JTAC, CAP amie, ravitailleurs, escorte, vols CAS et SEAD, batteries sol-air pour leurs zones, convois d'assaut.
- Le briefing est un dossier de théâtre (`.pptx` et `.pdf`) avec la carte du réseau, et les pages du kneeboard sont écrites dans la mission.
- Tout se règle dans un bloc `dynamic:`, et **Campagne → Auto-contrôle (admin)** donne une ligne OK/KO par mécanisme.
- Nouvelle page de doc : *Campagne persistante*, et un exemple dans `src/defaults/campaign-folder-persistent/`.

Les modules de la campagne sont dans les scripts de toutes les missions, et restent inactifs sans campagne.

---

## 🚚 Les colonnes au sol démarrent

- **Un groupe créé avec une destination ou une route part bien** : par marqueur, par commande ou par une zone de combat, il reçoit sa route 5 s après sa création. Avant, DCS perdait l'ordre donné à l'instant de la création, et le groupe restait sur place.
- Un convoi sous le feu n'envoie plus ses camions se replier dans l'eau, et un convoi bloqué au contact est retiré à l'heure prévue.

---

## 🚁 CTLD 2.1.0

- CTLD passe de `2.0.0-rc17` à `2.1.0`, avec les corrections demandées par BFR.
- Trois comportements reviennent à ceux de CTLD 1.x :
  - les troupes et véhicules déposés partent vers l'ennemi le plus proche dans un rayon de 4 000 m, sinon marchent jusqu'à 2 000 m ;
  - ce que CTLD crée peut être conduit par les joueurs Combined Arms et les game masters ;
  - une zone `troopZones` ou `wpZones` marquée inactive attend son activation.
- Pack et unpack ne perdent plus rien quand DCS refuse, les troupes parachutées gardent leurs armes, et les caisses de réparation SAM reviennent.

---

## 🔁 Les missions v5 converties

- `convert v5` n'ajoute plus ce que la mission v5 n'avait pas : templates de slots dynamiques, entrepôts ouverts, variantes météo.
- AIEN et REMOTE ne sont activés que si la mission v5 les utilisait, et `VEAF_DYNAMIC_MISSIONPATH` désigne bien le dossier de la mission.
- Un dossier dont un fichier dépasserait la limite de longueur des chemins Windows est refusé avant toute écriture.
- `validate` et le build vérifient que chaque `custom_scripts` est du Lua 5.1 valide.

---

## 📋 Briefing

- **Une mission bilingue a son briefing dans chaque langue** : `build_mission_briefing` prend un paramètre `language`, et n'écrit que dans les `.miz` de cette langue.

---

## 🔧 Corrections

Les avertissements de mise en place de Skynet vont dans `dcs.log` au lieu de l'écran de tous les joueurs (`SKYNET.setup_warnings_on_screen: true` les remet). Un menu réservé à une coalition reste caché à l'autre, à toute profondeur. Une QRA dont le `random_pick` dépasse sa liste garde son nombre d'avions, comme en v5. Sans le hook serveur VEAF, un sous-menu par pilote porte le nom du joueur. Le waypoint BULLSEYE est au sol.

---

## ⚠️ À savoir

- **Un message CTLD au démarrage des missions qui ont un `ctld-config.yaml`** : « 3 réglage(s) absent(s) de la config de la mission ». C'est sans effet sur le jeu : CTLD prend la valeur par défaut. Pour le faire disparaître, lancez `.\veaf-tools.exe ctld-upgrade` dans le dossier de la mission, puis rebuildez.
- **CTLD ramène trois comportements de la 1.x** (voir plus haut). Pour garder ceux de la 2.0 : `maximumSearchDistance: 0` et `maximumMoveDistance: 0` pour que les troupes restent où elles se posent, `spawnedUnitsPlayerCanDrive: false` pour que personne ne les conduise.
- Un groupe SAM créé par CTLD s'appelle maintenant `<type>_CTLD_AA_<id>`.
- Une nouvelle mission démarre sans trafic civil, sans oiseaux et sans pannes aléatoires.
