# System Architecture

## Layered design

```
config/inventory_targets.yaml   Approved target definitions (name + path)
        │
templates/inventory_report_template.md   Required report shape (all tasks conform)
        │
scripts/lib/inventory_engine.zsh   Shared scan/lock/stage/validate/publish logic (D7, 2026-08-02)
        │
scripts/0N_<target>_inventory.zsh   Thin wrapper: sources the library, names task number + target
        │
inventory/<Target>/             Per-target staging: metadata.csv, metadata.json, summary.md
        │
reports/0N_*.txt + logs/         Human-readable run report + optional debug trace
```

Each layer only depends on the layer above it. Adding a new approved target requires touching exactly one file (`config/inventory_targets.yaml`) plus creating its `inventory/<Target>/` directory, plus a ~15-line wrapper script — no changes to the shared engine unless the target needs genuinely different behavior.

## History: from six clones to one library (D7)

Tasks 03-08 (Documents, Desktop, Downloads, Pictures, Movies, Music) were originally six near-identical scripts, each hand-cloned from the last with exactly six categories of mechanical change (target name, paths, lock dir, error strings). This was deliberate at the time (`DECISIONS.md` D7) — one validated target isn't enough evidence to justify a shared abstraction, and refactoring mid-rollout risks destabilizing an already-working pipeline. Once all 5 non-Documents targets were cloned and validated with zero logic divergence across any of them, that evidence justified folding the shared logic into `scripts/lib/inventory_engine.zsh`, leaving each numbered script as a thin wrapper. `ls scripts/` is still self-documenting and every script still runs with no arguments — the consolidation is invisible from the outside.

## Execution model (shared engine: `scripts/lib/inventory_engine.zsh`, function `run_inventory_task`)

Every wrapper script sets `PROJECT_DIR`, sources the library, and calls `run_inventory_task <TASK_NUM> <TargetName>`. That function does, identically for every target:

1. **Preflight.** Confirm running from the repository root; confirm config, template, and output directory exist; resolve the target path from config via a parameterized `awk` lookup (`-v name="$TARGET_NAME"`, tested against all 8 configured targets).
2. **Lock.** Acquire an mkdir-based execution lock (`logs/.task<N>.lock`). A live lock aborts the run; a stale lock (dead PID) is reclaimed. Added 2026-08-02 — see `DECISIONS.md`.
3. **Stage.** Generate a run-unique Inventory ID (`INV-YYYYMMDD-HHMMSS`) and a private `mktemp -d` staging directory under `inventory/<Target>/`. All CSV/JSON/summary/report writes go here, never to the final path.
4. **Scan.** A single `find -xdev ...` pass walks the target. Package directories (`.app`, `.bundle`, `.framework`, `.kext`, `.pages`, `.numbers`, `.key`, `.photo library`, `.photoslibrary`, `.sparsebundle`) get their own `-exec stat ... {} \; -prune` branch — matched once via `-prune` listed *before* `-exec` (so pruning is guaranteed regardless of whether the stat side-action succeeds, `DECISIONS.md` D14) — recording exactly one `IsPackage=true` row per package and never descending into it. Everything else is stat'd via the original batched `-exec ... {} +` branch. `-xdev` prevents crossing mount points (excludes external volumes and network shares by design). Prior to D14 (2026-08-02), package directories were excluded from the inventory entirely rather than recorded once — a latent gap in the original D2 design present since this project's start, only noticed via Pictures' `.photoslibrary` (D13).
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
