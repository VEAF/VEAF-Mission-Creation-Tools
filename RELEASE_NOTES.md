# VEAF Mission Creation Tools — 6.38.0

**Des kneeboards d'Open Training qui tiennent dans leur page, des photos de reco prises zone par zone, et des groupes de spawn qui retrouvent leurs unités manquantes.**

---

## 🗺️ Kneeboards des Open Training

- **Un titre long passe à la ligne** au lieu de sortir de la page.
- **La fiche Commandes tient de nouveau sur une page.**
- **La photo de reco d'une zone est sous son zoom**, sur la même page : le pilote voit la carte et la photo ensemble. Falklands passe de 67 à 40 pages.
- La légende de la photo est en degrés et minutes décimales, et une entrée de la liste des zones n'est plus coupée entre deux pages.

---

## 📷 Photos de reco

- `recon-plan` ne vise que les zones de combat, suit les objectifs du kneeboard quand il existe, et vise chaque prise depuis la base donnée par `--from`.
- `recon-shoot` active la zone de chaque prise toute seule, laisse le terrain se charger, et prend la photo avec la capture d'écran de DCS.
- `recon-render` entoure chaque groupe, véhicules en mouvement compris, et l'étiquette par catégorie (blindés lourds, défense sol-air courte portée…).

---

## 🔧 Corrections

- **Des groupes de spawn livrés perdaient des unités** : quatorze types d'unités étaient appelés par leur nom d'affichage dans l'éditeur, que le runtime ne trouve pas. Le poste de commandement SA-18 de `Red Manpad Squad` et de `Red EWR`, et les camions des convois de ravitaillement, sont de retour.
- **Un build qui produit un exe incapable de démarrer échoue** au lieu de rendre la main comme si tout allait bien.
