# VEAF Mission Creation Tools — 6.24.0

**Cette version change la façon dont les défenses aériennes vous voient.** C'est la première depuis
longtemps qui modifie le comportement de missions existantes sans qu'on touche à leur configuration.
Lisez l'encadré ci-dessous avant de reconstruire.

> ### ⚠️ Ce qui change dans vos missions existantes
>
> **Voler sous l'horizon radar ne suffit plus à passer inaperçu.** Jusqu'ici, un site SAM piloté par
> l'IADS était totalement aveugle entre deux passages de veille : sans radar de détection lointaine
> pour le prévenir, il restait éteint quoi qu'il arrive, même si vous lui passiez au-dessus de la
> tête. Désormais chaque site garde un rayon de détection propre, court, et s'allume à l'intérieur.
>
> C'est **activé par défaut**. Pour retrouver le comportement précédent — un IADS puriste où seule la
> chaîne de détection compte — mettez dans votre `mission.yaml` :
>
> ```yaml
> modules:
>   SKYNET:
>     last_line_of_defence: false
> ```
>
> Les valeurs sont réglables : chaque site tire une fois son rayon entre
> `last_line_of_defence_min_radius_km` (10) et `last_line_of_defence_max_radius_km` (15), et reste
> allumé `last_line_of_defence_persistence_s` (45) secondes après le dernier passage. Ce rayon est
> mesuré à plat et **ignore l'enveloppe de tir** : un système à courte portée peut donc s'allumer pour
> un appareil qu'il ne peut pas atteindre. C'est voulu — un site qui vous entend passer réagit, même
> s'il ne peut rien vous faire.

---

## 📡 Le réseau de guetteurs : la parole circule

La grande nouveauté de cette version. Une unité au sol qui voit un appareil hostile le **signale**, et
le signalement voyage de véhicule en véhicule par radio, de proche en proche.

Ce qu'il faut comprendre, c'est que **voir et relayer sont deux choses différentes** :

- n'importe quelle unité terrestre qui voit un appareil devient une paire d'yeux — et un simple
  camion voit plus loin qu'un canon antiaérien automoteur, qui est presque aveugle ;
- un site SAM, lui, **relaie mais ne voit jamais** ;
- un pilote qui vole pour cette coalition devient lui aussi un guetteur.

Un site SAM qui reçoit le message **ne s'allume pas pour autant** : il garde le contact en mémoire et
attend, exactement comme il le ferait pour un radar de veille lointaine, et ne passe en émission que
lorsque l'appareil entre dans **sa propre** enveloppe de tir. Toutes les autres protections Skynet
continuent de s'appliquer.

C'est ce qui donne à une ligne de batteries ce comportement de réveil **dans la direction de la
pénétration** — et le relief compte : un appareil qui suit une vallée n'est pas vu par le guetteur
placé derrière la crête.

**C'est désactivé par défaut.** Pour l'activer :

```yaml
modules:
  SKYNET:
    spotter_network: true
```

Deux réglages méritent votre attention : `spotter_radio_range_km` (20) décide si le réseau est
seulement **connecté** sur votre carte — sans portée suffisante, vous n'avez pas un réseau mais des
îlots isolés — et `spotter_propagation_speed_kmh` (3 600) donne la vitesse de propagation. La période
entre deux sauts se déduit des deux, de sorte qu'élargir la portée ralentit les sauts au lieu de
doubler silencieusement la vitesse de l'alerte.

### Voir ce que le réseau voit

Un mode de diagnostic affiche le réseau sur la carte F10, avec **une couleur = une chose** :

- le **carré** d'un nœud dit ce qu'il sait — gris : pas prévenu · bleu : prévenu · rouge : élément
  d'une batterie réellement en émission ;
- le **cercle** dit ce qu'il voit — gris : un guetteur qui ne tient rien · orange : un guetteur avec
  un contact en vue · rouge : l'enveloppe d'engagement d'une batterie active ;
- une **croix rouge** marque chaque contact tenu, et un **trait rouge plein** le chemin par lequel
  l'alerte est réellement passée.

```yaml
modules:
  SKYNET:
    spotter_view: "on"    # "off" · "on" · "radio"
```

Les guillemets sont obligatoires : YAML lit un `on` nu comme un booléen. La valeur `"radio"` place un
interrupteur *Afficher / Masquer la vue des guetteurs* dans le menu F10, sous **RÉSEAU DE
GUETTEURS**, par coalition et accessible à un game master. Attention, c'est une vue **de
coalition** — DCS ne sait pas dessiner pour le seul game master, donc tous les pilotes du camp la
voient.

La documentation du module déroule maintenant une alerte complète en cinq captures prises en mission
réelle : le réseau au repos, un poste qui voit l'appareil et la batterie qu'il prévient, le mot qui
traverse 95 km de front, la défense qui se rendort, puis les patrouilles qui prennent le relais.

Et pour répondre à la question *« est-ce que le réseau a réveillé quelque chose cette nuit sur le
serveur ? »*, il existe désormais une trace durable : les 200 derniers réveils par coalition, avec
leur heure de mission.

---

## 🛰️ Skynet 3.5.0

L'IADS embarqué passe de `3.4.0RP-VEAF` à [3.5.0](https://github.com/VEAF/Skynet-IADS/releases/tag/v3.5.0),
première version publiée sous **maintenance conjointe VEAF / Regroupement de Patrouilles**.

Au-delà de la dernière ligne de défense, trois correctifs changent ce que fait une mission VEAF **au
respawn**, parce que notre assistant réinscrit les sites par préfixe à chaque fois :

- déclarer qu'un radar couvre une batterie n'éteint plus cette batterie ;
- une réinscription en masse ne laisse plus d'éléments écartés câblés dans le graphe de couverture,
  où une batterie se croyait couverte par un radar que l'IADS n'interrogeait plus ;
- un site démonté pour esquiver un HARM ne reste plus sourd pour le reste de la mission.

**Les quatre avertissements de configuration de Skynet sont réaffichés à l'écran**, après cinq ans
passés à n'être écrits que dans le journal : nom de groupe inconnu, nom d'unité inconnu, élément de
la mauvaise coalition, groupe dont il ne connaît pas le type de SAM. Concrètement, une mission qui
contient une faute de frappe vous le dira au chargement au lieu de se comporter bizarrement en
silence.

### L'option `ewr` n'avait jamais fonctionné sur cinq systèmes

**SA-10, SA-6, SA-5, Patriot et Hawk** : si vous marquiez l'un d'eux comme veille lointaine avec
l'option de spawn `ewr`, il était éteint dans la foulée. Deux balayages internes remettaient ces cinq
types en veille désactivée — l'un à la fin de chaque inscription de groupe, son jumeau juste après la
boucle d'inscription au démarrage. C'était un reliquat de l'époque où VEAF forçait les gros systèmes
en mode veille ; le forçage a été abandonné en 2022 et les balayages ont seulement été basculés de
`true` à `false` au lieu d'être supprimés. Ils sont partis.

Au passage, cela cesse d'envoyer un ordre d'extinction parasite à tous les sites de ces cinq types
chaque fois qu'un groupe rejoint le réseau — et cela cesse de défaire le mécanisme de défense
rapprochée de **Flogas** quand cette défense est l'un d'eux.

---

## ✈️ Slots dynamiques : douze appareils de plus, onze emports

Le catalogue livré passe de **104 à 128 templates**, dans les deux coalitions à chaque fois :

> C-130J-30 · F-100D · F-14B(U) · La-7 · MB-339A/PAN · MiG-29A Fulcrum · P-47D-40 · P-51D-30-NA ·
> T-45 · J-11A · MiG-29S · Su-33

Et **onze templates qui sortaient avec les pylônes vides sortent maintenant armés** — F-16CM, F/A-18C,
Ka-50 III, M-2000C et MiG-29G côté bleu ; F-16CM, F-5E-3, F/A-18C, Ka-50, M-2000C et Su-27 côté
rouge. 33 des 128 portent un emport, contre 18 auparavant.

**Merci à Reaper**, qui a extrait le catalogue de sa propre mission avec nos outils et nous l'a
envoyé. C'est de là que vient tout ce qui précède — et aussi les trois défauts ci-dessous, que son
fichier a mis au jour.

### L'A-4E-C et l'OV-10A étaient livrés comme des hélicoptères

Ils étaient donc proposés sur les plots hélicoptères. Les templates de slots dynamiques sont classés
d'après la vraie catégorie DCS de l'unité, lue dans la base d'unités embarquée — qui est générée
depuis le jeu de base et ne peut donc pas connaître un mod. Ces types retombaient sur la table où DCS
les avait rangés, et **DCS range tous les templates de slot dynamique sous `helicopter`**, quel que
soit l'appareil. Une petite table d'appareils modés corrige cela. Deux vieilles verrues partent avec :
`CH-47F Template-1` devient `CH-47F Template`, et `F-15E S4+ Template Red` quitte `Russia` pour
`CJTF Red`, où vivent les 51 autres templates rouges.

### Trois défauts que l'extract de Reaper a révélés

- **`extract-aircraft-groups` écrivait un catalogue qu'il ne savait pas relire.** L'extraction ouvrait
  son fichier de sortie sans nommer d'encodage, donc sur un Windows français elle écrivait dans la
  page de code locale quand tous les lecteurs ouvrent ce fichier en UTF-8. Un seul indicatif ou une
  seule livrée accentuée suffisait : le traitement annonçait une réussite, et la commande suivante —
  un build, une injection, une deuxième extraction avec `--merge` — mourait sur une erreur de
  décodage.
- **Les templates injectés sont maintenant masqués de la carte et laissés inactifs par l'injecteur
  lui-même**, et non plus parce que le catalogue livré se trouvait le dire. Rien dans le code ne
  posait ces deux drapeaux ; les 104 templates par défaut les portaient, donc le résultat avait l'air
  correct. Un catalogue extrait d'une mission où personne n'a coché les cases à la main — le cas
  normal — dessinait **tous** les groupes de template sur la carte F10. Mesuré sur son extract : 78.
- **La validation d'un catalogue ne signale plus la sortie de l'outil comme suspecte.** Le contrôle
  « champ inhabituel » listait les clés qu'il connaissait, et cinq que l'outil produit lui-même n'en
  faisaient pas partie — dont `dynSpawnTemplate`, le drapeau qui *définit* un template de slot
  dynamique. Mesuré sur les deux catalogues livrés : **262 messages, tous du bruit**, dans le flux
  dont le métier est de pointer une faute de frappe. Une vraie faute y était invisible.

---

## 🤖 L'assistant de documentation répondait depuis un index gelé

Il répondait à partir d'une documentation figée, et cette fois pour une raison de quota : **une seule
reconstruction de l'index coûtait plus qu'une journée entière** du quota gratuit Cloudflare. La
première fusion de documentation de la journée le dépensait, et toutes les suivantes échouaient avant
d'écrire le moindre octet.

Les textes étaient stockés à raison d'une entrée par passage — 157 pages font 1 395 passages, contre
un plafond de 1 000 écritures par jour, à l'échelle du compte et partagé avec les compteurs
anti-abus de l'assistant. Ils tiennent maintenant en une valeur par langue : **une reconstruction
coûte quatre écritures**, que vous ayez changé un titre ou toute la documentation.

Deux garde-fous vont avec : le service refuse un index dont les deux moitiés ne s'accordent pas sur
leur longueur, au lieu de répondre avec un passage décalé ; et l'indexeur refuse un vecteur mis en
cache à la mauvaise largeur, qui produisait un classement de pertinence calculé sur un demi-vecteur.

Enfin, `poetry run reindex-docs` — l'équivalent à la main de cette reconstruction — n'avait jamais
reçu le correctif `--remote` livré en 6.23.1 au workflow : il écrivait l'index dans le magasin local
de wrangler et annonçait une réussite. **Toutes les réindexations lancées à la main depuis le
2026-08-08 n'ont donc rien envoyé.**

---

## 🙏 Remerciements

- **Reaper**, pour l'extract de son catalogue de slots dynamiques — douze appareils, onze emports, et
  trois défauts de nos outils qu'aucune de nos propres données ne pouvait révéler.
- **Flogas** et le **Regroupement de Patrouilles**, pour la maintenance conjointe de Skynet, dont
  cette version embarque la première release commune.
- **Pardon à Flogas** pour la longueur de tout ce qui précède. L'assistant qui rédige ces notes a
  deux défauts connus : il est verbeux, et il y revient toujours. Il a réécrit cette ligne quatre
  fois, dont deux pour la raccourcir.

Signaler qu'un message est incompréhensible, ou envoyer un fichier produit par nos outils sur une
machine qui n'est pas la nôtre, est infiniment plus utile qu'on ne le croit. Continuez.
