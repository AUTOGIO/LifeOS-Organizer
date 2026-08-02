# Roadmap

Format: Now / Next / Later. Nothing moves left until the item to its left is closed — this project runs sequentially by design (see `PROJECT_CHARTER.md` governance principles).

## Now

- Decide on CloudStorage and Volumes: both need separate explicit approval (`docs/SAFETY_RULES.md` rule 9) before any scan, and likely need engine changes (on-demand download risk for CloudStorage, unmount risk for Volumes) rather than a plain new wrapper over `run_inventory_task` as-is.

## Next

- (nothing queued beyond the CloudStorage/Volumes decision above — this is intentionally the current stopping point until that approval is given)

## Later

- Metadata-before-AI classification phase: define what "classification" means (categories, confidence thresholds, human-review requirement) before any AI step touches collected metadata.
- Draft the first remediation proposal format — read-only, human-approved, with a rollback map — per governance principle 4. No mutation code is written before this proposal format exists and is approved.

## Explicit non-goals for this roadmap

- No automatic Downloads/Desktop cleanup at any point (permanent rule, not a phase).
- No deletion capability during the initial project (permanent rule, not a phase — see `docs/SAFETY_RULES.md`, rule 5).
