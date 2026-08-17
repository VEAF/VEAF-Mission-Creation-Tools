# VEAF Mission Creation Tools — 6.15.0

**Ce que les outils perdaient en silence.**

Les trois chantiers de cette version racontent la même histoire : une mission qui a l'air correcte
et qui ne l'est pas. Des bases devenues neutres à la construction, des briefings tronqués à la
conversion, la moitié des réglages d'un `missionConfig.lua` évaporés sans un mot. Aucun message
d'erreur, aucun avertissement — le fichier se construisait, la conversion se terminait, et le
problème n'apparaissait qu'en vol.

Le fil rouge n'est pas « on a ajouté des fonctionnalités ». C'est : **ce qui disparaissait est
désormais soit porté, soit dit.**

---

## ⚠️ À faire en premier si vous avez construit une mission avec la 6.14.2

**Reconstruisez-la.** Toutes ses bases sont neutres — aucune n'appartient à une coalition, les
stocks d'avions sont vides, les slots dynamiques désactivés.

Votre **dossier de mission source est intact** : la construction ne le réécrit jamais. Une simple
reconstruction avec cette version restaure tout.

---

## Les bases ne deviennent plus neutres

Signalé par **Tripack**, avec deux constructions de la même mission — une en 6.14.0 correcte, une en
6.14.2 avec toutes les bases neutres. Ces deux fichiers ont donné la cause en une comparaison.

Ce qui se passait : DCS range les aérodromes dans une table indexée par leur numéro. Une mission qui
déclare **tous** les aérodromes de sa carte a donc les numéros 1, 2, 3… à la suite — et sous cette
forme précise, le lecteur de fichiers rendait une liste là où le code attendait un dictionnaire. Le
garde-fou écrit pour se protéger d'une table absente attrapait en réalité **le cas normal** : il
jetait les aérodromes de la mission et les remplaçait par des entrées neutres par défaut.

Mesuré sur la mission de Tripack : 29 aérodromes portant 26 bases rouges, 1 bleue et trois stocks
d'avions ressortaient en 30 entrées neutres sans rien. Après correction, ses 26 rouges, sa bleue et
ses trois stocks sont intacts, et le seul aérodrome ajouté est celui que sa mission n'avait jamais
déclaré.

Deux autres commandes plantaient sur la même forme de fichier — l'attribution d'une base à une
coalition et l'injecteur de stocks — et sont corrigées avec.

---

## Conversion v5 → v6 : trois pertes silencieuses

Trois rapports de **Sharko**, chacun accompagné d'un banc de mesure, de témoins de contrôle et
d'une re-mesure contre la version courante. C'est cette qualité de rapport qui a permis de corriger
sans deviner.

### Un briefing sur plusieurs lignes n'efface plus la suite

Un briefing écrit en plusieurs morceaux coupait la lecture de la zone de combat — et **tous les
réglages écrits après lui étaient perdus**. La perte dépendait de la position dans le fichier, pas
du réglage : rien, dans le réglage manquant, ne pouvait mettre sur la piste.

Sur le corpus de campagnes de Sharko : **302 briefings tronqués sur 1864 zones**, le pire passant de
137 caractères à 6.

### Six réglages de zone de combat existent enfin

`completable`, `show_units_list`, `show_zone_position_info`, `smoke_and_flare`,
`radio_menu_disabled`, et la désactivation de l'activation par les joueurs. Ces réglages servent
tous à **désactiver** quelque chose, et la valeur par défaut est « activé » : les perdre ne
remettait pas à neutre, cela **inversait** le comportement.

Le plus lourd de conséquences est `completable`. Sans lui, une zone qui ne contient aucune unité
rouge se déclare terminée toute seule environ une minute après son activation, annonce « tous les
ennemis sont détruits » et enchaîne sur la zone suivante. Sur 82 zones de narration ou de soutien,
c'est une campagne qui déraille.

`radio_menu_disabled` vient juste après : 171 zones volontairement cachées réapparaissaient dans le
menu F10, sous les noms provisoires que leurs auteurs leur avaient donnés justement parce que
personne ne devait les voir.

### Les réglages généraux sont portés, et ce qui ne l'est pas est écrit

Sur 28 réglages scalaires mesurés, **14 n'arrivaient nulle part** — mots de passe de sécurité et
réglages de défense antiaérienne compris.

Deux réponses, ensemble :

- **`module_settings:`**, une nouvelle section de `mission.yaml`, porte les réglages posés
  directement sur une table VEAF (`veafSkynet.DelayForStartup`, `veafRadio.RadioMenuName`…). Elle
  est **générique** : les quatorze réglages perdus ont été mesurés sur les campagnes d'un seul
  mission maker, alors des clés nommées une par une auraient couvert celles-là et laissé les
  quatorze suivantes à découvrir de la même façon.
- **Ce que la conversion ne sait toujours pas porter** — une table, une fonction — est désormais
  listé tel quel, en commentaire, dans le `mission-script.lua` généré sous « Settings NOT
  migrated », et nommé dans le rapport de conversion. Vous pouvez décommenter ce dont vous avez
  besoin.

Les **mots de passe de mission** survivent aussi à la conversion, dans `security.password_hashes`.
Avec une précaution : les deux empreintes que le framework embarque pour toutes les missions ne sont
**jamais** recopiées — elles sont publiques, et les migrer aurait rouvert une faille fermée
précédemment.

---

## Changement de comportement à la conversion

`convert-v5` porte maintenant dans `mission.yaml` des réglages qu'il laissait auparavant dans le
Lua. Conséquence visible si vous comparez deux conversions : un bloc `if veafSpawn then … end` qui
ne contenait qu'un réglage scalaire est désormais entièrement mis en commentaire, le réglage étant
parti dans `module_settings:`. C'est voulu.

Aucune rupture de schéma par ailleurs : toutes les nouvelles clés sont optionnelles et les valeurs
par défaut sont inchangées.

---

## Ce qu'il faut en retenir

Plusieurs de ces défauts vivaient depuis des mois sans que rien ne les voie. La raison est la même
pour tous : **les tests partaient de missions construites de zéro**, jamais de vraies missions. Une
mission vide n'a pas d'aérodromes, pas de briefing sur plusieurs lignes, pas de `missionConfig.lua`
de campagne — exactement les trois formes qui cassaient.

Les tests ajoutés dans cette version construisent leurs cas d'essai par le vrai cycle de lecture et
d'écriture des fichiers, et non plus à la main.

---

## Remerciements

- **Tripack**, pour le signalement des bases neutres et surtout pour les deux fichiers avant/après
  qui ont transformé une enquête en une comparaison.
- **Sharko**, pour trois rapports d'une précision rare — bancs de mesure, témoins de contrôle, et
  une re-mesure contre la version courante pour ne pas laisser de chiffres périmés. Ses bancs
  restent la mesure de référence pour vérifier que la conversion ne perd plus rien.
