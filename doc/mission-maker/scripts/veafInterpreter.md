# veafInterpreter — Commandes embarquées dans les unités


**ID du module :** `INTERPRETER` | **Fichier :** `veafInterpreter.lua`

---

## Objectif

L'interpréteur VEAF permet d'embarquer des commandes VEAF directement dans le nom des unités ou objets statiques de l'éditeur de mission DCS, sans écrire la moindre ligne de Lua. Au démarrage de la mission, l'interpréteur parcourt toutes les unités, détecte les commandes embarquées, les exécute, puis supprime l'unité déclencheuse.

Résultat : toute votre configuration d'apparition (spawn) vit dans l'éditeur DCS sous forme d'unités nommées — pas de scripts, pas de triggers, pas de magie.

---

## Fonctionnement

1. Placez une unité (ou un objet statique) dans l'éditeur de mission DCS, n'importe où sur la carte.
2. Nommez-la avec la balise `#veafInterpreter["command"]` — où `command` est n'importe quelle commande de marqueur VEAF.
3. Une seconde après le démarrage de la mission, l'interpréteur parcourt toutes les unités de la base de données de la mission.
4. Pour chaque unité portant une balise valide, il exécute la commande à la position de cette unité, puis **détruit l'unité** (et son groupe) **si la commande a réussi** — une commande refusée laisse son unité hôte en place.

La position de l'unité devient la position de la commande — parfait pour des configurations de JTAC, des points de passage de convois, ou des emplacements de batteries SAM que vous voulez positionner visuellement dans l'éditeur.

Si l'unité hôte appartient à un groupe doté de **points de passage**, ces points de passage sont transmis aux groupes générés. Les convois et patrouilles générés ainsi suivront la route que vous avez tracée dans l'éditeur.

---

## Convention de nommage des unités

```
#veafInterpreter["<command>"]
```

La balise peut apparaître n'importe où dans le nom de l'unité. Le texte avant et après est ignoré — ce qui est utile pour rendre les noms d'unités uniques quand DCS l'exige :

```
#veafInterpreter["-sa11, side red"] #001
#veafInterpreter["-sa11, side red"] #002
```

Les deux unités portent la même commande mais ont des noms différents.

---

## Syntaxe des commandes

La commande à l'intérieur de la balise utilise la même syntaxe que les marqueurs de la carte F10 — le préfixe `-` suivi d'une commande VEAF et de ses options :

```
-sa11, side red
-jtac, laser 1688
-convoy, dest ZONE-B
-arty, side red
```


!!! warning "Une clé inconnue interrompt la commande"
    Depuis l'unification des analyseurs de marqueurs, un mot-clé que la commande ne connaît pas
    **arrête** l'exécution au lieu d'être ignoré, avec un message proposant la clé la plus proche.
    Une balise `#veafInterpreter` mal orthographiée ne produit donc rien au démarrage — vérifiez
    vos clés dans la [référence des alias](../../ALIASES.md).

Toutes les commandes comprises par le système de marqueurs VEAF fonctionnent ici. Voir la [référence des commandes VEAF](../../LUA_API_REFERENCE.md) pour la liste complète.

---

## Exemples

### JTAC à une position fixe

Placez une unité d'infanterie factice nommée :
```
#veafInterpreter["-jtac, laser 1688"]
```

Au démarrage de la mission, l'interpréteur crée un JTAC à cette position, désignant ses cibles avec le code laser 1688. L'infanterie factice disparaît.

### Batterie SA-11

```
#veafInterpreter["-sa11, side red"]
```

Une batterie SA-11 complète apparaît à la position de l'unité dans l'éditeur. L'alias intègre déjà son intégration Skynet et son espacement ; `side` choisit la coalition.

### Convoi suivant une route tracée dans l'éditeur

1. Dans l'éditeur DCS, créez un groupe terrestre et tracez des **points de passage** de A vers B.
2. Nommez le groupe (ou une unité du groupe) :
   ```
   #veafInterpreter["-convoy, dest ZONE-B, size 8, defense 1, patrol"]
   ```
3. Au démarrage de la mission, l'interpréteur crée un convoi à la position du groupe, suivant la route tracée. Le groupe d'origine est détruit.

   `dest` est **obligatoire** pour un convoi : c'est le point nommé vers lequel il roule. `size` est le nombre de véhicules (défaut 10).

### Plusieurs sites SAM avec des noms uniques

```
#veafInterpreter["-sa10, side red"] NORTH-01
#veafInterpreter["-sa10, side red"] NORTH-02
#veafInterpreter["-sa6, side red"]  SOUTH-01
```

### Artillerie en position défensive

```
#veafInterpreter["-arty, side red, spacing 2"]
```

---

## Configuration

L'interpréteur ne nécessite aucune configuration par mission. Le seul réglage est le délai de démarrage :

```lua
-- À changer avant l'appel à initialize() (défaut : 1 seconde)
veafInterpreter.DelayForStartup = 3
```

Augmentez cette valeur si votre mission charge de nombreux scripts en parallèle et que l'interpréteur se déclenche avant que les autres modules ne soient prêts.

---

## Astuces

- Utilisez un type d'unité visuellement représentatif pour bien voir les positions d'apparition dans l'éditeur (par exemple un soldat pour un JTAC, un type de radar SAM pour un élément d'IADS).
- L'activation différée (*late-activation*) n'est pas requise pour les unités portant des balises d'interpréteur — VEAF les détruira de toute façon, mais l'activation différée évite qu'elles n'apparaissent brièvement en jeu.
- L'interpréteur effectue un balayage unique. Il ne se relance pas pendant la mission.

---

## Voir aussi

- [veafSpawn](veafSpawn.md) — commandes d'apparition manuelles
- [veafCombatZone](veafCombatZone.md) — zones activables (la balise `#command` dans les noms d'unités utilise le même mécanisme)
- [Référence de l'API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafInterpreter`
