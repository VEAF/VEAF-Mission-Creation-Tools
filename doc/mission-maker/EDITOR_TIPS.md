# Astuces de l'éditeur de mission

Des actions de déclencheur de l'éditeur de mission de DCS que VMCT n'enveloppe pas, et qui valent d'être connues.
Elles se posent à la main dans l'éditeur, dans une mission VMCT comme dans n'importe quelle autre : le build garde les déclencheurs que vous avez écrits.

Chaque astuce dit d'où vient ce qu'elle affirme.
**Lu** : relevé dans les fichiers Lua de l'éditeur que DCS livre en clair (`MissionEditor/modules/me_trigrules.lua`, DCS 2.9.30) ; ce que l'action fait vraiment est codé dans le moteur, donc déduit de ses paramètres.
**Mesuré** : vu en jeu, avec la date.

## Ce que VMCT fait déjà {#already-in-vmct}

Avant de poser un déclencheur, vérifiez que VMCT ne le fait pas déjà :

| Besoin | Dans VMCT |
|--------|-----------|
| Imposer les étiquettes, la vue F10, les vues externes… | `mission.forced_options` — voir [la référence](../MISSION_YAML_REFERENCE.md#forced-options) |
| Un bombardement d'artillerie fictif sur une zone | les raccourcis `-shell`, `-cesar` et `-flak` — voir [les alias](../ALIASES.md) |
| Couper l'ATC de DCS | `mission.silence_atc_on_all_airbases` |
| Un écran de fumée qui aveugle l'IA | n'existe pas : **mesuré** le 2026-10-08, une fumée n'empêche pas l'IA de voir et de tirer |
| Retirer les arbres d'une zone (*SCENERY REMOVE OBJECTS ZONE*) | ne marche pas : **mesuré** le 2026-10-12, la forêt reste en place |

## Une panne déclenchée à la demande {#failure-on-demand}

*SET FAILURE* (`a_set_failure`) provoque une panne sur l'avion du joueur.
**Lu** : trois paramètres, la panne, une probabilité de 1 à 100 % et un délai aléatoire « Within (mm) » en minutes.
La liste des pannes est celle de l'avion **joueur** sélectionné dans l'éditeur au moment où vous posez l'action : une mission à plusieurs types d'avions ne peut viser que les pannes d'un type à la fois.

Usage typique, pour l'instruction : une entrée du menu F10 (*RADIO ITEM ADD FOR GROUP*) qui lève un flag, et un déclencheur *FLAG IS TRUE* → *SET FAILURE*.
L'instructeur provoque la panne quand l'élève est prêt.

## Un groupe que seul le maître de jeu commande {#game-master-only}

*GROUP CONTROL GAMEMASTER ONLY* (`a_group_controllable_off`) réserve un groupe au maître de jeu ; *GROUP CONTROL DEFAULT* (`a_group_controllable_on`) le rend à tous.
**Lu** : un seul paramètre, le groupe.
Utile pour une force adverse jouée par un maître de jeu Combined Arms, que les JTAC et commandants tactiques ne doivent pas pouvoir piloter.
Les slots de maître de jeu s'ouvrent avec `mission.ground_control` (voir [la référence](../MISSION_YAML_REFERENCE.md#ground-control)).

## Animer un objet {#play-argument}

*PLAY ARGUMENT* (`a_play_argument`) joue une animation d'un modèle 3D, unité ou statique.
**Lu** : le numéro d'argument du modèle (0 à 1000), une position de départ, une position d'arrivée et une vitesse.
Exemples : ouvrir les portes d'un hangar à l'arrivée d'un avion, lever une barrière.
Le numéro d'argument dépend du modèle ; on le trouve dans le *Model Viewer* de DCS.

## Changer le briefing en cours de mission {#briefing-update}

*SET BRIEFING* (`a_set_briefing`) remplace le briefing d'une coalition pendant la mission.
**Lu** : la coalition, une image et un texte.
Utile pour une opération en plusieurs phases : le briefing de la phase 2 apparaît quand la phase 1 est remplie, pour les joueurs qui arrivent en cours de route.

## Faire grandir une zone {#zone-resize}

*(dev) ZONE_INCREMENT_SIZE* (`a_zone_increment_resize`) agrandit ou rétrécit une zone de déclencheur.
**Lu** : la zone et un nombre de mètres, de -100 000 à 100 000.
L'éditeur la propose malgré son étiquette « (dev) ».
Pas encore vue en jeu : à vérifier avant de s'en servir (front qui avance, zone interdite qui s'étend).

## Détruire le décor d'une zone {#scenery-destruction}

*SCENERY DESTRUCTION ZONE* (`a_scenery_destruction_zone`) détruit les objets de la carte dans une zone.
**Lu** : la zone et un niveau de destruction de 0 à 100 %.
Exemple : une ville déjà bombardée au début de la mission.
Pas encore vue en jeu ; sa voisine *SCENERY REMOVE OBJECTS ZONE* ne retire rien (voir le tableau plus haut), donc vérifiez avant de bâtir une mission dessus.

## Voir aussi {#see-also}

- [Référence de `mission.yaml`](../MISSION_YAML_REFERENCE.md) — ce que VMCT règle à chaque build.
- [Guide](GUIDE.md) — le travail dans l'éditeur au sein d'un dossier de mission VMCT.
