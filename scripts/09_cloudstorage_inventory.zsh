#!/bin/zsh
# LifeOS Organizer — Task 09
# Metadata-only inventory for the configured CloudStorage target
# (~/Library/CloudStorage — iCloud Drive, Dropbox, Google Drive, etc.).
# Approved per docs/SAFETY_RULES.md rule 9 (2026-08-02). Runs in safe mode:
# Spotlight enrichment forced off, vanish-tracking active. See DECISIONS.md
# D8 and scripts/lib/inventory_engine.zsh (run_inventory_task header comment)
# for what safe mode changes and why. This script never opens file content
# and never follows a path that would materialize an offline-only item —
# same find+stat-only design as every other target, unchanged.

set -uo pipefail

PROJECT_DIR="${0:A:h:h}"
source "$PROJECT_DIR/scripts/lib/inventory_engine.zsh"

run_inventory_task 09 CloudStorage 1
exit $?
