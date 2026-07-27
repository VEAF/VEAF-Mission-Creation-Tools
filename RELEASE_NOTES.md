# VEAF Mission Creation Tools — 6.11.0

Cette version répond à trois retours de **Tripack** : les **noms d'aérodromes** étaient
faux dans nos données, et il manquait un moyen de **choisir quand** une QRA ou une zone de
combat s'active. Aucune mission existante n'a besoin d'être retouchée.

## 🛫 Les noms d'aérodromes sont enfin les bons

Le build refusait des `airport_link` de QRA parfaitement valides — Tiyas, Marj Ruhayyil,
Al-Dumayr… — en les déclarant « aérodrome inconnu ». **Merci à Tripack** de l'avoir
signalé : ses noms étaient corrects depuis le début, c'est notre table qui était fausse.

En cause : cette table nom→identifiant était extraite des **balises radio** des cartes.
Elle contenait donc des noms de VOR ou de NDB au lieu de noms d'aérodromes, et ignorait
toutes les bases sans balise. Elle est désormais construite depuis **DCS lui-même**, ce
qui donne le nom exact reconnu en jeu.

- **7 cartes couvertes**, 657 terrains : Caucase, Syrie, Golfe Persique, Normandie,
  Mariannes, Sinaï, Allemagne guerre froide.
- **Hélistations incluses** : elles sont utilisables pour une QRA ou un spawn.
- Vaut aussi pour les **entrepôts** (`warehouses.yaml`), qui utilisent la même table.

## 🎛️ Choisir quand une QRA ou une zone s'active

Deux nouvelles clés dans `mission.yaml`, toutes deux demandées par **Tripack** :

- **QRA en sommeil** — `active_at_start: false` déclare une QRA **sans l'armer** : elle
  attend une commande radio `qra.start` ou un appel de script. *(Jusqu'ici toute QRA était
  armée au chargement de la mission ; la clé était ignorée sans avertissement.)*
- **Zone qui ne s'éteint pas** — `completable: false` empêche une zone de combat de se
  terminer d'elle-même. Indispensable pour une zone **sans unité rouge** : la fin de partie
  se décidant sur le seul décompte des rouges, une telle zone s'activait puis se
  désactivait toute seule au bout d'une minute environ — exactement le symptôme rapporté.

## 🗺️ Aider à collecter les données d'une carte

Les cartes que personne n'a encore relevées peuvent maintenant l'être **par n'importe
qui**, sans outil de développement : un nouveau **kit de capture** est publié à chaque
version, avec les programmes, une mission prête pour chaque carte connue et une procédure
pas-à-pas.

- Téléchargez `veaf-map-capture-kit-<version>.zip` dans les fichiers de cette version.
- Fonctionne aussi sur **n'importe quelle carte** via une mission créée dans l'éditeur DCS.
- Chaque relevé renvoyé enrichit la table pour toute la communauté.

**Cartes déjà relevées :**

- [x] Caucase
- [x] Syrie
- [x] Golfe Persique
- [x] Normandie
- [x] Mariannes
- [x] Sinaï
- [x] Allemagne guerre froide

**Cartes qui restent à relever — si vous en possédez une, votre aide est bienvenue :**

- [ ] Nevada (NTTR)
- [ ] La Manche
- [ ] Atlantique Sud (Malouines)
- [ ] Kola
- [ ] Afghanistan
- [ ] Irak
- [ ] Mariannes 1944

## 🖥️ Serveurs

- **Liste de pilotes partagée retrouvée** : sur un serveur de production, plus aucun pilote
  n'était reconnu (administrateur compris) et toute commande `/…` faisait planter le hook.
  Le fichier partagé est de nouveau lu au bon endroit, un fichier absent est signalé
  clairement au lieu de tout interrompre, et un pilote inconnu se voit refuser la commande
  proprement. **Hook à redéployer.**

## 🙏 Remerciements

Merci à **Tripack**, dont les retours sur les QRA et les zones de combat sont à l'origine
de l'essentiel de cette version, et à tous les **mission makers** de la VEAF qui
continuent de faire remonter ce qui coince.
