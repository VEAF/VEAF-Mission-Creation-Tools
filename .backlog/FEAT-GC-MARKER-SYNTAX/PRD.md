# FEAT-GC-MARKER-SYNTAX — parler au commandant au sol comme on parle à la radio

Status: ✅ done

Demandé par David le 2026-08-25, en jeu, après avoir buté sur le point-virgule : *« j'aime vraiment pas
le point virgule dans les commandes _ground »*, puis la forme qu'il veut —
`_ground <unit>, <order>, <parameters>` — et *« "_ground" c'est pour "ground commander" ; on pourrait
mettre "_gc" ça serait bien non ? »*.

## Pourquoi le point-virgule existe

Le parseur découpe le texte du marqueur **à chaque virgule**, puis lit chaque morceau comme « un mot-clé,
puis sa valeur ». Donc dans :

```
_ground order, name arty-1, order aim; target 37T FH 73551 47565
```

la valeur du mot-clé `order` est `aim; target 37T FH 73551 47565` — une commande entière, que l'artillerie
recoupe ensuite. Écrire une virgule à la place du point-virgule produit un quatrième morceau, `target
37T…`, que le marqueur ne connaît pas : mesuré, la cible arrive à `nil` et rien ne se passe.

Le point-virgule n'est donc pas un choix de style : c'est **le seul séparateur qui survit au premier
découpage**. Ce qui le rend inutile, c'est que le marqueur connaisse lui-même les mots de l'ordre.

## La forme retenue

```
_gc <nom>, <verbe>[ <valeur>], <paramètre valeur>, ...
```

| Ce qu'on écrit | Ce que ça fait |
|---|---|
| `_gc arty-1` *(marqueur sur la batterie)* | crée le pilote automatique depuis le groupe le plus proche |
| `_gc arty-1, groupname ARTY-1` | idem, en nommant le groupe |
| `_gc arty-1, aim 37T FH 73551 47565` | tir de réglage sur cette grille |
| `_gc arty-1, correction 09050` | décale de 50 m à l'est et retire |
| `_gc arty-1, fire, shells 40-80, radius 50-150` | tir d'efficacité au dernier point visé |
| `_gc arty-1, status` / `stop` / `clear` / `unset` | consulte, arrête, efface, oublie |

Le destinataire d'abord, comme à la radio. Plus de `name`, plus de `order`, plus de `target`, plus de
point-virgule.

## Ce que la mesure a autorisé

- **`_gc` est libre.** Aucun des treize mots-clés de marqueur VEAF ne commence par `_gc`, et `_gc` n'est
  le préfixe d'aucun autre — `_ground` inclus.
- **Aucune collision de vocabulaire.** Les verbes de l'ordre (`aim`, `fire`, `correct`) et ses paramètres
  (`target`, `shells`, `radius`, `correction`) ne recoupent aucun verbe ni paramètre du marqueur.
- **Le moteur du parseur n'a pas à changer.** Il lit déjà « premier mot = clé, le reste = valeur », donc le
  mot-clé lui-même (`_gc`) devient la clé dont la valeur est le nom de l'unité. Rien à toucher dans
  `veaf.parseMarkerText`.

## Compatibilité

`_ground` et l'ancienne forme restent acceptés, **sans être documentés**. Décidé avec David : le coût est
d'une ligne, et on ne sait pas ce que les serveurs VEAF ou d'autres créateurs ont écrit dans leurs
missions. Les 13 alias livrés qui écrivent `_ground` passent à la nouvelle forme dans ce lot — ils sont à
nous.

## Un mensonge de la documentation, trouvé au passage

La page affirme : « Écrire `_ground` seul revient à écrire `_ground set` ». **C'est faux** — mesuré :
`_ground, name arty-1` est refusé (`nil`), parce qu'aucune commande du spec ne correspond. Seul
`_ground set` marche. Avec `_gc`, la forme courte fonctionne vraiment, et la page doit le dire
correctement.

## Definition of done

- [x] `_gc <nom>, <verbe>…` marche pour les sept verbes
- [x] `aim`, `fire` et `correction` acceptent leur valeur en ligne — et `correct` aussi bien que
      `correction`, pour ne pas avoir à s'en souvenir sous le feu
- [x] `_gc <nom>` seul vaut `set`, et un test le prouve
- [x] `_ground` et l'ancienne forme marchent encore, avec des tests qui tomberaient si on les cassait —
      dont un de bout en bout, parce que « ça se lit » et « ça tire » sont deux choses
- [x] Les 15 définitions d'alias passent à la nouvelle forme, et un test lit `veafShortcuts.lua` pour
      vérifier qu'aucune n'écrit plus `_ground`
- [x] La page du module, dans les deux langues — une seule mention de `_ground` subsiste par page, la
      note d'héritage, et l'affirmation fausse est corrigée

## Ce que le travail a donné

**Le moteur du parseur n'a pas bougé d'une ligne.** Il lit déjà « premier mot = clé, le reste = valeur »,
donc le mot-clé lui-même devient la clé dont la valeur est le nom : `_gc arty-1` se lit « clé `_gc`,
valeur `arty-1` ». C'est ce qui supprime le mot `name` sans toucher au code partagé.

**Un détail d'ordre qui n'est pas cosmétique.** Les commandes sont cherchées comme un morceau de texte
n'importe où, première trouvée gagne. Un groupe nommé `x_gcy` dans un ancien `_ground stop, name x_gcy`
contient `_gc` : déclarer l'entrée `_gc` avant les sept `_ground <verbe>` détournerait la commande. Elle
est déclarée en dernier, et une mutation qui la remonte tue un test.

**Un seul `executeOrder` pour les deux syntaxes.** L'ancienne forme recoupe une chaîne avant d'y arriver,
la neuve y arrive à plat. Deux copies de ce routage divergeraient, et le symptôme serait un ordre qui
marche dans une syntaxe et pas dans l'autre.

### Mutations

| Mutation | Résultat |
|---|---|
| la clé `_gc` ne range plus le nom | 9 échecs, 11 erreurs |
| `aim` ne pose plus `orderVerb` | 2 échecs, 2 erreurs |
| le routage à plat retiré | 1 échec, 3 erreurs |
| `aim` ne valide plus sa cible | 2 échecs |
| `_gc` déclaré **avant** les `_ground` | 1 échec |
| l'ancienne forme ne route plus | 1 échec |

Une mutation n'a rien tué au départ : retirer la validation de la cible dans `aim` passait tout, parce que
je n'avais testé la validation que pour `correction`. Trois tests de plus l'ont fermée — `aim`, `fire` et
la forme longue `target`.

## Un mensonge de la documentation, corrigé

La page affirmait : « Écrire `_ground` seul revient à écrire `_ground set` ». Mesuré : `_ground, name
arty-1` est **refusé**, parce qu'aucune commande du spec ne correspond. Avec `_gc`, la forme courte marche
vraiment — et un test le prouve, ce qui est toute la différence entre une promesse et un comportement.
