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

In scope for the current project phase:

- Metadata-only inventory of the eight configured targets (`config/inventory_targets.yaml`): Documents, Desktop, Downloads, Pictures, Movies, Music, CloudStorage, Volumes.
- A shared, versioned report format (`templates/inventory_report_template.md`).
- Deterministic, single-instance, auditable inventory scripts.
- Documentation of architecture, decisions, risks, and operating procedure.

Out of scope for the current phase:

- Any file move, rename, copy, or delete.
- Document content inspection, OCR, hashing, or duplicate detection.
- AI classification of collected metadata.
- Automated cleanup of Downloads or Desktop (explicitly excluded — see `docs/SAFETY_RULES.md`).
- External disks and cloud-backed folders (require separate approval before inventory, and again before any later remediation).

## Non-goals

- This project does not aim to be a general-purpose backup, sync, or file-management product.
- It does not aim to run unattended or headless; every task is explicitly invoked from a terminal session on the target Mac.
- It does not aim to support platforms other than macOS on Apple Silicon.

## Success criteria for the current phase

- All eight configured targets have a completed, validated metadata inventory (CSV + JSON + summary + report), each traceable to a unique Inventory ID.
- No inventory run has modified, moved, renamed, deleted, copied, or opened a user file for content inspection.
- Every inventory artifact passes the built-in validation gate (row-count parity between CSV and JSON, consistent Inventory ID) before publication.
- A complete, current set of governance and operational documentation exists in the repository.

## Sponsor / operator

Eduardo Giovannini (`automacao.giovannini@gmail.com`) is the sole operator and approval authority for this project. No mutation, remediation, or scope expansion proceeds without his explicit approval.
