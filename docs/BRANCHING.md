# Branching model

```
feature/*  ──▶  development  ──▶  qa  ──▶  release  ──▶  main
hotfix/*   ──▶  main  (then merged back down)
```

## The branches

| Branch | Purpose | Cut from | Merges into |
|---|---|---|---|
| `main` | Production. Only ever receives `release` (or a hotfix). | — | — |
| `release` | Release candidate. The only branch that merges into `main`. | `qa` | `main` |
| `qa` | Integration testing. | `development` | `release` |
| `development` | Shared integration branch; the base for all feature work. | `main` | `qa` |
| `feature/*` | One unit of work. | **`development`** | `development` |
| `hotfix/*` | Urgent production fix. The **only** branch cut from `main`. | **`main`** | `main`, then back down |

## Rules

1. **Never commit directly to `main`, `release`, `qa` or `development`.** Work
   happens on a `feature/*` branch and arrives by pull request.
2. **Feature branches are cut from `development`**, never from `main`.
3. Promotion is one step at a time: `development` → `qa` → `release` → `main`.
   Nothing skips a rung.
4. **`hotfix/*` is the only branch cut from `main`.** After it merges to `main`
   it must also be merged back down into `release`, `qa` and `development`, or
   the fix is silently lost at the next release.
5. Keep a feature branch to one concern, so it can be reviewed and reverted on
   its own.

## Naming

```
feature/backend-splitter-pipeline
feature/flutter-operator-app
hotfix/whatsapp-link-encoding
```

Short, kebab-case, describing the change rather than the ticket.
