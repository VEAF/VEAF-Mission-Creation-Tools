# `veaf-tools doctor` — format du bloc collable

> **Public visé** : les développeurs des lots qui consomment la sortie de `doctor` — l'analyse de
> journal (`FEAT-SUPPORT-LOG-ANALYSIS`) qui l'intègre à son propre bloc de rapport, et la prise en
> charge de signalement (`FEAT-SUPPORT-BUG-INTAKE`) qui le relit.
>
> **Schéma : `veaf-tools-doctor/1`.** — 🇬🇧 [`diagnostic-block.en.md`](diagnostic-block.en.md).

## Pourquoi un format {#why}

Le bloc voyage à travers Discord ou une issue GitHub, copié à la main par quelqu'un qui ne le relira
pas, et il est relu par une machine à l'autre bout. Ce n'est donc ni un affichage ni un fichier :
c'est un **contrat**, versionné, que ni le producteur ni les consommateurs ne peuvent changer seuls.

L'implémentation vit dans `src/python/veaf-tools/veaf_libs/diagnostics.py`, producteur
(`DiagnosticReport.to_block`) et lecteur (`parse_block`) dans le même module — pour qu'ils ne
puissent pas diverger — et le test d'aller-retour est dans
`test/python/veaf_libs/test_diagnostics.py`.

## Structure {#structure}

```text
=== VEAF-TOOLS DOCTOR BEGIN ===
schema: veaf-tools-doctor/1
generated: 2026-09-05T09:39:29Z
tool.version: 6.19.0
...
--- recent-errors ---
2026-09-03 21:05:52,533 - veaf-tools - ERROR - Failed to evaluate time expression
Traceback (most recent call last):
ValueError: ...
--- recent-errors end ---
=== VEAF-TOOLS DOCTOR END ===
```

Trois règles, et rien d'autre :

1. Le bloc est délimité par `=== VEAF-TOOLS DOCTOR BEGIN ===` et `=== VEAF-TOOLS DOCTOR END ===`.
   Il **arrive au milieu d'autre chose** (un message, des barrières de code) : un lecteur cherche
   ces deux lignes, il ne suppose pas que le bloc commence à la première ligne.
2. Entre les deux délimiteurs, chaque ligne est `clef: valeur`. La séparation se fait sur le
   **premier** `:` — une valeur peut en contenir d'autres (un chemin Windows, un horodatage).
3. La section optionnelle encadrée par `--- recent-errors ---` et `--- recent-errors end ---`
   contient du **texte brut**. Un enregistrement commence à une ligne d'en-tête
   (`AAAA-MM-JJ HH:MM:SS,mmm - <logger> - <NIVEAU> - `) ; tout ce qui suit lui appartient, ce qui
   permet à une trace d'appels de survivre entière.

## Les champs {#fields}

L'ordre est celui de `FIELD_ORDER` dans `diagnostics.py`, et il est stable.

| Clef | Exemple | Vaut `unknown` quand |
|---|---|---|
| `schema` | `veaf-tools-doctor/1` | jamais |
| `generated` | `2026-09-05T09:39:29Z` | jamais |
| `tool.version` | `6.19.0` | le paquet n'est pas installé et le fichier de version est absent |
| `tool.packaging` | `frozen` ou `source` | jamais |
| `tool.executable` | `C:\Users\<user>\...\python.exe` | l'interpréteur ne se nomme pas |
| `tool.python` | `3.13.15` | jamais |
| `machine.os` | `Windows-11-10.0.26200-SP0` | la plateforme ne répond pas |
| `machine.locale` | `fr_FR / cp1252` | la locale n'est pas déterminable |
| `machine.free_space` | `654.0 GB on D:\` | le disque ne répond pas |
| `dcs.detected` | `yes` / `no` | jamais |
| `dcs.version` | `2.9.29.27278` | DCS absent, ou bannière introuvable dans `dcs.log` |
| `dcs.variant` | `stable`, `openbeta` | DCS absent |
| `dcs.write_dir` | `C:\Users\<user>\Saved Games\DCS` | DCS absent |
| `dcs.log_age` | `3 d` | DCS absent |
| `veaf.home` | `C:\Users\<user>\.veaf` | le dossier ne peut pas être créé |
| `veaf.log` | `present, 1.2 MB` / `absent` | l'accès échoue |
| `veaf.lua_modules` | `37` | l'inventaire n'est pas lisible |

Un champ inconnu vaut la chaîne `unknown` et **jamais** une chaîne vide : « absent » et « non
collecté » se lisent pareil pour un humain, et un consommateur doit pouvoir les distinguer.

## Règles d'évolution {#evolution}

- **Ajouter** un champ est compatible : un lecteur lit ce qu'il connaît et ignore le reste. Le
  producteur fait déjà voyager un champ qu'il ne connaît pas.
- **Retirer ou renommer** un champ ne l'est pas, et impose de passer à `veaf-tools-doctor/2`.
- Un lecteur **vérifie `schema` avant de parser**. Un bloc portant un schéma inconnu est un bloc
  dont il ne peut rien supposer.

## Caviardage {#redaction}

Tout ce que produit `doctor` passe par `veaf_libs.redaction.redact` **avant** d'être affiché : nom
de compte Windows → `<user>`, adresse IPv4 routable → `<ip>`, adresse e-mail → `<email>`, jeton ou
mot de passe → `<redacted>`. Les adresses de bouclage sont conservées : elles ne portent rien de
personnel et disent quelque chose d'utile.

Le caviardage se fait à la production, pas à la publication : au moment de publier, c'est un autre
programme, sur une autre machine, et il est trop tard. Un consommateur peut repasser `redact` sur ce
qu'il reçoit — l'opération est idempotente — mais il ne doit pas compter dessus pour rattraper une
source non caviardée.
