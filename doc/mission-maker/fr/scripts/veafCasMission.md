# veafCasMission — Générateur d'entraînement CAS

**Module ID:** `CASMISSION` | **Version:** 1.15.x | **Fichier:** `veafCasMission.lua`

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
veafCasMission.start()
```

`start()` active le watchdog qui surveille le groupe CAS.

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

| Option | Plage | Description |
|--------|-------|-------------|
| `size` | 0–5 | Nombre d'unités cibles |
| `defense` | 0–5 | Niveau de défense AA (0=aucune, 5=SAM lourd) |
| `armor` | 0–5 | Niveau de blindage (0=infanterie, 5=MBT lourd) |
| `side` | blue/red | Coalition des cibles |

---

## Menu radio F10

- **Générer** — créer une nouvelle zone CAS à un emplacement aléatoire ou spécifié
- **Fumée** — marquer la zone avec de la fumée colorée (délai de 3 minutes)
- **Fusée éclairante** — marquer la zone avec des fusées d'illumination (délai de 2 minutes)
- **Infos** — afficher la position, composition et statut de la zone
- **Passer** — abandonner la zone courante et en générer une nouvelle
- **Nettoyer** — détruire toutes les unités CAS et réinitialiser

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
- [Référence API Lua](../../../LUA_API_REFERENCE.md) — API complète de `veafCasMission`
