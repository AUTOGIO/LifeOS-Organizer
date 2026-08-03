# Project Charter

## Objective

Build a production-grade, local-first, AI-ready operating layer for macOS that:

- Inventories the filesystem safely.
- Creates a canonical metadata repository.
- Supports AI-assisted classification.
- Produces auditable recommendations.
- Requires explicit human approval before any file mutation.
- Guarantees rollback capability for future organization tasks.

## Governance principles

1. Inventory before organization.
2. Metadata before AI.
3. Read-only before remediation.
4. Human approval before mutation.
5. Local-first.
6. Apple-native.
7. Deterministic execution.
8. Complete audit trail.

These principles are non-negotiable ordering constraints, not preferences. A task that violates ordering (for example, proposing mutation before an audited inventory exists for that target) is out of scope regardless of convenience.

## Scope

In scope for the inventory and classification phases (completed per `DECISIONS.md` D7–D15):

- Metadata-only inventory of the seven operator-approved targets (`config/inventory_targets.yaml`): Documents, Desktop, Downloads, Pictures, Movies, Music, CloudStorage.
- Metadata-only classification of the six local targets (Documents, Desktop, Downloads, Pictures, Movies, Music) — CloudStorage and Volumes excluded from classification (`DECISIONS.md` D9–D11).
- Documents classification triage into prioritized review batches (`DECISIONS.md` D12).
- A shared, versioned report format (`templates/inventory_report_template.md`).
- Deterministic, single-instance, auditable inventory and classification scripts.
- Documentation of architecture, decisions, risks, and operating procedure.

In scope for the remediation phase (design and pilot per `REMEDIATION_DESIGN.md`, once approved):

- Dry-run-by-default move-to-quarantine proposals with a rollback ledger.
- Explicit `--apply` gated by a `DECISIONS.md` approval entry.
- No deletion capability at any point (`docs/SAFETY_RULES.md` rule 5 — permanent).

Out of scope (permanent or deferred by operator decision):

- Volumes inventory — permanently out of scope by explicit operator decision 2026-08-02 (`DECISIONS.md` D8); not pending.
- Document content inspection, OCR, hashing, or confirmed duplicate detection (name+size is a heuristic only — `RISK_REGISTER.md` R8).
- Automated cleanup of Downloads or Desktop (explicitly excluded — see `docs/SAFETY_RULES.md`).
- Any file deletion during this project.
- External disks beyond the approved CloudStorage inventory (require separate approval before any later remediation).

## Non-goals

- This project does not aim to be a general-purpose backup, sync, or file-management product.
- It does not aim to run unattended or headless; every task is explicitly invoked from a terminal session on the target Mac.
- It does not aim to support platforms other than macOS on Apple Silicon.

## Success criteria

**Inventory + classification (met):**

- All seven operator-approved targets have a completed, validated metadata inventory (CSV + JSON + summary + report), each traceable to a unique Inventory ID. (Volumes permanently declined — not a defect.)
- All six in-scope local targets have a validated classification proposal traceable to its SourceInventoryID.
- No inventory or classification run has modified, moved, renamed, deleted, copied, or opened a user file for content inspection.
- Every published artifact passes the built-in validation gate (row-count parity, consistent IDs; inventory also refuses zero-directory results — `DECISIONS.md` D15) before publication.
- A complete, current set of governance and operational documentation exists in the repository.

**Remediation (in progress):**

- An approved remediation design exists with dry-run default, `--apply` gate, and rollback ledger.
- A limited pilot batch can be applied and deterministically rolled back with zero unintended file changes.

## Sponsor / operator

Eduardo Giovannini (`automacao.giovannini@gmail.com`) is the sole operator and approval authority for this project. No mutation, remediation, or scope expansion proceeds without his explicit approval.
