# System Architecture

## Layered design

```
config/inventory_targets.yaml   Approved target definitions (name + path)
        │
templates/inventory_report_template.md   Required report shape (all tasks conform)
        │
inventory/<Target>/             Per-target staging: metadata.csv, metadata.json, summary.md
        │
scripts/0N_*.zsh                One script per task; read-only until explicitly extended
        │
reports/0N_*.txt + logs/         Human-readable run report + optional debug trace
```

Each layer only depends on the layer above it. Adding a new approved target requires touching exactly one file (`config/inventory_targets.yaml`) plus creating its `inventory/<Target>/` directory — no script changes.

## Execution model (current: `03_documents_inventory.zsh`)

1. **Preflight.** Confirm running from the repository root; confirm config, template, and output directory exist; resolve the target path from config.
2. **Lock.** Acquire an mkdir-based execution lock (`logs/.task03.lock`). A live lock aborts the run; a stale lock (dead PID) is reclaimed. Added 2026-08-02 — see `DECISIONS.md`.
3. **Stage.** Generate a run-unique Inventory ID (`INV-YYYYMMDD-HHMMSS`) and a private `mktemp -d` staging directory under `inventory/<Target>/`. All CSV/JSON/summary/report writes go here, never to the final path.
4. **Scan.** A single `find -xdev ... -exec stat -f ... {} +` pass walks the target, pruning package directories (`.app`, `.bundle`, `.framework`, `.kext`, `.pages`, `.numbers`, `.key`, `.photo library`, `.sparsebundle`) so they are recorded once and not descended into. `-xdev` prevents crossing mount points (excludes external volumes and network shares by design).
5. **Emit.** Each entry is written to both CSV and JSON concurrently via open file descriptors (`>&3`, `>&4`), one pass, no second traversal.
6. **Aggregate.** Extension counts, largest files, largest directories, and per-directory size rollups are computed in-memory during the same pass.
7. **Validate.** Before anything touches the final path, an embedded Python check parses both staged files back, confirms row-count parity between CSV and JSON, and confirms every record carries the run's Inventory ID. A validation failure aborts the run and leaves prior published artifacts untouched.
8. **Publish.** Only after validation passes: four atomic `mv` operations move the staged CSV, JSON, summary, and report into their final locations.
9. **Release.** An `EXIT`/`HUP`/`INT`/`TERM` trap removes both the staging directory and the execution lock regardless of how the script exits.

## Why staging + validate + atomic move

A direct write to the final path is visible mid-write and unrecoverable if the process dies partway through. Staging in an isolated `mktemp -d`, validating the complete result, and only then doing an atomic `mv` means the final path is either the previous good artifact or a fully validated new one — never a partial write. See `RISK_REGISTER.md` for the incident this protects against and `QUALITY_GATES.md` for what the validation step actually checks.

## What the architecture explicitly does not do

- No content of any file is opened, parsed, hashed, or previewed.
- No Spotlight enrichment unless explicitly opted in (`COLLECT_SPOTLIGHT=1`), to keep large scans bounded.
- No target outside `config/inventory_targets.yaml` is ever touched.
- No mutation logic exists yet at any layer — this architecture covers inventory only, per the charter's "metadata before AI" and "read-only before remediation" ordering.
