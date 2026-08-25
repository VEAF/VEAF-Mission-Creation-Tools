# 01 — la syntaxe `_gc`

Status: ✅ done

Partie de [FEAT-GC-MARKER-SYNTAX](../PRD.md).

Étendre `veafGroundAI.MarkerSpec` :

- une commande `match = "_gc"`, déclarée **après** les sept `_ground <verbe>` pour qu'un nom de groupe
  contenant `_gc` ne détourne pas une ancienne commande ;
- une règle de paramètre sur la clé `_gc` qui range sa valeur dans `options.name` ;
- une règle par verbe (`set`, `unset`, `start`, `stop`, `clear`, `status`, `aim`, `fire`, `correct`,
  `correction`), chacune posant `options.verb` — et, pour `aim`/`fire`/`correct`/`correction`, rangeant
  sa valeur en ligne dans `options.target` ou `options.correction` ;
- `target`, `shells`, `radius` remontés au niveau du marqueur.

Puis extraire de `ArtilleryUnitHandler:orderTextAnalysis` la partie qui exécute l'ordre, pour que la
forme à plat et l'ancienne forme partagent le même code plutôt que d'en avoir deux copies.

Fini quand les deux formes marchent, que les mutations sur le routage tuent des tests, et que la doc
n'enseigne que la nouvelle.
