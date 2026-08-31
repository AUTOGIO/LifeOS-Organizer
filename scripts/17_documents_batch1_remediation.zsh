#!/bin/zsh
# LifeOS Organizer — Task 17
# Documents Batch 1 remediation: dry-run by default; --apply / --rollback
# gated per REMEDIATION_DESIGN.md. Move-to-quarantine only — no deletion.

set -uo pipefail

PROJECT_DIR="${0:A:h:h}"
source "$PROJECT_DIR/scripts/lib/remediation_engine.zsh"

run_documents_batch1_remediation "$@"
exit $?
