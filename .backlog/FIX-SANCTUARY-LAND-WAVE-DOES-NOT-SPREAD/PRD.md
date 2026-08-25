# FIX-SANCTUARY-LAND-WAVE-DOES-NOT-SPREAD — deux SAM posés au même endroit

Status: ✅ done

Repéré le 2026-08-24 en relisant le diff de
[`FIX-SANCTUARY-SHIFTED-ALIAS-CALLS`](../FIX-SANCTUARY-SHIFTED-ALIAS-CALLS/PRD.md), consigné comme
**question plutôt que comme défaut** — deux sites SAM au même point avec des caps différents étant une
disposition défendable, puisque le cap décide de l'orientation des rampes. Confirmé non voulu par David le
2026-08-25 : *« non, pas voulu »*.

## Le défaut

`VeafSanctuaryZone:deployDefenses` pose deux pièces par vague, et il y a quatre blocs. Trois les étalent :

| Bloc | 1re pièce | 2e pièce |
|---|---|---|
| eau, 1re vague | rayon 2000, `positionIn20s` | rayon **3000**, `positionIn40s` |
| terre, 1re vague | rayon 2000, `positionIn20s` | rayon **2000**, `positionIn20s` ← l'anomalie |
| eau, vague renforcée | rayon 3000, `positionIn20s` | rayon **4000**, `positionIn40s` |
| terre, vague renforcée | rayon 3000, `positionIn20s` | rayon **4000**, `positionIn40s` |

La première vague terrestre reposait donc **deux fois au même endroit avec le même rayon**, seul le cap
changeant. Les valeurs voulues se lisent dans ses trois voisins : 3000 et `positionIn40s`.

## Les tests portent sur la propriété, pas sur les valeurs

Un test qui vérifie « 3000 » fige le chiffre du jour et ne dit rien de l'intention. Ceux-ci affirment que
**les deux pièces d'une vague diffèrent** — commande différente, position différente, et le second rayon
plus large que le premier — sur les quatre blocs.

Le bloc « eau » garde son test bien qu'il fût déjà juste : c'est ce qui fait échouer l'erreur symétrique,
aligner l'eau sur le mauvais des deux.

### Mutations

| Mutation | Résultat |
|---|---|
| la répétition revient *(le bug d'origine)* | 1 échec |
| seul le rayon répété | 1 échec |
| seule la position répétée | 1 échec |
| la vague « eau » alignée sur le bug | 1 échec |

## Noté, non touché

La première vague terrestre passe `multiplier 2` à ses deux pièces, la vague renforcée terrestre non
(`"radius 3000, skynet false"`). Les deux blocs « eau » le passent partout. C'est peut-être un autre
copier-coller, peut-être un choix — David a confirmé l'asymétrie de rayon et de position, pas celle-ci, et
élargir la correction sans la lui soumettre serait exactement le « hors scope commode » à éviter.

## Definition of done

- [x] Les deux pièces de la première vague terrestre s'étalent, comme dans les trois autres blocs
- [x] Les quatre blocs sous test, sur la propriété et non sur les chiffres
- [x] Le commentaire dit pourquoi 3000 et `positionIn40s`, pour qu'on ne « corrige » pas dans l'autre sens
