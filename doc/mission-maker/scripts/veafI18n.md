# veafI18n — Le catalogue des messages en jeu

**Module ID:** `I18N` | **Fichier:** `veafI18n.lua`

---

## Objectif

Contient **le catalogue de traductions** des messages que les scripts VEAF affichent aux joueurs :
**263 clés**, chacune en français et en anglais. Le français est la langue par défaut
(`veaf.I18N_DEFAULT_LANGUAGE`).

Ce module ne contient que les données. La fonction de recherche, `veaf.t(key, ...)`, vit dans
`veaf.lua` — et c'est délibéré : elle doit rester disponible même si le catalogue n'est pas chargé.

Page destinée aux **développeurs**.

---

## Comment une traduction est résolue {#lookup}

`veaf.t("spawn.did_you_mean", "sa6")` cherche, dans l'ordre :

1. l'entrée dans la langue configurée (`veaf.config.language`) ;
2. la même entrée en **français**, la langue par défaut, si la traduction manque ;
3. **la clé elle-même**, si l'entrée n'existe pas du tout.

Cette troisième étape est ce qui fait qu'un message manquant s'affiche comme `spawn.did_you_mean` à
l'écran plutôt que de faire planter le script. Si vous voyez une clé brute en jeu, c'est une entrée
absente du catalogue.

Les arguments supplémentaires passent par `string.format`, **sous `pcall`** : un format qui ne
correspond pas aux arguments donne le texte non formaté au lieu d'une erreur DCS.

---

## Ajouter un message {#add-a-message}

```lua
["mon.module.message"] = {
  fr = "Le groupe %s est arrivé",
  en = "Group %s has arrived",
},
```

Puis, dans le module : `trigger.action.outText(veaf.t("mon.module.message", groupName), 10)`.

**Les deux langues sont obligatoires** — un test de couverture i18n refuse une clé qui n'aurait que
le français, et un autre refuse une chaîne écrite en dur dans un module. Aujourd'hui les 263 clés ont
leurs deux langues.

La convention de nommage est `<module>.<sujet>` en minuscules, par exemple `spawn.unknown_parameters`
ou `groundai.cannot_aim`.

---

## Choisir la langue d'une mission

```yaml
mission:
  language: fr      # fr | en — défaut : la langue des outils
```

---

## Configuration `mission.yaml`

Aucune option propre au module. Il se charge toujours.

---

## Voir aussi

- [Référence mission.yaml](../../MISSION_YAML_REFERENCE.md) — le champ `mission.language`
- [Guide du développeur](../../developer/GUIDE.md) — les tests de couverture i18n
