# Decisions

Architecture decision log. Newest first. Each entry: context, decision, consequences, status.

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
