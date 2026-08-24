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

## Ce qui marche, et ce qui ne marche pas {#state}

Établi en lisant le code le 2026-08-24, plutôt que déduit :

| Ce que vous pouvez faire | État |
|---|---|
| Construire un gardien, lui donner des unités et une zone, l'attacher avec `start()` | fonctionne |
| **Être averti** quand un tir vise une unité protégée dans la zone | fonctionne |
| Faire détruire le missile en vol | **pas implémenté** — il n'y a aucun watchdog, et `veafMissileGuardian.getLargeScaleProtector()` est une ébauche qui renvoie `nil` |
| `veafMissileGuardian.AddGuardian` / `ActivateGuardian` / `DesactivateGuardian` | **refusent** : le module n'a pas de stockage de gardiens, et la classe n'a ni `activate` ni `desactivate`. Elles écrivent un avertissement dans le journal DCS au lieu de planter |
| Lister les gardiens depuis le menu radio | **pas implémenté** : le menu « GUARDIAN » ne contient qu'une entrée d'aide |

Jusqu'à la 6.15.36, l'avertissement au pilote était suivi d'une **erreur Lua à chaque tir** (le protecteur
manquant), et les trois verbes ci-dessus plantaient sur une fonction qui n'avait jamais été écrite. Le
comportement que cette page décrit — avertir la cible — est donc désormais complet ; le reste est
explicitement refusé plutôt que silencieusement cassé.

## Notes

- Un gardien n'avertit que les cibles présentes dans sa zone protégée lorsqu'un tir est détecté
- Classes internes : `VeafMG_Weapon` (arme en vol), `VeafMG_Guardian` (observateur), `VeafMG_Protector` (protecteur, ébauche : ses méthodes `start()` et `stop()` ont un corps vide)

---

## Voir aussi

- [veafSanctuary](veafSanctuary.md) — protection contre les intrusions d'unités
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafMissileGuardian`
