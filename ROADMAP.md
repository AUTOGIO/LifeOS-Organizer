# Roadmap

Format: Now / Next / Later. Nothing moves left until the item to its left is closed — this project runs sequentially by design (see `PROJECT_CHARTER.md` governance principles).

## Now

- Clone `scripts/04_desktop_inventory.zsh` into a Downloads script (`05_downloads_inventory.zsh`) and run it — Downloads is next per the original target order.

## Next

- Scan the remaining configured targets one at a time: Pictures, Movies, Music.
- Two targets (Documents, Desktop) are now done and structurally identical — the "rule of three" trigger for deciding whether to fold per-target scripts into one parameterized script (`DECISIONS.md` D7) lands after the next one (Downloads).
- CloudStorage and Volumes require separate, explicit approval before their first scan (per `docs/SAFETY_RULES.md`, rule 9) — external and cloud-backed paths are not auto-included even though they are already configured.

## Later

- Metadata-before-AI classification phase: define what "classification" means (categories, confidence thresholds, human-review requirement) before any AI step touches collected metadata.
- Draft the first remediation proposal format — read-only, human-approved, with a rollback map — per governance principle 4. No mutation code is written before this proposal format exists and is approved.

## Explicit non-goals for this roadmap

- No automatic Downloads/Desktop cleanup at any point (permanent rule, not a phase).
- No deletion capability during the initial project (permanent rule, not a phase — see `docs/SAFETY_RULES.md`, rule 5).
