# veafMissileGuardian — Interception de missiles

**Module ID:** `MISSILEGUARDIAN` | **Fichier:** `veafMissileGuardian.lua`

---

> **Module expérimental / incomplet.** Ce module est à l'état de squelette (version `0.0.2`). Les classes décrites ci-dessous existent mais la logique de protection n'est pas encore implémentée (`veafMissileGuardian.getLargeScaleProtector()` et le watchdog du protecteur sont des ébauches). À utiliser uniquement à des fins exploratoires.

---

## Objectif

Vise à intercepter et détruire les missiles entrants pour protéger des ressources désignées. Un `VeafMG_Guardian` observe des unités et réagit lorsqu'un tir vise l'une d'elles dans une zone protégée, en avertissant la cible.

---

## Dépendances

---

## Activation

```lua
veafMissileGuardian.initialize()
```

`initialize()` construit le menu radio « GUARDIAN ». Puis définir un gardien :

```lua
local guardian = VeafMG_Guardian:new()
  :setName("carrier-defense")
  :setFriendlyName("Carrier Defense")
  :addProtectedUnit("CVN-73")        -- nom d'unité DCS à protéger (appeler plusieurs fois pour plusieurs unités)
  :setProtectedZone(polygon)         -- polygone (liste de points) où la protection s'applique
guardian:start()                     -- enregistrer le gestionnaire d'événements
```

`guardian:stop()` désenregistre le gestionnaire d'événements.

---

## Méthodes du builder (`VeafMG_Guardian`)

Le gardien est construit avec `VeafMG_Guardian:new()`. Chaque setter retourne le gardien, ce qui permet le chaînage.

| Méthode | Description |
|---------|-------------|
| `:setName(value)` | Identifiant interne |
| `:setFriendlyName(value)` | Nom lisible affiché aux joueurs |
| `:addProtectedUnit(value)` | Ajouter une unité DCS à protéger (nom ou objet unité) |
| `:setProtectedZone(value)` | Polygone (liste de points) délimitant la zone de protection |
| `:start()` | Enregistrer le gestionnaire d'événements |
| `:stop()` | Désenregistrer le gestionnaire d'événements |

---

## Notes

- Le module est expérimental : la destruction effective des missiles n'est pas encore implémentée
- Un gardien n'avertit que les cibles présentes dans sa zone protégée lorsqu'un tir est détecté
- Classes internes : `VeafMG_Weapon` (arme en vol), `VeafMG_Guardian` (observateur), `VeafMG_Protector` (protecteur, ébauche)

---

## Voir aussi

- [veafSanctuary](veafSanctuary.md) — protection contre les intrusions d'unités
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafMissileGuardian`
