# VEAF Mission Creation Tools — 6.27.0

**Cette version apprend aux outils à construire une mission à objectif.** Jusqu'ici, l'assistant
savait bâtir un théâtre d'entraînement qui tourne pendant des mois. Il sait maintenant préparer l'autre
moitié de ce que vole la VEAF : une mission jouée une fois, en une session, avec un package, un ou
plusieurs objectifs, une menace et un chemin du retour. Pour y arriver, il a fallu qu'une opération
sache se terminer, qu'un pont ou un bâtiment de la carte puisse être un objectif, que l'on connaisse
l'altitude du sol sans lancer DCS, et que les intercepteurs d'une QRA aient enfin quelque chose à
faire une fois en l'air.

> ### ⚠️ Ce qui change dans vos missions
>
> **1. CTLD : le UH-1H ne porte plus de véhicule entier, le Mi-8MT si.** Le UH-1H embarque désormais
> 10 soldats au lieu de 8 ; le Mi-8MT porte un véhicule, jusqu'à 3 000 kg. Ce sont les valeurs par
> défaut de CTLD 2.0.0-rc12 : elles s'appliquent à une mission **sans** `ctld-config.yaml`, ou créée à
> partir de maintenant. Un `ctld-config.yaml` existant n'est jamais réécrit et garde ses valeurs.
>
> **2. L'objectif « ne pas détruire d'objets de la carte » peut maintenant échouer.** Le registre du
> décor détruit n'enregistrait rien depuis la 6.18.0 : une mission de combat qui demandait de
> préserver un objet de la carte réussissait donc à tous les coups. Elle peut désormais finir en échec.
>
> **3. Les intercepteurs d'une QRA ou d'une vague reçoivent une patrouille.** Un groupe dont la tâche
> est `CAP` ou `Intercept`, et dont la route n'engage aucun avion, patrouille maintenant au-dessus de
> la zone qu'il défend (voir plus bas). Une route écrite à la main pour un tel groupe est **remplacée**,
> et le build le signale par un avertissement. Une route qui engage des avions est volée telle
> qu'écrite. Il faut rebuilder la mission pour en profiter.
>
> **4. Les fréquences des aérodromes viennent de DCS.** Les collections `airports-<théâtre>` du
> `presets.yaml` par défaut sont maintenant générées depuis DCS. Vos missions existantes gardent leur
> propre `presets.yaml` : lancez `.\veaf-tools.exe content airfield-channels` pour aligner leurs canaux
> d'aérodromes.

---

## 🎯 Les missions à objectif

**Un nouveau prompt pour l'assistant** (`.prompts/new-objective-mission.fr.md`) prépare une mission
jouée une fois, en deux temps :

1. **Proposer.** Il propose autant de scénarios numérotés que vous voulez, chacun sur un écran, avec
   ses distances mesurées et son temps de vol comparé à la durée de la session. Il répond aux
   questions et rédige un pré-briefing dans la conversation si vous le demandez. **Aucun fichier n'est
   écrit** tant qu'un scénario n'est pas explicitement validé.
2. **Construire.** Une fois le scénario choisi, il bâtit la mission — un groupe par vol de l'ATO, les
   objectifs en zones de combat actives au démarrage, une seconde phase enchaînée, une QRA pour les
   chasseurs qui « pourraient décoller après la frappe » — et un briefing PPTX et/ou PDF sur le modèle
   VEAF de *Deep Strike Palmyra*. Coordonnées, fréquences et plan de vol y sont relus dans la mission
   construite, pas recopiés du scénario.

Ce qui a été ajouté pour qu'une telle mission tienne debout :

- **Une opération se termine.** Elle annonçait déjà « Operation … is over » à la fin de sa dernière
  zone, mais `active_at_start` était ignoré sur une opération : elle ne démarrait que par le menu F10.
  Elle est maintenant activée au démarrage comme une zone, et l'action prévue à sa fin, qui n'était
  jamais appelée, s'exécute après le message.
- **Un objet de la carte peut être un objectif.** Une zone ne comptait que ce qu'elle avait fait
  apparaître : un pont ou un bâtiment du décor ne pouvait pas être une cible.
  `combat_zones[].scenery_targets: [<id>, …]` fait attendre à la zone la destruction de ces objets.
  Leurs identifiants n'existent que dans DCS : `.\veaf-tools.exe dcs scenery-objects <théâtre>
  --around x,y` liste les objets autour d'un point, avec leur identifiant, leur type et leur distance.
- **Une zone avec un objet statique se termine enfin.** DCS continue de renvoyer un statique après sa
  destruction, et la zone le comptait encore : une zone qui contenait un statique ne se terminait
  jamais, et son rapport F10 continuait de lister la cible détruite.
- **L'altitude du sol, sans DCS.** `.\veaf-tools.exe dcs terrain-sweep <théâtre>` relève une fois
  l'altitude sur toute la carte, et l'assistant s'en sert ensuite pour l'altitude des cibles d'un
  briefing, le plancher d'une route en basse altitude, et ce que chaque SAM ou radar voit de chaque
  tronçon par-dessus le relief. C'est le terrain seul : ni bâtiments, ni pylônes, ni arbres, et chaque
  réponse le rappelle.

---

## ✈️ Les intercepteurs ont une mission

**Constaté sur le Tacview de *Ligne rouge d'At Tanf*** : la QRA Sayqal a décollé trois fois et n'a
intercepté personne. Son groupe n'avait qu'un point de route et aucune tâche ; l'avion arrivait au
bout de sa route en apparaissant, et se posait quatre minutes et demie plus tard.

Désormais, un groupe `CAP` ou `Intercept` déployé par une QRA ou une vague **défend sa zone** : il
tourne en hippodrome au-dessus d'elle, dans l'axe d'où il arrive, et engage ce qui y entre. Un groupe
au parking ou sur la piste décolle et monte à 27 000 ft avant. À chaque build, l'outil dit ce que fera
chacun de ces groupes : patrouille donnée, route volée telle qu'écrite, ou route écrite à la main qui
sera remplacée (avertissement, que `validate` donne aussi).

Les `-cap` posés par marqueur en profitent aussi :

- **Un `-cap` ou un `-afac` partait sans aucun point de route** depuis la 6.18.0 : aucune CAP ne
  patrouillait, aucun AFAC ne tournait.
- **Une CAP ne perd plus sa patrouille après un combat**, et n'empile plus un ordre d'attaque par
  cible toutes les dix secondes. Elle cesse la poursuite quand elle quitte sa zone.
- **Un `-cap` restait en armes libres** et suivait la route du marqueur au lieu de la sienne : ses
  réglages sont maintenant respectés.
- **Un `-cap` rouge ne sort plus en F-15C** (#240) : il pioche dans les modèles de son camp, et dans
  les modèles neutres. `-cap mig` reste sur des MiG.
- **Un avion avec un rôle n'apparaît plus dans les arbres** : il est placé, et patrouille, au moins
  150 m au-dessus du sol.
- Le `capradius` d'un `-cap` est en **milles nautiques** (60 par défaut) : la documentation donnait
  `capradius 20000` en exemple, soit une zone de 20 000 NM. Elle donne maintenant `capradius 20`.

---

## 📻 Des fréquences d'aérodromes qui sont celles de DCS

Les fréquences d'aérodromes livrées avaient dérivé de DCS : Sanliurfa sur 251.6 au lieu de 252.7, 13
des 21 aérodromes du Caucase absents, quatre théâtres sans rien. Elles sont maintenant **relevées dans
DCS** même — 396 aérodromes sur sept théâtres, avec leur TACAN.

- `.\veaf-tools.exe content airfield-channels` liste les aérodromes utilisés par une mission (camp,
  slots dynamiques, appareils au parking) avec leurs fréquences DCS, et `--apply` écrit ceux que vous
  choisissez dans la collection `bases` de la mission. Un aérodrome que DCS ne déclare pas est refusé.
- Le nom d'aérodrome que vous avez écrit est conservé : « Büchel » ne devient plus « Buchel ».
- L'assistant fait la même chose (`describe_airfield_channels` / `set_airfield_channels`), et choisit
  les fréquences des AWACS, ravitailleurs et porte-avions **hors de la bande des tours** : sur le
  Caucase, les 21 tours occupent tout de 250.0 à 270.0, et Magic 1 tombait sur la fréquence de
  Nalchik.

---

## 🚁 Des hélicoptères posés par marqueur, avec une mission

`_spawn unit` et `_spawn group` posent maintenant un hélicoptère au marqueur, moteur coupé (#164) —
le premier refusait tout aéronef, le second en faisait un avion que DCS refusait. Une option `task`
lui donne un travail :

| `task` | Ce qu'il fait |
|---|---|
| `orbit` | tourne au-dessus du marqueur |
| `transport` | vole jusqu'à `dest` et se pose dans la clairière la plus proche |
| `patrol` | boucle (armé) ou fait la navette en se posant à chaque bout (non armé) |
| `attack` | attaque à `dest` |
| `escort` | couvre un groupe terrestre |

`alt` (en pieds au-dessus du sol) et `speed` (en nœuds) l'ajustent. Huit raccourcis sont livrés :
`mi8`, `mi26`, `uh1`, `ch47` non armés, `mi24`, `ka50`, `ah64`, `gazelle` armés. Tous ont été vérifiés
en jeu. Un `dest` en pleine forêt laisse l'hélicoptère en stationnaire à sa lisière. Les avions
restent refusés.

---

## 🛠️ Ce que l'assistant sait faire de plus

Tiré de la construction des Open Training Syria, Caucase et GermanyCW :

- **Charges par nom** : `add_air_group`, `create_qra` et `create_cap_mission` acceptent une charge DCS
  par son nom (613 charges, listées par `list_payloads`).
- **Portée des armes et des radars** de chaque type d'unité, telle que DCS la donne.
- **Drones laser** : `add_air_group` avec la tâche `AFAC` construit un MQ-9 qui tourne, carburant
  illimité.
- **Contrôles qui manquaient** : un ravitailleur qui recevait l'indicatif d'une autre famille
  (`Shell11` au lieu de `Texaco2`), des CLSID mal écrits sur 16 avions, une QRA dont certains groupes
  n'auraient jamais décollé, une escorte sans armes, un véhicule à la mer ou un navire à terre : tout
  ça est maintenant corrigé ou signalé.
- **Le prompt Open Training** tient compte de ce que les premiers vols ont appris : pas de longue
  portée dans une zone d'entraînement (la famille SEAD était à 24 minutes de la base la plus proche),
  un contour F10 pour chaque zone, des étiquettes F10 lisibles, un briefing pilote en français.
- **Deux porte-avions** : une mission générée avec un groupe aéronaval a toujours le Stennis et le
  Roosevelt, chacun avec ses fréquences.
- **`geocode`** ne se fait plus bannir par Nominatim : une requête par seconde.

---

## 🧭 Et encore

- **Le menu radio CSAR est de retour sur les hélicoptères en slot dynamique** (#989). Il manquait
  depuis la 6.18.0 ; le sauvetage, lui, fonctionnait.
- **Les fumées et fusées de couleur demandées par marqueur fonctionnent à nouveau**, ainsi que celles
  de `-farp` et d'un convoi. DCS les refusait toutes.
- **`_spawn signal, color …` tire la couleur demandée** : `red` (par défaut), `green`, `white` ou
  `yellow`. `orange` et `blue` sont refusés avec un message.
- **Une vague AIRWAVES qui échoue à se déployer ne fige plus sa zone** pour le reste de la mission.
- **La défense aérienne d'une zone de combat quitte le réseau Skynet** quand la zone est désactivée ;
  le réseau gardait jusqu'ici un site de plus à chaque désactivation.
- **L'escorte d'une FARP en terrain dégagé reste à sa place**, et une `-farp` en pleine forêt est
  refusée avec « no clear ground for its escort » au lieu de poser l'escorte sous les arbres.
- **Activer une mission de combat par un nom inconnu** affiche un message au lieu d'une erreur Lua.
- **Une variante `clearsky` annonce le ciel qu'elle vole** : son `${METAR}` décrit la météo plafonnée,
  et non plus le bulletin publié.
- **14 modèles d'apparition livrés** étaient rangés sous des pays réels (USA, France, URSS) : une
  mission où la France est rouge finissait avec la France des deux côtés (#985). Ils sont passés sous
  `CJTF Blue` / `CJTF Red`.
- **Le rayon logistique d'un aérodrome** : à Ramstein, un C-130 se gare à près de 1 km de la zone de
  250 m. Les guides disent maintenant de monter `airbase_logistics_radius` (1 100 m pour Ramstein).
- **CTLD 2.0.0-rc12** : un pilote qui reprend un slot n'hérite plus de l'état de vol du précédent, et
  une zone d'extraction peut se déclarer par une zone de déclenchement nommée
  `EXZ_<nom>_<drapeau>_<fumée>`.

---

## 📜 `veaf-logs`

- **La fenêtre s'ouvre en 2 s au lieu de 10** : les onglets distants se rouvrent après coup, un par
  un, à leur place.
- Son rapport de diagnostic donne enfin **la vraie version** au lieu de `unknown`.

---

## 🙏 Contributions

Merci à tous les copains de la VEAF qui ont volé sur les missions Syria, Caucase et *Ligne rouge
d'At Tanf*, et qui ont rapporté ce qui n'allait pas. Presque tout ce qui est corrigé ici a été trouvé
en vol.
