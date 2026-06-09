# VEAF Mission Creation Tools — v6.4.0

**Version de consolidation** — unification de la configuration `mission.yaml`,
internationalisation complète, refonte de la documentation et nombreuses
corrections de la conversion v5→v6.

Un grand merci à **Tripack** pour ses contributions et ses retours qui ont
nourri la qualité de cette version.

---

## ⚠️ Migrations à effectuer

### `versions.yaml` remplace `missions.yaml`

L'étape *weather* du build utilise désormais **exclusivement** `src/versions.yaml`.
Le nom `missions.yaml` n'est plus reconnu. **Renommez votre fichier
`src/missions.yaml` en `src/versions.yaml`** avant de relancer un build.

### Syntaxe `mission.yaml` unifiée

Les sections `lua_modules:` et `community_scripts:` fusionnent dans un bloc
**`modules:`** unique. Autres changements :

- les modules obligatoires s'écrivent `MODULE:` (valeur nulle) au lieu de `MODULE: {}` ;
- la clé `enable:` devient `enabled:` ;
- les listes en bloc remplacent la notation `[...]` ;
- un en-tête aide-mémoire de syntaxe YAML est ajouté aux fichiers générés.

> Les anciennes clés restent acceptées avec un avertissement de dépréciation —
> mais il est recommandé de migrer vers la nouvelle syntaxe.

---

## Nouveautés

### Validation des fréquences radio DCS

L'injection des presets vérifie maintenant chaque fréquence contre les
capacités matérielles réelles de l'avion **au moment du build**. Une fréquence
invalide (par ex. 284 MHz sur un MiG-19P ou une Gazelle M) déclenche un
avertissement *avant* que DCS ne la rejette au chargement de la mission.

Une table de référence lisible des plages de fréquences valides pour les
**85 avions pilotables de DCS** est fournie dans
`doc/mission-maker/dcs-radio-specs.md`.

### Injection automatique de `dcs-bridge.lua`

Nouvelle section `dcs_bridge` dans `mission.yaml` : injecte `dcs-bridge.lua`
comme premier trigger DO SCRIPT FILE de la mission. Si `lua_path` est absent,
le fichier est téléchargé automatiquement depuis GitHub (`VEAF/VEAF-dcs-bridge`).

### Activation fine des scripts communautaires

La section `community_scripts:` (intégrée au nouveau bloc `modules:`) permet
d'activer ou désactiver individuellement les scripts Lua communautaires
(MIST, CTLD, CSAR…). En l'absence de cette section, tous les scripts restent actifs.

### Affichage console épuré

La sortie des outils en ligne de commande est désormais « décluttée » : les
messages de progression de faible importance défilent sur une seule ligne
réécrite, tandis que les lignes techniques permanentes et les en-têtes d'étape
restent affichés. Chaque étape du build se termine par une ligne de résultat
concise (« injected presets into 127 aircraft », « created 6 weather
variants »…), si bien qu'un compteur à `0` signale immédiatement un problème de
configuration. `--verbose` rétablit l'affichage classique ligne par ligne ; le
fichier de log complet reste inchangé.

### Internationalisation complète

Tous les messages des outils (build, injecteurs de presets et waypoints,
validateur de fréquences, convertisseur v5…) sont désormais traduits en
français — plus aucun texte anglais en dur dans les logs en locale française.

### Profil de coloration Klogg

Un profil de mise en évidence des logs DCS est fourni dans
`tools/klogg/veaf.conf` pour faciliter l'analyse des journaux.

---

## Conversion v5 → v6 (`convert-v5`)

De nombreuses améliorations de la conversion automatique des missions v5 :

- **Résolution des dépendances** : activer un module (par ex. `CASMISSION`)
  active automatiquement les modules requis (`GROUNDAI`, `SPAWN` et leurs
  dépendances transitives). Le fichier généré reflète fidèlement ce qui
  s'exécutera ; le rapport de conversion liste les modules auto-activés.
- **Modules triés par catégorie** (Infrastructure → Core → Features → Combat →
  External) ; les modules optionnels sans configuration utilisent le raccourci
  `MODULE: true`.
- **Presets radio par avion** extraits depuis `radioSettings` : les warbirds
  (par ex. Bf-109K-4) sont assignés à `{coalition}_warbird`, les avions à VHF
  primaire (I-16, Spitfire) à un nouveau preset `{coalition}_vhf_primary`.
- **Briefings multi-lignes** en concaténation Lua (`"ligne1\n" .. "ligne2\n"`)
  désormais entièrement extraits et convertis en blocs YAML lisibles.
- **Commentaires localisés** : les utilisateurs francophones voient des
  commentaires en français dans le `mission.yaml` généré.
- `global_log_level` par défaut à `info` (au lieu de `debug`).
- La commande accepte d'être appelée sans argument (répertoire courant par défaut).

---

## Corrections notables

- **`presets inject`** : les clés `presets_assignments` acceptent désormais des
  motifs regex (`A[-]10C.*`, `FW[-]190.*`) — correspondance exacte prioritaire,
  puis motif, puis repli `all`. Les avertissements de fréquence sont regroupés
  par type d'avion.
- **`aircraft-groups inject` (mode `add`)** : les groupes dont le nom existe déjà
  sont ignorés au lieu d'être dupliqués — évite un crash DCS sur les FA-18C/F-16C
  privés de `datalinks` après une conversion v5→v6.
- **Lua** : gardes nil-safe ajoutées dans `veafGrass`, `veafSpawnGround` et
  `veafSpawnEffects` autour de `ctld.builtFOBS` / `logisticUnits` / `beaconCount`
  — plus de crash quand CTLD n'est pas chargé.
- **`veafRadio`** : l'absence du fichier de config SRS n'émet plus d'avertissement
  (passé en `debug`).
- **`veaf-tools-updater`** : URL de documentation corrigée lors de la première
  installation.

---

## Documentation

- **Refonte bilingue (FR/EN)** : guide pilote réécrit (dédupliqué, accessible,
  jargon expliqué) ; exemple `mission.yaml` mis à jour vers le bloc `modules:`
  unifié ; diagrammes mermaid ajoutés (menu radio F10, pipeline de build,
  migration v5→v6).
- **Parité FR/EN** des grandes références : `LUA_API_REFERENCE`,
  `TOOLS_REFERENCE` et `dcs-radio-specs`.
- Page française `veafInterpreter` créée (corrige un lien de navigation cassé)
  et liens brisés de `GUIDE.fr.md` réparés.

---

*VEAF Mission Creation Tools est un projet communautaire open-source.
Contributions et retours bienvenus sur
[GitHub](https://github.com/VEAF/VEAF-Mission-Creation-Tools).*
