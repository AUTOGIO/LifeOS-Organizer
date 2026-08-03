# Decisions

Architecture decision log. Newest first. Each entry: context, decision, consequences, status.

---

## D18 — Remediation design approved; dry-run engine authorized (2026-08-02)

**Context.** Charter closeout plan Phase 5a–5b. Classification and triage are complete; remediation was only a placeholder in `CLASSIFICATION_DESIGN.md` §5.

**Decision.** Approve `REMEDIATION_DESIGN.md`: move-to-quarantine only (no delete), quarantine root `/Users/eduardofgiovannini/Documents/_LifeOS_Quarantine/<RemediationID>/`, dry-run default, `--apply` gated by `LIFEOS_REMEDIATION_APPROVED`, `--limit` required for apply, rollback via `--rollback <RemediationID>`. Authorize implementation of `scripts/lib/remediation_engine.zsh` and Task 17 wrapper. Authorize dry-runs of Documents Batch 1 without further approval.

**Status.** Implemented. Dry-run verified (`REM-20260802-231723`, 5 proposed, 0 applied).

---

## D19 — Limited Batch 1 apply+rollback pilot authorized (2026-08-02)

**Context.** After successful dry-run, Phase 5c requires a tiny real move+rollback cycle to demonstrate Charter rollback capability.

**Decision.** Authorize one `--apply --limit 5` of the five smallest Documents Batch 1 files, with `LIFEOS_REMEDIATION_APPROVED=D19`, followed immediately by `--rollback` of that RemediationID. No larger apply without a new DECISIONS entry.

**Status.** Executed: `REM-20260802-231738` applied 5 / failed 0; rollback restored 5 / failed 0. All originals verified present after rollback.

---

## D17 — Stop tracking generated classification/review CSV/JSON (2026-08-02)

**Context.** Progress audit found ~660 MB of regenerable `classification/*/classification_proposal.{csv,json}` and `review/**/triage_assignments.{csv,json}` committed, inconsistent with inventory's `.gitignore` policy (`RISK_REGISTER.md` R3).

**Decision.** Extend `.gitignore` to exclude those paths going forward. `git rm --cached` to untrack existing blobs; leave files on disk. **No history rewrite.** Keep human summaries (`summary.md`, `EXECUTIVE_SUMMARY.md`, `triage_batches.*`) tracked.

**Status.** Implemented (Phase 4).

---


**Context.** The progress audit (2026-08-02) found that R10/D15 closed the empty-publish failure mode only in the inventory engine. Classification and triage validators check consistency (CSV/JSON parity, ID matching) but not plausibility — an empty-but-well-formed result would still publish when the source had usable rows. Independently, Tasks 03–16 use `set -uo pipefail` without `-e` (unlike Tasks 01–02), which enabled the original D14 silent-`find` failure; the audit asked whether to adopt `-e` or document deliberate omission.

**Decision.**

1. **R11 guards.** Added plausibility checks to `scripts/lib/classification_engine.zsh` and `scripts/16_documents_triage.zsh`: abort publish if output record/assignment count is 0 while the upstream artifact has usable rows/paths. Same `ALLOW_EMPTY_RESULT=1` bypass as D15.
2. **`set -e` deliberately omitted** on shared-engine wrappers (03–16). Enabling `set -e` inside/around sourced functions with EXIT traps and intentional non-zero arithmetic (`(( total_directories += 1 ))` when starting from 0 can interact poorly with errexit in zsh) is a regression risk given this project's D7 trap-scoping incident. Instead, critical steps already use explicit status checks (`gen_exit`, validation `if ! python3`, `mv || return 1`), and the R10/R11 plausibility guards catch the empty-publish class. Tasks 01–02 keep `set -euo pipefail` because they are self-contained scripts without the shared-engine trap pattern.
3. **Dead `errors` list removed** from classification generation (never appended to; permanently printed "None").
4. **Fuzzy near-duplicate matching** remains deferred / declined for this phase (still disclosed in classification summaries).

**Status.** Implemented. Verified via Phase 3 synthetic harness.

---

## D15 — R10 zero-result validation guard added to the shared inventory engine (2026-08-02)

**Context.** Operator directed a narrow follow-up to R10 (the gap D14 exposed and deliberately left unfixed): add the smallest possible validation guard so an unexpectedly zero-result inventory fails clearly instead of publishing misleading output. Explicit scope: shared inventory engine only, plus focused validation and minimum documentation — no rescan of any real target, no new large artifacts, no Documents triage work, no commit.

**Decision.** Added one check to `run_inventory_task` in `scripts/lib/inventory_engine.zsh`, immediately after the scan loop completes and before the safe-mode vanish-count/report-generation steps: if `total_directories == 0`, abort with `return 1` before anything is published, leaving the previous good artifact untouched. `total_directories` (not `total_files`) is the check target, because the target root itself is always recorded as one directory entry by a correctly functioning scan — even a genuinely empty folder yields `total_directories == 1`, `total_files == 0`. So `total_directories == 0` can only happen if the scan command itself failed silently, which is exactly what happened in the D14 incident (`find: ): no beginning '('`, no `set -e`, empty-but-consistent result published anyway). An `ALLOW_EMPTY_RESULT=1` environment override bypasses the guard explicitly, for a future confirmed edge case; it is never assumed by default.

**Verification performed.** `bash -n` on the full library: no new errors — the one pre-existing failure (`<->` numeric glob at line 294, zsh-only syntax, predates this change, part of commit `471e657`) is unrelated and unchanged. `zsh -n` unavailable in this sandbox (same standing caveat as every prior change, `RISK_REGISTER.md` R6). The guard's branching logic was extracted and exercised in isolation against fabricated inputs in a `/tmp` scratch script (per R9's established method — no real target touched, no artifact generated): a normal successful scan (`total_directories=6`) passes; a silently-failed scan (`total_directories=0`, no override) is blocked; a genuinely empty target (`total_directories=1`, `total_files=0`) passes; `total_directories=0` with `ALLOW_EMPTY_RESULT=1` passes (explicit bypass); `total_directories=0` with the override set to anything else still blocks. All five cases behaved as intended.

**Exact failure behavior.** On trigger, two lines are written to stderr — the error (what happened, why, where to look) and a recovery line (fix the root cause and rerun, or set `ALLOW_EMPTY_RESULT=1` to explicitly bypass for a confirmed edge case) — then the function returns 1. Because this fires before the staged CSV/JSON is moved into its final published location, the previous good artifact is never touched; the incomplete staged files are removed by the existing cleanup trap.

**Consequences.** Closes the specific failure mode from the D14 incident (silent `find` failure publishing an empty-but-consistent result) for every target using the shared engine, at the cost of one integer comparison — no new subprocess calls, no new I/O, no measurable runtime impact. Does not address R10's broader suggested future gate (comparing against the previous run's count to catch a large-but-nonzero silent drop) — that remains open and is explicitly out of scope here.

**Status.** Implemented, logic-verified, and committed (Phase 1 Charter closeout).

---

## D14 — Package directories now recorded once, not silently excluded; two bugs found and fixed en route (2026-08-02)

**Context.** D13's proposal was approved with a narrower scope than originally written: not just add `.photoslibrary` to the prune patterns, but fix the deeper gap it exposed — package directories were never being recorded as a single row at all, for any of the 9 patterns, since D2. Operator approved a minimal, targeted correction: emit the matched directory once, then prune, no engine redesign, no classification-rule changes.

**Root cause.** The original `find -xdev \( -type d \( -name patterns \) -prune -o -exec stat ... {} + \)` shape relies on `-o` short-circuiting: when a directory matches the prune patterns, `-prune`'s own success makes the left side of the `-o` true, so the right side (`-exec`/`-print`) never runs for that specific entry — not just for its descendants. This silently excluded every package directory itself from the inventory, not merely their contents, for as long as D2 has existed. Confirmed via grep: `IsPackage=true` had a count of exactly 0 across all 6 local targets' published inventories, historically and currently, before this fix.

**Fix, attempt 1 (broken, caught before further damage).** Gave the package-matching branch its own `-exec ... {} \; -prune`, keeping the fallback branch's original batched `{} +`. This introduced a real bug: an extra, unmatched closing parenthesis was left over from the original single-group structure when restructuring into two branches. `bash -n` (the only syntax check available in this sandbox — no zsh here) could not catch this, since it's a `find` argument-grammar error, not a shell syntax error. The operator's first real run failed with `find: ): no beginning '('` and, because the script has no `set -e`, continued anyway, publishing an internally-consistent but completely empty result (`INV-20260802-201858`, 0 files, 0 directories) — the validation gate checks CSV/JSON consistency, not plausibility, so an empty-but-well-formed result passed it and overwrote the previous good Pictures inventory. No user file was affected; the only casualty was the project's own inventory artifact, immediately regenerable. See `RISK_REGISTER.md` R10 for this gap.

**Fix, attempt 2 (correct, tested before shipping).** Two corrections:
1. Removed the extra parenthesis (paren-balance re-verified programmatically: 2 opens / 2 closes on both affected lines, matching the original structure's balance).
2. **Reordered `-prune` before `-exec`** in the package branch, not after. Reasoning: `find` evaluates an AND chain left-to-right and short-circuits on the first false term; `-exec`'s truthiness depends on the executed command's exit status. With `-exec` before `-prune` (the naive fix), a single failed `stat` call on one package directory would skip `-prune` entirely and fall through to full traversal of that directory's contents — silently defeating the fix for that one entry. `-prune` always evaluates true per POSIX, so listing it first guarantees pruning fires regardless of whether the side-action succeeds. **Verified with a controlled test** (substituting `/bin/false` for the stat call against a synthetic directory tree, run outside the mounted repo): the naive ordering leaked into the pruned directory's contents when the action failed; the corrected ordering did not, in either a failing- or succeeding-action scenario. Same fix applied to the safe-mode pre-scan entry-count expression (D8) for consistency between the two.

**Verification performed.** `bash -n` (same pre-existing zsh-only `<->` false positive, no new errors). Exact command strings extracted programmatically from the committed file (not retyped) and executed against a synthetic tree in `/tmp`, outside the mounted repo, confirming: a package directory is emitted exactly once, its internals never appear, and this holds even when the action is forced to fail.

**Result, operator's real run.** Task 06 (Pictures): `INV-20260802-202531`, 13 files, 6 directories (one more than the pre-fix-attempt's 5 — the package itself, now counted), 9,987,047 bytes. Independently confirmed: 19 CSV/JSON rows matching, single consistent Inventory ID, exactly one `IsPackage=true` row (`Photos Library.photoslibrary`), zero rows individually inventoried beneath it. Task 14 (Pictures classification): `CLS-20260802-202619`, 28 records (23 High / 2 Medium / 3 Low) from the 13 real files, `SourceInventoryID` confirmed matching the new Pictures inventory exactly.

**Consequences.** `is_package_path()`/`package_count` now actually do what D2 originally described, for all 9 patterns, not just `.photoslibrary` — this was a project-wide latent gap, fixed project-wide, though the only target with real package content today is Pictures (confirmed via grep against the other 5 local targets — zero matches). `SYSTEM_ARCHITECTURE.md` step 4 updated to describe the corrected behavior.

**Status.** Fully implemented and verified. Not yet committed — awaiting operator's final review of this summary before commit, per instruction.

---

## D13 — Pictures `.photoslibrary` package-pruning fix: proposed, not approved (2026-08-02)

**Context.** Flagged as an open observation in D11. Assessed on operator request, explicitly as design-only — no code change, no re-run authorized in this decision.

**Finding.** `is_package_path()` and both `find -prune` expressions in `scripts/lib/inventory_engine.zsh` (D2) prune `*.photo\ library` (with a space) but not `*.photoslibrary` (the real, modern extension). Quantified against the real inventory: 8,964 of Pictures' 8,982 rows (99.8%) are the internals of one `Photos Library.photoslibrary` package that should have been recorded as a single opaque entry. Confirmed via grep that zero rows in any other of the 5 local targets mention `.photoslibrary` — the fix lives in the shared engine, but today's practical impact is Pictures-only.

**Proposal.** Full write-up in `PICTURES_PACKAGE_FIX_PROPOSAL.md`: three one-line additive edits (extend the existing OR-lists in `is_package_path()` and both `find -prune` expressions), a re-run of Task 06 (Pictures inventory) required afterward since the fix only affects future scans, and a consequent re-run of Task 14 (Pictures classification) since its `SourceInventoryID` would otherwise reference a now-stale inventory snapshot — the classification engine's own validation gate would catch that mismatch, not silently drift.

**Status.** Proposed, not approved. No file has been edited. Pictures has not been re-inventoried or re-classified. Awaiting explicit operator approval before touching `scripts/lib/inventory_engine.zsh` or running Task 06/14 again.

---

## D12 — Documents classification triage built and run (2026-08-02)

**Context.** Operator directed the next safe phase: reduce the Documents classification review queue (132,279 records, `DECISIONS.md` D11) into practical, prioritized review batches, using only the existing `classification/Documents/` proposal and `inventory/Documents/` artifacts — no filesystem rescan, no mutation, no commit until reviewed. Five priority tiers were specified: (1) high-confidence build/cache artifacts, (2) largest files/directories, (3) exact name+size duplicate-risk candidates, (4) medium-confidence duplicate and stale-file candidates, (5) low-confidence/ambiguous records last — each requiring record count, total size, rationale, confidence tier, review-mandatory flag, examples, and a recommended next action.

**Decision — mapping the 5 requested tiers onto the actual classification schema.** The user's 5 tiers don't map one-to-one onto the classification pipeline's dimensions/labels, so the mapping is documented explicitly here rather than silently assumed:

1. `duplicate-risk: regeneratable-build-artifact` (High, path-pattern + exact size match).
2. Top 50 files by `SizeBytes` (joined from `inventory/Documents/metadata.csv`, since `classification_proposal.csv` doesn't carry sizes) not already in batch 1. Largest directories are reported for context only, pulled from the already-computed ranking in `inventory/Documents/summary.md` — directories were never individually classified (only `IsDirectory=='false'` rows are), so they can't be "batched" the same way.
3. `duplicate-risk: possible-duplicate-candidate` (Medium, exact Name+SizeBytes match outside a build-cache pattern) — the strongest true duplicate signal available.
4. `duplicate-risk: same-name-different-size` (Low, weaker signal) plus `staleness: stale`/`very-stale` (High tier — staleness bucket assignment is deterministic date arithmetic; grouped here by the operator's priority logic, not because its confidence tier changed). This is flagged explicitly because "stale-file candidates" as requested implies Medium confidence, but no such label exists in the current schema.
5. Everything else — dominated by `file-type: unclassified-type` (Low) and plain project-grouping/file-type labels with no other signal.

Batch assignment is per unique `FullPath` (one batch per file, first-match-wins in the priority order above), not per raw classification record, since a file can carry 2-4 dimension records and record-level batching would double-count it.

**Implementation.** `scripts/16_documents_triage.zsh` — single-purpose script (not a shared library; only one use case exists, consistent with D7's rule-of-three reasoning), reads `classification/Documents/classification_proposal.csv`, `inventory/Documents/metadata.csv`, and `inventory/Documents/summary.md` only. Same lock/stage/generate/validate/publish pattern as every other task script. Output: `review/Documents/EXECUTIVE_SUMMARY.md`, `triage_batches.csv/json`, `triage_assignments.csv/json`, `reports/16_documents_triage.txt`.

**Verification performed (scratch, per R9's corrected method) and result.** Generated and validated against the real, published Documents classification (`CLS-20260802-160151`) and inventory (`INV-20260802-141128`) from `/tmp`, then copied into `review/Documents/` (plain file copy, not the locked pipeline — no lock/staging artifact was created inside the mounted repo this time). All 128,380 classified files were assigned to exactly one batch, summing correctly, with total size across all batches (161,007,433,747 bytes) matching Documents' known total exactly:

| Batch | Files | Total size |
|---|---|---|
| 1 — regeneratable build/cache artifacts | 8,997 | 146,553,591,983 B |
| 2 — largest files (top 50, not in batch 1) | 50 | 8,619,602,903 B |
| 3 — exact duplicate-risk candidates | 42,317 | 724,998,881 B |
| 4 — weak duplicate + stale candidates | 16,920 | 955,547,782 B |
| 5 — low-confidence/ambiguous | 60,096 | 4,153,692,198 B |

Notable finding surfaced by batch 2: this project's own `logs/03_documents_inventory_debug.log` (5.4 GB) is currently the single largest file under Documents — a leftover from the original Task 03 concurrency incident (`RISK_REGISTER.md` R1), inventoried like any other file since `Documents/GitHub` includes this very repository.

**Status.** Built and run once (scratch-verified copy). `scripts/16_documents_triage.zsh` exists for the operator to re-run on the real Mac for full provenance (mirrors the Task 10 pattern) before committing — not yet done. **Not committed**, per operator instruction, pending review of both this and D13.

---

## D11 — Classification extended to the remaining 5 local targets (2026-08-02)

**Context.** Operator reviewed the Downloads dry run (Task 10, committed `ab0a51f`) and gave a clean "go ahead" to proceed. `CLASSIFICATION_DESIGN.md` §6 step 5 allowed moving straight to a parameterized rollout, rather than repeating D7's clone-first-then-refactor cycle, if the dry run gave enough confidence — it did (exact match between sandbox-verified and operator-run numbers), and unlike inventory's original per-target scripts, `run_classification_task` was already built parameterized from the start (D10), so no engine change was needed for the remaining targets.

**Decision.** Added five thin wrappers: `scripts/11_movies_classification.zsh`, `12_desktop_classification.zsh`, `13_music_classification.zsh`, `14_pictures_classification.zsh`, `15_documents_classification.zsh`, plus their `classification/<Target>/` output directories. Task numbers assigned in ascending size order (Movies 49 files → Documents 128,380) as a cheap-first safety sequence, though it turned out not to matter — nothing failed at any scale.

**Verification performed (scratch, per R9/D10's corrected method — no lock/staging created inside the mounted repo).** The exact generation and validation Python bodies were extracted directly from the committed `scripts/lib/classification_engine.zsh` (not retyped, to rule out transcription drift) and run against each target's real, already-published `inventory/<Target>/metadata.csv` from `/tmp`. All five validated cleanly, 0 warnings, 0 errors:

| Target | Records | High | Medium | Low | Review queue | Gen time |
|---|---|---|---|---|---|---|
| Movies | 98 | 49 | 0 | 49 | 49 | <1s |
| Desktop | 312 | 265 | 5 | 42 | 47 | <1s |
| Music | 473 | 163 | 13 | 297 | 310 | <1s |
| Pictures | 17,323 | 11,386 | 2 | 5,935 | 5,937 | <1s |
| Documents | 463,774 | 331,495 | 42,321 | 89,958 | 132,279 | 6s |

**Two observations surfaced, neither acted on without further discussion:**

1. **Documents' review queue (132,279 records) is large relative to what a human can practically triage.** The dominant driver is `duplicate-risk: possible-duplicate-candidate` (42,321, Medium) and `same-name-different-size` (27,316, Low) — at 128k+ files, mostly inside a single large source-code workspace (`GitHub`, 127,699 project-grouping records), exact-size collisions between unrelated small files are common and mostly noise, not real duplicates. This is the heuristic working as designed (R8: name+size is a candidate signal, not proof) but at a scale where "requires human review" needs a follow-up conversation about triage strategy — e.g. surfacing only the largest-by-size candidates first — before Documents' review queue is treated as an actionable list. Not fixed here; flagged for the next conversation about this data.
2. **Pictures' `workspace:Photos Library.photoslibrary` grouping has 8,643 entries** — larger than expected for a "package" the inventory engine was supposed to prune. Checking `is_package_path()` in `scripts/lib/inventory_engine.zsh` (D2) confirms the prune pattern matches `*.photo\ library` (with a space, an older bundle naming convention) but not `*.photoslibrary` (the actual modern Photos Library package extension, no space) — so Pictures' inventory scan descended into and fully catalogued the library's internals rather than recording it as one opaque package entry. This is an **inventory-phase gap** (D2's prune list), not a classification bug — classification correctly reported what the inventory recorded. Fixing it would mean amending the prune pattern and re-running Pictures' inventory (Task 06), which is out of scope for this classification-phase decision and needs separate discussion, not a silent fix.

**Status.** Fully verified (2026-08-02). Operator ran all 5 wrappers; every count matched the pre-verified table exactly:

| Target | Classification ID | Records | High/Medium/Low |
|---|---|---|---|
| Movies | `CLS-20260802-160123` | 98 | 49/0/49 |
| Desktop | `CLS-20260802-160130` | 312 | 265/5/42 |
| Music | `CLS-20260802-160137` | 473 | 163/13/297 |
| Pictures | `CLS-20260802-160143` | 17,323 | 11,386/2/5,935 |
| Documents | `CLS-20260802-160151` | 463,774 | 331,495/42,321/89,958 |

Independently confirmed: CSV/JSON row-count parity and a single consistent ClassificationID for all 5, no leftover lock or staging artifacts anywhere. All 6 local targets now have committed classification proposals under the same pipeline.

---

## D10 — Classification pipeline built for Downloads; policy defaults finalized; sandbox-verification method changed (2026-08-02)

**Context.** Operator approved `CLASSIFICATION_DESIGN.md` with three policy defaults for the open questions in its §7: (1) target-specific staleness thresholds — Downloads 30/90/180 days, Documents/Desktop 180/365/730 days, Pictures/Movies/Music no staleness dimension; (2) duplicate-risk comparison stays within each target only, never across targets, for this phase; (3) package directories excluded from classification output by default. Operator directed the first safe execution: build the pipeline and dry-run Downloads only, reading only `inventory/Downloads/metadata.csv`, no filesystem rescan, no mutation, output confined to `classification/Downloads/` and `reports/`.

**Decision.** Built `scripts/lib/classification_engine.zsh` (`run_classification_task`, mirrors the inventory engine's lock → stage → generate → validate → publish pattern) and `scripts/10_downloads_classification.zsh`. The three policy defaults are encoded as a `case` statement on `TARGET_NAME` inside the library (single place to audit or extend, no new config file — deliberately not over-engineered for a one-target rollout). Duplicate-risk detection was split into two distinct signals to fix an inconsistency in the original design write-up: build-cache/regeneratable-artifact detection (path-pattern match + exact size match) stays High-confidence, since it is a structural claim about the path, not a claim that two files are copies of each other; genuine duplicate-*candidates* (exact Name+SizeBytes match outside a known build-cache pattern) are capped at Medium, consistent with `RISK_REGISTER.md` R8's "heuristic, not proof" framing; a third, weaker signal (same Name, differing SizeBytes — possibly different revisions) is Low.

**Bug found before reaching the operator.** While verifying the embedded Python generation script by running it directly (see below), an argv-slicing off-by-one surfaced immediately: `sys.argv[1:11]` silently dropped the 11th passed argument (`stale3`), crashing with `ValueError: not enough values to unpack`. Fixed to `sys.argv[1:12]` in `scripts/lib/classification_engine.zsh` before any execution was shown to the operator or committed.

**New lesson: the sandbox mount's `unlink()` restriction is general, not git-specific.** Prior guidance (see `RISK_REGISTER.md`, git lock-file incident) treated the sandboxed bash mount's inability to `unlink()` certain files as a git-only quirk. Verifying this pipeline end-to-end exposed the same failure on ordinary files: an `mkdir`-based lock directory and a `mktemp -d` staging directory created inside the mounted repo (`logs/.task10.lock`, `classification/Downloads/.task10.46B7b6`) could not be removed by `rm -rf` from the sandbox (`Operation not permitted`), identical in nature to the earlier `.git/*.lock` problem. **Revised rule: the sandbox must never create lock or staging artifacts inside the synced repository, for any task, not just git.** Verification of AI-authored pipeline logic must run against a scratch location outside the mounted repo (e.g. `/tmp` in the sandbox), never by exercising the real lock/stage path against `logs/` or a target's output directory. The two stray directories from this incident need manual removal on the real Mac before the official run:

```
cd /Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer
rm -rf classification/Downloads/.task10.* logs/.task10.lock
```

**Verification performed.** With the bug fixed, the exact generation and validation Python bodies (byte-identical to what's embedded in `scripts/lib/classification_engine.zsh`) were run against the real, already-published `inventory/Downloads/metadata.csv` from a `/tmp` scratch location — never touching `classification/Downloads/`, `logs/`, or `reports/` in the mounted repo. Result: 161 classification records from Downloads' 53 files (127 High / 0 Medium / 34 Low, 34 in the review queue, 0 warnings, 0 errors), validation gate passed (`VALIDATE_OK`). This confirms the pipeline's logic is correct; it does not confirm the zsh orchestration shell (lock/trap/mv) runs cleanly under real zsh, since zsh is not available in this sandbox — same caveat this project has carried since D4/D5 (`RISK_REGISTER.md` R6).

**Status.** Pipeline implemented and logic-verified. Not yet run as the operator's own official, committed artifact. Next: operator clears the two stray artifacts above, then runs `./scripts/10_downloads_classification.zsh` to produce the real `classification/Downloads/` output.

---

## D9 — Classification design proposed; scope limited to local targets, design-only until approved (2026-08-02)

**Context.** With inventory closed for 7 of 8 targets (D7, D8), the Charter's next ordering step is "Metadata before AI" — the classification phase. Operator directed: local targets only (Documents, Desktop, Downloads, Pictures, Movies, Music — CloudStorage and Volumes explicitly excluded), read-only design and proposal only, no file mutation of any kind, four classification dimensions (project/workspace grouping, file type/extension, age/staleness, size and duplicate-risk signals from metadata only), a three-tier confidence policy (high auto-proposable, medium/low require human review, no tier ever triggers movement), and an explicit stop for approval before any classification output is generated or code is run.

**Decision.** Produced `CLASSIFICATION_DESIGN.md`: category model, confidence thresholds/review rules, a pipeline design that mirrors the inventory engine's proven staged-write/validate/atomic-publish/execution-lock pattern (D1, D5-D7) reading only already-published `inventory/<Target>/metadata.csv|json` (no filesystem re-scan), example proposed outputs grounded in real numbers pulled read-only from the existing validated inventory metadata (not fabricated), a safety/rollback plan for a possible future mutation phase (not requested, not scoped), and a 5-step implementation plan. No classification script was written or run. No user file or inventory artifact was touched — only already-published `metadata.csv` files were read, the same read-only access already exercised throughout this project's documentation work.

**Consequences.** The design introduces a new artifact tree, `classification/<Target>/`, structurally separate from `inventory/<Target>/` — classification output can never overwrite inventory data, and every classification record must cite the `InventoryID` it was derived from, preserving the audit-trail principle (Charter principle 8). Duplicate-risk detection is explicitly scoped as a `(Name, SizeBytes)` heuristic, not a hash comparison — no hash column exists in the current schema, and adding one would be a separate, separately-approved inventory-schema change, not part of this phase.

**Status.** Design delivered, awaiting operator approval. No implementation started. Three open questions recorded in `CLASSIFICATION_DESIGN.md` §7 need answers before Phase 2 (pipeline build) begins.

---

## D8 — CloudStorage approved with a safe-mode flag on `run_inventory_task`; Volumes explicitly out of scope (2026-08-02)

**Context.** `docs/SAFETY_RULES.md` rule 9 requires separate approval before scanning CloudStorage or Volumes. Operator approved scoped engine changes and a full metadata-only inventory of both, with requirements: no cloud downloads triggered, no files modified, unmounted/unavailable volumes handled cleanly, each report validated before proceeding. Before writing code, the proposed safeguards were presented for review, including one real design fork: the engine's `find` uses `-xdev` (correct for local targets), which for a target of literally `/Volumes` would list mount-point stubs but not descend into any individually-mounted volume — a silent, misleadingly "clean" near-empty scan. Two resolutions were offered (per-volume inventory with individual approval, or a shallow mount-listing only). Operator's decision: **skip Volumes entirely** — "NO NEED to work in VOLUMES." Scope narrowed to CloudStorage only.

**Decision.** Added an optional third parameter to `run_inventory_task`, `SAFE_MODE` (default `"0"`), rather than forking the engine or writing CloudStorage-specific logic outside it:
- `SAFE_MODE=0` (all of scripts 03-08, unchanged): byte-for-byte identical behavior and report output to the D7-verified baseline. No regression risk — nothing about the six already-validated targets changes.
- `SAFE_MODE=1` (new `scripts/09_cloudstorage_inventory.zsh` only): Spotlight enrichment (`mdls`) forced off regardless of the `COLLECT_SPOTLIGHT` env override — precautionary, since `mdls` behavior against not-yet-materialized cloud placeholder files isn't independently verified as non-triggering. Also runs one extra path-only `find` pass before the scan to count entries as listed, then compares that to what was actually resolved at `stat` time; any gap is reported as a "vanished mid-scan" count in the report's new Availability section, instead of silently vanishing from output the way a mid-batch `stat` failure did before.

**Why this design and not a schema change.** No new CSV/JSON column (e.g. a per-file "materialized/offline" flag) was added. The engine's scan primitives (`find` for traversal, `stat` for metadata) never open file content regardless of target — that's what already makes them safe against triggering iCloud/Dropbox downloads, and it required no change. A per-file download-status column was considered and rejected as scope beyond what was asked: none of the four stated requirements (no downloads, no mutation, clean unavailable-handling, per-report validation) call for it, and touching the shared field list would mean re-validating all 6 existing targets' schema again for no operational gain.

**Consequences.** One shared file (`inventory_engine.zsh`) still covers every target; CloudStorage's differences are fully contained in one flag most reviewers won't need to know about when reading the six unchanged wrappers. Volumes remains configured in `config/inventory_targets.yaml` but is not scheduled — `RISK_REGISTER.md` R7 updated to reflect CloudStorage as in-progress and Volumes as explicitly deferred by operator choice, not by omission.

**Verification performed before handoff.** `bash -n` against the modified library and the new wrapper — same pre-existing zsh-only `<->` false positive as D7 (`RISK_REGISTER.md` R6), no new syntax errors from this change. Not yet executed under zsh — pending operator run, same as every prior script change in this project.

**Status.** Fully verified (2026-08-02). Operator ran `./scripts/09_cloudstorage_inventory.zsh`: `INV-20260802-144307`, 22,833 files, 1,779 directories, 86,341,869,509 bytes. Independently confirmed: 24,612 CSV/JSON records matching under the single Inventory ID, Availability section reports "All entries listed at scan start were resolvable at stat time" (0 vanished mid-scan), no leftover `logs/.task09.lock` or `inventory/CloudStorage/.task09.*` staging artifacts. Safe mode worked exactly as designed on first run — no bug this time.

---

## D7 — Clone per target instead of parameterizing; refactor point deferred again (2026-08-02)

**Context.** With Task 03 (Documents) validated end-to-end, the next step was scanning additional targets (Desktop, Downloads, Pictures, Movies, Music). Two options: write one parameterized script that takes a target name/path, or clone the validated Task 03 script per target with minimal, mechanical changes.

**Decision (initial).** Clone. `scripts/04_desktop_inventory.zsh` is `03_documents_inventory.zsh` with exactly six categories of change (header comment, `TARGET_NAME`, `REPORT_PATH`, `LOCK_DIR`, `mktemp` suffix, awk match string, user-facing target-name strings, report titles) — every other line, including all locking, staging, and validation logic, is untouched. Confirmed via `diff` before use. `scripts/05_downloads_inventory.zsh` followed the same pattern.

**Rule-of-three checkpoint (2026-08-02, same day).** Three targets now done — Documents (128,305 files, 275s), Desktop (99 files, 1s), Downloads (53 files, 0s) — spanning three orders of magnitude in scale with zero logic divergence across any of them; every diff between clones was exactly the same six mechanical substitutions. That's the signal a shared script would generalize cleanly. Decided **not** to refactor yet anyway: Pictures, Movies, and Music are the same kind of target (local, already-approved, no special handling expected) and cost minutes each to clone versus the regression risk of restructuring an already-validated, in-flight rollout mid-stream. Refactoring is cheaper and safer done once, after all local targets are stable, against five known-good outputs to regression-test against, than done now against three with two more still to come.

**Decision (2026-08-02, later same day — refactor executed).** All 5 local targets (Documents, Desktop, Downloads, Pictures, Movies, Music — 6 scripts counting Documents) completed and validated with zero logic divergence across every clone. Refactored as planned: created `scripts/lib/inventory_engine.zsh` containing every shared function (`section`, `csv_escape`, `json_escape`, `is_package_path`, `emit_csv_row`, `emit_json_row`, `print_ranked_entries`, `print_top_extensions`) plus a new `run_inventory_task <TASK_NUM> <TARGET_NAME>` function holding the full pipeline (preflight, lock, staging, scan, report, validate, publish) — parameterized but otherwise line-for-line the same logic as the validated Task 08 clone. Rewrote `scripts/03-08` as ~15-line thin wrappers that `source` the library and call `run_inventory_task` with their own task number and target name.

**Verification performed before handoff.** (1) `bash -n` against the library with its one zsh-only construct (`<->` numeric glob, present since the original script) neutralized — no other structural errors. (2) The parameterized awk target-lookup tested against the real `config/inventory_targets.yaml` for all 8 configured targets, including the two not yet in use (CloudStorage, Volumes) — all resolved to the correct paths. (3) All 6 wrapper scripts pass `bash -n` outright (no zsh-specific syntax in them). **Not yet done:** an actual zsh execution — no zsh available in the environment this refactor was written in. The real regression test is the operator re-running each target script once and confirming file/directory counts land close to the last known-good numbers, with the built-in validation gate as a safety net (a broken refactor would fail validation and preserve the prior good artifact, not silently corrupt it).

**Consequences.** One shared file to fix instead of 6 for any future bug. Slightly more indirection when reading a single wrapper script in isolation (have to open the library to see what it does) — accepted, since `DECISIONS.md`/`SYSTEM_ARCHITECTURE.md` document the split. CloudStorage and Volumes remain out of scope for this library — they'll likely need their own handling (on-demand download risk, unmount risk) layered on top, not folded into `run_inventory_task` as-is.

**Bug found on first real run (2026-08-02, same day).** Operator ran the refactored `03_documents_inventory.zsh`. The scan/validate/publish pipeline worked correctly — Inventory ID `INV-20260802-140520`, 128,380 files, 17,831 directories, independently confirmed at 146,211 matching CSV/JSON records — but the script printed `cleanup: RUN_DIR: parameter not set` and left a stale `logs/.task03.lock` plus two empty `.task03.XXXXXX` staging-directory husks behind. Root cause: `RUN_DIR` and `LOCK_DIR` were declared `local` inside `run_inventory_task`, so they went out of scope the moment the function returned — but the `EXIT`/`HUP`/`INT`/`TERM` trap fires at the *wrapper script's* process exit, after the function has already returned, and under `set -u` referencing the now-unset locals aborted the cleanup command before it ran. No data loss: the leftover lock self-heals on the next run (dead PID gets reclaimed automatically), and the empty staging dirs held no data since their contents were already `mv`'d out before cleanup would have run. Fixed by declaring both `typeset -g` instead of `local`, matching the same fix already applied to the shared associative arrays for the identical cross-function-boundary reason.

**Re-verified after fix (2026-08-02).** Operator cleared the leftover lock/staging artifacts and reran Task 03: completed with no `cleanup:` error, and both `logs/.task03.lock` and `inventory/Documents/.task03.*` confirmed absent afterward. Inventory ID `INV-20260802-141128`: 128,380 files, 17,830 directories, 161,007,433,747 bytes, independently confirmed at 146,210 matching CSV/JSON records. Documents is verified end-to-end under the refactored engine.

**Status: fully verified (2026-08-02).** All 6 scripts (03-08) reran clean under the fixed library — no `cleanup:` errors, no leftover lock or staging directories anywhere, every CSV/JSON pair independently confirmed matching under a single consistent Inventory ID:

| Task | Target | Inventory ID | Files | Dirs | Records matched |
|---|---|---|---|---|---|
| 03 | Documents | `INV-20260802-141128` | 128,380 | 17,830 | 146,210 |
| 04 | Desktop | `INV-20260802-141614` | 99 | 21 | 120 |
| 05 | Downloads | `INV-20260802-141749` | 53 | 6 | 59 |
| 06 | Pictures | `INV-20260802-141844` | 8,656 | 326 | 8,982 |
| 07 | Movies | `INV-20260802-141928` | 49 | 5 | 54 |
| 08 | Music | `INV-20260802-142008` | 161 | 23 | 184 |

The D7 refactor is done: one shared library, six thin wrappers, one bug found and fixed on first contact, now fully exercised and trusted.

---

## D6 — Execution lock extended to Tasks 01 and 02 (2026-08-02)

**Context.** D5 added an execution lock only to `03_documents_inventory.zsh`, the script actually involved in the concurrency incident. `RISK_REGISTER.md` (R1) flagged the same unlocked-concurrent-invocation risk as latent in `01_environment_baseline.zsh` and `02_inventory_engine.zsh` — lower likelihood today (both are fast, interactive, rarely rerun mid-flight) but the same bug class.

**Decision.** Apply the identical mkdir-lock pattern (`logs/.task01.lock`, `logs/.task02.lock`) to both scripts, unchanged in mechanics from D5. Did not add staged-publish/validation to either script — both still write their report directly via `exec > "$REPORT_PATH"`. That remains a separate, lower-priority gap (`QUALITY_GATES.md`), acceptable because a single small text file has no partial-write risk comparable to a 100k-row CSV/JSON pair.

**Consequences.** Neither script can now be run twice concurrently; a second invocation fails fast with a named holder PID instead of silently interleaving output.

**Status.** Implemented in `scripts/01_environment_baseline.zsh` and `scripts/02_inventory_engine.zsh`. Not syntax-checked with `zsh -n` in this environment (no zsh available here) — same caveat as D4/D5, see `RISK_REGISTER.md` R6.

---

## D5 — Execution lock via `mkdir`, not `flock` (2026-08-02)

**Context.** Task 02.5 found 9 stale, non-completing Task 03 process trees, traced to repeated manual invocation with no mechanism to prevent concurrent runs. This directly caused corruption of `metadata.csv` / `metadata.json`.

**Decision.** Use an `mkdir`-based lock directory (`logs/.task03.lock`) rather than `zsh/system`'s `zsystem flock` or `flock(1)`. `mkdir` is atomic on the local filesystem, needs no extra zsh module or external binary, and its failure mode (directory already exists) is trivial to detect and reason about. The lock directory holds a `pid` file so a stale lock (holder process no longer alive) can be safely reclaimed via `kill -0`.

**Consequences.** Locking is local-filesystem-only and would not protect against a second Mac writing to the same path (not a real scenario here — single-machine, local-first project). Reclaiming a stale lock is best-effort: it trusts that a PID no longer running means the prior holder is truly gone, which is correct for this project's process model (no daemons, no respawn).

**Status.** Implemented in `scripts/03_documents_inventory.zsh`.

---

## D4 — Inventory ID widened to `INV-YYYYMMDD-HHMMSS` (2026-08-02)

**Context.** The prior format, `INV-<date>-001`, hardcoded the sequence field. The debug log shows two distinct completed runs on 2026-08-01 both publishing as `INV-20260801-001` — a direct violation of the charter's "complete audit trail" principle, since the ID alone can no longer identify which run produced a given artifact.

**Decision.** Replace the hardcoded `-001` with the run's start time (`HHMMSS`). Same-day reruns are now distinguishable unless two runs start in the same second, which the execution lock (D5) already prevents by construction.

**Consequences.** The embedded Python validation regex (`INV-\d{8}-\d{3}`) had to change to `INV-\d{8}-\d{6}`. Any external tooling that parses this ID format must be updated to match. None currently exists.

**Status.** Implemented in `scripts/03_documents_inventory.zsh`.

---

## D3 — Spotlight metadata is opt-in, off by default

**Context.** Optional `mdls`-based content-type/kind enrichment adds a per-file subprocess call, which is expensive at 100k+ file scale.

**Decision.** Gate Spotlight collection behind `COLLECT_SPOTLIGHT=1`. Default runs record a single warning noting the fields were skipped, rather than silently omitting an explanation.

**Consequences.** Default reports have blank `SpotlightContentType` / `SpotlightKind` columns. This is documented, not a defect.

**Status.** Implemented in `scripts/03_documents_inventory.zsh` (original version).

---

## D2 — Package directories are recorded, not descended into

**Context.** macOS treats `.app`, `.bundle`, `.framework`, `.kext`, `.pages`, `.numbers`, `.key`, `.photo library`, and `.sparsebundle` as single logical files even though they are directories on disk. Descending into them would inflate file counts and mostly surface internal implementation detail the user doesn't need inventoried.

**Decision.** Prune these directory types at `find` level (`-prune`), recording one entry per package with `IsPackage=true`.

**Consequences.** Contents of packages are invisible to this inventory. This is intentional and documented in every generated report's Notes section.

**Status.** Implemented in `scripts/03_documents_inventory.zsh` (original version).

---

## D1 — Staged write + validate + atomic publish, not direct write

**Context.** A script writing large CSV/JSON output directly to its final path is vulnerable to partial writes on interruption and offers no pre-publish sanity check.

**Decision.** Every task script that produces shared artifacts writes to a private `mktemp -d` staging directory first, validates the complete result, and only then does an atomic `mv` into the final location. A validation failure leaves the previous good artifact untouched.

**Consequences.** This is why the 2026-08-01 corruption was not a design flaw in the current script — it was caused by stale processes from *before* this pattern's protections applied to a given run, not by the pattern failing. See `RISK_REGISTER.md`.

**Status.** Implemented in `scripts/03_documents_inventory.zsh` (original version). Not yet extended to `01_environment_baseline.zsh` or `02_inventory_engine.zsh`, which write their reports directly — acceptable for now since both are fast, idempotent, read-only checks with no large-scan interruption risk.
