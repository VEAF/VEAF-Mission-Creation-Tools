# VEAF Mission Creation Tools — 6.16.0

**Corrections et améliorations.**

Quarante-sept versions correctives se sont accumulées depuis la 6.15.4 ; les voici rassemblées.
Il y a de vraies nouveautés — le réglage du tir d'artillerie, un brief d'accueil au décollage, les
coordonnées au format que DCS affiche — mais la majeure partie du travail a consisté à corriger des
choses qui ne fonctionnaient pas, souvent sans le dire.

**Cinq de ces défauts ont été trouvés en vol, pas par les tests.** Un `-tacan` qui n'annonçait rien,
un brief météo qui ne partait jamais, des commandes d'artillerie sans réponse : rien de tout cela
n'apparaissait dans une suite de tests verte. Si vous voyez quelque chose qui ne se comporte pas comme
la documentation le dit, dites-le — c'est ce qui a produit la moitié de cette version.

---

## ⚠️ À lire avant de mettre à jour

Quatre changements peuvent modifier le comportement de missions qui fonctionnaient déjà.

### Vos coordonnées en degrés-minutes-secondes se déplacent de 31 mètres

Le lecteur de coordonnées perdait exactement une seconde d'arc sur chaque valeur en
degrés-minutes-secondes, **depuis 2021**. `N42:30:15` était lu comme 42,5038889° au lieu de
42,5041667° — une trentaine de mètres vers le sud.

Ce lecteur est le seul du projet : il sert les zones AirWaves, les cibles d'artillerie, les points
nommés, les QRA et les alias. **Si vous avez compensé ce décalage à la main**, en décalant vos
coordonnées pour que les objets tombent au bon endroit, vos positions bougeront de 31 mètres. Les
coordonnées décimales et le MGRS n'étaient pas touchés.

### Une option de marqueur mal orthographiée est maintenant refusée

Elle était ignorée en silence dans toutes les commandes sauf `_spawn`. Une mission dont les marqueurs
contiennent une coquille pouvait donc « marcher » depuis toujours, en appliquant simplement les valeurs
par défaut. Ces marqueurs vont désormais être refusés, et la coquille nommée à l'écran.

### Le validateur refuse davantage de missions

Il refuse maintenant les missions que l'éditeur de DCS refuse lui-même d'ouvrir. C'est une bonne
nouvelle sur le fond — mieux vaut l'apprendre à la construction qu'en jeu — mais une mission qui se
construisait peut être rejetée.

### L'injection de waypoints atteint désormais tous les slots

Elle n'en atteignait **qu'un sur 105**. Les 104 autres étaient silencieusement ignorés. Vos missions
existantes vont voir leurs plans de vol apparaître là où ils étaient absents, et un waypoint de
bullseye ajouté par coalition.

---

## Artillerie : le réglage du tir

Une batterie retient le dernier point qu'elle a visé, et un nouvel ordre `correct` décale ce point.

```
_ground set, name arty-1                     (marqueur posé sur la batterie)
_ground order, name arty-1, order aim; target 37T FH 73551 47565
_ground order, name arty-1, order correct; correction 09050
_ground order, name arty-1, order fire
```

La correction s'écrit comme l'artillerie l'écrit : **trois chiffres de cap vrai, puis la distance en
mètres**. `09050` vaut cinquante mètres à l'est. Les corrections se cumulent, et un tir d'efficacité
sans coordonnées tombe au point corrigé.

Une correction illisible, ou adressée à une batterie sans tir en cours, est **refusée et annoncée** —
tirer sur le seul décalage mettrait les obus là où la batterie se trouve.

## Les coordonnées telles que DCS les affiche

`37T GG 12345 12345`, recopié de la carte F10 avec ses espaces, est accepté tel quel : plus de préfixe
`u`, plus de retranscription. Le nombre de chiffres est la précision, de 10 km à deux chiffres par côté
jusqu'au mètre à cinq. Un nombre **impair** de chiffres est refusé plutôt que deviné.

Les degrés-minutes-secondes acceptent maintenant les espaces et les symboles `°`, `'`, `"`, en plus des
`:` et `-` qui marchaient déjà. Les degrés et minutes décimales des cartes aéronautiques
(`N42:30.5E041:45.5`) sont lus correctement.

Et une coordonnée écrite longitude d'abord est **refusée** au lieu d'être silencieusement transposée :
`E041N42` revenait avec les deux valeurs inversées.

## Un brief au moment où vous prenez votre appareil

Cinq secondes après avoir occupé un slot, vous recevez la météo et **la piste en service**, déduite du
vent. Sur un porte-avions, pas de piste : le navire annonce son **cap actuel**, comme il le fait déjà
quand il se met au vent.

Un créateur de mission qui écrit son propre briefing peut le désactiver.

## Balises, treuil et CTLD

- **`-beacon`** pose une balise radio VHF/UHF/FM par CTLD, depuis un simple marqueur, et annonce ses
  fréquences.
- Un **game master** peut couper et remettre le treuil de CTLD depuis le menu radio, pour tout le monde
  à la fois.
- **`-tacan`** annonce enfin son canal, sa bande et son indicatif. Il ne disait strictement rien : la
  balise apparaissait, et le pilote n'avait aucun moyen de savoir sur quoi se caler.
- Le CTLD embarqué était épinglé **quatre versions candidates en retard** du fichier qu'il décrivait.

## Convois, zones de combat, sanctuaires

- Un **convoi** peut recevoir un itinéraire, le parcourir seul, et prendre des ordres en route.
- Une **zone de combat** signale à nouveau les groupes hors de combat, disperse ses groupes, peut
  conserver les noms d'origine de ses unités, et accepte une **plage** de valeurs dans ses étiquettes
  numériques — lesquelles comptent désormais où qu'elles soient écrites.
- Les **défenses d'une zone sanctuaire** ne se déployaient pas : elles levaient une erreur Lua. Depuis
  2021, et invisible parce que l'option qui les déclenche est désactivée par défaut.
- Une **défense rapprochée** ne garde plus un site qui ne peut plus se battre.

## CSAR

- Un pilote abattu n'apparaît plus dans l'eau.
- Une mission qui configurait `csar.csarMode` recevait une erreur Lua au lieu de la sanction demandée.
- La réponse du CSAR donne maintenant sa géométrie, pas seulement son verdict.

## Météo

- Un briefing peut afficher la météo avec laquelle la mission a été construite.
- Une variante météo ne déclarant qu'un `airport_icao` n'avait jamais sa météo injectée.
- Le METAR en direct est récupéré une fois, pas deux.

## Waypoints et plans de vol

- L'injection atteint tous les slots humains, et non plus un sur 105.
- Le **bullseye** de la mission est injecté comme waypoint, par coalition.
- Le plan de vol **le plus spécifique** gagne, au lieu du premier déclaré. La priorité décrite dans la
  documentation n'existait pas dans le code.

## Ce qui ne se taira plus

Une longue série de refus qui n'en étaient pas : ils ne faisaient rien, sans un mot, et rien ne
permettait de distinguer « la commande est mauvaise » de « le module est cassé ».

- **Huit commandes `_ground`** ne répondaient pas. Un pilote automatique dont le nom n'existe pas, un
  marqueur posé à plus de 250 m du groupe, un texte d'ordre illisible : silence complet. Chaque réponse
  dit maintenant **quoi faire** — la commande qui crée le pilote automatique, l'option `groupname`, la
  liste des ordres valides.
- Un **alias qui contourne le mot de passe** n'était plus autorisé à parler. C'est ce qui rendait
  `-tacan` muet : « cette commande n'a pas besoin de mot de passe » et « ne rien dire au pilote »
  étaient le même réglage dans le code. Un pilote qui pose un marqueur reçoit toujours une réponse ; un
  script n'inonde jamais personne.
- Un **marqueur avec du texte** répondait « votre commande a échoué » quoi qu'il arrive.
- Une **option mal orthographiée** est nommée, dans toutes les commandes.
- Un joueur qui **quitte son slot** n'est plus enregistré dans une unité appelée `nil`.

## Divers

- Un `-farp` posé près d'une FARP existante ne pose plus son escorte sur cette plateforme, et la
  décision de placement est journalisée.
- Un peloton bleu de la guerre froide tirait dans une liste dont **une entrée sur trois** ne créait
  rien. Les blindés Currenthill peuvent apparaître.
- Six commandes radio de convoi étaient chacune seule dans son propre sous-menu.
- Un déclencheur d'interpréteur que le monde ne rend pas se déclenche quand même.
- Une plage numérique ouverte ou inversée ne lève plus d'erreur.
- La référence d'API documentait le contraire du défaut réel.

---

## Remerciements

À ceux qui volent avec ces outils et qui disent quand quelque chose ne va pas. Cinq défauts de cette
version viennent de là, et aucun n'aurait été trouvé autrement : nos tests étaient verts pendant que le
TACAN se taisait, que le brief météo ne partait pas et que l'artillerie ignorait les ordres.
