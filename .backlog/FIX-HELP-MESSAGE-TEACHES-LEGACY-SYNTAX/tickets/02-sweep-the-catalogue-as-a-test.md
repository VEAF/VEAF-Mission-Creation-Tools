# 02 — livrer le balayage comme test

Status: ✅ done

Partie de [FIX-HELP-MESSAGE-TEACHES-LEGACY-SYNTAX](../PRD.md).

La famille n'est pas « un message qui cite `_ground` », c'est « un message qui **enseigne une commande** ».
Le balayage doit donc énumérer : chaque entrée du catalogue, ses valeurs françaises et anglaises, les jetons
commençant par `_`, croisés avec les mots-clés de marqueur lus dans le code.

Et il doit vivre comme test, pas comme une vérification faite une fois — sinon le prochain message d'aide
écrit avec une syntaxe périmée passera inaperçu.

Un test de plus, celui qui manquait : extraire du message la commande qu'il donne et la passer au parseur.
Un message d'aide qui enseigne une commande que rien n'accepte est un conseil mort.

Fini quand un message enseignant un mot-clé non enregistré fait tomber le balayage.
