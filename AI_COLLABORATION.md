# AI Collaboration

## History

This project has been built and modified by more than one AI system, under human direction:

| Date | System | Contribution |
|---|---|---|
| 2026-08-01 | Codex (generated), ChatGPT (reviewed) | Tasks 01–03: environment baseline, inventory engine, Documents inventory script |
| 2026-08-02 | Claude (Cowork) | Task 02.5-driven remediation: execution lock and Inventory ID fix in `03_documents_inventory.zsh`; this documentation set |
| 2026-08-02 | Claude (Cowork) | D7 shared-engine refactor; D8 CloudStorage safe-mode inventory (Task 09); D9 classification design (`CLASSIFICATION_DESIGN.md`), design-only, no code run |
| 2026-08-02 | Claude (Cowork) | D10–D11 classification pipeline for all 6 local targets; D12 Documents triage; D13–D14 package-recording fix; D15 R10 zero-result guard |
| 2026-08-02 | Cursor (Composer) | Independent progress audit; Charter/Executive/AI/Roadmap currency; pipeline hardening; remediation design and dry-run pilot |

Multiple AI systems working on the same codebase over time is expected and supported, provided every change follows the rules below regardless of which system makes it.

## Rules for any AI system working on this project

1. **Verify before acting.** Read the current state of a file, script, or artifact before changing or describing it. Do not assume prior output is still valid — this project's one documented incident (see `RISK_REGISTER.md`) was caused by stale process state, not a design flaw, and would have been visible to a quick check before acting.
2. **Read-only until explicitly authorized.** No AI system may add file-mutation logic (move, rename, delete, copy of user files) without explicit human approval recorded in `DECISIONS.md`.
3. **Minimal diffs.** Patch the smallest surface that fixes the identified problem. Do not rewrite working scripts wholesale. The 2026-08-02 fix touched roughly 20 lines across one file for exactly this reason.
4. **No fabrication.** Do not invent file paths, counts, statuses, or completion claims. Every number in this documentation set traces to a report, log, or script in this repository.
5. **Validation before publication.** Any script an AI system writes or modifies that produces a shared artifact must validate that artifact before it overwrites a previous good one (see `QUALITY_GATES.md`).
6. **Document the decision, not just the diff.** A change that alters behavior (locking, ID format, validation logic) gets an entry in `DECISIONS.md` and `CHANGELOG.md`, not just a code comment.
7. **Ask before expanding scope.** If a request is ambiguous between a narrow technical fix and a broader deliverable (as happened on 2026-08-02, between "repair the blocker" and "write the missing docs"), the AI system asks rather than guessing.
8. **Never let the sandbox create lock or staging artifacts inside the synced repository.** Originally learned as a git-only issue (stray `.git/*.lock` files from a sandbox `unlink()` restriction), confirmed general on 2026-08-02 when the same failure hit an ordinary `mkdir` lock directory and `mktemp -d` staging directory during classification pipeline verification (`RISK_REGISTER.md` R9, `DECISIONS.md` D10). Verify AI-authored pipeline logic against a scratch location outside the mounted repo (e.g. `/tmp`), never by exercising a script's real lock/stage path against the synced repo.

## What "AI-ready" means for this project

Classification of collected metadata is implemented for the six local targets (`DECISIONS.md` D9–D11). "AI-ready" now means: inventory and classification schemas are stable and documented, every proposal is traceable via InventoryID → ClassificationID → TriageID, and any future remediation requires a separate approved design with dry-run default and a rollback ledger (`REMEDIATION_DESIGN.md`).
