# 01 — un enregistrement par mot-clé

Status: ✅ done

Partie de [FIX-GC-NEVER-REACHES-THE-MODULE](../PRD.md).

`veafCommands.registerCommandHandler` prend un filtre de mot-clé, et il n'accepte qu'une chaîne. Enregistrer
le gestionnaire de marqueur **deux fois**, un filtre par mot-clé (`_ground` et `_gc`), plutôt qu'élargir
`handlesText` à une liste pour un seul module.

Puis des tests qui interrogent les filtres déclarés, pas le gestionnaire — c'est le seul endroit d'où le
défaut était visible.

Fini quand retirer le second enregistrement fait tomber un test.
