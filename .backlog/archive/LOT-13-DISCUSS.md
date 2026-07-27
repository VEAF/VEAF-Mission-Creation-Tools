# Lot 13 — DISCUSS: Standards industrie — à évaluer et décider

Status: ✅ done

**Goal**: Évaluer les standards industrie manquants et décider lesquels adopter. Chaque ticket est un point de discussion/décision avant implémentation éventuelle.
**Branch**: `feature/disc-wave3` (PR #320 mergée)
**Statut**: ✅ Lot terminé — DISC-001/002/003/004/005/006/007/008/009/010/011/012/013/014/015/017/019 implémentés — DISC-016 rejeté (proxy silencieux dans LUAR-001) — DISC-018 rejeté (sur-ingénierie)

| # | Ticket | Type | Effort si adopté | Status |
|---|--------|------|-----------------|--------|
| DISC-008 | Release automation complète — GitHub Actions workflow sur tag push (build + publish, zéro intervention manuelle) | feat | 120 min | ✅ |
| DISC-014 | Documentation versionnée — lier les docs à une release (GitHub Pages tags ou dossiers versionnés) | feat | 90 min | ✅ |
| DISC-016 | API deprecation warnings — système de warnings Lua quand des fonctions legacy sont appelées | feat | 45 min | ❌ |
| DISC-018 | Monorepo workspace Poetry — structurer `veaf-tools` + `veaf_build` comme un vrai workspace avec dépendances explicites | chore | 60 min | ❌ |
| DISC-019 | GitHub Pages — publier la documentation (`doc/`) sur `https://veaf.github.io/VEAF-Mission-Creation-Tools-v6/` via GitHub Actions (déclenchement sur merge PR vers `develop` / `main`) | feat | 60 min | ✅ |
| DISC-001 | Pre-commit hooks (`pre-commit` framework) : ruff + stylua + luacheck + detect-secrets | chore | 45 min | ✅ |
| DISC-002 | Ajouter `luacheck` au CI (lint statique Lua — undefined globals, unused vars, shadowing) | chore | 60 min | ✅ |
| DISC-003 | Coverage reporting en CI (Codecov ou Coveralls) + badge README + seuil `--cov-fail-under` | chore | 30 min | ✅ |
| DISC-004 | `CONTRIBUTING.md` + PR template + issue templates (bug report / feature request) | chore | 45 min | ✅ |
| DISC-005 | `SECURITY.md` — politique de disclosure des vulnérabilités | chore | 15 min | ✅ |
| DISC-006 | `CODEOWNERS` — auto-assign reviewers par path (`src/scripts/` → Lua team, `src/python/` → Python team) | chore | 10 min | ✅ |
| DISC-007 | Dependabot ou Renovate — auto-update des dépendances Python + GitHub Actions | chore | 20 min | ✅ |
| DISC-009 | `.editorconfig` — uniformité des settings IDE (indentation, EOL, trim trailing whitespace) | chore | 10 min | ✅ |
| DISC-010 | DevContainer / Docker — environnement dev reproductible (Python 3.13 + Lua 5.1 + outils) | feat | 90 min | ✅ |
| DISC-011 | Signed commits / tag signing — intégrité supply chain | chore | 15 min | ✅ |
| DISC-012 | Branch protection rules — require CI pass + review avant merge | chore | 10 min | ✅ |
| DISC-013 | Changelog automation (`git-cliff` ou `release-please` + conventional commits) | feat | 60 min | ✅ |
| DISC-015 | SBOM (Software Bill of Materials) — traçabilité des dépendances embarquées dans l'exe | chore | 30 min | ✅ |
| DISC-017 | Secret scanning — activer GitHub secret scanning ou intégrer `gitleaks` en CI | chore | 15 min | ✅ |

**Effort total si tout adopté: ~830 min (~13h50)**
⚠️ Chaque ticket doit être discuté individuellement — certains seront adoptés, d'autres rejetés ou reportés.

<details>
<summary>Points de discussion par ticket</summary>

**DISC-001 — Pre-commit hooks**
- **Pour** : Catch les erreurs avant le push, impossible d'oublier de formatter
- **Contre** : Friction pour les contributeurs occasionnels, complexifie le setup
- **Question** : Est-ce que les contributeurs sont suffisamment techniques pour installer `pre-commit` ? Ou suffit-il de compter sur la CI ?

**DISC-002 — Luacheck**
- **Pour** : Détecte des vrais bugs (undefined globals, unused vars, variable shadowing comme `local coalition = coalition`). StyLua ne vérifie que le formatage.
- **Contre** : Configuration initiale complexe (beaucoup de globals DCS à déclarer), bruit potentiel
- **Question** : Le `.luarc.json` remplit déjà partiellement ce rôle. Luacheck en CI apporte-t-il un gain suffisant ?
- **Recommandation** : Oui, fort gain. La liste de globals est déjà dans `.luarc.json` — convertible en `.luacheckrc`.

**DISC-003 — Coverage CI**
- **Pour** : Visibilité, empêche les régressions, motive l'écriture de tests
- **Contre** : Seuil bas (15%) est symbolique ; seuil haut inatteignable à court terme
- **Question** : Quel seuil initial ? Monter graduellement (15% → 30% → 50%) ?
- **Recommandation** : Commencer à 15%, monter de 5% par lot.

**DISC-004 — CONTRIBUTING.md**
- **Pour** : Standard OSS, onboarde les nouveaux contributeurs
- **Contre** : Overhead de maintenance si peu de contributeurs externes
- **Question** : Le projet a-t-il des contributeurs externes réguliers ou est-ce principalement l'équipe VEAF ?

**DISC-005 — SECURITY.md**
- **Pour** : GitHub affiche un avertissement si absent, standard pour tout projet public
- **Contre** : Quasi-gratuit à créer (template GitHub)
- **Recommandation** : Adopter (5 min de travail réel)

**DISC-006 — CODEOWNERS**
- **Pour** : Auto-assign les bons reviewers, protège les chemins critiques
- **Contre** : Nécessite de définir les responsabilités formellement
- **Question** : Qui sont les reviewers Lua vs Python ?

**DISC-007 — Dependabot/Renovate**
- **Pour** : Alerte sur les vulnérabilités, PR automatiques pour updates
- **Contre** : Bruit (PRs fréquentes), risque de casser PyInstaller si pas de bornes
- **Recommandation** : Adopter Dependabot avec `open-pull-requests-limit: 5` et grouping

**DISC-008 — Release automation** ✅
- **Décision** : Full-auto — tag push `published-v*` déclenche build + publish via GitHub Actions
- **Notes** : git-cliff génère les release notes depuis les commits conventionnels ; le dev peut enrichir/traduire sur GitHub après la release
- **Implémenté dans** : `feature/disc-008-release-automation` — `.github/workflows/release.yml`, `--ci` flag sur `veaf-build publish`

**DISC-009 — .editorconfig**
- **Pour** : Fonctionne avec tous les IDE, pas de dépendance à VS Code settings
- **Contre** : Quasi-gratuit, pas de raison de ne pas le faire
- **Recommandation** : Adopter immédiatement (5 min)

**DISC-010 — DevContainer**
- **Pour** : Zéro-config pour les nouveaux développeurs, environnement identique pour tous
- **Contre** : Docker requis, overhead pour dev habitués à leur propre env
- **Question** : Les contributeurs sont-ils sous Windows (DCS = Windows only) ? Un devcontainer Linux est-il pertinent pour un projet DCS ?
- **Recommandation** : Utile surtout pour la CI reproductible. En dev local, documenter le setup Windows suffit peut-être.

**DISC-011 — Signed commits**
- **Pour** : Intégrité supply chain (important pour un .exe distribué à la communauté)
- **Contre** : Complexifie le workflow (GPG keys), freine les contributeurs occasionnels
- **Recommandation** : Au minimum, signer les tags de release (pas tous les commits)

**DISC-012 — Branch protection rules**
- **Pour** : Empêche les push directs sur `develop` et `main`, garantit que le CI passe avant tout merge. Standard pour tout projet collaboratif.
- **Contre** : Peut bloquer des hotfixes urgents si le CI est cassé pour une raison externe
- **Statut** : ✅ Implémenté — settings à appliquer dans GitHub Settings (action admin requise)

**Settings à appliquer** sur `develop` et `main` :

*GitHub → Settings → Branches → Add branch protection rule*

| Setting | Valeur recommandée |
|---------|-------------------|
| Require a pull request before merging | ✅ (1 approval required) |
| Require status checks to pass | ✅ |
| — Status checks : `Lua Unit Tests` | ✅ |
| — Status checks : `StyLua Formatting` | ✅ |
| — Status checks : `python-quality` | ✅ |
| Require branches to be up to date | ✅ |
| Do not allow bypassing the above settings | ❌ (laisser l'escape hatch admin) |
| Restrict who can push to matching branches | Optionnel |

**DISC-013 — Changelog automation**
- **Pour** : Plus d'oublis, changelog toujours à jour
- **Contre** : Impose conventional commits (`feat:`, `fix:`, `chore:`) — changement d'habitude
- **Question** : L'équipe est-elle prête à adopter conventional commits ?

**DISC-014 — Documentation versionnée**
- **Pour** : Un utilisateur en v6.0.3 voit les docs correspondantes, pas les docs de develop
- **Contre** : Complexité GitHub Pages, maintenance de branches docs
- **Recommandation** : Reporter — pertinent quand il y aura des breaking changes entre versions

**DISC-015 — SBOM**
- **Pour** : Le projet distribue un `.exe` PyInstaller qui embarque des dizaines de bibliothèques tierces. Un SBOM (`cyclonedx-bom` ou `syft`) permet d'auditer les licences et de détecter des CVEs dans les dépendances embarquées. Standard dans la communauté open-source depuis le décret US 2021.
- **Contre** : Peu d'utilisateurs VEAF ne vont pas auditer le SBOM. Overhead de génération et de publication.
- **Recommandation** : Générer le SBOM en artifact CI sans le publier obligatoirement — coût quasi-nul, utilisable si besoin.

**DISC-016 — Deprecation warnings Lua** ❌ Rejeté (2026-05-21)
- **Décision** : Rejeté. LUAR-001 utilise un proxy **silencieux et transparent** — `veafSpawn.lua` ré-exporte les fonctions publiques sans warning. Les missions existantes continuent de fonctionner indéfiniment sans modification, et sans bruit dans les logs DCS. Les deprecation warnings ajouteraient de l'overhead (un wrapper par fonction) pour un bénéfice nul : l'API publique de `veafSpawn` ne sera pas supprimée.

**DISC-017 — Secret scanning**
- **Pour** : Détecte les API keys, tokens, mots de passe accidentellement commités. GitHub secret scanning est gratuit sur les repos publics et couvre des centaines de patterns (AWS, GCP, GitHub tokens, etc.). `gitleaks` en CI ajoute une couche pour les secrets maison.
- **Contre** : Faux positifs possibles (ex : clés DCS dans les fichiers de mission). Configuration du `.gitleaksignore` nécessaire.
- **Recommandation** : Activer GitHub secret scanning (zéro coût, zéro configuration). `gitleaks` en CI est optionnel — à voir si les faux positifs sont gérables.

**DISC-018 — Monorepo workspace Poetry** ❌ Rejeté (2026-05-21)
- **Décision** : Rejeté. La situation actuelle (un seul `pyproject.toml`, `veaf_build` embarqué via `packages`) fonctionne correctement. Poetry workspace 2.x est une fonctionnalité récente dont la maturité sur Windows reste à confirmer, le refactoring des imports serait non trivial, et le gain est marginal pour un projet sans équipes séparées sur les deux packages. Pas assez intéressant pour le coût.

**DISC-019 — GitHub Pages**
- **Situation actuelle** : La documentation (`doc/`) existe uniquement dans le repo Git — pas de site web navigable, pas d'URL publique stable.
- **Ce que proposerait DISC-019** : Publier automatiquement `doc/` sur GitHub Pages (`https://veaf.github.io/VEAF-Mission-Creation-Tools/`) via un workflow GitHub Actions déclenché sur push `develop` et sur chaque tag. Utiliser [MkDocs](https://www.mkdocs.org/) (Material theme) ou simplement servir les Markdown via GitHub Pages natif. Lien DISC-014 (docs versionnées) — DISC-019 est le prérequis.
- **Pour** : URL stable et partageable pour les utilisateurs, navigabilité entre les pages, moteur de recherche intégré (MkDocs Material), nul coût d'hébergement.
- **Contre** : Nécessite de choisir et configurer un générateur de site statique. MkDocs ajoute une dépendance Python (groupe `docs`).
- **Recommandation** : Adopter — c'est la norme pour les projets open-source. MkDocs Material est le choix le plus rapide à mettre en place.

</details>
