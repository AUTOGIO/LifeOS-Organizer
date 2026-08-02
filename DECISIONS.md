# Decisions

Architecture decision log. Newest first. Each entry: context, decision, consequences, status.

---

## D7 — Clone per target instead of parameterizing, until proven otherwise (2026-08-02)

**Context.** With Task 03 (Documents) validated end-to-end, the next step was scanning additional targets (Desktop, Downloads, Pictures, Movies, Music). Two options: write one parameterized script that takes a target name/path, or clone the validated Task 03 script per target with minimal, mechanical changes.

**Decision.** Clone. `scripts/04_desktop_inventory.zsh` is `03_documents_inventory.zsh` with exactly six categories of change (header comment, `TARGET_NAME`, `REPORT_PATH`, `LOCK_DIR`, `mktemp` suffix, awk match string, user-facing target-name strings, report titles) — every other line, including all locking, staging, and validation logic, is untouched. Confirmed via `diff` before use.

**Consequences.** More files to keep in sync if the shared logic ever needs a fix (as it did twice already for Task 03 — see D4/D5). Accepted deliberately: with only one validated target, a shared/parameterized script would be an abstraction built on a sample size of one, and any target-specific quirk (scale, symlink density, file types) would land in shared code before it's understood. Revisit after Desktop plus one more target are both done and clearly identical in structure — that's a "rule of three" trigger, not before.

**Status.** Implemented. `scripts/04_desktop_inventory.zsh` created, not yet executed against real data.

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
