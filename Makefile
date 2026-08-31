# LifeOS Organizer — task runner
# =============================================================================
# Thin, self-documenting front end over the numbered zsh task scripts in
# scripts/ (01-17) and the synthetic guard harness in tests/. It does not
# reimplement any logic — each target just invokes the corresponding script,
# which owns its own execution lock, pwd guard, and validation.
#
# Safety contract (see README.md / docs/SAFETY_RULES.md), reflected here:
#   * The default target is `help` — running `make` mutates nothing.
#   * `pipeline` is read-only end to end (inventory -> classify -> triage).
#   * Only remediation targets can move files, and only 17 with `--apply`
#     actually mutates; it is never part of `pipeline` and prints a warning.
#   * `clean` removes ONLY regenerable derived artifacts. It never touches
#     remediation/ ledgers or proposals (those are rollback maps — the one
#     thing the project promises never to delete).
#
# Usage:  make <target>     (run `make help` for the full list)
# =============================================================================

# Repo root, derived from this Makefile's own location, so `make -C <path>`
# and `make -f <path>/Makefile` both work. Scripts additionally self-check
# that they run from the repo root; every recipe cd's here first.
ROOT := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
SHELL := /bin/zsh
RUN := cd $(ROOT) &&

.DEFAULT_GOAL := help

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
.PHONY: help
help: ## Show this help
	@echo 'LifeOS Organizer — make targets'
	@echo '================================'
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo 'Read-only pipeline:  make pipeline'
	@echo 'Recover stuck run:   make clean-locks   (see RUNBOOK.md)'

# -----------------------------------------------------------------------------
# Baseline & framework (read-only)
# -----------------------------------------------------------------------------
.PHONY: baseline framework check
baseline: ## 01 Environment & safety baseline
	$(RUN) ./scripts/01_environment_baseline.zsh

framework: ## 02 Inventory framework readiness check
	$(RUN) ./scripts/02_inventory_engine.zsh

check: baseline framework ## Run baseline + framework readiness checks

# -----------------------------------------------------------------------------
# Inventory — 03-09 (read-only metadata collection)
# -----------------------------------------------------------------------------
.PHONY: inventory inv-documents inv-desktop inv-downloads inv-pictures inv-movies inv-music inv-cloud
inv-documents: ## 03 Documents inventory
	$(RUN) ./scripts/03_documents_inventory.zsh
inv-desktop: ## 04 Desktop inventory
	$(RUN) ./scripts/04_desktop_inventory.zsh
inv-downloads: ## 05 Downloads inventory
	$(RUN) ./scripts/05_downloads_inventory.zsh
inv-pictures: ## 06 Pictures inventory
	$(RUN) ./scripts/06_pictures_inventory.zsh
inv-movies: ## 07 Movies inventory
	$(RUN) ./scripts/07_movies_inventory.zsh
inv-music: ## 08 Music inventory
	$(RUN) ./scripts/08_music_inventory.zsh
inv-cloud: ## 09 CloudStorage inventory
	$(RUN) ./scripts/09_cloudstorage_inventory.zsh
inventory: inv-documents inv-desktop inv-downloads inv-pictures inv-movies inv-music inv-cloud ## Run all inventory targets (03-09)

# -----------------------------------------------------------------------------
# Classification — 10-15 (read-only proposals; dry run, no mutation)
# -----------------------------------------------------------------------------
.PHONY: classify cls-downloads cls-movies cls-desktop cls-music cls-pictures cls-documents
cls-downloads: ## 10 Downloads classification proposal
	$(RUN) ./scripts/10_downloads_classification.zsh
cls-movies: ## 11 Movies classification proposal
	$(RUN) ./scripts/11_movies_classification.zsh
cls-desktop: ## 12 Desktop classification proposal
	$(RUN) ./scripts/12_desktop_classification.zsh
cls-music: ## 13 Music classification proposal
	$(RUN) ./scripts/13_music_classification.zsh
cls-pictures: ## 14 Pictures classification proposal
	$(RUN) ./scripts/14_pictures_classification.zsh
cls-documents: ## 15 Documents classification proposal
	$(RUN) ./scripts/15_documents_classification.zsh
classify: cls-downloads cls-movies cls-desktop cls-music cls-pictures cls-documents ## Run all classification targets (10-15)

# -----------------------------------------------------------------------------
# Triage — 16 (read-only)
# -----------------------------------------------------------------------------
.PHONY: triage
triage: ## 16 Documents triage into review batches
	$(RUN) ./scripts/16_documents_triage.zsh

# -----------------------------------------------------------------------------
# Remediation — 17 (the ONLY file-mutating stage; move-to-quarantine, no delete)
# -----------------------------------------------------------------------------
.PHONY: remediate remediate-dry remediate-apply remediate-rollback
remediate-dry: ## 17 Documents Batch 1 remediation — DRY RUN (default, no changes)
	$(RUN) ./scripts/17_documents_batch1_remediation.zsh
remediate: remediate-dry ## Alias for remediate-dry
remediate-apply: ## 17 Documents Batch 1 remediation — APPLY (moves files to quarantine)
	@echo '!! APPLY moves files to quarantine (reversible via `make remediate-rollback`).'
	@echo '!! Requires prior operator approval per REMEDIATION_DESIGN.md. Ctrl-C to abort.'
	$(RUN) ./scripts/17_documents_batch1_remediation.zsh --apply
remediate-rollback: ## 17 Documents Batch 1 remediation — ROLLBACK a prior apply
	$(RUN) ./scripts/17_documents_batch1_remediation.zsh --rollback

# -----------------------------------------------------------------------------
# Read-only end-to-end pipeline (never mutates files)
# -----------------------------------------------------------------------------
.PHONY: pipeline
pipeline: check inventory classify triage ## Full read-only run: check -> inventory -> classify -> triage

# -----------------------------------------------------------------------------
# Tests & reports
# -----------------------------------------------------------------------------
.PHONY: test reports
test: ## Run synthetic guard harness (no real user targets touched)
	$(RUN) ./tests/run_synthetic_guards.zsh
reports: ## List generated run reports
	@ls -1 $(ROOT)/reports

# -----------------------------------------------------------------------------
# Housekeeping
# -----------------------------------------------------------------------------
.PHONY: clean-locks clean
clean-locks: ## Remove stale execution locks (stuck-run recovery, see RUNBOOK.md)
	@find $(ROOT)/logs -type d -name '.task*.lock' -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
	@echo 'Stale execution locks cleared.'
clean: ## Remove regenerable derived artifacts (never remediation ledgers)
	@echo 'Removing regenerable inventory / classification / triage artifacts...'
	@find $(ROOT)/inventory -type f \( -name 'metadata.csv' -o -name 'metadata.json' \) -delete 2>/dev/null || true
	@find $(ROOT)/classification -type f \( -name 'classification_proposal.csv' -o -name 'classification_proposal.json' \) -delete 2>/dev/null || true
	@find $(ROOT)/review -type f \( -name 'triage_assignments.csv' -o -name 'triage_assignments.json' \) -delete 2>/dev/null || true
	@find $(ROOT)/logs -type f -name '*.log' -delete 2>/dev/null || true
	@echo 'Done. remediation/ ledgers & proposals left untouched by design.'
