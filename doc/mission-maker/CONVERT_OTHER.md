# `convert-other` — adopter une mission tierce sur la v6

`convert-other` adopte une mission `.miz` **tierce** (non-VEAF, p. ex. *Foothold*
de Lekaa) sur la chaîne d'outils v6. C'est le pendant de
[`convert-v5`](MIGRATION_GUIDE.md), qui migre une mission **VEAF v5** : ici la
mission n'a jamais été construite avec les outils VEAF, on l'**adopte**.

> Cette commande ne contient aucune connaissance propre à une mission donnée.
> Le savoir spécifique à une famille de missions (ordre des scripts, triggers à
> retirer, réglages à surcharger…) est porté par un *profil de conversion*
> Deux profils sont livrés avec l'outil : `foothold` et `foothold-ww2`. Voir l'ADR 0007.

## Usage

```bash
veaf-tools convert convert-other <mission.miz> <dossier-de-sortie>
```

Sans argument (dans un terminal interactif), la commande ouvre l'assistant TUI
et demande le `.miz` source puis le dossier de sortie.

### L'entrée peut être une archive de release

Les missions tierces sont souvent distribuées sous forme d'**archive `.zip`** plutôt que de
`.miz` nu — les assets Foothold de Lekaa contiennent la mission avec un exécutable de
gestion de configuration, le manuel et un raccourci. Passez l'archive que vous avez
téléchargée, `convert-other` adopte le `.miz` qu'elle contient :

```bash
veaf-tools convert convert-other Foothold_CA_4.4.1_Multi_Language_Coldwar-Modern-Vietnam.zip <dossier-de-sortie> --profile foothold
```

Seul le membre `.miz` est lu ; rien d'autre dans l'archive n'est écrit où que ce soit
(l'exécutable embarqué n'est jamais extrait, ni exécuté). L'archive doit contenir
**exactement un** `.miz` : s'il n'y en a aucun, ou plusieurs, la commande s'arrête et
nomme ce qu'elle a trouvé plutôt que de deviner quelle mission vous visiez.

| Argument / option | Rôle |
|-------------------|------|
| `INPUT_MIZ` | Chemin de la mission tierce à adopter : un `.miz`, ou une archive `.zip` en contenant exactement un |
| `OUTPUT_FOLDER` | Dossier de mission v6 à créer / compléter |
| `--force` | Écraser un `mission.yaml` existant (sinon il est laissé intact) |
| `--report-file` | Chemin du rapport Markdown (défaut `<sortie>/convert-other-report.md`) |
| `--profile` | Profil de conversion (nom fourni, p. ex. `foothold`, ou chemin vers un `.yaml`) |

## Profils de conversion

Sans `--profile`, le scaffold est générique (tier `minimal`). Avec un profil, la
connaissance propre à une famille de missions est appliquée — **données, pas code**
(voir [ADR 0007](../../docs/adr/0007-third-party-mission-adoption.md)). Le profil
`foothold` (livré) :

- **active les modules VEAF** que Foothold utilise (RADIO, SPAWN, WEATHER,
  SHORTCUTS, SECURITY, REMOTE) au lieu du tier `minimal` ;
- **normalise les noms versionnés** (`Moose_2026-06-14.lua` → `Moose.lua`,
  `Splash_Damage_3.4.1_leka.lua` → `Splash_Damage.lua`) pour que les chemins
  `custom_scripts:` restent stables entre versions de Lekaa. Le script de setup propre à
  chaque carte (`MA_Setup_CA.lua`, `footholdSyriaSetup.lua`, `kola_setup.lua`…) n'est
  **pas** normalisé : ces noms varient par carte, pas par version ;
- **inscrit un marqueur** `conversion_profile: foothold` dans le `mission.yaml` ;
- **pré-remplit un `config_override` commenté** ciblant `Foothold Config.lua` ;
- **déclare les modules incompatibles** (`CTLD` : Foothold embarque sa propre CTLD).
  Si un module incompatible est activé, **`veaf-tools mission validate` et le build
  échouent** — y compris si vous l'activez à la main plus tard.

```bash
veaf-tools convert convert-other <mission.miz> <dossier-de-sortie> --profile foothold
```

### Profils livrés

| Profil | Pour |
|--------|------|
| `foothold` | le Foothold de Lekaa sur Caucasus, Persian Gulf, Sinaï, Syrie, Cold War Germany, Kola, Irak, Afghanistan |
| `foothold-ww2` | le Foothold Normandie WWII — autre fichier de config (`Foothold Config WW2.lua`), pas de `Era`, et pas de CTLD Foothold, donc la CTLD VEAF n'y est *pas* incompatible |

Voir [FOOTHOLD](FOOTHOLD.md) pour la procédure complète à chaque version.

## Ce que fait la commande

1. **Extrait** le `.miz` dans le dossier de mission (les scripts atterrissent
   dans `src/scripts/`). Les copies tierces des scripts communautaires connus
   (CTLD, CSAR, AIEN…) sont **conservées** telles quelles (iso-fonctionnel), au
   lieu d'être remplacées par les versions VEAF.
2. **Détecte** les scripts chargés par les triggers natifs de la mission, dans
   leur **ordre de chargement** (ordre des triggers × ordre des actions).
3. **Génère** un `mission.yaml` *scaffold* :
   - un bloc `custom_scripts:` **ordonné** (l'ordre de chargement d'origine) ;
   - une liste `strip_native_triggers:` des triggers natifs de chargement
     détectés (par commentaire ou motif glob) — le **build les supprime**
     (trigrule + entrées `trig` + ressources `mapResource`) pour éviter un
     double chargement avec les `custom_scripts` réinjectés ;
   - un bloc `modules:` initialisé sur le **tier `minimal`** (infra + MIST +
     RADIO/SPAWN/SHORTCUTS/INTERPRETER, SECURITY commenté) : une base VEAF
     fonctionnelle d'emblée ; activez davantage au besoin.
4. **Émet** un rapport Markdown récapitulant les actions et les points à revoir.

## Surcharge partielle de la config

Une mission tierce comme Foothold embarque un gros fichier de configuration
maîtrisé par son auteur, que VEAF laisse **intact**. Pour changer quelques
réglages au déploiement (difficulté, camp de départ, redémarrage auto…) sans
réécrire ce fichier, remplissez le bloc `config_override:` que le *scaffold*
laisse commenté :

```yaml
config_override:
  target: "Foothold Config.lua"   # le script de config amont que vous surchargez
  values:
    CapDifficulty: medium         # global = valeur
    StartNormal: true
    AutoRestart: false
    Some.Nested.Global: 42        # chemin pointé → Some.Nested.Global = 42
```

Au build, ceci génère un petit `veaf-config-override.lua` qui **ne réaffecte que
les globals modifiés**, chargé **entre** la config amont intacte et le script de
*setup* (la config amont se met donc à jour sans réécriture sur une nouvelle
version Lekaa, et vos surcharges l'emportent). Les valeurs sont transmises
telles quelles — VEAF ne les interprète jamais ; la mission valide ses propres
valeurs au runtime.

Chaque clé de surcharge est **validée lexicalement** : chaque segment pointé doit
apparaître comme identifiant quelque part dans les scripts injectés
(`src/scripts/*.lua`). Un segment introuvable — une faute de frappe ou un global
renommé/supprimé en amont — **fait échouer `veaf-tools mission validate` et le build**,
transformant une dérive amont silencieuse en alerte au build. (Aucun Lua n'est
exécuté : la vérification est une recherche mot entier en Python pur.)

## Après la conversion

- Relisez le `mission.yaml` : activez les modules VEAF voulus, vérifiez l'ordre
  des `custom_scripts` et leurs dépendances.
- Construisez puis testez la mission dans DCS pour confirmer le comportement
  iso-fonctionnel.

## Mettre à jour vers un `.miz` upstream plus récent (`--update`)

Quand l'auteur tiers publie une nouvelle version (p. ex. une montée de version
Foothold de Lekaa), ré-importez-la dans votre dossier déjà adopté avec `--update` :

```bash
veaf-tools convert convert-other <nouveau-upstream.miz> <dossier-sortie> --profile foothold --update
```

Le nouvel upstream peut aussi être l'archive `.zip` de release — même règle, exactement un
`.miz` dedans.

En mode mise à jour, `convert-other` :

- **rafraîchit les scripts tiers** (`src/scripts/*.lua`) et la **base de mission**
  (`src/mission/**`) depuis le `.miz` frais — en écrasant les copies précédentes
  au lieu de garder les anciennes (une première adoption conserve les fichiers
  existants ; `--update` est l'interrupteur explicite « prends la nouvelle
  version ») ;
- **ré-applique la normalisation des noms versionnés** pour que les chemins
  `custom_scripts:` restent stables d'une version à l'autre (p. ex.
  `Moose_<nouvelle-date>.lua` → `Moose.lua`) ;
- **préserve votre `mission.yaml` réglé** — il n'est jamais régénéré, donc vos
  modules, votre `config_override` et vos `custom_scripts` survivent ;
- **rapporte les scripts ajoutés, mis à jour et retirés en amont** dans le rapport
  de conversion, pour que vous ajustiez `custom_scripts:` (et
  `strip_native_triggers:`) pour tout script nouveau ou disparu. Un script retiré
  en amont est signalé mais laissé sur disque — retirez-le de `custom_scripts:`
  vous-même s'il ne sert plus.

Relisez le rapport, réconciliez `custom_scripts:` / `strip_native_triggers:` avec
les scripts ajoutés/retirés, puis reconstruisez et testez dans DCS.
