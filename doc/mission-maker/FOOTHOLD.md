# Adopter une mission Foothold sur la chaîne v6 (la « moulinette »)

> **Foothold** est une mission communautaire (par *Lekaa*) qui évolue plusieurs
> fois par mois. Ce guide décrit la **moulinette** : une procédure reproductible
> que n'importe quel membre VEAF peut relancer à chaque nouvelle version upstream,
> pour produire les `.miz` VEAF (Modern **et** Cold-War) depuis un seul dossier de
> mission.
>
> Architecture : **code générique, connaissance auteur en donnée** (voir
> [ADR 0007](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0007-third-party-mission-adoption.md))
> et **config amont intacte + override partiel validé lexicalement** (voir
> [ADR 0008](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0008-foothold-config-override.md)).
> Le détail de chaque commande est dans [CONVERT_OTHER](CONVERT_OTHER.md) et la
> [référence mission.yaml](../MISSION_YAML_REFERENCE.md).

## Prérequis

- `veaf-tools` (ou `veaf-tools.exe`) à jour.
- L'archive de release Foothold de la carte visée (p. ex. Caucasus) — voir ci-dessous.
- Le profil de conversion **`foothold`** (livré avec les outils).

### Où récupérer l'upstream

Foothold est publié sur GitHub : **[leka1986/Lekas-Foothold](https://github.com/leka1986/Lekas-Foothold)**,
onglet *Releases*. Une release fournit un `.zip` par carte (Caucasus, Persian Gulf, Sinaï,
Syrie, Cold War Germany, Kola, Irak, Afghanistan, Normandie WWII), chacun contenant :

| Fichier | Ce qu'on en fait |
|---|---|
| `Foothold_<carte>_<version>.miz` | **c'est l'entrée de la moulinette** |
| `Foothold Config Manager <version>.exe` | ignoré — voir [la mise en garde](#external-config) |
| `Foothold_Manual_v<x>.pdf` | documentation amont, utile à lire |
| `Getting Started.url` | raccourci vidéo |

Passez le `.zip` directement à `convert-other` : il adopte le `.miz` qu'il contient et
ignore le reste. Pas besoin de dézipper à la main.

> **Les dix cartes d'un coup.** Une release contient une archive par carte. Depuis un clone du
> dépôt, [`tools/Convert-FootholdBatch.ps1`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/tools/Convert-FootholdBatch.ps1)
> les adopte toutes en une passe, en choisissant le bon profil pour chacune (il regarde dans
> l'archive, pas son nom) :
>
> ```powershell
> .\tools\Convert-FootholdBatch.ps1 -InputFolder <dossier-des-zips> -OutputFolder <dossier-missions> -Validate
> ```
>
> Aux releases suivantes, ajoutez `-Update` : les scripts sont rafraîchis et chaque
> `mission.yaml` réglé est préservé. Comptez environ une minute par mission.

### Quel profil pour quelle carte

| Carte | Profil |
|---|---|
| Caucasus, Persian Gulf, Sinaï, Syrie, Cold War Germany, Kola, Irak, Afghanistan | `foothold` |
| **Normandie WWII** | `foothold-ww2` |

La Normandie est une autre famille, d'où son profil : son fichier de config s'appelle
`Foothold Config WW2.lua`, il n'a **pas** de global `Era` (la Seconde Guerre mondiale n'a pas
de sélecteur d'ère) ni de `StartNormal`, et la mission **n'embarque aucune CTLD Foothold** —
la CTLD VEAF n'y est donc pas incompatible (elle reste OFF par défaut, mais vous pouvez
l'activer).

Si vous adoptez la Normandie avec le profil `foothold`, `validate` vous arrête : le
`config_override` viserait `Foothold Config.lua`, absent de cette mission, et l'override
serait alors chargé **en dernier** — après le script de setup qui a déjà lu les réglages —
donc sans aucun effet.

## Vue d'ensemble

```
.zip release   ──(1) convert-other --profile foothold──►  dossier mission v6
                                                          │
                              (2) réglage mission.yaml ◄──┘
                                                          │
                          (3) validate  ──►  (4) build  ──►  <base>_MODERN.miz
                                                              <base>_COLD_WAR.miz
                                                          │
                                          (5) test DCS ◄──┘

Nouvelle version Lekaa ──► convert-other --update ──► (re)validate ──► build
```

## 1. Initialiser (adopter)

```bash
veaf-tools convert convert-other Foothold_CA_4.4.1_Multi_Language_Coldwar-Modern-Vietnam.zip <dossier-mission> --profile foothold
```

`convert-other` extrait le `.miz` (de l'archive si besoin), détecte les scripts chargés par
les triggers natifs (dans l'ordre), et génère un `mission.yaml` avec :

- un bloc **`custom_scripts:` ordonné** (Moose, zoneCommander, Foothold Config,
  setup, CTLD Foothold, Splash, AIEN, EWRS… — l'ordre de chargement d'origine) ;
- un **`strip_native_triggers:`** listant les triggers de chargement natifs (le
  build les supprime pour éviter un double chargement) ;
- les **modules VEAF** du profil (RADIO, SPAWN, WEATHER, SHORTCUTS, SECURITY,
  REMOTE) ;
- un marqueur `conversion_profile: foothold` (le build/validate refusent un module
  incompatible — Foothold embarque sa propre CTLD, donc la CTLD VEAF reste OFF) ;
- un scaffold **`config_override:`** commenté ciblant `Foothold Config.lua`.

## 2. Régler le `mission.yaml`

Trois ajustements, tous **config-only** (on ne touche jamais aux scripts upstream) :

### a. Community scripts VEAF (déjà coupés par le profil)

Foothold embarque **ses propres** bibliothèques (Moose, sa CTLD, AIEN, EWRS,
Splash…) en `custom_scripts`. Les community scripts VEAF doivent donc rester OFF —
sinon, par exemple, l'AIEN de VEAF écrase celui de Foothold et la mission plante.
Le profil `foothold` **scaffolde déjà** ces désactivations **dans le bloc `modules:`**
(et pas dans un bloc `community_scripts:` séparé, qui serait *ignoré* dès que
`modules:` existe) — rien à faire, vérifiez juste leur présence :

```yaml
modules:
  # … modules VEAF …
  # ── Community scripts OFF ──
  stts: false
  ctld: false
  aien: false
  csar: false
  hercules: false
  skynet: false
  tum: false
```

> MiST n'est pas dans la liste : c'est une dépendance VEAF obligatoire (toujours
> chargée).

### b. Override partiel de la config Foothold

Décommentez le bloc `config_override:` et n'y mettez **que** les globals que vous
changez (le reste de `Foothold Config.lua` reste intact et se met à jour tout seul
à la prochaine version). Deux contrôles au `validate` :

- chaque clé est **validée lexicalement** contre le code injecté — une faute de frappe ou un
  renommage amont fait échouer `validate` et le build ;
- le `target` doit **désigner un script de la mission**. Sinon l'override serait chargé en
  dernier, après le script de setup qui a déjà lu les réglages, et n'aurait donc aucun effet —
  une panne silencieuse, désormais bloquée.

```yaml
config_override:
  target: "Foothold Config.lua"
  values:
    Era: Modern          # défaut ; surchargé par variante ci-dessous
    AutoRestart: false
    FootholdLocale: FR   # langue des messages Foothold à l'écran
```

`FootholdLocale` (config amont V1.0.9) accepte `EN`, `DE`, `FR`, `ES`, `RU`, `PT-BR`, `TR`,
`IT`, `zh-CN`, `zh-TW`. Elle ne force pas la langue du menu radio des joueurs, qui reste
réglable par chacun en jeu.

### ⚠️ La config externe du Config Manager (à ne pas installer) {#external-config}

Depuis la config V1.0.9, `Foothold Config.lua` **cherche un fichier de config externe** et,
s'il le trouve, l'applique par-dessus les valeurs embarquées dans le `.miz` :

```
<Saved Games>\DCS…\Missions\Saves\Foothold Config.lua
```

C'est le canal du **Foothold Config Manager** (l'exécutable livré dans l'archive) : son bouton
*Import MIZ Config* installe ce fichier. Conséquences à connaître :

- **notre `config_override` gagne quand même** : le `veaf-config-override.lua` généré est
  chargé *après* le script de config, donc il réassigne les globals en dernier —
  [ADR 0008](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0008-foothold-config-override.md)
  reste valable ;
- **mais** un tel fichier posé dans le `Saved Games` d'un serveur modifie **silencieusement**
  toutes les missions Foothold de cette instance, y compris les nôtres, pour tous les
  réglages que nous ne surchargeons pas explicitement ;
- Foothold affiche en plus un avertissement à l'écran (`FOOTHOLD_CONFIG_EXTERNAL_OUTDATED`)
  quand ce fichier externe est plus vieux que la config embarquée.

> **Donc : n'installez pas la config externe du Config Manager sur un serveur VEAF.** La
> configuration d'une mission VEAF vit dans son `mission.yaml`, versionnée avec le dossier de
> mission et validée au build — ce qu'un fichier dans `Saved Games` n'est pas. Le Config
> Manager reste utile hors ligne pour *explorer* les réglages disponibles et voir ce que
> chaque option fait.

### c. Variantes Modern / Cold-War

L'ère Foothold est pilotée par le global `Era`, qui accepte quatre valeurs — `"Modern"`,
`"Coldwar"`, `"Gulfwar"` (le nom de l'ère Cold-War côté Irak) et `"Vietnam"`. C'est une
**différence de config**, donc on émet plusieurs `.miz` en un seul build via
[`build_variants:`](../MISSION_YAML_REFERENCE.md) :

```yaml
mission:
  name: VEAF-Foothold-Caucasus

build_variants:
  - MODERN
  - COLD_WAR

profiles:
  MODERN:
    mission:
      era: MODERN
    config_override:
      values:
        Era: Modern
  COLD_WAR:
    mission:
      era: COLD_WAR
    config_override:
      values:
        Era: Coldwar
```

Le même schéma donne une variante Vietnam si on la veut (`Era: Vietnam`) : les missions
récentes de Lekaa embarquent les appareils et les armements de l'époque, sélectionnés par
`Era`. Sur la carte Irak, l'ère Cold-War s'appelle `Gulfwar`.

## 3. Valider

```bash
veaf-tools mission validate <dossier-mission>
```

Vérifie la syntaxe, la sémantique des modules, l'existence des `custom_scripts`,
les incompatibilités du profil, et que **chaque segment de clé `config_override`
existe** dans le code Foothold injecté.

## 4. Construire les deux variantes

```bash
veaf-tools mission build <dossier-mission>
```

Un seul build produit **deux** `.miz` : `…_MODERN.miz` et `…_COLD_WAR.miz`. Chaque
variante : config amont intacte → petit `veaf-config-override.lua` réassignant
`Era` (chargé entre la config et le setup) → triggers natifs supprimés →
`custom_scripts` chargés dans l'ordre déclaré → spawns/data VEAF injectés.

> Pour `--profile <X>` seul (une variante précise, sans suffixe) ou les options de
> build, voir la [référence mission.yaml](../MISSION_YAML_REFERENCE.md).

## 5. Tester dans DCS

Ouvrez chaque `.miz` dans DCS et vérifiez le comportement **iso-fonctionnel**
(menu radio VEAF présent, moteur Foothold opérationnel, équipements cohérents avec
l'ère). C'est l'étape de validation finale avant de publier le dossier mission.

## Mettre à jour (nouvelle version Lekaa)

Quand Foothold sort une nouvelle release, téléchargez la nouvelle archive et ré-importez-la
**dans le même dossier** :

```bash
veaf-tools convert convert-other <nouvelle_release.zip> <dossier-mission> --profile foothold --update
```

`--update` rafraîchit les scripts tiers et la base de mission, **préserve votre
`mission.yaml` réglé**, normalise les noms versionnés (`Moose_<date>.lua` → `Moose.lua`,
`Splash_Damage_<version>_leka.lua` → `Splash_Damage.lua`), et **rapporte les scripts
ajoutés / mis à jour / retirés** en amont. Relisez le rapport, réconciliez
`custom_scripts:` / `strip_native_triggers:` au besoin, puis revalidez et reconstruisez.
Voir [CONVERT_OTHER](CONVERT_OTHER.md).

> Surveillez dans le rapport l'apparition d'un **nouveau script** en amont : il n'est pas
> ajouté à `custom_scripts:` à votre place, justement parce que sa position dans l'ordre de
> chargement est une décision qui revient à un humain.
