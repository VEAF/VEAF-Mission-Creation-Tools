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
| `defense` | 0–5 | 1 | Niveau de défense AA (0=aucune, 5=SAM lourd) |
| `armor` | 0–5 | 1 | Niveau de blindage (0=infanterie, 5=MBT lourd) |
| `spacing` | 1–5 | 1 | Espacement entre les unités du groupe |
| `side` | blue/red | *(coalition du marqueur)* | Coalition des cibles |
| `disperse` | secondes | — | Les cibles se dispersent quand elles sont attaquées ; un `disperse` sans valeur = 15 secondes |
| `password` | texte | — | Mot de passe de sécurité (voir [veafSecurity](veafSecurity.md)) |

---

## Menu radio F10

Le sous-menu **CAS MISSION** est créé dès l'initialisation du module, avec une entrée **HELP**. Une fois une mission générée (via le marqueur `_cas`), il propose en plus :

- **Target information** — afficher position, composition et statut des cibles
- **Skip current objective** — abandonner la zone courante et en générer une nouvelle (commande sécurisée)
- **Target markers → Request smoke on target area** — marquer la zone avec de la fumée (délai de 3 minutes)
- **Target markers → Request illumination flare over target area** — marquer la zone avec une fusée d'illumination (délai de 2 minutes)

---

## Référence de difficulté

| Niveau | Unités typiques | Défense AA |
|--------|-----------------|------------|
| 0 | Infanterie, jeeps | Aucune |
| 1 | APC, camions | MANPADS |
| 2 | BMP, BTR | ZU-23 |
| 3 | IFV, chars légers | ZSU-23-4 + SA-9 |
| 4 | MBT | SA-13 + SA-15 |
| 5 | Mix MBT lourds | SA-6 / SA-11 |

---

## Voir aussi

- [veafCombatZone](veafCombatZone.md) — pour des zones persistantes et rejouables
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafCasMission`
