# veafQraManager — Alerte de réaction rapide (QRA)

**Module ID:** `QRA` | **Version:** 1.2.x | **Fichier:** `veafQraManager.lua`

---

## Objectif

Définit des zones d'espace aérien protégées défendues par des intercepteurs IA. Quand un aéronef hostile entre dans la zone, un vol QRA est scramblé. Une fois la QRA détruite, la zone n'est plus défendue jusqu'à la prochaine réinitialisation (quand tous les intrus ont quitté). Supporte plusieurs groupes, le réarmement, la dépendance à une base aérienne et les messages radio de statut.

---

## Dépendances

- `veafRadio` — messages de statut (optionnel)
- `veafSpawn` — spawn du groupe IA

---

## Activation

Pas d'appel global `initialize()`. Chaque zone QRA est créée et initialisée individuellement :

```lua
local myQra = VeafQRA:new()
  :setName("QRA-North")
  :setZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :setGroups({ "MiG-29 QRA" })
  :initialize()
```

---

## Méthodes du builder VeafQRA

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne et préfixe des messages |
| `:setZone(zoneName)` | Zone de trigger DCS définissant l'espace aérien défendu |
| `:setCoalition(side)` | Quelle coalition défend la zone |
| `:setGroups(names)` | Liste des noms de groupes DCS à scrambler |
| `:setRearmTime(s)` | Secondes avant réinitialisation de la QRA après départ de tous les intrus (défaut : 300) |
| `:setAirbase(name)` | Base aérienne dont dépend la QRA — si détruite, la QRA passe hors ligne |
| `:setAirbaseMinLifePercent(pct)` | Santé minimale de la base (défaut : 0,9 = 90%) |
| `:setSilent(bool)` | Supprimer les messages radio de statut |
| `:setMessageStart(text)` | Message personnalisé quand la QRA se met en ligne |
| `:setMessageDeploy(text)` | Message personnalisé quand la QRA est scramblée |
| `:setMessageDestroyed(text)` | Message personnalisé quand la QRA est détruite |
| `:setMessageReady(text)` | Message personnalisé quand la QRA est prête |
| `:setMessageOut(text)` | Message personnalisé quand plus d'aéronefs disponibles |

---

## Machine à états QRA

```
PRÊTE ──(intrus entre)──> ACTIVE ──(QRA détruite)──> MORTE
  ^                                                       |
  └──────(tous les intrus partis + délai de réarmement)──┘
```

États supplémentaires : `WILLREARM`, `OUT` (plus de groupes), `NOAIRBASE` (base aérienne détruite), `STOP` (désactivée manuellement).

---

## Constantes de configuration

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafQraManager.WATCHDOG_DELAY` | `5` | Intervalle de vérification en secondes |
| `veafQraManager.MINIMUM_LIFE_FOR_QRA_IN_PERCENT` | `10` | Vie minimale des unités QRA avant destruction |
| `veafQraManager.DEFAULT_airbaseMinLifePercent` | `0,9` | Seuil de santé par défaut de la base |
| `veafQraManager.AllSilence` | `false` | Supprimer globalement tous les messages QRA |

---

## Exemple : plusieurs zones QRA

```lua
-- Zone nord défendue par des MiG-29, liée à la base de Beslan
VeafQRA:new()
  :setName("QRA-NORTH")
  :setZone("ZONE-NORTH-DEFENSE")
  :setCoalition(coalition.side.RED)
  :setGroups({ "MiG-29S QRA North-1", "MiG-29S QRA North-2" })
  :setAirbase("Beslan")
  :setRearmTime(600)
  :initialize()

-- Zone sud, toujours active, silencieuse
VeafQRA:new()
  :setName("QRA-SOUTH")
  :setZone("ZONE-SOUTH-DEFENSE")
  :setCoalition(coalition.side.RED)
  :setGroups({ "Su-27 QRA South" })
  :setSilent(true)
  :initialize()
```

---

## Voir aussi

- [veafAirWaves](veafAirWaves.md) — système d'attaque IA par vagues (vs QRA qui est défensif)
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafQraManager`
