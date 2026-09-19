# Coalitions et pays

Quatre messages qui parlent de la même chose : **qui appartient à quel camp** dans votre mission.
Deux d'entre eux annoncent une mission que DCS refusera de charger, ce qui en fait les plus urgents
de toute la documentation.

## Pourquoi il y a deux tables, et pas une {#two-tables}

Un `.miz` décrit l'appartenance des objets **deux fois**, dans deux tables qui ne se parlent pas :

- `coalition.<camp>.country[…]` — les objets eux-mêmes. Chaque pays y porte ses avions, ses
  hélicoptères, ses véhicules, ses navires et ses objets statiques.
- `coalitions.<camp>` — la liste des ids de pays que ce camp possède. Rien d'autre : une liste de
  nombres.

Dans l'éditeur DCS vous ne voyez jamais cette séparation. Vous posez un objet, vous choisissez un
pays, et l'éditeur remplit les deux. Mais un outil qui injecte des groupes — y compris VMCT — écrit
la première et peut oublier la seconde. C'est exactement ce que ces contrôles cherchent.

`<camp>` vaut `red`, `blue` ou `neutrals`. Le contrôle est fait **camp par camp**.

## Des pays possèdent des unités sans figurer dans la liste du camp {#validate-side-missing-countries}

> Camp 'red' : les pays [68 (USSR)] possèdent des unités mais ne figurent pas dans coalitions.red
> ([0 (Russia), 81 (Combined Joint Task Forces Red)]) : DCS ouvrira l'écran d'affectation des
> coalitions et refusera de charger la mission. Ajoutez ces ids de pays — le nombre seul, sans le
> nom — dans coalitions.red, ou réaffectez les objets concernés à un pays déjà listé.

**Dans l'éditeur.** Vous avez des objets rouges appartenant à l'URSS, mais le camp rouge de la
mission ne déclare que la Russie et Combined Joint Task Forces Red. DCS ne sait pas quoi faire de
ces objets : au chargement il ouvre l'écran **CHANGING COALITIONS** et s'arrête là.

Un id que DCS ne connaît pas est affiché **seul**, sans nom entre parenthèses. C'est déjà une
information : la mission contient un pays qui n'existe pas dans cette version du jeu.

**Comment le reproduire.** Le plus simple est de partir d'un dossier neuf et de faire injecter des
groupes par le build : c'est le chemin qui produisait le défaut avant la correction. Un objet posé
à la main dans l'éditeur ne le produit pas, l'éditeur tenant les deux tables à jour.

**Les deux issues, et ce qui les départage.** Le message imprime **les deux** listes exprès, parce
que le choix se fait en les comparant :

| Issue | Quand la préférer | Ce qu'elle coûte |
|---|---|---|
| Ajouter l'id manquant dans `coalitions.<camp>` | Le pays est voulu — c'est un choix de scénario | Rien, mais il faut éditer la table |
| Réaffecter les objets à un pays déjà listé | Le pays est arrivé par accident, ou l'un des deux suffit | Passer les objets en revue dans l'éditeur |

**Où l'on corrige, et où l'on ne corrige pas.** Pas dans `mission.yaml` : ce fichier n'a **pas** de
clé `coalitions`, et chercher à l'y ajouter ne fera rien du tout. La table vit dans la mission
elle-même, donc soit :

- dans l'**éditeur DCS** — ouvrez le `.miz`, faites que le pays manquant soit bien présent dans le
  camp, enregistrez, puis ré-extrayez le dossier de mission ;
- dans le fichier `src/mission/mission` de votre dossier, à la clé `coalitions` — c'est la table
  DCS décompressée. On y écrit **le nombre seul**, `68`, jamais `68 (USSR)` : le nom n'est là que
  pour vous.

**Ce que ce n'est pas.**

- **Ce ne sont pas vos objets statiques neutres.** C'est la fausse piste qui a coûté le plus cher
  jusqu'ici, et elle est à moitié fondée, ce qui la rend tenace : les objets statiques **comptent
  bien** comme des unités pour ce contrôle, exactement comme un véhicule. Mais un objet *neutre*
  appartient au camp `neutrals`, et le contrôle est fait camp par camp. Un message qui dit `red`
  ne peut parler que d'un objet rouge.
- **Ce n'est pas un pays vide.** Un pays qui ne possède aucun objet n'a jamais besoin d'être
  listé — DCS s'en moque, et le contrôle le laisse tranquille.
- **Ce n'est pas un échec du build.** Le `.miz` a bien été écrit. Il ne se chargera simplement pas.

## Un camp n'a aucun pays affecté {#validate-side-without-country}

> Le camp 'blue' contient des unités mais aucun pays ne lui est affecté : DCS ouvrira l'écran
> d'affectation des coalitions et refusera de charger la mission. Ajoutez l'id du pays dans
> coalitions.blue.

Le cas extrême du précédent : la liste du camp est entièrement vide alors qu'il possède des objets.
Les issues et l'endroit où corriger sont les mêmes.

**Comment le reproduire.** C'était le comportement d'une mission créée avec `prepare --theatre` :
la mission vierge générée laissait `coalitions = { blue = {}, red = {}, neutrals = {} }`, et les
étapes suivantes du build y ajoutaient des groupes sans jamais toucher à ces listes. Corrigé depuis
dans les injecteurs, mais une mission produite avant l'est restée.

**Ce que ce n'est pas.** Pas la même chose qu'un camp sans aucune unité : celui-là ne déclenche
rien, et a même son propre message ci-dessous.

## Un groupe au sol caché a été injecté {#builder-coalition-placeholder-injected}

> La coalition 'blue' n'avait aucune unité — un groupe sol placeholder caché a été injecté pour que
> DCS la reconnaisse (plus besoin de groupe sol manuel).

**Tout va bien.** Ce message annonce un service rendu, pas un problème.

**Dans l'éditeur.** DCS purge les pays qui ne possèdent rien, et un camp entièrement vide finit par
disparaître de la mission — ce qui casse tout ce qui s'y réfère au runtime. La parade classique
était de demander au créateur de poser « un groupe sol bleu et un rouge » à la main quelque part.
Le build le fait maintenant tout seul, sur le bullseye du camp, avec un groupe invisible.

**Ce que ce n'est pas.** Ce groupe n'apparaît pas en jeu, ne compte dans aucun objectif et ne
déclenche rien. Vous n'avez rien à faire, et surtout rien à supprimer.

## Un `country` de coalition a une forme inattendue {#builder-coalition-country-unexpected}

> Un 'country' de coalition n'est ni une liste ni une table (reçu str) ; il est ignoré et le camp
> est considéré comme vide.

**Rare, et ça veut dire que la mission a été abîmée.** La table `coalition.<camp>.country` doit être
une liste de pays ; le build en a trouvé autre chose — le plus souvent après une édition à la main
du fichier `src/mission/mission`, ou le passage d'un outil tiers.

**Que faire.** Rouvrez la mission dans l'éditeur DCS et ré-enregistrez-la : DCS réécrit ses tables
dans la forme qu'il attend. Si vous avez édité `src/mission/mission` à la main, revenez à la
version précédente. Voir aussi [les tables trouées](routes-and-tables.md#validate-holed-sequence),
qui relèvent de la même famille de dégâts.

## La table des pays DCS {#country-ids}

Les messages affichent désormais le nom à côté de l'id, mais un journal ancien, un `.miz` ouvert à
la main ou la table `coalitions` elle-même ne contiennent que des nombres. Voici la correspondance
complète.

> **Il n'y a pas de pays à l'id 14.** Ce n'est pas une erreur de cette table : DCS a réellement un
> trou à cet endroit.

| id | Pays | id | Pays | id | Pays | id | Pays |
|---|---|---|---|---|---|---|---|
| 0 | Russia | 24 | Belarus | 47 | Syria | 70 | Algeria |
| 1 | Ukraine | 25 | Bulgaria | 48 | Yemen | 71 | Kuwait |
| 2 | USA | 26 | Czech Republic | 49 | Vietnam | 72 | Qatar |
| 3 | Turkey | 27 | China | 50 | Venezuela | 73 | Oman |
| 4 | UK | 28 | Croatia | 51 | Tunisia | 74 | United Arab Emirates |
| 5 | France | 29 | Egypt | 52 | Thailand | 75 | South Africa |
| 6 | Germany | 30 | Finland | 53 | Sudan | 76 | Cuba |
| 7 | USAF Aggressors | 31 | Greece | 54 | Philippines | 77 | Portugal |
| 8 | Canada | 32 | Hungary | 55 | Morocco | 78 | GDR |
| 9 | Spain | 33 | India | 56 | Mexico | 79 | Lebanon |
| 10 | The Netherlands | 34 | Iran | 57 | Malaysia | 80 | Combined Joint Task Forces Blue |
| 11 | Belgium | 35 | Iraq | 58 | Libya | 81 | Combined Joint Task Forces Red |
| 12 | Norway | 36 | Japan | 59 | Jordan | 82 | United Nations Peacekeepers |
| 13 | Denmark | 37 | Kazakhstan | 60 | Indonesia | 83 | Argentina |
| 15 | Israel | 38 | North Korea | 61 | Honduras | 84 | Cyprus |
| 16 | Georgia | 39 | Pakistan | 62 | Ethiopia | 85 | Slovenia |
| 17 | Insurgents | 40 | Poland | 63 | Chile | 86 | Bolivia |
| 18 | Abkhazia | 41 | Romania | 64 | Brazil | 87 | Ghana |
| 19 | South Ossetia | 42 | Saudi Arabia | 65 | Bahrain | 88 | Nigeria |
| 20 | Italy | 43 | Serbia | 66 | Third Reich | 89 | Peru |
| 21 | Australia | 44 | Slovakia | 67 | Yugoslavia | 90 | Ecuador |
| 22 | Switzerland | 45 | South Korea | 68 | USSR | 91 | Afghanistan |
| 23 | Austria | 46 | Sweden | 69 | Italian Social Republic | 92 | New Zealand |

## Pour aller plus loin {#more}

- [Les messages du build](README.md) — les autres familles
- [Le dossier de mission](../concepts/mission-folder.md) — où vit `src/mission/mission`
- [Obtenir de l'aide](../../SUPPORT.md)
