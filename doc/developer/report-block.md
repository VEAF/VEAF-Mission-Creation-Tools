# `veaf-logs` — format du bloc de rapport

> **Public visé** : les développeurs des lots qui produisent ou consomment le bloc collable de
> `veaf-logs` — l'analyse de journal (`FEAT-SUPPORT-LOG-ANALYSIS`) qui l'écrit, et la prise en charge
> de signalement (`FEAT-SUPPORT-BUG-INTAKE`) qui le relit.
>
> **Schéma : `veaf-logs-report/1`.** — 🇬🇧 [`report-block.en.md`](report-block.en.md).

## Pourquoi un second format {#why}

Le [bloc de `doctor`](diagnostic-block.md) décrit **la machine**. Celui-ci décrit **le problème** :
ce que l'utilisateur regardait, ce que le catalogue en a dit, et ce que personne n'a su expliquer.
Il *contient* le bloc de `doctor`, il ne le remplace pas.

Comme lui, il voyage à travers Discord ou une issue GitHub, collé à la main par quelqu'un qui ne le
relira pas, et il est relu par une machine à l'autre bout. C'est donc un **contrat**, versionné, que
ni le producteur ni les consommateurs ne peuvent changer seuls.

L'implémentation vit dans `src/python/veaf-tools/veaf_logs/report.py`, producteur (`build_report`) et
lecteur (`parse_report_block`) dans le même module — pour qu'ils ne puissent pas diverger — et le
test d'aller-retour est dans `test/python/veaf_logs/test_report.py`.

## Structure {#structure}

```text
=== VEAF-LOGS REPORT BEGIN ===
schema: veaf-logs-report/1
generated: 2026-09-05T09:39:29Z
excerpt.shown: 42
excerpt.selected: 3356
excerpt.total: 87989
excerpt.omitted: 3314
excerpt.excluded: levels=DEBUG,INFO,TRACE
catalogue.matched: damage_model,payload_weight
catalogue.uncatalogued: 24
proposals.count: 2
truncated: sections retirées pour tenir dans un message : proposals, analysis
--- doctor ---
=== VEAF-TOOLS DOCTOR BEGIN ===
schema: veaf-tools-doctor/1
...
=== VEAF-TOOLS DOCTOR END ===
--- doctor end ---
--- excerpt ---
[veaf-logs] 42 entrées sur 87989 indexées (3356 retenues, 3314 omises par la limite de taille)
masqué (✕) — niveaux : DEBUG, INFO, TRACE
16:28:35.388 ERROR      ED_SOUND     can't load proto file "/sounds/54/sdef/..."
--- excerpt end ---
--- catalogue ---
Motifs connus (texte du catalogue, tel quel) :
- Modèle de dégâts corrompu (damage_model) ×3 : Modules tiers dont le modèle de dégâts...
--- catalogue end ---
=== VEAF-LOGS REPORT END ===
```

Quatre règles, et rien d'autre :

1. Le bloc est délimité par `=== VEAF-LOGS REPORT BEGIN ===` et `=== VEAF-LOGS REPORT END ===`.
   Il **arrive au milieu d'autre chose** : un lecteur cherche ces deux lignes, il ne suppose pas que
   le bloc commence à la première ligne. Il est habituellement entouré d'une barrière de code
   ` ```text ` ; les trois accents graves qui pourraient se trouver dans le contenu sont remplacés
   par trois apostrophes, faute de quoi ils fermeraient la barrière trop tôt.
2. Entre les deux délimiteurs, et **en dehors des sections**, chaque ligne est `clef: valeur`, sur
   le premier `:`, sur une seule ligne. Même règle que pour le bloc de `doctor`, et pour la même
   raison : une valeur multi-lignes reviendrait sous la forme de deux champs, dont un que personne
   n'a écrit.
3. Une section est encadrée par `--- <nom> ---` et `--- <nom> end ---` et contient du **texte brut**.
   Les noms sont ceux de `SECTIONS` : `doctor`, `excerpt`, `catalogue`, `analysis`, `proposals`.
   Une section vide n'est pas écrite du tout — son absence est une information, pas un oubli.
4. La section `doctor` porte un bloc complet au format `veaf-tools-doctor/1`, délimiteurs compris.
   Les deux jeux de délimiteurs sont volontairement différents : un lecteur qui cherche l'un ne
   tombe jamais sur l'autre, et le bloc imbriqué se relit avec `parse_block` sans précaution
   particulière.

## Les champs {#fields}

L'ordre est celui de `FIELD_ORDER` dans `report.py`, et il est stable.

| Clef | Exemple | Ce qu'elle dit |
|---|---|---|
| `schema` | `veaf-logs-report/1` | à vérifier **avant** de lire quoi que ce soit d'autre |
| `generated` | `2026-09-05T09:39:29Z` | quand le bloc a été produit, en UTC |
| `excerpt.shown` | `42` | entrées réellement présentes dans la section `excerpt` |
| `excerpt.selected` | `3356` | entrées que les filtres retenaient, avant la limite de taille |
| `excerpt.total` | `87989` | entrées indexées dans le journal — le dénominateur |
| `excerpt.omitted` | `3314` | entrées retenues mais écartées par la limite de taille |
| `excerpt.excluded` | `levels=DEBUG,INFO` | catégories mises à ✕, ou `aucune` |
| `catalogue.matched` | `damage_model,...` | identifiants des entrées de `rules.json` reconnues, ou `aucun` |
| `catalogue.uncatalogued` | `24` | entrées que le catalogue n'explique pas |
| `proposals.count` | `2` | motifs récurrents non catalogués repérés |
| `truncated` | `non` | ou la liste des sections retirées, ou `OUI — …` |

`excerpt.excluded` est le champ à lire en premier après le schéma : il dit ce que l'extrait **ne
peut pas** contenir. Un rapport où `catalogue.uncatalogued` vaut 0 et où `excerpt.excluded` cite
`ERROR` ne décrit pas un journal propre, il décrit un journal dont on a masqué les erreurs.

## Ce qui se passe quand ça ne rentre pas {#truncation}

Le bloc est construit pour tenir dans un message Discord — 2 000 caractères, barrière de code
comprise. L'extrait complet en fait plus de dix fois autant : mesuré le 05/09/2026 sur un `dcs.log`
de 11,1 Mo (87 989 entrées), l'extrait par défaut se rend en ~16 000 caractères.

L'ordre de sacrifice est donc fixe, et il est asymétrique :

1. `proposals`, puis `analysis`, puis `catalogue` sont retirées **en entier** ;
2. l'extrait est ensuite **réduit** à la place qui reste, jamais supprimé tant qu'il reste de quoi
   montrer quelques lignes ;
3. en dernier recours, les enregistrements d'erreur du bloc `doctor` partent, mais **jamais ses
   champs** : c'est la moitié du rapport que personne ne peut reconstituer après coup.

Le champ `truncated` nomme ce qui est parti à chaque étape. Un bloc coupé au ras de la limite se lit
comme un bloc complet chez celui qui le reçoit : il n'y en a donc pas.

## Caviardage {#redaction}

Le bloc est caviardé **assemblé**, pas seulement morceau par morceau. Les deux ne sont pas
équivalents : l'extrait est déjà caviardé à sa construction, mais le commentaire du modèle arrive du
réseau et n'est passé nulle part ailleurs. Le caviardage est celui de
[`veaf_libs.redaction`](diagnostic-block.md#redaction) — le seul du projet, et il est idempotent, si
bien qu'un second passage sur des morceaux déjà traités n'abîme rien.

## Ce que le lecteur doit supposer {#untrusted}

**Rien.** Le bloc voyage dans une issue publique et n'importe qui peut en taper un à la main. Le
producteur garantit la *forme* — un champ, une ligne — jamais la vérité d'une valeur. Un consommateur
qui agit sur `excerpt.total` traite une affirmation, pas une mesure prise sur la machine.

`parse_report_block` lève `ValueError` sur un bloc absent ou sans délimiteur de fin — un collage
tronqué, qu'il faut signaler plutôt que lire à moitié. Une section restée ouverte est en revanche
rendue avec ce qui a été lu : perdre le contenu en plus de la fin serait doublement pénalisant.
