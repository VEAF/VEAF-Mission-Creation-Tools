# Références manquantes

Votre `mission.yaml` nomme un groupe, une zone de déclenchement, une unité ou un aérodrome ; le
build regarde dans la mission et ne le trouve pas. C'est la famille la plus fréquente, et la plus
coûteuse : la mission se construit, se charge, se joue — et la fonctionnalité concernée ne fait
simplement rien, **sans un mot en jeu**.

## L'encadré de fin de build {#builder-reference-issues-header}

> ────────────────────────────────────────────────────────────
> 3 référence(s) de mission.yaml vers un objet du Mission Editor sont absentes (le .miz a quand
> même été généré) — corrigez-les dans le Mission Editor ou mission.yaml :
>   • …
>   • …
> ────────────────────────────────────────────────────────────

Toutes les références manquantes sont regroupées là, à la toute fin, dans un encadré — pas
dispersées au fil du build où elles passeraient inaperçues.

**Le build ne s'arrête pas, et c'est voulu.** Pour poser le groupe qui manque, il vous faut ouvrir
la mission dans l'éditeur DCS ; refuser de produire le `.miz` vous priverait précisément de l'objet
dont vous avez besoin pour corriger.

**Comment relire la liste sans reconstruire :**

```powershell
.\veaf-tools.exe validate
```

> **Le `.\` est obligatoire.** PowerShell ne cherche pas dans le dossier courant — exprès. Voir
> [PowerShell ou invite de commandes ?](../GUIDE.md#powershell-vs-cmd).

## Comment lire un de ces messages {#how-to-read}

Chacun a la même forme : **quoi** manque, et **où** c'est déclaré.

> Le groupe 'Alert-CAP-1' déclaré dans **QRA** est absent de la mission

Le mot en gras est un chemin dans votre `mission.yaml`, pas un dossier ni un script. Voici les
sections réellement contrôlées :

| Ce qui est contrôlé | Sections de `mission.yaml` |
|---|---|
| Des **groupes** posés dans l'éditeur | `modules.ASSETS` (`name`, `linked`), `modules.QRA` (`simple_groups`, `groups_by_enemy_count`), `cap_missions`, `combat_missions` |
| Des **zones de déclenchement** | `modules.AIRWAVES` (`trigger_zone_name`), `modules.QRA` (`trigger_zone`), `modules.COMBATZONE` (`zone_name`) |
| Des **unités** (ou des groupes) | `modules.SANCTUARY` (`polygon_units`) |
| Des **aérodromes** | `modules.QRA` (`airport_link`) |
| Des **sous-zones** déclarées ailleurs dans le YAML | `modules.COMBATZONE`, opérations (`tasking_orders`, `dependencies`) |

Si votre message nomme une section qui n'est pas dans ce tableau, c'est qu'il ne vient pas de cette
famille — retournez à l'[index](README.md).

## Un groupe déclaré est absent de la mission {#validate-missing-group}

> Le groupe 'Alert-CAP-1' déclaré dans QRA est absent de la mission — placez-le dans le Mission
> Editor, sinon la fonctionnalité échoue au runtime.

**Dans l'éditeur.** Le nom doit correspondre **exactement** au nom du groupe dans l'éditeur DCS —
celui de la colonne de gauche, pas le nom d'une unité à l'intérieur du groupe. Majuscules,
espaces et tirets compris.

**Les deux pièges qui ne sont pas des fautes de frappe.**

- **`cap_missions` cherche un nom préfixé.** Le runtime ajoute `OnDemand-` devant le nom que vous
  écrivez, donc votre groupe modèle dans l'éditeur doit s'appeler `OnDemand-<votre nom>`. Si vous
  avez écrit `group_name: Patrouille-Nord`, l'éditeur doit contenir `OnDemand-Patrouille-Nord`.
- **Renommer dans l'éditeur ne met pas `mission.yaml` à jour.** Les deux fichiers ne se parlent
  pas : si vous renommez ou reposez un groupe côté éditeur, c'est à vous de reporter le nouveau nom
  dans le YAML. C'est la cause la plus fréquente d'un nom qui « marchait hier ».

**Les issues.** Poser le groupe manquant dans l'éditeur, corriger le nom dans `mission.yaml`, ou
retirer l'entrée si la fonctionnalité ne vous sert plus.

**Ce que ce n'est pas.** Pas une erreur de script VEAF, et reconstruire n'y changera rien : le
build lit ce que contient votre `.miz`, il ne crée pas de groupes.

## Une zone de déclenchement n'existe pas {#validate-missing-trigger-zone}

> La zone de déclenchement 'ZONE-KOBULETI' référencée par COMBATZONE n'existe pas dans la mission —
> créez-la dans le Mission Editor.

**Dans l'éditeur.** Les zones de déclenchement sont les cercles et polygones de l'onglet *Trigger
zones*. Une zone de combat ou une QRA sans la sienne échoue au démarrage du module : côté
`VeafCombatZone`, l'initialisation lève une erreur et le module s'arrête.

**Les issues.** Créer la zone dans l'éditeur, ou corriger le nom dans `mission.yaml`. Là encore, le
nom doit être identique au caractère près, et renommer une zone dans l'éditeur ne met pas le YAML à
jour.

## …mais un centre et un rayon prendront le relais {#validate-missing-trigger-zone-optional}

> La zone de déclenchement 'AIRWAVE-1' référencée par AIRWAVES n'existe pas dans la mission — le
> centre/rayon configuré sera utilisé à la place. Retirez trigger_zone_name pour supprimer cet
> avertissement.

**La version bénigne de la précédente**, et la différence tient à votre configuration : une zone
AIRWAVES qui porte à la fois `zone_center_coordinates` et `zone_radius` a de quoi fonctionner sans
la zone de l'éditeur. Le build le voit, dégrade l'erreur en avertissement, et la mission marche.

**Les issues.** Créer la zone si vous la vouliez vraiment, ou retirer `trigger_zone_name` pour
assumer le centre/rayon — et faire taire le message.

**Ce que ce n'est pas.** Ce n'est jamais le cas des zones QRA ou COMBATZONE : celles-là n'ont pas
de repli, et restent des erreurs.

## Une unité référencée est absente {#validate-missing-unit}

> L'unité 'Sanctuary_Kutaisi_Polygon #003' référencée par SANCTUARY est absente de la mission —
> placez-la dans le Mission Editor, sinon le polygone de la zone est incomplet.

**Dans l'éditeur.** Un sanctuaire dessine son polygone en reliant des unités posées aux sommets. Il
en manque une : le polygone se referme autrement, donc la zone protégée n'a pas la forme voulue —
et rien ne le signalera en jeu.

**Le piège utile à connaître.** Le nom peut désigner une **unité** *ou* un **groupe**. Le runtime
cherche d'abord une unité, et à défaut prend la première unité du groupe du même nom. Donc un
`polygon_units` qui nomme des groupes est parfaitement valide — inutile de « corriger » vers des
noms d'unités.

## Un aérodrome est inconnu sur ce théâtre {#validate-unknown-airfield}

> L'aérodrome 'Kobuletti' référencé par QRA.airport_link est inconnu sur ce théâtre — vérifiez
> l'orthographe par rapport au nom de l'aérodrome dans le Mission Editor.

**Dans l'éditeur.** Le nom attendu est celui que l'éditeur DCS affiche pour l'aérodrome, à la
lettre. Les noms translittérés du géorgien, du syrien ou du persan sont des pièges à doublement de
consonne — *Kobuleti*, pas *Kobuletti*.

**Ce que ce n'est pas.** Le contrôle ne s'exécute pas du tout sur un théâtre dont les outils n'ont
pas la table des aérodromes : mieux vaut ne rien dire que signaler chaque aérodrome d'une carte non
couverte. Donc le silence ne prouve pas que votre nom est bon — il peut simplement vouloir dire que
la carte n'est pas connue.

## Une sous-zone n'est pas déclarée {#validate-undeclared-subzone}

> La sous-zone 'ZONE-SUD' référencée par COMBATZONE.operation[OPERATION-TEST] n'est pas déclarée
> comme entrée combat_zones — l'opération ne pourra pas la résoudre au runtime.

**Celle-ci ne parle pas de l'éditeur DCS.** Elle est entièrement interne à votre `mission.yaml` :
une opération enchaîne des zones de combat par ses `tasking_orders` et ses `dependencies`, et
chacune doit nommer une entrée `combat_zones` **du même fichier**, qui ne soit pas elle-même une
opération.

**Les issues.** Déclarer la zone manquante dans `combat_zones`, ou corriger la référence dans
l'ordre de mission.

**Ce que ce n'est pas.** Pas une zone de déclenchement manquante — l'objet cherché est une entrée
YAML, pas un cercle sur la carte.

## Pour aller plus loin {#more}

- [Les messages du build](README.md) — les autres familles
- [Zones de combat](../concepts/combat-zones.md)
- [Référence `mission.yaml`](../../MISSION_YAML_REFERENCE.md)
