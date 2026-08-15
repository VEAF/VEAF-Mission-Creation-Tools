# `veaf-tools mission export` — contrat JSON pour le plugin BFR `dcs-mission-tools`

> **Public visé** : les développeurs du plugin Claude BFR `dcs-mission-tools`
> ([bfr-claude-plugins](https://github.com/Bullseye-Francophone/bfr-claude-plugins)) qui consomment
> `veaf-tools mission export --format json` au lieu d'exécuter les fichiers mission via `lua54`.
> Ce document est le **contrat figé** entre les deux outils.
>
> **schemaVersion : 2.** — 🇬🇧 [`export-json-contract.en.md`](export-json-contract.en.md).

## Pourquoi ce contrat

`veaf-tools` parse les fichiers `mission` / `dictionary` / `mapResource` d'un `.miz` avec une machine
à états **pur-Python** `luadata` — il **n'exécute jamais de Lua** (`luadata/serializer/unserialize.py`).
Exporter ce parse en JSON permet au plugin de lire **n'importe quelle** mission (un `.miz` venu d'un
forum, d'un DM, un dossier extrait) sans exécuter de Lua non fiable. Le plugin ne garde `lua54` **que**
pour exécuter ses propres checks `.lua`.

Le seul problème dur est de mapper fidèlement les **tables Lua** vers le **JSON** et retour. Les clés
d'un object JSON sont **toujours des strings** : un object JSON ne peut donc pas distinguer une clé
**entière** Lua d'une clé **string** Lua — or DCS a les deux, parfois dans la *même* table :

- **clés entières sparse** — `payload.pylons = {[1]=,[2]=,[8]=,[11]=}` (numéros de pylônes avec trous) ;
- **clés mixtes** — `callsign = {[1]=,[2]=,[3]=,["name"]="Colt11"}` ;
- **clés string-numériques** — `failures = {["10"]=,["11"]=}` (les ids de panne DCS sont des strings).

Une heuristique qui « coerce les clés string-numériques en entiers » est donc **impossible à rendre
universellement correcte** : elle casse `failures` (vraies strings), tandis qu'une règle « clés
toujours string » casse `pylons` et la partie entière de `callsign`. Le contrat ci-dessous supprime
toute devinette en **préservant le type de clé dans le JSON lui-même**, via la distinction native
nombre-vs-string du JSON.

## 1. Forme de premier niveau

```json
{
  "schemaVersion": 2,
  "theatre": "Caucasus",
  "mission": { "...": "la table `mission` parsée" },
  "dictionary": { "DictKey_...": "..." },
  "mapResource": { "ResKey_...": "fichier.lua" }
}
```

- `schemaVersion` (entier) — **toujours présent, en tête**, actuellement **2**. Voir §5.
- `theatre` — string (ou `null` si absent).
- `mission`, `dictionary`, `mapResource` — les tables parsées, mappées selon §2. `dictionary` et
  `mapResource` sont des maps string→string et sérialisent toujours en **object** JSON.

## 2. Règle de mapping des tables (déterministe, sans perte du type de clé)

Pour chaque table Lua, exactement une de ces formes est émise :

| Table Lua | Forme JSON | Quand |
|---|---|---|
| **Séquence** | **array** JSON | clés = entiers contigus `1..n` (n ≥ 1) |
| **Record string** | **object** JSON | toutes les clés sont des strings |
| **Table entière / mixte** | **enveloppe `__luaTable__`** | au moins une clé entière, et pas une séquence pure |
| **Vide** | `{}` JSON | aucune clé (neutre pour la parité, voir §3) |

L'enveloppe est un object à clé unique dont la valeur est une liste de paires `[clé, valeur]` :

```json
{ "__luaTable__": [ [1, "..."], [2, "..."], [8, "..."], ["name", "..."] ] }
```

Chaque **clé de paire** est un **nombre JSON** pour une clé entière Lua, une **string JSON** pour une
clé string Lua. La distinction nombre/string propre au JSON porte le type : le décodeur ne devine
jamais. Garanties :

- Les clés de paire entières sont des **entiers JSON** (`1`, jamais `1.0`) — une clé entière Lua, pas
  un float.
- Chaque paire est un array JSON de **exactement deux** éléments ; `pair[0]` est **uniquement** un
  nombre ou une string.

### Exemples travaillés

```json
"trigrules": [ {"comment": "init"}, {"comment": "win"} ],
"trig": { "actions": [ "a_do_script(...)" ], "flag": [ true ] },
"pylons":   { "__luaTable__": [[1,"AIM-9"],[2,"AIM-120"],[8,"fuel"],[11,"AIM-9"]] },
"callsign": { "__luaTable__": [[1,169],[2,1],[3,1],["name","Colt11"]] },
"failures": { "10": {"enable": false}, "11": {"enable": true} }
```

Les séquences indexées numériquement (`trigrules`, `trig.actions/conditions/flag`, groupes/pays/zones)
restent des arrays, donc `#t` / `ipairs` marchent après décodage. `failures` reste un object à clés
string — **jamais coercé**.

## 3. Tables vides

Une table Lua vide `{}` exporte en `{}` JSON. C'est **neutre pour la parité** : un `{}` JSON et un `[]`
JSON décodent tous deux vers une table Lua vide où `#t == 0` et `next(t) == nil`. Le décodeur doit
produire une table Lua vide pour **les deux**.

## 4. Scalaires, strings, encodage

- Nombres Lua → nombres JSON ; booléens Lua → `true`/`false` JSON.
- Strings Lua → strings JSON, **UTF-8, non échappées en ASCII** (`ensure_ascii=false`).
- Les valeurs absentes / `nil` ne sont pas présentes (`theatre` peut valoir `null`).
- **L'ordre des clés / paires n'est pas significatif** ; les décodeurs ne doivent pas en dépendre.

## 5. `schemaVersion` et compatibilité

- `schemaVersion` est un entier, **incrémenté à tout changement cassant** du contrat. Le plugin
  **doit** le lire et refuser / avertir sur une version inconnue plutôt que de mal lire en silence.
- Version actuelle : **2** (la v1 utilisait une heuristique de coercition des clés string-numériques,
  retirée).

## 6. Exigences du décodeur (résumé, côté plugin)

Un décodeur JSON→Lua conforme :

1. **array** JSON → séquence Lua à clés entières `1..n`.
2. **object** JSON *sans* clé unique `__luaTable__` → table Lua avec les clés **verbatim en string**
   (pas de coercition numérique — c'est ce qui garde `failures` correct).
3. **object** JSON dont la *seule* clé est `__luaTable__` et dont la valeur est une liste de paires à
   2 éléments → table Lua construite depuis les paires : `pair[0]` de type JSON *nombre* → clé entière,
   *string* → clé string ; `pair[1]` décodé récursivement. (Durcir contre la collision de sentinelle en
   exigeant exactement cette forme ; sinon, traiter l'object comme un record verbatim.)
4. array vide **et** object vide → table Lua vide.

Avec ces règles, les tables décodées reproduisent la sortie `load()` **table pour table** (array-ness
*et* types de clés), donc les checks du plugin rendent des findings identiques — et restent corrects
pour les *futurs* checks qui liront des tables que les checks d'aujourd'hui ignorent.

## 7. Note sur la forme JSON

Avec l'enveloppe, `--format json` est une représentation **fidèle au Lua** : des tables fréquentes
comme `pylons` et `callsign` deviennent des wrappers `__luaTable__`, moins ergonomiques pour un
consommateur JSON générique (`jq`…). C'est voulu — ce JSON est le contrat de parsing du plugin. Les
vues human-friendly sont **`--format yaml`** (clés entières natives via PyYAML) et **`--format
markdown`**.

## 8. Ressources (entrée `.miz`)

Quand l'entrée est un `.miz`, `veaf-tools mission export --extract-dir <dir>` **extrait** aussi les ressources
embarquées de l'archive — scripts `.lua` et `l10n/DEFAULT/*` (sons/images) — vers un dossier annexe
reproduisant le layout de l'archive, pour que le plugin exécute ses checks `.lua` et résolve les noms de
fichiers de `mapResource` sans dézipper. Les fichiers data déjà portés par le JSON sont ignorés. Pour un
dossier mission déjà extrait, rien n'est extrait.

## Hors périmètre (côté plugin)

Le décodeur JSON→Lua, le reroutage du `missionLoader.lua` du plugin hors de `load()`, et le bundling de
`veaf-tools` sont implémentés dans le repo du plugin BFR. Ce document **spécifie** seulement ce que
veaf-tools garantit et ce que le décodeur doit faire.
