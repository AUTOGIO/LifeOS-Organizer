# Roadmap

Format: Now / Next / Later. Nothing moves left until the item to its left is closed — this project runs sequentially by design (see `PROJECT_CHARTER.md` governance principles).

## Now

- Phase 2 hardening: plausibility guards on classification and triage engines; `set -e` decision; dead `errors` list cleanup.
- Phase 3: minimal synthetic-fixture regression harness.
- Phase 4: `.gitignore` for generated classification/review CSV/JSON (going forward only; no history rewrite).

## Next

- Phase 5a: `REMEDIATION_DESIGN.md` — move-to-quarantine, rollback ledger, dry-run default, `--apply` gate. Hard stop for operator approval before any remediation code.
- Phase 5b: `scripts/lib/remediation_engine.zsh` dry-run + Documents Batch 1 wrapper.
- Phase 5c: Operator-gated limited `--apply` + rollback verification on a Batch 1 subset.

## Later

- Larger Batch 1 quarantine applies after successful limited pilot.
- Fuzzy near-duplicate name matching — deferred / declined for current phase (`DECISIONS.md`).
- Broader remediation batches (2–5) only after Batch 1 pilot proves rollback.

## Explicit non-goals for this roadmap

- No automatic Downloads/Desktop cleanup at any point (permanent rule, not a phase).
- No deletion capability during the initial project (permanent rule, not a phase — see `docs/SAFETY_RULES.md`, rule 5).
- No Volumes inventory (permanently out of scope by operator decision, `DECISIONS.md` D8).
- No git history rewrite for past generated blobs.
