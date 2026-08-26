# VEAF Mission Creation Tools — 6.17.0

**Le transport et la logistique retrouvent ce qu'ils avaient perdu.**

Deux jours après la 6.16.0, cette version répare une série de défauts dont trois touchaient la même
chose : faire vivre CTLD dans une mission VEAF. Une FARP posée dans l'éditeur n'était plus un point
de chargement, le brief d'accueil ne s'affichait jamais sur un serveur, et la documentation ne disait
nulle part où récupérer l'outil de configuration de CTLD.

**Aucun de ces trois défauts n'a été trouvé par les tests.** Ils sont venus des questions et des
constats d'un mission maker qui construisait sa mission — ils étaient invisibles dans une suite verte
parce que les tests vérifiaient les fonctions, jamais ce qui les branche. Les correctifs de cette
version ajoutent donc, à chaque fois, un test sur le branchement.

---

## ⚠️ À lire avant de mettre à jour

### CTLD ajoute maintenant ses types logistiques à votre configuration

Si votre mission utilise CTLD, le build ajoute désormais cinq types d'unités à ce que déclare votre
`ctld-config.yaml` : les quatre porte-avions (`LHA_Tarawa`, `Stennis`, `CVN_71`, `KUZNECOW`) et le
dépôt de munitions FARP (`FARP Ammo Dump Coating`).

**Votre fichier n'est pas modifié** — c'est la copie injectée dans la mission qui l'est, et le
`CTLD_userConfig.lua` généré indique en commentaire ce qui a été ajouté.

C'est un retour au comportement d'avant CTLD 2, qui reconnaissait ces unités automatiquement. Mais
c'est un changement réel : une mission dont les listes étaient volontairement vides verra ces cinq
types réapparaître. Pour garder la main entière sur ces listes :

```yaml
modules:
  CTLD:
    enabled: true
    manage_logistics: false
```

Avec ce réglage à `false`, si vos deux listes sont vides, le build vous prévient explicitement plutôt
que de démarrer une mission sans aucun point de chargement.

---

## Transport et logistique

### Vos FARP et porte-avions sont à nouveau des points de chargement

CTLD 2 apprend quelles unités sont des points de chargement par deux réglages,
`logisticUnitTypes` et `troopZoneShipTypes` — et il les livre **vides**. Ces listes n'étaient
remplies qu'à la création du dossier de mission, jamais ensuite. Un `ctld-config.yaml` écrit à la
main, repris d'une autre mission ou régénéré depuis les défauts de CTLD arrivait donc avec deux
listes vides, sans que rien ne le signale.

Le symptôme était déroutant parce qu'il était partiel : **les FOB créées en vol fonctionnaient**,
elles passent par un autre chemin, et les FARP posées dans l'éditeur non.

Le nouveau réglage `manage_logistics` (actif par défaut) règle le cas — voir l'encadré ci-dessus.

### Où télécharger `ctld-tools`

La documentation expliquait tout du fichier `ctld-config.yaml` sauf la première étape : où trouver
l'outil qui l'édite. L'exécutable est publié avec CTLD, mais **toutes les versions de CTLD 2 sont
des pre-releases** — donc aucune n'apparaît en « Latest release » et le lien vers le dépôt ne mène
pas au fichier.

Le guide a maintenant une section dédiée : la page des releases, le nom du fichier, ce piège des
pre-releases, et comment lire la version de CTLD embarquée dans votre installation pour prendre
l'outil qui lui correspond.

---

## En vol

### Le brief d'accueil s'affiche enfin, sur serveur aussi

Le brief météo affiché en prenant un slot, arrivé en 6.16.0, ne s'est jamais déclenché sur un serveur
dédié. Il fonctionnait en solo, ce qui l'a fait passer pour opérationnel.

La cause : le gestionnaire cherchait l'unité sous une forme que le système d'événements VEAF n'envoie
jamais. Il abandonnait donc à chaque événement reçu, silencieusement, avant même d'écrire dans le
journal — d'où un silence total plutôt qu'une erreur.

### Chaque événement DCS était traité deux fois

Le gestionnaire d'événements VEAF s'enregistrait deux fois auprès de DCS. Résultat : chaque
naissance, chaque tir, chaque destruction traversait deux fois toute la chaîne — double
reconstruction du menu radio, double évaluation des QRA, double remplissage des entrepôts de FARP.

Le défaut passait inaperçu parce que la plupart des fonctionnalités concernées ont leur propre garde
contre les doublons, qui avalait le second passage. Il ne se voyait que là où cette garde n'existait
pas.

---

## Unités au sol

### `_gc` : commander une unité au sol, en plus court

Une nouvelle syntaxe de marqueur, avec l'interlocuteur en premier, comme on s'adresse à quelqu'un :

```
_gc <groupe>, <ordre>
```

Livrée en même temps que trois correctifs sans lesquels elle était inutilisable :

- la commande **n'atteignait jamais le module** — elle ne faisait donc rien du tout ;
- `groupname` ne retrouvait pas un groupe qu'une commande VEAF venait de créer, et lui substituait
  silencieusement un autre groupe ;
- le message d'aide affiché quand un ordre s'adresse à une unité inconnue enseignait **la mauvaise
  commande**.

### L'artillerie reste en place

Une batterie quittait sa position après chaque mission de tir : le tir de réglage partait, puis la
correction trouvait une batterie en mouvement. C'était une option d'évasion de contre-batterie
codée en dur.

Et `-arty1` et ses semblables ne pouvaient pas commander la batterie qu'ils venaient de faire
apparaître.

---

## Divers

- **Sanctuary** : une vague terrestre posait ses deux sites SAM au même endroit, avec le même rayon.
- **Zones de combat** : le briefing d'une opération terminée affichait sa clé de traduction au lieu
  du texte.

---

## Merci

Cette version doit beaucoup à **Tripack**, dont les remontées et les questions de la journée ont
mis au jour trois défauts que rien d'automatique n'avait vus — dont deux dataient de la veille et un
de plus longtemps. Les journaux de serveur qu'il a fournis ont permis de diagnostiquer le brief
d'accueil sans lancer DCS une seule fois.
