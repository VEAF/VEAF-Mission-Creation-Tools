# `veaf-tools export` — contrat JSON pour le plugin BFR `dcs-mission-tools`

> **Public visé** : les développeurs du plugin Claude BFR `dcs-mission-tools`
> ([bfr-claude-plugins](https://github.com/Bullseye-Francophone/bfr-claude-plugins)) qui consomment
> `veaf-tools export --format json` au lieu d'exécuter les fichiers mission via `lua54`.
> Ce document est le **contrat figé** entre les deux outils.
>
> 🇬🇧 English version: [`export-json-contract.en.md`](export-json-contract.en.md).

## Pourquoi ce contrat

`veaf-tools` parse les fichiers `mission` / `dictionary` / `mapResource` d'un `.miz` avec une machine
à états **pur-Python** `luadata` — il **n'exécute jamais de Lua** (`luadata/serializer/unserialize.py`).
Exporter ce parse en JSON permet au plugin de lire **n'importe quelle** mission (un `.miz` venu d'un
forum, d'un DM, un dossier extrait) sans exécuter de Lua non fiable. Le plugin ne garde `lua54` **que**
pour exécuter ses propres checks `.lua`.

Le seul problème dur est de mapper fidèlement les **tables Lua** vers le **JSON** et retour, car :

- Une séquence Lua `{[1]=,[2]=,…}` supporte `#t` et `ipairs`. Le plugin s'appuie là-dessus pour
  `trigrules`, `trig.actions/conditions/flag`, et les tableaux groupes/pays/zones.
- Le JSON n'a **pas de clés entières**. Un mapping naïf `{1:…}` → `{"1":…}` produit des clés **string**
  en Lua (`#t == 0`, `ipairs` ne boucle pas) → les checks cassent en silence.

Le contrat ci-dessous rend le mapping déterministe côté veaf-tools et fige les **deux règles** que le
décodeur JSON→Lua du plugin doit suivre pour restaurer la parité.

## 1. Forme de premier niveau

```json
{
  "schemaVersion": 1,
  "theatre": "Caucasus",
  "mission": { "...": "la table `mission` parsée" },
  "dictionary": { "DictKey_...": "..." },
  "mapResource": { "ResKey_...": "fichier.lua" }
}
```

- `schemaVersion` (entier) — **toujours présent, en tête**. Voir §6.
- `theatre` — string (ou `null` si absent).
- `mission`, `dictionary`, `mapResource` — les tables parsées, mappées selon §2.

`dictionary` et `mapResource` sont des maps string→string et sérialisent toujours en **object** JSON.

## 2. Règle array vs object (déterministe)

Une table Lua est émise en **array** JSON **si et seulement si ses clés sont exactement les entiers
contigus `1..n`** (n ≥ 1). Toute autre table est un **object** JSON à clés string.

| Table Lua (telle que parsée) | Sortie JSON | Raison |
|---|---|---|
| `{[1]=a,[2]=b,[3]=c}` (séquence) | `["a","b","c"]` (**array**) | `#t`, `ipairs` marchent directement après décodage |
| `{[2]=a,[5]=b}` (**sparse**) | `{"2":"a","5":"b"}` (**object**) | non contigu → impossible en array JSON ; voir §3 |
| `{[1]=a,["x"]=b}` (**mixte**) | `{"1":"a","x":"b"}` (**object**) | clés mixtes → object ; voir §3 |
| `{["a"]=1,["b"]=2}` (record) | `{"a":1,"b":2}` (**object**) | object naturel |
| `{}` (vide) | `{}` (**object**) | neutre pour la parité ; voir §4 |

Cela couvre les tables que le plugin indexe numériquement — `trigrules`, `trig.actions`,
`trig.conditions`, `trig.flag`, et les tableaux `group` / `country` / `zones` — qui sortent toutes en
**array**.

### Exemple travaillé — `trigrules` et `trig`

Mission parsée (conceptuellement) :

```lua
trigrules = { [1] = {...rule1...}, [2] = {...rule2...} }
trig      = { actions    = { [1]="a_do_script(...)" },
              conditions = { [1]="return true" },
              flag       = { [1]=true } }
```

JSON exporté :

```json
{
  "trigrules": [ {"...rule1...": true}, {"...rule2...": true} ],
  "trig": {
    "actions":    [ "a_do_script(...)" ],
    "conditions": [ "return true" ],
    "flag":       [ true ]
  }
}
```

`trig` est un record (clés string) → object ; chacune de ses sous-tables est une séquence `1..n` →
array. Après décodage, `#mission.trigrules`, `ipairs(mission.trig.actions)` se comportent comme
aujourd'hui.

## 3. Tables sparse et mixtes — le travail du décodeur

Une table qui **n'est pas** une séquence contiguë `1..n` ne peut pas être un array JSON : elle part
donc en object à clés **string**. C'est le seul cas où le JSON perd la nature entière des clés.

Pour restaurer la parité, le décodeur JSON→Lua du plugin **doit recoercer les clés string-entières
canoniques en clés entières Lua** quand il construit une table à partir d'un object JSON :

- Une clé qui matche `^-?%d+$` **sans zéro initial** (sauf le seul `"0"`) → utiliser l'entier comme
  clé Lua.
- Toute autre clé → garder la clé string.

Ainsi `{"2":a,"5":b}` décode vers la table Lua native `{[2]=a,[5]=b}`, identique à ce que `load()`
produisait.

> `#t` et `ipairs` sur une table sparse sont **indéfinis** en Lua de toute façon : le contrat garantit
> la **parité valeurs/clés**, pas la parité de longueur de séquence, pour les tables sparse — ce qui
> correspond exactement à `load()`.

## 4. Tables vides

Une table Lua vide `{}` est ambiguë (array ou record). Elle exporte en `{}` JSON. C'est **neutre pour
la parité** : un `{}` JSON **et** un `[]` JSON décodent tous deux vers une table Lua vide où
`#t == 0` et `next(t) == nil`. Le décodeur doit produire une table Lua vide pour `{}` **comme** pour `[]`.

## 5. Scalaires, strings, encodage

- Nombres Lua → nombres JSON (les entiers restent entiers, ex. les coordonnées en flottants).
- Booléens Lua → `true`/`false` JSON.
- Strings Lua → strings JSON, **UTF-8, non échappées en ASCII** (`ensure_ascii=false`). Les décodeurs
  doivent lire de l'UTF-8.
- Les valeurs absentes / `nil` ne sont simplement pas présentes (pas de `null` JSON pour un membre de
  table ; `theatre` peut valoir `null`).
- **L'ordre des clés n'est pas significatif.** Les décodeurs ne doivent pas en dépendre.

## 6. `schemaVersion` et compatibilité

- `schemaVersion` est un entier, **incrémenté à tout changement cassant** du contrat (forme, règle
  array/object, sémantique des clés). Les ajouts rétro-compatibles ne l'incrémentent **pas**.
- Le plugin **doit** lire `schemaVersion` et refuser / avertir sur une version majeure inconnue plutôt
  que de mal lire en silence.
- Version actuelle : **1**.

## 7. Exigences du décodeur (résumé, côté plugin)

Un décodeur JSON→Lua conforme :

1. **array** JSON → séquence Lua à clés entières `1..n`.
2. **object** JSON → table Lua ; pour chaque clé, si c'est une string-entière canonique (§3) utiliser
   la clé **entière** Lua, sinon la clé **string**.
3. array vide **et** object vide → table Lua vide.
4. Nombres/booléens/strings → leurs équivalents Lua ; strings UTF-8.

Avec ces règles, les tables décodées reproduisent la sortie `load()` actuelle **table pour table**
(array-ness et types de clés), donc les checks existants du plugin rendent des findings identiques —
le critère de validation n°1.

## 8. Ressources (entrée `.miz`)

Quand l'entrée est un `.miz`, `veaf-tools export` **extrait** aussi les ressources embarquées de
l'archive — scripts `.lua` et `l10n/DEFAULT/*` (sons/images) — vers un dossier annexe reproduisant le
layout de l'archive, pour que le plugin exécute ses checks `.lua` et résolve les noms de fichiers de
`mapResource` sans dézipper. L'object JSON ci-dessus reste le pivot de données ; `mapResource` mappe
les clés de ressource vers les fichiers extraits.

Quand l'entrée est un dossier mission déjà extrait, les ressources sont déjà lâches : rien n'est extrait.

## Hors périmètre (côté plugin)

Le décodeur JSON→Lua, le reroutage du `missionLoader.lua` du plugin hors de `load()`, et le bundling de
`veaf-tools` sont implémentés dans le repo du plugin BFR. Ce document **spécifie** seulement ce que
veaf-tools garantit et ce que le décodeur doit faire.
