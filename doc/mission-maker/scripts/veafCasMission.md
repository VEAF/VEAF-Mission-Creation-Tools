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

`veafCasMission` lui-même n'a pas de champs configurables en YAML. Cependant, les **missions CAP** et les **missions de combat** (gérées par le module `COMBATMISSION`) sont déclarées dans des sections de premier niveau de `mission.yaml`.

```yaml
modules:
  CASMISSION:
    enabled: true          # défaut : true
    logLevel: info        # surcharge optionnelle du niveau de log
  COMBATMISSION:
    enabled: true          # requis pour cap_missions: et combat_missions:

# ── Missions CAP ──────────────────────────────────────────────────────────────
cap_missions:
  - group_name: "Groupe CAP"      # REQUIS — nom logique ; le groupe DCS doit s'appeler "OnDemand-Groupe CAP"
    menu_name: "CAP Nord"          # libellé dans le menu F10
    briefing: "Patrouiller le secteur nord et engager les menaces."
    default: false                # true = actif par défaut
    activated: true               # true = activé immédiatement au démarrage

# ── Missions de combat ───────────────────────────────────────────────────
combat_missions:
  - name: "Frappe-Alpha"          # REQUIS — identifiant interne
    friendly_name: "Frappe Alpha" # libellé dans le menu F10
    secured: false                # true = activation réservée aux pilotes autorisés (voir veafSecurity)
    radio_menu_enabled: true      # afficher dans le menu F10
    briefing: |
      Détruire la colonne blindée dans le carré BQ-123.
      Prévoir de l'AAA et des MANPADS.
    elements:
      - name: "Elément Alpha 1"   # nom interne de l'élément
        groups:                   # noms de groupes DCS inclus dans cet élément
          - "STRIKE-GROUP-1"
          - "STRIKE-GROUP-2"
        scalable: true            # true = le nombre de groupes s'adapte au paramètre de compétence
```

### Champs de `cap_missions[]`

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `group_name` | string | — | Oui | Nom logique du vol CAP. **Le groupe DCS placé dans l'éditeur doit être nommé `OnDemand-<group_name>`** : le runtime préfixe `OnDemand-` (depuis la v5). Ex. `group_name: CAP-Alpha` → groupe DCS `OnDemand-CAP-Alpha` |
| `menu_name` | string | — | Non | Libellé du menu F10 |
| `briefing` | string | — | Non | Texte de briefing affiché aux joueurs |
| `default` | booléen | `false` | Non | Démarrer comme mission active par défaut |
| `activated` | booléen | `true` | Non | Activer immédiatement au démarrage de la mission |

### Champs de `combat_missions[]`

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `name` | string | — | Oui | Identifiant interne |
| `friendly_name` | string | — | Non | Libellé du menu F10 |
| `secured` | booléen | `false` | Non | L'activation est réservée aux pilotes autorisés — au menu F10, le groupe agit au niveau de son occupant le moins gradé (voir [veafSecurity](veafSecurity.md)) |
| `radio_menu_enabled` | booléen | `true` | Non | Afficher dans le menu F10 |
| `briefing` | string | — | Non | Texte de briefing multi-ligne |
| `elements` | objet[] | `[]` | Non | Définitions des éléments de mission |
| `elements[].name` | string | — | Non | Nom interne de l'élément |
| `elements[].groups` | string[] | — | Non | Noms de groupes DCS dans cet élément |
| `elements[].scalable` | booléen | `true` | Non | Adapter le nombre de groupes à la difficulté |

### Exemple minimal

```yaml
modules:
  COMBATMISSION:
    enabled: true

cap_missions:
  - group_name: "CAP-Alpha"
    menu_name: "CAP"

combat_missions:
  - name: "Frappe-Nord"
    briefing: "Détruire les cibles nord."
    elements:
      - groups: ["Strike-Group-1"]
```

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
