# veafMissileGuardian — Interception de missiles

**Module ID:** — | **Fichier:** `veafMissileGuardian.lua`

---

## Objectif

Intercepte et détruit les missiles entrants spécifiques pour protéger des ressources ou zones désignées. Utile pour protéger les porte-avions, FARP ou autres cibles de haute valeur contre des menaces balistiques dans des scénarios où une défense antimissile réaliste est souhaitée.

---

## Dépendances

- `veafEventHandler` — pour la surveillance des événements de tir de missile

---

## Activation

```lua
veafMissileGuardian.initialize()
```

Puis définir les zones de protection :

```lua
VeafMissileGuardian:new()
  :setName("Carrier Defense")
  :setGroupName("CVN-73")           -- protéger ce groupe
  :setRadius(30000)                 -- rayon d'interception en mètres
  :setMissileTypes({ "P-700", "Kh-41" })  -- intercepter ces types de missiles
  :initialize()
```

---

## Méthodes du builder

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne |
| `:setGroupName(name)` | Groupe DCS à protéger |
| `:setZoneName(zone)` | Alternativement, protéger une zone |
| `:setRadius(m)` | Rayon d'interception autour de la cible protégée |
| `:setMissileTypes(list)` | Liste des noms de types d'armes DCS à intercepter |
| `:setAllMissiles(bool)` | Si vrai, intercepter tous les missiles |
| `:setSilent(bool)` | Supprimer les messages d'interception |
| `:initialize()` | Activer le gardien |

---

## Notes

- Les missiles sont détruits quand ils entrent dans le rayon de protection
- Utiliser des listes de types de missiles spécifiques pour éviter d'intercepter les munitions amies
- Fonctionne pour les missiles anti-navires et sol-air

---

## Voir aussi

- [veafSanctuary](veafSanctuary.md) — protection contre les intrusions d'unités
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafMissileGuardian`
