# veafAssets — Ravitailleurs, AWACS et porte-avions

**Module ID:** `ASSETS` | **Version:** 1.8.x | **Fichier:** `veafAssets.lua`

---

## Objectif

Gère les ressources persistantes d'une mission — ravitailleurs, AWACS et porte-avions. Fournit des entrées dans le menu radio F10 pour chaque ressource : informations (position, TACAN, fréquence), réapparition après perte, et désactivation optionnelle.

---

## Dépendances

- `veafRadio` — menu F10
- `veafCarrierOperations` — pour les porte-avions (optionnel, intégration automatique)

---

## Activation

```lua
veafAssets.initialize()
```

Doit être appelé après avoir défini `veafAssets.Assets`.

---

## Définir les ressources

Remplir `veafAssets.Assets` avant d'appeler `initialize()` :

```lua
veafAssets.Assets = {
  {
    name        = "Texaco",
    description = "Texaco (KC-135)",
    groupName   = "KC-135 Texaco",
    information = true,    -- afficher le bouton Infos dans le menu radio
    disposable  = false,   -- permettre aux joueurs de le désactiver
  },
  {
    name        = "Arco",
    description = "Arco (KC-130)",
    groupName   = "KC-130 Arco",
    information = true,
    disposable  = false,
  },
  {
    name        = "Overlord",
    description = "Overlord (E-3A)",
    groupName   = "E-3A Overlord",
    information = true,
    disposable  = false,
  },
  {
    name        = "Mother",
    description = "CVN-73 Theodore Roosevelt",
    groupName   = "CVN-73",
    information = true,
    carrier     = true,    -- active les infos spécifiques aux porte-avions (BRC, TACAN, ICLS)
    disposable  = false,
  },
}
```

### Champs de la table de ressource

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `name` | string | Oui | Identifiant interne |
| `description` | string | Oui | Libellé affiché dans le menu F10 |
| `groupName` | string | Oui | Nom du groupe DCS dans la mission |
| `information` | boolean | Non | Afficher le bouton Infos (position, TACAN, fréq) |
| `disposable` | boolean | Non | Permettre aux joueurs autorisés de désactiver la ressource |
| `carrier` | boolean | Non | Afficher les infos spécifiques aux porte-avions (BRC, TACAN, ICLS) |

---

## Menu radio F10

Pour chaque ressource, un sous-menu est créé sous **F10 → Ressources** :

- **Réapparition [nom]** — fait réapparaître le groupe à sa position d'origine
- **Infos sur [nom]** — affiche la position, le canal TACAN, la fréquence radio (si `information = true`)
- **Désactiver [nom]** — désactive la ressource (si `disposable = true`, commande sécurisée)

---

## Notes

- Le groupe DCS doit exister dans l'éditeur de mission avec exactement le nom utilisé dans `groupName`
- Les informations du ravitailleur (TACAN, fréquence) sont lues depuis les paramètres de route/waypoint du groupe DCS
- Les informations du porte-avions nécessitent que `veafCarrierOperations` soit initialisé

---

## Voir aussi

- [veafCarrierOperations](veafCarrierOperations.md) — gestion des récupérations sur porte-avions
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafAssets`
