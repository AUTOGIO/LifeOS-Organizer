# Project Context

## What this is

LifeOS Organizer is a local-first, read-only-first inventory and organization framework for the primary macOS user account on Eduardo's MacBook Air. It builds a canonical metadata record of the filesystem before any AI-assisted classification or file mutation is authorized.

## Environment (verified, Task 01 baseline — 2026-08-01)

| Field | Value |
|---|---|
| Machine | MacBook Air, Model Mac16,12 |
| Chip | Apple M4 — 10 cores (4 performance, 6 efficiency) |
| Memory | 16 GB |
| OS | macOS 27.0 (Build 26A5378n) |
| Shell | /bin/zsh |
| User | eduardofgiovannini |
| Hostname | Eduardos-Air-16.localdomain |
| Project path | `/Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer` |
| Data volume | disk3s1 — 228Gi total, 171Gi used (85%), 31Gi available |

Source: `reports/01_environment_baseline.txt`. No version control is in use — the project directory is not a git repository as of this writing.

## Current phase

Infrastructure & Inventory. The reusable inventory framework (Task 02) is validated and ready. One target (Documents) has completed a metadata scan (Task 03). Seven configured targets remain unscanned: Desktop, Downloads, Pictures, Movies, Music, CloudStorage, Volumes.

## Work completed

- Task 01 — Environment Baseline — done
- Task 02 — Inventory Engine (framework readiness) — done, 0 failures / 0 warnings
- Task 02.5 — Process Diagnostics — done, identified 9 stale concurrent Task 03 process trees as the cause of artifact corruption
- Task 03 — Documents Inventory — metadata collected (128,173 files, 17,730 directories, 161,584,842,619 bytes); publish artifacts were corrupted by the concurrency issue found in Task 02.5. Fix applied 2026-08-02 (execution lock + collision-proof Inventory ID); a clean rerun is pending on the user's Mac.

## What this project intentionally does not do yet

- No document content is opened, parsed, OCR'd, hashed, or summarized.
- No file has been moved, renamed, copied, or deleted by any script.
- No AI classification has run against collected metadata.
- No remediation or reorganization proposal exists yet.

## Governing documents

See `PROJECT_CHARTER.md` for objective and principles, `docs/SAFETY_RULES.md` for the mutation-safety contract, and `RUNBOOK.md` for how to operate the scripts.
