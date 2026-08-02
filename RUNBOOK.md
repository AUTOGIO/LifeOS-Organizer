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

## Adding a new inventory target

1. Confirm the target name and path already exist in `config/inventory_targets.yaml` and `inventory/<Target>/` exists (both are already true for all 8 configured targets).
2. Run `./scripts/02_inventory_engine.zsh` and confirm `READY` with 0 failures.
3. Clone the most recently added target script (as of this writing, `scripts/04_desktop_inventory.zsh`, cloned from `03_documents_inventory.zsh`) rather than writing from scratch. Change only: the header comment, `TARGET_NAME`, `REPORT_PATH`, `LOCK_DIR`, the `mktemp` template suffix, the awk match string (`$0 == "<Target>:"`), the two user-facing "Configured `<Target>`" / "Another Task N" error strings, and the report title strings. Everything else — locking, staging, validation, atomic publish — stays identical. This is deliberate (`DECISIONS.md` D7): don't parameterize into a shared script until at least three targets are proven identical in practice.
4. Diff the new script against its parent before running it for the first time — every changed line should be explainable as one of the six items above. Any other difference is a mistake, not a feature.

External disks and CloudStorage-backed targets require explicit separate approval before this sequence — see `docs/SAFETY_RULES.md`, rule 9.
