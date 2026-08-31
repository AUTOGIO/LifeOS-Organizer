#!/bin/zsh
# LifeOS Organizer — Task 10
# Read-only classification proposal (DRY RUN) for the Downloads target.
# Approved per operator instruction 2026-08-02 (DECISIONS.md D10),
# implementing CLASSIFICATION_DESIGN.md, scoped to Downloads only.
#
# This script never rescans the filesystem — it reads only the already
# published, already validated inventory/Downloads/metadata.csv. It never
# opens a write handle to anything outside classification/Downloads/. It
# performs no move, rename, tag, copy, or delete of any file, at any
# confidence tier. See scripts/lib/classification_engine.zsh for the full
# pipeline (generate → validate → atomic publish, same pattern proven by
# the inventory engine).

set -uo pipefail

PROJECT_DIR="${0:A:h:h}"
source "$PROJECT_DIR/scripts/lib/classification_engine.zsh"

run_classification_task 10 Downloads
exit $?
