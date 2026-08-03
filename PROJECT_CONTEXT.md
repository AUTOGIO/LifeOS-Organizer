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

Inventory and classification are closed for all operator-approved scope. Volumes is permanently out of scope (`DECISIONS.md` D8). Pictures package recording (D14) and the R10 zero-result guard (D15) are committed. Documents triage (D12) is published under `review/Documents/`.

Active work: pipeline hardening (plausibility guards on classification/triage), repo hygiene (`.gitignore` for generated classification/review data), then remediation design and a dry-run → limited-apply → rollback pilot on Documents Batch 1. See `ROADMAP.md`.

## Work completed

- Task 01 — Environment Baseline — done
- Task 02 — Inventory Engine (framework readiness) — done, 0 failures / 0 warnings
- Task 02.5 — Process Diagnostics — done, identified 9 stale concurrent Task 03 process trees as the cause of artifact corruption
- Task 03 — Documents Inventory — done and validated under the D7 library refactor. Inventory ID `INV-20260802-141128`: 128,380 files, 17,830 directories, 161,007,433,747 bytes, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 146,210 matching records under one consistent Inventory ID.
- Task 04 — Desktop Inventory — done and validated under the D7 library refactor. Inventory ID `INV-20260802-141614`: 99 files, 21 directories, 99,051,425 bytes, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 120 matching records under one consistent Inventory ID.
- Task 05 — Downloads Inventory — done and validated under the D7 library refactor. Inventory ID `INV-20260802-141749`: 53 files, 6 directories, 8,546,888 bytes, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 59 matching records under one consistent Inventory ID.
- Task 06 — Pictures Inventory — done and validated under the D7 library refactor. Inventory ID `INV-20260802-141844`: 8,656 files, 326 directories, 523,227,442 bytes, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 8,982 matching records under one consistent Inventory ID.
- Task 07 — Movies Inventory — done and validated under the D7 library refactor. Inventory ID `INV-20260802-141928`: 49 files, 5 directories, 11,827 bytes, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 54 matching records under one consistent Inventory ID.
- Task 08 — Music Inventory — done and validated under the D7 library refactor. Inventory ID `INV-20260802-142008`: 161 files, 23 directories, 132,758,072 bytes, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 184 matching records under one consistent Inventory ID.
- Task 09 — CloudStorage Inventory — done and validated under safe mode (`DECISIONS.md` D8). Inventory ID `INV-20260802-144307`: 22,833 files, 1,779 directories, 86,341,869,509 bytes, 0 errors. `metadata.csv`/`metadata.json` independently confirmed at 24,612 matching records under one consistent Inventory ID. 0 entries vanished mid-scan.

## What this project intentionally does not do yet

- No document content is opened, parsed, OCR'd, hashed, or summarized.
- No user file has been moved, renamed, copied, or deleted by any script (remediation dry-run/apply is the next gated phase).
- No deletion capability will be added during this project (`docs/SAFETY_RULES.md` rule 5).

## Governing documents

See `PROJECT_CHARTER.md` for objective and principles, `docs/SAFETY_RULES.md` for the mutation-safety contract, and `RUNBOOK.md` for how to operate the scripts.
