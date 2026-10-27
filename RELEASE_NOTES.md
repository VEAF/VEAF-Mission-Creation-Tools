# VEAF Mission Creation Tools — 6.33.0

**Deux chantiers dans cette version : la Fat Cow de CTLD, et ce qu'il faut à une mission qui apporte ses propres scripts (BFR).**

---

## 🐄 La Fat Cow

### Un CH-47 qui devient un point de ravitaillement

VMCT embarque maintenant CTLD `2.0.0-rc15`, qui apporte la Fat Cow : un CH-47 qui se pose en campagne et devient une FARP où les hélicoptères refont le plein et réarment, sur ce qu'il transporte.
Un pilote de CH-47F charge un lot tout prêt dans une zone logistique (F10 → CTLD → Fat Cow → **Charger**), se pose et déploie sa FARP.
N'importe quel pilote peut aussi **demander une Fat Cow IA**, en choisissant son lot : elle suit la patrouille et se pose à la demande.
Les lots ont tous deux réservoirs de 800 gallons : Apache en tête (40 ou 60 Hellfire, laser et radar, et des obus de 30 mm), puis des sous-menus **Russes** (Ka-50, Mi-24P) et **Mixtes**.

### Ce que VMCT a changé pour elle

- **GRASS ne remplit plus les FARP de CTLD** : il remplissait toutes les FARP à chaque arrivée d'un joueur, ce qui rendait une Fat Cow inépuisable.
- **Le CH-47F a le menu CSAR.**
- **Une mission existante a la Fat Cow sans rien faire** : son `ctld-config.yaml`, écrit pour un CTLD plus ancien, n'a pas les listes de la Fat Cow, et CTLD prend désormais celles par défaut.
  `veaf-tools mission validate` le signale, et `veaf-tools mission ctld-upgrade` les écrit dans le fichier.

---

## 🧩 Les missions qui apportent leurs propres scripts

Étudié sur les missions BFR de Sharko, pour qu'elles puissent passer en v6 :

- **Sécurité** : après un raccourci qui contourne la sécurité (`-jtac`, `-smoke`, `-tacan`…), un marqueur n'accepte plus que les options de ce raccourci ; la synthèse vocale SRS refuse des arguments malformés.
- **Menu F10 en multijoueur** : les commandes suivent les pilotes présents (les ailiers d'un leader parti cliquaient dans le vide) ; une mission peut réserver un sous-menu à certains groupes, ou en faire un par pilote.
- **Modules lancés par la mission** : `initialized_by_mission: true` laisse à la mission le soin d'appeler `initialize()`, pour n'importe quel module, CTLD, CSAR et Skynet compris.
- **Porte-avions sans la boucle VEAF** (`operations_scheduler: false`), **points nommés déclarés par script**, **`WEATHER.welcomeBrief: false`** qui marche enfin.
- **`convert v5`** reprend la couche de scripts d'une mission v5, et une nouvelle page explique comment porter une telle mission, avec BFR comme exemple.

---

## ⚠️ Points d'attention

- **La Fat Cow est activée par défaut** dans toute mission qui a CTLD. Pour la retirer : `fatCowEnabled: false` dans `ctld-config.yaml`.
- **CTLD `2.0.0-rc15` est une version candidate** : la Fat Cow a été testée en jeu le 26 octobre, et les corrections qui ont suivi tournent sur les Open Training depuis le 27 au soir. Vos retours sont les bienvenus.

## 🙏 Merci

Merci à Sharko pour les missions BFR, et aux pilotes de la soirée Fat Cow du 26 octobre pour leurs retours.

---

📖 [Porter une mission qui a ses propres scripts](https://veaf.github.io/documentation/latest/mission-maker/custom-script-layer/) · [CTLD — la Fat Cow](https://veaf.github.io/CTLD/2.0.0-rc15/pilot/)
