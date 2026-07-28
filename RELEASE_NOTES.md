# VEAF Mission Creation Tools — 6.12.0

Trois chantiers dans cette version : les **zones de combat** deviennent symétriques (jouables
côté rouge, avec un menu radio propre à chaque camp), la **chaîne Foothold** encaisse les
releases de Lekaa telles qu'elles sont distribuées, et une série de **correctifs de fiabilité**
sur des choses qui semblaient marcher sans marcher — une mission que l'éditeur refusait
d'enregistrer, un mot de passe décoratif, une page de doc anglaise servant du français.

---

## ⚠️ À lire avant de mettre à jour

**Le menu F10 d'une zone de combat n'est plus proposé aux deux camps.** Il va désormais au camp
qui joue la zone : par défaut les **bleus**, puisque l'ennemi par défaut est rouge.

- Si tous les slots joueurs de vos missions sont bleus : **aucune différence**.
- Si vous avez des slots rouges qui doivent garder l'accès aux zones bleues (un arbitre, un
  Mission Master en slot rouge) : ajoutez `radio_menu_coalition: ALL` sur ces zones.

Le détail et le YAML exact sont dans la section **Migration** en fin de page.

---

## ⚔️ Les zones de combat se jouent des deux côtés

Jusqu'ici une zone de combat supposait que les joueurs étaient bleus et que les unités à
détruire étaient rouges. Ce n'était pas un réglage manquant, c'était une hypothèse inscrite en
dur à deux endroits : la zone se terminait quand il ne restait plus d'unité **rouge**, et le
rapport F10 annonçait les bleus comme « amis » et les rouges comme « ennemis ».

Conséquence : une zone dont les ennemis étaient bleus ne pouvait pas fonctionner. Elle ne
contenait aucune unité rouge, donc le surveillant comptait zéro ennemi dès sa première passe
(~1 min) et désactivait la zone aussitôt.

Le contournement qui circulait — `completable: false` — ne rendait pas la zone rouge : il
coupait simplement la fin automatique, et le rapport continuait d'appeler les ennemis bleus
« amis ».

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: "CZ-Kobuleti"
        enemy_coalition: BLUE   # les joueurs sont rouges, les bleus sont les ennemis
```

La condition de fin **et** les libellés amis/ennemis du rapport suivent ce réglage. Une zone
qui ne précise rien se comporte exactement comme avant.

### Chaque camp ne voit que ses zones

Le menu F10 d'une zone n'est pas qu'un affichage : c'est par lui qu'on **active** la zone,
qu'on tire la fumée, qu'on demande son état. Avec des zones rouges devenues possibles, chaque
camp pouvait déclencher les zones de l'autre.

Une zone propose donc maintenant son menu au camp qui la joue, et `radio_menu_coalition`
permet d'en décider autrement (`RED`, `BLUE`, ou `ALL` pour revenir au menu commun).

Le menu parent `COMBAT ZONES` reste, lui, visible par tout le monde : un groupe radio peut
contenir des zones des deux camps.

---

## 🏗️ Foothold : les releases s'adoptent telles qu'elles arrivent

Les missions Foothold de Lekaa ne se distribuent plus en `.miz` nu mais en **archive**, avec le
gestionnaire de configuration, le manuel et un raccourci. Chaque adoption commençait donc par
un dézippage manuel.

- **`convert-other` accepte l'archive** que vous avez téléchargée et adopte le `.miz` qu'elle
  contient. Seul ce membre est lu — l'exécutable fourni n'est jamais extrait, jamais lancé. Si
  l'archive contient zéro ou plusieurs `.miz`, la commande s'arrête et dit ce qu'elle a trouvé
  plutôt que de deviner.
- **Nouveau profil `foothold-ww2`** pour la Normandie WWII : c'est une autre famille (fichier
  de configuration différent, pas de variable `Era`, pas de CTLD Foothold). L'adopter avec le
  profil moderne produisait une surcharge embarquée, chargée… et sans effet.
- **`validate` refuse une `config_override.target` qui ne désigne aucun script injecté** —
  exactement le piège précédent : la surcharge était embarquée et silencieusement inopérante.
- **Adoption par lot des dix cartes** d'une release, en une passe, avec choix du profil **par
  contenu** (le script ouvre le `.miz` dans l'archive et cherche le fichier de configuration
  WWII, donc une future carte WWII nommée autrement se résout quand même). Éprouvé sur la vraie
  4.4.1 : 10/10 adoptées et validées.
- **Les préréglages radio Foothold passent au modèle par plan.** L'ancien fichier
  *fonctionnait*, mais donnait à **10 types d'appareils** des canaux hors de la bande de leurs
  radios — silencieusement supprimés, l'AJS-37 perdant sa liste FM de 30 canaux entière. Sur
  `Foothold_AF_2.4.1` : **10 → 2** types en défaut et **30 → 32** planchettes ; sur la Normandie
  WWII : **2 → 0**. Le Mi-24P et le Mi-8MT gagnent des préréglages que l'ancien fichier avait
  renoncé à leur donner.

---

## 🔧 Fiabilité : ce qui semblait marcher sans marcher

### Une mission avec des FW-190 refusait de s'enregistrer

Signalé par **Tripack**. L'éditeur de mission renvoyait :

```
FW-190D9 Template: Fréquence invalide 134 MHz
```

…et seuls les templates **bleus** étaient signalés. Un appareil DCS impose en réalité **deux**
contraintes de fréquence différentes, et l'outillage n'en connaissait qu'une :

| Contrainte | Ce qu'elle borne | FW-190 |
|------------|------------------|--------|
| plage radio | les **canaux préréglés** | 38–156 MHz |
| `human_radio` | la **fréquence principale du groupe** | 38.4–42.4 MHz |

L'injecteur recopie le canal 1 dans la fréquence du groupe pour que les deux concordent. Le
canal 1 valait 134 MHz : préréglage parfaitement légal sur la FuG 16, fréquence principale
illégale. Les FW-190 rouges allaient bien parce qu'ils ne correspondent à aucun préréglage —
l'injecteur n'y touchait pas.

La contrainte manquante est désormais connue pour **27 appareils sur 87**, et la recopie est
abandonnée quand elle produirait une fréquence invalide : le groupe garde la sienne, les
préréglages sont injectés normalement. Au passage, cela ferme le même piège latent sur le Hawk,
le M-2000C et toute la série P-51 / P-47 / Mosquito.

> Si vous avez déjà construit une mission touchée, elle porte encore la mauvaise fréquence :
> reconstruisez-la avec cette version, ou remettez 38.4 à la main dans le champ avant
> d'enregistrer.

### Un mot de passe de `mission.yaml` protège enfin quelque chose

Deux défauts indépendants faisaient de `security:` une décoration. Les empreintes n'étaient
émises qu'au niveau le plus faible, alors que les verrous qui comptent (authentification des
marqueurs, apparitions sensibles, missions de transport) lisent les niveaux forts : un mot de
passe configuré ainsi ne pouvait authentifier aucun marqueur.

Et la page de référence documentait **SHA-256** quand le script calcule un **SHA-1** : toute
empreinte produite en suivant la documentation ne pouvait jamais correspondre. La mission
paraissait protégée et était grande ouverte.

**Si vous utilisez `security:`, régénérez vos empreintes en SHA-1 et revérifiez vos missions.**

### Autres correctifs

- `convert-other --profile` fonctionne dans l'exécutable livré : les profils n'étaient pas
  embarqués, la moulinette Foothold documentée était donc inutilisable sans les sources.
- La documentation des versions publiées repart : le site restait sur la 6.10.0 alors que la
  6.11.0 était sortie.
- Le lot Foothold signale un `.miz` dont le nom ne correspond plus à `mission.yaml` — ce nom
  est une interface (RealWeather y lit le code `_ICAO_`), donc un fichier resté d'une
  construction antérieure tire la météo du mauvais aérodrome, sans rien dire.

---

## 📚 Documentation

Un audit complet a été passé sur le site publié. Ce qu'il a corrigé : une page qui n'existait
qu'en français et servait donc du français sur son URL anglaise, six liens renvoyant un **404
en production**, des ancres laissées derrière par une renumérotation de sections, une signature
d'API périmée, un en-tête annonçant une version vieille de six correctifs, et une page absente
de tous les menus.

Ces défauts n'étaient pas un problème de rangement mais d'absence de surveillance : la CI
vérifiait le Lua, le Python, la couverture, les données DCS — et rien dans la documentation.
C'est réparé : un contrôle refuse désormais un lien mort, une ancre inexistante, une page non
traduite ou absente du menu. Les ancres citées d'une page à l'autre sont explicites et en
anglais, identiques dans les deux langues, **le texte des titres restant dans la langue de la
page**.

---

## 🔀 Migration

Un seul point demande une action, et seulement dans un cas précis.

**Votre mission est concernée si** elle contient des zones de combat **et** des slots joueurs
rouges qui doivent pouvoir consulter ou activer les zones bleues.

Dans ce cas, sur les zones concernées :

```yaml
      - type: zone
        zone_name: "CZ-Alpha"
        radio_menu_coalition: ALL   # les deux camps voient la zone et peuvent l'activer
```

**Votre mission n'est pas concernée si** tous vos slots joueurs sont bleus : le menu allait déjà
de fait aux seuls bleus présents, rien ne change à l'usage.

Rien d'autre à modifier : `enemy_coalition` vaut `RED` par défaut, et une zone qui ne mentionne
aucune de ces deux clés se comporte comme avant, au bit près dans la configuration générée.

> Cette restriction s'appuie sur la fonction de menu par coalition de DCS. Les cas usuels sont
> couverts ; si vous constatez un comportement inattendu sur le menu `COMBAT ZONES` en jeu,
> signalez-le — `radio_menu_coalition: ALL` rétablit immédiatement l'ancien comportement sur la
> zone concernée.

---

## 🙏 Merci

- **Tripack**, qui a remonté les deux bugs de fréquence radio (le FW-190 de cette version, le
  MiG-15bis précédemment) en construisant ses propres missions avec les outils. Les deux
  venaient de la même zone du code et ont chacun révélé une contrainte DCS que l'outillage ne
  modélisait pas.
- **Reaper et les copains de la VEAF**, pour le test de la mission **OT Caucasus** avec cette
  version — une mission complète passée en jeu vérifie ce qu'aucun test automatique ne voit.
- La chaîne Foothold de cette version vient d'un besoin concret : adopter la **release 4.4.1 de
  Lekaa** sur les dix cartes des serveurs VEAF. Chaque friction rencontrée sur ce vrai lot est
  devenue un correctif ou un garde-fou.
