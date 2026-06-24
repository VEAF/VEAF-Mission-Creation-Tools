# Transverse Instructions (All Projects)

## 1. Language and Communication
- **Communication**: Automatically adapt to the language used by the user in their messages.
- **Code & Documentation**: Exclusively use English for functions, variables, comments, docstrings, commit messages, PR descriptions, and all technical project documentation.

## 2. AI Behavior (Surgical Mode)
- **RULE N°1 (Surgical Changes)**: NEVER modify adjacent code, comments, or formatting that are not directly related to the request. Do not refactor functional code.
- **RULE N°2 (Absolute Simplicity)**: Produce the minimum volume of code necessary to solve the current problem. Do not add any speculative features or abstractions.
- **RULE N°3 (Zero Assumptions)**: If an instruction is ambiguous, contradictory, or confusing, STOP immediately and ask questions to clarify the intent.

## 3. Code Quality and Style (Zero Tolerance)
- **IDE Errors**: No warnings or errors must remain in the editor (Pylance, mypy, ruff, markdown-lint).
- **Static Typing**: Type annotations are mandatory for all functions with explicit return syntax `-> ReturnType`. Use modern unions like `Type | None`.
- **Docstrings**: Write comprehensive docstrings strictly following the Google format (with `Args:`, `Returns:`, `Raises:` sections).

## 4. TDD and Behavioral Coverage Rule
- **TDD Cycle**: Always write a failing unit test before implementing any business logic, make the test pass, then refactor.
- **COVERAGE RULE (Zero Regression)**:
  - *New Code*: Every new function, method, or class must be delivered with its corresponding unit tests. Code is considered incomplete without its tests.
  - *Existing Code*: Any modification to existing business logic requires updating existing tests or creating a new test if it is missing.

## 5. Git Flow and Commits
- **Branch Management**: All work must be done on feature branches (`feature/*` or `fix/*`) created from `develop`. Never commit directly to `master` or `main`.
- **Commit Messages**: Scrupulously respect the Conventional Commits specification in English (`type(scope): description`).

## 6. Backlog and Roadmap Maintenance
- **Real-Time Updates**: the `.backlog/` directory and `ROADMAP.md` must exactly reflect task status. Each active lot is a directory `.backlog/<LOT-ID>/` (PRD.md + tickets); `.backlog/README.md` is the lot index, maintained by hand.
- **Archiving**: move lots closed for more than 3 days from `.backlog/<LOT-ID>/` to a compact `.backlog/archive/<LOT-ID>.md`.