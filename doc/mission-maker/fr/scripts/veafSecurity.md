# veafSecurity — Permissions par rôle

**Module ID:** `SECURITY` | **Version:** 1.3.x | **Fichier:** `veafSecurity.lua`

---

## Objectif

Fournit un système de permissions par mot de passe pour les commandes de marqueur VEAF et les actions du menu radio. Restreint les commandes sensibles (spawn, téléportation, destruction) aux joueurs autorisés. Trois niveaux de permission avec des mots de passe hachés en SHA-1.

---

## Activation

```lua
veafSecurity.initialize()
```

À appeler avant les autres modules pour que les vérifications de sécurité soient actives lors de leur initialisation.

---

## Niveaux de permission

| Niveau | Constante | Qui peut utiliser |
|--------|-----------|------------------|
| 0 (public) | `veafSecurity.LEVEL_L0` | Tous les joueurs — aucun mot de passe requis |
| 1 (pilotes) | `veafSecurity.LEVEL_L1` | Pilotes avec le mot de passe L1 |
| 9 (admin) | `veafSecurity.LEVEL_L9` | Administrateurs avec le mot de passe L9 |

Le niveau de sécurité par défaut pour les commandes de spawn peut être défini par module.

---

## Définir les mots de passe

Les mots de passe sont stockés sous forme de hachages SHA-1 pour la sécurité. Utiliser la fonction intégrée `sha1` :

```lua
-- Dans missionconfig.lua (après chargement de veafSecurity)

-- Effacer les mots de passe par défaut et définir les vôtres
veafSecurity.password_L1 = {}
veafSecurity.password_L9 = {}

-- Ajouter des mots de passe hachés (plusieurs mots de passe supportés par niveau)
veafSecurity.password_L1[sha1.hex("monMotDePasseL1")] = true
veafSecurity.password_L9[sha1.hex("monMotDePasseAdmin")] = true
```

> Ne pas committer de mots de passe en clair dans les fichiers de mission. Utiliser uniquement des hachages.

---

## Constantes clés

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafSecurity.authDuration` | `10` | Minutes pendant lesquelles l'authentification reste valide |
| `veafSecurity.Keyphrase` | `"_auth"` | Commande de marqueur pour l'authentification |
| `veafSecurity.LEVEL_L0` | `90` | Poids interne pour le niveau public |
| `veafSecurity.LEVEL_L1` | `10` | Poids interne pour le niveau pilotes |
| `veafSecurity.LEVEL_L9` | `1` | Poids interne pour le niveau admin |

---

## Authentification du joueur

Les joueurs s'authentifient via une commande de marqueur :

```
_auth [MOT_DE_PASSE]
```

En cas de succès : l'accès est accordé pour `authDuration` minutes. Aucun message n'est affiché aux autres joueurs.

---

## Désactiver la sécurité (développement / solo)

Pour les tests ou les missions solo où la sécurité n'est pas nécessaire :

```lua
veaf.SecurityDisabled = true
```

Cela contourne toutes les vérifications de sécurité globalement.

---

## Sécurité au niveau du module

Chaque module peut définir l'exigence de sécurité par défaut pour ses commandes. Exemple pour spawn :

```lua
-- Exiger L1 (pilotes) pour toutes les commandes de spawn
veafSpawn.defaultSecurity = veafSecurity.LEVEL_L1
```

---

## Voir aussi

- [Référence API Lua](../../../LUA_API_REFERENCE.md) — API complète de `veafSecurity`
