# VEAF Mission Creation Tools — 6.14.0

Trois grands chantiers dans cette version, plus une longue liste de correctifs. **L'assistant
d'édition de mission (MCP) passe de créateur à éditeur** : il peut désormais *modifier* une mission
existante — bouger un groupe, changer une loadout, éditer une route ou une zone, dessiner sur la
carte, ajouter une place joueur. **Un harnais de fumée** vérifie enfin le comportement de VEAF dans
un vrai DCS, sans personne devant l'écran. Et **le modèle de sécurité passe par pilote** — c'est le
point à lire avant de mettre à jour. Le tout sur fond de **CTLD 2.0.0-rc7** embarqué et d'une refonte
documentaire de fond.

---

## ⚠️ À lire avant de mettre à jour

**`/login` et `_auth` n'ouvrent plus la mission pour tout le monde.**

Jusqu'ici, une authentification réussie ouvrait chaque commande sécurisée à **tous les joueurs du
serveur** pendant `authDuration` minutes. Ce n'est plus le cas : chaque commande vérifie **qui**
demande.

| | |
|---|---|
| **Un pilote listé dans `veaf-pilots.txt`** | rien ne change — son propre palier lui donne déjà ses commandes, il n'a jamais eu besoin du mot de passe |
| **Un pilote non listé** | doit donner le mot de passe **à chaque commande**. Plus de session de dix minutes |
| **Le menu radio F10** | DCS ne sait pas *quel* occupant d'un groupe a cliqué, donc un groupe agit au niveau de son occupant **le moins gradé**. `_auth` ou `/login` depuis un marqueur ou le chat élève ce groupe au niveau du **demandeur** pour 2 minutes |

C'est cette dernière ligne qui résout le vol à plusieurs : un instructeur avec un élève garde ses
commandes en s'authentifiant, sans rien prêter à l'élève. `veaf.SecurityDisabled = true` désactive
toujours toute la couche pour une mission solo ou de test. Détails :
[`veafSecurity.md`](doc/mission-maker/scripts/veafSecurity.md).

**Les paliers de sécurité sont renommés** pour dire ce qu'ils sont : `ADMIN` / `SENIOR_PILOT` /
`KNOWN_PILOT` (les anciens `L0`/`L1`/`L9` marchent encore une version, avec un avertissement).

---

## L'assistant d'édition de mission devient un éditeur

Le serveur MCP savait *créer* une mission ; il peut maintenant en **modifier** une existante, à
partir d'un `.miz` ou d'un dossier de mission :

- **lire** ce qui est là : les groupes et zones, puis les unités jusqu'aux loadouts et routes ;
- **changer une unité** (loadout par numéro de pylône, compétence, livrée, cap, callsign) et
  **déplacer un groupe** (le déplacement emporte unités, route et ancre) ;
- **éditer une route** (ajouter/insérer/retirer/réordonner des waypoints, et leur donner une tâche
  d'un jeu fermé validé) et **remodeler une zone de combat** (déplacer, redimensionner, en polygone) ;
- **dessiner sur la carte F10** (ligne, rectangle, étiquette, cercle, ovale, forme libre) — un dessin
  posé par l'assistant survit à un rebuild, contrairement à un dessin fait à la main dans l'éditeur ;
- **ajouter une place joueur**, un groupe au sol, ou un vol au parking (places de stationnement
  résolues automatiquement à partir des données capturées, appareils bien garés).

Chaque action mesure ce que l'éditeur DCS fait *réellement* subir à ce qu'elle écrit — plusieurs
défauts (une tâche `Bombing` silencieusement supprimée, une altitude ignorée) ont été trouvés et
corrigés en comparant à de vraies missions ouvertes puis sauvées dans l'éditeur.

## Un harnais qui vérifie VEAF dans un vrai DCS

`veaf-tools dcs smoke-test` interroge un DCS en cours d'exécution et exécute des assertions **à
l'intérieur du jeu**, là où les mocks ne peuvent rien prouver. Il a servi à mesurer, entre autres,
que l'API non documentée `Disposition` évite réellement les bâtiments (0 point sur 30 posé sur du
décor, dans une zone qui en compte 369), et il embarque une mission de test dont l'ancre est vérifiée
en jeu. Outil **local** et opt-in : il n'exige pas de DCS pour les machines qui n'en ont pas, il
**passe** proprement.

## CTLD 2.0.0-rc7

Le CTLD embarqué passe de `2.0.0-rc3` à **`2.0.0-rc7`** (la réécriture VEAF). La configuration s'y
adapte sans que vous n'ayez rien à faire de plus qu'en 6.13 : elle vit dans un fichier dédié
(`CTLD_userConfig.lua`) éditable via l'outil graphique. Au passage, **sauver une mission dans
l'éditeur DCS ne supprime plus les sons de CTLD et CSAR**.

> **`2.0.0-rc7` reste une *release candidate*** — éprouvée, mais si vous exploitez un serveur public,
> sachez sur quoi vous décollez.

## Documentation

Un audit en cinq passes a trouvé une quarantaine d'endroits où la documentation disait le contraire
du code — tous corrigés. En vrac : une **référence CLI complète** (25 commandes, toutes leurs
options, dans les deux langues), les **pages des modules qui n'en avaient pas**, le guide pilote qui
annonçait des entrées de menu inexistantes, 239 liens qui renvoyaient les lecteurs anglophones vers
des pages françaises, et un contrôle documentaire (`docs-check`) durci pour que ces dérives ne
repassent plus en silence.

## Autres correctifs notables

- **La démo de référence est passée en v6** (dossier de mission `mission.yaml`, et elle montre des
  choses qu'une mission v5 ne pouvait pas déclarer).
- **`convert-v5`** : un `presets.yaml` v5 qui survivait à la conversion puis tuait le build ; un
  doublon de clé `SKYNET` dans le bloc `modules:` ; un chemin Windows de config météo converti en rien.
- **Radio** : les préréglages radio des Flaming Cliffs reviennent sur planchette ; le menu radio F10
  parle enfin la langue de la mission ; les canaux E/F de l'AJS-37 atteignent enfin la mission ; un
  radiocompas ne se déclare plus comme radio FM.
- **Un script personnalisé peut être chargé avec un délai**, et une mission adoptée reproduit
  l'échelonnement de chargement d'origine (ce dont AIEN a besoin après Foothold).
- **`validate`** refuse désormais une mission que personne ne peut charger (coalitions non peuplées),
  et une mission bâtie de zéro est jouable de bout en bout.
- Une volée de correctifs runtime issus de la revue de sécurité `SECREV-2`, close avec ses 140 points
  décidés : chaque CAP volait sa route à Mach 0.3, une faute de frappe dans un nom de zone plantait
  toutes les air waves, `-showmfd` faisait l'inverse de ce qu'il annonce sur les AFAC et CAP, un METAR
  pouvait écraser la météo observée, et d'autres.

---

*Le CTLD embarqué est `2.0.0-rc7`. Signalez tout souci sur le
[Discord VEAF](https://www.veaf.org) ou le dépôt.*
