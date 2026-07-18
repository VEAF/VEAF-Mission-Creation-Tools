# veafServerHook — Hook serveur VEAF

**Fichier:** `VEAF-Server-hook.lua` | **Version:** 2.7.x | **Emplacement:** `Saved Games/<serveur>/Scripts/Hooks/`

---

## Objectif

Hook DCS (environnement GameGUI) tournant sur un serveur dédié. Il :

- écoute le chat et exécute les commandes serveur VEAF (`/secu login`, `/send`, `/pause`…),
  relayées à la mission via `veafRemote` / `veafSecurity` ;
- charge la liste des pilotes (niveaux de permission par UCID) ;
- redémarre optionnellement le serveur quand il est inactif (opt-in) ;
- pousse optionnellement de la télémétrie vers un serveur d'API (opt-in).

> Ce n'est **pas** un module de mission : il n'est pas injecté dans le `.miz`, il se dépose
> dans le dossier `Scripts/Hooks/` du serveur et se charge au démarrage de DCS.

---

## Installation

1. Déposer `VEAF-Server-hook.lua` dans `Saved Games/<serveur>/Scripts/Hooks/`.
2. Déposer `veaf-pilots.txt` à côté (ou dans un dossier partagé, voir `pilotsDir`) et l'éditer.
3. Ajouter un `VEAF-specific-server-hook.lua` dans le même dossier pour la configuration
   propre au serveur (voir ci-dessous).
4. **Redémarrer le serveur** : le hook est chargé au démarrage de DCS ; recharger la mission
   ne suffit pas.

Ordre de chargement DCS : les fichiers de `Scripts/Hooks/` sont chargés par ordre alphabétique.
`VEAF-Server-hook.lua` se charge **avant** `VEAF-specific-server-hook.lua`, qui peut donc
surcharger les réglages ci-dessous avant le premier événement.

---

## Configuration (via le specific-hook)

Le `VEAF-Server-hook.lua` est générique : ses valeurs par défaut conviennent à un serveur
simple. Tout ce qui est propre à un serveur va dans `VEAF-specific-server-hook.lua` :

```lua
veafServerHook.enableAutoRestart     = false  -- watchdog de redémarrage + commandes /restart /restartnow /halt
veafServerHook.enableBufferingSocket = false  -- télémétrie vers un serveur d'API (module natif BufferingSocket)
veafServerHook.pilotsDir             = nil     -- dossier du fichier pilotes ; défaut = dossier du hook
```

- **`enableAutoRestart`** (défaut `false`) : active le redémarrage automatique du serveur
  inactif et les commandes chat `restart` / `restartnow` / `halt`. À laisser désactivé si les
  redémarrages sont gérés par un outil externe (ex. DCSServerBot).
- **`enableBufferingSocket`** (défaut `false`) : active la télémétrie. Le module natif
  `BufferingSocket` est chargé de façon défensive : s'il est absent, la télémétrie est
  désactivée automatiquement et le hook continue de fonctionner (aucun crash).
- **`pilotsDir`** (défaut `nil` → dossier du hook) : permet de mutualiser un `veaf-pilots.txt`
  partagé par plusieurs serveurs (p. ex. la racine `Saved Games/`).

Le specific-hook porte aussi `serverName` et `serverBotChannel` (injectés dans la mission).

---

## Fichier des pilotes (`veaf-pilots.txt`)

Table Lua indexée par UCID, avec un niveau de permission par pilote :

```lua
pilots =
{
  ["<ucid>"] = { name = "Nom", level = 99 },
  ...
}
```

Grille des niveaux (croissant) :

| Niveau | Peut… |
|-------:|-------|
| 0 | envoyer des messages (`/send`) |
| 1 | déverrouiller les commandes (`/secu login`), spawn, missions/zones |
| 10 | `/restart`, `/halt` (si `enableAutoRestart`) |
| 30 | `/restartnow` |
| 50 | `/haltnow` |
| 90 | `/code` (exécution de code arbitraire) |
| 99 | administrateur |

---

## Mise à jour

Remplacer `VEAF-Server-hook.lua` par la nouvelle version, conserver le
`VEAF-specific-server-hook.lua` et le `veaf-pilots.txt` existants, puis **redémarrer le
serveur**.
