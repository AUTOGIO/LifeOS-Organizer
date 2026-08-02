# Roadmap

Format: Now / Next / Later. Nothing moves left until the item to its left is closed — this project runs sequentially by design (see `PROJECT_CHARTER.md` governance principles).

## Now

- Operator clears two stray artifacts left by sandbox verification (`classification/Downloads/.task10.*`, `logs/.task10.lock` — see `DECISIONS.md` D10), then runs `./scripts/10_downloads_classification.zsh` to produce the official Downloads classification proposal. Logic already verified against real data (161 records, 127 High / 0 Medium / 34 Low, 0 warnings/errors) — this run is to confirm the zsh orchestration layer and produce the committed artifact.

## Next

- Review the official Downloads run together. Only after that: extend to the remaining local targets one at a time, per `CLASSIFICATION_DESIGN.md` §6 step 5.

## Later

- Extend classification to the remaining local targets after the Downloads dry run is reviewed.
- Draft the first remediation proposal format — read-only, human-approved, with a rollback map — per governance principle 4 and `CLASSIFICATION_DESIGN.md` §5. No mutation code is written before this proposal format exists and is approved.

## Explicit non-goals for this roadmap

- No automatic Downloads/Desktop cleanup at any point (permanent rule, not a phase).
- No deletion capability during the initial project (permanent rule, not a phase — see `docs/SAFETY_RULES.md`, rule 5).
