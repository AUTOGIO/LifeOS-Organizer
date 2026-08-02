# Changelog

No version tags — this project has no releases yet, only dated task entries. Newest first.

## 2026-08-02

- **Fixed:** `scripts/03_documents_inventory.zsh` had no execution lock, allowing concurrent invocations to race on shared output paths. Added an `mkdir`-based lock (`logs/.task03.lock`) with stale-PID reclaim. See `DECISIONS.md` D5.
- **Fixed:** Inventory ID format (`INV-<date>-001`) had no per-run uniqueness; two same-day completed runs collided on an identical ID. Widened the sequence field to `HHMMSS` and updated the embedded validation regex accordingly. See `DECISIONS.md` D4.
- **Added:** Full documentation set — `PROJECT_CONTEXT.md`, `README.md`, `PROJECT_CHARTER.md`, `EXECUTIVE_REPORT.md`, `SYSTEM_ARCHITECTURE.md`, `ROADMAP.md`, `AI_COLLABORATION.md`, `DECISIONS.md`, `RUNBOOK.md`, `QUALITY_GATES.md`, `RISK_REGISTER.md`, this file.
- **Added:** Extended the same execution-lock pattern to `scripts/01_environment_baseline.zsh` and `scripts/02_inventory_engine.zsh` (`logs/.task01.lock`, `logs/.task02.lock`). See `DECISIONS.md` D6.
- **Added:** `git init` — this repository now has version control. Initial commit captures the full pre-fix and post-fix state in one snapshot (26 files); history from here forward is incremental.
- **Closed:** Task 03 concurrency incident. Operator confirmed 9 stale process trees via `ps`, terminated them with `pkill -TERM`, confirmed zero survivors, then ran one clean pass. Result: Inventory ID `INV-20260802-013608`, 128,305 files, 17,786 directories, 161,275,096,221 bytes, 275-second runtime, 1 warning, 0 errors. Independently validated: `metadata.csv` and `metadata.json` both hold 146,091 records, all under the same Inventory ID.
- **Added:** `scripts/04_desktop_inventory.zsh` — Task 04, Desktop target. Cloned from the validated `03_documents_inventory.zsh` rather than parameterized (`DECISIONS.md` D7).
- **Task 04 — Desktop Inventory. Done and validated on first run**, no incident. Inventory ID `INV-20260802-132721`: 99 files, 21 directories, 99,051,425 bytes, 1-second runtime, 1 warning, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 120 matching records under one consistent Inventory ID.

## 2026-08-01

- **Task 02.5 — Process Diagnostics.** Read-only process snapshot found 9 concurrent, non-completing Task 03 process trees, all using a legacy pre-repair execution path. Root-caused the ongoing artifact corruption to repeated manual invocation without an execution lock. Recommended: terminate stale processes, then run exactly one validated pass. Report: `reports/02_5_process_diagnostics.txt`.
- **Task 03 — Documents Inventory.** Completed a metadata scan of `/Users/eduardofgiovannini/Documents`: 128,173 files, 17,730 directories, 161,584,842,619 bytes, 586-second runtime, 1 warning, 0 errors, Inventory ID `INV-20260801-001`. Artifacts were subsequently overwritten by the stale processes found in Task 02.5 (see 2026-08-02 entry above).
- **Task 02 — Inventory Engine.** Built the reusable inventory framework: target configuration (`config/inventory_targets.yaml`), shared report template, per-target staging directories, and a readiness-check script. Readiness result: 0 failures, 0 warnings. Report: `reports/02_inventory_engine.txt`.
- **Task 01 — Environment Baseline.** Recorded machine, OS, disk, and required-path baseline: MacBook Air (Apple M4), macOS 27.0 (Build 26A5378n), 16 GB RAM, data volume at 85% capacity. Report: `reports/01_environment_baseline.txt`.
