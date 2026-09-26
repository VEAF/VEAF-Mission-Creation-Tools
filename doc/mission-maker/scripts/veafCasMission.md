# veafCasMission — Générateur d'entraînement CAS

**Module ID:** `CASMISSION` | **Fichier:** `veafCasMission.lua`

---

## Objectif

Génère à la demande des zones d'entraînement Close Air Support (CAS) avec des packages de taille, blindage et défense aérienne configurables. Les joueurs peuvent créer, marquer, passer et nettoyer les cibles CAS depuis le menu F10 ou via des commandes de marqueur.

---

## Dépendances

- `veafMarkers` — gestion des commandes de marqueur
- `veafRadio` — menu F10
- `veafSpawn` — backend de spawn d'unités

---

## Activation

```lua
veafCasMission.initialize()
```

> **Activé par défaut** dans le `mission.yaml` livré. Piloté par marqueur (`_cas`), sans configuration requise — posez simplement un marqueur `_cas`. Le bloc ci-dessous ne sert qu'à l'ajuster.

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

`veafCasMission` n'a **aucun champ configurable en YAML** : il s'active comme les autres modules.

```yaml
modules:
  CASMISSION:
    enabled: true          # défaut : true
    logLevel: info         # surcharge optionnelle du niveau de log
```

> **Les missions CAP et les missions de combat ne sont pas configurées ici.** Les sections
> `cap_missions:` et `combat_missions:` appartiennent au module `COMBATMISSION`, qui est un module
> distinct : voir [veafCombatMission](veafCombatMission.md#configuration-missionyaml). Elles étaient
> documentées sur cette page, ce qui envoyait chercher les champs d'un module dans la page d'un autre.

---

## Constantes de configuration clés

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafCasMission.Keyphrase` | `"_cas"` | Texte déclencheur du marqueur |
| `veafCasMission.SecondsBetweenWatchdogChecks` | `15` | Intervalle du watchdog (s) |
| `veafCasMission.SecondsBetweenSmokeRequests` | `180` | Délai entre fumées (s) |
| `veafCasMission.SecondsBetweenFlareRequests` | `120` | Délai entre fusées (s) |
| `veafCasMission.RedCasGroupName` | `"Red CAS Group"` | Nom du groupe DCS pour les unités CAS rouges |
| `veafCasMission.BlueCasGroupName` | `"Blue CAS Group"` | Nom du groupe DCS pour les unités CAS bleues |
| `veafCasMission.RadioMenuName` | `"CAS MISSION"` | Libellé du sous-menu F10 |

---

## Commandes de marqueur (côté joueur)

```
_cas
_cas, size 3, defense 2, armor 3
_cas, side blue
```

Options :

| Option | Plage | Défaut | Description |
|--------|-------|--------|-------------|
| `size` | 1–5 | 1 | Nombre d'unités cibles |
| `defense` | 0–5 | 1 | Niveau de défense aérienne de l'escorte, tiré à ±1 — voir [ce que place un niveau](#defense-levels) |
| `armor` | 0–5 | 1 | Niveau de blindage (0=infanterie, 5=MBT lourd) — voir [ce que contient un palier](#armour-tiers) |
| `spacing` | 1–5 | 1 | Espacement entre les unités du groupe |
| `side` | blue/red | *(coalition du marqueur)* | Coalition des cibles |
| `disperse` | secondes | — | Les cibles se dispersent quand elles sont attaquées ; un `disperse` sans valeur = 15 secondes |
| `password` | texte | — | Mot de passe de sécurité (voir [veafSecurity](veafSecurity.md)) |


### Ce que contient un palier de blindage {#armour-tiers}

Chaque palier tire au hasard dans une liste de types de véhicules, choisie selon la coalition et l'époque de la mission (`era`). Les listes sont maintenues à la main : un palier exprime une puissance *relative*, une notion que la base de données DCS ne porte pas — elle ne dit ni l'époque d'un véhicule ni sa place dans une échelle.

Depuis la 6.15.25, les blindés modernes ajoutés par DCS y figurent : le T-84 Oplot-M et le Stryker CV côté bleu, le T-90M et le BMPT Terminator côté rouge, entre autres. Un contrôle automatique vérifie désormais que **chaque** type nommé dans ces listes existe bien dans la base — auparavant, une entrée devenue invalide ne faisait simplement rien apparaître, sans le dire.

### Ce que place un niveau de défense {#defense-levels}

Le niveau `defense` sert à deux choses : l'**escorte** d'une section (un ou deux véhicules de défense
aérienne ajoutés aux blindés, à l'infanterie ou aux camions de `_cas`, `-armor`, `-convoy`…) et le
**groupe de défense aérienne** complet que posent `-sam`, `-samSR`, `-samLR` et `-aaa`
(`_spawn samgroup`). Pour une vraie batterie longue portée, c'est `-samVLR` (`_spawn longrangesam`),
qui ne dépend d'aucun niveau : voir [la liste des alias](../../ALIASES.md).

**Le niveau est tiré, pas garanti.** Pour un niveau demandé supérieur à 0 : 60 % de chances de
l'obtenir, 20 % d'obtenir le niveau en dessous, 20 % celui au-dessus. Le groupe de défense aérienne
reste ensuite borné à 0–5 ; l'escorte a un palier 6, atteint seulement par un 5 tiré vers le haut.
Les alias tirent aussi le niveau demandé dans une plage : `-sam` 1–5, `-samLR` 4–5, `-samSR` 2–3,
`-aaa` 1–2. `list_shortcuts` (MCP) donne ces plages pour chaque alias.

**Le niveau suit l'époque de la mission** (`mission.era`) :

- `MODERN` (défaut) : les groupes ci-dessous.
- `COLD_WAR` : les types entrés en service après 1980 — la référence des listes de blindés — sont
  remplacés : Avenger → Vulcan, Linebacker → Chaparral, Tor → Osa, Tunguska → Shilka, HQ-7 →
  Strela-10, Igla-S → Igla. Dates de service estimées, non sourcées.
- `WW2` : de la flak uniquement pour les groupes de défense aérienne (Bofors, M45, 3.7-inch côté
  bleu ; Flak 30/36/37/38/41 côté rouge), et **aucune escorte**.

Groupes de défense aérienne en `MODERN` :

| Niveau | Bleu | Rouge |
|--------|------|-------|
| 0 | AAV7, camions (aucune défense aérienne) | ZU-23, S-60 (0–1 chacun) |
| 1 | Vulcan, Avenger (0–1) | Shilka, ZSU-57-2 |
| 2 | Vulcan, Avenger | SA-9, Shilka, ZSU-57-2, S-60 |
| 3 | Gepard, Linebacker, Avenger | SA-13, SA-9, Shilka, ZSU-57-2 |
| 4 | Roland, Chaparral, Gepard | SA-8, SA-13, Shilka, ZSU-57-2 |
| 5 | Hawk, Chaparral, Gepard | SA-15, SA-8, SA-13, SA-19, ZSU-57-2, S-60 |

---

## Menu radio F10

Le sous-menu **CAS MISSION** est créé dès l'initialisation du module, avec une entrée **HELP**. Une fois une mission générée (via le marqueur `_cas`), il propose en plus :

- **Target information** — afficher position, composition et statut des cibles
- **Skip current objective** — abandonner la zone courante et en générer une nouvelle (commande sécurisée)
- **Target markers → Request smoke on target area** — marquer la zone avec de la fumée (délai de 3 minutes)
- **Target markers → Request illumination flare over target area** — marquer la zone avec une fusée d'illumination (délai de 2 minutes)

---

## Référence de difficulté

| Niveau | Unités typiques | Escorte de défense aérienne (rouge, `MODERN`) |
|--------|-----------------|------------|
| 0 | Infanterie, jeeps | Aucune |
| 1 | APC, camions | ZU-23 ou ZSU-57-2 |
| 2 | BMP, BTR | Shilka ou ZSU-57-2, ×2 |
| 3 | IFV, chars légers | SA-9 ou SA-13, Shilka ou ZSU-57-2 |
| 4 | MBT | Shilka ou ZSU-57-2, HQ-7 |
| 5 | Mix MBT lourds | SA-8 ou SA-19, Shilka ou SA-13 |

Le niveau est tiré à ±1 et suit l'époque : voir [ce que place un niveau de défense](#defense-levels).

---

## Voir aussi

- [veafCombatZone](veafCombatZone.md) — pour des zones persistantes et rejouables
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafCasMission`
