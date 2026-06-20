# Adopter une mission Foothold sur la chaîne v6 (la « moulinette »)

> **Foothold** est une mission communautaire (par *Lekaa*) qui évolue plusieurs
> fois par mois. Ce guide décrit la **moulinette** : une procédure reproductible
> que n'importe quel membre VEAF peut relancer à chaque nouvelle version upstream,
> pour produire les `.miz` VEAF (Modern **et** Cold-War) depuis un seul dossier de
> mission.
>
> Architecture : **code générique, connaissance auteur en donnée** (voir
> [ADR 0007](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/docs/adr/0007-third-party-mission-adoption.md))
> et **config amont intacte + override partiel validé lexicalement** (voir
> [ADR 0008](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/docs/adr/0008-foothold-config-override.md)).
> Le détail de chaque commande est dans [CONVERT_OTHER](CONVERT_OTHER.md) et la
> [référence mission.yaml](../MISSION_YAML_REFERENCE.md).

## Prérequis

- `veaf-tools` (ou `veaf-tools.exe`) à jour.
- Le `.miz` upstream Foothold de la carte visée (p. ex. Caucasus).
- Le profil de conversion **`foothold`** (livré avec les outils).

## Vue d'ensemble

```
.miz upstream  ──(1) convert-other --profile foothold──►  dossier mission v6
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
veaf-tools convert-other <Foothold_upstream.miz> <dossier-mission> --profile foothold
```

`convert-other` extrait le `.miz`, détecte les scripts chargés par les triggers
natifs (dans l'ordre), et génère un `mission.yaml` avec :

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
Le profil `foothold` **scaffolde déjà** ces désactivages **dans le bloc `modules:`**
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
à la prochaine version). Chaque clé est **validée lexicalement** contre le code
injecté : une faute de frappe fait échouer `validate` et le build.

```yaml
config_override:
  target: "Foothold Config.lua"
  values:
    Era: Modern          # défaut ; surchargé par variante ci-dessous
    AutoRestart: false
```

### c. Variantes Modern / Cold-War

L'ère Foothold est pilotée par le global `Era` (`"Modern"` ou `"Coldwar"`) —
c'est une **différence de config**. On émet donc les deux `.miz` en un seul build
via [`build_variants:`](../MISSION_YAML_REFERENCE.md) :

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

## 3. Valider

```bash
veaf-tools validate <dossier-mission>
```

Vérifie la syntaxe, la sémantique des modules, l'existence des `custom_scripts`,
les incompatibilités du profil, et que **chaque segment de clé `config_override`
existe** dans le code Foothold injecté.

## 4. Construire les deux variantes

```bash
veaf-tools build <dossier-mission>
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

Quand Foothold sort une nouvelle version, ré-importez-la **dans le même dossier** :

```bash
veaf-tools convert-other <nouveau_upstream.miz> <dossier-mission> --profile foothold --update
```

`--update` rafraîchit les scripts tiers et la base de mission, **préserve votre
`mission.yaml` réglé**, normalise les noms versionnés (`Moose_<date>.lua` →
`Moose.lua`), et **rapporte les scripts ajoutés / mis à jour / retirés** en amont.
Relisez le rapport, réconciliez `custom_scripts:` / `strip_native_triggers:` au
besoin, puis revalidez et reconstruisez. Voir [CONVERT_OTHER](CONVERT_OTHER.md).
