# VEAF Mission Creation Tools — 6.25.0

**Cette version a été écrite en construisant une mission.** Nous avons repris *Open Training Germany
Cold War* à partir d'un dossier vide, avec les outils, comme le ferait n'importe quel créateur de
mission — et nous avons noté chaque chose qui ne marchait pas. Presque tout ce qui suit vient de là :
des fonctions qui écrivaient dans un fichier que DCS ne lit pas, des avions posés dans l'herbe, des
batteries entières qui disparaissaient à l'apparition.

L'autre moitié vient de DCS lui-même, mesurée en vol le 25 septembre : là où nos véhicules se garent
réellement quand on leur demande d'éviter les arbres.

> ### ⚠️ Ce qui change dans vos missions existantes
>
> **1. Le vent de vos variantes météo souffle peut-être à l'envers.** La météo des variantes n'a
> jamais atteint DCS (voir plus bas) : elle était écrite dans une table que le jeu ignore. Maintenant
> qu'elle arrive vraiment, une erreur d'orientation restée invisible devient visible. Si votre
> `versions.yaml` a été converti depuis la v5 par une version précédente, ses `weather.wind_direction`
> écrits à la main désignent la direction **vers laquelle** le vent souffle, au lieu de celle d'où il
> vient.
>
> Deux façons de corriger, au choix : relancer la conversion, ou **ajouter 180° à chaque valeur**.
> Les variantes qui lisent un `airport_icao` ne sont pas concernées.
>
> **2. Une mapping dans un bloc `settings:` arrête maintenant le build.** Jusqu'ici, écrire un bloc
> à clés sous `settings:` produisait une chaîne de caractères inerte côté Lua : ça ne faisait rien,
> et ça ne le disait pas. Le build refuse désormais, en nommant le réglage. C'est le but — mais une
> `mission.yaml` qui en contient une devra la déplacer dans `mission-script.lua`.
>
> **3. `-samLR` n'est plus ce que son nom laissait croire.** Décrit comme « longue portée » depuis
> 2020, il a toujours tiré un Roland, un Hawk, un Osa ou un Tor. Il continue exactement pareil —
> seule sa description change, en *moyenne portée*. Si vous vouliez vraiment du longue portée, c'est
> le nouveau **`-samVLR`** qu'il vous faut.

---

## 🌲 Vos véhicules ne se garent plus dans les arbres

Jusqu'ici, une batterie SAM posée en forêt y restait. Pire : ce que nous croyions être un correctif
n'avait jamais rien déplacé du tout. Mesuré sur 20 véhicules réellement coincés sous les arbres :
**25 emplacements proposés, 25 valides, 0 retenu, 0,0 m de déplacement.**

La cause est une particularité de DCS qu'il fallait mesurer pour la voir. Quand on lui demande un
emplacement dégagé dans un rayon de 50 m, il répond entre 52 et 171 m — médiane 130. Le rayon demandé
ne veut rien dire. Le filtre qui vérifiait « la proposition est-elle bien dans le rayon ? » rejetait
donc tout, systématiquement.

Et le corriger en desserrant ce filtre n'aurait pas marché non plus : **l'espacement naturel d'une
batterie SAM est de 20 à 27 m**, et le point le plus proche que DCS sache proposer est à 52 m. Déplacer
chaque véhicule séparément aurait éclaté la formation d'un facteur 2 à 5 — une batterie en fleur.

Le groupe est donc déplacé **d'un bloc** : on demande une clairière assez large pour l'empreinte
entière, puis on applique le même décalage à tous les véhicules. Les distances entre eux sont
inchangées par construction.

Sur 31 groupes en faute, **30 sont entièrement résolus** et les véhicules sous les arbres passent de
**132 à 2**. Les six pires — les S-300 de Wittstock et Borkenberge, trois autres S-300 et un SA-11 —
passent de 8 à 13 véhicules sous les arbres à zéro.

Le déplacement est borné à 1 000 m (les besoins mesurés vont de 100 à 800 m). **Ce que vous avez placé
dans l'éditeur de mission n'est jamais déplacé**, et les convois sont exempts pour qu'ils ne quittent
pas leur premier point de passage.

### Une zone de combat sur un pont

Sur 25 zones de combat, une seule ne faisait rien apparaître : son convoi est sur un pont, et DCS
rapporte la nature du sol **sous** le pont, c'est-à-dire de l'eau. La zone se comportait correctement
— aucun point acceptable à proximité, donc elle gardait la position déclarée — mais un second contrôle
en aval jugeait cette position invalide et supprimait le groupe entier.

Le principe qui tranche est celui posé en août : **on refuse ce qu'une commande fait apparaître**, parce
qu'il y a quelqu'un pour lire le message ; on ne refuse jamais ce que le créateur a placé dans
l'éditeur, parce qu'il n'y a personne. Un `-teleport` sur un lac refuse toujours.

### Une régression corrigée dans la foulée

Entre-temps, un correctif intermédiaire faisait disparaître des groupes entiers : quand un véhicule
était effectivement déplacé, son cap était perdu en route, ce qui plantait l'apparition en silence.
**11 erreurs, 6 zones vides** sur une seule partie. C'est réparé, et une protection empêche qu'un cap
manquant puisse à nouveau tout emporter.

---

## 🌦️ La météo et l'heure de vos variantes fonctionnent enfin

Trouvé en construisant la mission depuis zéro : **toutes les variantes volaient sous le ciel de la
mission de base.** Sur Caucasus v6, `dawn-broken` et `dawn-overcast-rain` étaient identiques — même
preset, 20 °C, vent nul. La météo était écrite dans une table que DCS ne lit pas.

Elle écrit maintenant ce que le jeu lit réellement : un preset de nuages choisi d'après la couverture
et la base (dans la plage d'altitude que DCS accepte pour ce preset), la pluie, la température, le vent
au sol et en altitude, la visibilité, le brouillard, et le QNH tel qu'un METAR le donne. Le bloc
`weather:` accepte une nouvelle clé `precipitation`.

**Les heures solaires étaient calculées en UTC** alors que DCS lit l'heure de départ sur l'horloge du
théâtre. Toutes les variantes `sunrise…` démarraient donc 2 à 4 heures trop tôt — 01h28 pour une aube
sur le Caucase. Elles utilisent désormais le décalage propre à chaque théâtre, la même table que les
scripts en jeu, qui gagne au passage GermanyCW à UTC+2 (mesuré dans DCS).

**La météo réelle n'avait jamais fonctionné** : la récupération lisait des informations qui n'existaient
pas et retombait silencieusement sur les valeurs par défaut à chaque fois — et l'exécutable ne
contenait même pas la table des stations. Chaque variante qui retombe sur les défauts est maintenant
nommée, et le build dit combien il y en a eu.

---

## 🛬 Les slots dynamiques : navires, FARP, et des identifiants qui se marchaient dessus

**Les slots dynamiques ne fonctionnaient pas sur les navires ni les FARP.** DCS tient deux tables
distinctes — les aérodromes d'un côté, les navires et FARP de l'autre — et l'outil n'a jamais parcouru
que la première. Mesuré sur une mission complète : les aérodromes finissaient avec 832 liens tous
valides, pendant que les **41 navires et FARP gardaient 69 liens dont pas un seul** ne désignait un
groupe encore présent. DCS affiche ça *Group template: None*. Pour un appareil embarqué, c'était toute
l'histoire.

Chaque objet reçoit maintenant ce qu'il peut réellement accueillir, lu dans la base d'unités plutôt que
deviné : un porte-avions prend avions et hélicoptères, un porte-hélicoptères ou un héliport prend les
hélicoptères, et un navire sans pont d'envol est laissé tranquille. Deux clés facultatives, `ships:` et
`farps:`, permettent de les viser nommément. Même mission après correction : **40 objets configurés,
705 liens valides, 0 lien mort.**

**Et les identifiants se télescopaient.** Les catalogues livrés vivent dans les petits numéros pendant
qu'une vraie mission dépasse 3 800 : les deux se chevauchaient par construction. Mesuré : 6 identifiants
de groupe et 11 d'unité en double après injection. La conséquence n'est pas une erreur — c'est **un
type d'avion qui cesse silencieusement d'être proposé** en slot dynamique. Les identifiants sont
désormais vérifiés contre la mission d'accueil et réattribués **uniquement en cas de collision**, pour
qu'une reconstruction ne déplace pas ce qu'elle avait déjà attribué. Une mission vierge ne reproduit
rien de tout ça — ce qui explique que ce soit passé inaperçu.

### Un nouveau gabarit vous parvient enfin

`prepare` recopiait les catalogues dans chaque dossier de mission, et le build ne lisait que cette
copie — gelée au jour de la création du dossier. **Un dossier préparé en juin garde ses 104 gabarits
pour toujours**, et le `F-14BU Template` ajouté le 21 septembre ne lui parvient jamais, quelle que soit
la fréquence des mises à jour.

`prepare` écrit maintenant un catalogue vide, et le build résout le fichier de la mission s'il contient
au moins un groupe, sinon le catalogue livré — en disant lequel il a pris. Un dossier qui possède déjà
son catalogue n'est pas touché : **rien n'est jamais fusionné dans votre fichier à votre insu.** Pour
récupérer les nouveautés, une commande explicite :

```powershell
.\veaf-tools.exe content pull-aircraft-groups
```

Elle liste ce que le catalogue livré a et que le vôtre n'a pas ; `--add "<nom>"` ou `--add-new` copie ce
que vous choisissez, sans jamais remplacer une entrée que vous possédez déjà.

### Le build dit ce qu'il a obtenu, pas seulement ce qu'il a écrit

Deux situations qui ne cassent rien et laissent les slots inutilisables sont maintenant signalées :
un lien de gabarit qui ne pointe sur rien (65 cas distincts sur une mission de test), et des gabarits
qui n'ont **nulle part où être proposés** — une mission sortie tout droit de `prepare` injecte 128
gabarits et configure 0 aérodrome, puisque tous les aérodromes d'une mission vierge sont neutres. Aucun
slot dynamique n'était jouable, et le build passait dessus en silence.

---

## 🎚️ Les défenses aériennes suivent l'époque

Une mission `COLD_WAR` ne reçoit plus les matériels entrés en service après 1980 — l'armement terrestre
suivait déjà cette règle, les défenses aériennes non. Les groupes de `-sam`, `-samSR`, `-samLR` et
`-aaa` ont maintenant des variantes par époque, et les escortes de `_cas`, `-armor`, `-convoy`…
échangent Avenger, Linebacker, Tor, Tunguska, HQ-7 et Igla-S contre leurs prédécesseurs.

Une mission **WW2** reçoit de la flak, et rien d'autre : plus aucune escorte. Auparavant, les escortes
testaient un réglage que les missions v6 ne posent jamais, si bien qu'**une section WW2 arrivait avec
des SAM modernes**.

### `-samVLR`, la vraie longue portée

Nouveau raccourci. Selon l'époque de la mission, il place un SA-10 ou un SA-5 (rouge moderne), un
Patriot (bleu moderne), un SA-2 ou un SA-5 (rouge Guerre froide), un Hawk (bleu Guerre froide — rien de
plus long n'existait avant 1984), ou la flak la plus lourde en WW2.

Le tirage à ±1 d'un niveau de défense est documenté : 60 % le niveau demandé, 20 % de chaque côté.

---

## 🧩 Trois niveaux de difficulté sur les mêmes objectifs, en une clé

Une zone de combat peut emprunter les éléments d'autres zones :

```yaml
includes: [zone-facile, zone-moyenne]
```

L'emprunt est transitif et l'ordre n'a pas d'importance : activer le niveau « difficile » d'un champ de
tir fait apparaître aussi le moyen et le facile, le désactiver les enlève, et son achèvement les
compte. Une zone inconnue arrête le build plutôt que de laisser un niveau discrètement incomplet.

Cela demandait auparavant du Lua dans `mission-script.lua` — et l'imbrication par préfixe de nom, que la
règle des préfixes semble pourtant suggérer, **ne peut pas marcher**, puisqu'une zone détruit au
démarrage les groupes qu'elle ramasse.

---

## 🤖 L'assistant IA construit des missions qui tiennent debout

C'est ici que la construction depuis zéro a fait le plus de dégâts — et le plus de progrès.

**Les avions étaient fabriqués avec le constructeur de véhicules terrestres** : au niveau du sol,
à 20 km/h, sans carburant ni armement, sur un point « hors route ». Une QRA au décollage apparaissait
donc dans l'herbe. Les QRA et les patrouilles sont maintenant construites en vol, ravitaillées, avec un
emport d'armes (`pylons`, ou `loadout_from` en copiant celui d'un autre groupe), et une patrouille à qui
l'on donne un second point vole un hippodrome au lieu de tourner dans le vide.

Un **objet statique** porte enfin la catégorie que DCS lit pour savoir de quoi il s'agit — il n'en avait
aucune — et un **navire** ne reçoit plus la tâche et la route d'un véhicule.

**Les vols de soutien, la date, le bullseye et le briefing** ne demandent plus de Lua écrit à la main.
Un ravitailleur fabriqué par l'assistant ravitaille réellement quelqu'un : les tâches ont été relevées
dans 401 missions réelles pour être écrites dans la forme que DCS attend — ravitailleur, AWACS, carburant
illimité, EPLRS, balise TACAN (canal, X/Y, indicatif, fréquence calculée comme les missions la stockent)
et escorte.

Le reste, en vrac : les FARP, la météo et la liste des aérodromes sont accessibles à l'assistant ; les
navires sont espacés de 600 m au lieu de 20 ; les sauvegardes automatiques vont dans un dossier dédié
(20 par fichier) au lieu de s'empiler à côté de la mission — jusqu'à 51 copies en une seule session ; et
quand une action échoue, l'assistant reçoit enfin le message d'erreur au lieu d'un laconique *Error
executing tool*.

### L'assistant connaît les pièges de DCS

Nouvelle capacité en lecture seule : l'assistant peut demander **les limitations connues des outils** et
**les comportements de DCS qui ne lèvent aucune erreur et sont faux quand même** — un groupe à activation
retardée que les scripts voient déjà, une heure de départ qui ne retarde pas une apparition en vol, un
site SAM sans radar de veille qui reste allumé en permanence… Chacun avec son symptôme, ce qu'il faut
faire, et ce qu'il a coûté. La liste correspond à **la version que vous avez installée** : une limitation
corrigée cesse d'être signalée à partir de la version qui la corrige.

### Une invite pour construire une mission Open Training complète

Collez `.prompts/new-open-training-mission.fr.md` (ou `.en.md`) au début d'une session d'assistant dans un
dossier vide. Elle donne les règles de conception — quelles bases, combien de soutien et de défense
aérienne pour la taille du front, trois familles de niveaux imbriqués, de vraies zones de combat, QRA et
patrouilles, la sécurité activée — et demande à l'assistant de signaler chaque manque qu'il rencontre.

---

## ⚙️ Configuration : ce qui était écrit et ne servait à rien

**Une liste écrite dans `settings:` arrive enfin en Lua sous forme de liste.** Écrire
`csarPrefix: ["helicargo", "MEDEVAC"]` produisait `csar.csarPrefix = "['helicargo', 'MEDEVAC']"` — du Lua
valide, une chaîne de caractères là où le script attend une liste, et pas le moindre avertissement.

**L'exemple de la documentation cassait CSAR.** Le guide montrait `csarPrefix: "MEDEVAC"` tout en activant
l'option qui parcourt cette valeur élément par élément — ce qui plante. Copier le bloc documenté suffisait
à casser le sauvetage en mission. L'exemple est corrigé, et un test compare désormais chaque exemple de la
documentation aux valeurs par défaut du script.

**Les 38 réglages de CSAR sont listés**, groupés par intention. Le guide en nommait 3, à titre d'exemple —
d'où la conclusion d'un créateur de mission que `csarOncrash`, `enableForAI` et `enableForRED` exigeaient
un bloc Lua. Il dit aussi clairement que `aircraftType` est **le seul** réglage que le YAML ne peut pas
atteindre.

**Les liens `# Doc:` de votre `mission.yaml` fonctionnent à nouveau.** Les neuf pointaient vers une vue qui
ne sait pas interpréter nos ancres, et sept visaient des titres qui avaient changé de nom depuis. Un
contrôle automatique vérifie maintenant chaque lien écrit dans un message.

---

## 📜 `veaf-logs` suit le journal d'un serveur à distance

*Fichier › Ouvrir un journal distant…* liste les couples `serveur › instance` déclarés dans un nouveau bloc
`servers:` de votre `~/veafmct.yaml` — une machine, plusieurs instances DCS, un `dcs.log` chacune. Le
journal est recopié localement en continu (seuls les octets nouveaux circulent), si bien que les filtres,
les règles, les profils et la restauration de session fonctionnent comme sur un fichier local. Un
redémarrage de DCS côté serveur relance l'onglet avec le nouveau journal.

**Authentification par clé uniquement** : l'outil ne demande ni ne conserve jamais de mot de passe. Une
empreinte d'hôte inconnue vous est montrée et mémorisée sur demande, comme le fait `ssh`.

`veaf-tools.exe` est inchangé.

---

## 💬 L'assistant de documentation répond au besoin, pas seulement à la question

Une question arrive emballée dans la solution que son auteur a déjà choisie, et l'assistant restait dans
cet emballage : interrogé sur la façon de simplifier un bloc Lua réglant trois booléens, il répondait
correctement sur le bloc Lua et ne disait jamais que **quatre lignes de `mission.yaml` remplacent le bloc
entier** — alors que l'extrait le disant était cité dans ses propres sources.

Il propose désormais la route la plus simple en premier, la montre, dit ce qu'elle remplace, et répond
quand même à la question posée. Uniquement quand un extrait l'affirme, jamais de sa propre initiative.
Vaut pour le widget du site, `veaf-tools ask` et Discord.

---

## 🙏 Contributions

Cette version est le travail de **Zip**. Les mesures en jeu qui l'ont guidée ont été faites sur
GermanyCW-v6 et Caucasus v6 les 21 et 25 septembre 2026.
