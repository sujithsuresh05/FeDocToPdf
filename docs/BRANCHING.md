# Branching model

```
feature/*  ──▶  Development  ──▶  QA  ──▶  Release  ──▶  main
hotfix/*   ──▶  main  (then merged back down)
```

## The branches

| Branch | Purpose | Cut from | Merges into |
|---|---|---|---|
| `main` | Production. Only ever receives `Release` (or a hotfix). | — | — |
| `Release` | Release candidate. The only branch that merges into `main`. | `QA` | `main` |
| `QA` | Integration testing. | `Development` | `Release` |
| `Development` | Shared integration branch; the base for all feature work. | `main` | `QA` |
| `feature/*` | One unit of work. | **`Development`** | `Development` |
| `hotfix/*` | Urgent production fix. The **only** branch cut from `main`. | **`main`** | `main`, then back down |

## Rules

1. **Never commit directly to `main`, `Release`, `QA` or `Development`.** Work
   happens on a `feature/*` branch and arrives by pull request.
2. **Feature branches are cut from `Development`**, never from `main`.
3. Promotion is one step at a time: `Development` → `QA` → `Release` → `main`.
   Nothing skips a rung.
4. **`hotfix/*` is the only branch cut from `main`.** After it merges to `main`
   it must also be merged back down into `Release`, `QA` and `Development`, or
   the fix is silently lost at the next release.
5. Keep a feature branch to one concern, so it can be reviewed and reverted on
   its own.

## Naming

Branch names are **case-sensitive on GitHub**, so use the exact names above —
`Development`, not `development`. Feature and hotfix branches are lower-case
kebab-case after the prefix:

```
feature/backend-splitter-pipeline
feature/flutter-operator-app
hotfix/whatsapp-link-encoding
```

Short, describing the change rather than the ticket.
