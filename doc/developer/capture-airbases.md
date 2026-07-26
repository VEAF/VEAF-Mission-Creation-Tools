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
  veaf-tools.exe capture-map --out-dir .
  ```

- → Un fichier **`<Carte>.json`** apparaît dans le dossier (ex. `Syria.json`). 🎉

> Rien à configurer : le programme récupère tout seul le code d'accès créé par
> `dcs-serve.exe` (dans le fichier `dcs-serve.yaml`, à côté).

## 4 · L'envoyer

Envoie ce fichier `<Carte>.json` à **David**. Fini pour cette carte !

**Carte suivante :** quitte la mission dans DCS, ouvre la mission de l'autre carte,
et refais les étapes **2 → 4**. (Inutile de relancer la fenêtre noire, laisse-la.)

---

## Les cartes : ce qui est fait, ce qui reste

Coche au fur et à mesure. **Inutile de refaire une carte déjà cochée.**

### ✅ Déjà récupérées

- [x] **Syria**
- [x] **Caucasus**
- [x] **Cold War Germany** (Allemagne guerre froide)
- [x] **Marianas** (Mariannes)
- [x] **Normandy** (Normandie)
- [x] **Persian Gulf** (Golfe Persique)
- [x] **Sinai** (Sinaï)

### ⬜ À récupérer (si tu as la carte)

- [ ] **Nevada** (NTTR)
- [ ] **The Channel** (la Manche)
- [ ] **South Atlantic** (Atlantique Sud / Malouines)
- [ ] **Kola**
- [ ] **Afghanistan**
- [ ] **Iraq** (Irak)
- [ ] **Marianas WWII** (Mariannes 1944)

> Tu n'as pas une carte ? Passe simplement à la suivante — on prend ce que tu as.
> Une nouvelle carte est sortie et n'est pas dans la liste ? Fais-la quand même
> (voir juste en dessous), ça nous intéresse !

---

## Fabriquer la mission toi-même (carte non fournie)

1. Dans DCS : **Mission Editor** → **New Mission**.
2. Choisis la **carte**.
3. Pose **un avion** n'importe où *(obligatoire — sinon DCS refuse d'enregistrer)*.
4. **Enregistre** (*Save*) en `.miz`. Retiens l'endroit.
5. Dans le terminal (comme à l'étape 3), tape *(mets le vrai chemin de ta mission)* :

   ```
   veaf-tools.exe inject-bridge "C:\...\ma-mission.miz"
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
