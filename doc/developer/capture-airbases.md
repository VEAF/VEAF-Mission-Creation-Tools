# Récupérer les aérodromes d'une carte — pas à pas

Tu vas : lancer un petit programme, ouvrir une mission dans DCS, taper une commande.
Ça crée **un fichier** à renvoyer à David. **Une carte à la fois.** Compte 5 minutes.

## Avant de commencer

- **DCS World** installé, avec la carte à traiter.
- Le **kit** : télécharge `veaf-map-capture-kit-<version>.zip` depuis la
  [page des versions VEAF](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases)
  et **dézippe-le dans un dossier**.
  ⚠️ **Garde tout ensemble, ne déplace rien** : les programmes se cherchent entre eux.

---

## 0 · Une manip à faire UNE SEULE FOIS sur ton DCS ⚠️

Par défaut, DCS **interdit** aux scripts de communiquer avec l'extérieur. Sans cette
manip, **rien ne fonctionnera** (la fenêtre noire n'affichera jamais `DCS connected`).

- **Ferme DCS** complètement.
- Ouvre le fichier suivant avec le Bloc-notes *(dans ton dossier d'installation DCS)* :
  `Scripts\MissionScripting.lua`
- **Supprime tout ce qui se trouve à partir de** la ligne qui commence par
  `local function sanitizeModule(name)` — **jusqu'à la fin du fichier**.
- **Enregistre.**

> 🔁 **À refaire après chaque mise à jour de DCS** (les mises à jour remettent le fichier
> d'origine).
> 📖 Détail et explications : [prérequis du dcs-bridge](https://github.com/VEAF/VEAF-dcs-bridge/blob/develop/docs/guide/prerequisites.fr.md).
> Cette manip est la même que celle demandée par d'autres scripts DCS connus (ex. le
> module de synthèse vocale STTS) — si tu l'as déjà faite, tu n'as rien à refaire.

---

## 1 · Démarrer le petit serveur

Double-clique sur **`dcs-serve.exe`**.
→ Une **fenêtre noire** s'ouvre et **reste ouverte**. C'est normal, **laisse-la tranquille**
(ne la ferme pas tant que tu n'as pas fini).

> La fenêtre se referme toute seule ? Un serveur tourne déjà : ferme les autres fenêtres
> noires et recommence.

## 2 · Ouvrir la mission dans DCS

- Lance **DCS**.
- Ouvre la mission **`missions\bridge-<Carte>.miz`** (celle de ta carte).
- Clique sur **play** ▶, puis **choisis le slot « Spectateur »** (*Spectators*) et
  **valide** pour entrer dans la mission.
  → Pas besoin de piloter : il faut juste que la mission **tourne**.
- Attends **~5 secondes**. Dans la fenêtre noire, tu dois voir s'afficher **`DCS connected`**.

> Pas de mission fournie pour ta carte ? Va voir **« Fabriquer la mission toi-même »** en bas.

## 3 · Lancer la récupération

- Ouvre le **dossier du kit** dans l'explorateur Windows.
- Clic droit dans le dossier → **« Ouvrir dans le terminal »**
  *(ou : clique dans la barre d'adresse, tape `cmd`, Entrée)*.
- **Copie-colle** cette ligne, puis Entrée :

  ```
  .\veaf-tools.exe dcs capture-map --out-dir .
  ```

- → Un fichier **`<Carte>.json`** apparaît dans le dossier (ex. `Syria.json`). 🎉

> Rien à configurer : le programme récupère tout seul le code d'accès créé par
> `dcs-serve.exe` (dans le fichier `dcs-serve.yaml`, à côté).

> **Garde le `.\`.** « Ouvrir dans le terminal » ouvre **PowerShell**, qui ne cherche pas dans le
> dossier courant — exprès. Sans le `.\`, il te répond que `veaf-tools.exe` « is not recognized »,
> en te désignant le fichier que tu as sous les yeux. Dans `cmd`, les deux formes marchent, donc
> `.\` est bon partout. Voir
> [PowerShell ou invite de commandes ?](../mission-maker/GUIDE.md#powershell-vs-cmd).

### Si David t'a demandé les places de parking en plus

Ajoute `--parking` à la fin de la ligne :

```
.\veaf-tools.exe dcs capture-map --out-dir . --parking
```

Ça fait **deux** fichiers au lieu d'un : le `<Carte>.json` habituel, plus un
`parking/<Carte>.json` avec les emplacements où un avion peut se garer. C'est un peu plus long
(quelques dizaines de secondes de plus), et les aérodromes sont récupérés **en premier** — donc si
la deuxième partie coince, tu as quand même la première, la plus utile.

Une carte qui ne renvoie aucune place de parking, ce n'est pas une panne : certaines n'en ont
simplement pas. Envoie les deux fichiers dans ce cas aussi.

## 4 · L'envoyer

Envoie ce fichier `<Carte>.json` à **David**. Fini pour cette carte !

**Carte suivante :** quitte la mission dans DCS, ouvre la mission de l'autre carte,
et refais les étapes **2 → 4**. (Inutile de relancer la fenêtre noire, laisse-la.)

---

## Les cartes : ce qui est fait, ce qui reste

Coche au fur et à mesure. **Inutile de refaire une carte déjà cochée.**

### ✅ Toutes les cartes DCS actuelles sont couvertes 🎉

- [x] **Syria** · **Caucasus** · **Cold War Germany** · **Marianas** · **Normandy**
- [x] **Persian Gulf** · **Sinai** — *relevées par David*
- [x] **Nevada** · **The Channel** (la Manche) · **South Atlantic** (Malouines) · **Kola**
- [x] **Afghanistan** · **Iraq** · **Marianas WWII** (Mariannes 1944) — *relevées par Reaper, merci !*

**Il n'y a donc plus rien à relever pour l'instant.** Ce dont on aura encore besoin :

- **une nouvelle carte DCS sort** → relève-la (la mission se fabrique en deux minutes dans
  l'éditeur, voir juste en dessous) ;
- **une carte existante gagne des terrains** dans une mise à jour → un nouveau relevé
  remplace simplement l'ancien.

---

## Fabriquer la mission toi-même (carte non fournie)

1. Dans DCS : **Mission Editor** → **New Mission**.
2. Choisis la **carte**.
3. Pose **un avion** n'importe où *(obligatoire — sinon DCS refuse d'enregistrer)*.
4. **Enregistre** (*Save*) en `.miz`. Retiens l'endroit.
5. Dans le terminal (comme à l'étape 3), tape *(mets le vrai chemin de ta mission)* :

   ```
   .\veaf-tools.exe dcs inject-bridge "C:\...\ma-mission.miz"
   ```

   → Ta mission est prête (une copie de secours est créée automatiquement à côté).
6. Ouvre cette mission dans DCS et reprends aux étapes **2 → 4**.

---

## Si ça coince

| Ce que tu vois | Quoi faire |
|---|---|
| La fenêtre noire se referme aussitôt | Un serveur tourne déjà — ferme les autres fenêtres noires, recommence l'étape 1. |
| `cannot reach dcs-serve` | La fenêtre noire (étape 1) n'est pas ouverte. Relance `dcs-serve.exe`. |
| La fenêtre noire n'affiche jamais `DCS connected` | **L'étape 0 n'a pas été faite** (ou une mise à jour de DCS l'a annulée). Refais-la. |
| `504` ou `bridge exec failed` | Tu n'es pas **entré** dans la mission (slot Spectateur), ou elle démarre encore. Vérifie que la fenêtre noire affiche `DCS connected`, attends 5 s, réessaie. |
| `no API key found` | `dcs-serve.exe` n'a jamais été lancé depuis ce dossier (c'est lui qui crée le fichier `dcs-serve.yaml`). Fais l'étape 1, puis réessaie. |
| `HTTP 403` | Le code d'accès ne correspond pas : ferme la fenêtre noire, relance `dcs-serve.exe`, réessaie. |

Un souci non listé ? Fais une capture d'écran et envoie-la à David.
