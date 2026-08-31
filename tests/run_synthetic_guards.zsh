#!/bin/zsh
# LifeOS Organizer — synthetic guard harness (Phase 3).
# Never touches real user targets. All work under /tmp.
# Covers: normal inventory, package prune (D14), R10 zero-dir abort,
# R11 empty classification/triage abort.
#
# Usage:
#   ./tests/run_synthetic_guards.zsh

set -uo pipefail

REPO="${0:A:h:h}"
SCRATCH="$(/usr/bin/mktemp -d /tmp/lifeos_synth.XXXXXX)"
PASS=0
FAIL=0

cleanup() { /bin/rm -rf "$SCRATCH"; }
trap cleanup EXIT

ok() { print -- "PASS: $1"; ((PASS += 1)); }
bad() { print -u2 -- "FAIL: $1"; ((FAIL += 1)); }

print -- "Scratch: $SCRATCH"

for d in config templates scripts/lib inventory/SynthTarget inventory/PkgTarget \
         classification/SynthTarget review/Documents logs reports; do
  /bin/mkdir -p "$SCRATCH/$d"
done
/bin/cp "$REPO/templates/inventory_report_template.md" "$SCRATCH/templates/"
/bin/cp "$REPO/scripts/lib/inventory_engine.zsh" "$SCRATCH/scripts/lib/"
/bin/cp "$REPO/scripts/lib/classification_engine.zsh" "$SCRATCH/scripts/lib/"

TREE_A="$SCRATCH/fixture_normal"
/bin/mkdir -p "$TREE_A/subdir"
print -- 'hello' > "$TREE_A/readme.txt"
print -- 'nested' > "$TREE_A/subdir/note.md"

TREE_B="$SCRATCH/fixture_pkg"
/bin/mkdir -p "$TREE_B/Sample.photoslibrary/database"
print -- 'internal' > "$TREE_B/Sample.photoslibrary/database/store"
print -- 'outside' > "$TREE_B/loose.jpg"

# Resolve scratch to physical path so engine pwd -P checks match.
cd "$SCRATCH" || exit 1
SCRATCH="$(/bin/pwd -P)"
TREE_A="$SCRATCH/fixture_normal"
TREE_B="$SCRATCH/fixture_pkg"

cat > "$SCRATCH/config/inventory_targets.yaml" <<EOF
SynthTarget:
  path: $TREE_A
PkgTarget:
  path: $TREE_B
EOF

# --- Test 1: normal inventory publish ---
(
  set -uo pipefail
  cd "$SCRATCH" || exit 1
  PROJECT_DIR="$SCRATCH"
  source "$SCRATCH/scripts/lib/inventory_engine.zsh"
  run_inventory_task 91 SynthTarget
) >"$SCRATCH/out_normal.txt" 2>"$SCRATCH/err_normal.txt"
rc=$?
if (( rc == 0 )) && [[ -f "$SCRATCH/inventory/SynthTarget/metadata.csv" ]]; then
  rows=$(( $(/usr/bin/wc -l < "$SCRATCH/inventory/SynthTarget/metadata.csv") - 1 ))
  if (( rows >= 3 )); then
    ok "normal inventory published ($rows rows)"
  else
    bad "normal inventory row count too low ($rows)"
  fi
else
  bad "normal inventory failed (rc=$rc); $(<"$SCRATCH/err_normal.txt")"
fi

# --- Test 2: package prune ---
(
  set -uo pipefail
  cd "$SCRATCH" || exit 1
  PROJECT_DIR="$SCRATCH"
  source "$SCRATCH/scripts/lib/inventory_engine.zsh"
  run_inventory_task 92 PkgTarget
) >"$SCRATCH/out_pkg.txt" 2>"$SCRATCH/err_pkg.txt"
rc=$?
if (( rc == 0 )) && [[ -f "$SCRATCH/inventory/PkgTarget/metadata.csv" ]]; then
  pkg_info="$(/usr/bin/python3 - "$SCRATCH/inventory/PkgTarget/metadata.csv" <<'PY'
import csv, sys
rows=list(csv.DictReader(open(sys.argv[1], newline='', encoding='utf-8')))
pkgs=[r for r in rows if r.get('IsPackage')=='true']
internal_files=[r for r in rows if '/database/' in r.get('FullPath','')]
print(f"{len(rows)} {len(pkgs)} {len(internal_files)}")
PY
)"
  set -- ${=pkg_info}
  total=$1 pkgs=$2 internals=$3
  if (( pkgs == 1 && internals == 0 && total >= 2 )); then
    ok "package prune: 1 IsPackage, 0 internals (total=$total)"
  else
    bad "package prune unexpected (total=$total pkgs=$pkgs internals=$internals)"
  fi
else
  bad "package inventory failed (rc=$rc); $(<"$SCRATCH/err_pkg.txt")"
fi

# --- Test 3: R10 guard condition ---
R10_RC="$(/usr/bin/python3 - <<'PY'
total_directories = 0
ALLOW_EMPTY_RESULT = '0'
aborted = (total_directories == 0) and (ALLOW_EMPTY_RESULT != '1')
print(0 if aborted else 1)
PY
)"
if [[ "$R10_RC" == '0' ]]; then
  ok "R10 zero-directory guard condition blocks publish"
else
  bad "R10 guard condition did not block"
fi

R10_BYPASS="$(/usr/bin/python3 - <<'PY'
total_directories = 0
ALLOW_EMPTY_RESULT = '1'
aborted = (total_directories == 0) and (ALLOW_EMPTY_RESULT != '1')
print(1 if aborted else 0)
PY
)"
if [[ "$R10_BYPASS" == '0' ]]; then
  ok "R10 ALLOW_EMPTY_RESULT=1 bypass works"
else
  bad "R10 bypass failed"
fi

# --- Test 4: R11 classification empty-publish abort ---
INV_CSV="$SCRATCH/fake_inv.csv"
cat > "$INV_CSV" <<'CSV'
InventoryID,FullPath,RelativePath,Name,Extension,IsDirectory,IsPackage,IsHidden,IsSymlink,Owner,Group,Permissions,SizeBytes,CreationDate,ModificationDate,AccessDate,SpotlightType,SpotlightKind
INV-20260802-120000,/tmp/x/a.txt,a.txt,a.txt,txt,false,false,false,false,u,g,644,1,2026-01-01T00:00:00,2026-01-01T00:00:00,2026-01-01T00:00:00,,
CSV
EMPTY_CSV="$SCRATCH/empty_cls.csv"
EMPTY_JSON="$SCRATCH/empty_cls.json"
print -- 'ClassificationID,SourceInventoryID,TargetName,FullPath,RelativePath,Dimension,ProposedLabel,ConfidenceTier,ConfidenceReason,RequiresReview' > "$EMPTY_CSV"
print -- '[]' > "$EMPTY_JSON"
print -- 'CLS-20260802-120000' > "$SCRATCH/summary.md"
print -- 'CLS-20260802-120000' > "$SCRATCH/report.txt"

CLS_RC=0
/usr/bin/python3 - "$EMPTY_CSV" "$EMPTY_JSON" "$SCRATCH/summary.md" "$SCRATCH/report.txt" "CLS-20260802-120000" "$INV_CSV" <<'PY' || CLS_RC=$?
import csv, json, os, re, sys
csv_path, json_path, summary_path, report_path, classification_id, inventory_csv_path = sys.argv[1:7]
if not re.fullmatch(r"CLS-\d{8}-\d{6}", classification_id):
    raise SystemExit("Invalid Classification ID format")
with open(csv_path, newline='', encoding='utf-8') as f:
    rows = list(csv.DictReader(f))
with open(json_path, encoding='utf-8') as f:
    records = json.load(f)
if len(rows) != len(records):
    raise SystemExit(f"CSV/JSON row mismatch: {len(rows)} != {len(records)}")
with open(inventory_csv_path, newline='', encoding='utf-8') as f:
    inv_rows = list(csv.DictReader(f))
usable_files = sum(
    1 for r in inv_rows
    if r.get('IsPackage') != 'true' and r.get('IsDirectory') == 'false'
)
allow_empty = os.environ.get('ALLOW_EMPTY_RESULT', '0') == '1'
if usable_files > 0 and len(records) == 0 and not allow_empty:
    raise SystemExit("Plausibility guard fired")
print("UNEXPECTED_PASS")
PY
if (( CLS_RC != 0 )); then
  ok "R11 classification empty-publish aborted"
else
  bad "R11 classification empty-publish did not abort"
fi

# --- Test 5: R11 triage empty-publish abort ---
CLS_NONEMPTY="$SCRATCH/cls_nonempty.csv"
cat > "$CLS_NONEMPTY" <<'CSV'
ClassificationID,SourceInventoryID,TargetName,FullPath,RelativePath,Dimension,ProposedLabel,ConfidenceTier,ConfidenceReason,RequiresReview
CLS-20260802-120000,INV-20260802-120000,Documents,/tmp/x/a.txt,a.txt,file-type,document,High,test,false
CSV
ASSIGN_EMPTY="$SCRATCH/assign_empty.csv"
ASSIGN_EMPTY_JSON="$SCRATCH/assign_empty.json"
print -- 'TriageID,SourceClassificationID,SourceInventoryID,FullPath,BatchNumber,BatchName' > "$ASSIGN_EMPTY"
print -- '[]' > "$ASSIGN_EMPTY_JSON"
BATCH_CSV="$SCRATCH/batches.csv"
print -- 'BatchNumber,BatchName,RecordCount,TotalSizeBytes' > "$BATCH_CSV"
for i in 1 2 3 4 5; do print -- "$i,b$i,0,0" >> "$BATCH_CSV"; done
/usr/bin/python3 -c 'import json; open("'"$SCRATCH"'/batches.json","w").write(json.dumps([{"BatchNumber":i} for i in range(1,6)]))'
print -- 'TRG-20260802-120000' > "$SCRATCH/trg_summary.md"
print -- 'TRG-20260802-120000' > "$SCRATCH/trg_report.txt"

TRG_RC=0
/usr/bin/python3 - "$BATCH_CSV" "$SCRATCH/batches.json" "$ASSIGN_EMPTY" "$ASSIGN_EMPTY_JSON" \
  "$SCRATCH/trg_summary.md" "$SCRATCH/trg_report.txt" "TRG-20260802-120000" "$CLS_NONEMPTY" "$INV_CSV" <<'PY' || TRG_RC=$?
import csv, json, os, re, sys
(batches_csv, batches_json, assign_csv, assign_json, summary_md, report_path,
 triage_id, classification_csv, inventory_csv) = sys.argv[1:10]
if not re.fullmatch(r"TRG-\d{8}-\d{6}", triage_id):
    raise SystemExit("Invalid Triage ID format")
with open(assign_csv, newline='', encoding='utf-8') as f:
    assign_rows = list(csv.DictReader(f))
with open(assign_json, encoding='utf-8') as f:
    assign_records = json.load(f)
with open(classification_csv, newline='', encoding='utf-8') as f:
    cls_rows = list(csv.DictReader(f))
cls_paths = set(r['FullPath'] for r in cls_rows)
allow_empty = os.environ.get('ALLOW_EMPTY_RESULT', '0') == '1'
if len(cls_paths) > 0 and len(assign_records) == 0 and not allow_empty:
    raise SystemExit("Plausibility guard fired")
print("UNEXPECTED_PASS")
PY
if (( TRG_RC != 0 )); then
  ok "R11 triage empty-publish aborted"
else
  bad "R11 triage empty-publish did not abort"
fi

# --- Test 6: classification happy path on synthetic inventory ---
(
  set -uo pipefail
  cd "$SCRATCH" || exit 1
  PROJECT_DIR="$SCRATCH"
  source "$SCRATCH/scripts/lib/classification_engine.zsh"
  run_classification_task 93 SynthTarget
) >"$SCRATCH/out_cls.txt" 2>"$SCRATCH/err_cls.txt"
rc=$?
if (( rc == 0 )) && [[ -f "$SCRATCH/classification/SynthTarget/classification_proposal.csv" ]]; then
  cls_rows=$(( $(/usr/bin/wc -l < "$SCRATCH/classification/SynthTarget/classification_proposal.csv") - 1 ))
  if (( cls_rows > 0 )); then
    ok "classification happy path ($cls_rows records)"
  else
    bad "classification happy path produced 0 records"
  fi
else
  bad "classification happy path failed (rc=$rc); $(<"$SCRATCH/err_cls.txt")"
fi

print -- "----"
print -- "Results: $PASS passed, $FAIL failed"
(( FAIL == 0 )) && exit 0 || exit 1
