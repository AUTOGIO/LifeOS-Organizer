# AI Collaboration

## History

This project has been built and modified by more than one AI system, under human direction:

| Date | System | Contribution |
|---|---|---|
| 2026-08-01 | Codex (generated), ChatGPT (reviewed) | Tasks 01–03: environment baseline, inventory engine, Documents inventory script |
| 2026-08-02 | Claude (Cowork) | Task 02.5-driven remediation: execution lock and Inventory ID fix in `03_documents_inventory.zsh`; this documentation set |

Multiple AI systems working on the same codebase over time is expected and supported, provided every change follows the rules below regardless of which system makes it.

## Rules for any AI system working on this project

1. **Verify before acting.** Read the current state of a file, script, or artifact before changing or describing it. Do not assume prior output is still valid — this project's one documented incident (see `RISK_REGISTER.md`) was caused by stale process state, not a design flaw, and would have been visible to a quick check before acting.
2. **Read-only until explicitly authorized.** No AI system may add file-mutation logic (move, rename, delete, copy of user files) without explicit human approval recorded in `DECISIONS.md`.
3. **Minimal diffs.** Patch the smallest surface that fixes the identified problem. Do not rewrite working scripts wholesale. The 2026-08-02 fix touched roughly 20 lines across one file for exactly this reason.
4. **No fabrication.** Do not invent file paths, counts, statuses, or completion claims. Every number in this documentation set traces to a report, log, or script in this repository.
5. **Validation before publication.** Any script an AI system writes or modifies that produces a shared artifact must validate that artifact before it overwrites a previous good one (see `QUALITY_GATES.md`).
6. **Document the decision, not just the diff.** A change that alters behavior (locking, ID format, validation logic) gets an entry in `DECISIONS.md` and `CHANGELOG.md`, not just a code comment.
7. **Ask before expanding scope.** If a request is ambiguous between a narrow technical fix and a broader deliverable (as happened on 2026-08-02, between "repair the blocker" and "write the missing docs"), the AI system asks rather than guessing.

## What "AI-ready" means for this project

Per `PROJECT_CHARTER.md`, AI classification of collected metadata is a later phase, not yet started. "AI-ready" currently means: the metadata schema is stable and documented (`SYSTEM_ARCHITECTURE.md`), and the audit trail (Inventory ID per run) is unique and traceable — a precondition for any future classification step to be reproducible and reviewable.
