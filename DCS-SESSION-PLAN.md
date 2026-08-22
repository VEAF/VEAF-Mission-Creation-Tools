# Plan de session DCS — préparé le 2026-08-22

Tout est prêt et construit. Ce document est l'**ordre de passage** : il regroupe les vérifications par
mission pour que tu charges chaque mission une seule fois. Le détail de chaque item vit dans
[`DCS-SESSION-TODO.md`](DCS-SESSION-TODO.md) ; ici, seulement ce que tu fais et ce que tu regardes.

**Coche au fur et à mesure. Si tu t'arrêtes en route, dis-moi juste où tu en es.**

---

## Ce que j'ai préparé

| Fait | Pourquoi ça comptait |
|---|---|
| **Bundle de scripts régénéré** (`build/veaf-scripts.lua`) | Il datait du **19 août** et ne contenait **aucun** correctif de la journée. Construire les missions en l'état t'aurait fait tester le code de mardi — toutes les vérifications auraient été fausses sans que rien ne le dise. |
| **`VerifyMissionA_noon.miz` reconstruite** | `test/veaf-tools/verify-mission-a/missions/` |
| **`VerifyMissionC_noon.miz` reconstruite** | `test/veaf-tools/verify-mission-c/missions/` |
| **Vérifié que les deux `.miz` embarquent le code du jour** | Les six symboles neufs sont bien dedans (`resolveCsarSurvivorPoint`, `isGroupCombatEffective`, `offsetWP1`, `referencePositionOf`, `advanceConvoy`, `CSAR_SURVIVOR_SEARCH_RADIUS`). |

Les deux missions sont en `security.disabled: true` et en slots parking, moteur froid.

---

## Étape 0 — ✅ fait, et le résultat est plus intéressant que prévu

Trois **SA-15 (Tor 9A331)** rouges sur une carte nue, sans aucun script, alarme rouge, ROE ouvrir le feu :
**ils lockent et ils tirent.**

Mais ta version est **la même** que celle où Sharko a reproduit le bug — 2.9.28.26385, rien n'a été patché
entre les deux. Donc ce n'est pas « DCS a été réparé ». Ce qui est établi est plus étroit :

| Prouvé | Toujours ouvert |
|---|---|
| Un SAM qui embarque son propre radar de tir engage | Un **site multi-unités**, dont les lanceurs dépendent d'un radar séparé, n'est pas testé |

Le Tor n'a besoin de rien ; un `Kub 2P25 ln` ne peut pas tirer sans son `Kub 1S91 str`. Sharko a dit
« 3 sams sur une carte » sans préciser lesquels — s'il avait posé des sites incomplets ou des lanceurs
seuls, ça ressemblerait exactement à une panne générale de DCS.

**Conséquence : les items 11 et 16 sont débloqués, et l'étape 2c devient un test à double lecture.**
`VerifyMissionC` fait justement tourner un SA-6 complet, donc elle exerce la famille non testée.

---

## Résultats de la session — au 22/08

| Vérification | Résultat |
|---|---|
| 0 · SAM autonome (Tor) | ✅ locke et tire — voir la nuance sur les sites multi-unités ci-dessus |
| 1a · dispersion + départ sans détour | ✅ tout comme prévu |
| 1b · escorte du FARP | ❌ **échec** — tout se pose sur le FARP statique. Cause racine trouvée, lot rouvert, voir ci-dessous |
| 1c · convoi sur itinéraire | ✅ les commandes fonctionnent. Réserve d'ergonomie : chaque commande est enfermée dans un sous-menu à un seul élément |
| — · un marqueur simple renvoyait une erreur | ✅ **corrigé**, PR #789 — onze jours de régression, sans lien avec la session |
| 2a · `#command` retardé meurt avec sa zone | ✅ |
| 2b · menu porte-avions côté rouge | ✅ |
| 2c · le SA-6 | 🔎 locke, lève, se rétracte, 5 fois, sans tirer — **mon hypothèse DCS est morte**, voir ci-dessous |
| 2d · alarme par nature | ✅ pour ce qui était testable : le convoi roule. Les chars n'ont **qu'un waypoint** dans la mission C, donc aucune route — leur immobilité est la donnée, pas un défaut |

### 2c — pourquoi ton observation tue l'hypothèse DCS

J'avais annoncé qu'un SA-6 muet serait « la vraie forme du bug DCS ». C'est faux, et c'est ton
observation qui le montre : un site qui **acquiert, oriente ses lanceurs et lève ses missiles** n'est pas
un site que DCS empêche de fonctionner. C'est un site qu'on **éteint** entre l'acquisition et le tir.
Cinq cycles propres, c'est une boucle de contrôle, pas un engagement cassé.

Et cette boucle, c'est Skynet : `goLive()` / `goDark()` sont appelés depuis `setActAsEW`,
`resetAutonomousState`, `goAutonomous`, et depuis la **défense HARM** — qui fait plonger un site sur une
*probabilité* par type (30 à 90 % dans la base). Donc c'est très probablement chez nous.

Le test qui tranche, et il coûte 5 minutes : un **SA-6 complet** sur carte nue, sans aucun script, alarme
rouge, ROE ouvrir le feu — exactement la forme de ton test des SA-15.

- **Il tire** → Skynet éteint le site en pleine action. À nous, et la défense HARM est le premier suspect.
- **Même cycle** → c'est DCS après tout, et propre aux sites dont le radar de tir est un véhicule séparé.
  Ce qui expliquerait aussi le rapport de Tripack sur les SAM muets en zone.

Note pour 2c lui-même : les checks 6 et 7 ne lisent **pas** un tir, ils lisent les compteurs affichés à
l'écran (`group added`, `delayedActivate`, `RED IADS REACTIVATED`). C'est ça leur verdict. Le tir était
mon ajout, et il a fait dériver la lecture.


### 1b — pourquoi ça a échoué, et ce n'est pas mesurable autrement

Deux causes, toutes deux lisibles dans le code, et la seconde aurait survécu à un correctif de la
première :

1. **Un FARP n'est pas un objet statique.** `isSpotOccupied` sonde `world.searchObjects` sur `UNIT` et
   `STATIC` seulement. Le dépôt lui-même montre ce qu'est un FARP : une **airbase**
   (`Airbase.Category.HELIPAD`, cf. `veafAirbases.lua:191`), et le log DCS le confirme —
   `NO ATC COMM HELIPAD + StaticFarpAlpha-1`. La sonde ne pouvait pas voir le seul objet qui compte.
2. **`searchObjects` compare des positions, pas des emprises.** La tolérance est de **12 m** et un FARP
   fait plusieurs dizaines de mètres : une escorte posée sur son **bord** — le cas exact de #232 — laisse
   le centre du FARP largement hors de la sphère.

Les tests unitaires simulaient `isSpotOccupied`, donc ils prouvaient que la recherche de cap réagit à un
emplacement occupé, sans que rien ne prouve qu'un vrai FARP en soit un. Un test juste sur une prémisse
fausse.

### 1c — le sous-menu à un seul élément

Ta remarque est fondée, et la convention est **gratuite** : `veafCarrierOperations` met plusieurs
commandes `USAGE_ForGroup` dans un même sous-menu, et `convoy_cleanup` s'ajoute directement à la racine
juste à côté. Rien ne l'impose. À noter : le motif **préexiste** au lot convoi — `convoy_mark`, plus
ancien, fait déjà pareil — donc les six commandes du menu sont à aplatir ensemble. Je le fais après tes
vérifications, pour ne pas te changer le terrain en cours de route.

---

## Étape 1 — `VerifyMissionA_noon.miz` (3 vérifications, une seule charge)

```
test/veaf-tools/verify-mission-a/missions/VerifyMissionA_noon.miz
```

> **Réparée et reconstruite le 22/08 après ton retour.** L'éditeur refusait de la sauvegarder :
> `SmokeZone-SmokeArmor` avait ses deux waypoints avec temps *et* vitesse verrouillés — le second point,
> ajouté hier, avait été copié du premier avec ses verrous. Corrigé à la source, `.miz` reconstruit,
> vérifié. Le balayage de **toutes** les routes des deux missions n'a trouvé que celle-là ; la mission C
> est saine. **Recharge le fichier**, celui que tu avais ouvert est l'ancien.

Prends le slot, roule ou décolle, puis tout se fait au marqueur F10 et au menu radio.

### 1a · ~~Le tag sur une seule unité du groupe~~ — retiré, le critère était faux

**Rien à faire ici.** Deux erreurs de ma part, trouvées par ton retour :

- La zone s'appelle **« Convoy Test Zone »** au menu radio. `SmokeZone` est son nom technique de zone de
  déclenchement, pas ce que tu vois. La correction vaut pour tout ce document.
- **« ils restent sur place » n'était pas la signature du tag.** `#alarm=2` se réduit à
  `setOption(ALARM_STATE, 2)` (`veaf.lua:2117`) ; rien dans notre code n'immobilise un groupe. Deux chars
  qui roulent est le comportement normal, tag lu ou pas — le test ne discriminait rien, quel que soit le
  résultat.

Ce que le jeu aurait ajouté : uniquement « DCS honore l'option », qui n'est pas notre code. La lecture du
tag est prouvée par des tests énumérés sur toute la famille des tags, tag posé sur la deuxième unité
(`test/lua/test_veafCombatZone.lua:1674` et `:1872`). Lot fermé sur cette base.

### 1b · Item 18 — la dispersion revenue, et le départ sans détour

Active **« Convoy Test Zone »** et regarde `SmokeZone-ConvoyBlue` et `SmokeZone-SmokeArmor` :

- [ ] **Les groupes sont éparpillés**, pas alignés sur leur position d'éditeur → le défaut de 50 m est
      bien réactivé.
- [ ] **Rien n'est dans le décor** — pas de camion dans un bâtiment, pas de char sur une pente qu'il ne
      peut pas quitter. L'ancrage `(-32220, 405386)` est du désert vide documenté, donc un échec ici
      serait une vraie surprise.
- [ ] **Le convoi part vers sa route sans revenir chercher un point derrière lui.** C'est le correctif
      #779 : avant, un groupe dispersé retournait à sa position d'éditeur d'abord. Ce détour serait
      l'indice que le correctif ne prend pas.
- [ ] Désactive puis réactive la zone : les groupes doivent réapparaître **à des endroits différents**.
      C'est le seul moyen de voir que la dispersion est vraiment aléatoire et pas un décalage fixe.

**À regarder en passant, nouveau d'aujourd'hui (#780) :** est-ce qu'un groupe apparaît à peu près sur sa
position dessinée, à la dispersion près, ou nettement plus loin ? Si tu veux tester le cas exact,
déplace un camion de `SmokeZone-ConvoyBlue` juste **en dehors** du cercle de la zone avant de lancer : le
groupe doit quand même apparaître là où il est dessiné.

### 1c · Item 14 — l'escorte du FARP

Deux marqueurs, dans cet ordre :

- [ ] `-farp` à **~150 m du FARP statique**. L'escorte doit être sur du terrain dégagé, plus sur les
      plateformes. `dcs.log` doit montrer `findClearBearing: moved from … to …`.
- [ ] `-farp` en **terrain complètement dégagé**, loin de tout. Ça doit ressembler exactement à avant :
      150 m sur le cap du FARP, **aucun message** dans le log. C'est la non-régression, et elle compte
      plus que le fix.
- [ ] Si le log dit `unknown FARP-like type [...]`, envoie-moi le nom du type.

### 1d · Un convoi qui suit un itinéraire

Pose trois marqueurs. Sur le premier, tape :

```
_spawn convoy, dest <2e marqueur>, dest <3e marqueur>, speed 40
```

Les libellés du menu F10 sont **exactement** ceux-ci — je te les donne au mot près, j'ai déjà perdu du
temps à te faire chercher un nom approximatif :

| Commande F10 | Ce qu'elle doit faire | Le message attendu |
|---|---|---|
| **Envoyer le convoi le plus proche au point suivant** | saute à l'étape suivante tout de suite | — |
| **Faire attendre les ordres au convoi le plus proche (au point suivant)** | il **termine son étape** et se gare là | « *… va terminer son étape et attendre les ordres à …* » puis, à l'arrivée, « *… est arrivé à … et attend les ordres* » |
| **Arrêter le convoi le plus proche sur place** | immobilisation immédiate, en pleine route | « *… s'arrête sur place* » |
| **Faire repartir le convoi le plus proche (après un arrêt)** | il reprend | « *… reprend sa route* » |

- [ ] Il part vers le 2e point, **puis repart seul** vers le 3e. La surveillance tourne toutes les 30 s
      et le rayon d'arrivée est de 150 m : laisse-lui une demi-minute après l'arrêt avant de conclure.
- [ ] Les deux commandes « attendre » et « arrêter » doivent se **sentir différentes en jeu**. Si ce
      n'est pas le cas, c'est le vocabulaire qu'il faut revoir, pas le code — dis-le-moi.
- [ ] Sur la **dernière étape**, « Faire attendre les ordres » doit répondre : « *… est sur la dernière
      étape de son trajet : il n'y a pas de point suivant où l'arrêter* ».
- [ ] À la fin du trajet : « *… a parcouru tout son trajet* ».
- [ ] En passant : si le convoi se gare **visiblement loin** de son point et compte quand même comme
      arrivé, le rayon de 150 m est à revoir. C'est le genre de chose qu'aucun test ne peut me dire.

---

## Étape 2 — `VerifyMissionC_noon.miz` (4 vérifications)

```
test/veaf-tools/verify-mission-c/missions/VerifyMissionC_noon.miz
```

**Prends un slot et vole** : le rôle « game master » ne voit pas les commandes `ForGroup`, donc la
plupart de ces vérifications lui sont invisibles (c'est la reproduction de #128, déjà actée).

### 2a · Item 12 — un `#command` retardé meurt avec sa zone

- [ ] Active la zone, attends que le groupe retardé apparaisse, puis **désactive la zone**. Le groupe
      doit disparaître avec elle. Avant #781, la zone ne l'enregistrait pas et il survivait.

### 2b · Item 13 — le menu porte-avions côté rouge

- [ ] Depuis un slot **rouge**, vérifie que tu ne vois **pas** les opérations du porte-avions bleu, et que
      tu vois les tiennes. C'est #87.

### 2c · Item 11 — Skynet, et au passage la vraie forme du bug SAM

> **Mission C reconstruite le 22/08, et sans ça ce check ne valait rien.** Son `dynamic_spawn` était
> réglé par une trappe (`module_settings:`) que le générateur écrase depuis le 20/08 : le fichier de
> config produit contenait `DynamicSpawn = true` ligne 19 **puis `= false` ligne 164**, juste avant
> `initialize()`. La mission tournait donc avec la fonctionnalité coupée, et les checks 6 et 7 auraient
> mesuré le comportement par défaut en le présentant comme un verdict. Réglé dans le bloc `SKYNET:`,
> reconstruit, vérifié : une seule affectation, `true`, juste avant `initialize`.
> Le silence du générateur est déposé comme lot à part.


Checks 6 et 7 du README de la mission C. **À faire**, puisque les SAM tirent — mais lis le résultat sur
deux plans, parce que cette mission utilise un **SA-6 Kub complet** : 4 lanceurs `Kub 2P25 ln` et
2 radars `Kub 1S91 str`. C'est précisément la famille que ton test au Tor n'a pas couverte.

- [ ] **Le SA-6 engage** → les checks 6 et 7 valent ce qu'ils disent, et on sait en plus que le bug SAM
      n'existe pas non plus sur les sites multi-unités. Le rapport de Sharko devient un faux positif à
      expliquer.
- [ ] **Le SA-6 reste muet alors que le Tor tirait** → tu viens de trouver la **vraie forme du problème** :
      il touche les sites dont le radar de tir est un véhicule séparé. C'est une information qui vaut plus
      que le check lui-même — dis-le-moi, ça rouvre le rapport de Tripack sur les SAM silencieux en zone de
      combat, qu'on avait classé « DCS est cassé pour tout le monde ».

Avant de conclure « muet », vérifie que le `Kub 1S91 str` est **vivant** : un site sans radar de tir ne
tire pas, et c'est le comportement correct. C'est exactement la question que répond
`veaf.isGroupCombatEffective`, livré aujourd'hui.

### 2d · Item 16 — l'état d'alerte par nature (⚠️ celui-ci conditionne la publication)

Débloqué par ton test, et c'est le seul de la liste qui **bloque la release**. Mission C porte les deux
natures qu'il faut, dans deux zones distinctes : `IadsZone` tient la batterie SA-6, `SmokeZone` le convoi.
Le ticket décrivait une zone unique tenant les deux — deux zones testent la même règle, puisque le défaut
s'applique par nature de groupe, pas par zone.

- [ ] Active **« Convoy Test Zone »** : **le convoi doit rouler sa route.** C'est #290, corrigé en 6.15.5, et c'est la
      régression à surveiller — elle compte plus que la moitié neuve.
- [ ] Active `IadsZone` : **la batterie doit allumer ses radars et engager.** De 6.15.5 à 6.15.12 elle
      restait muette, c'est le défaut corrigé ici. Même double lecture que 2c : si elle est muette,
      vérifie d'abord que le `Kub 1S91 str` est vivant.
- [ ] Puis `#alarm=0` sur la batterie : elle doit se taire. Un tag explicite gagne toujours sur le défaut
      par nature.

Ce n'est **pas** le cas de Tripack : il a vu des SAM de zone muets en 6.15.2, ce qui précède le défaut
AUTO. Son cas reste ouvert et ce check ne le referme pas.

---

## Étape 3 — le banc d'essai CSAR (aucun avion, 2 min)

Avec **DCS lancé et une mission chargée** (n'importe laquelle des deux ci-dessus fait l'affaire),
depuis le dépôt :

```bash
poetry run veaf-tools dcs smoke-test
```

Deux vérifications neuves : `csar-avoids-water-open-sea` et `csar-avoids-water-coast`.

- [ ] **Les deux passent** → le correctif #787 prend bien effet en vraie mission. C'est ce qu'on attend
      maintenant : quand ces vérifications ont été écrites, la prédiction était qu'elles échoueraient
      *toutes les deux*, et le correctif a inversé ça.
- [ ] **Un échec** → le remplacement de `csar.addCsar` ne s'applique pas dans une vraie mission, ce
      qu'aucun test unitaire ne peut me dire. Envoie-moi la sortie.

**Un piège que je te signale avant que tu l'interprètes** : sur la vérification en pleine mer, le pilote
est maintenant *perdu*, donc il n'y a plus de groupe à inspecter. La vérification peut rapporter
`no-group`, ce qui est un **succès** pour la règle des 500 m et un **échec** pour l'assertion telle
qu'elle est écrite. Si tu vois ça, ne cherche pas : dis-le-moi et j'apprends la différence à la
vérification.

---

## Étape 4 — le reste, classé par ce qu'il coûte vraiment

Ces items ne dépendent d'aucune des deux missions. J'ai retiré la formule « si tu as de l'énergie » :
elle mélangeait un check de dix minutes et deux chantiers de préparation.

**Faisable tout de suite, mais long :**

- [ ] **Item 10 — l'escorte respawnée.** Mission C, F10 → Assets → Respawn Arco, puis tu la regardes
      **plus de dix minutes**. Le défaut est un retour à la base *retardé* : un coup d'œil rapide
      aurait déclaré l'ancien comportement corrigé. Attendu : elle reste avec le ravitailleur. Tu avais
      tenu 30 minutes sur le chemin téléport le 18/08, c'est la barre.

**Pas des checks rapides — de la préparation d'abord, dis-moi si tu les veux et je prépare :**

- **Item 3 — l'image de checklist servie périmée.** Il faut éditer le texte d'une étape, reconstruire,
  et revoler **sans redémarrer DCS**. Je peux préparer l'édition et le build ; seul le vol est à toi.
- **Item 4 — le chargement échelonné.** Demande de construire un Foothold adopté, ce qui n'est pas fait.
  La lecture ensuite est dans `dcs.log` (6 scripts au départ, 5 vers +3 s, AIEN à +12 s) — je la ferai.

**Ce ne sont pas des tests, ce sont des avis à me donner :**

- **Item 5 — la checklist de démarrage du F-14B(U).** Ses quatre étapes automatiques sont déjà vérifiées ;
  il ne reste que ton verdict sur la procédure elle-même.
- **Item 9 — d'où vient `parking_id`.** Une investigation, pas une vérification. Débloque un ticket MCP.

---

## Ce que ça débloque

Quinze lots attendent cette session. Par ordre de ce que chaque étape libère :

| Étape | Lots débloqués |
|---|---|
| 1a | `FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY` |
| 1b | `FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT`, `FIX-COMBATZONE-SPAWN-ROUTE-OFFSET`, `FIX-COMBATZONE-SPAWN-REFERENCE-UNIT` |
| 1c | `FIX-FARP-ESCORT-PLACEMENT` |
| 1d | `FEAT-CONVOY-WAYPOINTS` |
| 2a | `FIX-COMBATZONE-DELAYED-COMMAND` |
| 2b | `FIX-CARRIER-MENU-COALITION` |
| 2c | `FIX-SKYNET-DYNAMICSPAWN-SCOPE` |
| 2d | `FIX-COMBATZONE-ALARM-BY-NATURE` — **conditionne la publication** |
| 3 | `FEAT-SMOKE-CSAR-WATER`, `FIX-CSAR-SPAWNS-ON-WATER` |
| 4 | `FIX-ESCORT-RESPAWN-TASK`, puis `FEAT-AWACS-ESCORT-COMMANDS` qui l'attend |

---

## Comment me rendre compte

Le plus utile pour moi, dans l'ordre :

1. **Ce qui a échoué**, même en une ligne — c'est ce qui porte l'information.
2. **Ce qui t'a surpris**, même si ça a « marché ». Tes remarques d'usage attrapent souvent ce que mes
   vérifications ne regardaient pas.
3. Le reste : « le bloc 1 est bon » suffit.

Pas besoin de fouiller les logs : si j'ai besoin de `dcs.log`, je te le demanderai et je te dirai quoi
chercher.
