# veafCombatMission — Le menu MISSIONS

**Module ID:** `COMBATMISSION` | **Fichier:** `veafCombatMission.lua`

---

## Objectif

Propose aux joueurs, depuis le menu radio F10 **MISSIONS**, des scénarios que le créateur de la
mission a préparés dans l'éditeur DCS et déclarés en YAML. Deux familles :

- les **missions CAP** (`cap_missions:`) — des patrouilles aériennes à la demande ;
- les **missions de combat** (`combat_missions:`) — des scénarios avec briefing, éléments et suivi
  des ennemis restants.

Le module est **actif par défaut** (`veaf.registerModule(..., { enable = true }, 100)`). Il ne
construit **aucun menu** si aucune mission n'est déclarée.

---

## Dépendances

- `veafRadio` — le menu F10 `MISSIONS`
- `veafSpawn` — fait apparaître les groupes d'une mission
- `veafSecurity` — pour les missions déclarées `secured: true`
- `veafRemote` — le module distant `/air` (facultatif)

---

## Le menu F10 {#radio-menu}

> **Le menu suit la langue de la mission** (`mission.language`). Les libellés ci-dessous sont ceux
> d'une mission en français.

À la racine de `MISSIONS` :

| Entrée | Effet |
|--------|-------|
| `AIDE` | Rappelle le fonctionnement du menu *(absente si les menus d'aide sont désactivés)* |
| `Lister les missions disponibles` | Liste les missions déclarées |
| `Lister les missions en cours` | Liste les missions en cours, avec leur nombre d'ennemis restants |

Puis un sous-menu par mission, et dedans :

| Entrée | Effet |
|--------|-------|
| `Infos` | Briefing et état de la mission |
| `Activer la mission` | Démarre la mission *(visible quand elle est inactive)* |
| `Désactiver la mission` | L'arrête *(visible quand elle est active)* |

Une mission déclarée `secured: true` voit ses entrées d'activation passer par le contrôle de
sécurité : au menu F10, le groupe agit au niveau de son occupant **le moins gradé** (voir
[veafSecurity](veafSecurity.md)).

Une mission de combat propose en plus des sous-menus de **compétence** et d'**échelle**, qui règlent
la difficulté et le nombre de groupes engagés.

---

## Les alias {#aliases}

`veafShortcuts` fournit deux raccourcis, qui **ne contournent pas la sécurité**
(`setBypassSecurity(false)`) :

| Alias | Ce qu'il fait |
|-------|---------------|
| `-airstart` | Démarre une mission de combat — le nom se tape juste après |
| `-airstop` | Arrête une mission de combat |

```
-airstart Frappe-Nord
-airstop Frappe-Nord
```

---

## Le module distant `/air` {#remote}

Enregistré auprès de `veafRemote` sous le nom `air`, il répond dans le tchat :

| Commande | Effet |
|----------|-------|
| `/air list` | Liste les missions disponibles |
| `/air start <mission>` | Démarre la mission nommée |
| `/air start <mission> silent` | La démarre sans message à l'écran |
| `/air stop <mission>` | L'arrête |
| `/air stop <mission> silent` | L'arrête sans message |

---

## Configuration `mission.yaml` {#configuration-missionyaml}

```yaml
modules:
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
    secured: false                # true = activation réservée aux pilotes autorisés
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

### Champs de `cap_missions[]` {#cap-missions}

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `group_name` | string | — | Oui | Nom logique du vol CAP. **Le groupe DCS placé dans l'éditeur doit être nommé `OnDemand-<group_name>`** : le runtime préfixe `OnDemand-` (depuis la v5). Ex. `group_name: CAP-Alpha` → groupe DCS `OnDemand-CAP-Alpha` |
| `menu_name` | string | — | Non | Libellé du menu F10 |
| `briefing` | string | — | Non | Texte de briefing affiché aux joueurs |
| `default` | booléen | `false` | Non | Démarrer comme mission active par défaut |
| `activated` | booléen | `true` | Non | Activer immédiatement au démarrage de la mission |

### Champs de `combat_missions[]` {#combat-missions}

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

## Constantes du module {#constants}

| Constante | Valeur | Rôle |
|-----------|--------|------|
| `SecondsBetweenWatchdogChecks` | `30` | Intervalle entre deux vérifications de l'état des missions |
| `MinimumSpacingBetweenClones` | `300` | Distance minimale, en mètres, entre deux clones d'un même groupe |
| `RadioMenuName` | `menu.combatmission.root` | **Clé** i18n du nom du menu F10, résolue à la construction du menu |

---

## Voir aussi

- [veafCasMission](veafCasMission.md) — les missions CAS à la demande, un module distinct
- [veafSecurity](veafSecurity.md) — ce que `secured: true` implique côté pilote
- [Référence mission.yaml](../../MISSION_YAML_REFERENCE.md) — toutes les sections de premier niveau
