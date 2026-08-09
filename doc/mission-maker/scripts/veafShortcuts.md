# veafShortcuts — Aliases de marqueurs

**Module ID :** `SHORTCUTS` | **Fichier :** `veafShortcuts.lua`

---

## Objectif

Fournit des commandes marqueur courtes et faciles à retenir (aliases) qui correspondent à des commandes `_spawn` ou autres commandes VEAF complètes. Les joueurs tapent `-nomAlias` dans un marqueur F10 au lieu de mémoriser la syntaxe complète des commandes.

---

## Fonctionnement

1. Le joueur place un marqueur F10 avec un texte commençant par `-`
2. `veafShortcuts` résout l'alias vers la commande VEAF sous-jacente
3. La commande résolue est exécutée comme si le joueur l'avait tapée directement

Les aliases peuvent inclure des **paramètres aléatoires** (ex : `-sam` choisit un niveau de défense aléatoire à chaque fois).

---

## Activation

```lua
veafShortcuts.initialize()
```

Cela enregistre automatiquement la liste d'aliases par défaut.

> **Activé par défaut.** Les alias intégrés (`-shilka`, `-sa2`, …) fonctionnent d'emblée — la liste `shortcuts:` ci-dessous ne sert qu'à ajouter vos *propres* alias custom.

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

```yaml
modules:
  SHORTCUTS:
    enabled: true          # défaut : true
    logLevel: info        # surcharge optionnelle du niveau de log
    shortcuts:            # définitions d'aliases personnalisés
      - name: "smoke"                 # nom de l'alias (tapé en -smoke dans les marqueurs)
        description: "Raccourci fumée" # affiché dans l'aide radio
        command: "/_smoke"            # commande VEAF à exécuter
        bypass_security: false        # true = toujours disponible, sans /secu
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `enabled` | booléen | `true` | Non | Activer ou désactiver le module |
| `logLevel` | string | *(global)* | Non | Surcharge du niveau de log par module |
| `shortcuts` | objet[] | `[]` | Non | Aliases personnalisés supplémentaires |
| `shortcuts[].name` | string | — | Oui | Nom de l'alias — les joueurs tapent `-nom` dans un marqueur |
| `shortcuts[].description` | string | — | Non | Description affichée dans l'aide radio |
| `shortcuts[].command` | string | — | Oui | Commande VEAF complète à exécuter (ex : `/_smoke`) |
| `shortcuts[].bypass_security` | booléen | `false` | Non | Si true, cet alias ignore le système de sécurité |

### Exemple minimal

```yaml
modules:
  SHORTCUTS:
    enabled: true
    shortcuts:
      - name: "cas"
        description: "Demander CAS"
        command: "/_spawn group, name CAS-Template"
```

---

Les créateurs de missions peuvent également ajouter des aliases personnalisés dans `mission-script.lua` :

---

## Aliases personnalisés

Ajoutez des aliases spécifiques à votre mission dans `mission-script.lua` :

```lua
veafShortcuts.AddAlias(
  VeafAlias:new()
    :setName("-monalias")
    :setDescription("Mon spawn personnalisé")
    :setVeafCommand("_spawn group, name mon-groupe-custom")
)
```

---

## Référence des aliases par défaut {#default-aliases-reference}

Les aliases intégrés les plus courants sont regroupés ci-dessous. Voir la **[Référence des Alias](../../ALIASES.md)** pour la liste complète de tous les alias intégrés.

### Missions aériennes

| Alias | Description |
|-------|-------------|
| `-cap` | CAP dynamique (nécessite le nom de l'appareil) |
| `-airstart` | Démarrer une mission de combat (nécessite un nom) |
| `-airstop` | Arrêter une mission de combat (nécessite un nom) |
| `-zonestart` | Activer une zone de combat (nécessite un nom) |
| `-zonestop` | Désactiver une zone de combat (nécessite un nom) |

### Radio

| Alias | Description |
|-------|-------------|
| `-send` | Envoyer un message radio (nécessite `"MESSAGE"`) |
| `-play` | Jouer un fichier son (nécessite `"NOMFICHIER"`) |

### Mission Master

| Alias | Description |
|-------|-------------|
| `-flag` | Lire la valeur d'un flag (nécessite un nom) |
| `-flagon` | Mettre un flag à ON (nécessite un nom) |
| `-flagoff` | Mettre un flag à OFF (nécessite un nom) |
| `-run` | Exécuter un runnable (nécessite un nom) |

### Commandes utilitaires

| Alias | Description |
|-------|-------------|
| `-destroy` | Détruire toute unité dans un rayon de 100 m du marqueur |
| `-ai_set` | Définir le handler IA d'un groupe terrestre |

---

## Sécurité

La plupart des aliases respectent le système de sécurité (`veafSecurity`). Certains aliases utilitaires (comme `-smoke`, `-signal`, `-light`, `-tacan`, `-jtac`, `-afac`) contournent la sécurité et sont toujours disponibles pour tous les joueurs.

---

## Voir aussi

- [Référence des Alias](../../ALIASES.md) — liste complète de tous les alias intégrés
- [veafSpawn](veafSpawn.md) — le moteur de spawn sous-jacent
- [veafSecurity](veafSecurity.md) — système de permissions

