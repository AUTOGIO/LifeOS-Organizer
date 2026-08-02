#!/bin/zsh
# LifeOS Organizer — Task 15
# Read-only classification proposal (DRY RUN) for the Documents target.
# See scripts/10_downloads_classification.zsh / scripts/lib/classification_engine.zsh
# for the full pipeline description. Same guarantees: reads only
# inventory/Documents/metadata.csv, never rescans the filesystem, performs no
# file mutation at any confidence tier. Staleness thresholds: 180/365/730
# days (DECISIONS.md D10). Largest target (128k+ files) — logic verified at
# this scale from a /tmp scratch location before handoff (DECISIONS.md D11).

set -uo pipefail

PROJECT_DIR='/Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer'
source "$PROJECT_DIR/scripts/lib/classification_engine.zsh"

run_classification_task 15 Documents
exit $?
