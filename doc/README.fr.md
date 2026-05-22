# VEAF Mission Creation Tools

Framework de scripts Lua et outils CLI Python pour créer des missions [DCS World](https://www.digitalcombatsimulator.com/) dynamiques et interactives.

**34 modules Lua runtime** s'exécutent dans DCS pour offrir le spawning, la gestion d'assets, les menus radio, les zones de combat, les opérations porte-avions, l'injection météo, et plus — le tout contrôlable par les joueurs via les marqueurs F10 et les menus radio.

**Les outils Python design-time** (`veaf-tools.exe`) manipulent les fichiers `.miz` : injection de scripts, configuration météo, gestion des waypoints et presets radio.

---

## Démarrage rapide

| Je suis… | Je veux… | Commencer ici |
|----------|----------|---------------|
| **Joueur / Pilote** | Utiliser les fonctionnalités VEAF en vol (spawn, CAS, assets) | [Guide Pilote](pilot/README.md) |
| **Créateur de missions** | Intégrer VEAF dans mes missions DCS | [Guide Créateur de missions](mission-maker/README.md) |
| **Développeur** | Contribuer au code source VEAF | [Guide Développeur](developer/README.md) |

---

## Principe de fonctionnement

```mermaid
flowchart LR
    A["Votre mission .miz"] -->|veaf-tools inject| B["Mission + scripts VEAF"]
    B -->|DCS charge| C["34 modules Lua actifs en jeu"]
    C -->|Les joueurs utilisent| D["Marqueurs F10 · Menus radio"]
```

1. **Design time** — Vous configurez les modules à charger dans `veaf-mission.yaml` et construisez avec `veaf-tools.exe`
2. **Runtime** — DCS exécute le framework Lua VEAF ; les joueurs interagissent via F10

---

## Références

| Document | Contenu |
|----------|---------|
| [Référence API Lua](LUA_API_REFERENCE.md) | API publique complète des 34 modules runtime |
| [Référence CLI des outils](TOOLS_REFERENCE.md) | Commandes et options de `veaf-tools.exe` |
| [Feuille de route](ROADMAP.md) | Fonctionnalités prévues et limitations connues |

---

## Liens

- **Source** : [github.com/VEAF/VEAF-Mission-Creation-Tools](https://github.com/VEAF/VEAF-Mission-Creation-Tools)
- **Communauté** : [Discord VEAF](https://www.veaf.org/discord)
- **Licence** : [MIT](../LICENSE.md)
