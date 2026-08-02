# Roadmap

Format: Now / Next / Later. Nothing moves left until the item to its left is closed — this project runs sequentially by design (see `PROJECT_CHARTER.md` governance principles).

## Now

- Three items awaiting operator's final review before a single commit: (1) Documents classification triage (`review/Documents/`, `DECISIONS.md` D12). (2) Pictures package-recording fix, implemented and verified (`DECISIONS.md` D14) — Task 06 and Task 14 both re-run and validated against the corrected inventory. (3) New `RISK_REGISTER.md` R10 (validation gate doesn't catch an empty-result regression), documented, not fixed — deliberately out of scope for D14's "minimal correction."

## Next

- Commit once approved.
- Consider whether R10 (plausibility check on inventory reruns) is worth a small follow-up gate — not scoped or approved yet.

## Later

- Extend classification to the remaining local targets after the Downloads dry run is reviewed.
- Draft the first remediation proposal format — read-only, human-approved, with a rollback map — per governance principle 4 and `CLASSIFICATION_DESIGN.md` §5. No mutation code is written before this proposal format exists and is approved.

## Explicit non-goals for this roadmap

- No automatic Downloads/Desktop cleanup at any point (permanent rule, not a phase).
- No deletion capability during the initial project (permanent rule, not a phase — see `docs/SAFETY_RULES.md`, rule 5).
