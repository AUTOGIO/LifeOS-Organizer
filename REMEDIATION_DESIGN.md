# Remediation Design (Move-to-Quarantine Phase)

**Status:** DESIGN APPROVED for implementation under the Charter closeout plan (operator-directed execution 2026-08-02). Dry-run is the default. First real `--apply` requires a `DECISIONS.md` entry and `--limit` for the pilot.

This phase implements Charter principles 4–6: human approval before mutation, auditable recommendations, and guaranteed rollback. It expands the placeholder in `CLASSIFICATION_DESIGN.md` §5.

## 1. Scope

| Topic | Decision |
|---|---|
| Allowed actions | `move` only (to quarantine). No rename-in-place without a ledger row. **No delete** (`docs/SAFETY_RULES.md` rule 5 — permanent). |
| Pilot batch | Documents Batch 1 only (`review/Documents/triage_assignments.csv` where `BatchNumber=1`) — regeneratable build/cache artifacts. |
| Quarantine root | `/Users/eduardofgiovannini/Documents/_LifeOS_Quarantine/<RemediationID>/` |
| Input | Published triage + classification + inventory IDs only. No filesystem rescan for discovery. Existence is checked before each move. |
| Out of scope | Batches 2–5; CloudStorage; Volumes; Downloads/Desktop auto-cleanup; any `rm`/`unlink` of user files; fuzzy near-duplicates. |

## 2. Modes

| Mode | Flag | Behavior |
|---|---|---|
| Dry-run (default) | none | Build proposal + ledger under `remediation/Documents/`. **Never** calls `mv` on user paths. |
| Apply | `--apply` | Requires `LIFEOS_REMEDIATION_APPROVED=<ApprovalRef>` env (must match a `DECISIONS.md` id, e.g. `D19`). Moves files per ledger. |
| Limit | `--limit N` | Cap number of moves. Required for `--apply`. |
| Order | `--order smallest\|largest` | Selection order after filters. Default `smallest` (safe pilots). Use `largest` for CompilationCache disk-impact runs. |
| Match | `--match SUBSTR` | Keep only Batch 1 paths containing SUBSTR (e.g. `CompilationCache.noindex`). |
| Rollback | `--rollback <RemediationID>` | Reverse-move every ledger row with `Status=applied` for that ID. Reads `remediation/Documents/ledgers/<ID>.csv` when present so later runs do not erase history. |

Idempotency: paths already `Status=applied` in any archived/current ledger, and paths missing on disk, are skipped before `--limit` is applied.

## 3. Ledger schema

Written **before** any apply. Published at `remediation/Documents/ledger.csv` / `ledger.json`.

```
RemediationID, SourceTriageID, SourceClassificationID, SourceInventoryID,
OriginalFullPath, ProposedNewPath, Action, Timestamp, ApprovalRef, Status, SizeBytes
```

- `Action`: always `move` in this phase.
- `Status`: `proposed` (dry-run) → `applied` → `rolled_back` (or `failed` with no partial silent success).
- `ProposedNewPath`: `QuarantineRoot + relative path under Documents` (preserves tree shape under quarantine).

## 4. Safety constraints

1. Dry-run is default; `--apply` without `LIFEOS_REMEDIATION_APPROVED` aborts.
2. No deletion code path exists in the remediation engine.
3. Quarantine destination must be under the configured quarantine root; refuse paths that escape it.
4. Refuse to overwrite an existing destination path.
5. Refuse to move if source missing (record `failed`, continue or abort per `--fail-fast`; default abort).
6. Execution lock (`logs/.task17.lock`), stage → validate → atomic publish for proposal/ledger artifacts (mirrors inventory engine).
7. Apply loop updates ledger status after each successful `mv`; crash mid-batch leaves a partial ledger that rollback can use for completed rows only.

## 5. Validation gate (before publish of proposal/ledger)

1. RemediationID matches `REM-YYYYMMDD-HHMMSS`.
2. CSV/JSON row-count parity.
3. Every row's SourceTriageID / ClassificationID / InventoryID match the published upstream artifacts.
4. Every OriginalFullPath appears in Batch 1 of the triage assignments.
5. Every ProposedNewPath is under the quarantine root for this RemediationID.
6. Plausibility: refuse 0 proposed rows when Batch 1 has usable assignments (unless `ALLOW_EMPTY_RESULT=1`).

## 6. Pilot procedure (Phase 5c)

1. Dry-run full Batch 1 → operator reviews sample of proposed quarantine paths.
2. Record approval in `DECISIONS.md` (e.g. D19).
3. `--apply --limit 5` with `LIFEOS_REMEDIATION_APPROVED=D19` on the five **smallest** Batch 1 files.
4. Verify files in quarantine; originals gone.
5. `--rollback <RemediationID>` → originals restored; quarantine entries removed.
6. Only then consider larger limits.

## 7. Explicit non-goals

- No automatic regeneration of build caches after quarantine.
- No content hashing before move.
- No UI — terminal invocation only (`RUNBOOK.md`).
- No history rewrite of git for prior generated blobs.
