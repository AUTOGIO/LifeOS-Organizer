# Roadmap

Format: Now / Next / Later. Nothing moves left until the item to its left is closed — this project runs sequentially by design (see `PROJECT_CHARTER.md` governance principles).

## Now

- D21 CompilationCache multi-GB quarantine complete and kept (`REM-20260803-005600`, 11 files / ~146 GB moved within volume). Decide on remaining Batch 1 / CompilationCache files, and separately whether to approve purge of quarantine to free disk.

## Next

- Optional remaining CompilationCache / Batch 1 applies with a new `DECISIONS.md` approval.
- Optional approved quarantine purge (only path that frees disk; still no silent deletion).
- Optional R10 large-but-nonzero drop gate.

## Later

- Batches 2–5 remediation designs (separate approvals).
- Fuzzy near-duplicate name matching — deferred.
- Broader remediation after Batch 1 operational confidence.

## Explicit non-goals for this roadmap

- No automatic Downloads/Desktop cleanup at any point (permanent rule, not a phase).
- No deletion capability during the initial project (permanent rule, not a phase — see `docs/SAFETY_RULES.md`, rule 5).
- No Volumes inventory (permanently out of scope by operator decision, `DECISIONS.md` D8).
- No git history rewrite for past generated blobs.
