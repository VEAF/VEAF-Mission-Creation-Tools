# FIX-HELP-MESSAGE-TEACHES-LEGACY-SYNTAX — le seul message qui apprend une commande apprenait la mauvaise

Status: ✅ done

Repéré en relisant le lot [FEAT-GROUPNAME-PARTIAL-MATCH](../FEAT-GROUPNAME-PARTIAL-MATCH/PRD.md), signalé à
David, qui a demandé un lot à part.

## Le défaut

Quand un ordre s'adresse à un pilote automatique qui n'existe pas, le module répond en disant **comment en
créer un** — c'est le correctif de [FIX-GROUNDAI-SILENT-REFUSALS](../FIX-GROUNDAI-SILENT-REFUSALS/PRD.md),
qui avait remplacé huit silences par des réponses utiles. Sauf que la commande donnée était :

```
_ground set, name arty-1
```

Or [FEAT-GC-MARKER-SYNTAX](../FEAT-GC-MARKER-SYNTAX/PRD.md) a livré `_gc` le même jour et **retiré `_ground`
de la documentation**. La forme reste acceptée pour ne casser aucune mission existante, mais plus une page ne
l'enseigne. Le seul endroit où le produit apprenait encore une commande au pilote lui apprenait donc celle
qu'on venait de retirer — et c'est le pire endroit pour ça : le pilote lit ce message précisément parce qu'il
ne sait pas quoi taper.

## La famille, énumérée

Le défaut se lit « un message qui cite `_ground` », mais la famille est « un message qui **enseigne une
commande** ». Chercher `_ground` n'aurait répondu qu'à la question posée. Le catalogue entier a donc été
balayé : chaque entrée, ses valeurs françaises et anglaises, les jetons commençant par `_`, croisés avec les
mots-clés de marqueur **lus dans le code** plutôt que supposés.

Quatorze mots-clés sont enregistrés (`_auth`, `_cas`, `_destroy`, `_drawing`, `_gc`, `_ground`, `_mm`,
`_move`, `_name point`, `_radio`, `_spawn`, `_teleport`, `_transport`, `_weather`). **Trois** messages sur
tout le catalogue citent une commande :

| Message | Commande citée | Verdict |
|---|---|---|
| `cas.help` | `_cas` | à jour |
| `move.help` | `_move` | à jour |
| `groundai.no_such_handler` | `_ground` | **périmée** |

Hors catalogue, aucun message construit à la main ne cite `_ground` : les neuf autres occurrences dans le code
sont des commentaires, qui documentent volontairement l'ancienne forme.

La famille est donc bien cette ligne, et le balayage est livré comme test — pas comme une vérification faite
une fois.

## Ce qui a changé

Le message dit maintenant `_gc arty-1, set`. Les deux `%s` restent le nom, dans l'ordre où la forme neuve les
attend.

## Les tests, et pourquoi ils ne cherchent plus une chaîne littérale

Deux tests assertaient `said:find("_ground set")`. Une chaîne littérale dans un test ne dit rien de la
**relation** qu'elle est censée garder : elle aurait tout aussi bien survécu à un renommage du mot-clé, le
message restant en arrière sans que rien ne tombe. Ils lisent maintenant `veafGroundAI.ShortKeyphrase` et
`veafGroundAI.MarkerKeyphrase`, donc le message est comparé à ce que le module déclare vraiment.

Et un test de plus, celui qui manquait : la commande que le message donne est **extraite du message** et
passée au parseur, qui doit y lire un `set` sur le bon nom. Un message d'aide qui enseigne une commande que
rien n'accepte est un conseil mort — c'est exactement ce qu'il était.

### Mutations

| Mutation | Résultat |
|---|---|
| le message revient à `_ground set, name %s` *(le bug d'origine)* | 1 échec |
| le message inverse les deux `%s` en `set, %s` | 1 échec |
| le message enseigne un mot-clé inconnu (`_grond`) | 3 échecs |
| une coquille dans le message d'aide d'un **autre** module (`_transprt`) | 1 échec |
| le message cite `_gc` sans verbe (`_gc %s`) | **0 échec — mutant équivalent** |

La quatrième est celle qui compte pour le balayage : une coquille dans le message d'aide de
`veafTransportMission` le fait tomber aussi. C'est ce qui prouve qu'il énumère au lieu de chercher
`_ground`.

Ce que le balayage ne peut pas faire, dit ici pour qu'on ne s'y fie pas trop : la liste des modules à lire
est explicite, parce que Lua ne sait pas parcourir un dossier. Un module futur dont le mot-clé n'y figure pas
verrait son propre message signalé à tort — un faux positif bruyant, pas un silence, ce qui est le bon sens
de l'erreur.

Le mutant `_gc %s` n'est pas un survivant : `_gc arty-1` seul **vaut** `_gc arty-1, set`, la page le dit et le
parseur le fait. Le message reste explicite parce qu'il s'adresse à quelqu'un qui apprend la commande,
mais la mutation produit un message tout aussi juste — il n'y a rien à tuer.

## Definition of done

- [x] Le message enseigne `_gc <nom>, set`
- [x] Les tests comparent le message aux constantes du module, pas à une chaîne écrite en dur
- [x] La commande donnée par le message est prouvée exécutable, en la passant au parseur
- [x] Le balayage du catalogue est un test, pas une vérification ponctuelle
