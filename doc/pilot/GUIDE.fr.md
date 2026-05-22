# Guide du pilote — VEAF Mission Creation Tools

Ce guide s'adresse aux joueurs qui volent dans des missions utilisant le framework de scripts VEAF. Aucune connaissance technique n'est requise.

---

## Table des matières

1. [Qu'est-ce que VEAF MCT ?](#quest-ce-que-veaf-mct)
2. [Reconnaître une mission VEAF](#reconnaître-une-mission-veaf)
3. [Menu radio F10](#menu-radio-f10)
4. [Commandes de marqueur](#commandes-de-marqueur)
5. [Ressources — Ravitailleurs, AWACS, Porte-avions](#ressources)
6. [Missions et zones de combat](#missions-et-zones-de-combat)
7. [Entraînement CAS](#entraînement-cas)
8. [Sécurité et permissions](#sécurité-et-permissions)
9. [Conseils par rôle d'appareil](#conseils-par-rôle-dappareil)
10. [FAQ](#faq)
11. [Communauté et support](#communauté-et-support)

---

## Qu'est-ce que VEAF MCT

VEAF Mission Creation Tools est un framework de scripts Lua qui rend les missions DCS World dynamiques et interactives. Au lieu d'un scénario statique, il est possible de :

- Faire apparaître des unités ennemies à la demande via des marqueurs sur la carte ou le menu radio
- Créer des zones d'entraînement CAS avec un niveau de difficulté configurable
- Activer des missions de combat prédéfinies
- Gérer des ressources partagées (ravitailleurs, AWACS, porte-avions) via le menu F10
- Interagir avec l'environnement en temps réel

---

## Reconnaître une mission VEAF

Quand une mission utilise les scripts VEAF, il est possible d'observer :

- Des messages de démarrage dans le coin inférieur droit listant les modules VEAF chargés
- Un sous-menu **VEAF** sous **F10 → Autre**
- Des marqueurs sur la carte indiquant les trajectoires des ravitailleurs, les orbites AWACS ou les positions des zones de combat

---

## Menu radio F10

Toutes les fonctionnalités VEAF MCT sont accessibles via **F10 → Autre → VEAF**.

### Structure typique du menu

```
F10 → Autre → VEAF
├── Ressources
│   ├── Ravitailleurs
│   │   └── [Nom du ravitailleur] → Infos / Réapparition
│   ├── AWACS
│   │   └── [Nom de l'AWACS] → Infos / Réapparition
│   └── Porte-avions
│       └── [Nom du porte-avions] → Infos / Commencer récupération / Arrêter récupération
├── Mission CAS
│   ├── Générer
│   ├── Fumée
│   ├── Fusée éclairante
│   ├── Passer
│   ├── Infos
│   └── Nettoyer
├── Zones de combat
│   └── [Nom de la zone] → Activer / Désactiver / Infos / Fumée / Fusée éclairante
├── Missions
│   └── [Nom de la mission] → Activer / Désactiver / Infos
└── Aide
```

La structure exacte dépend de ce que le créateur de mission a activé.

---

## Commandes de marqueur

Placer un marqueur sur la carte F10 (clic droit → Ajouter marqueur), saisir une commande dans le champ texte, puis confirmer. VEAF MCT intercepte le marqueur, exécute la commande et supprime le marqueur.

> Sur les serveurs multijoueurs, certaines commandes nécessitent un mot de passe. Voir [Sécurité](#sécurité-et-permissions).

### Aliases (raccourcis) — La méthode recommandée

Les aliases commencent par `-` et sont le moyen le plus simple de faire apparaître des unités. Ils sont prédéfinis par le créateur de mission et correspondent à des commandes complètes en arrière-plan.

#### Aliases de défense aérienne courants

| Alias | Ce qui apparaît |
|-------|-----------------|
| `-sa2` | Batterie SA-2 Guideline (S-75) |
| `-sa6` | Batterie SA-6 Gainful (2K12 Kub) |
| `-sa10` | Batterie SA-10 Grumble (S-300) |
| `-sa11` | Batterie SA-11 Gadfly (9K37 Buk) |
| `-sa15` | Véhicule SA-15 Gauntlet (Tor) |
| `-sa22` | Véhicule SA-22 Greyhound (Pantsir-S1) |
| `-shilka` | AAA ZSU-23-4 Shilka |
| `-manpads` | Escouade MANPAD |
| `-samLR` | Batterie SAM longue portée aléatoire |
| `-samSR` | Batterie SAM courte portée aléatoire |

#### Aliases de véhicules/navires courants

| Alias | Ce qui apparaît |
|-------|-----------------|
| `-burke` | Destroyer USS Arleigh Burke IIa |
| `-ticonderoga` | Croiseur Ticonderoga |
| `-mortar` | Équipe de mortiers |
| `-arty` | Batterie d'artillerie M-109 |
| `-mlrs` | Batterie de roquettes MLRS |
| `-attack_convoy_red` | Convoi d'attaque rouge |

#### Aliases utilitaires

| Alias | Ce que ça fait |
|-------|----------------|
| `-point Nom` | Nomme un point sur la carte |
| `-destroy` | Détruit les unités dans un rayon de 100 m |
| `-login MOT_DE_PASSE` | S'authentifie pour les commandes restreintes |
| `-logout` | Verrouille le système |

> **Astuce :** Les créateurs de missions peuvent définir des aliases personnalisés. Demandez à l'administrateur de votre serveur la liste complète.

### Commandes brutes (avancé)

Pour tout ce qui n'est pas couvert par un alias, vous pouvez utiliser la syntaxe complète des commandes VEAF. Ces commandes commencent par `_`.

#### Faire apparaître une unité : `_spawn unit`

```
_spawn unit, name F-16C
_spawn unit, name T-80, group 4, hdg 270
_spawn unit, name SA-6
```

Options courantes :

| Option | Description | Exemple |
|--------|-------------|---------|
| `name [TYPE]` | Type d'unité DCS (obligatoire) | `name F-16C` |
| `group [N]` | Nombre d'unités dans le groupe | `group 4` |
| `hdg [DEG]` | Cap initial en degrés | `hdg 270` |
| `alt [FT]` | Altitude en pieds (aéronefs) | `alt 15000` |
| `speed [KT]` | Vitesse en nœuds | `speed 450` |
| `side [blue/red]` | Coalition imposée | `side red` |

#### Faire apparaître un groupe prédéfini : `_spawn group`

```
_spawn group, name CAP-2
_spawn group, name RED-SAM-SITE, hdg 180
```

Les groupes doivent être définis dans la configuration de la mission par le créateur.

#### Faire apparaître une patrouille CAP : `_spawn cap`

```
_spawn cap, name Su-27, alt 25000, capradius 20000
```

#### Fumée / fusées éclairantes / explosions

```
_spawn smoke, color red
_spawn flare, power 1000000, shells 5
_spawn bomb, power 500, shells 3
```

### Commande CAS

```
_cas
_cas, size 3, defense 2, armor 3
```

Options : `size [0-5]`, `defense [0-5]`, `armor [0-5]`, `side [blue/red]`.

### Authentification de sécurité

```
-login [MOT_DE_PASSE]
```

Accorde des permissions élevées temporaires. Requis sur certains serveurs avant d'utiliser les commandes de spawn avancées. Utilisez `-logout` pour verrouiller à nouveau.

---

## Ressources

### Ravitailleurs

Les informations du ravitailleur sont accessibles via **F10 → VEAF → Ressources → Ravitailleurs → [Nom] → Infos**.

Affichées : position, canal TACAN, fréquence radio, type.

Si le ravitailleur a été détruit, utiliser **Réapparition** pour le faire revenir (si le créateur de mission l'a autorisé).

### AWACS

Accéder à l'AWACS via **F10 → VEAF → Ressources → AWACS → [Nom] → Infos**.

Affiché : indicatif, fréquence, position.

### Porte-avions

| Action | Chemin du menu |
|--------|----------------|
| Obtenir les infos (BRC, TACAN, ICLS, radio) | Ressources → Porte-avions → [Nom] → Infos |
| Mettre le porte-avions face au vent pour la récupération | Ressources → Porte-avions → [Nom] → Commencer récupération |
| Reprendre la navigation normale | Ressources → Porte-avions → [Nom] → Arrêter récupération |

Les opérations expirent automatiquement après 45 minutes.

---

## Missions et zones de combat

### Zones de combat

Zones prédéfinies par le créateur de mission, activables à la demande.

| Action | Chemin du menu |
|--------|----------------|
| Lister les zones disponibles | Zones de combat |
| Activer une zone | Zones de combat → [Zone] → Activer |
| Consulter le statut de la zone | Zones de combat → [Zone] → Infos |
| Marquer la zone avec de la fumée | Zones de combat → [Zone] → Fumée |
| Désactiver / nettoyer | Zones de combat → [Zone] → Désactiver |

Quand une zone est activée, des unités ennemies apparaissent. Quand tous les ennemis sont détruits, la zone se complète et peut être rejouée.

### Missions scriptées

Scénarios plus complexes avec objectifs et suivi.

| Action | Chemin du menu |
|--------|----------------|
| Lister les missions | Missions |
| Activer | Missions → [Mission] → Activer |
| Lire le statut / les objectifs | Missions → [Mission] → Infos |
| Abandonner | Missions → [Mission] → Désactiver |

---

## Entraînement CAS

Le générateur CAS crée une zone cible avec des packages de menaces configurables.

**Procédure :**

1. **Générer** — F10 → Mission CAS → Générer (optionnellement avec des paramètres via marqueur `_cas, size 3, defense 2`)
2. **Marquer la zone** — F10 → Mission CAS → Fumée ou Fusée éclairante (délai de 3 minutes entre les marques)
3. **Obtenir les infos** — F10 → Mission CAS → Infos (position, composition en unités, statut)
4. **Engager** — Attaquer les cibles marquées
5. **Avancer** — La zone passe automatiquement à la suivante quand toutes les unités sont détruites, ou utiliser **Passer**
6. **Nettoyer** — F10 → Mission CAS → Nettoyer supprime toutes les unités restantes

**Guide de difficulté :**

| Niveau | Composition typique | Pour |
|--------|---------------------|------|
| 0 | Infanterie, jeeps, sans AA | Débutants |
| 1 | Véhicules légers, MANPADS | Facile |
| 2 | APC, AAA légère | Intermédiaire |
| 3 | IFV, AAA moyenne + SHORAD | Avancé |
| 4 | Chars lourds, ZSU + SA-9 | Difficile |
| 5 | Blindés lourds, SAM | Expert |

---

## Sécurité et permissions

Sur les serveurs multijoueurs, le créateur de mission peut restreindre certaines commandes :

| Niveau | Qui peut utiliser |
|--------|------------------|
| Public | Tous les joueurs — infos ressources, activation zones de combat, fumée/fusée |
| Pilotes | Joueurs non spectateurs |
| Admin | Administrateurs serveur |

Pour s'authentifier en tant qu'admin :

```
_auth [MOT_DE_PASSE]
```

Après authentification, les droits élevés sont valables pendant la durée configurée (par défaut : 10 minutes). Le mot de passe est défini par le créateur de mission ou l'admin serveur.

---

## Conseils par rôle d'appareil

### Chasseurs (F-16C, F/A-18C, F-15C, Su-27…)

- Utiliser l'AWACS pour obtenir des vecteurs de menace avant d'engager
- Faire apparaître une CAP ennemie avec `-cap Su-27` pour un scénario d'interception réaliste
- Activer une mission d'interception prédéfinie via le menu F10

### Avions d'attaque (A-10C, Su-25, F/A-18C…)

- Commencer l'entraînement CAS au niveau de difficulté 1–2
- Utiliser **Fumée** pour marquer la cible avant d'attaquer
- Augmenter progressivement la difficulté (le niveau 3+ contient des menaces nécessitant du SEAD)

### Hélicoptères (AH-64D, Ka-50, Mi-24…)

- Maintenir la difficulté à 0–2 (AA minimale)
- Utiliser `_spawn unit, name BTR-80, group 5` pour des cibles APC dispersées
- Exploiter le masquage de terrain pour approcher sous le radar AA

### Transports (C-130, Mi-8, UH-1H…)

- Faire apparaître un FARP comme destination : `-farp FARP Alpha`
- Utiliser l'intégration CTLD (si activée) pour des missions de transport de troupes/cargo

---

## FAQ

**Q : Comment savoir si une mission utilise VEAF ?**
Chercher le sous-menu VEAF sous F10 → Autre au démarrage de la mission.

**Q : Pourquoi mes marqueurs ne fonctionnent-ils pas ?**
Vérifier la syntaxe de la commande. Sur certains serveurs, il faut d'abord s'authentifier avec `_auth [MOT_DE_PASSE]`.

**Q : Quels noms de types d'unités DCS puis-je utiliser ?**
Les noms DCS standard : `F-16C`, `Su-27`, `T-80`, `M1 Abrams`, `SA-6`, etc. Ils sont sensibles à la casse.

**Q : Les unités apparues ont disparu ?**
Certaines missions imposent une limite de portée (~40–50 NM). C'est un comportement normal.

**Q : Comment réinitialiser une session CAS ?**
F10 → Mission CAS → Nettoyer, puis Générer à nouveau.

**Q : Peut-on faire apparaître des unités amies ?**
Oui, ajouter `side blue` à n'importe quelle commande de spawn.

---

## Communauté et support

- [Discord VEAF](https://www.veaf.org/discord) — aide en temps réel, canal `#support`
- [Site VEAF](https://www.veaf.org)
- [GitHub](https://github.com/VEAF/VEAF-Mission-Creation-Tools)

---

*Voir aussi : [Guide du créateur de mission](../mission-maker/GUIDE.md) pour la référence complète du créateur.*
