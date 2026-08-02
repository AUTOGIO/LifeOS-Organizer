# Risk Register

Format: risk, evidence, impact, status, mitigation.

---

## R1 — Concurrent script execution corrupts shared artifacts

**Evidence.** `reports/02_5_process_diagnostics.txt`: 9 stale `03_documents_inventory.zsh` process trees found running simultaneously against the same target, none completing, all contending for the same output paths. `inventory/Documents/metadata.json` was observed truncated mid-record; `metadata.csv` held roughly double the expected row count.

**Impact.** High while unmitigated — a validated, successful scan (Aug 1, 128,173 files, 0 errors) was overwritten into an unusable state by later stale processes.

**Status.** Closed 2026-08-02. Execution lock added (`DECISIONS.md`, D5) and confirmed working under real conditions: operator identified all 9 stale process trees, terminated them (`pkill -TERM`), confirmed zero survivors, then ran one clean pass. Result: Inventory ID `INV-20260802-013608`, 128,305 files / 17,786 directories, 0 errors, `metadata.csv`/`metadata.json` independently validated at 146,091 matching records each under a single consistent Inventory ID.

**Mitigation.** Execution lock in `03_documents_inventory.zsh`. Extended to `01_environment_baseline.zsh` and `02_inventory_engine.zsh` the same day (`DECISIONS.md` D6) — all three task scripts now refuse concurrent invocation.

---

## R2 — Inventory ID collisions break audit trail

**Evidence.** Debug log (`logs/03_documents_inventory_debug.log`) shows two distinct completed runs, different timestamps and file counts (127,441/18,459 vs. 128,173/17,730), both stamped `INV-20260801-001`.

**Impact.** Medium. Violates the charter's "complete audit trail" governance principle — an ID alone can no longer prove which run produced a given artifact.

**Status.** Mitigated 2026-08-02 (`DECISIONS.md`, D4).

**Mitigation.** ID widened to include `HHMMSS`; combined with R1's lock, same-day collisions are now structurally prevented, not just statistically unlikely.

---

## R3 — No version control

**Evidence.** The project directory was not a git repository as of 2026-08-01 (`git log` / `git status` failed with "not a git repository").

**Impact.** Medium. Prior to mitigation, every "current state" claim in this documentation set depended entirely on live files on disk with no history and no way to recover a previous version of a script or config file if overwritten incorrectly.

**Status.** Mitigated 2026-08-02 — `git init` run, initial commit captures the full documented state (26 files). Generated inventory data (`inventory/*/metadata.csv`, `inventory/*/metadata.json`) and logs are excluded via `.gitignore` — those are regenerated, not source.

**Mitigation.** Adopt commits as the record of change going forward. Recommended discipline: commit after every task run and after every script change, with a message that matches the corresponding `CHANGELOG.md` entry.

---

## R4 — Documents target contains large, low-value build artifacts

**Evidence.** `inventory/Documents/summary.md` "Largest Files": four separate 25.7 GB compilation-cache files (`LitoralPriceTracker`, `System_Org 2`, `MacHealthOS`, `CodexCheatSheet`, each under `.build/out/CompilationCache.noindex/...`), plus matching multi-GB index/action files in the same directories.

**Impact.** Low to inventory correctness (these are recorded accurately), but relevant to disk capacity (R5) and to any future "what should be reorganized" recommendation — these are almost certainly safe-to-regenerate build caches, not user data, and should be flagged rather than treated as candidates for the same review process as personal documents.

**Status.** Open — informational only. No action taken; this project does not delete or move files.

**Mitigation.** None required at this phase. Flag for the eventual classification/remediation phase (`ROADMAP.md`, "Later").

---

## R5 — Data volume close to capacity

**Evidence.** `reports/01_environment_baseline.txt`: disk3s1 (Data volume) at 85% used, 171Gi used of 228Gi, 31Gi available.

**Impact.** Medium. Large future inventory artifacts (Documents alone produced a 460 MB JSON file before corruption) and any subsequent AI-classification working data add to a volume already 85% full.

**Status.** Open — informational only.

**Mitigation.** None required for read-only inventory work. Worth monitoring before any phase that writes larger intermediate artifacts (e.g. content hashing or AI classification caches).

---

## R6 — Unreviewed AI-authored script change

**Evidence.** The 2026-08-02 locking/ID fix could not be syntax-checked with `zsh -n` in the environment it was written in (no zsh available, no package-install permission).

**Impact.** Low-medium. A silent zsh syntax error would only surface the next time the script is actually run on the Mac, not before.

**Status.** Open until the operator runs the script and confirms it executes cleanly.

**Mitigation.** Manual read-through of both edited regions was performed. Recommended: run `zsh -n scripts/03_documents_inventory.zsh` on the Mac before or as part of the next execution.

---

## R7 — External/cloud targets untested

**Evidence.** `config/inventory_targets.yaml` includes CloudStorage and Volumes as configured targets; neither has been scanned. `docs/SAFETY_RULES.md` rule 9 requires separate approval for both.

**Impact.** Low currently (nothing has run against them). Becomes relevant the moment either target's first scan is approved — cloud-backed paths can trigger on-demand downloads just by being `stat`'d, and external volumes may not stay mounted for a multi-hour scan.

**Status.** Open, deferred by design.

**Mitigation.** Do not schedule either target's first scan without explicit operator approval and a plan for handling an unmount or on-demand-download mid-scan.
