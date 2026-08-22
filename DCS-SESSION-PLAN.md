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

### 1d · Item 19 — un convoi qui suit un itinéraire (nouveau, #781)

Pose trois marqueurs. Sur le premier, tape :

```
_spawn convoy, dest <2e marqueur>, dest <3e marqueur>, speed 40
```

- [ ] Le convoi part vers le 2e point, **puis repart seul** vers le 3e. La surveillance tourne toutes les
      30 s et le rayon d'arrivée est de 150 m : laisse-lui une demi-minute après l'arrêt avant de
      conclure.
- [ ] **« Faire attendre les ordres (au point suivant) »** au menu F10 : il doit **terminer son étape** et
      se garer là. Pas freiner sur place.
- [ ] **« Arrêter sur place »** : il s'immobilise immédiatement, au milieu de la route s'il le faut.
- [ ] Ces deux-là doivent se **sentir différents en jeu**. Si ce n'est pas le cas, c'est le vocabulaire
      qu'il faut revoir, pas le code — dis-le-moi.
- [ ] Sur la dernière étape, « Faire attendre les ordres » doit te répondre qu'il n'y a pas de point
      suivant.

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

## Étape 4 — si tu as encore de l'énergie

Ces items ne dépendent d'aucune des deux missions et sont indépendants entre eux.

- [ ] **Item 10** — regarder une escorte respawnée pendant **plus de dix minutes**. Le défaut se
      manifestait vers la dixième. C'est le seul qui demande de la patience.
- [ ] **Item 9** — d'où vient `parking_id` ? Débloque un ticket MCP.
- [ ] **Items 3, 4, 5** — l'image de checklist qui pourrait être servie périmée, le chargement échelonné
      des scripts, la checklist de démarrage du F-14B(U).

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
