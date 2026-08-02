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

**Evidence.** `config/inventory_targets.yaml` includes CloudStorage and Volumes as configured targets. `docs/SAFETY_RULES.md` rule 9 requires separate approval for both.

**Impact.** Low currently for CloudStorage (approved, engine change written, not yet run — see below). Zero for Volumes: operator explicitly declined to scan it ("NO NEED to work in VOLUMES," 2026-08-02), so the `-xdev`/mount-crossing design risk flagged during the CloudStorage safeguards proposal is moot unless this decision is revisited.

**Status.** CloudStorage: closed 2026-08-02. `INV-20260802-144307`, 22,833 files, 1,779 directories, 24,612 CSV/JSON records independently confirmed matching, 0 entries vanished mid-scan, no leftover lock/staging artifacts. Volumes: deferred indefinitely by explicit operator choice, not scheduled, no engine work done or planned for it.

**Mitigation.** CloudStorage — `run_inventory_task`'s `SAFE_MODE=1` path forced Spotlight off and tracked vanished entries as designed; confirmed clean on first run, no bug found (contrast with D7's first-run cleanup-trap bug). Volumes — no action needed unless the operator asks to revisit it; if so, resolve the `-xdev` mount-crossing question (per-volume scans vs. shallow listing) before any engine work.

---

## R8 — Duplicate-risk classification is a heuristic, not a proof

**Evidence.** `CLASSIFICATION_DESIGN.md` §1: the size/duplicate-risk dimension can only compare `Name` and `SizeBytes` columns already in the inventory schema. No content hash is collected today.

**Impact.** Medium if this limitation is forgotten downstream. A `(Name, SizeBytes)` match is consistent with — but does not prove — byte-identical content; two different files can coincidentally share a name and size. Conversely, true duplicates with different names would never surface under this dimension at all.

**Status.** Open by design, not a defect. Documented explicitly in the classification design so no future phase treats a "duplicate-risk candidate" label as a confirmed duplicate.

**Mitigation.** All duplicate-risk output is capped at Medium confidence at best and routed to human review — see `CLASSIFICATION_DESIGN.md` §2. A content-hash column, if ever wanted, would be a separate, separately-approved inventory-schema change (new scan pass, new engine version), not a classification-phase change. Exception: a build-cache/regeneratable-artifact label (path pattern + exact size match) can reach High — that is a structural claim about the *path*, not a duplicate-content claim about two files, so it isn't subject to this cap (`DECISIONS.md` D10).

---

## R9 — Sandbox mount's `unlink()` restriction is general, not git-specific

**Evidence.** `RISK_REGISTER.md`'s original git lock-file incident (see R3's mitigation history) was treated as a git-only quirk. Building and verifying the Task 10 classification pipeline (`DECISIONS.md` D10) reproduced the identical failure on ordinary files: an `mkdir` lock directory and a `mktemp -d` staging directory created inside the mounted repo from the sandbox could not be removed by `rm -rf` (`Operation not permitted`), leaving `classification/Downloads/.task10.46B7b6` and `logs/.task10.lock` behind.

**Impact.** Medium. Any future AI-run verification that creates lock/staging artifacts inside the synced repository — not just git operations — risks leaving stray directories that block the real script's own lock logic on the operator's Mac (the same symptom as the original git incident, different subsystem).

**Status.** Mitigated by rule change, 2026-08-02. Two stray directories from the Task 10 verification pass need manual removal (see `DECISIONS.md` D10 for the exact command) before the operator's first official run of `scripts/10_downloads_classification.zsh`.

**Mitigation.** Revised rule: the sandbox never creates lock or staging artifacts inside the synced repository, for any task. Verification of AI-authored pipeline logic runs against a scratch location outside the mounted repo (e.g. `/tmp` in the sandbox) instead of exercising the real lock/stage path.

**Addendum (same day):** a plain `git status --short` — previously treated as unconditionally safe since it's read-only — also left a stray `.git/index.lock` once during this same verification session, undeletable from the sandbox for the same reason. Revised further: read-only git commands are still preferred over write commands from the sandbox, but are not guaranteed lock-free. The operator should always check for and clear stray `.git/*.lock` files before a commit, not just after a sandbox-run write command.

---

## R10 — Validation gate checks consistency, not plausibility

**Evidence.** The D14 correction's first (broken) attempt caused a real `find` syntax error on the operator's Mac. Because the wrapper script has no `set -e`, the run continued past the failed scan and published a completely empty but internally-consistent result: `INV-20260802-201858`, 0 files, 0 directories, valid CSV/JSON with matching row counts (0 = 0) and a correctly-formatted, self-consistent Inventory ID. The embedded validation gate (`QUALITY_GATES.md`) passed it, and it overwrote the previous good Pictures inventory (13 files, 5 directories at the time).

**Impact.** Medium. The gate's checks (row-count parity, ID consistency, ID format) are necessary but not sufficient — they can't distinguish "a small target really does have 0 files" from "the scan silently failed and produced nothing." A target going from N files to 0 between consecutive runs is exactly the kind of result that should raise a flag before publishing, and today it doesn't.

**Status.** Open, documented. No fix implemented — flagged for a future quality-gate enhancement, not addressed as part of D14 (out of scope for "minimal, targeted correction").

**Mitigation today.** None automated. The practical safety net that caught this was the operator's own explicit validation checklist (this project's established discipline of checking real output after every run, `RUNBOOK.md`), not the pipeline itself. No user file was at risk either way — only the project's own regenerable inventory artifact was affected, and it self-corrected on the next successful run.

**Suggested future gate (not implemented):** compare the new run's file/directory count against the previous published run's; require explicit confirmation (or a `--force` flag) if the new count drops by some large factor (e.g. >90%) with no corresponding warning/error explaining why.
