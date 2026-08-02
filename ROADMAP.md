# Roadmap

Format: Now / Next / Later. Nothing moves left until the item to its left is closed — this project runs sequentially by design (see `PROJECT_CHARTER.md` governance principles).

## Now

- All 6 local targets have committed, validated classification proposals (Tasks 10-15, `DECISIONS.md` D10/D11). Nothing queued for execution — awaiting operator direction on the two open observations below.

## Next

- Two open observations from D11 need a follow-up conversation, not silent action: (1) Documents' classification review queue is large (132k records) — needs a triage-strategy discussion before treating it as actionable. (2) Pictures' inventory scan didn't prune the Photos Library package (`.photoslibrary` extension missing from D2's prune pattern) — an inventory-phase fix, separate from classification.

## Later

- Extend classification to the remaining local targets after the Downloads dry run is reviewed.
- Draft the first remediation proposal format — read-only, human-approved, with a rollback map — per governance principle 4 and `CLASSIFICATION_DESIGN.md` §5. No mutation code is written before this proposal format exists and is approved.

## Explicit non-goals for this roadmap

- No automatic Downloads/Desktop cleanup at any point (permanent rule, not a phase).
- No deletion capability during the initial project (permanent rule, not a phase — see `docs/SAFETY_RULES.md`, rule 5).
