# 01 — enseigner la syntaxe documentée

Status: ✅ done

Partie de [FIX-HELP-MESSAGE-TEACHES-LEGACY-SYNTAX](../PRD.md).

`groundai.no_such_handler` apprend au pilote `_ground set, name %s`, la forme retirée de la documentation le
même jour où `_gc` a été livré. Le message devient `_gc %s, set`.

Les deux tests qui assertaient la chaîne `_ground set` doivent lire `veafGroundAI.ShortKeyphrase` et
`veafGroundAI.MarkerKeyphrase` : une chaîne écrite en dur aurait survécu à un renommage du mot-clé en
laissant le message en arrière.

Fini quand remettre `_ground set, name %s` fait tomber un test.
