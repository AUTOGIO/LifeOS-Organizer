# Changelog

No version tags — this project has no releases yet, only dated task entries. Newest first.

## 2026-08-02 (Pictures package-recording fix — implemented and verified, NOT committed)

- **Decided:** operator approved a minimal correction so package directories are recorded once (`IsPackage=true`) instead of being silently excluded entirely — the deeper gap D13's proposal exposed. See `DECISIONS.md` D14.
- **Fixed:** `scripts/lib/inventory_engine.zsh`'s package-matching `find` branch now uses its own `-exec ... {} \; -prune` (prune listed before exec, so pruning is guaranteed even if the stat action fails — verified with a controlled `/bin/false` test before shipping).
- **Bug found and fixed before final handoff:** the first attempt left an unmatched closing parenthesis, causing a real `find` syntax error on the operator's Mac. Because the wrapper has no `set -e`, the run continued and published an empty-but-consistent Pictures inventory (`INV-20260802-201858`, 0 files), overwriting the previous good one. No user file affected — only the project's own regenerable artifact. See `RISK_REGISTER.md` R10 (new): the validation gate checks consistency, not plausibility, and doesn't catch a suspicious drop to zero.
- **Verified (operator's real runs):** Task 06 — `INV-20260802-202531`, 13 files, 6 directories, exactly one `IsPackage=true` row for `Photos Library.photoslibrary`, zero rows beneath it, 19 CSV/JSON rows matching. Task 14 — `CLS-20260802-202619`, 28 records from the 13 real files, `SourceInventoryID` confirmed matching the corrected inventory.
- **Updated:** `SYSTEM_ARCHITECTURE.md` (corrected scan-step description), `QUALITY_GATES.md` (documents the fix and the new R10 gap).
- **Not committed.** Awaiting operator's final review of the validation summary.

## 2026-08-02 (Documents triage + Pictures package-fix proposal — NOT committed)

- **Added:** `scripts/16_documents_triage.zsh` and `review/Documents/` — reduces the 128,380-file Documents classification into 5 prioritized batches (build/cache artifacts, largest files, exact duplicate-risk, weak duplicate/stale, low-confidence). Reads only the already-published `classification/Documents/` and `inventory/Documents/` artifacts; no rescan, no mutation. See `DECISIONS.md` D12 for the full tier-mapping rationale and results.
- **Found:** this project's own `logs/03_documents_inventory_debug.log` (5.4 GB, a leftover from the original Task 03 incident) is currently the single largest file under Documents.
- **Added:** `PICTURES_PACKAGE_FIX_PROPOSAL.md` — assessment (not implementation) of a fix for `.photoslibrary` package pruning. Quantified: 99.8% of Pictures' inventory is one package's internals. Three one-line additive edits proposed, plus a required Task 06 + Task 14 re-run chain. See `DECISIONS.md` D13. **Not implemented, not approved.**
- **Not committed.** Both items are staged for operator review per explicit instruction.

## 2026-08-02 (classification — remaining 5 local targets)

- **Decided:** operator approved extending classification to Movies, Desktop, Music, Pictures, and Documents after reviewing the Downloads dry run. See `DECISIONS.md` D11.
- **Added:** `scripts/11_movies_classification.zsh` through `scripts/15_documents_classification.zsh` plus their `classification/<Target>/` output directories. No engine changes — `run_classification_task` was already parameterized for all 6 local targets in D10.
- **Verified (scratch, per corrected R9 method):** all 5 validated cleanly against real inventory data, 0 warnings, 0 errors — Movies 98 records, Desktop 312, Music 473, Pictures 17,323, Documents 463,774 (128k-file target, 6s generation time).
- **Observed, not acted on:** Documents' review queue (132,279 records) is large — mostly duplicate-risk noise at scale, flagged for a follow-up triage-strategy discussion. Pictures' Photos Library package wasn't pruned by the inventory engine's `.photo\ library` pattern (misses the modern `.photoslibrary` extension) — an inventory-phase (D2) gap, not a classification bug, not fixed here.
- **All 5 confirmed on first run, no incidents.** Movies `CLS-20260802-160123` (98), Desktop `CLS-20260802-160130` (312), Music `CLS-20260802-160137` (473), Pictures `CLS-20260802-160143` (17,323), Documents `CLS-20260802-160151` (463,774) — every count matched the sandbox-verified table exactly. Independently confirmed CSV/JSON row-count parity and single consistent ClassificationID for all 5; no leftover lock/staging artifacts.

## 2026-08-02 (classification pipeline — Downloads dry run)

- **Decided:** operator finalized the three open policy questions from `CLASSIFICATION_DESIGN.md` §7 — target-specific staleness thresholds (Downloads 30/90/180d; Documents/Desktop 180/365/730d; Pictures/Movies/Music none), duplicate-risk stays within-target only, package directories excluded by default. See `DECISIONS.md` D10.
- **Added:** `scripts/lib/classification_engine.zsh` and `scripts/10_downloads_classification.zsh` — read-only classification pipeline for Downloads, mirrors the inventory engine's lock/stage/generate/validate/publish pattern. Reads only `inventory/Downloads/metadata.csv`; never rescans the filesystem; performs no file mutation at any confidence tier.
- **Fixed (before reaching the operator):** an argv-slicing off-by-one in the embedded Python generator (`sys.argv[1:11]` should have been `[1:12]`) was caught during sandbox verification, before any execution was shown or committed.
- **Found:** the sandbox mount's `unlink()` restriction (previously thought git-specific) also blocks removal of ordinary lock/staging directories created inside the synced repo. Verification method changed to run against a `/tmp` scratch location instead. See `RISK_REGISTER.md` R9, `AI_COLLABORATION.md` rule 8. Two stray artifacts from this discovery (`classification/Downloads/.task10.*`, `logs/.task10.lock`) need manual removal before the first official run.
- **Verified (logic only, via `/tmp` scratch run against real `inventory/Downloads/metadata.csv`):** 161 classification records from Downloads' 53 files — 127 High / 0 Medium / 34 Low confidence, 34 in the review queue, 0 warnings, 0 errors. Validation gate passed. Not yet run as the operator's own official, committed artifact.

## 2026-08-02 (classification design)

- **Decided:** operator directed the metadata-before-AI classification phase to begin, scoped to local targets only (CloudStorage and Volumes excluded), design-and-proposal only, no file mutation, four classification dimensions (project/workspace grouping, file type/extension, age/staleness, size/duplicate-risk), three-tier confidence policy (high auto-proposable, medium/low require human review, no tier triggers movement). See `DECISIONS.md` D9.
- **Added:** `CLASSIFICATION_DESIGN.md` — category model, confidence thresholds, a metadata-only pipeline design (reads only already-published `inventory/<Target>/metadata.csv|json`, never re-scans the filesystem), example proposed outputs grounded in real inventory numbers (not fabricated), a safety/rollback plan for a possible future mutation phase, and a 5-step implementation plan.
- **Added:** `RISK_REGISTER.md` R8 — duplicate-risk classification is a `(Name, SizeBytes)` heuristic, not a hash-verified proof; documented explicitly so it's never mistaken for confirmed-duplicate detection downstream.
- **No classification code was written or run.** No user file or inventory artifact was modified — only existing, already-published `metadata.csv` files were read to produce the design's grounded examples.

## 2026-08-02 (continued)

- **Decided:** operator approved scoped engine changes and a full metadata-only inventory of CloudStorage; explicitly declined Volumes ("NO NEED to work in VOLUMES"). See `DECISIONS.md` D8.
- **Added:** `SAFE_MODE` parameter to `run_inventory_task` (`scripts/lib/inventory_engine.zsh`), default off — zero behavior change to scripts 03-08. When enabled: forces Spotlight enrichment off regardless of `COLLECT_SPOTLIGHT`, and adds a pre-scan entry count so anything that vanishes mid-scan is reported instead of silently dropped.
- **Added:** `scripts/09_cloudstorage_inventory.zsh` — Task 09, CloudStorage target, safe mode enabled.
- **Task 09 — CloudStorage Inventory. Done and validated on first run**, no incident. Inventory ID `INV-20260802-144307`: 22,833 files, 1,779 directories, 86,341,869,509 bytes, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 24,612 matching records under one consistent Inventory ID. Availability section: 0 entries vanished mid-scan. No leftover lock or staging artifacts.
- **Updated:** `RISK_REGISTER.md` R7 closed for CloudStorage; Volumes remains deferred by operator choice.

## 2026-08-02

- **Fixed:** `scripts/03_documents_inventory.zsh` had no execution lock, allowing concurrent invocations to race on shared output paths. Added an `mkdir`-based lock (`logs/.task03.lock`) with stale-PID reclaim. See `DECISIONS.md` D5.
- **Fixed:** Inventory ID format (`INV-<date>-001`) had no per-run uniqueness; two same-day completed runs collided on an identical ID. Widened the sequence field to `HHMMSS` and updated the embedded validation regex accordingly. See `DECISIONS.md` D4.
- **Added:** Full documentation set — `PROJECT_CONTEXT.md`, `README.md`, `PROJECT_CHARTER.md`, `EXECUTIVE_REPORT.md`, `SYSTEM_ARCHITECTURE.md`, `ROADMAP.md`, `AI_COLLABORATION.md`, `DECISIONS.md`, `RUNBOOK.md`, `QUALITY_GATES.md`, `RISK_REGISTER.md`, this file.
- **Added:** Extended the same execution-lock pattern to `scripts/01_environment_baseline.zsh` and `scripts/02_inventory_engine.zsh` (`logs/.task01.lock`, `logs/.task02.lock`). See `DECISIONS.md` D6.
- **Added:** `git init` — this repository now has version control. Initial commit captures the full pre-fix and post-fix state in one snapshot (26 files); history from here forward is incremental.
- **Closed:** Task 03 concurrency incident. Operator confirmed 9 stale process trees via `ps`, terminated them with `pkill -TERM`, confirmed zero survivors, then ran one clean pass. Result: Inventory ID `INV-20260802-013608`, 128,305 files, 17,786 directories, 161,275,096,221 bytes, 275-second runtime, 1 warning, 0 errors. Independently validated: `metadata.csv` and `metadata.json` both hold 146,091 records, all under the same Inventory ID.
- **Added:** `scripts/04_desktop_inventory.zsh` — Task 04, Desktop target. Cloned from the validated `03_documents_inventory.zsh` rather than parameterized (`DECISIONS.md` D7).
- **Task 04 — Desktop Inventory. Done and validated on first run**, no incident. Inventory ID `INV-20260802-132721`: 99 files, 21 directories, 99,051,425 bytes, 1-second runtime, 1 warning, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 120 matching records under one consistent Inventory ID.
- **Added:** `scripts/05_downloads_inventory.zsh` — Task 05, Downloads target. Cloned from `04_desktop_inventory.zsh`.
- **Task 05 — Downloads Inventory. Done and validated on first run**, no incident. Inventory ID `INV-20260802-133234`: 53 files, 6 directories, 8,546,888 bytes, 0-second runtime, 1 warning, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 59 matching records under one consistent Inventory ID.
- **Decision point reached:** three targets (Documents, Desktop, Downloads) are now built and validated from the identical cloned pattern — the "rule of three" trigger named in `DECISIONS.md` D7. See D7 update: decision is to keep cloning, not refactor yet.
- **Added:** `scripts/06_pictures_inventory.zsh` — Task 06, Pictures target. Cloned from `05_downloads_inventory.zsh`.
- **Task 06 — Pictures Inventory. Done and validated on first run**, no incident. Inventory ID `INV-20260802-133626`: 8,694 files, 338 directories, 530,543,823 bytes, 9-second runtime, 1 warning, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 9,032 matching records under one consistent Inventory ID.
- **Added:** `scripts/07_movies_inventory.zsh` — Task 07, Movies target. Cloned from `06_pictures_inventory.zsh`.
- **Task 07 — Movies Inventory. Done and validated on first run**, no incident. Inventory ID `INV-20260802-134048`: 49 files, 5 directories, 11,827 bytes, 0-second runtime, 1 warning, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 54 matching records under one consistent Inventory ID.
- **Added:** `scripts/08_music_inventory.zsh` — Task 08, Music target. Cloned from `07_movies_inventory.zsh`.
- **Task 08 — Music Inventory. Done and validated on first run**, no incident. Inventory ID `INV-20260802-134325`: 161 files, 23 directories, 132,758,072 bytes, 0-second runtime, 1 warning, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 184 matching records under one consistent Inventory ID.
- **Milestone: all 5 local targets complete.** Documents, Desktop, Downloads, Pictures, Movies, Music (6 scripts, 5 non-Documents clones, all mechanical diffs, zero logic divergence). 137,361 files and 18,179 directories inventoried in total across all local targets, 0 errors anywhere. This is the D7 refactor trigger point — see next entry.
- **Refactored (D7):** Added `scripts/lib/inventory_engine.zsh` — a shared library holding every function and the full pipeline (`run_inventory_task`) previously duplicated across `scripts/03-08`. Rewrote all 6 scripts as ~15-line thin wrappers. Verified structurally (`bash -n` on the library and all wrappers, parameterized target-lookup tested against the real config for all 8 targets) but **not yet executed under zsh** — pending operator verification per `RUNBOOK.md`.
- **Bug found and fixed on first real run of the refactor:** `RUN_DIR`/`LOCK_DIR` were `local` to `run_inventory_task`, so the `EXIT` trap (which fires after the function returns) couldn't see them — cleanup failed with `parameter not set`, leaving a stale lock dir and two empty staging-dir husks. Inventory data itself was unaffected (Documents rescan: `INV-20260802-140520`, 128,380 files, 17,831 directories, 146,211 CSV/JSON records confirmed matching). Fixed by declaring both `typeset -g`. See `DECISIONS.md` D7.
- **Fix re-verified:** operator cleared the leftover artifacts and reran Task 03 — clean, no `cleanup:` error, lock and staging husks confirmed gone afterward. `INV-20260802-141128`: 128,380 files, 17,830 directories, 161,007,433,747 bytes, 146,210 CSV/JSON records confirmed matching. D7 refactor verified for Documents; Desktop/Downloads/Pictures/Movies/Music still to retest.
- **D7 refactor fully verified.** All remaining targets reran clean under the fixed library, no leftover artifacts anywhere: Desktop `INV-20260802-141614` (99/21/120), Downloads `INV-20260802-141749` (53/6/59), Pictures `INV-20260802-141844` (8,656/326/8,982), Movies `INV-20260802-141928` (49/5/54), Music `INV-20260802-142008` (161/23/184). Six scripts, one shared library, zero unresolved issues.

## 2026-08-01

- **Task 02.5 — Process Diagnostics.** Read-only process snapshot found 9 concurrent, non-completing Task 03 process trees, all using a legacy pre-repair execution path. Root-caused the ongoing artifact corruption to repeated manual invocation without an execution lock. Recommended: terminate stale processes, then run exactly one validated pass. Report: `reports/02_5_process_diagnostics.txt`.
- **Task 03 — Documents Inventory.** Completed a metadata scan of `/Users/eduardofgiovannini/Documents`: 128,173 files, 17,730 directories, 161,584,842,619 bytes, 586-second runtime, 1 warning, 0 errors, Inventory ID `INV-20260801-001`. Artifacts were subsequently overwritten by the stale processes found in Task 02.5 (see 2026-08-02 entry above).
- **Task 02 — Inventory Engine.** Built the reusable inventory framework: target configuration (`config/inventory_targets.yaml`), shared report template, per-target staging directories, and a readiness-check script. Readiness result: 0 failures, 0 warnings. Report: `reports/02_inventory_engine.txt`.
- **Task 01 — Environment Baseline.** Recorded machine, OS, disk, and required-path baseline: MacBook Air (Apple M4), macOS 27.0 (Build 26A5378n), 16 GB RAM, data volume at 85% capacity. Report: `reports/01_environment_baseline.txt`.
