#!/bin/zsh
# LifeOS Organizer — Task 13
# Read-only classification proposal (DRY RUN) for the Music target.
# See scripts/10_downloads_classification.zsh / scripts/lib/classification_engine.zsh
# for the full pipeline description. Same guarantees: reads only
# inventory/Music/metadata.csv, never rescans the filesystem, performs no
# file mutation at any confidence tier. Music has no staleness dimension
# by default (DECISIONS.md D10).

set -uo pipefail

PROJECT_DIR='/Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer'
source "$PROJECT_DIR/scripts/lib/classification_engine.zsh"

run_classification_task 13 Music
exit $?
