# Quality Gates

Gates that already exist in code, and what still needs one.

## Task 02 — framework readiness gate

`scripts/02_inventory_engine.zsh` checks, before any inventory task may run:

- All required project directories exist (`docs`, `scripts`, `reports`, `plans`, `logs`, `inventory`, `templates`, `config`).
- All eight per-target inventory staging directories exist.
- `config/inventory_targets.yaml` and `templates/inventory_report_template.md` exist.
- The project directory and `reports/` are writable.
- Every configured target path currently exists on disk (`WARN`, not `FAIL`, if a path is temporarily unavailable — e.g. an unmounted volume).

Result is `READY` only at 0 failures. Last run: 0 failures, 0 warnings (`reports/02_inventory_engine.txt`).

## Task 03 — pre-publish artifact validation gate

Before `scripts/03_documents_inventory.zsh` moves anything into its final path, an embedded Python check must pass:

1. Inventory ID matches the expected format (`INV-\d{8}-\d{6}` as of 2026-08-02).
2. `metadata.csv` parses as valid CSV.
3. `metadata.json` parses as valid JSON.
4. CSV row count equals JSON record count.
5. Every CSV row's `InventoryID` matches the run's ID.
6. Every JSON record's `InventoryID` matches the run's ID.
7. The run's Inventory ID string appears in both `summary.md` and the report file.

Any failure aborts the run (`exit 1`) and leaves the previously published artifacts untouched — this is what makes a failed run safe rather than destructive.

## Task 03 — execution gate (added 2026-08-02)

- Only one instance may hold the execution lock (`logs/.task03.lock`) at a time. A second invocation fails immediately rather than racing on shared paths. This closes the gap that caused the 2026-08-01 corruption (`RISK_REGISTER.md`).

## Package directory recording (corrected 2026-08-02, `DECISIONS.md` D14)

Before D14, the shared `find` prune expression excluded matched package directories (`.app`, `.pages`, `.photoslibrary`, etc.) entirely — not just their contents — because of how `-prune`/`-o` short-circuiting works. `IsPackage=true` had never actually appeared in any published inventory. Fixed by giving the package branch its own `-exec ... \; -prune` (prune listed first, so it fires even if the stat side-action fails) — verified with a controlled test forcing the action to fail before trusting it on a real run.

## Gaps — not yet covered

- **Validation checks consistency, not plausibility** (`RISK_REGISTER.md` R10, found 2026-08-02). A scan that silently fails and produces 0 files still passes today's gate (0 CSV rows = 0 JSON records, trivially consistent) and will overwrite a previous good result. **Partially closed 2026-08-02** (`DECISIONS.md` D15): `run_inventory_task` now refuses to publish if a scan yields zero directory entries (the root is always one, so this can only mean the scan itself failed silently), bypassable only via explicit `ALLOW_EMPTY_RESULT=1`. Still no large-but-nonzero-drop check — a scan that returns far fewer files than the previous run, but not zero, still passes silently.
- **Classification/triage empty-publish** (`RISK_REGISTER.md` R11). **Closed 2026-08-02** (`DECISIONS.md` D16): both engines refuse empty publish when upstream has usable content.

- **Tasks 01 and 02 write directly to their report paths**, with no staging/validation step. Acceptable today because both are fast, idempotent, and produce a single small text file, but if either script grows in scope, apply the same staged-publish pattern used in Task 03.
- **Minimal synthetic harness exists** (`tests/run_synthetic_guards.zsh`) covering R10, package prune, and R11 empty-classification/triage guards — not a full offline suite for every script path.
- **No schema version field** in `metadata.csv` / `metadata.json`. If the column set changes in a future task revision, older and newer artifacts are distinguishable only by inspecting the header row, not by a declared version. Worth adding before a second target's schema needs to diverge from Documents'.
- **No automated verification that AI-authored script changes were syntax-checked.** Prefer `zsh -n` on the target Mac before trusting a future AI-authored patch.
- **`set -e` deliberately omitted on Tasks 03–16** (`DECISIONS.md` D16): failure propagation relies on explicit status checks plus R10/R11 plausibility guards.
