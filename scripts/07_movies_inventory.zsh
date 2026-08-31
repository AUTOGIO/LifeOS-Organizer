#!/bin/zsh
# LifeOS Organizer — Task 07
# Metadata-only inventory for the configured Movies target.
# This script never opens user documents or follows symlinks.
# Thin wrapper over the shared engine (scripts/lib/inventory_engine.zsh) —
# folded here per DECISIONS.md D7 once all 5 local targets were validated
# with zero logic divergence across their clones. All scan/lock/staging/
# validation logic lives in the library; this file only names the task
# number and target.

set -uo pipefail

PROJECT_DIR="${0:A:h:h}"
source "$PROJECT_DIR/scripts/lib/inventory_engine.zsh"

run_inventory_task 07 Movies
exit $?
