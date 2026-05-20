# veafSanctuary — Zones protégées

**Module ID:** — | **Fichier:** `veafSanctuary.lua`

---

## Objectif

Définit des zones qui détruisent automatiquement toute unité de la coalition spécifiée qui y entre. Utile pour protéger les zones d'opération des porte-avions, les bases aériennes amies ou les zones arrière sécurisées contre les intrusions ennemies.

---

## Dépendances

- `veafEventHandler` — pour la détection d'entrée dans la zone

---

## Activation

```lua
veafSanctuary.initialize()
```

Puis définir les zones :

```lua
VeafSanctuary:new()
  :setName("Carrier Zone")
  :setZoneName("ZONE-CARRIER-PROTECTION")
  :setCoalition(coalition.side.RED)  -- détruire les unités rouges qui entrent
  :setMessage("Aéronef hostile éliminé dans la zone de défense du porte-avions")
  :initialize()
```

---

## Méthodes du builder

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne |
| `:setZoneName(zone)` | Zone de trigger DCS |
| `:setCoalition(side)` | Coalition des unités à détruire |
| `:setMessage(text)` | Message affiché quand une unité est détruite |
| `:setSilent(bool)` | Supprimer les messages |
| `:initialize()` | Activer la zone |

---

## Notes

- La zone utilise la zone de trigger DCS définie dans l'éditeur de mission
- Les unités sont détruites immédiatement à l'entrée dans la zone
- Fonctionne pour les aéronefs et les unités terrestres
- N'affecte pas la coalition qui possède le sanctuary

---

## Voir aussi

- [veafMissileGuardian](veafMissileGuardian.md) — système d'interception de missiles
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafSanctuary`
