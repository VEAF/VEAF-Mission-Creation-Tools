# veafShortcuts — Aliases de marqueurs

**Module ID :** `SHCUT` | **Fichier :** `veafShortcuts.lua`

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

Cela enregistre automatiquement la liste d'aliases par défaut. Les créateurs de missions peuvent ajouter des aliases personnalisés dans `missionConfig.lua`.

---

## Aliases personnalisés

Ajoutez des aliases spécifiques à votre mission dans `missionConfig.lua` :

```lua
veafShortcuts.AddAlias(
  VeafAlias:new()
    :setName("-monalias")
    :setDescription("Mon spawn personnalisé")
    :setVeafCommand("_spawn group, name mon-groupe-custom")
)
```

---

## Référence des aliases par défaut

Voir la **[Référence des Alias](../../ALIASES.fr.md)** pour la liste complète de tous les alias intégrés.

---

## Sécurité

La plupart des aliases respectent le système de sécurité (`veafSecurity`). Certains aliases utilitaires (comme `-smoke`, `-signal`, `-light`, `-tacan`, `-jtac`, `-afac`) contournent la sécurité et sont toujours disponibles pour tous les joueurs.

---

## Voir aussi

- [Référence des Alias](../../ALIASES.fr.md) — liste complète de tous les alias intégrés
- [veafSpawn](veafSpawn.md) — le moteur de spawn sous-jacent
- [veafSecurity](veafSecurity.md) — système de permissions

