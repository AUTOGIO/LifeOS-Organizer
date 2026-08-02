# Roadmap

Format: Now / Next / Later. Nothing moves left until the item to its left is closed — this project runs sequentially by design (see `PROJECT_CHARTER.md` governance principles).

## Now

- All approved local and CloudStorage targets are complete and verified (7 of 8 configured; Volumes explicitly declined by operator, 2026-08-02, not scheduled). No inventory work queued. Next substantive phase is the metadata-before-AI classification work below — not started, needs scoping.

## Next

- (nothing queued beyond scoping the classification phase — see Later)

## Later

- Metadata-before-AI classification phase: define what "classification" means (categories, confidence thresholds, human-review requirement) before any AI step touches collected metadata.
- Draft the first remediation proposal format — read-only, human-approved, with a rollback map — per governance principle 4. No mutation code is written before this proposal format exists and is approved.

## Explicit non-goals for this roadmap

- No automatic Downloads/Desktop cleanup at any point (permanent rule, not a phase).
- No deletion capability during the initial project (permanent rule, not a phase — see `docs/SAFETY_RULES.md`, rule 5).
