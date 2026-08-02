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
```

Run `02_inventory_engine.zsh` before any new target's first inventory run — it fails fast on missing config, missing staging directories, or a target path that no longer exists.

`03_documents_inventory.zsh` takes minutes to over an hour on a full Documents tree (prior runs: 586s–3915s). Run it in a terminal session you intend to keep open; do not background it and forget about it — that is exactly how the 2026-08-01 incident happened (see `RISK_REGISTER.md`).

Optional Spotlight enrichment (adds runtime, off by default):

```
COLLECT_SPOTLIGHT=1 ./scripts/03_documents_inventory.zsh
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

1. Add the target name and path to `config/inventory_targets.yaml`.
2. Create `inventory/<Target>/`.
3. Run `./scripts/02_inventory_engine.zsh` and confirm `READY` with 0 failures.
4. Write or reuse a task script following the pattern in `SYSTEM_ARCHITECTURE.md` (stage → scan → validate → publish → release lock).

External disks and CloudStorage-backed targets require explicit separate approval before this sequence — see `docs/SAFETY_RULES.md`, rule 9.
