# Roadmap

Format: Now / Next / Later. Nothing moves left until the item to its left is closed — this project runs sequentially by design (see `PROJECT_CHARTER.md` governance principles).

## Now

- Close out Task 03: operator terminates the 9 stale process trees and runs one clean, lock-protected pass of `03_documents_inventory.zsh`.
- Confirm the resulting `metadata.csv` / `metadata.json` pass validation and carry a single, unique Inventory ID.

## Next

- Scan the remaining seven configured targets, one task per target, reusing the same staged-publish pattern: Desktop, Downloads, Pictures, Movies, Music, CloudStorage, Volumes.
- CloudStorage and Volumes require separate, explicit approval before their first scan (per `docs/SAFETY_RULES.md`, rule 9) — external and cloud-backed paths are not auto-included even though they are already configured.
- Extend the execution-lock pattern to every task script, not just Task 03, so the whole pipeline is safe against repeated manual invocation.

## Later

- Metadata-before-AI classification phase: define what "classification" means (categories, confidence thresholds, human-review requirement) before any AI step touches collected metadata.
- Draft the first remediation proposal format — read-only, human-approved, with a rollback map — per governance principle 4. No mutation code is written before this proposal format exists and is approved.
- Revisit whether this project should move under version control. It currently has no git history; every "final state" depends entirely on the files on disk.

## Explicit non-goals for this roadmap

- No automatic Downloads/Desktop cleanup at any point (permanent rule, not a phase).
- No deletion capability during the initial project (permanent rule, not a phase — see `docs/SAFETY_RULES.md`, rule 5).
