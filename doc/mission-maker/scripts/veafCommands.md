# veafCommands — Le répartiteur des commandes marqueur

**Module ID:** `COMMANDS` | **Fichier:** `veafCommands.lua`

---

## Objectif

C'est le **point d'entrée unique** de toutes les commandes que les joueurs tapent dans un marqueur
F10. Un seul gestionnaire d'événement DCS est enregistré ; il essaie ensuite chaque module dans un
ordre déterminé jusqu'à ce que l'un consomme la commande.

Page destinée aux **développeurs** et aux créateurs de modules : un créateur de mission n'a rien à y
configurer.

---

## Ce que le module garantit

**Chaque commande déclare son palier de sécurité, et l'oubli est refusé au chargement.** Quatre
gestionnaires sur neuf avaient dérivé vers « aucun contrôle » sans que rien ne le signale
(`SECREV-2`) : le palier est désormais un argument sans valeur par défaut, et un module qui ne le
déclare pas ne s'enregistre pas.

| Valeur déclarée | Signification |
|-----------------|---------------|
| `ADMIN` · `SENIOR_PILOT` · `KNOWN_PILOT` | Le répartiteur applique le contrôle **avant** le gestionnaire, sur l'identité de l'auteur du marqueur |
| `OPEN` | Ouvert à tous — dit explicitement, plutôt qu'obtenu en omettant le palier |
| `veafCommands.SECURITY_HANDLED` | Le gestionnaire vérifie lui-même, parce qu'il lit un mot de passe dans le texte du marqueur ; le répartiteur ne double pas le contrôle |

Les anciens noms `L0` / `L1` / `L9` restent acceptés une release et signalent leur dépréciation une
fois par nom. Un nom inconnu déclenche une erreur d'assertion à l'enregistrement.

**Un palier inconnu au moment du dispatch refuse la commande** plutôt que de la laisser passer :
l'enregistrement l'interdit déjà, donc y arriver signifie que la table a été modifiée en cours de
partie.

---

## L'ordre d'essai {#priorities}

Les gestionnaires sont essayés par priorité croissante. Le premier qui renvoie `true` consomme
l'événement et le marqueur est retiré.

| Priorité | Module |
|----------|--------|
| 10 | `veafShortcuts` — les alias, qui se réécrivent en commandes brutes |
| 20 | `veafSpawn` |
| 30 | `veafNamedPoints` |
| 40 | `veafCasMission` |
| 50 | `veafSecurity` |
| 60 | `veafMove` |
| 62 | `veafGroundAI` |
| 70 | `veafRadio` |
| 80 | `veafRemote` |

Les alias passent en premier **par construction** : ils traduisent `-sa6` en `_spawn group, name ...`
avant que les modules ne voient le texte.

---

## Le chemin de contournement {#bypass}

`veafInterpreter` exécute au démarrage les commandes écrites dans les **noms d'unités** par le
créateur de la mission. Ce chemin **contourne le contrôle de sécurité** volontairement : ces
commandes viennent de l'auteur de la mission, pas d'un joueur. C'est pinné par un test, pour qu'un
changement soit délibéré.

---

## Configuration `mission.yaml`

Aucune. Le module est de l'infrastructure : il se charge toujours.

---

## Voir aussi

- [veafSecurity](veafSecurity.md) — les paliers, et ce qu'un pilote non listé doit faire
- [veafShortcuts](veafShortcuts.md) — les alias, premiers servis
- [veafInterpreter](veafInterpreter.md) — les commandes dans les noms d'unités
