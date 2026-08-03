# Runbook

All commands run from the repository root on the target Mac:

```
cd /Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer
```

Every script enforces this — they exit immediately if `pwd` doesn't match.

## Standard task execution

```
./scripts/01_environment_baseline.zsh   # read-only env/safety baseline → reports/01_environment_baseline.txt
./scripts/02_inventory_engine.zsh       # framework readiness check → reports/02_inventory_engine.txt
./scripts/03_documents_inventory.zsh    # Documents metadata inventory → inventory/Documents/*, reports/03_documents_inventory.txt
./scripts/04_desktop_inventory.zsh      # Desktop metadata inventory → inventory/Desktop/*, reports/04_desktop_inventory.txt
```

Run `02_inventory_engine.zsh` before any new target's first inventory run — it fails fast on missing config, missing staging directories, or a target path that no longer exists.

Each `0N_<target>_inventory.zsh` script takes minutes to over an hour depending on target size (Documents: 275s–3915s across runs). Run it in a terminal session you intend to keep open; do not background it and forget about it — that is exactly how the 2026-08-01 Task 03 incident happened (see `RISK_REGISTER.md`). Every target script carries its own execution lock (`logs/.taskNN.lock`), so a second accidental invocation of the *same* script fails fast instead of racing — but nothing stops you from starting two *different* target scripts at once if you choose to; that's fine, they don't share output paths.

Optional Spotlight enrichment (adds runtime, off by default), same flag on any target script:

```
COLLECT_SPOTLIGHT=1 ./scripts/04_desktop_inventory.zsh
```

## Recovering from a stuck or duplicated Task 03 run

Symptom: a Task 03 run appears to never finish, or `inventory/Documents/metadata.csv` / `metadata.json` grow in size with no corresponding new report.

**1. Check what's actually running (not what you remember running):**

```
ps -Ao pid,ppid,etime,pcpu,command | grep -E '03_documents_inventory\.zsh|find /Users/eduardofgiovannini/Documents -xdev' | grep -v grep
```

**2. If anything shows up, terminate it gracefully.** These are read-only `find`/`zsh` processes — SIGTERM is safe, no data loss:

```
pkill -TERM -f '03_documents_inventory\.zsh'
pkill -TERM -f 'find /Users/eduardofgiovannini/Documents -xdev'
```

**3. Confirm nothing remains** (repeat step 1's command — it should print nothing). If a PID survives after a few seconds, escalate only that PID:

```
kill -9 <pid>
```

**4. Clear a leftover lock, if the script now refuses to start** claiming another run holds the lock but you've confirmed nothing is running:

```
rm -rf logs/.task03.lock
```

Since 2026-08-02 this should be rare — the script self-reclaims a stale lock (dead PID) automatically. Manual removal is a fallback only.

**5. Run one clean pass:**

```
./scripts/03_documents_inventory.zsh
```

## Validating a completed Task 03 artifact

```
python3 -c "
import json, csv
with open('inventory/Documents/metadata.json') as f:
    records = json.load(f)
with open('inventory/Documents/metadata.csv', newline='') as f:
    rows = list(csv.DictReader(f))
print('json records:', len(records))
print('csv rows:', len(rows))
print('row count match:', len(records) == len(rows))
print('inventory id:', records[0]['InventoryID'] if records else 'N/A')
"
```

A successful run's own internal validation gate already checks this before publishing (see `QUALITY_GATES.md`); this command is for independent confirmation, e.g. after a manual investigation.

## Verifying the D7 library refactor (one-time, before trusting scripts/03-08 again)

`scripts/03-08` were rewritten as thin wrappers over a new shared `scripts/lib/inventory_engine.zsh` (see `DECISIONS.md` D7). The rewrite was verified structurally (`bash -n`, awk lookup tested against the real config) but never actually executed under zsh before handoff. Confirm it works before relying on it:

1. Run one target you already have a known-good count for, e.g.:
   ```
   ./scripts/03_documents_inventory.zsh
   ```
2. Compare the new `Completed INV-...` line against the last known-good numbers (Documents: 128,305 files / 17,786 directories as of `INV-20260802-013608`). Expect the new count to be very close — small drift is normal (files change), a large or zero count is not.
3. If it fails, the failure mode is safe by design: the validation gate refuses to publish a broken result and leaves the prior artifact in place. You'll see `ERROR: Staged artifact validation failed` rather than corrupted output.
4. Once one target confirms clean, run the rest (`04` through `08`) the same way, one at a time.
5. Report back the `Completed INV-...` lines (or any error) so the docs can be updated and the refactor marked verified in `DECISIONS.md`.

**2026-08-02 update:** step 1 already ran once and found a real bug — `RUN_DIR`/`LOCK_DIR` scoping caused `cleanup: RUN_DIR: parameter not set` and left a stale lock plus two empty staging-dir husks (inventory data itself was correct and validated; only cleanup failed). Fixed in the library (`DECISIONS.md` D7). Before re-testing, clear the leftovers from that run:

```
cd /Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer
rm -rf logs/.task03.lock inventory/Documents/.task03.*
./scripts/03_documents_inventory.zsh
```

This time it should complete with no `cleanup:` error printed. Confirm with:
```
ls logs/.task03.lock inventory/Documents/.task03.* 2>&1
```
Both should report "No such file or directory" once the run finishes cleanly.

## Running the CloudStorage inventory (Task 09, safe mode)

Approved 2026-08-02 (`docs/SAFETY_RULES.md` rule 9; Volumes explicitly deferred, out of scope — operator choice). Runs `run_inventory_task` in safe mode (`DECISIONS.md` D8): Spotlight enrichment forced off, and an extra pre-scan `find` pass counts entries so anything that vanishes between listing and `stat` (evicted cloud placeholder, deleted mid-scan) is reported, not silently dropped.

```
./scripts/09_cloudstorage_inventory.zsh
```

Same lock/staging/validation behavior as every other target — a broken run leaves the prior good artifact untouched. Check the new report's Availability section (`reports/09_cloudstorage_inventory.txt` / `inventory/CloudStorage/summary.md`) for the vanished-entry count; `0` is the expected outcome for a normal run.

Validate the published artifact the same way as any other target, pointing at `inventory/CloudStorage/`:

```
python3 -c "
import json, csv
with open('inventory/CloudStorage/metadata.json') as f:
    records = json.load(f)
with open('inventory/CloudStorage/metadata.csv', newline='') as f:
    rows = list(csv.DictReader(f))
print('json records:', len(records))
print('csv rows:', len(rows))
print('row count match:', len(records) == len(rows))
print('inventory id:', records[0]['InventoryID'] if records else 'N/A')
"
```

## Running the Downloads classification dry run (Task 10)

Approved 2026-08-02 (`DECISIONS.md` D9/D10). Read-only proposal only — reads `inventory/Downloads/metadata.csv`, never rescans the filesystem, performs no move/rename/tag/copy/delete of any file.

**First, clear two stray artifacts left by sandbox verification** (see `DECISIONS.md` D10 — an AI-sandbox `unlink()` limitation, not a real concurrent-run conflict):

```
cd /Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer
rm -rf classification/Downloads/.task10.* logs/.task10.lock
```

Then run:

```
./scripts/10_downloads_classification.zsh
```

Output goes to `classification/Downloads/` (`classification_proposal.csv`, `classification_proposal.json`, `summary.md`) and `reports/10_downloads_classification.txt`. The pipeline's logic was already verified against this same real data from a sandbox scratch location: 161 records, 127 High / 0 Medium / 34 Low confidence, 0 warnings, 0 errors — this run is to confirm the zsh orchestration layer and produce the official, committable artifact. Compare your `Completed CLS-...` line's counts against those numbers; they should match exactly (only the `ClassificationID` and timestamp will differ).

Validate the published artifact:

```
python3 -c "
import json, csv
with open('classification/Downloads/classification_proposal.json') as f:
    records = json.load(f)
with open('classification/Downloads/classification_proposal.csv', newline='') as f:
    rows = list(csv.DictReader(f))
print('json records:', len(records))
print('csv rows:', len(rows))
print('row count match:', len(records) == len(rows))
print('classification id:', records[0]['ClassificationID'] if records else 'N/A')
"
```

## Running classification for the remaining local targets (Tasks 11-15)

Approved 2026-08-02 (`DECISIONS.md` D11). Same guarantees as Task 10: read-only, reads only each target's `inventory/<Target>/metadata.csv`, never rescans the filesystem, no file mutation at any confidence tier.

```
./scripts/11_movies_classification.zsh
./scripts/12_desktop_classification.zsh
./scripts/13_music_classification.zsh
./scripts/14_pictures_classification.zsh
./scripts/15_documents_classification.zsh
```

Documents is the large one (128,380 files) — expect the generation step to take several seconds, not instant like the others. Logic was already verified against this exact data from a sandbox scratch location; your run's counts should match:

| Target | Records | High | Medium | Low |
|---|---|---|---|---|
| Movies | 98 | 49 | 0 | 49 |
| Desktop | 312 | 265 | 5 | 42 |
| Music | 473 | 163 | 13 | 297 |
| Pictures | 17,323 | 11,386 | 2 | 5,935 |
| Documents | 463,774 | 331,495 | 42,321 | 89,958 |

Validate any of them the same way as Downloads, substituting the target name:

```
python3 -c "
import json, csv
target = 'Documents'  # change per target
with open(f'classification/{target}/classification_proposal.json') as f:
    records = json.load(f)
with open(f'classification/{target}/classification_proposal.csv', newline='') as f:
    rows = list(csv.DictReader(f))
print('json records:', len(records))
print('csv rows:', len(rows))
print('row count match:', len(records) == len(rows))
"
```

## Running the Documents classification triage (Task 16)

Approved 2026-08-02 (`DECISIONS.md` D12). Read-only — reads only `classification/Documents/classification_proposal.csv` and `inventory/Documents/{metadata.csv,summary.md}`, never rescans the filesystem, never re-runs classification, performs no file mutation.

```
./scripts/16_documents_triage.zsh
```

Output goes to `review/Documents/` (`EXECUTIVE_SUMMARY.md`, `triage_batches.csv/json`, `triage_assignments.csv/json`) and `reports/16_documents_triage.txt`. A scratch-verified run already produced these exact counts — yours should match (only the `TriageID`/timestamp differ):

| Batch | Files | Total size |
|---|---|---|
| 1 — regeneratable build/cache artifacts | 8,997 | 146,553,591,983 B |
| 2 — largest files (top 50, not in batch 1) | 50 | 8,619,602,903 B |
| 3 — exact duplicate-risk candidates | 42,317 | 724,998,881 B |
| 4 — weak duplicate + stale candidates | 16,920 | 955,547,782 B |
| 5 — low-confidence/ambiguous | 60,096 | 4,153,692,198 B |

Do not commit until you've reviewed `review/Documents/EXECUTIVE_SUMMARY.md` — see `DECISIONS.md` D12.

## Documents Batch 1 remediation (Task 17)

See `REMEDIATION_DESIGN.md`. Move-to-quarantine only — **no deletion**. Dry-run is default.

```
# Dry-run (full Batch 1, or --limit N for a sample proposal)
./scripts/17_documents_batch1_remediation.zsh
./scripts/17_documents_batch1_remediation.zsh --limit 5

# Largest-first CompilationCache sample (dry-run)
./scripts/17_documents_batch1_remediation.zsh --limit 11 --order largest --match CompilationCache.noindex

# Apply requires DECISIONS approval id + limit (pilot pattern)
LIFEOS_REMEDIATION_APPROVED=D20 ./scripts/17_documents_batch1_remediation.zsh --apply --limit 5
LIFEOS_REMEDIATION_APPROVED=D21 ./scripts/17_documents_batch1_remediation.zsh --apply --limit 11 --order largest --match CompilationCache.noindex

# Rollback a completed apply by RemediationID (uses ledgers/<ID>.csv when archived)
./scripts/17_documents_batch1_remediation.zsh --rollback REM-YYYYMMDD-HHMMSS
```

Outputs: `remediation/Documents/{ledger,proposal,summary}` and `reports/17_documents_batch1_remediation.txt`. Quarantine files land under `~/Documents/_LifeOS_Quarantine/<RemediationID>/`.

## Synthetic guard harness

```
./tests/run_synthetic_guards.zsh
```

Runs under `/tmp` only — never touches real user targets. Covers normal inventory, package prune, R10/R11 empty-publish guards, and classification happy path.

## Adding a new inventory target

1. Confirm the target name and path already exist in `config/inventory_targets.yaml` and `inventory/<Target>/` exists (both are already true for all 8 configured targets).
2. Run `./scripts/02_inventory_engine.zsh` and confirm `READY` with 0 failures.
3. Add a thin wrapper script (`scripts/0N_<target>_inventory.zsh`) that sets `PROJECT_DIR`, sources `scripts/lib/inventory_engine.zsh`, and calls `run_inventory_task <TASK_NUM> <TargetName>` — copy the shortest existing wrapper (e.g. `08_music_inventory.zsh`) and change only the header comment and the final `run_inventory_task` call.
4. Only touch `scripts/lib/inventory_engine.zsh` itself if the new target genuinely needs different scan/validation behavior (unlikely for another local folder; likely for CloudStorage/Volumes — see below). A bugfix to the library applies to every target's wrapper at once, so changes there warrant extra care and, ideally, re-running all existing targets afterward to confirm nothing regressed.

External disks and CloudStorage-backed targets require explicit separate approval before this sequence — see `docs/SAFETY_RULES.md`, rule 9. They likely also need engine changes (on-demand download risk, unmount risk) rather than a plain new wrapper — don't assume the existing `run_inventory_task` is sufficient for them without reviewing that first.
