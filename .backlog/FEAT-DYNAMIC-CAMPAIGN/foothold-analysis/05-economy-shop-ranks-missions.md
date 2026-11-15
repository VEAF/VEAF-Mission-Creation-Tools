# 05 — Économie du joueur : crédits, boutique, rangs, récompenses et missions joueur (Foothold v6.5.3)

Source : tag amont v6.5.3, `Common Scripts/zoneCommanderv2.lua` (moteur), `Common Scripts/Foothold Config.lua`, `Setup files/MA_Setup_CAv2.lua` (Caucase), `Common Scripts/Foothold_Localization.lua`.
Les citations utilisent des noms de fichiers courts : `zoneCommanderv2.lua` → `zc`, `Foothold Config.lua` → `Config`, `MA_Setup_CAv2.lua` → `Setup`, `Foothold_Localization.lua` → `L10N`.

## Liste des fonctionnalités

| # | Fonctionnalité | Description en une ligne | Emplacement principal dans le code |
|---|---|---|---|
| 1 | Crédits de coalition | un compte partagé par camp, dépensé en boutique et dans CTLD | `zc:19368-19375`, `zc:21418-21548` |
| 2 | Cœur de la boutique | registre des articles, étagères par camp avec stock et rang, validation des achats, paiement différé | `zc:19322-19366`, `zc:21770-22132` |
| 3 | Crédits personnels (non réclamés) | les récompenses s'accumulent sur le joueur et sont encaissées en se posant dans une zone amie ; perdues à la mort, 25 % conservés à l'éjection | `zc:41264-41273`, `zc:41818-41922`, `zc:42083-43149` |
| 3.1 | Attribution des kills | `S_EVENT_KILL` uniquement, cible classée par attributs DCS | `zc:42812-42891`, `zc:43151-43233` |
| 3.3 | Bonus de temps de vol, de rotation et de nuit | récompense à la minute, bonus même appareil, bonus de décollage de nuit | `zc:101289-101318`, `zc:41504-41612` |
| 3.4 | Récompense de ravitaillement en vol | crédits par 100 lb reçues d'un ravitailleur | `WelcomeMessage.lua:2731-2829` |
| 3.5 | Points d'accroche logistique / CSAR / capture | livraison de supply, capture, sauvetage, capture de pilote ennemi | `zc:98238-98300`, `zc:100538-100558`, `zc:42284-42311` |
| 3.6 | Pénalité de tir ami | crédits de rang retirés pour les team kills | `zc:42641-42675` |
| 4 | Menu F10 de la boutique et boutique par marqueur | menu catégorisé par groupe avec sélecteurs de zone ; marques de carte `buy:<id>` | `zc:22395-22533`, `zc:28555-28706` |
| 5 | Catalogue de la boutique | chaque article, prix, rang, cible, effet | `Setup:3009-5751`, `Config:1608-1916` |
| 5 | Menu Dynamic Control | contrôle des vols et ravitailleurs achetés (la navigation du porte-avions est sous Stats and Settings) | `zc:16259-16694`, `zc:106266-106480` |
| 6 | Rachat automatique des CAP après perte (6.5.2) | rachat automatique d'un vol CAP détruit | `zc:21863-21876`, `zc:106427-106466` |
| 7 | Rangs | échelle de 20 échelons sur les crédits de rang personnels, conditionne boutique / CTLD / porte-avions | `zc:17231-17232`, `zc:44332-44408` |
| 8 | Statistiques et classements | statistiques par sortie, par session et sur la vie entière ; listes des meilleurs | `zc:40510-40970`, `zc:21395` |
| 9 | Carrière et hauts faits | compteurs sur la vie entière par joueur et par appareil, avec des échelles de hauts faits rémunérées | `zc:12040-12101`, `zc:44035-44100` |
| 10 | Missions conjointes | groupes de jusqu'à 4 joueurs qui se partagent les récompenses de mission | `zc:18059`, `zc:41275-41360` |
| 11 | Missions joueur | liste de missions scrutée, registre de cibles, événements de frappe, missions d'escorte | `zc:102460-103960`, `zc:8866-9072`, `Setup:6073-9700` |
| 12 | Arborescence du menu F10 | chemins de menu, portée et rafraîchissement | `zc:101203-101215`, `zc:101490-101497` |
| 13 | Réglages économiques de Config | chaque réglage qui ajuste les prix, les récompenses et les pénalités | `Config:260-292`, `Config:1573-1952` |

## 1. Crédits de coalition (le compte partagé)

### Ce que voit le joueur

- Chaque coalition possède un compte entier ; chaque message d'achat se termine par le solde restant (`SHOP_BOUGHT_BY_PLAYER`, `zc:22093-22095`).
- `F10 > Shop > Budget overview` affiche `Credits: <n>[/<cap>]`, chaque article de la boutique avec son coût et son stock restant, et une liste « Unclaimed credits » des joueurs en vol qui détiennent des crédits non encaissés (`zc:21418-21464`, entrée de menu en `zc:22411-22413`).

### Ce que règle le créateur de mission

- `bc:addFunds(side, amount)` ajoute (ou retire, si négatif) des crédits ; le solde est borné à 0 et à `bc.creditsCap` quand ce plafond est défini (`zc:19368-19375`).
- `StartupFunds = {[1]=1000,[2]=1000}` sont les fonds de départ PvP d'une manche nouvelle ou réinitialisée (`Config:304-311`) ; le setup les applique comme un delta sur le compte courant (`Setup:5861-5862`).
- `CreditLosewhenKilled` (par défaut `false`) et `CreditLosewhenKilledAmount` (100) font perdre des crédits à la coalition à chaque mort de joueur (`Config:260-264`).
- Les alias admin de chat/marqueur `addBlueFunds`, `addRedFunds` existent dans `AdminCommandAliases` (`Config:3477-3483`).
- Le fichier de setup accorde des crédits depuis des triggers de mission avec `bc:addFunds(2,200)` / `bc:addFunds(2,500)` dans une série de callbacks scriptés (`Setup:2583-2727`).

### Mécanisme

- État : `bc.accounts[side]` (nombre), `bc.creditsCap` (facultatif), `bc._pendingShopCreditReservations[side]` (crédits réservés par des achats dont la livraison est encore en attente) (`zc:19368-19375`, `zc:21550-21573`).
- Un achat vérifie `accounts[side] - reserved >= cost` (`zc:21945-21953`).
- Aucun Moose : de simples tables Lua et `trigger.action.outTextForCoalition/Group`.

## 2. Cœur de la boutique : registre des articles, étagères par coalition, déroulé d'un achat

### Modèle de données

- `bc:registerShopItem(id, name, cost, action, altAction, aiPurchaseChance, flightRole, flightTemplatesBySide)` stocke la définition dans `bc.shopItems[id]` (`zc:19322-19339`).
- `action(sender[, ownerSide])` s'exécute quand l'article est acheté sans paramètre ; `altAction(sender, params[, ownerSide])` s'exécute quand une table de paramètres est fournie (zone choisie dans le menu, ou point de marqueur) (`zc:22036-22049`).
- Une action renvoie `true`/`nil` en cas de succès, une chaîne ou une fonction (constructeur de texte localisé) pour un message de refus montré à l'acheteur, `false` pour le générique « not available now », ou `{deferredShopPurchase=true}` quand le paiement sera réglé plus tard (`zc:22054-22131`).
- `bc:addShopItem(side, id, amount, prio, reqRank, category)` place l'article sur l'étagère d'une coalition `bc.shops[side][id] = {name,cost,stock,prio,category,reqRank}` ; `amount = -1` signifie un stock illimité, une quantité positive est un stock fini qui est décrémenté et retire l'article à 0 (`zc:19341-19361`, `zc:22073-22079`).
- `reqRank` n'est stocké que lorsque `RankingSystem` vaut true (`zc:19353`, `zc:19357`).
- `bc:removeShopItem(side, id)` le retire et reconstruit les menus de boutique de la coalition (`zc:19363-19366`).
- `AvailableShopItems[id] == false` dans Config fait marquer l'article `purchaseAvailable = false` par `registerShopItem`, ce qui fait que `addShopItem` l'ignore (`zc:19323`, `zc:19344`).
- En PvP, une liste codée en dur d'ids est forcée indisponible (`dynamicstatic`, `armor`, `artillery`, `recon`, `airdef`, `calav`, `camgs`, `cadragoon`, `jtac`, `9lineam`, `9linefm`, `zsup3`, `zwh50`, `advancecapture`, `cruisemsl`, les articles IA rouges), et les articles de vol exigent un `flightRole` plus une ligne de template pour le camp acheteur (`zc:19324-19338`, `zc:19345`).

### Déroulé d'un achat (`BattleCommander:buyShopItem`, `zc:21770-22132`)

Vérifications, dans l'ordre :

1. L'article doit être sur l'étagère de la coalition, sinon `SHOP_ITEM_NOT_FOUND` (`zc:21780-21787`).
2. PvP : les articles de vol/upgrade doivent appartenir au camp de l'acheteur, le groupe acheteur doit être de cette coalition, et le rang de l'acheteur doit atteindre `reqRank` (`zc:21791-21803`).
3. Les ravitailleurs (`dynamicarco`, `dynamictexaco`) sont des « déblocages persistants » : une fois débloqué, l'article est retiré de l'étagère et l'action est relancée gratuitement avec le message `SHOP_ALREADY_UNLOCKED` (`zc:21809-21852`).
4. `purchaseAvailable == false` → refus (`zc:21853`).
5. `zpat` refusé si la zone a déjà un Patriot (`zc:21854-21862`).
6. Pré-vérifications du rachat automatique des CAP (voir §6) (`zc:21863-21876`).
7. `StoreLimit` (Config, par défaut `false`) : un joueur ne peut acheter un article coûtant plus de 250 / 1000 / 2000 / 3000 que si sa statistique `Points` sur la vie entière atteint au moins 100 / 1000 / 2000 / 3000 (`zc:21877-21894`, `Config:277-282`).
8. `supplies` : refusé avec `SHOP_ALL_ZONES_UPGRADED` quand toutes les zones possédées sont entièrement construites et à pleine force (`zc:21895-21923`).
9. `capture` : refusé avec `SHOP_NO_NEUTRAL_ZONES` quand aucune zone neutre éligible n'existe (`zc:21925-21943`).
10. Assez de crédits non réservés, sinon `SHOP_NOT_ENOUGH_CREDITS_FOR_ITEM` (`zc:21945-21953`).
11. Stock non épuisé, sinon `SHOP_OUT_OF_STOCK` (`zc:21955-21962`).
12. Si la zone cible est « idle-suspended » (zone en dormance), la zone est réveillée, l'acheteur reçoit `SHOP_TARGET_STANDBY`, et une boucle `timer.scheduleFunction` de 0,5 s retente l'achat jusqu'à ce que la zone soit réveillée ou que `idleZoneWakeHoldSec` soit écoulé (`zc:21980-22018`).
13. L'action s'exécute ; en cas de succès, le coût est débité, le stock décrémenté, `Points spent` est ajouté aux statistiques de l'acheteur et à ses dépenses de carrière, et la coalition reçoit `SHOP_BOUGHT_BY_PLAYER` (ou `SHOP_BOUGHT` quand l'achat est fait sans joueur, par exemple par l'IA ou par un marqueur hors slot) (`zc:22056-22113`).

Paiement différé (« pending shop purchase ») : pour `supplies`, `supplies2`, `capture`, `advancecapture` (et en PvP `groundattack` et les vols), un enregistrement d'achat `{coalition,id,cost,buyerGroupId,buyerName,itemName}` est attaché au `GroupCommander` qui livrera, son coût est réservé, et le débit n'a lieu dans `_completePendingShopPurchase` que lorsque le groupe de livraison décolle réellement ; `_failPendingShopPurchase` libère la réservation avec un message facultatif (`zc:22030-22034`, `zc:21575-21671`).

Le commandant IA rouge achète aussi par la même fonction, avec un prix fourni par le Director (`alternateParams._redDirectorPurchase`, `_directorShopCost`) (`zc:21804-21808`).

### Points d'accroche de débit/crédit CTLD

- `bc:debit(side, amount, groupId, groupObj, reason, reqRank)` est le point d'entrée utilisé par CTLD pour facturer une caisse ou des troupes : il vérifie le rang de l'acheteur par rapport à `reqRank` (« Insufficient rank for … »), puis le solde (« Our team does not have enough credits for … »), débite, ajoute `Points spent`, et annonce « X spent N credits on CTLD … » à la coalition (`zc:21466-21513`).
- `bc:credit(...)` rembourse (par exemple une caisse rendue) et réduit `Points spent` (`zc:21516-21548`).
- `CTLDCost = true` active ces coûts ; `CTLDPrices[name] = {available, price, reqRank}` donne le prix et le rang de chaque article CTLD (`Config:1958-1959`, `Config:1975-2058`).

## 3. Crédits personnels (« non réclamés ») et comment on les gagne

### Principe

- Un joueur dans un appareil n'alimente pas directement le compte de la coalition : chaque récompense va dans `bc.playerContributions[side][playerName]`, une bourse temporaire qui ne devient crédits de coalition (et crédits de rang personnels) que lorsque le joueur se pose dans une zone amie (`zc:41264-41273`, `zc:41818-41922`).
- Les récompenses sont partagées avec tout l'équipage : `addContribution` ajoute le même montant à chaque membre d'équipage renvoyé par `getMulticrewPlayersNow` (`zc:41264-41273`).
- Un joueur est « inscrit » quand `playerContributions[side][name] ~= nil` ; la plupart des chemins de récompense testent cela avant de payer (`zc:42876`, `zc:41483`, `zc:98272`).
- Un `SCHEDULER` de 60 s (premier passage à 1 s) supprime la bourse des joueurs qui ne sont ni dans une unité de cette coalition ni connectés de ce côté (`zc:43110-43148`).
- Les récompenses sont activées par le setup avec `bc:startRewardPlayerContribution(15, RewardContribution)` : 15 est la récompense par défaut pour un kill non classé, la table est la table de récompenses de Config (`Setup:6000`, `zc:43016-43019`).

### Table des récompenses (`RewardContribution`, `Config:1920-1936`)

| Clé | Par défaut | Payée quand | Code |
|---|---|---|---|
| `infantry` | 10 | kill d'une unité d'attribut `Infantry` | `zc:43181-43184` |
| `ground` | 10 | kill d'une unité d'attribut `Ground Units` | `zc:43189-43192` |
| `sam` | 30 | kill d'une unité avec `SAM SR`, `SAM TR` ou `IR Guided SAM` | `zc:43177-43180` |
| `airplane` | 50 | kill d'une unité avec `Planes` | `zc:43169-43172` |
| `helicopter` | 50 | kill d'une unité avec `Helicopters` | `zc:43173-43176` |
| `ship` | 200 | kill d'une unité avec `Ships` | `zc:43185-43188` |
| `structure` | 100 | kill d'un objet avec `Buildings`, ou d'une static de catégorie 4 qui est un groupe « construit » de zone ou l'installation d'entrepôt de la zone | `zc:43193-43225` |
| (par défaut) 15 | — | toute autre static (message `REWARD_UNIT_KILL`) | `zc:43165`, `zc:43226-43228` |
| `ctldGround` / `ctldAir` | 10 / 20 | une unité terrestre que le joueur a construite avec CTLD tue une unité terrestre / aérienne ennemie | `zc:42827-42849`, `zc:42791-42810` |
| `crate` | 100 | une caisse de supply est livrée à une zone amie (payée directement à la coalition ; 25 % si la zone n'a pas de demande) | `zc:55236-55246` |
| `rescue` | 200 | un pilote à terre est récupéré (plus les 75 % que le joueur éjecté avait perdus) | `zc:100540-100550` |
| `enemyPilotCapture` | 200 | par pilote ennemi livré à une zone amie | `zc:42284-42300` |
| `Zone upgrade` | 100 | supply du joueur livrée à une zone amie (25 % quand la zone ne peut pas recevoir de supply) | `zc:98269-98290` |
| `Zone capture` | 200 | supply du joueur livrée à une zone neutre qui aboutit à une capture | `zc:98248-98267`, `zc:24691-24710` |
| `Warehouse delivery` | 150 | cargaison d'entrepôt CTLD livrée (point d'accroche dans le script CTLD) | `Foothold CTLD.lua:5305` |

- Les statics critiques d'une zone (`zone.criticalObjects`) ne paient jamais (`zc:43155-43163`).
- Autres sources de gains : temps de vol (§3.3), ravitaillement en vol (§3.4), hauts faits de carrière (§9), missions joueur (§10–11).

### 3.1 Attribution des kills

- Un seul `world.addEventHandler` est installé par `BattleCommander:init` ; il appelle `_handleWorldEvent` pour chaque événement (`zc:30226-30231`).
- Les ids d'événements pertinents pour les récompenses sont `S_EVENT_LAND`, `S_EVENT_EJECTION`, `S_EVENT_PILOT_DEAD`, `S_EVENT_KILL`, `S_EVENT_SCORE`, `S_EVENT_UNIT_LOST` (`zc:43024-43031`) ; `S_EVENT_TAKEOFF`, `S_EVENT_BIRTH` (id 15), `S_EVENT_LANDING_AFTER_EJECTION`, `S_EVENT_SHOT` (cargaison Hercules) et `S_EVENT_DEAD` (piste d'aérodrome uniquement) sont traités plus tôt dans la même fonction (`zc:42906-42992`).
- `S_EVENT_HIT` n'est pas utilisé pour l'attribution : le crédit de kill repose uniquement sur `S_EVENT_KILL` (initiateur = tueur, cible = victime) (`zc:43041-43044`, `zc:42812-42891`).
- `_handleRewardKillEvent` : l'initiateur doit être un avion ou un hélicoptère contrôlé par un joueur (`unit:getPlayerName()`), inscrit, et la coalition de la cible doit être différente et non neutre (`zc:42868-42887`).
- Cible de la même coalition → branche de tir ami (§3.6) (`zc:42878-42879`).
- Cible ennemie → `_handleRewardEnemyKill` : classe la cible avec `objectToRewardPoints2`, ajoute le gain à la bourse, ajoute une statistique temporaire de la classe, enregistre le kill de carrière, alimente les compteurs de mission CAS/SEAD/CAP et le registre des cibles de mission (`zc:42677-42789`).
- Le message par kill `[player] <text>` n'est montré au groupe du tueur que si `ShowKills == true` (Config, par défaut `false`) (`zc:42711-42714`, `Config:275`).
- Une unité terrestre dont le `unit:getID()` est enregistré dans `Foothold_ctld.PlayerCtldRewards.unitsById` crédite son constructeur (`ctldGround`/`ctldAir`) quand elle tue un ennemi (`zc:42827-42849`).
- Les kills de l'IA (sans nom de joueur) sont seulement enregistrés comme « air combat evidence » pour le Director IA, pas récompensés (`zc:42888-42890`, `zc:42584-42639`).
- Kills par splash : `Splash_Damage_3.4.1_leka.lua` est un script facultatif (`SplashDamage`, par défaut `false` dans Config, `Config:272-273`) ; le chemin de récompense du moteur n'a pas d'attribution splash dédiée et ne réagit qu'au `S_EVENT_KILL` qu'il reçoit.
- Le script de splash n'émet pas d'événements : il crédite lui-même les kills par splash, via les fonctions publiques du moteur. Chaque objet rouge qu'il trouve détruit par une explosion est valorisé avec `bc:objectToRewardPoints2` et mis en file ; un `S_EVENT_KILL` reçu pour le même id d'unité retire l'entrée de la file (le moteur l'a déjà payée) ; un timer (toutes les 5 s tant que des entrées sont en file, sinon 60 s) appelle ensuite, pour chaque entrée restante dont le joueur est inscrit (`bc.playerContributions[2][player] ~= nil`), `bc:addTempStat`, `bc:addContribution(player, 2, points)`, `bc:registerCasMissionKill`, `bc:registerSeadMissionKill` et `bc:registerMissionTargetKill` (`Splash_Damage_3.4.1_leka.lua:1304-1346`, `:3492-3532`, `:4549-4559`, `:4780-4783`).
- Le crédit de splash est donc réservé au bleu (le côté 2 est codé en dur) et contourne les compteurs de kills de carrière ainsi que l'« air combat evidence » que `_handleRewardEnemyKill` enregistre (`Splash_Damage_3.4.1_leka.lua:3511-3519`, `zc:42677-42789`).
- `S_EVENT_SCORE` sert aux « score targets » (objectifs de frappe sur décor/static) : quand un joueur déclenche un événement de score avec le commentaire `general` et un montant 0, un timer de 6 s revérifie chaque objet `ScoreTargets[flag]` enregistré et compte comme détruits ceux dont la vie relative est ≤ 50 % (`zc:42083-42131`).

### 3.2 Encaisser à l'atterrissage, perdre à la mort

- Décollage (`S_EVENT_TAKEOFF` → `LogisticCommander:_handleTakeoff` → `_armPlayerTakeoffRewardState`) : arme la pénalité de perte (`lossPenaltyArmByPlayer[player] = true` quand `CreditLosewhenKilled` ou `RankLoseWhenKilled`), fait passer un bonus de rotation de `armed` à `active`, et enregistre `flightTimeTakeoffByPlayer[player] = {t, gid, rewardEligible}` (`zc:42947-42979`, `zc:101289-101318`).
- Atterrissage (`S_EVENT_LAND`, joueur) : `_handleRewardPlayerLanding` livre d'abord les pilotes ennemis transportés, puis, si la bourse est positive ou si une récompense de temps de vol est due, cherche une zone amie contenant le point d'atterrissage (`CustomZone:isInside`), sinon une zone `CTLD FARP` / `Escort Mission FARP` (Moose `GROUP:IsInZone`), sinon un porte-avions à moins de 200 m (`zc:42442-42582`).
- Le joueur reçoit `PLAYER_LANDED_CLAIM_ZONE` (« landed at <zone>, wait N seconds ») et un `SCHEDULER` à usage unique se déclenche 5 s plus tard (10 s sur un porte-avions) ; la réclamation n'est payée que si le même objet unité est toujours là, toujours posé (`Utils.isLanded`), vivant (`getLife() > 0`), à l'intérieur de la zone, et si la zone appartient toujours à son camp (`zc:42486-42513`, `zc:42568-42577`).
- `_claimLandingRewards` (par membre d'équipage) : montant = bourse + bonus de rotation + bonus de nuit ; `bc:addFunds(side, amount)` ; les statistiques temporaires sont validées dans les statistiques persistantes avec `Points += amount` ; la bourse est remise à zéro ; avec `RankingSystem`, le même montant est ajouté aux crédits de rang personnels et une promotion est annoncée avec `PLAYER_PROMOTED` et le son `Rank.ogg`, puis le menu de boutique du groupe est reconstruit (`zc:41869-41917`).
- La coalition reçoit un message d'encaissement qui liste chaque membre d'équipage, le montant et les statistiques par vol (`PLAYER_REDEEM_HEADER`, `PLAYER_REDEEM_LINE`, `zc:41839`, `zc:41889`, `zc:41918-41920`).
- Une récompense gagnée par un joueur déjà au sol (par exemple un partenaire de mission conjointe qui termine le travail) déclenche un `S_EVENT_LAND` synthétique via `world.onEvent` après 5 s, pour qu'elle soit encaissée sans nouveau vol (`zc:41316-41328`).
- Éjection (`S_EVENT_EJECTION`) : 25 % de la bourse vont immédiatement à la coalition (`PLAYER_EJECTED_CREDITS`), le joueur reçoit `Points +25 %` et `Deaths +1`, la bourse est remise à zéro, et les 75 % restants sont stockés comme `lostCredits` dans un enregistrement `ejectedPilotOwnersByAircraft[aircraftId]` attaché au pilote à terre, récupérable par celui qui le sauve (`zc:42133-42159`, `zc:41742-41803`).
- Mort du pilote (`S_EVENT_PILOT_DEAD`) : `Deaths +1`, statistiques temporaires remises à zéro, compteurs de kills de mission remis à zéro, groupe conjoint quitté ; la bourse elle-même est effacée à la naissance de slot suivante par `_cleanupPlayerRespawnRewardState` (`zc:42161-42206`, `zc:41658-41693`).
- Appareil perdu (`S_EVENT_UNIT_LOST`) avec la pénalité armée : 2 s plus tard, sauf si la perte est un team kill par un autre joueur (`lossPenaltySkipByPlayer`), la coalition perd `CreditLosewhenKilledAmount` (si activé) et le joueur perd `RankLoseWhenKilledAmount` crédits de rang et `Points`, avec `PLAYER_AIRCRAFT_LOST_CREDITS`, `PLAYER_AIRCRAFT_LOST_RANK` et éventuellement `PLAYER_DEMOTED` (`zc:42208-42255`).

### 3.3 Bonus de temps de vol, de rotation et de nuit

- `RewardFlightTime` (par défaut `true`), `FlightTimeRewardPerMinute` (2), `RewardAllAircraft` (`false`) et la table par type `AllowedFlightTimeReward` (seuls C-130J-30, CH-47F et Hercules valent `true` par défaut) paient `minutes × rate` quand le vol a duré au moins 300 s ; la statistique `Flight time` est ajoutée en minutes (`Config:2262-2303`, `zc:41826-41837`).
- La récompense de temps de vol est aussi payée à l'éjection (`zc:41727-41740`).
- `TurnaroundRewardPercent` (par défaut 10, max 50) : après un vol qualifiant (≥ 300 s) qui a encaissé des crédits, l'état passe à `armed` ; un nouveau décollage le fait passer à `active` ; l'encaissement suivant reçoit `+N %` (`PLAYER_REDEEM_SAME_AIRCRAFT_BONUS`) ; toute perte, éjection, mort ou réapparition l'efface (`Config:1586-1589`, `zc:41876-41879`, `zc:41913-41915`, `zc:101296-101303`, `zc:42209`, `zc:41664`).
- `NightRewardPercent` (par défaut 10, max 50) : si le décollage a eu lieu de nuit et que le vol a duré ≥ 5 min avec le même objet unité, l'encaissement reçoit `+N %` (`PLAYER_REDEEM_NIGHT_OPERATION_BONUS`) (`Config:1591-1594`, `zc:41838`, `zc:41880-41888`).
- La nuit est calculée dans le moteur avec une formule de lever/coucher du soleil (même modèle que Moose `GetSunRiseAndSet`) à partir de `coord.LOtoLL` de la zone de départ, de `env.mission.date` et d'une table de décalages UTC par théâtre ; les résultats sont mis en cache par zone et par jour (`zc:41504-41612`).

### 3.4 Récompense de ravitaillement en vol

- `RefuelReward` (par défaut 2 crédits par 100 lb) et `RefuelRewardMinimumLbs` (100) (`Config:1938-1939`, `zc:11993-11994`).
- Implémenté dans `WelcomeMessage.lua` sur Moose `EVENTS.Refueling` / `EVENTS.RefuelingStop` (DCS `S_EVENT_REFUELING` / `S_EVENT_REFUELING_STOP`) : la fraction de carburant au début est stockée par unité ; à l'arrêt, `gained = Δfuel × fuelMassMax × 2.2046` ; la récompense va à la bourse, la statistique `Refueling` est comptée une fois par sortie, et les lb sont ajoutées à la statistique de carrière (`WelcomeMessage.lua:2731-2829`).
- Quand l'événement de début vient du ravitailleur (pas d'initiateur joueur), chaque appareil joueur à moins de 300 m du ravitailleur est enregistré comme se ravitaillant (`WelcomeMessage.lua:2751-2776`).

### 3.5 Points d'accroche logistique, CSAR et capture (côté récompense uniquement)

- Supply déchargé par un joueur dans une zone amie : récompense `Zone upgrade` à la bourse et `Zone upgrade +1` (25 % et un message « no demand » si la zone ne peut pas recevoir de supply) (`zc:98269-98290`).
- Un supply déchargé dans une zone neutre démarre une « capture temporisée » avec une charge utile de livraison `{captureFundReward, upgradeFundReward, playerName}` ; la récompense est payée quand la livraison de capture réussit, par le handler enregistré `zonecommander_capture_delivery` (`zc:98248-98267`, `zc:30232-30234`, `zc:24691-24710`).
- Sauvetage de pilote : `rewards.rescue` plus les `lostCredits` de la victime, statistique `Pilot Rescue`, message `CSAR_RESCUED_WITH_CREDITS` (`zc:100538-100558`).
- Pilote ennemi livré : `enemyPilotCapture × count`, statistique `Enemy Pilot Capture`, puis après 10 à 60 s aléatoires un « debrief » avec 50 % de chance par pilote d'accorder 30 min d'intel sur la zone et 20 % de révéler l'opération en cours du Director ennemi (`zc:42284-42363`, `zc:42365-42440`).
- `CsarPilotSpawnWithoutCreditsChance` (par défaut 50) : chance de faire apparaître un pilote à terre quand le pilote éjecté ne portait aucun crédit (`Config:2229-2230`).

### 3.6 Tir ami

- Un kill sur une cible de la même coalition annonce `FRIENDLY_FIRE_PLAYER` / `FRIENDLY_FIRE_UNIT` à la coalition, enregistre un kill ami de carrière, marque la victime pour qu'on ne lui impute pas la pénalité de perte, et, avec `RankingSystem` et la pénalité armée (c'est-à-dire après un décollage), retire `FriendlyFireRankPenalty` (par défaut 500) crédits de rang et `Points`, au plus une fois par 30 s (`zc:42641-42675`, `Config:287-288`).

### Notes sur le mécanisme

- Tables d'état : `playerContributions[side][name]`, `tempStats[name][stat]` (sortie en cours), `sessionStats`, `playerStats` (persistant), `flightTimeTakeoffByPlayer`, `turnaroundRewardStateByPlayer`, `lossPenaltyArmByPlayer`, `lossPenaltySkipByPlayer`, `lossPenaltyCooldownUntilByPlayer`, `refuelLbsByPlayer`, `ejectedPilotOwnersByAircraft` (`zc:40510-40575`, `zc:43020-43021`, `zc:41767-41770`).
- Moose utilisé : `SCHEDULER:New` (qui encapsule `timer.scheduleFunction`) pour les réclamations différées et la purge de 60 s, `UNIT:Find():IsInZone`, `GROUP:FindByName():IsInZone`, `COORDINATE` pour les cas FARP/porte-avions, handlers d'événements Moose dans `WelcomeMessage.lua` pour le ravitaillement (`zc:42498-42499`, `zc:42512`, `zc:42529-42534`, `zc:42561-42562`).
- La gestion du multicrew utilise `net.get_player_list` et `net.get_player_info(pid,'slot')` pour distinguer le pilote (sous-slot 0) de l'équipage (`zc:40551-40571`, `zc:42134-42136`).

### Notes de reproduction

- La règle « encaisser à l'atterrissage » exige un test d'atterrissage robuste, l'identité de l'objet (`unit.id_`) à travers le délai de 5 s et une revérification de la possession de la zone ; un touch-and-go ne doit pas payer.
- Le partage multicrew dépend de l'accessibilité de l'API `net.*` depuis l'environnement de scripting de mission.
- La classification des récompenses s'appuie sur les attributs d'unité DCS (`hasAttribute`), pas sur des listes de types.
- Tout le travail par événement est en O(1), sauf `objectToRewardPoints2` pour les statics, qui parcourt les listes `criticalObjects` et `built` de chaque zone (`zc:43155-43163`, `zc:43202-43215`).

## 4. Le menu de boutique (F10) et la boutique par marqueur de carte

### Ce que voit le joueur

- Racine : `F10 > Other > Shop` (`MENU_SHOP` = "Shop"), un menu par groupe de joueur (`zc:22400-22402`, `L10N:161`).
- En dessous, un sous-menu par catégorie qui a au moins un article visible, dans un ordre fixe : "AI Attack", "Zone Upgrades", "JTAC & Intel", "Marking & Tools", "Combined Arms", "Capture & resources", "Other support" (`Setup:5515-5534`, `zc:22445-22476`, `zc:22524-22530`, `L10N:548-553`).
- Chaque article est libellé `[<cost>] <name>` (`SHOP_ITEM_LABEL`, `zc:22492`, `L10N:1549`).
- Un article qui nécessite une cible est un sous-menu qui liste les zones candidates (ordonnées par numéro de waypoint de la zone, la plus proche du front d'abord selon `sortPolicy`), chaque libellé de zone étant éventuellement suffixé du tag de waypoint et du nombre d'upgrades `built/total` ; les articles sans sélecteur sont des commandes directes (`zc:22506-22520`, `zc:22166-22231`).
- Les listes de plus de 9 entrées sont paginées avec des sous-menus « More » imbriqués (9 entrées, puis un sous-menu `MENU_MORE`, récursivement) (`zc:22353-22368`, `zc:22488-22504`).
- Dernière entrée du menu Shop : "Budget overview" (`zc:22411-22413`, `zc:22531`).
- Les articles dont le `reqRank` est supérieur au rang du joueur ne sont pas affichés du tout (`zc:22428-22439`).
- Un sélecteur vide affiche une seule ligne d'information (par exemple "No eligible zone") (`zc:22300-22305`).
- Boutique par marqueur : une marque de carte dont le texte est `buy` affiche la liste avec les ids (`buy:<id>`) ; une marque `buy:<id>` achète l'article avec `{zone = zone under the mark, point = mark position}` comme paramètres ; le rang est vérifié en premier, avec un message détaillé « Insufficient rank » (`zc:28555-28620`).
- `adminbuy` / `adminbuy:<id>` font la même chose sans acheteur et donc sans vérification de rang, quand `AllowAdminBuy` (par défaut `true` dans Config) ; l'alias admin `buyWithoutRank` (ou l'ancien `köp` suédois) fait la même chose (`zc:28622-28706`, `Config:1946-1948`, `Config:3488-3489`).
- D'autres textes de marqueur liés à ce thème sont des mots réservés : `stats`, `top`, `mystats`, `missions`, `intelstatus`, `addrank:<name>,<n>`, `caphere1/2`, `arcohere1/2`, `texacohere1/2`, `farphere…` (`zc:28358-28408`).

### Mécanisme

- Les menus sont construits avec l'API DCS brute (`missionCommands.addSubMenuForGroup`, `addCommandForGroup`, `removeItemForGroup`), pas avec les `MENU_*` de Moose (`zc:22401-22413`, `zc:22519`).
- État par groupe : `bc.groupSupportMenus[groupId] = {menu, items = {handles}, selectorNodes = {[itemId] = {menu, children, category, coalition, defaultRows}}}` (`zc:22400-22410`, `zc:22510-22516`).
- `refreshShopMenuForGroup` retire chaque handle enfant suivi et reconstruit tout l'arbre pour un groupe ; il est appelé à la naissance de slot, à la promotion/rétrogradation, quand un article est ajouté à l'étagère ou retiré (`zc:22395-22533`, `zc:41907`, `zc:42248`, `zc:19358`, `zc:19365`).
- Un ancien menu pour toute la coalition « shop for all » (`refreshShopMenuForCoalition`, `missionCommands.addCommandForCoalition`) existe encore dans le code (`zc:13041-13072`).
- Rafraîchissement des sélecteurs (zones qui changent de camp, upgrades, demande de supply) : `requestShopSelectorRefreshForCoalition(side, tags|itemIds)` accumule les articles « sales », un `SCHEDULER` antirebond de 0,15 s les verse dans une file de travail, et un worker tourne tous les `shopSelectorRefreshInterval` (0,5 s) en traitant au plus `shopSelectorRefreshBudget` (8) tâches « groupe × article » par tick ; un tick sur quatre est réservé au menu Dynamic Control quand les deux files ont du travail (`zc:17382-17411`, `zc:17615-17689`).
- Une reconstruction de sélecteur est sautée quand les lignes candidates et les libellés sont inchangés pour ce groupe/cette locale (`zc:22266-22279`).
- Les zones candidates viennent de « buckets » précalculés (`blue_unsuspended`, `enemy_unsuspended`, …) maintenus de façon incrémentale quand une zone change d'état, ou d'un `candidatesBuilder`, ou de toutes les zones ; les filtres sont `targetzoneside`, `allow`, `extraPredicate`, `includeSuspended` (`zc:22147-22215`).
- Buckets (`bc._shopSelectorBuckets[name]`, listes de `{z = zone, wp = waypoint number}`), tous restreints aux zones actives et non masquées : `blue_visible`, `blue_unsuspended`, `zone_supply_targets`, `blue_airbase_unsuspended`, `enemy_unsuspended`, `advance_capture_targets` (`zone:canAdvanceCapture()`, pas de porte-avions), `neutral_unsuspended`, `neutral_capture_targets` (neutre et soit pas neutre au départ, soit déjà capturée une fois par le rouge), `warehouse_targets` (zone d'aérodrome bleue qui n'est pas un Logistic Center) ; une zone suspendue « idle » (en dormance) compte comme non suspendue (`zc:34139-34189`).
- `_applyZoneShopSelectorDelta(zone, previousState)` est appelé quand une zone change d'état : pour chaque bucket, il compare l'appartenance avant et après et ajoute ou retire l'unique entrée, puis `_getZoneSelectorRefreshTags` renvoie les tags (`friendly_targets`, `enemy_targets`…) des articles de boutique dont les sélecteurs doivent être remis en file (`zc:34191-34262`, `zc:34263`).
- La boutique par marqueur est un handler d'événement sur l'id d'événement 26 (`S_EVENT_MARK_CHANGE`) installé par `startMonitorPlayerMarkers` (`zc:28354`, `zc:28455-28456`).
- Le texte est localisé par groupe via `L10N:ForGroup(groupId)` ; les noms d'articles peuvent être des fonctions `name(T)` résolues au moment de l'affichage (`zc:19307-19320`).

### Notes de reproduction

- Le menu F10 de DCS contient 10 entrées par niveau, d'où le code de pagination partout.
- Reconstruire les menus de groupe coûte cher avec beaucoup de joueurs et beaucoup de zones ; la file + le budget + la vérification « inchangé » existent pour éviter les saccades et le renouvellement des ids de commande.
- `missionCommands.removeItemForGroup` sur un parent retire ses enfants, donc les handles doivent être suivis par groupe et abandonnés quand le groupe meurt.

## 5. Catalogue de la boutique (setup Caucase, Config par défaut)

Colonnes : prix = `ShopPrices` (`Config:1771-1842`) ; rang = `ShopRankRequirements` (`Config:1846-1916`) ; stock d'après `addShopItem` (`Setup:5504-5751`) : ∞ = `-1`.
« Blue » = sur l'étagère bleue ; « PvP red » = aussi sur l'étagère rouge quand `GlobalSettings.pvpEnabled`.

### AI Attack

| id | Nom | Prix | Rang | Stock | Sélection de la cible | Effet | Code |
|---|---|---|---|---|---|---|---|
| `dynamiccap` | CAP Flight | 500 | 2 | ∞ (un actif à la fois) | zone amie → Orbit, ou cap (Hot 360…315) → branche de 10–50 NM | fait apparaître un vol de chasse IA qui tourne en orbite/racetrack sur la zone ; voir §6 | `Setup:3009-3096`, `Setup:5537-5538` |
| `dynamiccas` | CAS Flight | 1000 | 5 | ∞ (un actif) | zone ennemie | fait apparaître un vol CAS depuis la zone amie sûre la plus proche, attaque la zone | `Setup:3283-3353`, `zc:107991` |
| `dynamicbomb` | Bomber Flight | 500 | 4 | ∞ (un actif) | zone ennemie | fait apparaître un vol de bombardiers qui bombarde la zone | `Setup:3580-3645`, `zc:109391` |
| `dynamicsead` | SEAD Flight | 500 | 4 | ∞ (un actif) | zone ennemie → "Push when ready/now" ou "Push on command" | fait apparaître un vol SEAD ; en mode commande il attend jusqu'à ce que le joueur utilise Dynamic Control > Push | `Setup:3450-3570`, `zc:108779`, `zc:108699` |
| `dynamicdecoy` | TALD Decoy Flight | 300 | 1 | ∞ | zone ennemie (+ mode de push) | fait apparaître un vol qui lance des leurres vers la zone | `Setup:3360-3447`, `zc:108316` |
| `dynamicstatic` | Static structure Flight | 500 | 4 | ∞ | zone ennemie qui a des structures | fait apparaître un vol de frappe contre les bâtiments de la zone | `Setup:3841-3882`, `zc:109719` |
| `groundattack` | Ground attack | 1000 | 5 | ∞ | zone ennemie (PvP : origine FARP facultative) | lance un convoi terrestre depuis la zone amie ou le FARP le plus proche à portée | `Setup:4473-4544`, `zc:20673` |
| `strategicbomber` | Strategic Bomber | 1500 | 6 | ∞ | zone ennemie → options d'origine / d'escorte construites par `StrategicBomber.BuildBlueShopMenu` | lance un raid de bombardiers lourds avec escorte IA ou joueur | `Setup:3652-3838`, `zc:3518`, `zc:3759` |
| `cruisemsl` | Cruise Missile Strike | 800 | 10 | 12 | — | mis sur l'étagère par `addShopItem` mais **non enregistré** dans le setup Caucase, donc il n'y apparaît jamais ; il est enregistré dans les setups Syrie, golfe Persique et Atlantique Sud, où l'acheteur choisit une zone ennemie et où l'action est `bc:fireAtZone(zone, 'cruise1', true, 8)` (le groupe `cruise1` tire 8 missiles sur la zone ; `footholdSyriaSetup.lua:2913-2933`, `zc:24975`) | `Setup:5555`, `zc:19342-19344` |

### Zone Upgrades (ajoute un groupe défensif permanent à une zone amie)

| id | Nom | Prix | Rang | Template ajouté | Code |
|---|---|---|---|---|---|
| `zinf` | Infantry | 500 | 5 | `blueInfantry` | `Setup:4869-4910` |
| `zarm` | Armor | 1000 | 7 | `Blue Armor Modern` / `Coldwar` / `Vietnam` selon l'ère | `Setup:5275-5320`, `Setup:39-41` |
| `zhawk` | Hawk | 2000 | 6 | `Blue SAM HAWK` | `Setup:4977-4991` |
| `zsam` | NASAMS (Modern only) | 2000 | 6 | template NASAMS | `Setup:4913-4975`, `Setup:5845-5848` |
| `zpat` | Patriot (not Vietnam) | 5000 | 8 | Patriot ; un par zone | `Setup:5342-5346`, `zc:21854-21862` |
| `zavenger` | Avenger | 1000 | 5 | `Blue SAM SHORAD Avenger` | `Setup:4979` |
| `zroland` | Roland | 1000 | 5 | `Blue SAM SHORAD Roland` | `Setup:4980` |
| `zgepard` | Gepard | 750 | 4 | `Blue SAM AAA Gepard` | `Setup:4981` |
| `zvulcan` | Vulcan | 500 | 3 | `Blue SAM AAA Vulcan` | `Setup:4982` |
| `zcram` | C-RAM (Modern only) | 1500 | 6 | `Blue SAM AAA C-RAM` | `Setup:4983` |
| `zpantsir` | Pantsir (PvP, Modern) | 1500 | 6 | `Blue SAM SHORAD Pantsir` | `Setup:4993-5001` |
| `zhimars` | HIMARS (Modern) | 2500 | 8 | `HiMars` | `Setup:5005-5046` |
| `zgci` | GCI station | 500 | 3 | `BlueGCI` | `Setup:5352-5394` |
| `zewr` | EWR (PvP) | 500 | 3 | `Blue EWR Upgrade` | `Setup:5614-5622` |
| `gslot` | Unlock extra upgrade slot | 3000 | 9 | stock 1 ; relève d'un la limite par zone | `Setup:5322-5338` |

- Cible : une zone amie, active, hors porte-avions, dont `upgradesUsed` est inférieur à la limite (`isEligibleBlueZoneUpgradeTarget`, `zc:23786-23800`).
- Limite d'upgrades achetés par zone : 2 pour le bleu (1 pour le rouge en PvE), +1 une fois `gslot` acheté (`bc.globalExtraUnlock`) (`zc:23778-23784`, `zc:48130-48136`).
- Effet : `zone:addExtraSlot(template)` incrémente `upgradesUsed` et `level`, ajoute le template à `zone.upgrades.blue|red` et à `zone.extraUpgrade` (persisté) ; le groupe apparaît ensuite par le cycle normal de construction/amélioration de la zone (`zc:48130-48161`).
- Message `SYRIA_SHOP_UPGRADE_ADDED` à la coalition ; `bc:refreshZoneLabel` met à jour le libellé de la carte (`Setup:4889-4893`).

### JTAC & Intel

| id | Nom | Prix | Rang | Cible | Effet | Code |
|---|---|---|---|---|---|---|
| `jtac` | MQ-9 Reaper JTAC | 500 | 2 | zone ennemie | déploie l'un des deux drones JTAC au-dessus de la zone (2 actifs au plus, le plus ancien est retiré) et affiche son menu | `Setup:4246-4275` |
| `smoke` | Smoke markers | 20 | 1 | zone ennemie | `trigger.action.smoke` sur jusqu'à 3 unités/statics aléatoires de la zone | `Setup:4547-4574`, `zc:23618-23660` |
| `flare` | Flare markers | 20 | 1 | zone ennemie | 3 salves de `trigger.action.signalFlare` rouges, espacées de 5 s, sur jusqu'à 3 cibles | `Setup:4577-4604`, `zc:23662-23694` |
| `illum` | Illumination bomb | 100 | 1 | zone ennemie | bombes éclairantes à 1000 m au-dessus des groupes de la zone (puissance 700000) | `Setup:4607-4634`, `zc:23696-23716` |
| `intel` | Satellite Intel | 150 | 5 | zone ennemie | `startZoneIntel(zone, nil, side)` : 60 min d'intel sur la zone (marqueurs de carte des unités, rafraîchis périodiquement) | `Setup:4762-4795`, `zc:6954-6963` |
| `9lineam` / `9linefm` | JTAC 9-line AM / FM | 0 | 1 | zone ennemie | drone JTAC 9-line radio gratuit sur la zone | `Setup:4316-4410` |

### Combined Arms (PvE uniquement)

| id | Nom | Prix | Rang | Effet | Code |
|---|---|---|---|---|---|
| `armor` | Deploy armor | 100 | 3 | `CustomZone:spawnGroup('ca-tanks')` dans une zone amie (un groupe pilotable par un joueur) | `Setup:4057-4079` |
| `artillery` | Deploy artillery | 100 | 3 | `spawnGroup('ca-arty')` | `Setup:4083-4105` |
| `recon` | Deploy recon | 50 | 3 | `spawnGroup('ca-recon')` | `Setup:4109-4131` |
| `airdef` | Deploy air defence | 150 | 3 | `spawnGroup('ca-airdef')` | `Setup:4135-4157` |
| `calav` / `camgs` / `cadragoon` | Deploy LAV-25 / M1128 MGS / M1296 Dragoon | 100 | 3 | `spawnGroup('CA-…Hunter_Killer_…')` | `Setup:4161-4232` |

### Capture & resources

| id | Nom | Prix | Rang | Cible | Effet | Code |
|---|---|---|---|---|---|---|
| `capture` | Capture neutral zone | 500 | 1 | zone neutre | `bc:requestCaptureMission` : envoie le groupe de supply IA disponible le plus proche (hélico, avion, convoi) pour la capturer ; payé quand il décolle | `Setup:4638-4731`, `zc:23416` |
| `advancecapture` | Advance capture (PvE) | 500 | 1 | zone ennemie dont il reste ≤ `AdvanceCaptureRemainingThreshold` % de ses groupes d'upgrade | idem, lancé avant que la zone soit neutre | `Setup:4733-4758`, `Config:1598-1602`, `zc:50133` |
| `supplies2` | Resupply friendly zone | 200 | 1 | zone amie qui a besoin de supply | `bc:requestFriendlySupplyMission` (livraison IA, au plus 2 livraisons payées en cours par zone) ou, avec `AllowScriptedSupplies`, une étape immédiate de stock/upgrade | `Setup:3893-4014`, `zc:23255-23300` |
| `supplies` | Fully upgrade friendly zone | 1000 | 6 | zone amie pas entièrement construite | `zone:UpgradeUntilComplete` (sur l'étagère seulement quand `AllowScriptedSupplies`) | `Setup:4017-4052`, `Setup:5727-5731` |
| `zlogc` | Logistic Center [WH] | 5000 | 1 | zone d'aérodrome amie entièrement améliorée | fait apparaître une static d'entrepôt `[WH] <zone>` et active la logistique d'entrepôt | `Setup:5048-5066`, `zc:24155-24200` |
| `zwhrepair` | Repair Logistic Center | 2000 | 1 | zone dont l'entrepôt est détruit | timer de réparation de 30 min | `Setup:5069-5086`, `zc:24236-24253` |
| `zsup3` | Add 3 supplies to zone (PvE) | 750 | 2 | zone amie | `bc:applyZoneSupplyStockAdd(zone, 3)` | `Setup:5089-5106` |
| `zwh50` | Resupply warehouse with 50 (PvE) | 500 | 2 | zone avec entrepôt | `bc:applyWarehouseResupply` | `Setup:5108-5128` |

Détail des actions de supply et de capture (`Setup:3886-4052`, `zc:23255-23414`) :

- `supplies2` avec livraison IA (par défaut, `AllowScriptedSupplies = false`) : le sélecteur de zone liste les zones amies, actives, non suspendues, marquées `_needsSupplyForMenu`, triées `friendly_frontline`, avec le suffixe `built/total` (`Setup:3931-3937`, `Setup:4005`).
- Quand le meilleur groupe de supply disponible est un hélicoptère ou un convoi et que la coalition possède un FARP dynamique (ou qu'il en existe un à moins de 30 NM de la zone), l'entrée de zone devient un sous-menu "Deploy from FARP?" > Yes / No, et l'achat porte `allowFarp` (`Setup:3950-3997`).
- `bc:requestFriendlySupplyMission(zone, params)` : refuse si la zone n'est pas amie ; au plus `GlobalSettings.maxPaidSupplyPerZoneBlue` (par défaut 2) livraisons payées peuvent être en cours par zone (`_formatSupplyInProgressMessage`) ; puis `_selectShopSupplyCommander` choisit le `GroupCommander` de supply disponible le plus proche (en préférant un commandant basé sur un entrepôt pour une « livraison de stock » `supplies2`), ou signale `LOGISTICS_NO_SUITABLE_SUPPLY` (`zc:23276-23321`).
- Le commandant choisi est redirigé et forcé aussitôt dans son état de lancement (`targetzone = zone`, `state = 'preparing'`, `urgent = true`, `lastStateTime` repoussé loin dans le passé, `_activateFsmGroup`), en décollant éventuellement du FARP le plus proche ; les drapeaux `_paidSupplyParallelLaunch`, `_paidSupplyStockpileDelivery`, `_shopLaunchRequested` le marquent comme un vol payé (`zc:23346-23394`).
- Messages : « looking for pilots » puis, au lancement, `LOGISTICS_FRIENDLY_HELO_SCRAMBLE`, `LOGISTICS_FRIENDLY_RESUPPLY_TO` (avion), un message d'envoi de navire, ou `LOGISTICS_FRIENDLY_CONVOY_MOVING` (`zc:23397-23409`).
- La fonction renvoie `{deferredShopPurchase = true}` : les 200 crédits sont réservés et ne sont débités que lorsque le groupe décolle réellement (§2) (`zc:23410-23412`, `zc:23355`).
- Un achat `supplies2` sur une zone qui n'a besoin de rien est tout de même accepté comme « livraison de stock » (il s'ajoute au stock de supply de la zone) (`zc:23261`, `zc:23288-23290`).
- `supplies2` avec `AllowScriptedSupplies = true` (ou pour une zone de porte-avions) : pas de vol, la zone reçoit aussitôt une unité de supply accélérée (`zone:_addExpeditedRegularSupplyStock(1)` ; une zone de porte-avions reçoit `zone:upgrade()`), texte de refus `SYRIA_SHOP_ZONE_NO_RESUPPLY` (`Setup:3915-3927`).
- `supplies` (enregistré seulement quand `AllowScriptedSupplies`) : `zone:UpgradeUntilComplete(callback)` et un message de coalition `SYRIA_SHOP_ZONE_FULLY_UPGRADED` à la fin ; renvoie `false` (pas de facturation) si la zone était déjà complète (`Setup:4015-4035`).
- Les articles Combined Arms détruisent leurs groupes template au chargement (`Group.getByName('ca-tanks-Coldwar'):destroy()` …) et les font apparaître à l'achat avec `CustomZone:spawnGroup` (`Setup:4053-4232`).

### Other support

| id | Nom | Prix | Rang | Stock | Cible | Effet | Code |
|---|---|---|---|---|---|---|---|
| `dynamicarco` | Tanker (Drogue) | 1000 | 3 | 1 | zone amie → orbite ou cap/branche | déblocage unique ; ensuite le ravitailleur est repositionné gratuitement depuis Dynamic Control ou avec des marques `arcohere1/2` | `Setup:3099-3189`, `zc:21809-21852`, `zc:107690` |
| `dynamictexaco` | Tanker (Boom) | 1000 | 3 | 1 | idem | idem | `Setup:3191-3281`, `zc:107813` |
| `farphere` | Deploy FARP | 1000 | 4 | ∞ | marqueur de carte `buy:farphere` uniquement (l'entrée de menu n'affiche que l'aide) | un hélicoptère IA vole de l'aérodrome/FARP ami le plus proche jusqu'à la marque et construit un FARP ; refusé à l'intérieur d'une zone, à moins de 10 NM d'une zone ennemie, ou sans emplacement plat à moins de 100 m | `Setup:5398-5403`, `zc:21332-21380` |
| `replaceawacs` | Replace one lost AWACS (PvP) | 1000 | 3 | — | aucune | `bc:replaceLostAwacs(side)` | `Setup:3283-3285`, `zc:106029` |

### Articles IA rouges (PvE ; achetés par le Director rouge, pas par les joueurs)

| id | Prix | Effet | Code |
|---|---|---|---|
| `redzoneupgrade` | 3000 (`RED_ZONE_UPGRADE_COST`, `Setup:4799`) | le Director choisit une zone rouge et lui ajoute un emplacement d'upgrade, puis l'améliore aussitôt ; annoncé aux deux camps (`WAREHOUSE_RED_REINFORCED`) | `Setup:4802-4808`, `zc:24115-24153` |
| `redmassattack` | 2500 | `bc:triggerRedMassAttack()` | `Setup:4811-4822`, `zc:35003` |
| `strategicbomberRed` | 1500 | `StrategicBomber.LaunchRed()` | `Setup:4827-4829` |
| `redwarehouse` / `redwhrepair` | 3000 / 2000 (valeurs par défaut du setup, absentes de la table Config, `Setup:2931-2932`) | crée / répare un dépôt de supply rouge à l'arrière | `Setup:4833-4865` |

- Le compte rouge est alimenté par les propres règles de revenu du camp rouge et dépensé par `BudgetCommander`/le Director (un autre thème) ; les entrées d'étagère sont `bc:addShopItem(1, …)` (`Setup:5504-5512`).

### Boutique rouge en PvP

- Avec `PvP = true`, la coalition rouge reçoit sa propre étagère avec les articles de vol, `groundattack`, `strategicbomber`, `gslot`, marqueurs, intel, `capture`, `supplies2`, `supplies`, `zlogc`, `zwhrepair`, ravitailleurs et `farphere` (`Setup:5538-5551`, `Setup:5574-5576`, `Setup:5690-5702`, `Setup:5723-5736`, `Setup:5745-5751`).
- Les upgrades de zone rouges sont des articles distincts `rzinf`, `rzarm1-3`, `rzaaa`, `rzsa2`, `rzsa3`, `rzsa6`, `rzsa10`, `rzsa11`, `rzsa8`, `rzsa9`, `rzsa13`, `rzsa15`, `rzsa19`, `rztorm2`, `rzpantsir`, `rzmanpad`, `rzgci`, `rzarty`, `rzewr`, chacun tarifé et classé comme un article « tier » bleu (par exemple `rzsa10` = `zpat`), filtrés par ère, présence du template et `RedTemplateEnabled` (`Setup:5637-5683`).
- Chaque article PvP porte `upgradeSide` ; `buyShopItem` refuse un achat venant de l'autre coalition (`zc:21791-21803`).
- Les articles de vol en PvP gardent un runtime par camp dans `item.flightBySide[side]` et exigent un template de groupe pour ce camp (`zc:19332-19338`, `Setup:3066-3075`).

### Comment les effets achetés sont exécutés (résumé)

- Vols IA (`dynamiccap`, `dynamiccas`, `dynamicsead`, `dynamicdecoy`, `dynamicbomb`, `dynamicstatic`) : Moose `SPAWN:NewFromTemplate(...)` puis `SpawnAtParkingSpot` / `SpawnAtAirbase` (quand `AIAttackTakeoffFromGround`, par défaut `true` dans Config) ou `SpawnFromCoordinate` (départ en vol) ; le `GROUP` Moose obtenu reçoit des options et une route (`COORDINATE:WaypointAir…`, `GROUP:Route`) (`zc:107095-107111`, `zc:108165-108185`, `zc:107270-107273`, `zc:107306-107316`, `Config:1941-1944`).
- Chaque vol acheté est enregistré dans `DynamicSupportNative.groups[groupName]` avec des callbacks et des messages (`airborneMessage`, `winchesterMessage`, `landedMessage`, `killedMessage`) (`zc:106367`, `zc:107276-107325`).
- Une seule boucle `timer.scheduleFunction` partagée (30 s, vivante seulement tant qu'au moins un enregistrement existe) lit `unit:getAmmo()` de chaque vol ; quand un vol qui avait des munitions de mission n'en a plus, elle déclenche `onWinchester` (route RTB vers l'aérodrome ami le plus proche) et prévient la coalition (`zc:106303-106365`, `zc:107283-107316`).
- Les `S_EVENT_TAKEOFF`, `S_EVENT_LAND` et `S_EVENT_UNIT_LOST` de ces groupes sont routés vers `DynamicSupportNative:HandleTakeoff/HandleLanding/HandleUnitLost`, qui libèrent l'emplacement « un seul vol actif » et envoient le message d'atterrissage/de perte (`zc:42965-42972`, `zc:42262-42266`, `zc:43070-43073`, `zc:106402-106425`, `zc:106454-106469`).
- Un article d'artillerie navale existe dans le moteur (`spawnNavyArtyAt`) et utilise Moose `AUFTRAG:NewARTY` et `FLIGHTGROUP` / `AUFTRAG:NewANTISHIP` (couche OPS) ; il n'est pas sur l'étagère du Caucase (`zc:109950-110075`).
- Le bombardier stratégique utilise son propre module (`StrategicBomber`, `zc:2350-4195` ; les détails internes relèvent des thèmes IA) ; la boutique appelle seulement `StrategicBomber.LaunchBlue/LaunchRed` et `BuildBlueShopMenu` (`Setup:3743-3757`, `Setup:3775`).

### Menu Dynamic Control (contrôle du support acheté)

- `F10 > Other > Dynamic Control` (`MENU_DYNAMIC_CONTROL`), par groupe, reconstruit par `refreshDynamicControlMenuForGroup` (`zc:16259`, `zc:16425`).
- La racine n'existe que tant que quelque chose est contrôlable : un vol acheté est actif, ou un ravitailleur est actif ; sinon le menu est retiré (`zc:16340-16350`).
- L'arbre n'est reconstruit que lorsqu'une chaîne « signature » par groupe change (camp propriétaire, activité du ravitailleur, hélicoptère ou non, rang, quels vols sont actifs, mode de push SEAD/leurre et état de préparation, ordre de rachat automatique des CAP) (`zc:16380-16421`).
- Disposition exacte (libellés issus de `L10N:1874-1931`, `L10N:693-695`) :

```
Dynamic Control                                             (zc:16425)
├─ Tankers Control                                          (zc:16795 ; exige le rang ravitailleur, pas pour les hélicoptères : zc:16363-16370)
│  ├─ Arco (Drogue): Move to Zone > <zone> > Orbit | Hot 360…315 > 10…50 NM Leg
│  ├─ Arco (Drogue): Altitude > <list> / Arco (Drogue): Speed > <kt list>
│  ├─ Texaco (Boom): Move to Zone / Altitude / Speed        (même forme)
│  └─ Tanker Help
├─ CAP Control                                              (zc:16461, tant qu'une CAP achetée est active)
│  ├─ Stop CAP auto-buy                                     (seulement pour l'acheteur d'un ordre de rachat automatique en attente ; zc:16462-16466)
│  ├─ CAP: Reposition by Zone > <zone, "More" paging> > Orbit | Hot 360…315 > 10…50 NM Leg   (zc:16469-16540)
│  ├─ CAP: Reposition by Position > Reposition 360…315 > 0…100 NM > Orbit | Hot 360…315 > NM Leg   (zc:16543-16580)
│  ├─ CAP Help                                              (affiche l'aide des marqueurs caphere1/caphere2 ; zc:16583)
│  ├─ CAP: Hold Racetrack                                   (ROE open fire = "Engage If Engaged" ; zc:16586-16602)
│  ├─ CAP: Flightsweep                                      (ROE weapon free = "Engage All" ; zc:16603-16619)
│  └─ CAP: Destroy                                          (zc:16620-16625)
├─ CAS: Destroy                                             (zc:16627-16633)
├─ Bomber: Destroy                                          (zc:16635-16641)
├─ SEAD: Push (seulement en mode "push on command", une fois prêt) / SEAD: Destroy   (zc:16643-16664)
├─ <strategic bomber name> > Push (until pushed) | Destroy  (zc:16656-16657, zc:4195-4223)
├─ DECOY: Push (même règle) / DECOY: Destroy                (zc:16667-16684)
├─ Building strike: Destroy                                 (zc:16687-16688)
└─ Navy Artillery: Destroy                                  (zc:16690-16691)
```

- "Reposition by Zone" liste les zones amies actives (et les neutres déjà capturées une fois), ordonnées par numéro de waypoint décroissant ; le handler appelle `setCapRacetrack(zoneCoord, heading, leg, zoneName)` et annonce `DYNAMIC_CAP_EN_ROUTE_TO_ZONE` / `DYNAMIC_CAP_REPOSITIONING_ZONE` (`zc:16433-16458`, `zc:16504-16535`).
- "Reposition by Position" translate la position **actuelle** de la CAP de la distance choisie sur le relèvement choisi (`capGroup:GetCoordinate():Translate(...)`) et y règle une orbite ou un racetrack (`zc:16544-16578`).
- "Hold Racetrack" et "Flightsweep" ne changent que les règles d'engagement du vol (`OptionROEOpenFire` / `OptionROEOpenFireWeaponFree`, c'est-à-dire DCS `AI.Option.Air.id.ROE`), avec un message de coalition (`zc:16586-16619`).
- Les entrées "Destroy" appellent `despawnCap`, `despawnCas`, `despawnBomber`, `despawnSead`, `despawnDecoy`, `despawnStructure`, `despawnNavyArty` : le groupe est détruit, l'emplacement « un seul vol actif » est libéré, rien n'est remboursé (`zc:107958-107990`, `zc:108275`, `zc:108729`, `zc:109358`, `zc:109707`, `zc:109939`).
- "Push" appelle `pushSead` / `pushDecoy`, qui exécutent une fois le `pushAction` stocké (le vol quitte son orbite d'attente et vole la route d'attaque) et reconstruisent le menu (`zc:108699-108727`, `zc:108246-108273`).
- Bombardier stratégique : `StrategicBomber.PushBlue(groupId)` démarre la route de bombardement (`StartBomberAuftrag`), en refusant avec `STRATEGIC_BOMBER_ALREADY_PUSHING` / `…_NOT_ACTIVE` ; `DestroyBlue` retire le bombardier et l'escorte (`STRATEGIC_BOMBER_DESTROYED`) (`zc:3936-3975`, `zc:4101-4121`).
- **La navigation du porte-avions n'est pas sous Dynamic Control** : c'est un sous-menu "Carrier Navigation" de `Stats and Settings`, bleu uniquement, conditionné par le rang `CarrierRankRequirement` (`refreshCarrierNavigationMenuForGroup` le rattache à `logistics.statsMenus[groupId]`, `zc:16178-16229`, `zc:16081-16096`).
- Le contrôle des ravitailleurs est conditionné par l'exigence de rang de l'article de boutique ravitailleur (`_getTankerRequiredRank`) (`zc:13326`, `zc:16363-16370`, `Config:290-292`).

### Vols achetés : ce qui apparaît, comment il reçoit ses tâches, comment il se termine

Cadre commun (tous les `dynamiccas`, `dynamicsead`, `dynamicdecoy`, `dynamicbomb`, `dynamicstatic` ; `spawnCapAt` est décrit au §6) :

- Les templates sont des groupes en late activation choisis par ère : `DynamicCas_Template[_CW|_VT]`, `DynamicSead_Template[_CW|_VT]`, `DynamicDecoy_Template[_CW]`, `DynamicBomber_Template[_CW|_VT]`, `DynamicStructure_Template[_CW|_VT]`, `CAP_Template[_CW|_VT]` (`zc:107935`, `zc:108673`, `zc:108217`, `zc:109335`, `zc:109698`, `zc:105244`).
- Départ au sol (`AIAttackTakeoffFromGround`) : `_spawnDynamicSupportFromGround` choisit un aérodrome ami proche de la zone d'origine avec assez de parking libre du type de terminal voulu (jusqu'à 8 tentatives, chacune excluant l'aérodrome précédent), prépare l'entrepôt pour la charge du template (`_prepareBlueAiWarehouseSpawn`), et fait apparaître avec `SPAWN:NewFromTemplate():SpawnAtParkingSpot(homebase, spots, SPAWN.Takeoff.Hot)`, avec repli sur `SpawnAtAirbase` (`zc:107074-107136`).
- Départ en vol (repli, ou quand le départ au sol est désactivé) : le groupe apparaît à 7 620 m au-dessus de la zone d'origine, repoussé de `offsetNM` loin de la cible, cap sur la cible (`zc:108005-108015`, `zc:108160-108167`).
- Une validation s'exécute 5 s (sol) ou 8 s (air) après l'apparition : si le groupe n'est pas vivant, un spawn au sol est retenté une fois en spawn aérien ; seul un spawn validé règle l'achat en attente (`_completePendingShopPurchase`) (`zc:107003-107072`).
- Chaque vol enregistre une entrée dans `DynamicSupportNative` avec ses messages et callbacks, et prend un « idle hold » sur la zone cible pour qu'une zone cible en dormance reste éveillée tant que le vol est vivant (`_beginPurchasedAttackHold`) (`zc:108062-108081`, `zc:37409-37432`).
- La route porte des tâches de waypoint scriptées (`WrappedAction` / `Script`) qui appellent `DynamicSupportNative:ReportMissionStarted(name)` au waypoint d'ingress ou d'attaque et `ReportMissionComplete(name)` à l'egress ; elles déclenchent `onMissionStarted` et le message « completed » (`zc:108123-108130`, `zc:106380-106400`).
- Fin de vie : atterrissage (message « … have landed », groupe retiré), dernière unité perdue (« … have been killed »), "Destroy" depuis le menu, ou zone cible/origine devenue invalide avant l'attribution des tâches ; dans tous les cas, le drapeau « un seul vol actif » est effacé et le menu Dynamic Control reconstruit (`zc:106402-106469`, `zc:107939-107956`).

| Vol | Options à l'apparition | Tâches | Fin / messages spécifiques | Code |
|---|---|---|---|---|
| CAS | carburant illimité, silence radio, ROE return fire, evade fire | 2 s après l'apparition `bc:EngageCasMission(target, group, WeaponExpend.ONE, nil, 27000 ft, homebase, …)` : une route `Mission` départ → ingress → waypoint d'attaque 14 NM avant la première cible (survol) → egress → atterrissage ; le waypoint d'attaque porte un `ComboTask` avec une tâche d'attaque par nom de groupe/static de `zone.built` (plus l'entrepôt de la zone), une tâche en route `EngageTargets` sur `Ground Units`, et la ROE réglée sur open fire | winchester (plus de munitions A/S au contrôle de 30 s) → RTB avec "CAS group is Winchester" ; `DYNAMIC_SUPPORT_CAS_SCRAMBLING` / `_LAUNCHED` à l'apparition | `zc:107991-108152`, `zc:36091-36276` |
| SEAD | silence radio, ROE return fire, evade fire ; altitude 28 000 ft par défaut | cibles = unités des groupes de la zone ayant l'attribut `SAM TR`, `SAM SR`, `SR SAM`, `MR SAM`, `LR SAM` ou `AAA` (toutes les autres unités s'il n'y en a pas) ; `EngageCasMission(target, group, WeaponExpend.ALL, AnyAG, altitude − 1000, …)` avec `targetNames` = ces unités, vitesse de route 600 kt, pas de tâche en route ; en mode « push on command » le vol commence par tourner en orbite (départ au sol : à 10 NM de la base vers la cible à 25 000 ft jusqu'à ce que chaque appareil soit à moins de 500 ft de cette altitude) et signale « ready to PUSH » avec une ETA | si la zone n'a aucune unité : vol détruit après 5 s et **500 crédits remboursés** (`DYNAMIC_SUPPORT_NO_SEAD_TARGETS_REFUND`) ; au début de la mission le vol passe en weapon free et le script **réveille les SAM cibles** (émission activée, état d'alarme rouge, état MANTIS forcé à RED, capacité de défense anti-ARM forcée à 99 pendant 300 s) pour qu'ils rayonnent pour les missiles antiradiations | `zc:108779-108900`, `zc:108934-109024`, `zc:109105-109146`, `zc:109162-109270` |
| Decoy (TALD) | silence radio, option de formation 131074 ; altitude 30 000 ft par défaut | `bc:EngageDecoyMission` : route vers un waypoint `attackOffsetNM` (par défaut 20 NM) avant le centre de la zone, portant une tâche `Bombing` sur le centre de la zone avec `weaponType = 8589934592` (leurres), `expend = ALL`, attaque de groupe ; même push automatique / sur commande et même orbite d'attente que le SEAD, avec des messages d'ETA | winchester = "All ducks away. Returning to base." ; bleu uniquement (PvP : côté 2 seulement) | `zc:108316-108540`, `zc:36002-36076` |
| Bomber | silence radio, ROE return fire, réaction à la menace evade fire | 2 s après l'apparition `StartBomberAuftrag(nil, group, targetZone, nil, 750 kt, {routeAltitudeFt = 25000, attackAltitudeFt = 25000, staticsLast = true, staticWeaponExpend = ONE…})` : malgré son nom, il construit un `ComboTask` brut de tâches `Bombing` (`weaponType = AnyBomb`, `groupAttack = false`), une par **position d'unité** de chaque groupe de `zone.built`, puis une par static et l'entrepôt de la zone (statics en dernier) | ROE open fire au début de la mission ; winchester → RTB "Bomber Group, returning to base" | `zc:109391-109620`, `zc:1500-1581`, `zc:1776-1853` |
| Structure strike | silence radio, ROE return fire, evade fire | cibles = statics vivantes de `zone.built` plus l'entrepôt de la zone ; le script compte les bombes emportées (`unit:getAmmo()`, catégorie BOMB) et règle l'expend par cible : ALL pour une cible, HALF pour deux, QUARTER pour quatre, sinon FOUR / TWO / ONE selon les bombes par appareil et par cible ; puis `EngageCasMission(target, group, ONE, AnyBomb, 25000 ft, …)` avec ces profils par cible | PvE bleu uniquement (un seul état global, pas d'enregistrement par camp) ; winchester → RTB "Infrastructure Group is now RTB" | `zc:109719-109892` |

- Le « winchester » de tous ces vols est la scrutation de munitions partagée de 30 s de `DynamicSupportNative` ; la route RTB compte deux waypoints (point courant, puis `WaypointAirLanding` à la base d'attache ou à l'aérodrome ami le plus proche) à 300 kt, réglée avec `Controller:setTask({id = "Mission", …})` ou `GROUP:Route` (`zc:109081-109096`, `zc:109054-109065`, `zc:109833-109846`).
- Moose utilisé : `SPAWN`, setters d'options de `GROUP` (`OptionROE*`, `SetOption`, `SetOptionRadioSilence`, `CommandSetUnlimitedFuel`, `EnRouteTaskEngageTargets`), `COORDINATE:WaypointAir*`, requêtes de parking `AIRBASE` ; les tâches elles-mêmes sont des tables de tâches DCS brutes, pas des `AUFTRAG` (`zc:108045-108046`, `zc:36157`, `zc:36118`).

## 6. Rachat automatique des CAP après perte (6.5.2)

### Ce que voient le joueur / l'admin

- `AllowCapAutoBuyAfterLoss` (par défaut `false`, PvE uniquement) et `MaxCapAutoBuys` (1–5, par défaut 1) (`Config:1577-1584`).
- Quand c'est activé, chaque choix du menu d'achat de CAP devient un sous-menu avec "Yes, Buy again if Dead" et "No" (`zc:22307-22341`).
- Si le vol CAP acheté est entièrement détruit, le moteur rachète une CAP sur la même zone de lancement, avec le même cap et la même branche, en débitant à nouveau la coalition, jusqu'au nombre de remplacements autorisé ; quand il ne peut pas, la coalition reçoit `SHOP_CAP_AUTO_BUY_STOPPED` (`zc:106439-106466`).
- L'acheteur peut annuler depuis Dynamic Control ("CAP auto-buy cancelled. The current flight will continue.") (`zc:106427-106437`).

### Mécanisme

- Un « ordre » `{buyer, remaining, launchZone, heading, leg, point, committed}` accompagne l'achat ; `buyShopItem` construit un achat en attente et appelle directement `spawnCapAt(..., purchase, nil, target, order, isReplacement)` (`zc:22019-22029`).
- Le paiement n'est réglé qu'une fois que le vol a sa route (`settlePurchasedCap`) ; si la coalition ne peut plus se le permettre à ce moment-là, le vol est détruit (`zc:107229-107246`).
- Préconditions revérifiées à chaque remplacement : aucune CAP active, l'acheteur est toujours le même joueur dans le même groupe bleu (`_isCapAutoBuyBuyer`), la zone de station est toujours éligible, le rang de l'acheteur est toujours suffisant (`zc:21863-21876`, `zc:21753-21768`).
- Déclencheur : `DynamicSupportNative:HandleUnitLost` sur `S_EVENT_UNIT_LOST` quand aucune autre unité du groupe n'est vivante (`zc:106454-106466`).

## 7. Rangs

### Ce que voit le joueur

- 20 rangs, numérotés de 1 à 20 ; les seuils sont des crédits de rang personnels : 0, 3000, 5000, 8000, 12000, 16000, 22000, 30000, 45000, 65000, 90000, 120000, 155000, 195000, 240000, 290000, 345000, 405000, 470000, 540000 (`zc:17231`).
- Noms dans le même ordre : Recruit, Aviator, Airman, Senior Airman, Staff Sergeant, Technical Sergeant, Master Sergeant, Senior Master Sergeant, Chief Master Sergeant, Second Lieutenant, First Lieutenant, Captain, Major, Lieutenant Colonel, Colonel, Brigadier General, Major General, Lieutenant General, General, General of the Air Force (`zc:17232`).
- `F10 > Stats and Settings > Stats > Rank Help` affiche l'échelle sous forme de table pointillée (`zc:40883-40908`, `zc:101209`).
- Promotion : message de coalition `PLAYER_PROMOTED` et son `Rank.ogg` au moment de l'encaissement ; rétrogradation : `PLAYER_DEMOTED` (`zc:41897-41902`, `zc:42240-42242`).
- Un rang débloque : des articles de boutique (`ShopRankRequirements`, masqués sous le rang), des articles CTLD (`CTLDPrices[...].reqRank`, vérifié dans `bc:debit`), le contrôle des ravitailleurs, la navigation du porte-avions (`CarrierRankRequirement = 5`) (`zc:22428-22439`, `zc:21478-21487`, `zc:13326`, `zc:13692`, `Config:292`).

### Ce que règle le créateur de mission

- `RankingSystem` (par défaut `true`) : quand il vaut `false`, `reqRank` n'est jamais stocké sur les articles d'étagère et tout le monde voit la boutique complète (`Config:284-285`, `zc:19353-19357`).
- `RankLoseWhenKilled` (`true`) / `RankLoseWhenKilledAmount` (100), `FriendlyFireRankPenalty` (500) (`Config:266-270`, `Config:287-288`).
- `bc.rankThresholds` / `bc.rankNames` peuvent être fournis à `BattleCommander:new` (ils prennent une valeur par défaut seulement en leur absence) (`zc:17231-17232`).
- Marqueur admin `addrank:<player>,<n>` (insensible à la casse, `n` peut être négatif) : `bc:addPlayerRankCredits(player, n)` sur l'enregistrement trouvé par le **nom** du joueur, menu de boutique du groupe du joueur reconstruit, `PLAYER_PROMOTED` + `Rank.ogg` à sa coalition si le rang a monté, `ADMIN_RANK_SET` à la coalition du marqueur, marque retirée ; comme les autres commandes de marqueur, il n'a aucun contrôle d'identité (`zc:29097-29124`, `zc:44400-44408`).

### Mécanisme

- Les crédits de rang forment un compteur distinct du compte de la coalition : `record.credits` dans l'enregistrement `RankSave` du joueur, augmenté exactement du montant encaissé à l'atterrissage (`addPlayerRankCredits`), diminué par les pénalités de mort / de tir ami, borné à 0 par le bas (`zc:44400-44408`, `zc:41895`, `zc:42237`, `zc:42668`).
- `getPlayerRank` parcourt le tableau des seuils et renvoie l'indice le plus élevé dont le seuil est atteint (0 quand le joueur n'a pas d'enregistrement) (`zc:44384-44393`).
- Persistance : table globale `RankSave = {players = {[ucid] = record}, legacyPlayers = {[name] = record}, playerAliases, version, …}` écrite dans `<writedir>/Missions/Saves/Foothold_Ranks.lua` par `Utils.saveTable`, dans le cadre du job de sauvegarde par étapes, seulement quand `RankingSystem` vaut true (`zc:44332-44377`, `zc:44508`, `zc:44533`).
- Identité : les enregistrements sont indexés par UCID, avec un cache d'alias nom→UCID et une table « legacy » indexée par nom pour les joueurs jamais vus avec un UCID (`zc:43358-43378`, `zc:43446-43466`).
- Résolution de l'UCID (`_syncRankSavePlayerIdentity(player, plist, force, pid)`) : l'id du joueur est trouvé en faisant correspondre `net.get_name(pid) == playerName` sur `net.get_player_list()` (ou via le cache de pid multicrew), puis `ucid = net.get_player_info(pid, 'ucid')` ; le résultat est mis en cache dans `_rankIdentityByPlayer[name] = {pid, ucid}` et `_rankNameByUcid[ucid] = name` (`zc:43685-43707`, `zc:43726`, `zc:43738`).
- Une synchronisation forcée (apparition du joueur) estampille aussi `lastSeen` sur l'enregistrement ; un joueur qui revient sous un nouveau nom garde son enregistrement, l'ancien nom étant stocké dans `rankSave.playerAliases[oldName] = ucid` (`zc:43710-43713`, `zc:43727-43737`).
- La première observation d'un UCID « réclame » les données legacy stockées sous le nom du joueur : enregistrement de rang, statistiques sur la vie entière, réglages EWRS et auto-JTAC passent des tables indexées par nom à celles indexées par UCID ; un nom déjà détenu par un autre UCID n'est pas réclamé (`_claimLegacyPlayerIdentity`, `zc:43467-43501`, `zc:43719-43742`).
- Tout cela exige l'API `net.*` depuis l'environnement de scripting de mission ; quand aucun pid ou aucun UCID n'est renvoyé, la fonction renvoie nil et l'enregistrement legacy indexé par nom est utilisé (`zc:43704-43707`, `zc:43446-43466`).
- Le même fichier stocke aussi les réglages EWRS et auto-JTAC de chaque joueur (`_syncRankEwrsSettings`, `_syncRankSelfJtacSettings`, `zc:44360-44361`).
- Le fichier de rangs est indépendant de la sauvegarde de campagne, donc les rangs survivent à une réinitialisation de campagne : quand une réinitialisation est en attente (`bc._persistenceResetPending`, posé quand la campagne est gagnée et redémarre automatiquement avec `AutoRestart`, ou quand un joueur confirme le menu de coalition "Restart and reset" ; la sauvegarde des zones est écrasée par une table vide au même moment), le job de sauvegarde par étapes s'exécute en mode `rankOnly` et n'écrit que `Foothold_Ranks.lua`, pas l'état des zones (`zc:44334-44340`, `zc:44429-44447`, `zc:28112-28134`).

## 8. Statistiques et classements

### Ce que voit le joueur

- `F10 > Stats and Settings > Stats >` "My Stats", "Top 10 Players", "Top 5 Players", "Top 5 Today", "Rank Help", et un sous-menu "Career" (`zc:101203-101215`, `L10N:1018-1024`).
- "My Stats" : position au classement (par `Points`), rang actuel, rang suivant et crédits restants, puis Air, Helo, Ground Units, Ship, SAM, Structure, Deaths, Captured by enemy, Zone capture, Zone upgrade, Pilot Rescue, Enemy Pilot Capture, Refueling (avec lb), Points, Points spent, Flight time (min) (`zc:40638-40742`).
- "Top N" : joueurs triés par `Points` sur la vie entière, avec le nom de leur rang (`zc:40912-40955`).
- "Top 5 Today" : trié par `sessionStats[name].Points` (depuis le début de la mission) (`zc:21395-21410`).
- Les mêmes sorties sont accessibles avec les marques de carte `stats`, `top`, `mystats` (`zc:29215-29240`).
- À l'encaissement, le message de coalition liste les statistiques de la sortie par joueur (`+N Air`, `+N Ground Units`, `Flight time (N MIN)` …) (`zc:40605-40636`, `zc:41889`).

### Mécanisme

- Trois couches : `tempStats[name]` (sortie en cours, perdue à la mort, validée à l'encaissement), `sessionStats[name]` (depuis le début de la mission, jamais sauvegardée), `playerStats` (persistante, par UCID dans `playerStatsByUcid` ou par nom dans `legacyPlayerStats`) (`zc:40510-40549`, `zc:40958-40970`, `zc:43446-43466`).
- Les clés de statistique sont des chaînes libres ; les connues ont des clés de localisation (`FootholdStatLabelKeys`), celles propres à une mission sont créées à la volée (`'CAP mission'`, `'Recon mission'`, `'Escort Mission'`, `'Strategic bomber escort'`, `'<title> (Joint mission)'`, `'Achievement'`) (`zc:40577-40603`, `zc:41346-41353`, `Setup:8253-8254`, `Setup:8667`, `zc:3148`).
- `Points` est la somme sur la vie entière des crédits encaissés (moins les pénalités) ; `Points spent` est la somme des dépenses en boutique et en CTLD (`zc:41890`, `zc:21501`, `zc:22088`).

## 9. Carrière et hauts faits

### Ce que voit le joueur

- `F10 > Stats and Settings > Stats > Career >` "Overview", "Flight progress", "Combat progress", "Logistics progress", "Aircraft" (`zc:101210-101215`).
- Overview : temps de vol (total / voilure fixe / hélicoptère), sorties (décollages, atterrissages, décollages/atterrissages sur porte-avions, appontages), kills par classe, séries de kills aériens, kills amis / éjections / morts, carburant reçu, supply livré, constructions CTLD, largages de troupes, sauvetages de pilotes, pilotes ennemis capturés, dépenses sur la vie entière et nombre d'achats (`zc:40799-40823`).
- Pages de progression : une ligne par métrique avec la valeur actuelle, le titre actuel, débloqués/total et le titre suivant avec son seuil (`zc:40771-40797`, `zc:40825-40847`).
- Page Aircraft : par type d'appareil piloté, temps de vol, kills, atterrissages, atterrissages sur porte-avions, supplies, constructions, hauts faits (`zc:40849-40881`).
- Franchir un seuil de haut fait verse des crédits dans la bourse et ajoute une statistique `Achievement` ; l'annonce est regroupée et publiée 10 s plus tard (`zc:44035-44060`).

### Mécanisme

- Les compteurs de carrière sont des ids entiers (`CAREER_STAT`, `CAREER_AIRCRAFT_METRIC`) stockés dans l'enregistrement de rang : `record.career[statId]` et `record.aircraft[aircraftId][metricId]` (`zc:12040-12078`, `zc:44085-44095`, `zc:40853-40857`).
- Chaque métrique a une échelle d'au plus 9 niveaux ; la récompense du niveau n est `{100, 250, 500, 1000, 2000, 3500, 5000, 7500, 10000}[n]` ; les kills amis, les éjections et les morts de pilote ont des échelles mais pas de récompense (`zc:12080-12101`, `zc:44062-44083`).
- Les compteurs sont alimentés par les handlers de récompense : kills (`recordCareerKillForCrew`), atterrissages et appontages à l'encaissement, éjections, morts, carburant, livraisons de supply et de CTLD, sauvetages, achats (`zc:42718`, `zc:41849-41864`, `zc:42144`, `zc:42175`, `WelcomeMessage.lua:2803-2808`, `zc:21504`).
- Recherche de l'échelle : `_careerAchievementLadder(scope, subjectId, metricId)` renvoie `CAREER_GLOBAL_ACHIEVEMENTS[metricId]` pour la portée joueur, et pour la portée appareil la surcharge par appareil `CAREER_AIRCRAFT_ACHIEVEMENT_OVERRIDES[aircraftId][metricId]`, sinon `CAREER_AIRCRAFT_ACHIEVEMENTS[metricId]` (une table vide, donc seules les surcharges existent) (`zc:43906-43911`, `zc:12468-12469`).
- Une échelle est une liste de `{threshold, title}` ; l'indice de niveau donne la récompense (voir plus haut), donc une échelle de 6 niveaux paie 100, 250, 500, 1000, 2000, 3500 (`zc:12167-12175`, `zc:12080-12090`).

Échelles globales (par joueur), seuils seulement (`zc:12167-12466`) ; chaque niveau a un titre humoristique (par exemple temps de vol : "Getting Settled" … "Please Go Outside" ; série de kills aériens : "Ace", "Air Master", "Own the Sky", "Untouchable") :

| Métrique (`CAREER_STAT`) | Seuils |
|---|---|
| `FlightSeconds` | 20, 75, 200, 400, 750, 1000 heures |
| `Takeoffs`, `Landings` | 10, 50, 100, 250, 500, 750 |
| `CarrierTakeoffs` | 10, 50, 100, 250, 500, 1000 |
| `ConventionalCarrierTraps` | 5, 25, 100, 250 |
| `Ejections` (sans récompense) | 1, 10, 25, 50, 100, 250, 500 |
| `PilotDeaths` (sans récompense) | 5, 10, 25, 50, 100, 250, 500 |
| `FixedWingAirStreakBest` | 5, 10, 15, 20 |
| `HelicopterAirStreakBest` | 1, 3, 5 |
| `FuelReceivedLbs` | 10 000, 50 000, 100 000, 250 000, 500 000, 1 000 000, 5 000 000 |
| `TotalKills` | 10, 50, 100, 250, 500, 1000, 2500, 5000, 10 000 |
| `AirKills`, `HeloKills` | 5, 25, 50, 100, 250, 500, 1000 |
| `FixedWingGroundKills` | 50, 100, 250, 500, 1000, 2500, 5000, 10 000 |
| `HelicopterGroundKills` | 100, 250, 500, 1000, 2500, 5000 |
| `SamKills` | 5, 20, 50, 100, 250, 500, 1000 |
| `ShipKills` | 1, 10, 25, 50, 100, 200 |
| `StructureKills` | 1, 10, 50, 100, 250 |
| `DemolitionKills` | 1, 10, 25, 50, 100, 250 |
| `InfantryKills` | 25, 100, 250, 500, 1000, 2500, 5000 |
| `FriendlyKills` (sans récompense) | 1, 10, 50 |
| `SupplyUnitsDelivered` | 10, 50, 100, 250, 500, 1000, 2500, 5000, 10 000 |
| `ZoneSupplyUnits` | 10, 50, 100, 250, 500, 1000, 2500, 5000 |
| `FarpSupplyUnits`, `WarehouseDeliveries` | 5, 25, 50, 100, 250, 500, 1000 |
| `CtldBuilds` | 5, 25, 50, 100, 250, 500 |
| `CtldUpgrades` | 1, 10, 25, 50, 100, 250, 500 |
| `FarpsBuilt`, `TroopZoneUpgrades`, `PilotRescues`, `EnemyPilotCaptures` | 1, 10, 25, 50, 100, 250 |
| `AirDefenseBuilt`, `TroopCaptures` | 1, 10, 25, 50, 100 |
| `TroopDrops` | 10, 50, 100, 250, 500, 1000, 2500 |
| `LifetimeSpent` | 5000, 10 000, 50 000, 100 000, 250 000, 500 000, 1 000 000, 5 000 000 crédits |
| `Purchases` | 10, 50, 100, 250, 500, 1000, 2500 |

- Échelles par appareil : `CAREER_AIRCRAFT` associe 42 ids d'appareils de carrière à leurs noms de type DCS (par exemple l'id 1 "F/A-18 Hornet" = `FA-18C_hornet`, `FA-18E`… ; ids d'hélicoptères 101–110 ; warbirds 201–211) avec des drapeaux `naval` / `rotary` (`zc:12112-12166`).
- Chaque appareil a une échelle de temps de vol à 5, 25, 50, 100, 250, 500 heures avec des titres propres à l'appareil ; quelques-uns ont des échelles supplémentaires sur `TarawaLandings` (5, 10, 20, 35, 50), `CarrierLandings`, `TotalKills`, `SupplyUnitsDelivered`, `AirdroppedSupplyUnits`, `AirdroppedBuilds`, `AirdroppedAirDefenseBuilds`, `CtldBuilds`, `TroopDrops`, `PilotRescues`, `EnemyPilotCaptures`, `FuelReceivedLbs` (`zc:12469-12926`).
- L'annonce publique est `CAREER_ACHIEVEMENT_PUBLIC_HEADER` + une `…_PUBLIC_LINE` par titre avec son contexte ("<aircraft>: <label> <value>") (`zc:43942-43951`, `zc:44004-44007`).

## 10. Missions conjointes (groupes de partage des récompenses)

- `F10 > Missions > Joint missions >` "Request joint with player", "Pending joint requests", "Leave Joint mission", "Joint mission status", "Help" (clés de libellé `JOINT_MENU_*`, `L10N:1592-1606` ; création du menu en `zc:18653-18675`).
- Un groupe compte au plus 4 joueurs (`JOINT_MAX_MEMBERS`, `zc:18059`).
- Quand un membre accomplit une cible de mission, chaque membre vivant du groupe qui est inscrit reçoit aussi la récompense complète, et la statistique est enregistrée comme `<stat> (Joint mission)` (`zc:41330-41360`, `zc:41283-41314`).
- Pour les cibles de groupe avec plusieurs tueurs, la récompense est partagée entre les tueurs, puis complétée jusqu'à la récompense complète pour les tueurs qui sont dans un groupe, et les membres du groupe qui n'ont pas tué reçoivent la récompense complète (`zc:41383-41413`).
- Un membre qui meurt, s'éjecte ou réapparaît quitte le groupe (`JOINT_YOU_HAVE_LEFT`, `JOINT_PLAYER_DIED_LEFT`, `JOINT_LEFT_DUE_RESPAWN`) (`zc:41790-41801`, `zc:42187-42197`, `zc:41699-41710`).
- Demande : "Request joint with player" liste les autres joueurs du même camp — joueurs solo par leur nom, groupes existants sous la forme "Join <host>'s Party (n/4)" — paginés par 9 ; en choisir un appelle `_jointRequestPlayer(groupId, target, side)` (`zc:18681-18812`, `L10N:1597`).
- Refus : se demander soi-même (`JOINT_CANT_JOIN_OWN`), son propre groupe plein (`JOINT_REQUEST_REQUESTER_BUSY`), cible disparue (`JOINT_REQUEST_NOT_AVAILABLE`), les deux déjà dans un groupe (`JOINT_ALREADY_SHARING` si c'est le même, sinon `JOINT_REQUEST_TARGET_BUSY`), groupe de la cible plein, ou une demande à ce joueur encore en attente (`JOINT_REQUEST_ALREADY_SENT` avec les secondes restantes) (`zc:19013-19054`).
- Une demande est `jointRequests[side][target][requester] = {requesterGroupId, targetGroupId, side, expiresAt = now + 120}` ; un `timer.scheduleFunction` à `expiresAt` la supprime et prévient les deux joueurs avec `JOINT_REQUEST_EXPIRED` ; le demandeur reçoit `JOINT_REQUEST_SENT`, la cible `JOINT_REQUEST_RECEIVED` pendant 30 s (`zc:19047-19092`).
- Accepter / refuser : "Pending joint requests" montre un sous-menu "Request from <player>" avec "Accept" et "Decline" ; `_jointAcceptRequest` revalide tout (non expirée, les deux groupes toujours détenus par les mêmes joueurs, tailles), puis soit ajoute le demandeur au groupe de la cible, soit ajoute la cible au groupe du demandeur, soit crée un nouveau groupe de deux (`_jointCreateParty`) ; `_jointDenyRequest` supprime la demande et prévient le demandeur avec `JOINT_REQUEST_DENIED_BY` (`zc:18813-18904`, `zc:19096-19252`).
- Les groupes sont des tables avec un hôte et une liste de membres, indexées par `jointPartiesByPlayer[player]` ; "Leave Joint mission" appelle `_jointLeave` (`zc:18142-18246`, `zc:18460-18486`).
- Réintégration automatique : quand un membre devient indisponible (mort, réapparition, changement de slot), le groupe et ses membres vivants sont mémorisés pendant `jointRejoinGraceSeconds` (par défaut 300 s) ; s'il réapparaît du même côté dans ce délai, que le groupe existe toujours avec une place libre et qu'au moins un membre d'origine y est vivant, il y est remis sans nouvelle demande (`_jointRememberRejoin`, `_jointTryAutoRejoin`, `zc:18342-18400`).
- Les menus sont rafraîchis par un worker en file (`_runJointMenuRefreshTick`) pour qu'un changement dans la liste des joueurs ne reconstruise pas d'un coup le menu de chaque groupe (`zc:18911-18983`).
- L'aide en jeu énonce la portée : "Eligible party members receive mission credits. Regular kills are not shared. Valid for CAS, CAP, Bomb runway, and Strike missions. Only active, surviving party members receive Joint mission rewards." (`L10N:1619`).
- Un ancien flux « code d'invitation » (code à 4 chiffres, libellés `JOINT_MENU_INVITE`, `JOINT_CODE`, `JOINT_HELP`) a encore ses chaînes dans le fichier de localisation, mais le menu construit en v6.5.3 ne propose que le flux de demande (`L10N:1585-1595`, `L10N:1620`, `zc:18659-18675`).

## 11. Missions joueur (`MissionCommander`)

### Modèle de données

- Une instance : `mc = MissionCommander:new({side = 2, battleCommander = bc, checkFrequency = 60})` ; le constructeur force `checkFrequency` à 15 s quelle que soit la valeur passée (`Setup:6075`, `zc:102558-102560`).
- `mc:trackMission(def)` ajoute une définition à `mc.missions` ; champs : `title`, `description` (chaîne ou `function(T)`), `messageStart`, `messageEnd`, `isActive()` (condition), `startAction()`, `endAction()`, `canExecute()` facultatif, `missionFail()`, `startOver()`, `reward` (payé directement sur le compte de la coalition), `side`, `missionType`, `idleAttackEvent`, et pour les escortes `isEscortMission`, `missionGroup`, `zoneName`, `titleBefore`, `returnAccepted` (`zc:103747-103761`, `zc:103763-103936`).
- Une mission n'a pas de déclencheur explicite : `checkMissions` scrute chaque mission à chaque cycle (`timer.scheduleFunction`, premier passage à +15 s, puis tous les `checkFrequency`) et en déduit une machine à deux états à partir de `isActive()` (`zc:103960`, `zc:103763-103936`).
  - pas en cours et `isActive()` vrai (et `canExecute()` s'il existe) → affiche `messageStart` à la coalition (30 s), appelle `startAction`, pose `isRunning` (`zc:103866-103912`).
  - en cours et `isActive()` faux → affiche `messageEnd`, ajoute `reward` au compte de la coalition avec `bc:addFunds`, appelle `endAction`, efface `isRunning` (`zc:103832-103860`).
  - en cours, toujours active et `missionFail()` vrai → la mission est retirée de la liste et `startOver()` est appelé (`zc:103815-103830`).
- Après un début ou une fin, la boucle revient plus tôt et se relance 6 s / 2 s plus tard, si bien qu'au plus une transition est annoncée par passage (`zc:103858`, `zc:103909`).
- Le côté « qui l'a déclenchée » est externe : quelque chose d'autre pose la variable ou le `ActiveMission[flag]` que lit `isActive()` (un emplacement d'objectif du Director, un événement d'`EventCommander`, un générateur du fichier de setup).
- `EventCommander` (`evc`) : `evc = EventCommander:new({decissionFrequency = 15*60, decissionVariance = 10*60, skipChance = 15, strikeFrequency = 5*60})` ; toutes les ~15 à 25 min il choisit un événement aléatoire exécutable hors frappe (85 % de chance), et toutes les 5 min un événement de frappe aléatoire exécutable (`Setup:6073`, `zc:96294-96361`).

### Registre des cibles et détection de l'accomplissement

- `RegisterUnitTarget(unitName, reward, stat, flag, custom)`, `RegisterGroupTarget(groupName, reward, stat, flag, custom)`, `RegisterStaticGroup(key, source, reward, stat, flag, custom)`, `RegisterScoreTarget(flag, sceneryObj, reward, stat, custom)` remplissent les tables globales `MissionTargets[unitName]`, `MissionGroups[groupName] = {reward, stat, alive, remaining, killers, flag}`, `ScoreTargets[flag]` et posent `ActiveMission[flag] = true` (`zc:8866-8878`, `zc:9000-9072`).
- Le kill d'une unité enregistrée par un joueur inscrit (`S_EVENT_KILL`) la retire de `alive`, enregistre le tueur, et quand `remaining == 0` paie : la récompense du groupe est partagée à parts égales entre les tueurs encore inscrits, message `MISSION_REWARD_COMPLETED_SOLO/GROUP/JOINT`, son `cancel.ogg`, la marque de mission est retirée, `ActiveMission[flag]` est effacé et, pour les cibles « custom » (à usage unique), `CustomFlags[flag] = true` est posé pour qu'elle ne revienne jamais (`zc:41467-41502`, `zc:41362-41465`).
- Les cibles de frappe sur décor/static sont détectées par `S_EVENT_SCORE` + un contrôle de vie différé de 6 s (vie relative ≤ 50 % = détruit) (`zc:42083-42131`).
- Si un groupe enregistré meurt sans kill de joueur (IA, despawn), `isActive()` de la mission constate que le groupe a disparu et la mission se termine sans récompense ; `endAction` appelle `bc:cancelGroupTargetMission(flag, side)` (`Setup:6205-6216`).
- Un tueur qui meurt, s'éjecte ou réapparaît est retiré de chaque `MissionGroups[*].killers` (`zc:41677`, `zc:41766`, `zc:42184`).
- Marque de carte : 30 s après l'enregistrement, si le groupe est immobile (vitesse < 1 m/s), une marque de coalition portant le libellé de la mission est posée sur sa première unité (`trigger.action.markToCoalition`, id issu du compteur global `missionMarkId`, stocké dans `MissionMarks[groupName]`) (`zc:9028-9056`).

### Types de missions dans le setup Caucase

| Mission | Source d'activation | Accomplissement | Récompense | Code |
|---|---|---|---|---|
| Attack zone (3 emplacements) | emplacements d'objectif du Director / `attackTarget1..3` posés par le générateur du moteur | la zone cible n'est plus rouge (capturée ou neutralisée) | aucune : tag de zone "Attack" sur le libellé de carte et récompenses de kill seulement | `Setup:6888-7228`, `zc:64183` |
| Resupply zone (2 emplacements) | `resupplyTarget1..2` choisis au hasard parmi les zones amies qui ont besoin de supply | la zone n'a plus besoin de supply | récompenses `Zone upgrade` par livraison (§3.5) | `Setup:6575-6884`, `zc:63750`, `zc:63876` |
| Capture zone | `captureTarget` | la zone n'est plus neutre ou une capture est temporisée | récompense `Zone capture` par livraison | `Setup:7232-7458`, `zc:64370` |
| SEAD (emplacements) | emplacements SEAD du Director (`RegisterDirectorSeadMission`) | toutes les cibles SAM de l'emplacement détruites ou zone perdue | pool = kills × 50, partagé au prorata entre les participants éligibles | `Setup:7461-7632`, `zc:63506-63560`, `zc:62634` |
| DEAD (3 emplacements) | `generateDEADMission()` toutes les 120 s (300 s quand un emplacement est rempli) : une zone rouge dont le nom contient `sam` ou `defence`, sans SAM à radar restant, à moins de 24 km d'une cible d'attaque | la zone n'est plus rouge, est suspendue, ou a de nouveau des cibles SEAD | aucune (seulement les récompenses de kill) ; tag de zone "DEAD" | `Setup:7637-7640`, `zc:103458-103633`, `zc:64375-64560` |
| Recon (3 emplacements) | emplacements recon du Director ; annulée quand la zone obtient de l'intel | un avion joueur entre dans la trigger zone cible puis en ressort vivant (scrutation round-robin de 5 s) | 100 au vainqueur, partagé en conjoint, statistique `Recon mission`, puis 10 min d'intel sur la zone et un cooldown de 900 s sur cette zone | `Setup:7646-7946`, `Setup:7911-7919`, `zc:65120-65223` |
| CAP | générateur du moteur : au moins un groupe aérien rouge en vol, des joueurs en ligne, pas de cooldown ; cible = 2 à 8 kills selon le palier de nombre de joueurs | premier joueur à atteindre le nombre de kills | `kills × 100` au vainqueur (partagé en conjoint), puis cooldown de 900 s | `Setup:8322-8368`, `zc:65567-65606`, `zc:42780-42787` |
| CAS (emplacements) | emplacements CAS du Director (`RegisterDirectorCasMission`) | cibles de l'emplacement détruites | pool = kills × 30, partagé au prorata | `Setup:8378-8545`, `zc:63362-63412`, `zc:62632` |
| Runway strike (3 emplacements) | `generateRunwayStrikeMission(slot)` : une zone d'aérodrome rouge avec une piste bombardable, choisie par le Director bleu | un impact de bombe de joueur à l'intérieur de chaque zone de piste de l'aérodrome | 100 (une piste) ou 200 (plusieurs), partagé en conjoint, statistique `Bomb runway` ; les spawns d'avions de l'aérodrome sont bloqués 3300 s ; cooldown de 3000 s sur la zone | `Setup:8739-8996`, `zc:62079-62284`, `zc:62287-62520` |
| Destroy artillery | suivi automatique : chaque `GroupCommander` rouge avec `mission == 'attack'`, `type == 'surface'`, `MissionType == 'ARTY'`, plus ceux écrits à la main | groupe enregistré détruit | `gc.Reward` ou 250 | `zc:102746-102760`, `Setup:7952-8117` |
| Destroy EWR (strike) | automatique : chaque EWR rouge à moins de 70 NM d'une zone amie est mis en file avec un délai aléatoire de 60 à 300 s, puis démarré par l'événement de frappe | groupe EWR détruit | 300 | `zc:102460-102465`, `zc:102804-102908` |
| Destroy SCUDs | un événement `evc` refait apparaître `Maykop-Scuds` et l'enregistre ; cooldown de 2700 s | groupe détruit | 100 | `Setup:6120-6216` |
| Intercept cargo plane | événement `evc` | avion abattu | 500 | `Setup:6254-6290` |
| Destroy cargo / battle ships | événement `evc` | navire détruit | 500 | `Setup:6323-6370` |
| Intercept bombers | événement `evc` (raid de bombardiers rouge, `StrategicBomber` état 1) | bombardiers détruits ou raid terminé | 500 (cible de groupe, drapeau `bomb`) | `Setup:6374-6420`, `zc:4160`, `Setup:3657` |
| Intercept enemy airstrike | événement `evc`, groupe `evt-attack` | groupe détruit | 250 | `Setup:6478-6555` |
| High-value strike targets (scenery, generals, warehouses) | événements de frappe, chacun conditionné par les zones que tient le bleu | décor ≤ 50 % de vie, ou groupe détruit | 1000 / 500 | `Setup:9040-9700` |
| Red mass attack defence | `bc:triggerRedMassAttack()` (article de boutique rouge `redmassattack`) pose `ActiveMission["RedMassAttack"]` | plus aucun groupe rouge participant n'est vivant | aucune (seulement les récompenses de kill) | `zc:103062-103090`, `zc:34445-34832`, `zc:35003-35025` |
| Industry strike (PvP) | construit dans `MissionCommander:new` à partir des statics d'industrie des zones à moins de 100 NM | statics détruites | `min(1000, 300 × objects)` | `zc:102566-102742` |
| Ground convoy escort | le joueur se pose/apparaît dans une zone qui a une mission d'escorte | le convoi atteint et capture la zone cible | 1000 partagés entre les joueurs escorteurs (ou à la coalition s'il n'y en a pas) | `Setup:2067-2100`, `Setup:8591-8700` |
| Strategic bomber escort | l'acheteur a choisi "Player escort" dans la boutique | le raid de bombardiers se termine avec des escorteurs qualifiés | 1000 partagés entre les joueurs qualifiés | `zc:3125-3158`, `Setup:3715` |

- En PvE, les définitions de mission se referment sur des globales du fichier de setup (`attackTarget1`, `capMissionTarget`…) ; en PvP les mêmes rôles sont pilotés par des « emplacements d'objectif » par camp (`bc.objectivesBySide[side].<role>Missions.slots[i].activation`), ce qui explique que `checkMissions` porte de longues vérifications de possession (`zc:103763-103800`).
- Les sons de début/fin sont des sons de coalition (`ding.ogg`, `cas.ogg`, `cancel.ogg`) joués depuis `startAction` / `endAction` (`Setup:6201-6209`, `Setup:7093-7095`).

### Générateurs d'attaque, de ravitaillement et de capture (détail)

- L'état est un ensemble de globales du fichier de setup en PvE : `attackTarget1..3`, `resupplyTarget1..2`, `captureTarget`, plus `attackCombinedStart1/2`, `attackSuppressStart2`, `resupplyCombinedStart1/2`, `resupplySuppressStart2` utilisés seulement pour fusionner les messages de début de deux missions créées dans le même passage en une seule ligne « Attack A and B » / « Resupply A and B » (`Setup:6559-6570`, `Setup:7095-7102`).
- Chaque générateur est une fonction libre du moteur, appelée par une boucle `timer.scheduleFunction` du fichier de setup qui renvoie `time + 300` quand une mission existe et `time + 120` sinon ; la boucle d'attaque démarre 35 s après le chargement, DEAD à 140 s, SEAD à 120 s (`Setup:9742-9747`, `Setup:9801-9824`).
- `generateAttackMission()` : une zone est une cible d'attaque valide quand elle est rouge, active, non suspendue, non masquée, et que son nom ne contient ni `hidden`, ni `sam`, ni `defence` ; les candidates sont les extrémités rouges de chaque connexion bleu–rouge de `bc.connections` (`zc:63911`, `zc:64087-64102`, `zc:64112-64123`, `zc:64164-64167`).
- `attackTarget1` est tirée au hasard parmi les candidates ; `attackTarget2` est tirée parmi les zones rouges qui partagent un voisin bleu avec la première cible (les deux attaques sont donc sur le même front), sinon parmi toutes les candidates (`zc:64172-64189`, `zc:64195-64256`).
- `attackTarget3` n'existe que quand le Director bleu signale une « troisième demande d'attaque » (`blueDirector:hasBlueThirdAttackDemand`), vérifiée toutes les 30 s ; sa création déclenche aussitôt les générateurs CAS, SEAD et piste pour que le troisième front reçoive ses missions de soutien (`zc:64258-64267`, `Setup:9785-9794`).
- La mission d'attaque elle-même ne fait qu'étiqueter la zone ("Attack" sur le libellé de carte), jouer `cas.ogg`, et se termine (`cancel.ogg`, "attack ended") quand la zone n'est plus rouge ou est suspendue ; elle ne porte aucun `reward` (`Setup:7078-7128`).
- `generateSupplyMission()` : exige plus d'une zone bleue ; les cibles préférées sont les zones bleues reliées à une cible d'attaque courante qui ont besoin de supply (`bc:_playerSupplyTargetNeedsSupply` = utilisable par le Director et « needs external supply » dans le modèle de supply régulier), sinon n'importe quelle zone bleue qui a besoin de supply ; chacun des deux emplacements tire au hasard dans le pool préféré, puis dans le pool de repli (`zc:63794-63801`, `zc:63823-63840`, `zc:63735-63773`, `zc:63640-63650`).
- La mission de ravitaillement est active tant que la zone a encore besoin de supply ; elle n'a pas de son de début propre au-delà du message, ni de `reward` : les joueurs sont payés par livraison (§3.5) (`Setup:6666-6671`, `Setup:6621`).
- `generateCaptureMission()` : les candidates sont les zones du bucket de boutique `neutral_capture_targets` sans capture temporisée, porte-avions exclus ; le Director bleu en choisit une avec `selectMissionTarget('CAPTURE', candidates)` dans `captureTarget` (`zc:64355-64371`).
- Phase d'ouverture de Normandie (état `bc.normandyAttackMissionState`, construit dans `Normandy_Zone_Setup.lua:3910-3996`, nom court `NZ`) :
  - la phase d'ouverture dure tant que le BLEU ne possède aucune zone active et visible sur le continent (chaque zone de la carte de connexions terrestres dont la zone du Director n'est pas `southern_england`) ; le test est mis en cache par `bc._capTargetStateGeneration` (`NZ:3963-3988`) ;
  - quatre fronts de débarquement écrits à la main, chacun `{id, primary = {zones}, support = {zones}}` : `cotentin` (Maupertus, Brucheville), `calvados` (Cricqueville, Saint-Pierre, Longues-Sur-Mer, Sainte-Croix), `seine_picardy` (Fecamp, Saint-Aubain, Abbeville), `pas_de_calais` (Dunkirk), avec des batteries côtières, des ports et des sites V1 comme zones de soutien (`NZ:3912-3961`) ;
  - pendant l'ouverture, il n'y a pas de connexion bleu–rouge à travers la Manche à partir de laquelle construire des candidates, donc `attackTarget1` est tirée parmi les zones **primary** de tous les fronts qui ont un aérodrome, et `attackTarget2` parmi les zones primary et support du **même front** que la première cible (`zc:64141-64156`, `zc:64191-64210`) ; aucune troisième cible n'est créée dans cette phase (`zc:64258`) ;
  - une fois l'ouverture terminée, la règle normale du front s'applique sur la carte de connexions terrestres (`blueDirector:_groundConnectionMap()`), la deuxième cible peut aussi être une zone d'infrastructure de la zone du Director de la première cible, et le second emplacement d'attaque de l'ouverture est retiré une fois (`zc:64157-64162`, `zc:64230-64240`, `zc:64077-64082`) ;
  - la même phase restreint les générateurs CAS et de frappe de piste aux zones du front courant (`bc.normandyOpeningCasZoneEvaluator`, `bc.normandyOpeningRunwayZoneEvaluator`) (`NZ:3998-4009`, `zc:63168-63176`, `zc:79153`).

### DEAD, frappe de piste, recon et attaque de masse rouge (détail)

- DEAD : `bc:initDeadMissions()` crée `bc.deadMissions.slots[1..3] = {targetZone}` (`DEAD_MISSION_MAX_SLOTS = 3`), et `mc:registerDeadMissions()` suit une mission par emplacement (`zc:62636-62652`, `zc:103602-103633`).
- Une candidate DEAD est une zone rouge active dont le nom en minuscules contient l'un des `_deadMissionNamePatterns` (`sam`, `defence` ; davantage en Syrie et à Kola), qui n'est pas déjà la cible d'un emplacement SEAD et pour laquelle `bc:HasSeadTargets(name)` est faux (plus aucun SAM à radar, donc seuls les « restes » d'une zone de défense aérienne qualifient) (`zc:64375-64380`, `zc:64447-64465`).
- Les candidates doivent se trouver à moins de 24 000 m (`ZONE_DISTANCES`) de l'une des cibles d'attaque courantes `attackTarget1..3` ; si aucune ne l'est, on essaie les zones des deux extrémités de chaque connexion du front ; le Director bleu choisit avec `selectMissionTarget('DEAD', candidates, context)` (`zc:64419-64443`, `zc:64468-64511`).
- Le générateur est une boucle `timer.scheduleFunction` démarrée 140 s après le chargement, relancée toutes les 300 s quand une mission existe et toutes les 120 s sinon (`Setup:9812-9824`).
- La mission ne fait qu'étiqueter la zone (`addMissionTag(zone, "DEAD")`, rafraîchissement du libellé de carte) et jouer `ding.ogg` / `cancel.ogg` ; il n'y a ni champ `reward` ni registre, donc les joueurs ne gagnent que les récompenses de kill normales (`zc:103611-103621`).
- `isActive` : zone toujours rouge, non suspendue et toujours sans cibles SEAD (`zc:103622-103630`).
- Frappe de piste : `bc.runwayMissions.slots[1..3]` contiennent `{target (airbase name), targetZone, hitZones, runwayNames, done, hits, need, bomberName, partnerName, completed, active, started}` (`zc:61961-61990`).
- Choix de la cible : zones d'aérodrome rouges actives reliées au bleu (`ZONE_CONNECTED_TO_BLUE`) qui ont une « piste bombardable » pour le Director et sont hors cooldown ; score = 2 par groupe aérien rouge basé là (+1 si c'est un groupe CAP), plus un bonus de 5 / 3 / 0 pour les trois plus proches d'une zone bleue ; les zones avec plus de deux groupes CAP sont préférées ; repli = n'importe quel tel aérodrome à moins de 60 NM ; l'emplacement 3 est réservé à l'aérodrome de la troisième cible d'attaque (`zc:62343-62357`, `zc:62364-62462`).
- Les zones de piste viennent de Moose `AIRBASE:GetRunways()` (chaque piste a une `zone` polygonale, un `heading` et `isLeft`), dédoublonnées par désignateur de piste pour que les deux extrémités d'une bande ne comptent qu'une fois ; `need` = nombre de pistes distinctes (`zc:62489-62512`).
- Détection : un objet Moose `EVENT` gère `EVENTS.Shot` seulement tant qu'un emplacement est actif ; pour un tir d'un joueur dont l'arme est une bombe (`WEAPON:New(EventData.weapon):IsBomb()`), l'arme est suivie toutes les 0,1 s (`WEAPON:StartTrack(0.1)`, `SetDistanceInterceptPoint(200)`) et `SetFuncImpact` reçoit le point d'impact (`zc:62048-62077`, `zc:62260-62281`).
- Un impact à l'intérieur d'une zone de piste (`ZONE:IsVec3InZone`) ou à moins de 10 m de son centre marque cette piste `done` ; avec plusieurs pistes, le pilote reçoit « `<runway> HIT!` » ; quand `hits >= need` l'emplacement est terminé, `bc:blockRunwayPlaneSpawns(zone, 3300)` empêche les avions rouges d'y apparaître pendant 55 min, et le bombardier reçoit `awardJointMissionReward(pilot, 2, need > 1 and 200 or 100, 'Bomb runway')` s'il est inscrit (`zc:62193-62223`).
- Le suivi d'arme de Moose `WEAPON` est un `timer.scheduleFunction` qui appelle `Weapon:getPosition()` dans un `pcall` à chaque pas ; quand l'appel échoue (l'arme n'existe plus), le point d'impact est le point d'interception du terrain calculé à moins de `distIP` mètres de la dernière position (`_GetIP`), sinon la dernière position connue, et le callback d'impact se déclenche une fois (`Moose:35135-35204`) ; c'est le seul usage de cette classe dans ce thème.
- Fin : message `SYRIA_BOMB_RUNWAY_END_SOLO/JOINT/COMPLETED`, ou `…_CANCELED_ZONE` quand la zone a changé de camp ; `RUNWAY_ZONE_COOLDOWN[zone] = now + 3000` ; l'emplacement est réinitialisé (`Setup:8936-8972`).
- Recon : `bc.reconMissions.slots[1..3]` (`RECON_MISSION_MAX_SLOTS = 3`) ; `startReconMissionZoneTracker(zone)` construit une fois un `SET_CLIENT` Moose des clients avions bleus actifs (`FilterCoalitions("blue"):FilterCategories("plane"):FilterActive(true):FilterStart()`) et un `ZONE:New(zoneName)` Moose sur la trigger zone de campagne (`zc:62637-62638`, `zc:65085-65094`, `zc:65248-65271`).
- Un seul `timer.scheduleFunction` partagé sert les emplacements en round-robin, un emplacement par passage, toutes les `5 s / number of active slots` (`RECON_MISSION_CHECK_PERIOD_SEC = 5`) ; pour chaque client vivant : à l'intérieur de la zone → `enteredBy[player] = true` ; à l'extérieur et auparavant à l'intérieur → ce joueur est le `winner` et l'emplacement est `completed` (`zc:65181-65222`).
- Le « recon run » consiste donc simplement à entrer dans la zone et à en ressortir vivant avec un avion à voilure fixe ; les hélicoptères ne sont pas dans l'ensemble de clients, et il n'y a aucune condition d'altitude, de vitesse ou de capteur (`zc:65087-65093`, `zc:65207-65219`).
- Les zones candidates excluent les zones masquées, celles dont le nom contient `sam` / `defence`, celles avec de l'intel actif ou un drone JTAC, celles qui détiennent un SAM, et celles situées dans le rayon de menace d'un SAM longue portée voisin (`ReconNeighborSamRadiusMeters` : SA-10 30 NM, SA-5 40 NM, HAWK, NASAMS, Patriot) (`zc:65295-65300`, `zc:65371-65383`).
- `endAction` paie `awardJointMissionReward(winner, 2, 100, "Recon mission")`, annonce `SYRIA_DYNAMIC_RECON_COMPLETED_SOLO/JOINT`, pose un cooldown de 900 s sur la zone et démarre 10 min d'intel de zone (`startZoneIntel(target, 600, 2)`) (`Setup:7910-7920`).
- Attaque de masse rouge : réglages `redMassAttackSettings = {missionId = "RedMassAttack", minimumGroups = 4, limits = {CAP = 2, CAS = 2, SEAD = 1, RUNWAYSTRIKE = 1}, liveStates = {takeoff, inair}}` (`zc:34445-34464`).
- `triggerRedMassAttack` construit, pour chaque zone d'aérodrome bleue, un plan de `GroupCommander` aériens rouges par rôle dans trois pools : `live` (déjà en vol vers cette zone), `assigned` (dormants, la visant déjà), `retask` (dormants, à portée de réassignation) ; un plan est éligible avec au moins 4 groupes, au moins un groupe CAP et un groupe de frappe, et au moins un groupe qui doit être forcé à apparaître ; le meilleur score l'emporte, une cible préférée par le Director ayant priorité (`zc:34501-34613`, `zc:35014-35018`).
- Lancement : les groupes dormants sont aussitôt mis en spawn avec `gc:forceSpawnNow(targetZone)` (un instantané d'état est conservé pour le retour arrière), au plus un par zone source au premier passage ; si le minimum n'est pas atteint, tout est annulé et l'achat renvoie « not available now » (`zc:34731-34800`).
- Le bleu reçoit `INTEL_MASS_ATTACK` ("Intel: The enemy is launching a mass attack on <zone>") avec `Intel_short.ogg` ; le rouge reçoit `COMBAT_RED_MASS_ATTACK` (`zc:35020-35023`).
- La mission suivie « Defend <zone> » (sa description donne le nombre de groupes attaquants) est active tant que `isRedMassAttackMissionActive()` trouve au moins un groupe participant vivant (`Group.getByName`, `getSize() > 0`), vérifié à chaque scrutation de mission de 15 s ; elle n'a pas de message de début propre ni de récompense (`zc:103065-103088`, `zc:34812-34832`).
- Persistance : tant que la mission est active, la sauvegarde de campagne porte `{targetZone, participants = {{commanderName, directorCapabilityId, directorInstanceGeneration, side, groupName, missionType, sourceZone, originalTarget, originalSpawnHot, retasked}…}}` (`_exportRedMassAttackMissionPersistence`, `zc:34834-34857`).
- Restauration (`_restorePendingRedMassAttackMission`, retentée par `scheduleRedMassAttackMissionRestore` jusqu'à ce que les groupes IA en vol aient été restaurés) : si la zone cible est toujours BLEUE et active, chaque participant sauvegardé dont le groupe est de nouveau vivant est remis dans la mission (un participant réassigné est de nouveau pointé sur la cible et reçoit de nouvelles tâches 1 s plus tard avec `_assignMissionAfterInAirRestore`), et `ActiveMission["RedMassAttack"]` est posé quand au moins un est revenu ; sinon chaque participant retrouve sa cible et son mode d'apparition d'origine et la mission est abandonnée (`zc:34859-34988`, `zc:34990-35001`).

### Missions d'escorte terrestre (flux d'acceptation)

- Définies dans la table de setup `missions[zone] = {zone, missionGroup, menuTitle, missionTitle, TargetZone, radius, MissionType = "Escort", flag, ActivateZone}` (PvE uniquement) (`Setup:2067-2100`).
- `handleMission(zoneName, groupName, groupID, group)` est planifié après l'apparition d'un **hélicoptère** joueur dans une zone (PvE uniquement, `_scheduleSpawnMissionHandle`, `zc:101053-101058`) ; si la mission peut démarrer, le groupe reçoit un sous-menu F10 de premier niveau intitulé du titre de la mission, contenant "Accept" et "Deny" (`zc:104606-104706`).
- "Accept" : `mc:acceptMission` marque la mission suivie comme acceptée et en cours, active éventuellement une zone masquée (`ActivateZone`), remplace le menu d'acceptation par un menu de contrôle pour chaque groupe suivi, leur dit qui a accepté, et 5 s plus tard pose une fumée bleue à côté du convoi (`zc:104638-104695`).
- "Deny" : marque la mission `denied` et retire le menu d'acceptation (`zc:104696-104709`).
- Menu de contrôle (`createControlMenuForGroup`, un sous-menu de groupe de premier niveau intitulé du `menuTitle` de la mission ; clés de libellé `ESCORT_*`, `L10N:1987-1995`) : le template du convoi est réapparu et arrêté (`trigger.action.groupStopMoving`) s'il n'était pas actif, puis le moniteur et la capture automatique sont armés (`zc:104380-104403`).
  - "Move" : si la vitesse du convoi dépasse 1 m/s, l'équipage répond "We're already on the move, <player>" ; sinon `trigger.action.groupContinueMoving(convoy)`, un son "CommandMove" aléatoire et "Copy that <player>, moving." à chaque groupe d'escorte (`zc:104405-104449`).
  - "Hold position" : l'image miroir avec `trigger.action.groupStopMoving(convoy)` et `mission.wasStopped = true` (`zc:104451-104496`).
  - "Deploy smoke near the convoy" : `trigger.action.smoke` bleu à 10 m de la dernière unité vivante du convoi (`zc:104499-104518`).
  - "Get Bearing to the Convoy" : relèvement et distance en km depuis l'unité de tête du joueur jusqu'à cette unité (`zc:104520-104545`).
  - "Manual Hold" > "Enable forced Hold" / "Disable forced Hold" : pose la globale `ManualHold`, qui empêche le convoi de repartir tout seul quand la zone est dégagée ; son `OkRoggerThat.ogg` (`zc:104547-104572`).
  - "Restart Mission" > Yes / No : détruit et refait apparaître le convoi, retire les menus de chaque groupe d'escorte et reconstruit celui-ci (`zc:104574-104601`).
  - "Set up FARP?" > Yes / No n'apparaît que quand le convoi atteint un point scripté (`PromptFarpSetup`) : le convoi s'arrête, "FARP deployment possible" ; Yes construit un FARP au niveau du convoi (`BuildFarpHere`) et repart, No repart simplement (`zc:104335-104375`).
- Arrêt automatique : `monitorFlagForMission` attache au convoi une `ZONE_GROUP` Moose de rayon `mission.radius` et exécute `triggerZone:Trigger(SET_GROUP of alive red ground groups)` ; quand un groupe terrestre rouge entre (en partie dedans suffit), le convoi est arrêté et les escorteurs sont prévenus « enemy convoy heading toward us » si ce groupe est en mouvement, « Enemy checkpoint ahead … clear it out » si l'une de ses unités a l'attribut `Fortifications`, ou une ligne « halt » aléatoire ; quand la zone est de nouveau vide, le convoi repart (`GROUP:RouteResume`) sauf si `ManualHold` est posé (`zc:104051-104185`).
- Près de la zone cible, `AutoHoldPosition` arrête le convoi avec « Nearing the target area, Clear it out » et force `ManualHold` jusqu'à ce que la zone cible déclenche son trigger `lost` (la zone a été neutralisée), puis le convoi continue (`zc:104283-104330`).
- Capture : `ArmEscortAutoCapture` scrute toutes les 5 s (`SCHEDULER` Moose, premier passage à 2 s) ; une fois la zone cible neutre et une partie du convoi à l'intérieur, `zone:startPendingCapture(BLUE, {kind = "group", name, template, destroyOnFinish = true, stopGroup = true})` confie le convoi à la mécanique de capture (`zc:104187-104213`).
- Échec : le groupe du convoi n'est plus actif → `missionFail` renvoie true, message « escort failed », menus retirés, et `startOver` re-propose la mission 10 s plus tard (`Setup:8605-8641`).
- Succès : zone cible bleue et active → 1000 crédits partagés entre les joueurs des groupes suivis (bourse + statistique `Escort Mission`), convoi détruit, et 30 s plus tard l'étape suivante est proposée depuis la zone cible (`Setup:8643-8697`).
- Aucun choix d'altitude n'a été trouvé dans ce flux d'escorte terrestre ; l'achat du bombardier stratégique propose « AI escort » ou « Player escort » par zone d'origine (`zc:3553-3585`), et l'escorte de chasseurs IA gratuite pour les joueurs est demandée depuis `WelcomeMessage.lua` (`AddEscortRequestMenu`, `EscortTypeByPlayerType`, `PvPEscorts`) : c'est là que vit le choix d'altitude, un menu "Request escort" proposant la même altitude, 2 000, 5 000 ou 10 000 ft au-dessus du joueur (`WelcomeMessage.lua:1724-1739` ; détail dans la note 06 §12).

### Affichage

- `F10 > Missions > Missions` affiche les missions en cours visibles du camp du spectateur (titre + description, séparés par des filets), puis "Available missions" pour les missions d'escorte pas encore acceptées (`zc:103413-103456`, `zc:101490-101497`).
- `F10 > Missions > Strike missions >` une commande par mission de frappe en cours (titre, suffixé du drapeau quand les titres se télescopent) qui affiche cette mission ; entrée "none" quand c'est vide (`zc:103227-103300`).
- `F10 > Missions > Intel >` (zones avec intel actif) et `F10 > Missions > Joint missions` vivent sous la même racine (`zc:103322-103347`, `zc:18653`).
- Une marque de carte de texte `missions` affiche la liste des missions (`zc:29080`).
- Les menus de frappe sont reconstruits par groupe seulement quand la signature (liste triée des drapeaux de frappe actifs) change (`zc:103218-103262`).

### Notes de reproduction

- La conception par scrutation signifie qu'une définition de mission est une closure aux effets de bord arbitraires ; la reproduire exige un contrat clair pour `isActive` (il est appelé toutes les 15 s pour chaque mission et modifie parfois l'état, par exemple efface sa propre cible, `Setup:7117-7128`).
- L'attribution des récompenses repose sur un enregistrement par unité au début de la mission, donc les unités d'un même groupe apparues plus tard ne sont pas des cibles.
- Trois canaux de récompense distincts coexistent : `reward` sur la mission (compte de la coalition), récompenses du registre (bourse du joueur), et paiements personnalisés dans `endAction` (CAP, recon, pools CAS/SEAD, escorte).
- L'usage de Moose est ici léger : `SCENERY:FindByZoneName` pour les cibles de décor (`Setup:9045`), conversions `UTILS`, sinon `trigger.action.markToCoalition`, `missionCommands.*`, `timer.scheduleFunction` bruts.

## 12. Arborescence du menu F10 (ce thème)

Toutes les entrées ci-dessous sont par groupe de joueur (`missionCommands.add…ForGroup`), créées à la naissance de slot par le handler de naissance du commandant logistique et retirées quand le groupe meurt (`pruneGroupMenus`) (`zc:101203-101215`, `zc:101490-101497`, `zc:43033-43035`).

```
F10 > Other
├─ Shop                                             (zc:22401)
│  ├─ AI Attack > [cost] item > zone > (options)    (zc:22524-22530)
│  ├─ Zone Upgrades > [cost] item > zone
│  ├─ JTAC & Intel > [cost] item > zone
│  ├─ Combined Arms > [cost] item > zone
│  ├─ Capture & resources > [cost] item > zone
│  ├─ Other support > [cost] item > zone > Orbit | Hot xxx > nn NM Leg
│  └─ Budget overview                               (zc:22412)
├─ Dynamic Control                                  (zc:16425)
│  └─ Tankers Control / CAP Control / entrées CAS, Bomber, SEAD, Decoy, strategic bomber, building strike, navy artillery (voir §5)
├─ Missions                                         (zc:101490)
│  ├─ Missions                                      (zc:101497)
│  ├─ Strike missions > <mission>                   (zc:103235)
│  ├─ Intel > <zone>                                (zc:103337)
│  └─ Joint missions > Request player | Pending requests | Status | Leave | Help   (zc:18653)
├─ Stats and Settings                               (zc:101203)
│  ├─ Stats > My Stats | Top 10 Players | Top 5 Players | Top 5 Today | Rank Help
│  │        └─ Career > Overview | Flight progress | Combat progress | Logistics progress | Aircraft
│  └─ AI Logistics (Currently …)                    (zc:101172)
└─ <escort mission title> > Accept | Deny           (zc:104636-104696)
```

- Portée : au niveau du groupe pour tout ce qui précède ; les seuls menus au niveau de la coalition dans ce thème sont l'ancien « shop for all » et l'ancien menu de demande de CAP (`DYNAMIC_REQUEST_CAP_FROM`) (`zc:13044`, `zc:107506`).
- Déclencheurs de rafraîchissement : naissance de slot, changement de rang, changement d'étagère, changement d'état d'une zone (rafraîchissement de sélecteur en file), début/fin de mission (menus de frappe et d'intel), changement de locale (`L10N:ForGroup`).
- Langue : chaque groupe a sa propre locale, donc chaque libellé est résolu par groupe (`zc:22398`).

## 13. Réglages de Config qui ajustent l'économie

| Réglage | Par défaut | Signification | Code |
|---|---|---|---|
| `ShopPrices[id]` | voir §5 | prix de l'article | `Config:1771-1842` |
| `ShopRankRequirements[id]` | voir §5 | rang minimum | `Config:1846-1916` |
| `AvailableShopItems[id]` | tous `true` | `false` retire l'article | `Config:1608-1767` |
| `RewardContribution` | voir §3 | récompenses par événement | `Config:1920-1936` |
| `RefuelReward` | 2 | crédits par 100 lb reçues | `Config:1939` |
| `TurnaroundRewardPercent` | 10 | bonus de seconde sortie sur le même appareil | `Config:1589` |
| `NightRewardPercent` | 10 | bonus de décollage de nuit | `Config:1594` |
| `RewardFlightTime`, `FlightTimeRewardPerMinute`, `RewardAllAircraft`, `AllowedFlightTimeReward` | `true`, 2, `false`, transports seulement | récompense de temps de vol | `Config:2265-2303` |
| `CreditLosewhenKilled`, `CreditLosewhenKilledAmount` | `false`, 100 | pénalité de coalition par perte de joueur | `Config:261-264` |
| `RankingSystem` | `true` | conditionnement par le rang activé/désactivé | `Config:285` |
| `RankLoseWhenKilled`, `RankLoseWhenKilledAmount` | `true`, 100 | pénalité personnelle par perte | `Config:267-270` |
| `FriendlyFireRankPenalty` | 500 | pénalité personnelle par team kill | `Config:288` |
| `StoreLimit` | `false` | seuil de points sur la vie entière pour les articles chers | `Config:282` |
| `ShowKills` | `false` | message par kill au tueur | `Config:275` |
| `StartupFunds` | 1000 / 1000 | crédits de départ PvP | `Config:308-311` |
| `AllowCapAutoBuyAfterLoss`, `MaxCapAutoBuys` | `false`, 1 | rachat automatique des CAP | `Config:1580-1584` |
| `AdvanceCaptureRemainingThreshold` | 50 | % de groupes d'upgrade restants pour « advance capture » | `Config:1602` |
| `AIAttackTakeoffFromGround`, `AIAttackTakeoffFromGroundExtraNM` | `true`, 40 | les vols achetés partent d'un aérodrome | `Config:1943-1944` |
| `AllowAdminBuy` | `true` | marqueur `adminbuy` | `Config:1948` |
| `AllowScriptedSupplies` | `false` | supplies instantanés au lieu d'une livraison IA ; met `supplies` sur l'étagère | `Config:1952` |
| `CTLDCost`, `CTLDPrices` | `true`, table | prix et rangs CTLD | `Config:1959`, `Config:1975-2058` |
| `CarrierRankRequirement` | 5 | rang pour déplacer le porte-avions | `Config:292` |
| `CsarPilotSpawnWithoutCreditsChance` | 50 | chance d'apparition d'un pilote à terre sans crédits | `Config:2230` |
| `PvPEscorts` | `false` | offre d'escorte gratuite de deux chasseurs en PvP | `Config:327` |
| `AdminCommandAliases.addBlueFunds / addRedFunds / buyWithoutRank` | `""` | mots de marqueur personnalisés pour les actions admin | `Config:3477-3489` |

- Le fichier de setup fusionne ses propres valeurs par défaut sous les tables de Config (`mergeDefaults`), donc une clé absente de Config retombe sur la valeur du setup (par exemple `redwarehouse = 3000`, `redwhrepair = 2000`) (`Setup:2996-3004`, `Setup:2931-2932`).
- Constantes économiques codées en dur : récompenses de hauts faits (`zc:12080-12090`), pools par kill CAS/SEAD 30 / 50 (`zc:62632-62634`), récompense d'EWR automatique 300 (`zc:102465`), recon 100 (`Setup:7911`), CAP `kills × 100` (`Setup:8346`), escorte 1000 (`Setup:8648`), escorte de bombardier stratégique 1000 (`Setup:3715`), partage à l'éjection 25 % / 75 % (`zc:41749`, `zc:41764`), upgrade de zone rouge 3000 et attaque de masse rouge 2500 (`Setup:4799`, `Setup:4812`).

## Vu hors de ce thème

- Hunter : intercepteurs/chasseurs ennemis lancés contre un joueur après un certain nombre de kills (`initHunter`, `registerHuntKill`, `_spawnHunterForPlayer`) (`zc:40974-41059`).
- Intel de zone (`startZoneIntel`, marqueurs d'unités, boucle de rafraîchissement, 60 min par défaut) (`zc:6954-7010`).
- Gestion de la nuit pour l'intervalle de détection de MANTIS et le flou radar (`_applyNightMantisState`) (`zc:41614-41643`).
- Collecte par le Director de preuves de combat aérien à partir des événements de kill (`_recordDirectorAirCombatEvidence`) (`zc:41926-42081`).
- Destruction de piste : `S_EVENT_DEAD` sur un aérodrome bloque les spawns d'avions pendant 3300 s (`zc:42906-42920`).
- Largage de cargaison par Hercules sur `S_EVENT_SHOT` (`HercCargoDropSupply.HandleShot`) (`zc:42921-42930`).
- Intel de « debrief » de capture de pilote ennemi, y compris la divulgation du plan du Director ennemi (`zc:42313-42363`).
- Suspension « idle » des zones / réveil à l'achat (`_idleSuspended`, `idleZoneWakeHoldSec`) (`zc:21980-22018`).
- Installation Entrepôt / Logistic Center (`applyLogisticCenterUpgrade`, `applyWarehouseRepair`) (`zc:24155-24253`).
- FARP dynamiques achetés par marqueur et construits par un hélicoptère IA (`processMapFarpPurchase`, `_dispatchMarkerFarpFlight`) (`zc:21332`, `zc:20870`).
- Commandes admin par marqueur (`startMonitorPlayerMarkers` : help, debug, spawn, event, capture, déplacement de Tarawa…) (`zc:28354-28408`).
- Module de bombardier stratégique et sa surveillance de l'enveloppe d'escorte joueur (`StrategicBomber.StartPlayerEscortWatch`) (`zc:3293`).
- Escorte IA gratuite pour les joueurs et gestion des indicatifs dans `WelcomeMessage.lua` (`AddEscortRequestMenu`, `WelcomeMessage.lua:2727`).
- Support d'artillerie navale avec Moose OPS (`AUFTRAG:NewARTY`, `FLIGHTGROUP`) (`zc:109950-110075`).
