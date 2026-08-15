# veafSecurity — Permissions par rôle

**Module ID:** `SECURITY` | **Fichier:** `veafSecurity.lua`

---

## Objectif

Fournit un système de permissions pour les commandes de marqueur VEAF et les actions du menu radio. Restreint les commandes sensibles (spawn, téléportation, destruction) aux joueurs autorisés, soit d'après le niveau du pilote déclaré côté serveur, soit par mot de passe haché en SHA-1.

---

## Activation

```lua
veafSecurity.initialize()
```

À appeler avant les autres modules pour que les vérifications de sécurité soient actives lors de leur initialisation.

---

## Niveaux de permission

**Un plus grand nombre est un palier plus strict.** Un contrôle passe si le niveau du pilote est
*au moins* égal à la constante, ou s'il fournit le mot de passe du palier.

| Palier | Constante | Passe sans mot de passe si le niveau du pilote est |
|--------|-----------|-----------------------------------------------------|
| `KNOWN_PILOT` | `veafSecurity.LEVEL_KNOWN_PILOT` = 1 | **≥ 1** — tout pilote inscrit dans le `veaf-pilots.txt` du serveur |
| `SENIOR_PILOT` | `veafSecurity.LEVEL_SENIOR_PILOT` = 10 | **≥ 10** — un membre de confiance |
| `ADMIN` | `veafSecurity.LEVEL_ADMIN` = 90 | **≥ 90** — un administrateur du serveur |
| `MM` | (aucun niveau) | jamais — seul le mot de passe Mission Master ouvre |
| `OPEN` | (aucun contrôle) | toujours — la commande est délibérément ouverte à tous |

!!! warning "`L0`, `L1` et `L9` sont des alias dépréciés, et ils se lisent à l'envers"

    Cette page annonçait « 0 (public) » pour `LEVEL_L0` jusqu'à la 6.13.70. C'était faux :
    `LEVEL_L0` vaut **90**, le palier le plus strict. Écrire `L0` en croyant ouvrir une
    commande à tous la réservait en réalité aux administrateurs.

    `L0` → `ADMIN`, `L1` → `SENIOR_PILOT`, `L9` → `KNOWN_PILOT`. Les valeurs sont inchangées,
    donc renommer ne change le comportement d'aucune mission.

Les mots de passe sont hiérarchiques : celui d'`ADMIN` ouvre aussi `SENIOR_PILOT` et
`KNOWN_PILOT`, celui de `SENIOR_PILOT` ouvre `KNOWN_PILOT`. Le mot de passe Mission Master est
en dehors de cette hiérarchie : il n'ouvre que les commandes déclarées `MM`.

Chaque commande sécurisée déclare son palier en littéral au moment de son enregistrement (voir
« Sécurité au niveau du module » plus bas). Voir aussi le
[Guide du créateur de mission](../GUIDE.md#security-tiers).

---

## Définir les mots de passe

Les mots de passe sont stockés sous forme de hachages SHA-1 pour la sécurité. Utiliser la fonction intégrée `sha1` :

```lua
-- Dans mission-script.lua (après chargement de veafSecurity)

-- Effacer les mots de passe livrés par défaut et définir les vôtres. Les tables gardent les
-- anciens noms : password_L0 = ADMIN, password_L1 = SENIOR_PILOT, password_L9 = KNOWN_PILOT.
veafSecurity.password_L0 = {}
veafSecurity.password_L1 = {}
veafSecurity.password_L9 = {}

-- Ajouter des mots de passe hachés (plusieurs mots de passe acceptés par palier)
veafSecurity.password_L0[sha1.hex("monMotDePasseAdmin")] = true
veafSecurity.password_L1[sha1.hex("monMotDePasseMembreDeConfiance")] = true
```

> **Effacer avant d'ajouter.** Sans le `= {}`, votre mot de passe s'*ajoute* à celui livré avec
> VEAF, qui est publié dans un dépôt public : la mission resterait ouverte avec le mot de passe
> par défaut.

> Ne pas committer de mots de passe en clair dans les fichiers de mission. Utiliser uniquement des hachages.

---

## Constantes clés

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafSecurity.authDuration` | `10` | Minutes pendant lesquelles l'authentification reste valide |
| `veafSecurity.Keyphrase` | `"_auth"` | Commande de marqueur pour l'authentification |
| `veafSecurity.LEVEL_ADMIN` | `90` | Palier administrateur (alias déprécié : `LEVEL_L0`) |
| `veafSecurity.LEVEL_SENIOR_PILOT` | `10` | Palier membre de confiance (alias déprécié : `LEVEL_L1`) |
| `veafSecurity.LEVEL_KNOWN_PILOT` | `1` | Palier pilote inscrit (alias déprécié : `LEVEL_L9`) |

---

## Authentification du joueur

La commande de marqueur `_auth` porte trois verbes :

```
_auth [MOT_DE_PASSE]   -- vérifie le mot de passe donné
_auth elevate          -- élève le groupe de l'auteur à son propre niveau pendant 2 minutes
_auth logout           -- reverrouille la mission
```

Un mot de passe accepté n'ouvre **pas de session** : les commandes sécurisées vérifient le mot de
passe commande par commande (mot-clé `password`). En tchat, les mêmes verbes existent sous la forme
`/secu login|elevate|logout` (voir [veafServerHook](veafServerHook.md)) ; l'alias caché `-login`
équivaut à `_auth`.

!!! danger "Changement de comportement — l'authentification n'est plus globale"
    **Avant** : un seul `_auth` réussi ouvrait toutes les commandes sécurisées à **tous les joueurs
    du serveur** pendant `authDuration` minutes. Tant que quelqu'un était authentifié, le niveau
    réel des pilotes n'était même plus consulté : le mécanisme grossier désactivait le précis.

    **Maintenant** : chaque commande sécurisée vérifie qui demande.

    - **Pour un pilote listé dans `veaf-pilots.txt`, rien ne change** : son niveau suffit, et il
      n'a jamais eu besoin du mot de passe.
    - **Un pilote non listé** doit fournir le mot de passe **à chaque commande** : il n'y a plus de
      session ouverte de dix minutes.
    - Pour le **menu radio F10**, DCS ne permet pas de savoir *quel* occupant d'un groupe a cliqué.
      Le groupe agit donc au niveau du **moins gradé** de ses occupants. Le verbe explicite
      `_auth elevate` (marqueur) ou `/secu elevate` (tchat) élève le groupe au niveau **du
      demandeur** pendant 2 minutes — un simple `_auth [MOT_DE_PASSE]` n'élève rien. C'est ce qui
      résout le cas de l'instructeur volant avec un élève.

    Prévenez vos pilotes : c'est un changement qui se remarque en pleine mission.

---

## Désactiver la sécurité (développement / solo)

Pour les tests ou les missions solo où la sécurité n'est pas nécessaire :

```lua
veaf.SecurityDisabled = true
```

Cela contourne toutes les vérifications de sécurité globalement.

!!! warning "`veafSecurity.SecurityDisabled` : ancienne orthographe, encore honorée"
    Les missions écrites avant juin 2026 utilisent `veafSecurity.SecurityDisabled` (avec le préfixe
    du module). Ce nom a été retiré par erreur : il était considéré comme jamais assigné, alors
    qu'il s'agit d'un réglage **de mission** — les seuls endroits qui l'assignent sont donc les
    configurations de mission, hors du dépôt.

    Conséquence pendant trois ans : une mission demandant la sécurité **désactivée** l'obtenait
    **activée**. Le sens de la panne est rassurant — personne n'a eu trop de droits — mais toutes
    les commandes sécurisées refusaient pour tout le monde, ce qui ressemble à « la couche de
    sécurité est cassée » plutôt qu'à « votre réglage a été retiré ».

    Les deux orthographes fonctionnent à nouveau. L'ancienne écrit un avertissement dans le log,
    une seule fois par mission, et **sera retirée en v7** : migrez vers `veaf.SecurityDisabled`.

---

## Sécurité au niveau du module

Il n'y a pas de réglage global par module : chaque commande déclare son palier en littéral au moment
de son enregistrement, et le répartiteur applique le contrôle avant d'exécuter. Exemple pour spawn :

```lua
-- Le deuxième argument est le palier exigé : "L9", "L1", "MM" ou "OPEN"
veafSpawn.registerCommandHandler("smoke", "OPEN", function(eventPos, options, coalition, markId, bypassSecurity)
  -- ...
end)
```

---

## Voir aussi

- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafSecurity`
