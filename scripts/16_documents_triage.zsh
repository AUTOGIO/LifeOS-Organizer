#!/bin/zsh
# LifeOS Organizer — Task 16
# Read-only triage of the existing Documents classification proposal into 5
# priority review batches. Approved 2026-08-02 (DECISIONS.md D12).
#
# Inputs (both already published, already validated — neither is touched):
#   classification/Documents/classification_proposal.csv
#   inventory/Documents/metadata.csv, inventory/Documents/summary.md
# This script never rescans the filesystem and never re-runs classification.
# It performs no move, rename, tag, copy, or delete of any file, at any
# batch or confidence tier. Output goes only to review/Documents/ and
# reports/16_documents_triage.txt.
#
# Single-target script, not a shared library — only one use case exists
# today (D7's rule-of-three: don't abstract before evidence justifies it).

set -uo pipefail

PROJECT_DIR='/Users/eduardofgiovannini/Documents/GitHub/LifeOS-Organizer'
TARGET_NAME='Documents'
TASK_NUM='16'

CLASSIFICATION_CSV="$PROJECT_DIR/classification/$TARGET_NAME/classification_proposal.csv"
INVENTORY_CSV="$PROJECT_DIR/inventory/$TARGET_NAME/metadata.csv"
INVENTORY_SUMMARY="$PROJECT_DIR/inventory/$TARGET_NAME/summary.md"
OUTPUT_DIR="$PROJECT_DIR/review/$TARGET_NAME"
FINAL_REPORT_PATH="$PROJECT_DIR/reports/${TASK_NUM}_documents_triage.txt"
typeset -g LOCK_DIR="$PROJECT_DIR/logs/.task${TASK_NUM}.lock"

if [[ "$(/bin/pwd -P)" != "$PROJECT_DIR" ]]; then
  print -u2 -- "ERROR: Run this script from $PROJECT_DIR"
  exit 1
fi

for f in "$CLASSIFICATION_CSV" "$INVENTORY_CSV" "$INVENTORY_SUMMARY"; do
  if [[ ! -f "$f" ]]; then
    print -u2 -- "ERROR: Required input not found: $f"
    exit 1
  fi
done

if [[ ! -d "$OUTPUT_DIR" ]]; then
  print -u2 -- "ERROR: $OUTPUT_DIR does not exist. Create it before running this task."
  exit 1
fi

if ! /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
  holder_pid=''
  [[ -f "$LOCK_DIR/pid" ]] && holder_pid="$(<"$LOCK_DIR/pid")"
  if [[ -n "$holder_pid" ]] && /bin/kill -0 "$holder_pid" 2>/dev/null; then
    print -u2 -- "ERROR: Another Task $TASK_NUM run (PID $holder_pid) holds the execution lock ($LOCK_DIR)."
    exit 1
  fi
  print -u2 -- "WARNING: Reclaiming stale execution lock (holder PID '${holder_pid:-unknown}' not running)."
  /bin/rm -rf "$LOCK_DIR"
  /bin/mkdir "$LOCK_DIR" || { print -u2 -- 'ERROR: Cannot acquire execution lock.'; exit 1; }
fi
print -- "$$" > "$LOCK_DIR/pid"

TRIAGE_ID="TRG-$(/bin/date '+%Y%m%d')-$(/bin/date '+%H%M%S')"
typeset -g RUN_DIR
RUN_DIR="$(/usr/bin/mktemp -d "$OUTPUT_DIR/.task${TASK_NUM}.XXXXXX")" || { /bin/rm -rf "$LOCK_DIR"; print -u2 -- 'ERROR: Cannot create staging directory.'; exit 1; }
SUMMARY_PATH="$RUN_DIR/EXECUTIVE_SUMMARY.md"
BATCHES_CSV="$RUN_DIR/triage_batches.csv"
BATCHES_JSON="$RUN_DIR/triage_batches.json"
ASSIGN_CSV="$RUN_DIR/triage_assignments.csv"
ASSIGN_JSON="$RUN_DIR/triage_assignments.json"
STAGED_REPORT_PATH="$RUN_DIR/${TASK_NUM}_documents_triage.txt"
cleanup() { /bin/rm -rf "$RUN_DIR" "$LOCK_DIR"; }
trap cleanup EXIT HUP INT TERM

TIMESTAMP=$(/bin/date '+%Y-%m-%dT%H:%M:%S%z')

gen_output="$(/usr/bin/python3 - "$CLASSIFICATION_CSV" "$INVENTORY_CSV" "$INVENTORY_SUMMARY" "$SUMMARY_PATH" "$BATCHES_CSV" "$BATCHES_JSON" "$ASSIGN_CSV" "$ASSIGN_JSON" "$STAGED_REPORT_PATH" "$TRIAGE_ID" "$TIMESTAMP" "$TARGET_NAME" <<'PY'
import csv, json, re, sys

(classification_csv, inventory_csv, inventory_summary_md,
 out_summary_md, out_batches_csv, out_batches_json,
 out_assign_csv, out_assign_json, out_report,
 triage_id, timestamp, target_name) = sys.argv[1:13]

with open(classification_csv, newline='', encoding='utf-8') as f:
    cls_rows = list(csv.DictReader(f))

cls_ids = set(r['ClassificationID'] for r in cls_rows)
if len(cls_ids) != 1:
    print(f"ERROR: source classification has {len(cls_ids)} distinct ClassificationIDs, expected 1", file=sys.stderr)
    sys.exit(1)
source_classification_id = next(iter(cls_ids))

src_inv_ids = set(r['SourceInventoryID'] for r in cls_rows)
if len(src_inv_ids) != 1:
    print(f"ERROR: classification references {len(src_inv_ids)} distinct SourceInventoryIDs, expected 1", file=sys.stderr)
    sys.exit(1)
source_inventory_id = next(iter(src_inv_ids))

with open(inventory_csv, newline='', encoding='utf-8') as f:
    inv_rows = list(csv.DictReader(f))
inv_ids = set(r['InventoryID'] for r in inv_rows)
if len(inv_ids) != 1 or next(iter(inv_ids)) != source_inventory_id:
    print("ERROR: inventory InventoryID does not match classification's SourceInventoryID", file=sys.stderr)
    sys.exit(1)

size_by_path = {}
for r in inv_rows:
    if r['IsDirectory'] == 'true':
        continue
    try:
        size_by_path[r['FullPath']] = int(r['SizeBytes'])
    except (ValueError, KeyError):
        size_by_path[r['FullPath']] = 0

with open(inventory_summary_md, encoding='utf-8') as f:
    inv_summary = f.read()
m = re.search(r'### Largest Directories\n(.*?)\n\n', inv_summary, re.S)
largest_dirs = []
if m:
    for line in m.group(1).splitlines():
        dm = re.match(r'- (\d+) bytes — (.+)$', line.strip())
        if dm:
            largest_dirs.append((int(dm.group(1)), dm.group(2)))

by_path = {}
for r in cls_rows:
    by_path.setdefault(r['FullPath'], []).append(r)

BUILD_LABEL = 'regeneratable-build-artifact'
DUP_EXACT_LABEL = 'possible-duplicate-candidate'
DUP_WEAK_LABEL = 'same-name-different-size'
STALE_LABELS = {'stale', 'very-stale'}

all_paths_sorted_by_size = sorted(size_by_path.items(), key=lambda kv: -kv[1])
TOP_N_LARGEST_FILES = 50

batch1_paths = set()
for path, recs in by_path.items():
    if any(rc['Dimension'] == 'duplicate-risk' and rc['ProposedLabel'] == BUILD_LABEL for rc in recs):
        batch1_paths.add(path)

largest_file_candidates = [p for p, sz in all_paths_sorted_by_size if p not in batch1_paths][:TOP_N_LARGEST_FILES]
batch2_extra_paths = set(largest_file_candidates)

assignments = []

BATCH_NAMES = {
    1: 'High-confidence regeneratable build/cache artifacts',
    2: 'Largest files (top 50 by size, not already in batch 1)',
    3: 'Exact name+size duplicate-risk candidates (non-build)',
    4: 'Medium-confidence duplicate (weak signal) and stale-file candidates',
    5: 'Low-confidence or ambiguous records',
}

for path, recs in by_path.items():
    labels = {(rc['Dimension'], rc['ProposedLabel']) for rc in recs}
    size = size_by_path.get(path, 0)

    if path in batch1_paths:
        batch = 1
        primary = BUILD_LABEL
        tier = 'High'
    elif path in batch2_extra_paths:
        batch = 2
        primary = 'largest-file'
        tier = next((rc['ConfidenceTier'] for rc in recs if rc['Dimension'] == 'duplicate-risk'), 'High')
    elif ('duplicate-risk', DUP_EXACT_LABEL) in labels:
        batch = 3
        primary = DUP_EXACT_LABEL
        tier = 'Medium'
    elif ('duplicate-risk', DUP_WEAK_LABEL) in labels or any(
        rc['Dimension'] == 'staleness' and rc['ProposedLabel'] in STALE_LABELS for rc in recs
    ):
        batch = 4
        if ('duplicate-risk', DUP_WEAK_LABEL) in labels:
            primary = DUP_WEAK_LABEL
            tier = 'Low'
        else:
            primary = next(rc['ProposedLabel'] for rc in recs if rc['Dimension'] == 'staleness' and rc['ProposedLabel'] in STALE_LABELS)
            tier = 'High'
    else:
        batch = 5
        ft = next((rc for rc in recs if rc['Dimension'] == 'file-type'), None)
        primary = ft['ProposedLabel'] if ft else 'unclassified'
        tier = ft['ConfidenceTier'] if ft else 'Low'

    assignments.append({
        'TriageID': triage_id,
        'SourceClassificationID': source_classification_id,
        'SourceInventoryID': source_inventory_id,
        'TargetName': target_name,
        'FullPath': path,
        'RelativePath': recs[0]['RelativePath'],
        'BatchNumber': batch,
        'BatchName': BATCH_NAMES[batch],
        'PrimaryReason': primary,
        'ConfidenceTier': tier,
        'SizeBytes': size,
    })

batch_stats = {}
for b in range(1, 6):
    items = [a for a in assignments if a['BatchNumber'] == b]
    total_size = sum(a['SizeBytes'] for a in items)
    tiers = {a['ConfidenceTier'] for a in items}
    examples = sorted(items, key=lambda a: -a['SizeBytes'])[:5]
    batch_stats[b] = {
        'BatchNumber': b,
        'BatchName': BATCH_NAMES[b],
        'RecordCount': len(items),
        'TotalSizeBytes': total_size,
        'ConfidenceTiersPresent': sorted(tiers),
        'RequiresReviewMandatory': b not in (1, 2),
        'Examples': [
            {'FullPath': e['FullPath'], 'SizeBytes': e['SizeBytes'], 'PrimaryReason': e['PrimaryReason'], 'ConfidenceTier': e['ConfidenceTier']}
            for e in examples
        ],
    }

WHY = {
    1: 'Deterministic path-pattern match (.build/, CompilationCache.noindex, etc.) plus exact size match across independent project trees. Largest, safest, most impactful signal — these are structurally regeneratable build outputs, not user data.',
    2: 'Highest absolute size impact on disk regardless of classification label. Reviewing the largest items first gives the fastest read on where space actually goes, independent of any heuristic.',
    3: 'Exact Name+SizeBytes match outside a recognized build-cache pattern — the strongest true "these might be the same file" signal this pipeline can produce without content hashing (see RISK_REGISTER R8).',
    4: 'Weaker duplicate signal (same name, different size — possibly different revisions) plus files whose ModificationDate places them in the stale/very-stale staleness buckets for this target\'s thresholds.',
    5: 'No actionable classification signal beyond a plain file-type or project-grouping label (often an unrecognized extension). Lowest priority; safe to review last or skip.',
}

RECOMMENDED_ACTION = {
    1: 'No individual review needed to *identify* these — the pattern match is reliable. Read-only for now: no deletion or regeneration action is authorized in this phase. Worth a future, separately-approved proposal once a remediation phase exists.',
    2: 'Manually skim the top 10-20 by size to confirm nothing here is unexpectedly user-critical (e.g. a real document that happens to be huge) before any future space-reclamation discussion.',
    3: 'Spot-check a sample per RISK_REGISTER R8 — name+size match is a candidate, not proof. A human should open/compare a few pairs before treating any as a confirmed duplicate.',
    4: 'Lower urgency than batch 3. Weak-duplicate entries and stale files are worth a periodic glance, not immediate triage.',
    5: 'Skim only if time permits. Consider whether the file-type lookup table should be extended if a common extension keeps appearing here.',
}

with open(out_batches_csv, 'w', newline='', encoding='utf-8') as f:
    fieldnames = ['BatchNumber', 'BatchName', 'RecordCount', 'TotalSizeBytes', 'WhyPrioritized',
                  'ConfidenceTiersPresent', 'RequiresReviewMandatory', 'RepresentativeExamples', 'RecommendedNextAction']
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    for b in range(1, 6):
        s = batch_stats[b]
        ex_str = '; '.join(f"{e['FullPath']} ({e['SizeBytes']:,}B, {e['PrimaryReason']})" for e in s['Examples'])
        w.writerow({
            'BatchNumber': b,
            'BatchName': s['BatchName'],
            'RecordCount': s['RecordCount'],
            'TotalSizeBytes': s['TotalSizeBytes'],
            'WhyPrioritized': WHY[b],
            'ConfidenceTiersPresent': '/'.join(s['ConfidenceTiersPresent']),
            'RequiresReviewMandatory': s['RequiresReviewMandatory'],
            'RepresentativeExamples': ex_str,
            'RecommendedNextAction': RECOMMENDED_ACTION[b],
        })

batches_json_out = []
for b in range(1, 6):
    s = batch_stats[b]
    batches_json_out.append({**s, 'WhyPrioritized': WHY[b], 'RecommendedNextAction': RECOMMENDED_ACTION[b]})
with open(out_batches_json, 'w', encoding='utf-8') as f:
    json.dump(batches_json_out, f, indent=2)

with open(out_assign_csv, 'w', newline='', encoding='utf-8') as f:
    fieldnames = ['TriageID', 'SourceClassificationID', 'SourceInventoryID', 'TargetName', 'FullPath',
                  'RelativePath', 'BatchNumber', 'BatchName', 'PrimaryReason', 'ConfidenceTier', 'SizeBytes']
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    for a in assignments:
        w.writerow(a)

with open(out_assign_json, 'w', encoding='utf-8') as f:
    json.dump(assignments, f, indent=2)

total_size_all = sum(a['SizeBytes'] for a in assignments)

with open(out_summary_md, 'w', encoding='utf-8') as f:
    f.write("# Documents Classification Triage — Executive Summary\n\n")
    f.write(f"- Triage ID: {triage_id}\n")
    f.write(f"- Source Classification ID: {source_classification_id}\n")
    f.write(f"- Source Inventory ID: {source_inventory_id}\n")
    f.write(f"- Timestamp: {timestamp}\n")
    f.write(f"- Total classified files triaged: {len(assignments)}\n")
    f.write(f"- Total size represented: {total_size_all:,} bytes\n\n")
    f.write("This is a read-only re-organization of the existing Documents classification proposal "
            "(`classification/Documents/`) into five priority batches for human review. No file was "
            "moved, renamed, tagged, copied, deleted, or modified. No filesystem rescan occurred — "
            "input was the already-published classification and inventory artifacts only.\n\n")
    f.write("## Batches\n\n")
    for b in range(1, 6):
        s = batch_stats[b]
        f.write(f"### Batch {b}: {s['BatchName']}\n\n")
        f.write(f"- Record count: {s['RecordCount']:,}\n")
        f.write(f"- Total size: {s['TotalSizeBytes']:,} bytes\n")
        f.write(f"- Why prioritized: {WHY[b]}\n")
        f.write(f"- Confidence tier(s) present: {'/'.join(s['ConfidenceTiersPresent']) or 'n/a'}\n")
        f.write(f"- Human review mandatory: {'Yes' if s['RequiresReviewMandatory'] else 'No (may be proposed automatically; nothing auto-applies)'}\n")
        f.write("- Representative examples:\n")
        for e in s['Examples']:
            f.write(f"  - {e['SizeBytes']:,} bytes — {e['FullPath']} ({e['PrimaryReason']})\n")
        if not s['Examples']:
            f.write("  - None\n")
        f.write(f"- Recommended next action: {RECOMMENDED_ACTION[b]}\n\n")
    f.write("## Largest directories (context, not individually triaged — directories aren't classified)\n\n")
    for sz, path in largest_dirs[:10]:
        f.write(f"- {sz:,} bytes — {path}\n")
    f.write("\n## Validation\n\n")
    f.write(f"- Batch record counts sum to {sum(batch_stats[b]['RecordCount'] for b in range(1,6)):,} "
            f"(expected {len(assignments):,}, the full classified-file count).\n")
    f.write("- Every assignment's FullPath, SourceClassificationID, and SourceInventoryID were cross-checked "
            "against the published `classification/Documents/classification_proposal.csv` and "
            "`inventory/Documents/metadata.csv` — see the embedded validation gate for the automated check.\n\n")
    f.write("---\n")
    f.write(f"Footer: Triage {triage_id} is a read-only re-prioritization. It does not authorize, stage, "
            "or perform any file move, rename, copy, delete, or tag.\n")

with open(out_report, 'w', encoding='utf-8') as f:
    f.write(f"LifeOS Organizer — {target_name} Classification Triage\n")
    f.write(f"Triage ID: {triage_id}\n")
    f.write(f"Source Classification ID: {source_classification_id}\n")
    f.write(f"Source Inventory ID: {source_inventory_id}\n")
    f.write(f"Timestamp: {timestamp}\n")
    f.write(f"Total files triaged: {len(assignments)}\n")
    for b in range(1, 6):
        s = batch_stats[b]
        f.write(f"Batch {b} ({s['BatchName']}): {s['RecordCount']} files, {s['TotalSizeBytes']:,} bytes\n")
    f.write("Safety result: read-only. No file was moved, renamed, tagged, copied, deleted, or modified. "
            "No filesystem rescan occurred.\n")

print(f"Completed {triage_id}: {len(assignments)} files triaged across 5 batches "
      f"({', '.join(str(batch_stats[b]['RecordCount']) for b in range(1,6))}), "
      f"{total_size_all:,} total bytes represented.")
PY
)"
gen_exit=$?
if (( gen_exit != 0 )); then
  print -u2 -- "ERROR: Triage generation failed."
  print -u2 -- "$gen_output"
  exit 1
fi

if ! /usr/bin/python3 - "$BATCHES_CSV" "$BATCHES_JSON" "$ASSIGN_CSV" "$ASSIGN_JSON" "$SUMMARY_PATH" "$STAGED_REPORT_PATH" "$TRIAGE_ID" "$CLASSIFICATION_CSV" "$INVENTORY_CSV" <<'PY'
import csv, json, os, re, sys

(batches_csv, batches_json, assign_csv, assign_json, summary_md, report_path,
 triage_id, classification_csv, inventory_csv) = sys.argv[1:10]

if not re.fullmatch(r"TRG-\d{8}-\d{6}", triage_id):
    raise SystemExit("Invalid Triage ID format")

with open(assign_csv, newline='', encoding='utf-8') as f:
    assign_rows = list(csv.DictReader(f))
with open(assign_json, encoding='utf-8') as f:
    assign_records = json.load(f)
if len(assign_rows) != len(assign_records):
    raise SystemExit(f"assignments CSV/JSON row mismatch: {len(assign_rows)} != {len(assign_records)}")

with open(classification_csv, newline='', encoding='utf-8') as f:
    cls_rows = list(csv.DictReader(f))
cls_paths = set(r['FullPath'] for r in cls_rows)
cls_ids = set(r['ClassificationID'] for r in cls_rows)

# R11 plausibility guard (DECISIONS.md D16): refuse empty triage when the
# source classification has classified file paths. Empty==empty would
# otherwise pass the set-equality check below.
allow_empty = os.environ.get('ALLOW_EMPTY_RESULT', '0') == '1'
if len(cls_paths) > 0 and len(assign_records) == 0 and not allow_empty:
    raise SystemExit(
        f"Plausibility guard: source classification has {len(cls_paths)} unique path(s) but "
        "triage produced 0 assignments. Refusing to publish; previous artifact untouched. "
        "Rerun after fixing generation, or set ALLOW_EMPTY_RESULT=1 to bypass explicitly."
    )
if len(cls_ids) != 1:
    raise SystemExit(f"Source classification has {len(cls_ids)} ClassificationIDs; expected 1")
expected_cls_id = next(iter(cls_ids))

with open(inventory_csv, newline='', encoding='utf-8') as f:
    inv_rows = list(csv.DictReader(f))
inv_file_paths = set(r['FullPath'] for r in inv_rows if r['IsDirectory'] == 'false')

assign_paths = set(a['FullPath'] for a in assign_records)
if assign_paths != cls_paths:
    missing = cls_paths - assign_paths
    extra = assign_paths - cls_paths
    raise SystemExit(f"Assignment path set mismatch: {len(missing)} missing, {len(extra)} extra")

if len(assign_records) != len(cls_paths):
    raise SystemExit(f"Duplicate or missing assignment rows: {len(assign_records)} assignments vs {len(cls_paths)} unique classified files")

for rec in assign_records:
    if rec.get('SourceClassificationID') != expected_cls_id:
        raise SystemExit("Assignment with inconsistent SourceClassificationID")
    if rec.get('TriageID') != triage_id:
        raise SystemExit("Assignment with inconsistent TriageID")
    if int(rec.get('BatchNumber', 0)) not in (1, 2, 3, 4, 5):
        raise SystemExit(f"Invalid BatchNumber: {rec.get('BatchNumber')}")
    if rec['FullPath'] not in inv_file_paths:
        raise SystemExit(f"Assignment references a path not present in source inventory: {rec['FullPath']}")

with open(batches_csv, newline='', encoding='utf-8') as f:
    batch_rows = list(csv.DictReader(f))
if len(batch_rows) != 5:
    raise SystemExit(f"Expected 5 batch summary rows, got {len(batch_rows)}")
total_from_batches = sum(int(r['RecordCount']) for r in batch_rows)
if total_from_batches != len(assign_records):
    raise SystemExit(f"Batch record counts ({total_from_batches}) do not sum to total assignments ({len(assign_records)})")

with open(batches_json, encoding='utf-8') as f:
    batches_json_data = json.load(f)
if len(batches_json_data) != 5:
    raise SystemExit("Expected 5 batch entries in JSON")

for path in (summary_md, report_path):
    with open(path, encoding='utf-8') as f:
        if triage_id not in f.read():
            raise SystemExit(f"Missing Triage ID in {path}")

print("VALIDATE_OK")
PY
then
  print -u2 -- 'ERROR: Staged triage artifact validation failed; no output was published.'
  exit 1
fi

/bin/mv "$SUMMARY_PATH" "$OUTPUT_DIR/EXECUTIVE_SUMMARY.md" || exit 1
/bin/mv "$BATCHES_CSV" "$OUTPUT_DIR/triage_batches.csv" || exit 1
/bin/mv "$BATCHES_JSON" "$OUTPUT_DIR/triage_batches.json" || exit 1
/bin/mv "$ASSIGN_CSV" "$OUTPUT_DIR/triage_assignments.csv" || exit 1
/bin/mv "$ASSIGN_JSON" "$OUTPUT_DIR/triage_assignments.json" || exit 1
/bin/mv "$STAGED_REPORT_PATH" "$FINAL_REPORT_PATH" || exit 1
print -- "$gen_output"
exit 0
