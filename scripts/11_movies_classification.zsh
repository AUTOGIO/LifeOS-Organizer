#!/bin/zsh
# LifeOS Organizer — Task 11
# Read-only classification proposal (DRY RUN) for the Movies target.
# See scripts/10_downloads_classification.zsh / scripts/lib/classification_engine.zsh
# for the full pipeline description. Same guarantees: reads only
# inventory/Movies/metadata.csv, never rescans the filesystem, performs no
# file mutation at any confidence tier. Movies has no staleness dimension
# by default (DECISIONS.md D10).

set -uo pipefail

PROJECT_DIR="${0:A:h:h}"
source "$PROJECT_DIR/scripts/lib/classification_engine.zsh"

run_classification_task 11 Movies
exit $?
