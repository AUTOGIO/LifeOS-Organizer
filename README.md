# LifeOS Organizer

Local-first, read-only-first filesystem inventory and organization framework for macOS. Builds a canonical, auditable metadata record before any AI-assisted classification or file mutation is authorized.

## Status

Infrastructure & Inventory phase. See `PROJECT_CONTEXT.md` for current state and `EXECUTIVE_REPORT.md` for the latest summary.

## Directory layout

```
config/      Approved inventory targets (config/inventory_targets.yaml)
docs/        Engine architecture and safety rules
inventory/   One staging directory per approved target; holds metadata only
logs/        Execution debug logs
plans/       Reserved for future planning artifacts
reports/     Human-readable run reports, one per task
scripts/     Task scripts (zsh, run from repository root)
templates/   Shared report template
```

## Requirements

- macOS (Apple Silicon), zsh, standard BSD userland tools (`find`, `stat`, `awk`, `mdls`).
- Scripts must be run from the repository root: `/Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer`.
- No sudo, no network access, no dependencies outside macOS system tools and Python 3 (used only for artifact validation).

## Running a task

See `RUNBOOK.md` for exact commands, including recovery from a stuck run. Quick reference:

```
cd /Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer
./scripts/01_environment_baseline.zsh   # environment/safety baseline
./scripts/02_inventory_engine.zsh       # framework readiness check
./scripts/03_documents_inventory.zsh    # Documents metadata inventory
./scripts/04_desktop_inventory.zsh      # Desktop metadata inventory
```

Every task script enforces an execution lock — only one instance of a given script may run at a time.

## Safety contract

1. Inventory before organization.
2. Metadata before AI.
3. Read-only before remediation.
4. Human approval before mutation.
5. No deletion during the initial project.
6. Every future mutation is logged with a rollback map.

Full rules: `docs/SAFETY_RULES.md`. Full governance: `PROJECT_CHARTER.md`.

## Documentation index

| Doc | Purpose |
|---|---|
| PROJECT_CONTEXT.md | Current state, environment, what's done |
| PROJECT_CHARTER.md | Objective, scope, governance principles |
| EXECUTIVE_REPORT.md | Status summary for review |
| SYSTEM_ARCHITECTURE.md | How the engine is structured |
| ROADMAP.md | Now / Next / Later |
| AI_COLLABORATION.md | Rules for AI-assisted changes to this project |
| DECISIONS.md | Architecture decision log |
| RUNBOOK.md | Exact operational commands |
| QUALITY_GATES.md | Validation gates in the pipeline |
| RISK_REGISTER.md | Known risks and mitigations |
| CHANGELOG.md | Dated change history |
