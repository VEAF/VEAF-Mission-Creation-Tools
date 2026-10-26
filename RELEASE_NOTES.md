# VEAF Mission Creation Tools — 6.32.0

**Deux chantiers dans cette version : un nouveau `veaf-logs`, réécrit de zéro, et tout ce que nos missions construites par une IA nous ont appris.**

---

## 📜 Le nouveau veaf-logs

### Plus léger, plus rapide

`veaf-logs.exe` garde son nom, ses menus et ses habitudes, mais c'est une nouvelle application : environ 14 Mo au lieu de 47, une fenêtre qui s'ouvre instantanément, un journal de 130 Mo indexé en 2,4 s au lieu de 13.
Mêmes filtres, mêmes profils, même session, mêmes journaux distants, même *Expliquer ce qui est affiché* et même rapport `/bug`.
Vos profils et votre session (`%APPDATA%\veaf_logs`) sont relus tels quels : rien à refaire.

Au passage, trois défauts de l'ancien lecteur sont corrigés : *Aller à la fin* répond enfin à Ctrl+Fin, une recherche par expression régulière avec `^` ou `$` ne rate plus des lignes, et un filtre commençant par `*` ne fige plus la fenêtre (une minute auparavant sur un gros journal, une seconde maintenant).

### Les journaux d'un serveur sans compte SSH

`veaf-logs` sait lire les journaux d'un serveur à travers l'API REST de DCSServerBot : on déclare l'adresse de l'API et le fichier de sa clé dans `~/veafmct.yaml`, et *Ouvrir un journal distant…* liste les serveurs DCS que le bot connaît, plus le journal du bot lui-même.
*Fichier › Ouvrir un ancien journal…* ouvre les fichiers plus anciens : `dcs.log.old`, les copies faites à l'arrêt, les journaux tournés du bot.

La barre d'état dit maintenant **pourquoi** un journal distant ne se lit pas — clé refusée, pas encore de journal, serveur inconnu ou injoignable, lignes perdues au redémarrage —, y compris pour les onglets SSH, qui affichaient *suivi actif* sur une connexion coupée.

### Des onglets qu'on retrouve

Au-delà de la largeur de la fenêtre, les onglets défilent (molette ou flèches ‹ ›) et l'onglet courant reste visible ; un bouton ≡ les liste tous.
*Renommer l'onglet…*, dans le menu du clic droit, donne un alias durable à un serveur ou à un fichier.

### Moins de bruit ED

Neuf nouvelles familles de messages sans intérêt pour un mission maker sont masquées par défaut : ce qu'un serveur dédié ne charge pas (textures, modèles 3D), les restes de la mission précédente, les héliports et balises incomplets des cartes, les assertions internes d'ED…
Sur un `dcs.log` réel de Privé 1, il reste 208 erreurs et avertissements non reconnus au lieu de 3 031 : ce qui reste affiché, c'est ce sur quoi on peut agir.

## 🤖 Les missions construites par une IA

La vidéo de démo et une session complète dans Claude Cowork nous ont montré où une IA bricolait faute d'outil adapté. Voici ce qui en sort.

### Le briefing, partout où on en a besoin

- **Le PDF du briefing**, écrit directement par l'exécutable à côté du diaporama : mêmes pages, mêmes cartes, sans PowerPoint, Edge ni LibreOffice.
- **Le briefing dans le kneeboard** de chaque appareil : la vue d'ensemble, un zoom par objectif, une fiche de vol (cap et distance de chaque branche, point le plus haut du relief, radios) et les cibles. `kneeboard: false` le désactive.
- **L'ATO d'une mission à slots dynamiques liste ses vols** : sous chaque terrain, les appareils proposés et le premier canal de leur plan radio.
- Les images du briefing vont dans **toutes** les variantes météo de `missions/`, pas seulement dans le `.miz` du build.

### De nouveaux outils pour l'IA

- **`set_route`** écrit le plan de vol des joueurs en une seule action, en donnant le cap et la distance de chaque branche.
- **Le niveau de l'opposition** : `add_group` et `create_combat_zone` acceptent `skill` (de Average à Excellent, ou Random), pour tout le groupe ou unité par unité ; le prompt d'objectif demande le niveau à la conception.
- **`create_combat_zone`** pose statiques et véhicules en un seul appel.
- **Le prompt d'objectif prépare la route selon l'appareil** : une mission basse altitude reçoit la route que son appareil et son époque voleraient, avec deux variantes comparées.
- **Les missions de campagne replacent AWACS et ravitailleurs** selon la menace du jour, et le briefing dit où ils sont et pourquoi.

### Des erreurs qui ne passent plus

- Un ravitailleur créé avec la tâche `Tanker` est enfin un vrai ravitailleur (indicatif Texaco/Arco/Shell, ligne de soutien du briefing, carte).
- Un texte français écrit sans accents est signalé : ce que lit un joueur garde ses accents.
- Des numéros de waypoints qui ne correspondent plus à la route sont signalés.
- Deux points du plan de vol portant le même nom sont injectés tous les deux, au lieu que le second remplace le premier en silence.
- Un statique posé sur un terrain encombré est signalé avec le point dégagé le plus proche.

### La sécurité de la mission, sans passer par l'IA

**`veaf-tools password-hash`** transforme un mot de passe en l'empreinte qu'attend `security.password_hashes`, saisie masquée : le mot de passe ne passe jamais par une conversation avec une IA.
Les prompts expliquent maintenant ce que la sécurité verrouille, et rappellent que le mot de passe livré par défaut est public.

### Claude Cowork

La documentation de l'assistant IA explique comment Claude Cowork, l'assistant dans le cloud, rejoint les outils VEAF installés sur le PC, et quoi faire en premier.

---

## ⚠️ Points d'attention

- **Lecture via l'API REST** : elle demande une version de DCSServerBot qui expose les routes de journaux — pour l'instant, la branche `veaf` de VEAF. Voir la page *Journaux*.
- **Missions COLD_WAR** : leurs slots dynamiques ne proposent plus de F-16C, d'Apache ni de warbirds (le catalogue livré est filtré par époque, le F/A-18C est conservé). Une mission existante peut donc perdre ces slots au prochain build.

## 🙏 Merci

Merci à Martinho, Trakdah, et à tous les autres testeurs pour leurs retours et leurs tests.

---

📖 [veaf-logs — lire les journaux de DCS](https://veaf.github.io/documentation/latest/mission-maker/LOGS/) · [Créer avec une IA](https://veaf.github.io/documentation/latest/mission-maker/AI_ASSISTANT_INSTALL/)
