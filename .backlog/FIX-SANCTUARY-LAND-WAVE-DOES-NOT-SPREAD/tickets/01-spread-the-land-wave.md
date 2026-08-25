# 01 — étaler la première vague terrestre

Status: ✅ done

Partie de [FIX-SANCTUARY-LAND-WAVE-DOES-NOT-SPREAD](../PRD.md).

Le second appel de la première vague terrestre passe `radius 3000` et `positionIn40s`, comme ses trois
blocs voisins, au lieu de répéter `radius 2000` et `positionIn20s`.

Puis des tests sur la **propriété** — les deux pièces d'une vague diffèrent, le second rayon est plus large
— appliqués aux quatre blocs, y compris ceux qui étaient déjà justes.

Fini quand remettre la répétition fait tomber un test, et quand aligner le bloc « eau » sur le bug en fait
tomber un aussi.
