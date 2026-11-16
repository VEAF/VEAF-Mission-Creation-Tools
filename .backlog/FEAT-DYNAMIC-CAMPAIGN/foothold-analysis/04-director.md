# 04 — Le Director : comment l'IA décide quoi faire (Foothold v6.5.3)

Périmètre : le planificateur `Director` (une instance par camp), les enregistrements passifs `DirectorCapability` dans lesquels il puise, `BudgetCommander`, `EventCommander`, et la mise à l'échelle de l'IA selon la difficulté et le nombre de joueurs.
Hors périmètre : ce que fait une sortie une fois lancée (`GroupCommander`, voir `03-ai-groups-sorties.md`), les règles de capture, le fonctionnement interne de la boutique, CTLD, le format du fichier de sauvegarde.
Toutes les références de lignes renvoient à `zoneCommanderv2.lua`, sauf indication d'un autre fichier.
Chaque mécanisme ci-dessous a été lu dans le code ; chaque section indique les plages de lignes lues.

La classe `Director` fait environ 25 000 lignes et 492 méthodes (`71164-96232`).
Le cycle de plus haut niveau, le score des cibles, la construction d'une opération, le choix de doctrine, la machine à phases, l'autorisation de lancement, le point d'entrée de fin d'opération et d'apprentissage, le point d'entrée des réactions et les deux petits commandants ont été lus en entier.
Le reste a été lu lors de deux passes ultérieures de comblement des lacunes ; chaque section dit ce qui a été lu.

## Liste des fonctionnalités

| # | Fonctionnalité | Description en une ligne | Emplacement principal dans le code |
|---|---|---|---|
| 1 | Architecture | Un `Director` par camp met son veto à chaque lancement d'IA géré et l'autorise ; `GroupCommander` ne fait qu'exécuter | `95930-96232`, `MA_Setup_CAv2.lua:6120-6123` |
| 2 | Catalogue `DirectorCapability` | Enregistrements de sortie passifs par zone (origine, cible, rôle, templates, condition), instanciés à la demande ; aussi générés automatiquement par DynamicHybrid | `11958-11969`, `25989-26030`, `26280-26400` |
| 3 | Cycle de planification | Tick de 30 s, états waiting/recovery/shaping/assault/exploit/surge, 10 à 20 min de récupération entre deux opérations | `95802-95928`, `71865-71895` |
| 4 | Choix de la cible | Score additif par zone Blue (faiblesse, valeur, front, exposition aux SAM, joueurs, historique), puis tirage aléatoire pondéré par secteur | `84401-84480`, `84767-84886` |
| 5 | Objectif de campagne | Stratégie nommée, secteurs/régions issus du fichier de setup, objectifs classés d'« ombre stratégique », mémoire du front | `87425-87454`, `MA_Setup_CAv2.lua:2271-2400` |
| 6 | Formation du package | Doctrine (6 types) → tirage pondéré des rôles (CAP, SEAD, frappe de piste, CAS, anti-navire, surface, artillerie), feinte, réserve conditionnelle | `89947-90128`, `87409-87527`, `87630-87890` |
| 7 | Posture aérienne | conserve / disperse / pressure / concentrate, selon les pertes, l'état de la piste et les joueurs ; dimensionne le package | `71149-71441` |
| 8 | Phases, autorisation, réévaluation, apprentissage | Machine à phases avec verrous (SEAD avant CAS, CAP avant les frappeurs), réévaluation toutes les 90 s (redirection / confinement / libération de la réserve), compteurs de résultats à décroissance | `94643-94735`, `91774-92109`, `89398-89903` |
| 9 | CAP de routine et réactions aériennes défensives | Allocation de CAP par slot en patrol/attack, scramble à l'arrivée d'un joueur, CAP réactive, appel de soutien aérien AIEN | `81380-81467`, `72414-72753`, `81160-81215` |
| 10 | Libération au sol | Libération probabiliste d'un convoi/d'une artillerie toutes les 90 s sous des limites mises à l'échelle des joueurs | `85257-85476` |
| 11 | Mémoires de renseignement | Carte d'activité des joueurs, mémoire des combats aériens, mémoire du champ de bataille par route, toutes à décroissance | `72928-72990`, `75689-75760`, `71018-71046` |
| 12 | Réactions à l'offensive des joueurs | Opérations de réaction sur capture/pression, détournement du CAS sur une zone capturée, plan défensif | `94279-94560`, `31715-31784`, `84482-84766` |
| 13 | Décisions économiques | Budget stratégique Red (upgrade, entrepôt, attaque de masse, bombardier), cible d'upgrade de zone, priorité des supplies ; `BudgetCommander` historique | `84006-84398`, `77825-77937`, `96236-96289` |
| 14 | IA Blue et PvP | Soutien de la mission d'attaque des joueurs au lieu d'un plan ; capacité partagée et autorisation stricte en PvP | `95709-95800`, `94737-94773`, `85494-85624` |
| 15 | Difficulté et mise à l'échelle des joueurs | Tables par palier et profils de difficulté alimentant chaque limite | `Foothold Config.lua:414-438`, `858-927`, `31055-31135` |
| 16 | `EventCommander` et événements | Événement aléatoire toutes les ~15 à 25 min, mission de frappe toutes les 5 min ; 17 événements sur le Caucase | `96291-96367`, `MA_Setup_CAv2.lua:6073-6500`, `9041-9715` |
| 17 | Visibilité joueur/admin | Un message d'interception, une trace optionnelle dans `dcs.log`, ni marques ni menus | `72448-72452`, `71913-71917` |
| 18 | Persistance | Tout est sauvegardé sous forme de secondes restantes et de compteurs à décroissance | `92448-92577` |
| 19 | Coût et limitation | Caches, signatures, compteurs de génération, budgets de candidats bornés | `75703`, `76862-76876`, `85432-85447` |

## 1. Architecture : qui décide quoi

- `GroupCommander` n'est que la machine à états d'une sortie ; en v6.5.3 il ne décide plus seul du moment de lancer pour les rôles que le Director gère (`95930-96022`).
- `Director` est instancié deux fois par le fichier de setup, une fois par coalition : `redDirector = Director:new({ battleCommander = bc, side = coalition.side.RED })` puis `:init()`, et de même pour Blue (`MA_Setup_CAv2.lua:6120-6123`).
- Les instances se retrouvent avec `Director:getForSide(side)` à partir d'une table de classe `instancesBySide` (`71897-71899`, `95903`).
- Le Director contrôle les lancements par un veto : `Director:allowsGroupSpawn(groupCommander)` ne renvoie true que lorsque le groupe détient une affectation autorisée, un permis/slot de CAP de routine, ou un permis au sol (`95998-96021`) ; les groupes qu'il ne gère pas reçoivent toujours `true` (`96007`, `96017`).
- Il est informé de chaque changement d'état de sortie par `Director:onGroupStateChanged(groupCommander, previousState, currentState, wasSpawned, isSpawned)` (`96024-96232`), qui marque les affectations comme lancées/terminées et libère les slots de CAP et les permis au sol.
- Trois boucles de décision coexistent pour Red en PvE : une **opération** à la fois (un package offensif contre une zone Blue), l'allocation de **CAP de routine**, et la **libération au sol** (convois/artillerie), plus un **budget stratégique** qui dépense les crédits de Red (`95842-95895`).
- L'IA Blue en PvE et les deux camps en PvP exécutent une boucle différente et plus simple, `_updateBlue`, dont l'« opération » consiste à soutenir la zone que les joueurs attaquent (`95802-95805`, `95709-95800`).

## 2. `DirectorCapability` — le catalogue passif des sorties

### Ce que règle le créateur de mission

- Une capability se déclare dans `zones.<origin>:addGroups({...})` avec `DirectorCapability:new({name=..., mission=..., template=..., MissionType=..., targetzone=..., Altitude=..., type=..., condition=...})` (`MA_Setup_CAv2.lua:1290-1297`).
- Exemples de Kobuleti : un convoi de supply de surface vers `SAM-India` avec une `condition` sur un user flag personnalisé, deux supplies par hélicoptère, une CAP `patrol` sur Batumi, une CAP `attack` et une CAP `patrol` sur Kutaisi (`MA_Setup_CAv2.lua:1290-1297`).
- La liste des champs et leur sens sont les mêmes que pour `GroupCommander` et sont tabulés dans `03-ai-groups-sorties.md` section 1 (non répétés).
- Le constructeur se contente de mettre `id` à `name` par défaut, d'exiger un id non vide, d'interdire les méthodes `update`/`shouldSpawn`, de mettre `type='air'` par défaut, de fixer `AllowSupplyLaunchFromSuspendedZone` pour les supplies hors boutique, et de marquer l'enregistrement `_isDirectorCapability` (`11960-11969`).
- `template` est le nom d'une liste Lua globale de noms de groupes template en late activation du `.miz` (par ex. `CapPlaneTemplate`, `HeloSupplyTemplate`, `SupplyConvoy`) ; le camp de la capability est déduit du premier template dont la coalition se résout (`26016-26022`).

### Mécanisme

- `ZoneCommander:addGroups` envoie les enregistrements marqués à `BattleCommander:registerDirectorCapability(originZone, capability)` (`56460-56472`, `26280-26298`).
- L'enregistrement vérifie l'unicité de l'id, compile un prototype de « faits » et indexe la capability de cinq façons : par zone d'origine, par zone cible, par `mission`, par `MissionType` et par `type` (`26286-26298`).
- Le prototype de faits est un faux sosie de `GroupCommander`, jamais spawné (état `inhangar`, `Spawned=false`), qui emprunte les méthodes de cache de templates et de délai de hangar de `GroupCommander`, afin que le code normal d'éligibilité au spawn puisse s'exécuter sur une capability sans l'instancier (`25989-26015`).
- `BattleCommander:evaluateDirectorSpawnEligibility(capability, request)` exécute cette éligibilité sur la vue passive (`26142-26150`).
- Une capability devient un `GroupCommander` vivant via `BattleCommander:activateDirectorCapability(capability, request)`, qui renvoie l'instance existante s'il y en a une, et autorise deux instances « dérivées » supplémentaires dans les slots 2 et 3 (`26383-26400`).
- Quand l'opération se termine, le Director demande la mise au rebut des instances : `requestDirectorInstanceDisposal(assignment.groupRef)` pour chaque affectation (`92104-92106`).
- Une seconde source de capabilities est le **remplisseur DynamicHybrid** : `bc:startDynamicHybridFiller(DynamicHybridConfig)` génère automatiquement des capabilities à partir de la géométrie des zones (limites de portée par rôle : `airMaxNm=150`, `heloCasMaxNm=40`, `surfaceMaxNm=30`, `minCapAttackNm=35`, `minSeadAttackNm=40`…, et `forcedZoneCapabilities` par zone) (`MA_Setup_CAv2.lua:6077-6118`), en créant des enregistrements `DirectorCapability` nommés d'après l'origine/la cible/le rôle (`33861-33876`).
- Le Director attend l'amorçage de ce remplisseur avant sa première passe (`94266-94271`).

### Notes de reproduction

- Le catalogue est de la donnée : origine, cible, rôle, liste de templates, prédicat ; rien dedans n'a besoin de Moose.
- Le point subtil est la « vue passive » : l'éligibilité (camp, disponibilité des templates, conditions, minuteurs de hangar) doit être calculable sans groupe vivant, faute de quoi le planificateur ne peut pas compter ce qu'il pourrait lancer.

## 3. Le cycle de planification (Red, PvE)

### Mécanisme (lu en entier : `95802-95928`)

- `Director:init()` construit un catalogue de régions et un catalogue de secteurs à partir des globales du setup `TheaterRegions`, `TheaterInfrastructure` et `TheaterAreas`, récupère les données de sauvegarde en attente auprès du `BattleCommander`, et démarre un unique `timer.scheduleFunction` qui se replanifie lui-même (`95898-95928`).
- Le premier passage a lieu après `startDelaySec` = 30 s pour Red en PvE et 5 s pour Blue ou le PvP ; la fonction renvoie `scheduleTime + tickSec`, donc la période est `tickSec` = 30 s (`95923-95927`, `71869-71870`).
- Le Director n'utilise lui-même aucun scheduler Moose ; c'est du `timer.scheduleFunction` brut.
- Tant que `_runtimeReady()` n'est pas vrai, le tick ne fait rien : il attend l'amorçage de DynamicHybrid et que les données de sauvegarde de l'IA air/surface et de l'attaque de masse aient été consommées (`94266-94277`).
- Au premier tick prêt, il restaure sa persistance ou, sans sauvegarde, entre dans l'état `recovery`, planifie le premier « surge » après `surgeInitialDelaySec` = 900 s et la première décision de budget stratégique après le `initialDelaySec` du profil de difficulté (`95810-95841`).
- Chaque tick Red en PvE exécute ensuite, dans cet ordre (`95842-95895`) :
  1. `_updateDefensivePlan` (quelles zones Red défendre, section 12) ;
  2. `_consumeAirCombatIntelligence` (où des appareils Red ont été perdus / où les joueurs se battent, section 11) ;
  3. CAP de routine : `_routineCapAwarenessTarget`, `_reconcileRoutineCaps`, `_updateRestoredCapStartup` (section 9) ;
  4. `_observeRegions`, `_ensureCampaignStrategy`, `_updateStrategicShadow` (objectif au niveau de la campagne, section 5) ;
  5. `_reconcileRoutineCapRevector` (re-vectorer une CAP en vol) ;
  6. adoption d'une attaque de masse lancée de l'extérieur comme opération `surge`, qui préempte l'opération en cours (`95853-95860`) ;
  7. `_updateStrategicBudget` (dépense des crédits, section 13) ;
  8. `_updateAirPosture` (section 7) ;
  9. `_updateGroundRelease` (convois et artillerie, section 10) ;
  10. si une opération existe : `_reconcileOperationCapacity`, `_updateOperation`, puis retour (`95876-95881`) ;
  11. sinon `_processPendingReaction` (demande de contre-attaque en file) ;
  12. sinon, si l'on n'est pas en `recovery` et que `nextPlanningAt` est dépassé, `_startOperation`.
- Un changement de la « signature de capacité » (effectifs des joueurs et les cinq limites de rôle concaténés) pendant `waiting` force une re-planification immédiate (`95872-95887`, `85626-85637`).
- États du Director : `waiting`, `recovery`, `shaping`, `assault`, `exploit`, `surge` pour Red ; `waiting`/`support` pour Blue (`71806`, `94300`, `92011`, `92019`, `92136`, `95731`).

### Constantes de temps (valeurs par défaut dans `_normalizeConfig`, `71865-71895`)

| Clé de config | Valeur par défaut | Usage |
|---|---|---|
| `enabled` | true | interrupteur général de l'instance |
| `log` | false | `env.info('[Director] side=… state=… …')` (`71913-71917`) |
| `startDelaySec` / `tickSec` | 30 / 30 | premier passage et période |
| `planningRetrySec` | 90 | nouvel essai quand aucune opération n'a pu être construite (`94639`) |
| `recoveryMinSec` / `recoveryMaxSec` | 600 / 1200 | pause après chaque opération (`92107-92108`) |
| `shapingMaxSec` / `assaultMaxSec` / `exploitMaxSec` / `operationMaxSec` | 720 / 1800 / 900 / 3600 | échéances de phase et d'opération |
| `captureReactionWindowSec` | 1200 | une capture Blue est « fraîche » pendant 20 min |
| `historySize` | 3 | opérations mémorisées pour le choix de cible/doctrine |
| `feintChance`, `feintDelayMinSec`, `feintDelayMaxSec` | 25 %, 240, 420 | sortie sur l'axe secondaire |
| `maxPackageBase`, `maxPackagePerPlayers`, `maxPackageCap` | 2, 2, 6 | taille du package selon les joueurs |
| `surgeInitialDelaySec`, `surgeCooldownMinSec`, `surgeCooldownMaxSec` | 900, 2700, 5400 | cadence des attaques de masse |
| `blueAssignmentRetrySec`, `capPermitRetrySec` | 120, 120 | nouveaux essais |
| `groundDecisionSec`, `groundPermitTimeoutSec`, `groundPermitRetrySec` | 90, 720, 120 | libération au sol |

- Le fichier de setup ne passe aucune table `config`, donc ces valeurs par défaut sont ce qui tourne (`MA_Setup_CAv2.lua:6120-6123`).

## 4. Choix de la cible et score (offensive Red)

### Mécanisme (lu en entier : `84401-84480`, `84767-84886`)

- Les candidates sont toutes les zones Blue utilisables ayant au moins un voisin Red utilisable dans le graphe de connexions « opérationnel » (`84776-84791`).
- Chacune reçoit `score = tacticalScore + 0.35 × strategicScore`, le score stratégique venant de la liste d'objectifs de l'« ombre stratégique » (section 5) (`84792-84799`).
- `_targetScore` part de 100 et ajoute ou retranche (`84402-84479`) :

| Terme | Valeur | Ligne |
|---|---|---|
| revenu de la zone | `min(40, income × 2)` | `84405` |
| possède une base aérienne | +18 | `84406` |
| possède des cibles SEAD | +18 | `84407` |
| faiblesse | `(1 − readiness) × 80`, readiness = ratio de force de combat de la zone ou construit/total d'upgrades | `84408-84412`, `88087-88108` |
| préférence de région | `_regionTargetPreference(zone,'ATTACK')` : 0 à 90 selon l'intention de la région et le rôle du membre, 0 hors région (section 5) | `84413`, `76959-77019` |
| capturée par Blue il y a moins de 20 min | +160 | `84414-84418` |
| voisins Red | +35 chacun | `84419` |
| connectivité | `min(48, connections × 8) + 12 × Blue neighbours` | `84431` |
| progression du front | `_campaignFrontProgressionScore` : `min(180, 45 × Red neighbours)`, +100 pour une poche, plus la proximité des dernières captures de Red et de Blue (section 5) | `84432-84438`, `79233-79309` |
| exposition aux SAM | `− min(260, exposure × 160)` | `84439-84440` |
| activité des joueurs près de la zone | `+ playerScores[zone]` | `84441-84442` |
| pression réactive des voisins Red | `+ min(20, pressure × 3)` chacun | `84443-84446` |
| historique, même cible | +60×age pour `near-complete`, +30×age pour `partial`, −35/−45/−55×age pour aborted/contained/failed (−20×age si fraîchement capturée) | `84456-84465` |
| historique, cible adjacente (1 saut) | +40×age après une capture/neutralisation là-bas, +18×age après un échec là-bas | `84466-84475` |
| biais de cible appris | `_targetOutcomeBias` | `84478` |

- `ageWeight = historySize − index + 1`, donc la dernière opération pèse 3 et la plus ancienne 1 (`84448`).
- Les opérations terminées administrativement (abandonnées, redirigées, préemptées, ou n'ayant jamais lancé d'attaquant) n'orientent pas le choix (`84449-84455`).
- Le tirage n'est pas glouton : `_areaFirstCandidateOrder` choisit d'abord un **secteur** par tirage aléatoire pondéré parmi les trois premiers secteurs de la recommandation de secteur, puis `_pickWeightedCandidate` choisit par tirage aléatoire pondéré parmi les trois premières candidates de ce secteur (`84832-84886`, `84810-84830`).
- Si cette cible préférée ne peut pas produire d'opération, les autres candidates sont essayées dans l'ordre (même secteur d'abord) (`94610-94637`).
- Chaque choix doit passer `_campaignActionAdmission` (un « bail d'action de campagne » qui empêche de basculer sans cesse d'un secteur à l'autre ; constantes : maintien 2 à 5 min, décision 1 à 2 min, historique de 6 sur 30 min) (`94585-94596`, `77446-77451`) ; le calcul est en section 5.

### Ce que voit le joueur

- Rien de direct ; aucun message n'annonce la cible choisie (la classe contient un seul appel `trigger.action.outText*`, en `72448`, sans rapport avec le choix de cible).

## 5. Objectif de campagne : stratégie, régions/secteurs et « ombre stratégique »

Lus en entier : `_regionTargetPreference` (`76959-77019`), `_selectCampaignStrategy`/`_ensureCampaignStrategy`/`_campaignStrategyShadowBias` (`77057-77332`), l'arbitre d'actions de campagne (`77445-77754`), `_strategicShadowCandidateScore` (`78104-78306`), la moitié « secteur » de `_collectStrategicShadowCandidates` (`78308-78427`, `78470-78670`), `_updateStrategicShadow` (`78759-78971`), `_regionIntent` (`76257-76304`), `recordZoneOwnershipChange` (`74800-74824`), `_campaignFrontProgressionScore` (`79233-79309`), les catalogues du setup (`MA_Setup_CAv2.lua:2271-2507`).
Lus en entier lors de la deuxième passe : `_buildRegionCatalog`/`_buildAreaCatalog` (`74895-75336`), `_buildRegionFacts` (`76105-76255`), `_observeRegions` (`76378-76448`), `_buildLogisticsIntelligence` et `_hasCurrentExploitationSupply` (`77938-78102`).

### Données du créateur de mission (fichier de setup)

- `TheaterAreas` est une liste de secteurs nommés, chacun `{id, kind, name, zones = {{name, role}, …}}` ; `kind` vaut `air_network` ou `coastal_corridor` sur le Caucase, et le `role` d'une zone est l'un de `hub`, `gateway`, `defence`, `resource`, `approach` (`MA_Setup_CAv2.lua:2365-2507`).
- Les secteurs du Caucase comprennent `western_georgia` (Batumi, Kobuleti, Senaki, Kutaisi comme hubs), `abkhazia` (Sukhumi, Sochi), `black_sea_north` (Gelendzhik, Anapa) et `kuban` (Krymsk, Krasnodar-Center) (`MA_Setup_CAv2.lua:2366-2420`).
- `TheaterRegions` décrit des objectifs multi-zones (groupes d'îles avec des membres `core`, `foothold`, `defence`) et est vide sur le Caucase, donc tous les termes fondés sur les régions ci-dessous valent 0 sur cette carte (`MA_Setup_CAv2.lua:2362-2363`, `76960-76961`).
- Les entrées de `TheaterInfrastructure` sont `{id, flag, effect = "defence_supply", side, scope = "routes", sourceZone, targetZones}` : un entrepôt destructible, identifié par un flag personnalisé, qui alimente une zone SAM depuis une base, par ex. Kobuleti → SAM-India sous le flag `SamAlphaWarehouse` (`MA_Setup_CAv2.lua:2271-2360`).
- Le Director lit `CustomFlags[infrastructure.flag]` pour compter les infrastructures intactes et détruites par secteur (`78508-78520`).

### Catalogues construits à `Director:init` (`_buildRegionCatalog`, `_buildAreaCatalog`)

- Les deux constructeurs valident strictement les données du setup et lèvent une `error('[Director] …')` Lua au moindre défaut : id manquant, id en double, nom de zone inconnu, une zone dans deux régions ou deux secteurs, une région sans exactement une zone `core`, une infrastructure sans flag ou avec une zone source inconnue, une infrastructure dont la source n'a aucune route de supply vers une cible listée, un secteur sans aucun hub (`74902-74960`, `74987-75058`, `75132-75137`, `75330-75332`).
- Une région est `{id, kind (default 'region'), name, zones = {{name, role (default 'member'), zone}}, zoneByName, coreZoneName, infrastructure}` ; recherches `regionById` et `regionByZone` (`74922-74957`, `74980-74982`).
- Une entrée d'infrastructure est compilée en `{…, scope, targetZones, affectedRegions}` : avec `scope = 'routes'` les cibles sont les `targetZones` saisis ; avec `scope = 'source'` ce sont toutes les cibles des groupes de supply de la zone source (`75010-75058`).
- Un secteur est `{id, kind (default 'strategic_area'), name, zones, zoneByName, membersByRole, regions, neighbors, gatewayLinks, supplyLinks, sourceInfrastructure, affectedInfrastructure}` ; un membre est `{name, role, zone, regionId, regionRole, bluePriority}` ; un secteur peut aussi lister des `regions`, dont les zones le rejoignent avec le rôle `region` (`75101-75178`).
- Liens dérivés : un `gatewayLink` pour chaque zone ayant un voisin du graphe dans un autre secteur, un `supplyLink` pour chaque zone ayant une route de supply vers un autre secteur ; les deux rendent les deux secteurs voisins (`75185-75240`).
- Une zone SAM saisie comme `defence` qui est la cible d'une entrée d'infrastructure reçoit un **parent défensif**, la zone source de l'infrastructure (`defenceParentByZone`, `defenceZonesByParent`) ; c'est ce que lit la composante `unlock` de l'ombre (`75242-75281`).
- Les **rôles opérationnels** sont calculés, pas seulement saisis (`75286-75329`) : le rôle saisi (sauf `member`/`region`) ; `hub` pour un core de région ou toute zone ayant une capability de CAP avion saisie à la main (hors DynamicHybrid) ; `gateway` pour une zone ayant un lien de passerelle ou de supply ; `resource` pour toute zone dont le revenu est > 0 ; `infrastructure` pour une source d'infrastructure ; `defence` pour une cible d'infrastructure ou un membre `defence` de région ; `approach` pour un foothold de région ; `member` quand rien ne s'applique.
- Donc, sur le Caucase, une zone saisie `gateway` qui rapporte aussi un revenu compte à la fois comme `gateway` et comme `resource` dans chaque score pondéré par les rôles.

### Faits de région et observation (uniquement sur les cartes avec `TheaterRegions`)

- `_observeRegions` revient aussitôt quand il n'y a aucune région, ce qui est le cas du Caucase (`76379`).
- Sinon il reconstruit les faits de chaque région au plus toutes les `PLANNING_INPUT_REUSE_SEC` = 60 s, et seulement si la signature d'activité des joueurs, la génération des cibles de CAP ou la signature complète des entrées a changé (`76395-76414`, `71063`).
- `_buildRegionFacts` donne, par région : le nombre de membres par camp (actifs et territoriaux), `coreSide`/`coreActive`, la pression cumulée des joueurs, les captures Blue dans la fenêtre de réaction aux captures, l'état de l'infrastructure (`intact`/`degraded`, avec `degradedForSide`), les liaisons terrestres internes ouvertes ou bloquées (`IsGroundConvoyBlocked`), les zones voisines extérieures par camp (`boundaryZonesBySide`, et celles atteignables par voie terrestre), et une étiquette `control` (`red`, `blue`, `neutral`, `contested`, `mixed`, `inactive`) (`76105-76255`).
- Chaque région reçoit ensuite son `intent` (tableau ci-dessus) et une ligne de log quand sa signature change (`76417-76441`).

### Renseignement logistique (`_buildLogisticsIntelligence`)

- Construit avec l'ombre stratégique ; vide quand le supply IA régulier est désactivé pour le camp (`77938-77940`, `78329-78331`).
- Pour chaque zone amie utilisable ayant des routes de supply régulières (groupes boutique seule et retirés exclus), il lit le stock de supply de la zone : `ready`, `pending`, `available = max(0, ready − pending)`, `efficiency` de production, stock `maximum`, et `pressured` (source Red en PvE avec `BlueIsNear`) (`77942-77990`).
- Une route est `open` sauf si l'entrepôt de son infrastructure est détruit (`_regularSupplyRouteInfrastructureBlocked`) ; elle est `slotReady` quand l'un de ses groupes est dormant sans permis, sans délai de perte et sans nouvel essai en attente (`77960-77975`).
- Par zone **cible** : `openSources`, `blockedSources`, `productiveSources` (efficiency > 0), `hubSources` (un centre logistique ou un stock maximum > 1), `pressuredSources`, `dispatchableSources` (slot prêt et non sous pression), `availableStock` (somme sur les sources expédiables), `averageEfficiency`, et `readyForExploitation = availableStock > 0 and dispatchableSources > 0` (`78012-78062`).
- Par **secteur** : sources, stock prêt/en attente/disponible/maximum, centres logistiques, sources sous pression, routes ouvertes et bloquées, efficiency moyenne (`77991-78011`, `78063-78066`).
- `_hasCurrentExploitationSupply` revérifie en direct les mêmes conditions, et c'est ce qu'exige la doctrine `ground_push` (`78075-78102`).

### Stratégie de campagne (Red, PvE)

- Une seule stratégie est tenue à la fois : `{name, generation, reason, goalZone, goalRegion, selectedAt, weight}` (`77245-77253`).
- Elle est conservée jusqu'à ce que sa zone objectif cesse d'être une zone valide, ennemie/neutre, active et non cachée (en pratique : jusqu'à ce que Red la capture) ; alors la génération est incrémentée et une nouvelle stratégie est tirée (`77267-77286`).
- La sélection inonde d'abord le graphe opérationnel à partir de chaque zone Red utilisable pour trouver les zones non-Red atteignables (`77083-77103`), puis rassemble des faits sur elles et choisit une zone objectif par stratégie (`77104-77171`) :

| Stratégie | Zone objectif = zone atteignable maximisant | Poids dans le tirage | Lignes |
|---|---|---|---|
| `air_supremacy` | `100 if runway + 50 if SEAD targets + 5 × connections + 10 × income` | `1 + 2 × runway targets + 0.75 × SEAD targets` | `77114-77120`, `77186-77193` |
| `economic_pressure` | `100 × income + 10 × connections + 20 if runway` | `1 + 2 × income targets + min(4, total income)` | `77121-77129`, `77194-77202` |
| `island_campaign` | membre d'une région `island` : score de rôle (core 100, foothold 80, defence 60, autre 40) + 70 si Red tient déjà une partie de la région + 40 si contestée | `2 + 0.8 × region targets + 1.5 × core targets` | `77130-77146`, `77203-77212` |
| `breakthrough` | candidate de l'ombre maximisant `hub + 30 if a ground route is open` | `2 + maxHub / 24 + min(3, 0.3 × ground-open targets)` | `77161-77165`, `77213-77219` |
| `counterpunch` | candidate de l'ombre maximisant `player + urgency` | `1 + maxPlayer / 60 + maxUrgency / 30`, seulement si l'un des deux est > 0 | `77166-77170`, `77220-77228` |

- Le tirage est un simple tirage aléatoire pondéré parmi les stratégies disponibles (`77235-77243`) ; le résultat est loggé avec tous les poids quand `config.log` est actif (`77255-77263`).
- La stratégie agit ensuite par une seule fonction, `_campaignStrategyShadowBias`, qui remplit la composante `strategy` de chaque candidate de l'ombre (`77288-77332`) :
  - un biais de route commun à toutes les stratégies : 120 pour la zone objectif elle-même, sinon `max(0, 100 − 12 × graph hops to the goal)` (recherche limitée à 12 sauts) ;
  - `air_supremacy` : +45 pour une piste, +25 pour des cibles SEAD ;
  - `economic_pressure` : `min(75, 40 × income)`, +40 sur l'objectif ;
  - `island_campaign` : dans la région objectif, core 85 / foothold 70 / defence 45 / autre 35, +60 sur l'objectif ;
  - `breakthrough` : `0.4 × hub + 20 if a ground route is open`, +60 sur l'objectif ;
  - `counterpunch` : `min(100, 0.35 × player) + min(100, urgency)`, +40 sur l'objectif.
- Elle renvoie 0 en PvP et pour Blue (`77289-77291`).
- Elle pèse aussi dans le choix de doctrine (section 6) et dans l'admission des actions de campagne (ci-dessous).

### Ombre stratégique : une entrée notée par zone attaquable

- Le score d'une candidate est la somme de quatorze composantes (`78107-78122`, `78292-78296`) :

| Composante | Valeur | Lignes |
|---|---|---|
| `base` | 100 pour une zone ennemie, 60 pour une neutre | `78108` |
| `player` | score d'activité des joueurs de la zone, plafonné à 300 | `78109` |
| `runway` | 110 si la zone a une capability de piste | `78123-78124` |
| `income` | `min(90, 45 × income)` | `78125-78126` |
| `readiness` | `(1 − target readiness) × 70` | `78127-78130` |
| `region` | `_regionTargetPreference` : selon l'intention de la région et le rôle du membre, par ex. `seize_core` core 90, `counterattack_foothold` foothold 90, `reduce_remnant` 75 (+15 defence), `expand_foothold` core 85, `prepare_assault` core 45 ; +12 si la région est dégradée pour l'ennemi, + `min(25, 0.1 × player pressure)` ; les zones neutres reçoivent 75/60/45/35 selon le rôle quand l'intention est d'étendre | `76969-77018`, `78132-78151` |
| `hub` | `min(48, 8 × connections) + min(36, 9 × connections to non-friendly zones)` | `78153-78162` |
| `urgency` (Red PvE, zone Blue) | +150 si Blue l'a capturée dans `captureReactionWindowSec` ; + `min(45, 5 × Σ reactive pressure of the Red neighbours)` | `78164-78176` |
| `history` (Red PvE) | même cible : +60 × age pour `near-complete`, +30 × age pour `partial`, 0 pour `incomplete`, −80 × age sinon ; une cible à moins de 2 sauts d'une précédente : −20 × age ; fins administratives ignorées | `78197-78215` |
| `history` (Blue / PvP) | même cible : +80/+60/+30 × age pour neutralised/near-complete/partial, −80 × age pour failed/aborted/contained ; à moins de 2 sauts d'une cible capturée ou neutralisée : +30 × age | `78180-78196` |
| `learning` | `_targetOutcomeBias` : `min(30, 10 × success) + min(15, 5 × partial) − min(60, 15 × failure)` sur les compteurs à décroissance, plus le biais de l'axe secondaire | `78217`, `77431-77442` |
| `commitment` | +100 si c'est la cible de l'opération en cours, +35 si c'est déjà l'objectif principal de l'ombre | `78218-78224` |
| `logistics` | prête pour l'exploitation : `45 + min(45, 15 × available stock)` ; sources ouvertes mais non prêtes : `−10 + min(20, 5 × productive sources)` ; aucune ouverte : −40 ; puis `+ min(35, 15 × hub sources) + min(45, 25 × pressured sources) − min(40, 12 × blocked sources) + 20 × (average efficiency − 0.5)` ; −30 quand il n'y a pas de ligne logistique | `78225-78242` |
| `unlock` (Red PvE) | pour une zone SAM avec des cibles SEAD dont le « parent défensif » est la cible en cours (80) ou l'objectif de la stratégie (60), +20 si le supply du parent est prêt | `78247-78262` |
| `strategy` | `_campaignStrategyShadowBias` | `78273-78281` |

- Chaque candidate porte aussi des `effects` : `SECURE` ou `CAPTURE`, `AIRFIELD_CONTROL`, `SEAD`, `GROUND_ASSAULT` (un voisin terrestre ami existe et la route de convoi n'est pas bloquée) ou `AIR_ASSAULT`, `LOGISTICS_READY`/`LOGISTICS_BUILDING`/`LOGISTICS_BLOCKED`, `PLAYER_SUPPORT` (`78244-78290`).
- `regionIntent` vient de `_regionIntent`, une table de décision sur le propriétaire des membres de la région, de son core et de ses footholds : `inactive`, `consolidate`, `defend_region`, `defend_degraded`, `hold_degraded`, `prepare_assault`, `contain`, `counterattack_foothold`, `reduce_remnant`, `expand_control`, `expand_foothold`, `seize_core`, `observe` ; une zone hors de toute région est `frontline` (`76257-76304`, `78300`).

### Classement des secteurs (l'« ombre de secteur »)

- Chaque secteur reçoit des faits : nombre de zones par camp (toutes les zones actives, et zones « territoriales » y compris suspendues), une étiquette `control` (`friendly`, `enemy`, `neutral`, `contested`, `mixed`, `inactive`), la pression des joueurs, le revenu, les infrastructures intactes/détruites, les pistes amies bloquées, l'inventaire de capabilities du secteur et de ses voisins (quand l'inventaire de planification a moins de 300 s), et un résumé logistique (`78332-78427`, `78478-78555`).
- Score de secteur = somme de (`78562-78662`) :
  - `target` : score de sa meilleure candidate ;
  - `depth` : `0.12 ×` les scores des candidates 2 à 4, plafonné à 140 ;
  - `player` : `min(90, 0.2 × area player pressure)` ;
  - `role` : rôles de secteur de la meilleure candidate, hub 70, gateway 55, resource 35, infrastructure 25, defence 20, approach 10, support 5, plafonné à 100 (`78469-78477`) ;
  - `frontline` : `min(45, 9 × number of candidates)` ;
  - `readiness` : `min(70, 6 × combat capabilities nearby)`, ou −40 quand il n'y en a aucune ;
  - `logistics` : `min(70, 12 × stock + 10 × logistics centres) + 20 × efficiency + min(30, 15 × pressured sources) − 30 × blocked-route ratio`, ou −35 sans source ;
  - `infrastructure` : `15 ×` infrastructures détruites ;
  - `runway` : `− min(140, 20 × blocked runways + 12 × importance + min(60, 0.15 × pressure))` ;
  - `continuity` (Blue ou PvP seulement) : `180 + min(90, 20 × friendly zones)` quand le secteur est en partie tenu, +220 pour le secteur engagé, +260 pour le secteur de l'opération en cours ;
  - `history` : ±25 / +12 / +35 × age selon le résultat des opérations précédentes dans le secteur.
- Les secteurs classés sont stockés dans `areaShadowRecommendation` ; c'est la liste dans laquelle le choix de cible tire son secteur (section 4) (`78838-78866`).

### `_updateStrategicShadow` : objectif et limiteur

- L'ombre est reconstruite au plus toutes les 300 s sauf si l'une de ses entrées a changé : cible en cours, génération de l'état des cibles de CAP, génération des blocages de piste, signature d'observation des régions, signature d'activité des joueurs, signature de pression réactive de Red, nom ou objectif de la stratégie (`78781-78800`).
- Un second verrou compare une signature complète des entrées et saute la reconstruction quand rien n'a changé et que le renseignement logistique a moins de 300 s (`78801-78809`).
- Un changement de propriétaire d'une zone force une reconstruction au tick suivant pour les deux Directors (`74820-74823`).
- Résultat `strategicShadowObjective = {main, secondary, candidates, areaShadow, campaignStrategy, campaignGoal, liveTarget}` (`78885-78895`).
- `main` est la meilleure candidate pour Red en PvE, et la meilleure candidate du secteur le mieux classé pour Blue et en PvP (`78817-78822`).
- `secondary` est la meilleure candidate sur un front distinct : une autre région, ou à plus de 2 sauts de graphe de `main` (`78823-78837`).
- Avec `config.log`, l'objectif principal, le secteur recommandé et le détail des composantes des trois meilleures candidates sont loggés, seulement quand la signature du résultat change (`78898-78969`).

### Mémoire du front de campagne et progression du front

- `Director:recordZoneOwnershipChange(zoneName, fromSide, toSide, now)` (au niveau de la classe, appelée à chaque capture) pousse un événement `{zone, fromSide, toSide, at}` dans une mémoire partagée via le Director Red, plafonnée à `CAMPAIGN_FRONT_EVENT_MAX` = 24, et enregistre la zone capturée comme **focus** du camp qui l'a prise (`74800-74819`, `71064-71065`).
- `_campaignFrontProgressionScore(target, advancingSide, friendlyNeighbours, enemyNeighbours)` = `min(180, 45 × friendly neighbours)`, +100 quand la cible a ≥ 2 voisins amis et aucun autre voisin ennemi (une poche), plus la proximité de la dernière capture du camp lui-même (180 dessus, 125 à 1 saut, 65 à 2, 25 à 3) ou, sans focus pour l'instant, la proximité des origines de la campagne (`105 − 22 × (hops − 1)`) ; pour Red, il ajoute la proximité de la dernière capture de Blue tant qu'elle est dans la fenêtre de mémoire (180 / 95 / 35 à 0 / 1 / 2 sauts) (`79233-79309`).
- Le résultat est mis en cache par génération de mémoire et par génération des cibles de CAP (`79240-79254`).
- Dans le score de cible de Red, il est ajouté sans pondération à côté du terme de connectivité (`84431-84438`).

### Admission des actions de campagne (le « bail d'initiative »)

- Chaque décision de Red qui engage des forces passe par `_campaignActionAdmission(proposal, now, facts)` ; les types d'action sont `operation`, `ground`, `upgrade`, `warehouse`, `warehouse_repair`, `mass_attack`, `bomber`, `reaction`, `reactive_cap`, `aien_air_support`, `local_response` (`77452-77464`, `77649-77653`).
- Une proposition est `{action, targetZone, areaId, score, urgency 1–3, reason, logistics}` ; l'urgency vaut 3 par défaut quand l'urgence stratégique de la candidate est ≥ 100, 2 quand elle est > 0, sinon 1 (`77488-77503`).
- `_campaignActionCandidates` construit deux scores, `allow` et `hold` (`77523-77647`) :
  - `allow` part de `70 + min(220, 0.30 × proposal score) + 30 × urgency` ; `hold` part de 75 ;
  - la charge de travail en cours relève `hold` : `+ min(100, 9 × air commitments)` pour une action aérienne, `+ min(75, 18 × ground commitments)` pour une action terrestre ;
  - si un bail est actif : alignée avec lui (même cible, ou même secteur et deux actions d'un type « support ») → `allow` +140 ; non alignée → `hold` +140 et `allow` + `55 × (urgency − 1)` ;
  - si une opération est en cours : même cible ou même secteur → `allow` +90 ; ailleurs → `hold` +120 (sauf pour `upgrade`) ;
  - stratégie : zone objectif +70, secteur objectif +30, et +30 à +40 quand le type d'action convient à la stratégie (par ex. `breakthrough` avec `operation`/`ground`, `counterpunch` avec les réactions et les upgrades) ;
  - plan défensif : +70 pour une action défensive dans la zone ou le secteur défendu en priorité ;
  - supply : `+ min(45, 25 × supply sorties already heading to the target)`, +35 pour une action défensive quand les sources sont sous pression ;
  - répétition : sur les 6 dernières actions dans les 30 min, `− min(45, 6 × age weight)` pour le même type d'action et `− min(35, 5 × age weight)` pour la même cible ;
  - une urgency de 3 ajoute +170 à `allow`.
- Décision : une proposition alignée est toujours autorisée ; une proposition qui a déjà attendu la fin d'un `hold` et ne rencontre aucun bail est autorisée ; sinon c'est un tirage aléatoire pondéré entre `allow` et `hold`, proportionnel aux deux scores (`77678-77685`, `84810-84830`).
- La décision est mise en cache par signature (`action|target|urgency|reason`) pendant 60 à 120 s, de sorte que la même proposition n'est pas retirée à chaque tick (`77658-77664`, `77697-77703`).
- `_commitCampaignAction` crée le bail quand l'action engagée n'est pas alignée avec l'actuelle : `{action, targetZone, areaId, urgency, generation, holdUntil = now + 120–300 s}`, et pousse l'action dans l'historique de 6 entrées (`77707-77754`).
- Effet : pendant 2 à 5 minutes après que Red s'est engagé quelque part, les actions du même secteur passent sans encombre et les actions ailleurs doivent gagner un tirage pondéré contre elles.

## 6. Construction d'une opération : doctrine, package, feinte, réserve

### Mécanisme (lu en entier : `89947-90128`, `87409-87527`, `87630-87890`, `88018-88085`)

- **Taille du package.** `_currentPackageMaximum(players) = max(configured air capacity, min(6, max(1, 2 + floor(players/2)))) − strategic bomber cost` (`85639-85649`).
- La « capacité aérienne configurée » en PvE vaut `CAP + CAS + SEAD + RUNWAYSTRIKE limits (+1 if CAS > 0)` (`85619-85623`).
- Les limites de rôle sont les fonctions globales de difficulté/nombre de joueurs `getCapLimit(bluePlayers)`, `getRedCasLimit`, `getRedSeadLimit`, `getRedRunwayStrikeLimit`, `getRedAntiShipLimit(redCasPlayers)` (`85517-85527`) ; ces fonctions sont décrites dans `03-ai-groups-sorties.md` section 3.
- `playerCount` pour la planification de Red est `getRedCasPlayersCount()` (`95852`).
- La posture aérienne réduit ensuite la taille (section 7) (`94563-94567`).
- **Doctrine.** Si la cible a été capturée par Blue dans `captureReactionWindowSec`, la doctrine est `counterattack` (`87411-87413`).
- Sinon, tirage aléatoire pondéré parmi les doctrines réalisables (`87456-87489`) :
  - `suppression` si la cible a des cibles SEAD, que la limite SEAD est > 0 et qu'un groupe SEAD existe ;
  - `isolation` si la cible a une piste, que le soutien aérien de piste de Blue vaut quelque chose et qu'un groupe de frappe de piste existe ;
  - `ground_push` si des groupes d'artillerie ou de surface existent, qu'un groupe de supply existe et que le « supply d'exploitation » est prêt ;
  - `counterattack` si la stratégie est `counterpunch` avec de la pression des joueurs, ou si l'intention de la région le demande ;
  - `air_assault` si un groupe CAS, CAP ou anti-navire existe ;
  - `probe` toujours.
- Le poids de chaque doctrine = base (1 pour `probe`, 3 pour les autres) × performance apprise bornée à [0,75 ; 1,35] ÷ pénalité de répétition issue de `history` × biais situationnel (1,75 quand sa précondition est forte, plus des bonus de stratégie) (`86853-86888`, `87432-87454`).
- **Pools.** `_collectExactRouteGroups(targetZone, …, planningInventory)` renvoie des listes de candidats par rôle : `CAP`, `CAS`, `SEAD`, `RUNWAYSTRIKE`, `ANTISHIP`, `ARTY`, `SURFACE`, `SUPPLY` (`86313-86571`, lu en entier à la deuxième passe ; noms des pools aussi en `94316`, `87471-87479`).
- Un candidat est un groupe ou une capability dormant(e) du camp, issu(e) d'une zone source utilisable, pas déjà dans une opération, pas boutique seule, pas une attaque terrestre de joueur, dont le `targetzone` est cette zone (« route exacte ») **ou**, pour les rôles aériens Red re-taskables, un groupe aérien `attack` pas encore re-taské situé à moins de la distance de retask de la cible (« route de retask ») (`86343-86386`).
- Filtres par rôle : CAP seulement si la cible est « pertinente pour la CAP » (joueurs) et que ses conditions le permettent ; SEAD seulement si la cible a des cibles SEAD et, pour les avions Red, que la source a une route SEAD dégagée ; frappe de piste seulement sur une base aérienne hors délai de recharge ; ARTY et SURFACE seulement si la route de convoi n'est pas bloquée ; SUPPLY pas depuis une zone suspendue (`86388-86432`).
- Chaque candidat porte `{sourceZone, graphHops, corridorReuse, battlefieldRisk, battlefieldSuccess, currentThreatPenalty, retasked, distanceNm, approachAxis}` ; `currentThreatPenalty = min(90, 36 × current Blue SAM exposure of the straight route)` (jusqu'au point d'ingress pour le SEAD), `approachAxis` est le relèvement source-cible par secteurs de 45° (`86434-86541`, `71042`).
- Les pools sont triés : routes exactes avant routes de retask, puis par `30 × min(8, graph hops) + battlefield risk + current threat − battlefield success` croissant, puis par corridor source le moins réutilisé (`86551-86566`).
- Les résultats par paire source/cible sont mémoïsés dans l'inventaire de planification pour toute la passe (`86434-86463`, `86492-86503`).
- **Remplissage des rôles (Red).** Une CAP est prise en premier quand la CAP est permise et que le package a plus d'une place (`87725-87737`) ; une CAP d'« escorte après perte de SEAD » peut être ajoutée (`87738-87749`).
- Puis les rôles sont tirés un par un, par tirage aléatoire pondéré dans `RED_PACKAGE_ROLE_CHOICES`, jusqu'à ce que le package soit plein ou que plus rien ne soit disponible (`87750-87835`).
- Poids d'un rôle = poids de la table de doctrine (`RED_PACKAGE_ROLE_WEIGHTS`, `71066-71073`) × √(role limit) × résultat de rôle appris [0,8 ; 1,2] × multiplicateur d'armes combinées × multiplicateur de renseignement de champ de bataille ÷ (1 + 1,5 × déjà sélectionnés) (`87769-87780`).
- Multiplicateurs situationnels : SEAD ×1,8 avec des SAM à longue portée sinon ×1,3 ; CAP × (1 + min(1,5, playerPressure/120)) ; CAS × (1 + min(1, built/12)), et avec des SAM à longue portée les hélicoptères ×1,4 et les avions ×0,55 (`87781-87792`).
- Le SEAD n'est éligible que si la cible a des cibles SEAD ; une frappe de piste seulement si la cible a une piste, que la frappe « vaut la peine », qu'aucune n'est déjà sélectionnée, et qu'un SEAD est déjà dans le package quand des SAM sont présents (`87760-87764`).
- SEAD, CAP et frappe de piste appartiennent à la phase `shape` ; le CAS (avion ou hélicoptère) et l'anti-navire à la phase `assault` (`71074-71081`).
- **Partie terrestre.** Un budget terrestre par doctrine (`suppression` 1, `isolation` 0, `air_assault` 1, `counterattack` 2, `ground_push` 2, `probe` 0) plus un extra d'« opportunité » issu de la tension sur les pistes, de la pression des joueurs et du nombre de joueurs, plafonné à 4, est rempli avec `SURFACE`/`ARTY` par tirage aléatoire pondéré (`87837-87890`, `71082-71093`).
- **Feinte / axe secondaire.** Avec ≥ 4 joueurs et un package de ≥ 4, avec une probabilité de `min(70, 25 + 10 × (players − 4))` %, un CAS (sinon une CAP) est envoyé contre une autre candidate située à au moins 3 sauts de graphe ; le gros du package est alors retardé de 240 à 420 s (`90030-90083`, `87492-87527`).
- Avec ≥ 6 joueurs, la feinte préfère un secteur différent (×1,35) (`87496-87508`).
- **Réserve.** Pour les packages hors réaction et hors probe d'au moins 3 groupes aériens dont ≥ 2 attaquants principaux, avec 35 % de chances, un CAS d'assaut est gardé comme réserve conditionnelle, au plus tôt après 120 à 240 s et au plus tard (repli) après 360 à 720 s (`88027-88085`).
- Si aucun attaquant n'a pu être affecté, l'opération est abandonnée ; si seule une CAP a pu être affectée, la doctrine est rebaptisée `probe` (`90111-90116`).
- Les affectations `SUPPLY` ne sont jamais lancées par l'opération : elles sont annulées avec la raison `regular-supply-owned`, le supply appartenant au système de supply régulier (`91826-91827`).

### Notes de reproduction

- L'enregistrement d'affectation est l'objet central : `{name, groupRef, role, capacityRole, phase, targetZone, sourceZone, unitCategory, authorized, launched, completed, cancelled, detached, reserveHeld, …}` (champs vus en `95979-95987`, `91782-91910`).
- Tout est tirage aléatoire pondéré avec départage déterministe des égalités, jamais arg-max : la même situation produit des packages différents.

## 7. Posture aérienne (dimensionnement des packages de Red selon les pertes et l'état des pistes)

Lu en entier : `71149-71441`.

- Chaque fois que le maintien de la posture précédente expire, Red choisit l'une de quatre postures selon un score, en tirant au hasard (pondéré par le score) parmi celles situées à moins de 66 % du meilleur score (`71396-71414`, `71151`).
- `conserve` : `35 + lossRatio×220 (+80 if < 40 % CAP serviceable) (+40 if a bomber or mass attack is running) + runwayStrain×130` (`71349-71353`).
- `disperse` : `65 + 4×players + 30×fronts(max 5) + 50×lossRatio + 115×runwayStrain + 10×affected runway areas` (`71356-71361`).
- `pressure` (exige ≥ 30 % de serviceable) : `70 + 7×players + 60×serviceable + min(40, 0.1×maxPressure) − 100×lossRatio − 30 if strategic conflict − 65×runwayStrain` (`71362-71368`).
- `concentrate` (exige ≥ 4 joueurs, ≥ 65 % de serviceable, 1 à 2 fronts, aucune opération en cours) : `80 + 8×players + 80 (one front) or 35 + 70×serviceable − 140×lossRatio − 140×runwayStrain` (`71369-71376`).
- Durées de maintien : conserve 8 à 14 min (et aucune opération pendant les 2 à 5 premières min), disperse 6 à 10, pressure 7 à 12, concentrate 9 à 15 (`71152-71162`).
- Effet sur la taille de la prochaine opération, avec `playerScaled = min(6, max(1, 2 + floor(players/2)))` : conserve ≤ 2 ; disperse entre la moitié et `playerScaled` ; pressure entre `playerScaled` et `playerScaled + 2` ; concentrate entre `max(4, playerScaled + 2)` et `playerScaled + max(2, 0.75×players)` ; moins la CAP de routine déjà en l'air ; la taille finale est un tirage uniforme dans cette plage (`71179-71206`).
- `lossRatio` = max(slots de CAP en refroidissement après une perte au combat, score de pertes aériennes récentes ÷ 80) ÷ total des slots de CAP (`71233-71246`).
- `runwayStrain` croît avec les pistes Red bloquées, leur importance et la pression (`71271-71275`).

## 8. Phases de l'opération, autorisation de lancement, réévaluation, fin

### Phases (lu en entier : `94643-94735`, `91774-92109`)

- `shaping` : autorise aussitôt les affectations `feint` et, à partir de `mainAuthorizeAt`, les affectations `shape` (SEAD, CAP, frappe de piste) ; passe à `assault` quand la couverture CAP est active et que les phases feint et shape sont « réglées » (tout est lancé ou terminé), ou à l'échéance de 720 s ; si l'échéance passe sans couverture CAP, l'opération est « confinée » (`94696-94713`).
- `assault` : autorise les affectations `assault` (CAS, anti-navire, surface, artillerie), éventuellement avec le CAS bloqué par le verrou SEAD ; passe à `exploit` quand la cible devient neutre ; échoue quand tous les groupes de combat sont terminés ou à l'échéance (`94714-94726`).
- L'échéance d'assaut est `assaultMaxSec` plus une marge de temps de trajet : la plus longue distance source-cible des CAS non lancés à 120 kt (hélicoptère) ou 350 kt (avion), plafonnée à un autre `assaultMaxSec` et par `operationMaxSec` (`91983-92006`).
- `exploit` : 900 s pour laisser une capture se produire ; se termine en `captured`, `neutralized` ou `failed` (`94727-94733`).
- À tout moment : cible inactive/cachée/suspendue → `aborted` ; cible désormais Red → `captured` ; âge ≥ 3600 s → `neutralized` ou `failed` (`94662-94674`).
- `surge` (attaque de masse) attend simplement la fin de la mission d'attaque de masse externe et lit le camp de la zone (`94646-94661`).

### Autorisation de lancement

- « Autoriser » une affectation ne spawne rien : cela met `assignment.authorized = true`, vide le cache d'évaluation de spawn du groupe et son délai dormant, et réveille son FSM (`91897-91909`, `82650`) ; le spawn proprement dit est celui du `GroupCommander`, qui interroge `allowsGroupSpawn` (`96017-96021`).
- Une affectation est refusée à ce tick (laissée non autorisée) quand : la frappe de piste attend le SEAD (`91828`), l'opération attend sa CAP (`91832`), le SEAD attend une CAP d'ingress (`91836-91837`), le rôle est bloqué par le verrou SEAD/CAS (hélicoptères exemptés) (`91841-91843`), aucun slot de rôle n'est libre (`91847-91849`), ou un autre groupe de surface a déjà été autorisé à ce tick depuis la même zone source (`91860-91862`).
- Une affectation est annulée quand la cible de la feinte est devenue inutilisable, que la zone d'origine n'est plus utilisable, ou que la cible d'une CAP d'attaque n'est plus « pertinente pour les joueurs » (`91786-91800`, `91819-91825`).
- **Verrou SEAD/CAS** (`_updateSeadCasGate`, lu en entier : `88955-89030`, `88456-88599`), Red seulement, en `shaping` et `assault`, réévalué toutes les `SEAD_CAS_GATE_RECHECK_SEC` = 30 s tant que l'opération a encore des CAS non lancés (`71004-71006`) :
  1. Si un SEAD du verrou est déjà en l'air, le CAS est libéré aussitôt (`88961-88963`).
  2. Menaces = sites SAM à longue portée près de la cible (`_longRangeSeadThreatsNearTarget`, 45 NM) ; s'il n'y en a aucune, le verrou est levé, tout SEAD de verrou non lancé dont la cible n'a plus de cible SEAD est annulé, et la levée est enregistrée comme preuve de rôle (`88973-88989`).
  3. Avec des menaces, le verrou bloque le CAS à voilure fixe et `_ensureSeadGateAttempt` cherche un SEAD, dans cet ordre : un SEAD du package déjà affecté sur une zone de menace ; sinon, si moins de `SEAD_CAS_GATE_MAX_ATTEMPTS` = 2 tentatives ont été faites, re-tasker un autre SEAD du package (ceux déjà lancés d'abord) sur une zone de menace ; sinon prendre un nouveau SEAD dans les pools de la zone de menace ; sinon accepter tout autre SEAD encore actif (`88456-88517`).
  4. Si aucun SEAD n'est disponible : recourir à un repli terrestre si un groupe d'artillerie ou de surface est dans le package ou peut être pris pour la cible, en annulant le CAS à voilure fixe (`sead-gate=ground`) (`88535-88565`, `89009`).
  5. Sinon, si le package a un CAS hélicoptère non lancé, annuler seulement le CAS à voilure fixe et laisser partir les hélicoptères (`89010-89029` première moitié).
  6. Sinon rediriger le package non lancé vers la meilleure candidate de l'ombre sans SAM à longue portée à proximité (pas pour une opération de réaction, une fois par opération) (`88567-88599`).
  7. Sinon confiner l'opération avec la raison `long-range-sead-<reason>` (`89028-89029`).
- Le CAS hélicoptère n'est jamais bloqué par le verrou (`91841-91843`).
- **CAP d'ingress du SEAD** (`_updateSeadIngressCapGate`, lu : `88800-88830`, `88860-88953`) : avant qu'un SEAD non lancé soit autorisé, un enregistrement `support` est construit avec le point d'ingress du SEAD et son axe de route (`88823-88830`).
  - Le verrou s'ouvre quand une CAP couvre le point d'ingress : une CAP existante à moins de `SEAD_INGRESS_CAP_COVERAGE_NM` = 30 NM (`existing`), une CAP en vol re-vectorée là et arrivée à moins de 30 NM (`revector`), ou une CAP spawnée pour l'occasion, 180 s après son lancement (`SEAD_INGRESS_CAP_SPAWN_DELAY_SEC`) (`88865-88924`, `71008-71013`).
  - Tant qu'une méthode est en cours, le SEAD reste bloqué (`88926-88929`).
  - Sans CAP obtenable : si l'ingress n'est pas « à haut risque », le SEAD est libéré sans escorte après `SEAD_INGRESS_CAP_UNSUPPORTED_DELAY_SEC` = 180 s (`seadIngressUnsupported`) ; s'il est à haut risque, le SEAD est annulé après `SEAD_INGRESS_CAP_MAX_HOLD_SEC` = 360 s (`88931-88952`).
- **Protection CAP du package Red** (lu : `90306-90318`, `90668-90684`, `90795-90978` ; la recherche de faisabilité `90459-90540` seulement à ses extrémités) :
  - Elle s'applique quand le package a encore des attaquants à voilure fixe non lancés et que le score de **menace aérienne** des joueurs sur la cible est > 0 (`90306-90318`).
  - La couverture CAP devient alors requise pour l'opération, et `_redPackageCapFeasibility` cherche une CAP dans cet ordre (`90459-90562`, lu en entier) :
    1. une affectation de CAP non lancée déjà réservée pour le package (CAP d'attaque, au hangar ou en préparation, détenant un slot `operation`) (`90438-90457`, `90466-90475`) ;
    2. une CAP d'attaque déjà en l'air qui peut couvrir la cible ou y être re-routée (`_redPackageAirborneAttackCap`) (`90477-90489`) ;
    3. sinon, si la limite de rôle CAP est > 0, la candidate de CAP d'attaque au hangar pour cette cible dont le temps de hangar restant est le plus court et au plus `RED_PACKAGE_CAP_ACCELERATION_MAX_SEC` = 5 min, et qui passe l'éligibilité au spawn (`90491-90509`, `90404-90413`, `71054`) ;
    4. plus un slot `attack` : un slot libre, ou un slot en refroidissement après une perte au combat dont le plancher de récupération tombe dans le même horizon de 5 min, ou un permis de routine récupérable (`90511-90540`).
  - Engager le candidat (`_redCommitPackageCapFeasibility`) loue le slot avec le type `operation` même pendant son refroidissement, enregistre `redPackageCapRecoveryReadyAt`, et compte comme la seule « accélération » permise à l'opération quand un minuteur a dû être raccourci (`90702-90757`, `90541-90549`).
  - Si la limite de rôle CAP est 0 ou qu'aucune CAP n'est trouvée, tout CAS, SEAD et frappe de piste à voilure fixe non lancé (feintes exceptées) est annulé avec la raison `red-package-cap-unavailable` ; les hélicoptères et les groupes terrestres restent (`90862-90876`, `90966-90978`, `90668-90684`).
  - Quand la pression aérienne disparaît, la CAP de package réservée est libérée (`red-package-pressure-cleared`) (`90816-90840`).

### Réévaluation (lu en entier : `89398-89541`, `89828-89903`)

- Toutes les 90 s pendant `shaping`/`assault`, et à chaque changement de phase, mais n'agit que lorsque l'opération a au moins 180 s (`70999-71001`, `89836-89843`).
- Entrées : force de la cible maintenant par rapport à la référence (−10 % depuis le dernier regard ou −20 % depuis le début = « en affaiblissement » ; l'inverse = « en renforcement »), pertes du package, le meilleur objectif alternatif et la composante d'activité des joueurs des deux (`89408-89417`, `89442-89463`).
- « Mauvais combat » = ≥ 2 lancés et ratio de pertes ≥ 60 % (75 % pour une cible importante : score ≥ 170, piste ou revenu) sans affaiblissement (`89446-89455`).
- Preuve de redirection = une part redirigeable (non lancée) existe et soit les joueurs se sont déplacés (score joueur de l'alternative ≥ 100 et ≥ actuel + 80), soit l'alternative est meilleure d'un facteur ×1,35 ou de +80 combiné avec un mauvais combat / un renfort / la perte de la candidate actuelle (`89458-89469`, `71002-71003`).
- Une redirection exige la même alternative sur 2 réévaluations consécutives, n'est permise qu'une fois par opération et jamais pour une opération de réaction ; elle ne re-cible que ce qui peut être re-taské (`89861-89891`).
- `_redirectOperationUnlaunched` (lu : `89608-89700`, `89760-89813`) : une affectation peut suivre si c'est un groupe aérien `attack` dormant non lancé d'un rôle re-taskable dont la source est encore utilisable et dont le rôle convient à la nouvelle cible (le SEAD exige des cibles SEAD là-bas et une route source dégagée, une frappe de piste exige une piste hors délai de recharge, une CAP exige une cible pertinente pour les joueurs), ou un SEAD en vol qui peut être re-routé avec `EngageSeadMission` ; le reste est annulé en `reassessment-redirect-incompatible`, et les groupes lancés sont marqués `detached` (ils terminent leur ancienne sortie hors de l'opération) (`89608-89643`, `89682-89700`, `89760-89771`).
- L'opération redémarre alors ses horloges sur la nouvelle cible : `originalTargetZone` conservé, `redirectCount + 1`, début de phase et échéances recalculés, référence de réévaluation, verrou SEAD et protection CAP du package réinitialisés ; la feinte est abandonnée (`89773-89805`).
- Si rien ne peut suivre, la redirection renvoie 0 et l'appelant retombe sur « contain » (`89656-89665`).
- Sinon « contain » : annuler tout ce qui n'est pas lancé et terminer avec le résultat `contained`, quand les attaquants principaux sont épuisés sans progrès ou que le combat est mauvais (`89893-89901`, `89814-89826`).
- La réserve est libérée sur « affaiblissement de la cible » ou « pression des joueurs » (score joueur ≥ 100 avec des pertes < 50 %), ou comme « vague retardée » à l'heure de repli ; elle est annulée (« conservée ») sur un mauvais combat (`89471-89478`, `89905-89945`).

### Fin d'opération et apprentissage (lu en entier : `92026-92109`, `89369-89396`, `86853-86904`, `73295-73364`, `88110-88129`)

- Un résultat `failed` est promu d'après la part détruite de la force initiale de la cible : reste ≤ 10 % → `near-complete`, détruit ≥ 25 % → `partial`, ≥ 10 % → `incomplete` (`88110-88129`).
- Le résultat d'apprentissage est `success` (capturée), `partial` (neutralisée, near-complete, partial, ou « progrès significatif »), `failure` (« engagé, sans progrès »), ou rien quand aucun élément d'attaque n'a été lancé ou que le déploiement était incomplet (`89369-89396`).
- Il est crédité, pondéré par une évaluation causale (ci-dessous), à trois compteurs à décroissance : `doctrineOutcomes[doctrine]`, `targetOutcomes[zone]` et `roleOutcomes[doctrine][role]` (`92043-92076`, `87387`).
- Les compteurs sont plafonnés à 99 et décroissent avec la demi-vie de renseignement de champ de bataille de 45 min, et expirent après 3 h (`73323-73332`, `73295-73321`, `71037-71038`).
- `_operationCausalAssessment` (lu en entier : `89244-89367`) renvoie `{primaryCause, confidence, doctrineAmount, targetAmount}` ; les deux montants règlent la part du résultat écrite dans les compteurs de doctrine et de cible :

| Résultat et preuve | `primaryCause` | Montant doctrine / cible |
|---|---|---|
| captured | `effective-execution` | 1 / 1 |
| neutralised, near-complete, partial | `effective-progress` | 1 / 1 |
| incomplete | `limited-progress` | 0 / 0 |
| failed ou contained, aucun effecteur lancé et certains non lancés | `assembly-shortfall` | `0.35 × unlaunched share` / 0 |
| failed ou contained, déploiement incomplet | `deployment-incomplete` | 0 / 0 |
| failed ou contained, pertes surtout dues aux avions | `enemy-air` | `max(0.35, 1 − 0.65 × air share of losses)` pour les deux |
| failed ou contained, pertes surtout dues aux tirs au sol | `air-defence` si une menace SAM à longue portée a été vue et jamais levée, sinon `surface-fire` | même formule avec la part au sol |
| failed ou contained, les deux types de pertes | `mixed-threat` | même formule avec la part combinée |
| failed ou contained avec progrès et ≥ 50 % de pertes | `costly-progress` | 1 / 1 |
| autrement | `unknown` | 1 / 1 |

- Ainsi un échec expliqué par une menace précise est moins imputé à la doctrine et à la cible (jusqu'à 35 %), et un package qui ne s'est jamais constitué n'est pas du tout imputé à la cible.
- Usage : poids de doctrine × clamp((success + 0.5×partial + 1)/(failure + 1), 0.75, 1.35) ; poids de rôle × (0.8 + 0.4 × (success + 0.5×partial + 1)/(total + 2)) (`86857-86860`, `86890-86904`).
- Un `history` de 3 entrées (`targetZone`, `feintTargetZone`, `sourceZone`, `doctrine`, `result`, résultat d'apprentissage et raison) pilote la pénalité de répétition et les termes d'historique de cible (`92091-92100`).
- Ensuite tous les groupes sont libérés, les instances à la demande sont mises au rebut, et le Director entre en `recovery` pour 600 à 1200 s (`92101-92108`).

## 9. Gestion de la CAP de routine et réactions aériennes défensives

Lus : `_routineCapAllocation` (`81380-81467`), début de `_reconcileRoutineCap` (`81469-81530`), `requestReactiveCap` (`72634-72753`), début de `requestPlayerCapResponse` (`81160-81215`), branche CAP de `onGroupStateChanged` (`96077-96133`), utilitaires de slot (`71926-71941`), profils de préparation après perte (`71582-71610`).
Lus aussi lors de la passe de comblement : `_advanceCapLossRecovery` (`71612-71798`), `_rankCapTargets`/`_capTargetRankAllowed`/`_routineCapTargetValue` (`80675-80874`), le cœur de sélection de `_reconcileRoutineCap` (`81530-81860`), `_routineCapRevectorTarget`/`_routineCapAwarenessTarget`/`_reconcileRoutineCapRevector` (`82044-82260`).
Lus lors de la deuxième passe : `_syncCapSlotOccupants` (`72225-72393`), la fin de `_reconcileRoutineCap` (`81860-82025`), les utilitaires de re-vectorage et la fin (`82136-82182`, `82260-82365`), `_updateRestoredCapStartup` (`81295-81378`).

### Mécanisme

- La CAP est gérée par des **slots**, pas par des groupes : les ids de slot sont `patrol:<n>`, `attack:<n>` et `reaction-<mission>:<n>` (`71926-71929`).
- À chaque tick, `_routineCapAllocation` fixe la capacité de slot à la limite de CAP de base pour `patrol` et pour `attack` (plus l'allocation de réaction sur `attack`), donc le total est `2 × baseLimit + reactionExtra` ; `baseLimit` est `getCapLimit(bluePlayers)` (`81382-81389`, `85517-85518`).
- Cela correspond au commentaire de la Config « 1 amount equals 1 CAP Patrol and 1 CAP Attack » (`Foothold Config.lua:889`).
- Les slots libres sont répartis entre `patrol` (défensif, au-dessus des zones propres) et `attack` (offensif, au-dessus des zones ennemies) par demande marginale : `demand.score / (1 + 0.85 × already allocated)`, ×1,25 tant que la limite de base n'est pas atteinte, avec un minimum d'un de chaque quand la demande est non nulle (`81410-81450`).
- Un slot a un type de bail (`routine`, `operation`, `active`), un état (`authorized`, `preparing`, active…) et un refroidissement `readyAt` (`96084-96125`, `95976`, `95995`).
- La première disponibilité d'un nouveau slot est le `respawnTimers[side][mission].hangar` du camp plus une gigue de 60 s à 25 min ; après une perte au combat, c'est `dead + hangar` plus 0 à 25 min (`71931-71941`, `71047-71048`).
- La récupération après perte s'accélère avec le nombre de joueurs, selon la difficulté (`RedReactiveDifficulty`) : easy exige ≥ 3 joueurs, 1 slot max, taux de progression 0,5, plancher 20 min ; medium ≥ 3 joueurs, jusqu'à 3 slots, taux 1 à 2, plancher 10 min ; hard ≥ 2 joueurs, jusqu'à 4 slots, taux 1,5 à 2,5, plancher 10 min (`71582-71610`) ; le taux est appliqué par `_advanceCapLossRecovery`, décrit sous « Récupération après perte » plus bas.
- Les changements d'état pilotent le slot : `preparing` → marqué en préparation ; vivant → actif ; `landed` → libéré « après remise » ; `dead` depuis un état en vol → libéré « après perte » (long refroidissement) ; `dead`/`inhangar` depuis `preparing` → libéré en `spawn-failed` avec un nouvel essai de permis à 120 s (`96093-96132`).
- Un « permis de CAP de routine » (`routineCapPermits[groupName]`) est l'élection par le Director d'un groupe précis pour un slot ; `allowsGroupSpawn` ne renvoie true pour un groupe de CAP de routine que s'il est vivant, que son slot est autorisé/en préparation, qu'il détient une affectation autorisée, ou qu'il détient un permis (`95998-96005`).
- **Arrivée d'un joueur** : quand le nombre de joueurs Blue augmente (PvE), la boucle de suivi des joueurs appelle `redDirector:requestPlayerCapResponse(now)`, qui, si aucune CAP Red n'est en l'air ou en préparation, élit la CAP au hangar la mieux classée pour la cible de CAP la mieux classée (`60801-60803`, `81160-81215`).
- **CAP réactive** : le système réactif de Red appelle `requestReactiveCap(zone, allowance)` quand des joueurs pressent une zone Red ; le Director vérifie que la zone se classe dans la fenêtre des cibles de CAP, compte les réponses disponibles, passe l'admission des actions de campagne et stocke un `aienAirSupportRequest` avec `explicitReaction=true` valable 20 min, ce qui ajoute jusqu'à `reactionCapExtra` slots à la limite de patrol (`31468`, `72634-72753`, `81501-81519`).
- **Appel de soutien aérien AIEN** : quand un avion de joueur attaque les forces terrestres d'une zone Red (signalé par AIEN via `BattleCommander:reportAIENAirSupportAttack`), au plus une fois par 20 min, avec 10 % de chances, le Director crée une demande de CAP patrol pour cette zone et Blue reçoit pendant 15 s le message "C2, intercepted enemy communications: %s has requested air support." (« C2, communications ennemies interceptées : %s a demandé un soutien aérien. ») (`71901-71905`, `72414-72456`, `70995-70997`, `Foothold_Localization.lua:21118`).
- **Le re-vectorage d'une CAP en vol** vers l'endroit où se déroule un combat aérien est limité à un ETA de 15 min et piloté par le renseignement de combat aérien (section 11) (`71030`) ; voir « Cible de vigilance et re-vectorage » plus bas.

### Classement et élection des cibles de CAP (Red, PvE)

- Le classement de base vient de l'extérieur du Director : `getClosestCapZonesToPlayers(mission, side, seed)` ordonne les zones cibles de CAP par proximité des joueurs, puis `Director:rankCapZones` les réordonne ; Blue et le PvP utilisent à la place `BattleCommander:getCapSpawnRankingForSide` (`80675-80701`).
- Chaque ligne garde son `baseRank` ; une cible n'est éligible que dans une fenêtre des `pendingNeeded` premiers rangs, élargie à 3 pour une zone adjacente à l'ennemi (`80703-80711`).
- Pour chaque cible éligible ayant au moins un candidat de CAP au hangar utilisable, `_routineCapTargetValue` additionne neuf composantes (`80753-80852`) :

| Composante | Valeur |
|---|---|
| `ranking` | le `directorPriority` porté par la ligne du classement de base |
| `rank` | `max(0, 60 − 8 × (rank − 1))` |
| `role` | rôles de secteur de la zone : hub 90, gateway 45, resource 40, defence 35, infrastructure 30, approach 15 |
| `runway` | 70 si la zone a une capability de piste |
| `income` | `min(60, 30 × income)` |
| `depth` | `min(60, 18 × friendly neighbours + 12 × enemy neighbours)` |
| `strategy` (CAP d'attaque) | `min(220, 0.35 × strategic-shadow score of the zone)`, sinon `_regionTargetPreference(zone, 'ATTACK_SUPPORT')` |
| `strategy` (CAP patrol) | proximité de l'objectif principal de l'ombre (100 à 0–1 saut, 55 à 2, 25 à 3) et de l'objectif secondaire (55 / 30 / 15) |
| `strategy` (les deux) | +150 pour la cible de l'opération en cours, +120 pour la zone d'une demande de soutien aérien active |
| `readiness` (attaque) | `(1 − readiness) × 70`, readiness = min(efficiency de supply, ratio de construction) de la zone |
| `readiness` (patrol) | `(1 − readiness) × (90 if important, else 40 if it has a friendly neighbour) − (1 − readiness) × (160 if isolated, 90 with one friendly neighbour, else 40)` |
| `intelligence` (patrol) | valeur de protection du supply issue de la mémoire du champ de bataille, + `min(120, 0.75 × awareness pressure)` sur la cible de vigilance actuelle |

- « Important » veut dire hub, gateway, resource, infrastructure ou piste (`80800`).
- La ligne porte aussi un facteur `overcommit` : `clamp((1 − readiness) × isolation − 0.25 if important, 0, 1)` avec isolation 1 / 0,55 / 0,20 pour 0 / 1 / plus de voisins amis, et une clé `front` (région, sinon secteur, sinon la zone ; les zones isolées à moins de 2 sauts partagent un front) (`80847-80850`, `80713-80719`, `81716-81724`).
- Au plus `max(4, 3 × pendingNeeded)` cibles sont valorisées, en inspectant au plus trois fois ce nombre de lignes classées (`81641-81642`, `81730-81741`).
- L'élection se fait par valeur marginale : `(score + placement intelligence) / (1 + targetCount × (0.85 + 1.25 × overcommit) + 0.22 × frontCount)`, ×1,15 pour une cible sans CAP pour l'instant, ×1,20 pour un front qui n'en a aucune, ×1,04 si un permis existe déjà (`81762-81775`).
- Dans la cible choisie, le groupe candidat obtient `−6 × its rank − 30 × CAPs already taken from its origin zone`, +45 s'il détient déjà un permis, +1000 s'il est le remplaçant nommé (`81779-81797`).
- **Une nouvelle autorisation par mission et par tick** (`newAuthorizations < 1`), donc les lancements de CAP sont espacés d'au moins 30 s (`81757`).
- Un candidat de patrol Red dont la zone d'origine a des joueurs Blue à proximité (`BlueIsNear`, ou `BluePlaneIsNear` pour les avions) n'est pas utilisé, sauf si la cible est une cible de réaction ; une CAP d'attaque peut alors être empruntée comme patrol (`81658-81664`, `81698-81715`, `81799-81810`).
- Un permis dont le slot reste `authorized` au-delà de son échéance sans que le groupe atteigne `preparing` est retiré, le slot libéré en `authorization-timeout` et le groupe mis en refroidissement de `capPermitRetrySec` = 120 s (`81530-81554`).

- Après l'élection (`81864-81915`) : une CAP d'attaque empruntée comme patrol est re-taskée (`_retaskGroupForAssignment`) ; un slot est loué avec le type `routine` et marqué autorisé ; une instance de capability à la demande est autorisée à spawner ; un candidat dont le minuteur de hangar n'a pas expiré est avancé (`_redReactiveFastForwardGroup`) quand il sert une cible de réaction ; le permis `{name, groupRef, mission, targetZone, grantedAt, slotId}` est enregistré.
- Une demande de soutien aérien active est ensuite liée aux groupes sélectionnés les plus proches, jusqu'à son `requestedAllowance` (`81939-81966`).
- Les permis non resélectionnés à ce tick sont libérés : leur slot `routine` est libéré (`permit-released`, sans refroidissement), un groupe re-taské retrouve sa cible d'origine, et son instance à la demande est mise au rebut (`81968-82008`).
- Le résultat est conservé dans `routineCapState[mission] = {limit, active, operationPending, pending, targets}` pour inspection (`82013-82024`).

### Synchronisation des slots (`_syncCapSlotOccupants`)

- Elle réconcilie les slots avec ce que font réellement les groupes de CAP, en deux passes (`72225-72393`).
- Passe 1, chaque slot qui a un propriétaire : l'état du propriétaire décide de l'état du slot et du type de bail : vivant → `active` ; `preparing` → `preparing` ; détenant une affectation d'opération non terminée → `authorized` ou `reserved` avec le bail `operation` ; détenant un permis → `authorized` avec le bail `routine` (`72226-72266`, `72292-72312`).
- Le slot est libéré quand le propriétaire a `landed`, a signalé la libération de son slot au retour à la base, est en retour à la base en vol depuis plus de `CAP_RTB_SLOT_RETENTION_MAX_SEC` = 20 min, ou ne correspond à aucun des états ci-dessus (`72227-72237`, `72313-72326`, `71031-71032`).
- Un slot laissé `authorized` avec un bail routine dont le propriétaire est revenu `inhangar` sans permis voit son permis recréé (`72272-72291`).
- Un slot `authorized` reçoit une échéance de `capPermitRetrySec` = 120 s (`72307-72310`).
- Passe 2, chaque groupe de CAP du camp sans slot mais dans un état occupant en loue un ; à la toute première synchronisation après le démarrage ou une restauration, si aucun n'est libre, un slot supplémentaire **désactivé** est créé afin qu'une patrouille déjà en l'air soit quand même comptée (`72330-72390`).

### Démarrage de la CAP après une restauration (`_updateRestoredCapStartup`)

- Après la restauration d'une sauvegarde, Red ne relance pas aussitôt sa CAP de routine : le démarrage est suspendu tant qu'aucun joueur Blue n'est connecté, et le temps de pause est rajouté à chaque échéance (`81295-81313`).
- Au premier tick avec un joueur, il tire un délai de patrol de 0 à 2 min et un délai d'attack de 2 à 5 min (au moins 2 min après celui de patrol), dans une fenêtre de `RESTORED_CAP_STARTUP_WINDOW_SEC` = 10 min (`81315-81335`, `71049-71053`).
- Par mission : si une CAP de cette mission est déjà utilisée, le rôle est `covered` ; sinon, une fois son délai passé, il appelle `requestPlayerCapResponse(now, mission, true, usage)` pour élire un groupe ; une demande non honorée sous 120 s est retentée ; à la fin de la fenêtre, le rôle est `unavailable` (`81337-81366`).
- L'enregistrement de démarrage est supprimé quand les deux rôles ont un statut (`81368-81375`).

### Récupération après perte (`_advanceCapLossRecovery`, Red PvE)

- Elle ne touche que les slots `attack` qui sont en `cooling` après une `combat-loss`, n'ont pas de propriétaire et ne sont pas des slots de réaction (`71690-71697`, `71719`).
- Elle exige un instantané d'activité des joueurs de moins de 15 s, une limite de CAP de base non nulle, au moins `minPlayers` joueurs humains et une pression de front non nulle (`71632-71670`).
- Exception avec zéro joueur : si une CAP IA Blue est en l'air, que Red n'a aucune CAP en l'air et qu'un CAS ou SEAD Red est en l'air, un slot est avancé au taux de base, à condition qu'aucun slot de CAP ne soit disponible par ailleurs (`71645-71678`).
- `tier = max(1, floor(players / playersPerSlot))` ; slots avancés par tick = `min(maxSlots, tier)` ; `rate = min(maxProgressRate, baseProgressRate + (tier − 1) × progressRatePerTier)` (`71680-71687`).
- Les slots sont choisis là où la mission d'attack est en deçà de son allocation, n'a aucun slot prêt et a de la demande ; `readyAt` le plus proche d'abord (`71728-71781`).
- Le `readyAt` de chaque slot choisi est avancé de `elapsed × rate` secondes (elapsed depuis le dernier tick, plafonné à 2 ticks), sans jamais descendre sous son `lossRecoveryFloorAt` (`71783-71793`).
- Ainsi, avec des joueurs qui pressent le front, une CAP d'attaque perdue revient jusqu'à `1 + rate` fois plus vite, jusqu'au plancher du profil de difficulté.

### Cible de vigilance et re-vectorage

- À chaque tick, Red calcule une zone de « vigilance » : une demande de remplacement en attente s'il y en a une, sinon la zone d'une demande de soutien aérien AIEN active (pression 100), sinon la première zone Red classée en patrol avec une activité aérienne de joueurs (score `capOnly` plus `min(cap, 0.30 × retained player intent)`) ou avec une réponse récente à une perte aérienne au-dessus du seuil (`82044-82118`).
- Une zone moins bien classée ne peut la remplacer que si elle a du renseignement de combat aérien et que `pressure + intelligence − rank step × rank difference` est plus élevé (`82066-82081`).
- `_reconcileRoutineCapRevector` choisit une station près de cette zone (`Frontline.PickStationNearZone`, décalage de 30 NM, distance de sécurité de 35 NM) et ne fait rien si une CAP Red la couvre déjà à moins de `capAssistCoverageNm` = 30 NM (puis un refroidissement de 300 s par cible) ou si un permis de patrol la vise déjà (`82121-82230`, `8517-8520`).
- Sinon il cherche la meilleure CAP en vol à re-vectorer (`_bestIngressCapRevector`) ; si son ETA dépasse `CAP_ROUTINE_REVECTOR_MAX_ETA_SEC` (15 min), il tente à la place un remplaçant prêt depuis un hangar, et pour une demande AIEN signale `needsReserve` (`82232-82260`, `71030`).
- La décision est différée : un re-vectorage en attente est armé avec un délai aléatoire entre `capAssistDelayMinSec` = 120 s et `capAssistDelayMaxSec` = 300 s, et n'est exécuté que si la même cible est encore la cible de vigilance à ce moment-là (`82274-82293`, `8518-8519`).
- Re-vectorage : la CAP en vol reçoit une nouvelle tâche CAP à la station avec une distance d'orbite de 30 à 40 NM (`_assignCapTask`), est marquée `_capAssistRetaskedTargetzone`, et la cible ainsi que tout le mécanisme passent en refroidissement de 300 s (`82330-82357`).
- Remplacement : la CAP donneuse, éloignée, est renvoyée à la base (`_startCapReturnHome`) et un `routineCapReplacementRequest {targetZone, preferredName, pressure, expiresAt = now + 20 min}` fait préférer par l'élection le groupe de hangar nommé (+1000) (`82296-82322`, `71031`).
- Test de couverture : une CAP Red en l'air, qui ne rentre pas, dont le point d'attente est à moins de la distance de couverture de la station (`82136-82151`).
- Quand la génération des cibles de CAP change, chaque CAP re-vectorée dont la cible de re-task n'est plus utilisable est renvoyée à la base (`82153-82182`).
- Le **Hunter** (un binôme scrambled après une série de kills d'un joueur) et le tirage de l'intercepteur de bombardier stratégique sont des mécanismes distincts hors du Director (voir `03-ai-groups-sorties.md` sections 8 et 12).

### Notes de reproduction

- L'abstraction en slots est ce qui maintient stable le nombre de vols de CAP quand des groupes meurent, sont re-taskés ou sont empruntés par une opération ; une réimplémentation qui ne compterait que les groupes vivants oscillerait.
- Le classement des cibles de CAP (`getClosestCapZonesToPlayers`, `CapTargets`, `CapRef`) vit hors du Director et est partagé avec `GroupCommander` (`85685`, `72668-72672`).

## 10. Libération au sol (convois et artillerie)

Lu en entier : `85257-85476`, `84922-84932`, `85184-85210`, branche terrestre de `onGroupStateChanged` (`96035-96073`).

- Ne tourne que pour Red, toutes les `groundDecisionSec` = 90 s (`85420-85423`).
- Limites selon le nombre de joueurs CAS de Red : `SURFACE` 1 (≤ 2 joueurs), 3 (≤ 5), 4 (au-delà) ; `ARTY` 2 (≤ 5 joueurs), 3 (au-delà) ; une artillerie par cible (`84922-84932`, `85277`).
- Les candidats sont tous les groupes de surface/artillerie ou capabilities passives dont la zone d'origine est utilisable et dont la cible figure dans la liste courante des cibles offensives, non bloqués par `IsGroundConvoyBlocked(source, target)` (`85312-85326`, `85281-85287`).
- Score = le score offensif de la cible, +35 si la cible n'a pas encore d'engagement terrestre, +20 si la source n'en a pas, −70 par engagement sur la cible, −40 par engagement depuis la source, −90 par engagement sur la même paire, −0,35 × distance (NM, plafonnée à 180), −6 × sauts de graphe (plafonnés à 8), +80 si c'est la cible de l'opération en cours, moins des pénalités d'historique sur les 8 dernières libérations (`85184-85210`, `84898`).
- Seuls les 12 meilleurs sont testés pour une vraie éligibilité au spawn et au plus 6 sont présélectionnés ; les candidats `SURFACE` perdent une pénalité pour la présence actuelle de joueurs à moins de 25 NM de leur route (max 180) (`85432-85447`, `84899-84900`, `71043-71044`).
- La libération est probabiliste : chance = 1 quand rien n'est engagé, sinon `clamp(0.25 + 0.35 × targetSignal + 0.30 × min(1, players/9) − 0.20 × workload, 0.10, 0.90)` ; puis un tirage pondéré parmi les trois premiers (`85337-85370`).
- Autoriser crée un **permis au sol** valable `groundPermitTimeoutSec` = 12 min, instancie la capability si besoin et réveille son FSM ; une zone source suspendue reçoit `_suspendAllowSpawn` (`85372-85417`).
- Au lancement, le permis est marqué lancé ; en cas d'échec de spawn, il est libéré avec un nouvel essai à 120 s ; à la fin de la sortie, un refroidissement de réutilisation est posé et une instance à la demande est mise au rebut (`96049-96072`).

## 11. Mémoires de renseignement (« apprentissage » du champ de bataille)

Lus : début de `_consumeAirCombatIntelligence` (`72928-72990`), constantes (`71018-71046`), début de `_playerFrontlineActivityScores` (`75689-75760`), décroissance des résultats (`73295-73364`).
Lus aussi lors de la passe de comblement : le corps du calcul de `_playerFrontlineActivityScores` (`75760-75990`), `_recordBattlefieldSortieOutcome` et les faits de risque de route (`73442-73530`), `_battlefieldPackageRoleMultiplier` (`73686-73698`), le multiplicateur de difficulté (`73248-73260`), `BattleCommander:_redReactiveBuildPressureByPlayers` (`31205-31292`).
Lus en entier lors de la deuxième passe : `_consumeBattlefieldIntelligence` (`74135-74309`), l'instantané de cible, les fonctions de placement de CAP, de protection du supply et de corridor (`73547-73809`), le cycle de vie d'une sortie (`73811-73930`, `73994-74104`), `_battlefieldRouteSegment` (`73422-73440`).

- **Activité des joueurs sur le front** : un score par zone de l'endroit où se trouvent les joueurs humains et de ce qu'ils font, plus une variante de menace aérienne (`capOnly`) ; mis en cache 15 s ; il fournit aussi `humanPlayers`, `frontCount` et `maxPressure` utilisés par la posture aérienne (`75689-75705`, `75712`, `71249-71252`).
- Il est construit à partir de la liste des joueurs en rattachant chaque joueur à la zone de campagne qu'il occupe ou à la plus proche (`75717-75760`).
- Quels joueurs comptent : pour le score général, les avions et hélicoptères hors `BlueCasCountIgnoreTypes` ; pour la variante de menace aérienne (`capOnly`), les avions hors `CapCountIgnoreTypes`, et seuls ceux en vol alimentent la sortie `airThreatScores` (`75884-75908`).
- Un joueur parti d'un porte-avions et encore dans la zone du porte-avions est ancré sur la zone de campagne du porte-avions la plus proche du front et pèse `CARRIER_ORIGIN_ACTIVITY_SCALE` = 0,30 (`75765-75781`, `75909-75931`, `70994`).
- Chaque joueur ajoute un **secteur** de scores autour de sa zone d'ancrage, pas un point unique (`75782-75866`) :
  - l'ancrage est une zone ennemie (Red) : +140 dessus, +100 sur chaque zone Blue adjacente, et +70 sur toute autre zone Red adjacente à celles-ci (+40 de retour sur l'ancrage) ;
  - l'ancrage est une zone amie ou neutre : parcours en largeur à travers les zones Blue (jusqu'à 6 sauts) jusqu'aux premières zones touchant Red ; ces zones reçoivent `max(35, 110 − 20 × hops)` et leurs voisines Red 20 de plus ; seuls comptent les fronts à moins de 3 sauts, et à un saut au-delà du premier.
- Donc la pondération se fait par position dans le graphe par rapport au front, pas par type d'appareil ni par distance métrique ; tous les types éligibles pèsent pareil.
- Chaque joueur incrémente aussi `humanPlayers` et, par ancrage distinct, `frontCount` ; `maxPressure` est la plus haute somme par zone (`75868-75881`).
- Pour la variante de menace aérienne de Red, la CAP **IA** de Blue ajoute un secteur sur sa zone cible, et les sorties CAS/SEAD IA de Blue actives en ajoutent un pondéré par `min(1.5, 0.5 × CAS + 0.75 × SEAD)` (`75934-75962`).
- Pour la variante générale de Red, chaque score de zone est aussi enregistré dans une mémoire à décroissance d'« intention agrégée des joueurs », ré-injectée plus tard à 25–30 % (`75966-75972`, `72822`, `71026-71029`).
- L'entrée de cache porte une `signature` (paires `zone:score` triées) que d'autres limiteurs comparent (`75964-75980`).
- **Renseignement de combat aérien** (Config `GlobalSettings.directorAirCombatIntelligenceEnabled`, true par défaut) : les kills aériens extraits de `BattleCommander:_drainDirectorAirCombatKills()` sont rattachés à une zone à moins de 60 NM ; chaque ligne porte `redAirLoss` et `playerPressure`, a une demi-vie de 5 min, expire après 20 min et est plafonnée à 200 ; un groupe Red perdu vaut 80 (`72947-72990`, `71018-71022`, `Foothold Config.lua:433-436`).
- Sa somme `airCombatRecentLossScore` alimente le ratio de pertes de la posture aérienne (`71238-71239`).
- **Renseignement de champ de bataille** (Config `GlobalSettings.directorBattlefieldIntelligenceEnabled`, true par défaut) : lignes par route pour les sorties aériennes (`source|target|role`) et les routes de supply (`source|target|mode`) consignant les résultats de sortie, avec une demi-vie de 45 min, une expiration à 3 h, au plus 128 lignes, valeurs plafonnées à 200 (`73261-73267`, `71037-71041`, `Foothold Config.lua:428-431`).
- Le commentaire de la Config énonce son contrat : il ne fait que biaiser la planification ; il "does not add groups, force launches, bypass cooldowns, or block a route" (« n'ajoute pas de groupes, ne force pas de lancements, ne contourne pas les refroidissements et ne bloque pas de route ») (`Foothold Config.lua:428-430`).
- Ses utilisateurs dans le code lu : les poids de rôle dans le package (`87779`), le risque d'escorte SEAD (`87661-87662`), la valeur de placement de CAP et les demandes de protection du supply (ci-dessous ; la valeur de placement de CAP est ajoutée au score de cible de CAP en section 9).
- **Cycle de vie d'une sortie alimentant la mémoire** : quand un groupe géré spawne (ou qu'un groupe de surface entre dans un état vivant), `_registerBattlefieldSortie` enregistre une sortie `{sourceZone, targetZone, role, mode}` indexée sur le groupe DCS et les noms de ses unités ; les rôles suivis sont SUPPLY (supply régulier), CAP, CAS, SEAD, RUNWAYSTRIKE, ANTISHIP, et SURFACE/ARTY quand ils appartiennent à une opération ; le mode est `surface`, `helicopter` ou `airplane` (`73811-73828`, `73912-73930`, `73994-74010`).
- Quand le groupe passe `dead` ou retourne `inhangar`, le résultat est mis en file : `dead`/`inhangar` s'il s'était déployé, `aborted` sinon ; la file est bornée à 128 entrées (`74011-74022`, `74084-74104`).
- `_consumeBattlefieldIntelligence(events, now)` tourne à chaque tick sur les événements de kill extraits du `BattleCommander` : un kill par une sortie suivie sur un aéronef ajoute un `airKills` ; un kill **d'**une unité d'une sortie suivie met son `lastLossCause` à `air` (le tueur est un aéronef Blue) ou `ground` (unité terrestre ou navire Blue) et stocke le point de perte (`74273-74302`).
- Finaliser une sortie transforme cela en résultat de route : `air-loss`, `ground-loss`, `unattributed-loss` (mort sans tueur connu), `safe-return` (ou `returned` pour le supply), sinon `aborted` ; les kills aériens de la sortie sont ajoutés à la ligne de route, et l'affectation d'opération reçoit `airKills` et `lossCause`, que lit l'évaluation causale de la section 8 (`73856-73910`).
- Une perte est classée sous un **segment** de route : `source` ou `target` quand elle est à moins de `BATTLEFIELD_INTELLIGENCE_ENDPOINT_NM` du centre de cette zone, sinon `corridor` (`73422-73440`).
- Par zone cible, un instantané donne `airRisk` et `groundRisk` (pertes dans le segment `target` ÷ `max(3, completed)`, maximum sur les routes) et `roleSuccess[role] = min(1, 0.75 × airKills / exposure + 0.25 × safeReturn / exposure)`, les kills aériens ne comptant que pour la CAP (`73565-73636`).
- **Valeur de placement de CAP** : patrol = activité aérienne hostile sans réponse dans la zone (`hostileAir − min(60 % of it, 0.35 × Red air successes + 0.50 × Red ground-to-air successes)`, plafond 100) `+ 50 × airRisk × difficulty` ; attack = `min(100, 100 × (0.75 × airRisk + 0.25 × CAP success) × difficulty)` (`73638-73684`, `71023`).
- **Protection du supply** : une route de supply dont le risque atteint `BATTLEFIELD_SUPPLY_PROTECTION_RISK_THRESHOLD` = 0,5 est signalée pendant 120 s, et chaque sortie de supply en cours sur une route risquée compte aussi ; la valeur est `min(80, 80 × risk × difficulty)` sur la zone cible et `min(40, 40 × risk × difficulty)` sur la source, et c'est la composante `intelligence` des cibles de CAP patrol (`73700-73758`, `71045-71046`).
- **Préférence d'offre de supply** : `(0 for aeroplane, 35 for helicopter, 50 for surface) + 100 × risk − 20 × success`, utilisée pour ordonner les offres de supply (`73760-73766`).
- **Pénalité de corridor source** pour une route aérienne : `min(90, 90 × combined risk in the source and corridor segments × difficulty)` et un bonus `min(20, 20 × role success × difficulty)` (`73768-73793`).
- En PvP, la même fonction tient aussi à jour, pour les deux camps, les lignes de combat aérien par zone (`hostileAir` +80 pour un aéronef perdu ou +45 pour un kill par un aéronef sur une unité terrestre, `redAirSuccess`/`redGroundAirSuccess` +60) (`74136-74262`).
- Une ligne de route compte les résultats par sortie : `airLoss`, `groundLoss`, `unattributedLoss`, `safeReturn` pour les routes aériennes (plus les mêmes compteurs de pertes par **segment** de route, localisés d'après le point de perte), `delivered`, `returned`, `aborted` pour les routes de supply, et `completed` (`73442-73500`).
- Faits de risque d'une route : avec `exposure = max(3, completed)`, `air = airLoss / exposure`, `ground = groundLoss / exposure`, `generic = unattributedLoss / max(4, exposure)`, `combined = min(1, 0.35 × air + 0.40 × ground + 0.25 × generic)` (`73502-73514`).
- Multiplicateur de rôle de package (utilisé en section 6) : `1 + min(0.75, (0.75 × risk + 0.25 × past success of the role on that target) × difficulty)`, où le risque est le risque aérien de la cible pour la CAP et le risque au sol pour le SEAD, 0 pour les autres rôles, et le facteur de difficulté vaut 0,65 / 1 / 1,25 pour `RedReactiveDifficulty` easy / medium / hard (`73686-73698`, `73254-73259`).
- Ainsi, des pertes passées face à des chasseurs augmentent le poids de la CAP dans le prochain package contre cette cible, et des pertes passées face à des tirs au sol augmentent celui du SEAD.
- La mémoire n'existe que pour Red en PvE (Blue seulement en PvP) (`73248-73252`).
- Les **résultats d'opération** (doctrine/cible/rôle) sont décrits en section 8.
- La **mémoire du front de campagne** et les listes d'**historique** (opérations 3, libérations au sol 8, achats stratégiques 6, actions de campagne 6) complètent la mémoire (`71879`, `84898`, `84226`, `77450`).

## 12. Réactions à l'offensive des joueurs (Red)

Lus en entier : `requestReaction` et sa file (`94279-94560`), l'appelant du tick réactif (`31715-31784`), les profils (`31055-31135`), la décision de détournement du CAS (`84482-84521`, `84736-84766`), début de `_updateDefensivePlan` (`76847-76905`).
Lus en entier lors de la deuxième passe : `_airReactionCandidates`/`_airReactionDecision` (`71443-71543`), `_defensivePlanPersistentEvidence`, `_defensivePlanBlueHint`, `_defensivePlanZoneCandidate`, `_buildDefensivePlanProposal` (`76464-76825`), `requestEnemyPositionResponse` (`72458-72556`, politique `70980-70987`), `_capturedZoneCasAssignmentFacts` (`84562-84666`).

- La boucle de **contre-pression réactive de Red** appartient à `BattleCommander` (`bc:startRedReactiveCounterpressure(RedReactiveConfig)`, `MA_Setup_CAv2.lua:6125-6127`) et est le capteur du Director : elle calcule une valeur de pression par zone Red à partir des joueurs proches et traite au plus `maxZonesPerTick` = 1 zone par tick (`31724-31742`, `31073`).
- Réaction « douce » (pression ≥ `minPressureSoft`) : renforce le supply et la CAP de la zone (`31744-31751`).
- Réaction « dure » (pression ≥ `minPressureHard`, ou capture Blue d'une zone voisine dans `captureHardWindowSec`) : demande éventuellement au Director une amélioration de zone, puis appelle `director:requestReaction({targetZone, sourceZone, reason='capture'|'pressure', allowance=hardForcePerZone, capAllowance, groupReuseCooldownSec})` (`31753-31781`, `31683-31696`).
- Profils de difficulté (`RedReactiveDifficulty`, `"medium"` par défaut, `Foothold Config.lua:438`) : seuils doux/dur 9/12 (easy), 6/9 (medium), 3/6 (hard) ; distance des joueurs 75/75/120 NM ; fenêtre de capture 120/180/240 s ; refroidissement de zone 1800/1800/900 s ; groupes forcés par zone 1/2/3 ; CAP de réaction supplémentaire 0/1/2 ; amélioration de zone désactivée/activée/activée ; soutien aérien AIEN désactivé/activé/activé ; refroidissement de réutilisation des groupes 1600/1200/900 s (`31064-31127`).
- `requestReaction` (PvE seulement) normalise la demande (priorité 2 pour `capture`, 1 pour `pressure`), demande à `_airReactionDecision` combien d'air elle peut se permettre (il renvoie une allocation, une allocation de CAP, un mode comme `limited`, et un maintien de 5 à 10 min), puis (`94475-94560`, `71443-71444`) :
  - si le Director n'est pas prêt ou qu'un surge est en cours : mise en file ;
  - si une opération vise déjà la même zone en `shaping`/`assault` : la renforcer (`_augmentReactionOperation`) ;
  - si la raison est `capture` et qu'une autre opération tourne : construire un remplacement et terminer l'opération actuelle en `redirected-by-reaction` ;
  - si inactif : construire aussitôt une opération de réaction (elle contourne `recovery` et `nextPlanningAt`) ;
  - sinon mise en file.
- La file ne contient qu'une seule demande en attente ; une demande sur la même cible augmente son allocation, une demande de priorité supérieure la remplace, et elle expire au temps de maintien de la décision aérienne (`94334-94378`, `94419-94426`).
- Une opération de réaction reçoit une `urgency` de 3 (capture) ou 2 (pression) et, pour une capture fraîche, la doctrine `counterattack` (`94443`, `87411-87413`).
- **Décision de réaction aérienne** (`_airReactionDecision`) : un tirage pondéré entre trois modes (`71446-71493`, `71519-71543`) :
  - `standdown = 110 + 220 × lossRatio + min(160, 10 × air commitments)` ;
  - `limited = 75 + 0.45 × strategicValue + min(40, 2 × players) + 30 if the reason is a capture` ;
  - `full = 30 + strategicValue + min(70, 4 × players) + 80 if capture` ;
  - `strategicValue = min(220, 0.25 × (hub + runway + income + region + strategy components of the target) + min(40, 2 × income) + 20 with an airbase)` ;
  - décalages selon la posture : conserve +80 standdown, +25 limited ; disperse +40 limited, +10 full ; pressure +15 / +20 ; concentrate +10 limited, +70 full.
- Résultat : `full` accorde l'allocation demandée, `limited` accorde 1 groupe, `standdown` en accorde 0 ; l'allocation de CAP est plafonnée par elle (`71521-71526`).
- La décision est maintenue 5 à 10 min : la même demande reçoit la même réponse, toute autre demande reçoit `hold` avec une allocation de 0, sauf une demande `capture` arrivant pendant qu'une décision non-capture est maintenue, qui est décidée à nouveau (`71496-71513`, `71443-71444`).
- **Réponse locale à une attaque sur une position** (`requestEnemyPositionResponse(zone, point, attackerKind)`, Red, appelée via `BattleCommander` en `71910`) : pour une attaque par un hélicoptère de joueur ou par de l'artillerie sur une zone Red, le Director peut envoyer un groupe à la demande de cette zone contre la position de l'attaquant.
  - Elle passe l'admission des actions de campagne comme un `local_response` avec un score de 200 et une urgency de 2 (hélicoptère) ou 260 et une urgency de 3 (artillerie) (`72468-72482`).
  - Type préféré par un jet de 1 à 100 : contre un hélicoptère de joueur, groupe terrestre 80 % / hélicoptère 20 % ; contre de l'artillerie, hélicoptère 60 % / terrestre 40 % ; l'autre type sert de repli (`70980-70987`, `72553-72555`).
  - La première capability non instanciée de ce type dans la zone qui passe l'éligibilité au spawn est instanciée sous le nom `<zone>-attack-enemy-position`, marquée `urgent`, dotée du point de réponse (et, pour un groupe terrestre, d'une route construite par `dc.BuildEnemyPositionResponseRoute`), puis autorisée (`72485-72548`).
- **Détournement du CAS sur une capture** : quand Blue capture une zone, `considerCapturedZoneCasDiversion` note chaque CAS **hélicoptère** en vol de l'opération en cours qui ne s'est pas encore engagé dans son passage d'attaque et n'a pas déjà été détourné (`84562-84575`), et la zone capturée doit contenir des cibles construites attaquables (`84577-84589`) ; il le note pour un re-task sur la zone capturée (distance, ETA, score de cible, score joueur, faiblesse de la zone capturée, carburant restant ≥ 20 %, armes d'attaque restantes ≥ 30 % du template) ; il détourne le meilleur si le score atteint 60 (`56709`, `84482-84521`, `84736-84766`, `71015-71017`).
- **Piste détruite** : `redDirector:onRunwayDestroyed(zone)` est appelée quand une piste est détruite, et les frappes de piste sur une cible refroidissent pendant 60 min (`42916`, `71014`).
- `onRunwayDestroyed` (lu : `82587-82620`) démarre le refroidissement de 60 min `runwayStrikeCooldownByTarget[zone]` pour cette zone Blue et, si une affectation de frappe de piste lancée de l'opération en cours la visait, enregistre la preuve de rôle `roleEvidenceRunwayHit` ; `_runwayStrikeTargetCooling` est ce qui rend une frappe de piste inéligible entre-temps (`82626-82637`).
- **Carte de pression réactive** (la carte que le Director lit sous le nom `battleCommander._redReactivePressureByZone`) : pour chaque joueur de combat Blue (avion ou hélicoptère hors `RedCasCountIgnoreTypes`), les trois zones Red actives les plus proches à moins de `maxPlayerDistanceNm` (distance au bord) reçoivent 3, 2 et 1 points ; les sommes par zone constituent la pression, scindée en `capPressure` (types chasseurs) et `strikePressure`, avec un drapeau `blueOccupied` pour les zones Red à l'intérieur desquelles se trouve un joueur Blue (`31205-31292`).
- Lecteurs de cette carte dans le Director : score de cible (`+ min(20, 3 × pressure)` par voisin Red, `84443-84446`), `urgency` de l'ombre (`78170-78175`), priorité de supply (`77857`), demande d'amélioration de zone (`83427`) ; sa signature est l'un des déclencheurs de reconstruction de l'ombre (`31294-31307`, `78776`).
- **Calcul du plan défensif** (`_buildDefensivePlanProposal`, `_defensivePlanZoneCandidate`) :
  - Un secteur est « actif » s'il a des preuves de dégâts persistants, une zone Red avec de l'activité de joueurs ou de la pression réactive, une zone Red voisine d'une zone capturée par Blue dans la fenêtre de réaction, ou une intention de joueurs retenue (`76724-76765`).
  - Preuve persistante par secteur : chaque infrastructure Red `defence_supply` détruite et chaque zone de défense jamais perdue compte pour un événement, ancré sur la source de l'infrastructure / le parent défensif (ou le hub ou la gateway le plus proche) ; `damage = min(60, 30 × events)` (`76464-76587`, `71061-71062`).
  - Chaque zone Red utilisable d'un secteur est notée comme la somme de (`76607-76707`) :

| Composante | Valeur |
|---|---|
| `role` | hub 70, gateway 65, infrastructure 35, resource 30, defence 25, approach 15 |
| `runway` | 55 avec une capability de piste, plus `min(95, 35 + 0.40 × player pressure)` quand cette piste est actuellement bloquée |
| `income` | `min(40, 50 × income)` |
| `position` | `min(90, 45 × Blue neighbours + 12 × neutral + 6 × Red)` |
| `frontline` | `max(0, 60 − 4 × distance to the front in NM)` |
| `vulnerability` | `max(0, 70 − 28 × own SAM cover)`, +20 sans SAM à longue portée |
| `readiness` | `(1 − supply efficiency) × 70` |
| `damage`, `anchor` | les dégâts du secteur ; `min(40, 20 × events anchored on this zone)` |
| `player` | `min(300, 0.75 × player-activity score)` |
| `intent`, `effectiveness` | `min(90, 0.45 × retained player intent)` ; `min(90, 0.75 × player effectiveness)` |
| `reactive` | `min(140, 14 × reactive pressure)` |
| `capture` | `min(240, 120 × neighbours captured by Blue within the window)` |
| `blueHint` | 35 si c'est le focus de soutien du Director Blue (15 même secteur), ou 25 / 15 pour l'objectif principal / secondaire de l'ombre de Blue (10 / 5 même secteur) |

  - La meilleure zone de chaque secteur est la candidate de ce secteur ; `primary` est la meilleure candidate parmi les secteurs actifs, `secondary` la meilleure candidate d'un autre secteur (`76766-76812`).
- **Plan défensif** : à chaque tick, Red calcule une zone primaire et une zone secondaire à défendre à partir de l'activité des joueurs, du focus d'opération du Director Blue et de l'objectif stratégique propre à Blue ; la proposition est mise en cache tant que ses entrées sont inchangées (jusqu'à 60 s), doit être tenue au moins 5 min, et un changement exige 2 confirmations (`76847-76905`, `71059-71063`).
- Le plan sert à la priorité de supply (+45 primaire, +25 secondaire) et à la liste de menaces des routes terrestres (`77872-77885`, `95875`).

## 13. Décisions économiques : budget stratégique, améliorations de zone, priorité de supply

Lus en entier : `84006-84398`, `83448-83467`, `77825-77937`, `BudgetCommander` (`96236-96289`) ; début de `selectZoneUpgradeTarget` (`83296-83330`).
Lus aussi lors de la passe de comblement : `_zoneUpgradeScore` (`83156-83231`), `_massTacticalAirstrikeDecision` (`83636-83676`), `_tacticalAirstrikeCandidates` (`83701-83781`), le planificateur d'attaque de masse (`34445-34613`, `35003-35024`), `_adoptMassAttack` (`92111-92139`).
Lus en entier lors de la deuxième passe : `_refreshStrategicAirFacts`, `_strategicBudgetFacts`, `_redGuaranteedIncomeFacts` (`83469-83552`), `_redLastStandUpgradeCost`, `_strategicBudgetUpgradePlan`, `_strategicWarehousePlan` (`83896-84004`), les sous-scores d'amélioration (`82934-83154`, `83233-83294`), la persistance de l'attaque de masse (`34812-35001`).

### Budget stratégique de Red (Director)

- Red en PvE seulement ; une décision toutes les `decisionSec` (180/120/60 s selon la difficulté), la première après 20/15/10 min (`84318-84328`, `71108-71148`).
- Cinq actions achetables, chacune étant un article de la boutique Red : `upgrade` → `redzoneupgrade`, `warehouse` → `redwarehouse`, `warehouse_repair` → `redwhrepair`, `mass_attack` → `redmassattack`, `bomber` → `strategicbomberRed` (`71099-71105`).
- Scores des candidates (`84020-84148`) :
  - `upgrade` : `(200 + min(240, 0.35 × plan score) (+400 if demanded by a reaction)) × upgradeWeight` ; considérée si demandée, ou abordable dans `saveHorizonSec` ;
  - `warehouse`/`warehouse_repair` : issues de `_strategicWarehousePlan`, seulement hors du refroidissement de dépense (choix du site plus bas) ;
  - `mass_attack` : `(260 + min(180, 0.30 × target score) + min(120, 25 × players) + min(100, 0.5 × urgency)) × massAttackWeight` ; exige qu'aucune autre action aérienne stratégique ne soit en cours, une posture autre que `conserve`, ≥ 55 % de CAP serviceable et < 55 % de pertes, le refroidissement du surge écoulé, et au moins `massMinPlayers` (4/3/2) joueurs ;
  - `bomber` : `(230 + min(180, 0.30 × target score) + 40 if runway + min(60, 15 × income)) × bomberWeight` ; exige ≥ 40 % de CAP serviceable, < 60 % de pertes et le refroidissement du bombardier écoulé.
- Une « intention » précédente pour la même action ajoute +35 (persistance) (`84013-84016`).
- Décision : acheter la meilleure candidate si elle est abordable ; sinon **épargner** pour elle si le revenu couvrira le manque dans l'horizon d'épargne (plus court pour les articles urgents) ; sinon acheter un repli abordable dont le score atteint au moins `fallbackScoreRatio` (0,75/0,60/0,45) de la meilleure ; un refroidissement de dépense de 30/20/15 min suit chaque achat (`84160-84192`, `84210-84216`).
- L'exécution passe par la boutique normale (`battleCommander:buyShopItem(side, itemId, …)`), avec des listes de cibles préférées transmises à l'attaque de masse et au bombardier ; un achat échoué bloque cette action pendant max(60 s, `decisionSec`) (`84230-84298`).
- Une attaque de masse achetée est adoptée comme opération `surge` ; le surge suivant n'a pas lieu avant 2700 à 5400 s (`84274-84276`, `92136-92137`).
- Crédits disponibles = compte moins les crédits réservés par les achats de boutique en attente (`84238-84239`).

### `BudgetCommander` (acheteur aléatoire historique)

- Une toute petite classe : toutes les `decissionFrequency` (+ une `decissionVariance` aléatoire), elle liste les articles de boutique abordables de son camp et, sauf si un jet de `skipChance` dit non, en achète un au hasard (jusqu'à 10 essais, chacun soumis à l'`aiPurchaseChance` de l'article) (`96246-96288`).
- Elle utilise le `SCHEDULER:New(nil, fn, {self}, delay, repeat)` de Moose (`96281-96288`), qui enveloppe `timer.scheduleFunction`.
- Elle s'efface devant le Director : `update` revient aussitôt si `director:ownsRedStrategicBudget()` (Director Red démarré et activé) et pour Red en PvP (`96247-96249`, `83458-83460`).
- Aucun `BudgetCommander:new` n'existe dans aucun fichier de setup de l'extrait v6.5.3 (tous les `.lua` ont été cherchés) : la classe est du code mort dans cette version.

### Améliorations de zone et priorité de supply

- `Director:requestZoneUpgrade(context)` enregistre une demande (zone de pression, zones occupées par Blue, raison, refroidissement) que le budget chiffre ensuite et planifie ; elle est appelée par le tick réactif de Red quand des joueurs frappent une zone (`31761-31771`, `83431`).
- `Director:selectZoneUpgradeTarget(zoneChoices, context, now)` est appelée par l'action d'amélioration de zone de la boutique pour choisir la zone et l'emplacement d'upgrade : elle note chaque zone candidate non occupée par Blue et située dans le « corridor d'upgrade » de la zone de pression, en utilisant un profil de défense par catégorie (`sam`, `shorad`, …) (`24130`, `83296-83330`).
- **Faits du budget** (`_strategicBudgetFacts`) : coût et stock des cinq articles de boutique, crédits disponibles après réservations, revenu de Red (somme des `income` des zones Red actives par mise à jour, donc par minute à `updateFrequency` = 10 s), CAP total / ratio de serviceable / ratio de pertes aériennes, refroidissements restants de dépense et de bombardier, et si une opération, une attaque de masse, un bombardier stratégique ou une frappe aérienne tactique est actif (`83469-83552`).
- **Quelle amélioration** (`_selectZoneUpgradeShadowRecommendation`, `83233-83294`) : les candidates sont les zones Red non occupées par Blue et, quand une zone de pression est donnée, les voisines terrestres de la zone de pression (pas la zone de pression elle-même) (`82934-82939`).
  - Pour chaque zone et chaque catégorie ayant un pool achetable, dans l'ordre `sam`, `shorad`, `aaa`, `ground`, `armor`, `arty` : `total = zone score + capability score + response score`.
  - Score de capability = `gap + role + pressure + frontline + strategy` issu de tables par catégorie (`83035-83090`) : `gap` est le plus élevé quand la zone n'a aucune unité de cette catégorie (sam 90, shorad 110, aaa 100, ground 120, armor 115, arty 90), sinon `max(0, 45 − 15 × assigned)` ; `role` favorise SAM et SHORAD sur les bases aériennes de CAP (80 / 55) et ground et armor sur les zones bien connectées ou à revenu ; `pressure` favorise SHORAD sous pression de frappe (40) et SAM sous pression de chasseurs (30) ; `frontline` favorise ground et armor sur les zones touchant Blue (50 / 45) ; `strategy` ajoute jusqu'à 55 selon la stratégie de campagne (par ex. SAM pour `air_supremacy`, armor 50 pour `breakthrough` près de l'objectif).
  - Score de réponse (`_zoneUpgradeResponsePosture`, `83092-83154`) : 0 sans zone de pression (`strategic`) ; pour la zone de pression elle-même `hold` 65 (+25 si ≥ 70 % de sa garnison est opérationnelle, −20 sous 40 %) ; pour une voisine `block` 75 ou `flank` 60 (+ jusqu'à 30 selon les arêtes du graphe Blue), +70 si Blue occupe déjà la zone de pression, +45 / +20 si la garnison de la zone de pression est sous 50 % / 75 %, +45 si la voisine est l'objectif principal de Blue (`anticipate`), plus `min(75, 0.45 × player activity)`.
  - Une candidate est un `upgrade` seulement si la zone n'en a aucun de cette catégorie, ou moins de 2 avec un besoin stratégique ≥ 100 ; les candidates `upgrade` l'emportent sur les `defer`, puis le total le plus élevé gagne (`83268-83287`).
  - Le profil de défense compte, par catégorie, les groupes affectés et ceux encore opérationnels (`82960-83013`).
  - Quand Blue tient ≥ 90 % des zones éligibles, les améliorations SAM et SHORAD coûtent moitié prix à Red (`_redLastStandUpgradeCost`, `83896-83909`).
- **Site d'entrepôt** (`_strategicWarehousePlan`, `83929-84004`) : les hubs sont les zones Red ayant des routes de supply ouvertes vers au moins 2 destinations ; `value` additionne `1 / (1 + other operational depots already serving that destination)` et `unique` compte les destinations sans autre source.
  - Un hub est qualifié s'il a une base aérienne, n'est pas connecté à une zone Blue, n'a pas d'entrepôt (`warehouse`) ou en a un détruit (`warehouse_repair`), et n'est pas à la fois sous 50 % de force et fortement attaqué.
  - Score = `(200 + min(240, 60 × value + 25 × unique)) × supply efficiency × (0.5 + 0.5 × strength ratio) − min(250, 2 × player pressure) − 120 if near Blue` ; conservé à partir de 180.
  - Seuls deux sites classés par décision sont testés pour un placement physique (`_findWarehousePlacement`), un curseur passant aux suivants à la décision suivante.
- `_zoneUpgradeScore(zone, context)` (`83156-83231`) : +45 si la zone est la zone sous pression elle-même, +35 pour une autre zone de la même demande ; +160 si elle peut lancer de la CAP (capability de piste), +45 avec une base aérienne, −35 si sa piste est actuellement bloquée ; `12 × ground connections + 5 × friendly ones` ; `min(30, 2 × attack or supply routes starting there)` ; `min(20, 5 × income)` ; +15 si connectée à une zone Blue, sinon +8 si proche d'une ; historique des améliorations précédentes : `−180 / index` pour la même zone, `−35 / index` pour une zone à moins de 2 sauts.
- Ainsi Red améliore d'abord les bases aériennes et les zones bien connectées voisines de la pression, et n'améliore pas deux fois de suite le même endroit.
- `Director:regularSupplyTargetPriority(targetZone, context)` donne au système de supply régulier une priorité par zone composée de : rôle de secteur (hub 50, infrastructure 45, gateway 40, resource 25, defence 20, approach 15), revenu (max 40), pression des joueurs (max 90, plus pression réactive de Red max 100), focus d'opération (120, ou 50 pour le même secteur), plan défensif (45/25), objectif stratégique (90 principal, 45 secondaire), recommandation de secteur (45/25), capture fraîche (100, camp Blue), et bonus de stratégie de campagne (`77825-77937`, appelée en `54488`).
- Donc les choix de supply/reprise/amélioration ne sont pas faits par l'opération du Director ; le Director ne fournit que des priorités et l'admission au système de supply (`BattleCommander:_regularSupplyTargetPriority`, `54443-54488`).

## 14. IA Blue (PvE) et les deux camps en PvP

Lus en entier : `_updateBlue` (`95709-95800`), `allowsGroupSpawn` (`95930-96022`), `_blueCanManageGroup` et `_blueGroupCandidateScore` (`94737-94773`), `_blueAdoptActiveAttackMission` (`80033-80078`), `_configuredRoleLimit`/`_configuredAirCapacity` (`85494-85624`).
Lus aussi en entier lors des passes de comblement : `_blueMissionCandidateScore` (`79364-79528`), `_blueSelectAreaMissionCandidate` (`79530-79828`), `selectMissionTarget` (`79890-80000`), `_blueSupportFocusCandidates` et `_blueReassessSupportFocus` (`80080-80304`), `_blueReconcileAssignments` (`95095-95708`).

- `Director:update` aiguille vers `_updateBlue` quand `GlobalSettings.pvpEnabled` est vrai (l'un ou l'autre camp) ou que le camp est Blue (`95802-95805`).
- Le Director Blue n'a pas de plan offensif propre : son « opération » est l'adoption de la **mission d'attaque active des joueurs** (PvE : une zone dont l'entrée `ActiveCurrentMission` est `Attack` ; PvP : les slots d'attaque d'objectif du camp), choisie par `selectMissionTarget('ATTACK', …)` (`95778-95780`, `80033-80078`).
- L'opération se termine `captured` quand la zone devient amie, `neutralized` quand elle devient neutre, `failed` à son échéance (`95781-95794`).
- Pendant qu'elle tourne, `_blueReassessSupportFocus` et `_blueReconcileAssignments` affectent des groupes IA Blue (`95795-95798`).
- Blue ne gère que les groupes de mission `attack` de rôle CAP, CAS, SEAD, RUNWAYSTRIKE, ANTISHIP qui ne sont ni lancés par la boutique ni demandés par un joueur (`94737-94751`).
- Une candidate Blue obtient 320 si sa cible est le focus de soutien, 190 à un saut, 100 à deux sauts (rien au-delà), plus le score d'activité des joueurs de la zone, plus `max(0, 40 − 6 × hops from source)`, plus 30 pour une frappe de piste sur une base aérienne (`94753-94773`).
- Les limites de rôle de Blue viennent des paliers de « soutien ami » : `getBlueCapLimit(bluePlayers)`, `getBlueCasLimit(blueCasPlayers)`, `getBlueSeadLimit(bluePlayers)` ; l'anti-navire seulement avec ≤ 1 joueur Blue (`85502-85515`).
- Elles diminuent à mesure que des joueurs rejoignent : par ex. `BlueCapSupportStages.medium` donne 1 CAP avec 0–1 joueur et 0 à partir de 1000 joueurs, `easy` donne 2 puis 1, `hard` donne 0 (`Foothold Config.lua:1053-1067`).
- Le Director Blue répond aussi aux questions de cible du générateur de missions : `selectMissionTarget(role, candidates, context)` est appelée pour les rôles `RUNWAYSTRIKE`, `ATTACK_SUPPORT`, `CAPTURE`, `DEAD`, `SEAD`, `CAS`, `RECON` (`62466`, `64037`, `64337`, `64510`, `64731`, `65050`, `65390`), et `getBluePackageRecommendation()` (`62320`).
- **Score de cible de mission** (`_blueMissionCandidateScore`, un score additif par zone candidate, base 100) (`79364-79528`) :

| Terme | Valeur |
|---|---|
| voisins | +45 par ami, +12 par ennemi, +8 par neutre, + `min(56, 8 × connections)` |
| progression du front | `_campaignFrontProgressionScore` pour le camp ami (section 5) |
| valeur | `min(50, 2 × income)`, +35 avec une base aérienne, +12 avec des cibles SEAD |
| faiblesse | `(1 − target readiness) × 80` |
| région | `_regionTargetPreference(zone, role)` |
| exposition aux SAM | SEAD/DEAD : `+ min(260, 180 × exposure)` ; RECON : `− min(300, 200 × exposure)` ; RUNWAYSTRIKE : `− min(180, 100 × exposure)` ; autres rôles : `− min(300, 180 × exposure)` |
| rôle de secteur | le `bluePriority` du membre, hub +110, gateway +85, approach +45, resource +30, infrastructure +25, defence +60 pour SEAD/DEAD |
| continuité de secteur | `+220 + min(80, 20 × friendly zones)` quand le secteur est en partie tenu ; +220 pour le secteur engagé, puis +120 / +90 / +45 à 0 / 1 / 2 sauts de la dernière cible engagée ; +260 pour le secteur de l'opération en cours ; +70 pour le secteur recommandé |
| joueurs | + score d'activité des joueurs de la zone |
| ancrage | proximité de la zone primaire/d'ancrage du contexte ou de la cible de l'opération : +220 / +150 / +95 / +45 à 0 / 1 / 2 / 3 sauts |
| couverture IA | +14 par rôle (CAP, CAS, SEAD) que l'IA Blue peut couvrir là, +20 de plus pour le SEAD sur une mission SEAD |
| RUNWAYSTRIKE | +700 sur la zone de piste du package, +220 sur l'objectif du package |
| historique ATTACK | même cible : −90 × age après failed/aborted/contained, +90/+70/+35 × age après neutralised/near-complete/partial ; à moins de 2 sauts d'une cible capturée ou neutralisée : +35 × age |

- `selectMissionTarget` note chaque candidate active et non cachée, ajoute pour ATTACK, ATTACK_SUPPORT et CAPTURE un terme vers l'objectif de package du secteur (`max(0, 180 − 35 × hops) + max(0, 40 − distance in NM)`), trie, et laisse `_blueSelectAreaMissionCandidate` choisir en commençant par le secteur (`79927-79972`).
- Si une opération est en cours et que le rôle est `ATTACK`, la candidate correspondant à la cible de l'opération est renvoyée aussitôt (`79907-79914`).
- Effets de bord : un choix `ATTACK` démarre l'objectif Blue (`_blueStartObjective`) ; un choix `CAPTURE` fixe `blueAreaCommitment = {areaId, startedAt, lastProgressAt, lastTargetZone}` et rafraîchit la recommandation de package (`79978-79997`).
- **Choix en commençant par le secteur** (`_blueSelectAreaMissionCandidate`, `79530-79828`) :
  - pour les rôles autres qu'ATTACK, ATTACK_SUPPORT et CAPTURE, c'est un tirage pondéré parmi les trois premiers, sauf pour le CAS où la meilleure candidate est prise d'office quand elle devance de 15 % (`79531-79538`) ;
  - le **secteur de focus** est, dans l'ordre, le secteur de la zone primaire du contexte, de l'opération en cours, le secteur engagé, le secteur de la zone de capture, le secteur de la zone d'ancrage (`79684-79689`) ;
  - dans un secteur, les candidates sont filtrées au **corridor de package** : parmi les zones du secteur, celles qui minimisent `graph distance from a start + graph distance to the area's package goal`, les points de départ étant le focus d'opération, la dernière cible engagée, les zones du contexte, les zones amies du secteur et les gateways du secteur dont la zone extérieure est amie (`79554-79655`) ;
  - ATTACK / CAPTURE avec des candidates dans le secteur de focus : rester dans le secteur de focus (tirage pondéré dans le corridor), sauf si les joueurs se sont déplacés (une zone d'un autre secteur a un score joueur ≥ `BLUE_AREA_PLAYER_SHIFT_MIN` = 100 et ≥ le meilleur du secteur de focus + 80) ou si le secteur a échoué deux fois (≥ 2 opérations failed/aborted/contained là et une candidate extérieure meilleure de +80 ou ×1,35) (`79754-79791`, `71055-71056`, `71002-71003`) ;
  - sans plus aucune candidate dans le secteur de focus : ne rien renvoyer tant que le secteur a encore une frontière neutre ; sinon abandonner l'engagement et tirer parmi un représentant par secteur, en préférant les secteurs déjà en partie tenus (`79793-79826`) ;
  - ATTACK_SUPPORT : rester dans le secteur de focus ; une « troisième attaque » suit là où les joueurs s'engagent réellement, et n'ouvre un autre front qu'avec ≥ `BLUE_AREA_MULTI_FRONT_PLAYERS` = 3 joueurs (`79691-79752`, `71057`).
- **Focus de soutien** (`_blueSupportFocusCandidates`, `_blueReassessSupportFocus`) : toutes les `OPERATION_REASSESS_INTERVAL_SEC` = 90 s, le Director Blue reconsidère quelle zone son IA soutient (`80215-80217`).
  - Les candidates sont les zones ennemies portant un objectif : la cible de l'opération (+160), les zones avec une mission de joueur active (Attack +130, Bomb runway +60, SEAD +55, DEAD +50, Recon +20, lues dans `ActiveCurrentMission` en PvE et dans les slots d'objectif du camp en PvP), les slots de mission CAS actifs (+90), et les candidates de l'ombre où des joueurs sont actifs (+0) (`80093-80173`).
  - Score = `_blueMissionCandidateScore(zone, 'ATTACK_SUPPORT')` + le bonus d'objectif, +35 pour le focus actuel (`80176-80205`).
  - Le focus passe à la meilleure alternative quand elle devance de +80 ou ×1,35, ou quand les joueurs se sont déplacés (score joueur de l'alternative ≥ 100 et ≥ actuel + 80), une fois l'opération âgée de 180 s et sur 2 réévaluations consécutives (immédiatement si le focus actuel n'est plus candidat) (`80248-80271`).
  - Lors d'un déplacement, les affectations non lancées dont la cible est à plus de 2 sauts du nouveau focus sont retirées (`tactical-focus-shift`) et la collecte de candidats est retentée aussitôt (`80273-80297`).
- **Réconciliation des affectations** (`_blueReconcileAssignments`, à chaque tick Blue tant qu'une opération existe) :
  - une affectation est retirée quand elle est terminée, que son groupe a disparu, ou que sa cible n'est plus une zone ennemie active et visible (`95151-95154`, `95203-95205`) ;
  - en PvP, une affectation est aussi retirée quand un champ d'identité ne correspond plus à son groupe (nom, camp, id d'opération, rôle, mission, type, catégorie, cible, source, id de capability, slot dérivé, slot de CAP) — une garde contre les enregistrements périmés après une restauration ou un changement de cohorte (`95160-95198`) ;
  - une CAP requise qui s'est terminée en `dead` met `requiredCapLost` (`95199-95202`) ;
  - pour la CAP, l'allocation en attente est en outre plafonnée par le total des slots de CAP (`2 × limit` en PvE) moins la CAP utilisée hors de l'opération ; les affectations en attente au-delà de l'allocation sont mises en file (`restoredCapacityQueued`) ou retirées en `limit-reduced` (`95330-95367`) ;
  - la vacance d'un rôle est réduite par ses minuteurs de remplacement en attente (`blueRoleReplacementReadyAtByRole`) (`95369-95381`) ;
  - les affectations en file restaurées depuis une sauvegarde sont réactivées en premier quand une vacance existe ; en PvP, cela réinstancie la capability via `_restoreDirectorPersistenceCommander` après revérification de chaque champ d'identité et de la génération de cohorte de joueurs (`95382-95495`) ;
  - en PvP, une passe finale (ré)autorise chaque affectation non lancée seulement si la capacité partagée a encore de la place pour elle et que sa `cohortGeneration` est à jour, sinon elle est désautorisée et mise en file (`95501-95560`) ;
  - il suit la progression de chaque affectation (`lastProgressState`, `lastProgressAt`) et retire celle qui reste non lancée au-delà de `blueAssignmentRetrySec` = 120 s plus le délai de préparation du groupe (`launch-timeout`), ou dont la zone source à la demande est devenue inutilisable (`95109-95118`, `95215-95224`, `95235-95245`) ;
  - les affectations non autorisées sont autorisées : une CAP quand son slot peut être autorisé, les autres rôles sauf si l'opération attend encore sa couverture CAP (`95246-95285`) ;
  - par rôle, dans l'ordre CAP, CAS, SEAD, RUNWAYSTRIKE, ANTISHIP, vacance = limite de rôle − actifs − en attente, la variante PvP utilisant la capacité partagée (`95288-95330`) ;
  - quand des vacances existent et que `blueCandidateRetryAt` est dépassé (nouvel essai toutes les 120 s), les candidates sont collectées (`_blueCollectCapCandidates`, `_blueCollectGroupCandidates`, notées comme décrit plus haut avec 320 / 190 / 100 selon les sauts depuis le focus) et affectées dans l'ordre, **au plus une CAP par passe** ; une candidate peut être re-taskée de sa propre cible vers le focus (`95572-95689`) ;
  - une affectation CAS ou SEAD déclenche `_blueEnsurePackageCap`, et elle reste non autorisée tant que cette CAP est requise et pas encore en l'air (`95659-95680`) ;
  - si la CAP requise a été perdue et que des joueurs Blue humains sont présents, l'exigence de couverture est levée (« cap-cover=human-players ») : les joueurs sont la CAP (`95225-95229`, `95695-95703`).
- `Director:recordBluePlayerEngagement(zoneName, …)` est alimentée par le handler de kills pour savoir où les joueurs Blue se battent (`42698-42701`).
- Blue conserve un « engagement de secteur » (le secteur où il progresse) qui est sauvegardé (`92077-92089`, `92515`).
- **PvP** : les deux Directors exécutent `_updateBlue` ; les effectifs de joueurs viennent de « cohortes » par camp (`pvpPlayerCohortsBySide[side].capCount/casCount/combatPlaneCount/generation`) (`95736-95740`).
- En PvP, les cinq rôles aériens partagent une seule capacité : `PvPCombatAIGroupLimit − own qualifying player planes` (limite de 10 par défaut), ou, avec une limite de 0, « équilibre » : `enemy player planes − own player planes` ; `PvPDisableCombatAI = true` la met à 0 (`85608-85618`, `17096-17102`, `Foothold Config.lua:329-337`).
- En PvP, `allowsGroupSpawn` est strict : les groupes de supply, de boutique et demandés par un joueur passent toujours ; tout groupe de combat doit détenir un permis de routine ou une affectation autorisée de l'opération en cours correspondant au rôle, à la mission, à la cible, à la source, à l'id de capability et à la `generation` de cohorte actuelle (`95931-95996`).
- En PvP, le budget stratégique, `requestReaction`, `requestPlayerCapResponse` et les chemins AIEN sont désactivés (`84320-84324`, `94476`, `81161`).
- Red en PvE est la seule configuration qui exécute le planificateur complet des sections 3 à 13.

## 15. Mise à l'échelle selon la difficulté et le nombre de joueurs (résumé)

| Levier | Réglage / source | Effet | Référence |
|---|---|---|---|
| Quantité de CAP Red | `CapDifficulty` + `CapLimitStages` (joueurs → quantité ; 1 quantité = 1 patrol + 1 attack) | slots de CAP de base | `Foothold Config.lua:866`, `889-927`, `85517-85518` |
| Quantité de CAS / SEAD / frappe de piste Red | `CasDifficulty`, `SeadDifficulty`, `RunwayStrikeDifficulty` + leurs tables de paliers | limites de rôle, donc capacité aérienne et maximum de package | `Foothold Config.lua:868-874`, `85519-85527`, `85619-85649` |
| Soutien IA Blue | `FriendlyCapSupport`, `FriendlyCasSupport`, `FriendlySeadSupport` + `Blue*SupportStages` | limites de rôle de Blue, décroissantes avec les joueurs | `Foothold Config.lua:877-882`, `1053-1067`, `85502-85515` |
| Réactivité de Red | `RedReactiveDifficulty` (easy/medium/hard) | seuils réactifs, groupes forcés, CAP supplémentaire, profil de budget stratégique, récupération de CAP après perte | `Foothold Config.lua:438`, `31055-31135`, `83448-83456`, `71612-71615` |
| Vitesse de spawn de l'IA | `GlobalSettings.difficultyScaling = {[1]=1.0,[2]=1.0}` | multiplie les minuteurs `dead`/`hangar`/`preparing` des sorties `attack` et `patrol` par camp (détails plus bas) | `Foothold Config.lua:416-423`, `8657-8668` |
| Vitesse de supply | `GlobalSettings.supplyDifficultyScaling = {[1]=1.0,[2]=1.0}` | même multiplicateur pour les sorties `supply` ; reprend le précédent en son absence | `Foothold Config.lua:1310`, `8661-8663`, `8675-8676` |
| Vitesse de réparation | `GlobalSettings.repairDifficultyScaling = {[1]=1,[2]=1}`, `ExtraRedRepairTimeLowPlayerCountPercent = 0` | met à l'échelle par camp le temps de réparation du supply régulier (plancher 0,1) ; temps de réparation supplémentaire de Red à faible effectif, borné à 0–50 % | `Foothold Config.lua:1325`, `1332`, `8486-8491` |
| Mémoires du Director | `GlobalSettings.directorBattlefieldIntelligenceEnabled`, `directorAirCombatIntelligenceEnabled` | désactivent les deux mémoires de renseignement | `Foothold Config.lua:428-436`, `72949-72962` |
| Taille du package | joueurs (comptés en CAS Red) | `2 + floor(players/2)`, plafond 6, puis posture | `85639-85649`, `71179-71206` |
| Feinte / second front | joueurs ≥ 4 | chance 25 % + 10 % par joueur au-dessus de 4, max 70 % | `90030-90033` |
| Groupes terrestres | joueurs | surface 1/3/4, artillerie 2/3 | `84922-84932` |
| Attaque de masse | joueurs ≥ 4/3/2 selon la difficulté | autorisée comme action de budget | `84106`, `71117-71143` |
| IA de combat PvP | `PvPDisableCombatAI`, `PvPCombatAIGroupLimit` | capacité IA à voilure fixe partagée par camp | `Foothold Config.lua:329-337`, `85608-85618` |
| Capture automatique Blue | `NoAIBlueCapture` (false par défaut) | bloque les lancements d'attaques de supply/surface de l'IA Blue vers les zones neutres ; appliqué dans le permis de supply et dans `GroupCommander`, pas dans le Director | `Foothold Config.lua:1359`, `54275-54277`, `66003-66006` |
| Nuit | `NightMantisInterval`, `NightRadarBlur`, `NightRewardPercent` | temps de réaction de la défense aérienne, détection, récompense ; aucun code du Director ne les lit | `Foothold Config.lua:529-538`, `1594` |

- Les effectifs de joueurs sont les tailles des listes globales `playerListBlue`, `playerListBlueCas`, `playerListRedCas` (`60619-60632`) ; les types d'appareils qui comptent sont décidés par des listes d'exclusion (`CapCountIgnoreTypes`, `RedCasCountIgnoreTypes`, `BlueCasCountIgnoreTypes`, `Foothold Config.lua:890`, `930`, `1069-1070`).
- Aucun réglage de Config nommé « max flights » ou « disable automatic combat AI » n'existe pour le PvE ; les équivalents PvE sont les tables de paliers ci-dessus et, pour le PvP, `PvPDisableCombatAI`.
- `MaxBlueGroundGroupsPerZone = 4` et son pendant Red limitent la génération de la garnison de zone, pas les sorties du Director (`Foothold Config.lua:445`, `481`).

### Tables de paliers : ce qui évolue avec quoi

- Sept tables de la Config associent un nombre de joueurs à une quantité, chacune avec des variantes `easy`/`medium`/`hard` choisies par son réglage de difficulté : `CapLimitStages`, `RedCasLimitStages`, `RedSeadLimitStages`, `RedRunwayStrikeLimitStages` (Red, croissantes avec les joueurs) et `BlueCapSupportStages`, `BlueCasSupportStages`, `BlueSeadSupportStages` (IA Blue, décroissantes avec les joueurs) (`Foothold Config.lua:894`, `936`, `975`, `1014`, `1053`, `1075`, `1097`).
- Une table est une liste de paliers `{player = n, amount = m}` ; `getCapLimit(players)` cherche l'effectif via `_limitFromStages`, en retombant sur des valeurs codées en dur quand la table manque (`60867-60885`).
- Exemple, `CapLimitStages.medium` : 0–2 joueurs → 1, 3–4 → 2, 5 → 3, 9 → 4, 10 → 6, 999 → 7 ; `easy` commence à 0 sans joueur et finit à 6 ; `hard` atteint 2 à 2 joueurs et finit à 8 (`Foothold Config.lua:894-932`).
- Une « quantité » de CAP vaut une CAP patrol plus une CAP attack (`Foothold Config.lua:889`).
- Les joueurs comptés diffèrent selon la table : joueurs Blue hors `CapCountIgnoreTypes` pour la CAP, hors `RedCasCountIgnoreTypes` pour le CAS Red (`Foothold Config.lua:890`, `930`).

### Mise à l'échelle des minuteurs hors du Director (`difficultyScaling`, escalade et atténuation)

- `GlobalSettings.setDifficultyScaling(value, coalition)` reconstruit `respawnTimers[coalition]` à partir de `defaultRespawns` (15 min `dead`, 18 min `hangar`, 2 min `preparing` pour supply, patrol et attack, les deux camps) et multiplie chaque minuteur par `value`, les minuteurs de supply par l'échelle de supply ; une valeur inférieure à 1 fait revenir l'IA de ce camp plus vite (`8571-8582`, `8586-8668`).
- Au chargement, elle est appliquée une fois par camp à partir des valeurs de la Config (`8670-8682`).
- **Rattrapage de Red quand il perd** : `_rebalanceRedDifficulty` s'exécute après chaque changement d'état de zone ; elle compte les zones éligibles (actives, non suspendues, non neutres, non cachées) et la part tenue par Blue ; quand Blue tient **≥ 90 %**, les minuteurs de Red sont mis à la **moitié** de l'échelle configurée, sinon remis à l'échelle configurée (`37004-37070`, appelée en `55450`).
- Ainsi les dernières zones Red respawnent leurs sorties deux fois plus vite ; c'est le seul changement automatique de difficulté actif sur le Caucase.
- **Escalade et atténuation (inactives sur le Caucase)** : `BattleCommander:new(savepath, updateFrequency, saveFrequency, difficulty)` accepte `difficulty = {start, min, max, escalation, fade, fadeTime, coalition}` (`17082`, `17120`).
- Avec elle, chaque fois qu'une zone de cette coalition est vidée de sa garnison, `increaseDifficulty()` abaisse le modificateur de `escalation` (jusqu'à `min`), donc des minuteurs plus courts, et à la fin de chaque vague de mise à jour de zones, une fois que `fadeTime` secondes se sont écoulées depuis le dernier changement, `decreaseDifficulty()` le relève de `fade` (jusqu'à `max`) ; l'échelle appliquée est `start + modifier` (`19253-19265`, `55297-55299`, `43266-43270`).
- Le setup du Caucase appelle `BattleCommander:new(filepath, 10, 60)` sans table `difficulty`, donc `bc.difficulty` est nil et rien de cela ne tourne (`MA_Setup_CAv2.lua:754`, `30240-30242`).
- Le modificateur n'est pas sauvegardé en v6.5.3 (voir `02-persistence-lifecycle-plumbing.md`).
- La mise à l'échelle propre du Director par `RedReactiveDifficulty` est distincte : seuils réactifs, profil de budget stratégique, profil de récupération de CAP après perte et facteur de renseignement de champ de bataille 0,65 / 1 / 1,25 (`31055-31135`, `83448-83456`, `71612-71615`, `73254-73259`).

### Attaque de masse de Red (le `surge`)

- C'est une fonctionnalité de `BattleCommander` que le Director ne fait qu'acheter et adopter : article de boutique `redmassattack` → `triggerRedMassAttack(preferredTargetNames)` (`35003-35024`, `84274-84276`).
- Réglages : au moins 4 groupes ; limites par type CAP 2, CAS 2, SEAD 1, RUNWAYSTRIKE 1 (6 groupes au plus) ; un groupe déjà en `takeoff` ou `inair` vers la cible compte comme vivant (`34445-34464`).
- Les cibles sont les zones Blue avec une base aérienne (pas les porte-avions) ; pour chacune, un plan met en commun les groupes aériens Red `attack` et les capabilities non instanciées de chaque zone Red utilisable par type en `live` (déjà en vol vers cette cible), `assigned` (dormants, même cible) et `retask` (dormants, autre cible à moins de la distance de retask), source la plus proche d'abord ; les groupes détenus par une opération du Director sont exclus, et le SEAD exige des cibles SEAD (`34501-34558`, `34582-34590`).
- Score du plan = `10 × groups filled + number of roles filled` ; un plan est éligible avec ≥ 4 groupes, au moins une CAP, au moins un frappeur et au moins un groupe dormant à faire sortir (`34560-34579`, `34591-34602`).
- Les cibles préférées du Director l'emportent si elles sont éligibles ; sinon tirage aléatoire parmi les plans les mieux notés (`34604-34613`).
- Ce que voit le joueur : Red reçoit `COMBAT_RED_MASS_ATTACK` (cible, groupes forcés, total), Blue reçoit `INTEL_MASS_ATTACK` (cible) pendant 15 s avec le son `Intel_short.ogg` (`35018-35022`).
- `Director:_adoptMassAttack` transforme l'attaque de masse en cours en une opération `{doctrine = 'surge', targetZone, assignments = {}}` sans affectation propre, met l'état `surge` et le surge suivant 2700 à 5400 s plus tard ; une attaque de masse lancée hors du Director (boutique, admin) est adoptée de la même façon et préempte l'opération en cours (`92111-92139`, `95853-95860`).
- La mission reste active tant qu'au moins un groupe participant est en vie ; un participant mort retrouve sa cible d'origine et son mode de spawn, et quand il n'en reste plus, les instances à la demande sont mises au rebut (`34812-34832`).
- Persistance : la sauvegarde contient `{targetZone, participants = {commanderName, directorCapabilityId, directorInstanceGeneration, side, groupName, missionType, sourceZone, originalTarget, originalSpawnHot, retasked}}` (`34834-34857`).
- La restauration attend l'amorçage de DynamicHybrid et la fin de la restauration des vols IA (premier essai après 8 s, puis toutes les 5 s, 15 essais), résout à nouveau le commandant de chaque participant (via sa capability du Director ou par nom de groupe vivant), réapplique la cible de l'attaque de masse aux groupes re-taskés, et rouvre la mission avec `restored = true` s'il reste un participant (`34859-34870`, `34960-35001`).

## 16. `EventCommander` et les événements du setup du Caucase

Lus en entier : `96291-96367`, les événements du setup `MA_Setup_CAv2.lua:6130-6500` et `9041-9392` ; les sept événements d'entrepôt de SAM (`9339-9715`) ont été vérifiés un par un pour leur `id`, `RegisterScoreTarget` (500 chacun), leurs conditions `canExecute` et leur appariement `mc:trackMission`, et suivent tous le même schéma.

### Mécanisme

- `evc = EventCommander:new({ decissionFrequency=15*60, decissionVariance=10*60, skipChance=15, strikeFrequency=5*60 })` puis `evc:init()` (`MA_Setup_CAv2.lua:6073-6074`).
- Deux boucles `timer.scheduleFunction` brutes : toutes les 15 min + 1 à 600 s aléatoires, choisir au hasard un événement non-strike dont `canExecute()` est vrai et exécuter son `action()` sauf si un jet de skip de 15 % dit non ; toutes les 5 min, choisir au hasard un événement exécutable marqué `StrikeMission = true` et l'exécuter (sans jet de skip) (`96319-96365`).
- Un événement est `{id, action, canExecute, StrikeMission?, reuseDirectCheck?}` ; `evc:triggerEvent(id)` en exécute un par id s'il peut s'exécuter (`96302-96317`).
- La plupart des événements s'apparient à une entrée `mc:trackMission({...})` (le `MissionCommander`) qui fournit le titre, la description, les messages de début/fin et les sons (`ding.ogg`, `cancel.ogg`) et un prédicat `isActive` (`MA_Setup_CAv2.lua:9064-9086`).

### Événements déclarés pour le Caucase

| id | Type | Conditions de déclenchement (`canExecute`) | Effet | Lignes |
|---|---|---|---|---|
| `scuds` | aléatoire (PvE seulement) | non actif, refroidissement de 45 min, jet à 50 %, Maykop Red et non suspendu, une cible Blue parmi Gudauta/Sochi/Sukhumi | respawn le groupe `Maykop-Scuds` comme cible de 100 crédits ; 20 min plus tard il tire sur une zone Blue valide au hasard avec la clé de message `CA_EVENT_SCUDS_MAYKOP_LAUNCHING` | `6132-6193` |
| `cargointercept` | aléatoire | non actif, refroidissement de 45 min, jet à 30 %, pas toutes les zones Maykop/Sochi/Anapa/Mineralnye Blue | respawn un avion cargo `evt-cargointercept1..4` depuis la première base Red dans cet ordre ; cible de 500 crédits | `6234-6263` |
| `shiptercept` | aléatoire | non actif, refroidissement de 45 min, jet à 30 %, zone `Red Carrier` Blue, Novorossiysk Red, Sochi Blue, aucun navire en vie | respawn l'un de `evt-shiptercept1..3` (500 crédits) en route vers Gudauta/Sochi/Sukhumi | `6298-6348` |
| `cas` (frappe aérienne tactique) | strike | PvE, pas d'ère Vietnam, des templates de frappe existent, aucun en vie, et le **Director Red** a un plan de frappe aérienne tactique | spawn un groupe de frappe démarré en l'air au point de spawn choisi par le Director contre la cible choisie par le Director, cible de 250 crédits « Intercept enemy airstrike » ; engage un refroidissement de 45 min auprès du Director | `6421-6500` |
| `StrikeTarget`, `StrikeTarget1`, `StrikeTarget2` | strike | flag non posé, non actif, l'une de deux zones nommées Blue | enregistre un objet de décor (ou un groupe respawné) comme cible de grande valeur à 1000 crédits et y pose une marque de carte Blue | `9041-9200` |
| `RightHandMan`, `LefttHandMan` | strike | flag non posé, l'une de deux zones Blue | respawn un groupe de « général de grande valeur », 500 crédits | `9205-9295` |
| `StrikeVaziani` | strike | flags, Lima Blue et Vaziani Red | respawn la cible d'entrepôt de supply de Vaziani, 1000 crédits | `9297-9337` |
| `SamDeltaWarehouse`, `SamEchoWarehouse`, `SamGolfWarehouse`, `SamAlphaWarehouse`, `SamHotelWarehouse`, `SamJuliettWarehouse`, `SamKiloWarehouse` | strike | flag non posé, la base Red fournisseuse et sa zone SAM toutes deux Red et actives, une zone voisine Blue | enregistre le décor d'entrepôt comme cible de frappe à 500 crédits avec une marque de carte ; le détruire pose le flag personnalisé que lisent l'entrée `TheaterInfrastructure` et la `condition` de la capability de supply (la zone SAM perd son réapprovisionnement) | `9339-9715`, `2271-2290`, `1291` |

- La frappe aérienne tactique est le seul événement que pilote le Director : `getTacticalAirstrikePlan(pickOptions)` / `consumeTacticalAirstrikePlan` / `commitTacticalAirstrikeLaunch(selection, cooldown)` ; les candidates viennent des sélecteurs de cible/de spawn du module bombardier et de la liste de cibles propre du Director, notées comme suit (`83701-83781`).
- Les candidates sont les candidates de cible offensive du Director que le module bombardier accepte aussi comme cible et pour lesquelles il trouve un point de spawn éloigné des joueurs ; score = le score offensif de la cible, +220 si c'est la cible de l'opération (`main`), +140 si c'est la cible de la feinte (`diversion`), +60 si elle est dans le secteur de l'opération (`opportunity`), puis ×0,35 si c'était la cible de la frappe aérienne précédente (`83737-83775`).
- Pendant un `surge`, la seule candidate est la cible de l'attaque de masse, et seulement si `_massTacticalAirstrikeDecision` a décidé d'inclure une frappe aérienne dans l'attaque de masse (`83711-83733`, `83636-83676`).
- Cette décision est refusée sans joueurs, avec 7 groupes ou plus déjà dans l'attaque de masse, avec < 30 % de CAP serviceable ou ≥ 65 % de pertes ; sinon c'est un tirage pondéré entre `include = 55 + min(100, 12 × players) + min(100, 0.25 × target score) + 70 × serviceable − 120 × lossRatio` et `omit = 95 + 160 × lossRatio + 15 × groups above 4`, décalé par la posture aérienne (conserve −90 / +70, pressure +30, concentrate +55 sur `include`) (`83646-83675`).
- Le lancement est revalidé au moment du spawn : Director toujours prêt, même signature d'opération, zone source toujours Red et active, aucun joueur à moins de `minPlayerSpawnNm` (80 NM par défaut) du point de spawn (`MA_Setup_CAv2.lua:6455-6465`).
- Moose n'est utilisé dans les événements que pour `GROUP:FindByName():GetAmmunition()` et `SCENERY:FindByZoneName()` (`MA_Setup_CAv2.lua:6143-6144`, `9045`).

## 17. Ce que les joueurs et les admins voient du Director

- Un seul message direct au joueur : l'interception du soutien aérien AIEN, à Blue, 15 s (`72448-72452`) ; c'est le seul `trigger.action.outText*` de toute la classe (lignes `70990-96234` cherchées).
- Le Director ne produit ni marque de carte, ni dessin, ni son.
- Indirectement, via d'autres sous-systèmes : la mission d'attaque de masse « Defend %s … Attacking groups: %d » et « Intel: The enemy is launching a mass attack on %s » (`Foothold_Localization.lua:1202-1204`, `1264`), la mission de frappe aérienne tactique « Intercept enemy airstrike » (`Foothold_Localization.lua:635-639`), les messages du bombardier stratégique de Red, et les messages d'événements de la section 16 ; ceux-ci sont émis par `MissionCommander`, la boutique et les modules bombardier, non analysés ici.
- Admin/débogage : `config.log` (false par défaut) écrit dans `dcs.log` avec `env.info` des lignes `[Director] side=<n> state=<state> <message>`, par ex. `operation=<id> doctrine=<d> target=<zone> area=<id> feint=<zone>`, `operation=<id> phase=assault`, `operation=<id> result=<r>`, `learning doctrine=… outcome=… reason=…`, `after-action cause=… confidence=…`, `air-posture=<name> reason=…`, `budget mode=… action=… funds=… cost=… incomePerMin=… eta=…`, `ground-permit role=… group=… source=… target=… score=…`, `reaction queued …` (`71913-71917`, `94604-94606`, `92015`, `92102`, `92057-92070`, `71436-71439`, `84389-84396`, `85411-85415`, `94347`).
- `Director:logRegionalCapabilityAudit(regionId)` affiche un résumé des capabilities qui peuvent atteindre une région (`75654-75657`).
- L'audit (`buildRegionalCapabilityAudit`, `75371-75556`) n'existe que pour les cartes avec des régions : pour chaque membre de région, il liste quelles « recettes » de capability des zones sources utilisables de la région peuvent l'atteindre, par mode d'accès : `local` (même zone), `explicit_supply` (une route de supply saisie), `shared_air` (une recette aérienne CAP/CAS/SEAD/RUNWAYSTRIKE depuis une zone avec une base aérienne), `shared_surface` (une recette d'attaque de surface depuis un voisin terrestre avec une route non bloquée) (`75347-75369`, `75466-75525`).
- Il totalise les accès par mode et par rôle, liste les sources d'infrastructure hors de la région, et consigne les problèmes d'intégrité ; c'est une sortie de diagnostic uniquement (`75526-75556`).
- Plusieurs décisions conservent un enregistrement « ombre » pour inspection (`airPostureDecisionState`, `strategicBudgetLastDecision`, `areaShadowRecommendation`) ; les drapeaux `AIR_POSTURE_SHADOW_ONLY` et `STRATEGIC_BUDGET_SHADOW_ONLY` (tous deux false) feraient calculer ces deux systèmes sans agir (`71106`, `71150`, `71166`, `84335-84337`).
- Aucune entrée de menu F10 n'appartient au Director : il n'y a aucun appel `MENU_` ni `missionCommands` dans `70990-96234` (cherché).

## 18. Persistance (ce que sauvegarde le Director)

Lu : la liste des champs de premier niveau de `exportPersistence` (`92448-92577`) ; la restauration (`93046-94266`) est décrite dans `02-persistence-lifecycle-plumbing.md`, sous-section « `Director:_restorePersistence` ».

- `exportPersistence(getCommanderIndex)` renvoie une table par camp, version 1, contenant : `state`, mémoire du front de campagne, stratégie de campagne, bail/décision/historique des actions de campagne, posture aérienne (en secondes restantes), décision de réaction aérienne, engagement de secteur de Blue, minuteurs de groupes de CAP Blue/Red, slots de CAP, transferts de frappe tactique, détournements de CAS sur capture, compteur d'opérations, secondes restantes des minuteurs de récupération/planification/surge/amélioration de zone/budget/dépense/bombardier/frappe aérienne tactique, intention de budget, demande AIEN, `history`, `doctrineOutcomes`, `targetOutcomes`, `roleOutcomes`, historique d'améliorations de zone, historique de budget, minuteur de décision au sol, historique au sol et refroidissements de réutilisation au sol, renseignement de combat aérien et de champ de bataille (`92457-92577`).
- Tous les minuteurs sont sauvegardés en **secondes restantes**, pas en heures absolues, et les lignes de résultats sous forme d'âge (`outcomeObservedAgeSec`), de sorte qu'un redémarrage reprend les horloges (`92538-92545`, `73334-73344`).
- Les données arrivent via `battleCommander._pendingDirectorPersistence` / `_pendingBlueDirectorPersistence` et sont appliquées au premier tick prêt (`95905`, `95914`, `95815-95818`).
- Après une restauration, le démarrage de la CAP de Red est échelonné : CAP patrol restaurée prête en 0 à 2 min, CAP attack en 2 à 5 min, dans une fenêtre de démarrage de 10 min, suspendue tant qu'aucun joueur n'est connecté (`71049-71053`, `81295-81378` ; détaillé en section 9).

## 19. Coût d'une passe de planification et limitation

- Un tick par camp toutes les 30 s ; le Director ne crée aucun minuteur par unité ni par joueur (`95925-95927`).
- Un tick Red exécute toujours le plan défensif, la décroissance du renseignement, la réconciliation de la CAP, l'observation des régions et la mise à jour de l'ombre stratégique ; seule la construction d'opération est conditionnelle (`95842-95895`).
- Limiteurs et caches vus dans le code lu :
  - scores d'activité des joueurs mis en cache 15 s par variante (`75703`) ;
  - proposition de plan défensif réutilisée jusqu'à 60 s tant que huit signatures/générations d'entrée sont inchangées (`76862-76876`, `71063`) ;
  - ombre stratégique recalculée seulement quand `strategicShadowNextAt` est dépassé ou que l'inventaire de planification est reconstruit (`95771-95775`) ;
  - instantané de l'inventaire de groupes de planification reconstruit toutes les 300 s sur le chemin Blue/PvP, et à la demande pour un plan Red, reconstruit pendant un plan seulement si `_reindexCombatFilterGeneration` a changé (`95770-95773`, `94578-94621`) ;
  - budget stratégique toutes les 60 à 180 s, avec une sortie de log seulement quand la signature de la décision change (`84325`, `84379-84388`) ;
  - libération au sol toutes les 90 s, vraie éligibilité testée pour au plus 12 candidats, présélection de 6, faits de route et résultats de paires bloquées mémoïsés par paire source/cible dans la passe (`85423`, `85432-85447`, `85266-85297`) ;
  - réévaluation d'opération toutes les 90 s (`70999`) ;
  - les recherches de menaces SEAD passent par un catalogue (`GetSeadThreatCatalog`) et les distances zone à zone par la table précalculée `ZONE_DISTANCES` plutôt que par de la géométrie en direct (`79321-79322`, `79324`) ;
  - des compteurs de « génération » (`_capTargetStateGeneration`, `generation` de cohorte, `campaignActionGeneration`, `_runwayPlaneSpawnBlockGeneration`) sont comparés au lieu de redériver l'état (`95747`, `76859-76860`) ;
  - la mémoire de routes de champ de bataille est bornée à 128 lignes (`71039`).
- Le travail inconditionnel par tick qui balaie toutes les zones est `_collectTargetCandidates` (chaque zone × ses voisines, avec `_targetScore` incluant un balayage d'exposition aux SAM du catalogue de menaces) quand un plan ou une libération au sol s'exécute (`84776-84802`, `85259`).
- Le changelog du moteur ne fait pas partie de l'extrait (seul `tools/FootholdConfigManager/CHANGELOG.md` existe), donc la note de la 6.4.6 sur la réduction des traitements répétés n'a pas pu être rapprochée du code.

## Notes de reproduction (ensemble du thème)

- Le Director n'a pas besoin de Moose : les minuteurs sont des `timer.scheduleFunction`, le temps est `timer.getAbsTime()`/`timer.getTime()`, l'aléa est `math.random` ; les seuls appels Moose dans les parties lues sont `UTILS.VecDist2D` et, dans `BudgetCommander`, `SCHEDULER` (`75749`, `96283`).
- La difficulté n'est pas dans une formule isolée mais dans la quantité d'état partagé qu'il lit dans le reste du moteur : graphe des zones et distances précalculées, instantanés de force de combat des zones, catalogue de menaces SEAD, classement des cibles de CAP, listes de joueurs, carte de pression réactive, boutique, modules d'attaque de masse et de bombardier, et les crochets du FSM de `GroupCommander` (`allowsGroupSpawn`, `onGroupStateChanged`, `onManagedSpawnDenied`).
- Les décisions sont en couches telles que chaque couche peut mettre son veto à la suivante : admission des actions de campagne → posture → construction du package → verrous par affectation → éligibilité au spawn de `GroupCommander` ; un échec à n'importe quelle couche laisse l'affectation non autorisée et elle est retentée au tick suivant.
- Presque chaque choix est un tirage aléatoire pondéré parmi les quelques meilleurs candidats avec hystérésis (temps de maintien, confirmations, baux) ; reproduire seulement les scores sans l'hystérésis donne un planificateur nerveux.
- Chaque élément de mémoire a une décroissance ou une expiration et est sauvegardé en temps restant, ce qui lui permet de survivre à un redémarrage du serveur sans se « réveiller » périmé.

## Vu hors de ce thème

- Remplisseur DynamicHybrid : génération automatique d'enregistrements `DirectorCapability` à partir de la géométrie des zones et des capabilities forcées par zone (`33850-33880`, `MA_Setup_CAv2.lua:6077-6118`).
- Boucle de contre-pression réactive de Red et ses renforcements doux (`31040-31790`).
- `MissionCommander` (`mc:trackMission`, `mc:launchIdleAttack`) appariant chaque événement à une mission côté joueur (`102546-103949`, `MA_Setup_CAv2.lua:6195`, `6454`).
- Système de supply régulier et ses permis, où `NoAIBlueCapture` est appliqué (`54270-54543`).
- Suspension automatique des zones selon la distance au front (`GlobalSettings.autoSuspendNmBlue = 70`, `autoSuspendNmRed = 95`, PvP 100/100 et `proximityWakeNm = 50`) (`MA_Setup_CAv2.lua:6061-6070`).
- Suivi de la mission d'attaque de masse de Red par `MissionCommander` (`autoTrackRedMassAttackMission`, `103062`) ; le planificateur lui-même est décrit en section 15.
- Installations d'entrepôt achetables par Red (`redwarehouse`, `redwhrepair`) et état `zone.warehouseFacility` (`84255-84265`).
- Cohortes de joueurs PvP et slots d'attaque d'objectif (`pvpPlayerCohortsBySide`, `objectivesBySide`, `80038-80047`).
