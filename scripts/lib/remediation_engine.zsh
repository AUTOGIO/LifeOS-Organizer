# LifeOS Organizer — Shared Remediation Engine
# Sourced by scripts/17_documents_batch1_remediation.zsh.
# Move-to-quarantine only. No deletion. Dry-run by default.
# See REMEDIATION_DESIGN.md and DECISIONS.md D18/D19.
#
# Requires PROJECT_DIR to already be set by the sourcing script.

QUARANTINE_BASE="${QUARANTINE_BASE:-/Users/eduardofgiovannini/Documents/_LifeOS_Quarantine}"

# run_documents_batch1_remediation [--apply] [--limit N] [--rollback REM-ID]
run_documents_batch1_remediation() {
  local DO_APPLY=0
  local LIMIT=0
  local ROLLBACK_ID=''
  local ApprovalRef="${LIFEOS_REMEDIATION_APPROVED:-}"

  while (( $# > 0 )); do
    case "$1" in
      --apply) DO_APPLY=1; shift ;;
      --limit)
        LIMIT="$2"
        shift 2
        ;;
      --rollback)
        ROLLBACK_ID="$2"
        shift 2
        ;;
      *)
        print -u2 -- "ERROR: Unknown argument: $1"
        return 1
        ;;
    esac
  done

  local TASK_NUM='17'
  local TARGET_NAME='Documents'
  local OUTPUT_DIR="$PROJECT_DIR/remediation/$TARGET_NAME"
  local TRIAGE_CSV="$PROJECT_DIR/review/$TARGET_NAME/triage_assignments.csv"
  local FINAL_REPORT="$PROJECT_DIR/reports/${TASK_NUM}_documents_batch1_remediation.txt"
  typeset -g LOCK_DIR="$PROJECT_DIR/logs/.task${TASK_NUM}.lock"

  if [[ "$(/bin/pwd -P)" != "$PROJECT_DIR" ]]; then
    print -u2 -- "ERROR: Run this script from $PROJECT_DIR"
    return 1
  fi

  if [[ ! -d "$OUTPUT_DIR" ]]; then
    print -u2 -- "ERROR: $OUTPUT_DIR does not exist."
    return 1
  fi

  if ! /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
    local holder_pid=''
    [[ -f "$LOCK_DIR/pid" ]] && holder_pid="$(<"$LOCK_DIR/pid")"
    if [[ -n "$holder_pid" ]] && /bin/kill -0 "$holder_pid" 2>/dev/null; then
      print -u2 -- "ERROR: Another Task $TASK_NUM run (PID $holder_pid) holds the lock."
      return 1
    fi
    print -u2 -- "WARNING: Reclaiming stale execution lock."
    /bin/rm -rf "$LOCK_DIR"
    /bin/mkdir "$LOCK_DIR" || { print -u2 -- 'ERROR: Cannot acquire lock.'; return 1; }
  fi
  print -- "$$" > "$LOCK_DIR/pid"

  typeset -g RUN_DIR
  RUN_DIR="$(/usr/bin/mktemp -d "$OUTPUT_DIR/.task${TASK_NUM}.XXXXXX")" || {
    /bin/rm -rf "$LOCK_DIR"
    print -u2 -- 'ERROR: Cannot create staging directory.'
    return 1
  }
  cleanup() { /bin/rm -rf "$RUN_DIR" "$LOCK_DIR"; }
  trap cleanup EXIT HUP INT TERM

  # --- Rollback mode ---
  if [[ -n "$ROLLBACK_ID" ]]; then
    local LEDGER_CSV="$OUTPUT_DIR/ledger.csv"
    if [[ ! -f "$LEDGER_CSV" ]]; then
      print -u2 -- "ERROR: No ledger at $LEDGER_CSV"
      return 1
    fi
    local rb_out
    rb_out="$(/usr/bin/python3 - "$LEDGER_CSV" "$ROLLBACK_ID" "$RUN_DIR/rollback_report.txt" <<'PY'
import csv, os, shutil, sys

ledger_path, rem_id, report_path = sys.argv[1:4]
rows = list(csv.DictReader(open(ledger_path, newline='', encoding='utf-8')))
targets = [r for r in rows if r['RemediationID'] == rem_id and r['Status'] == 'applied']
if not targets:
    print(f"ERROR: No applied rows for {rem_id}", file=sys.stderr)
    sys.exit(1)

restored = 0
failed = 0
errors = []
for r in targets:
    src = r['ProposedNewPath']
    dst = r['OriginalFullPath']
    if not os.path.exists(src):
        errors.append(f"missing quarantine file: {src}")
        failed += 1
        continue
    if os.path.exists(dst):
        errors.append(f"original path occupied, refuse overwrite: {dst}")
        failed += 1
        continue
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    try:
        shutil.move(src, dst)
        r['Status'] = 'rolled_back'
        restored += 1
    except Exception as e:
        errors.append(f"{src}: {e}")
        failed += 1

# Rewrite ledger with updated statuses
fieldnames = list(rows[0].keys())
with open(ledger_path, 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    w.writerows(rows)

with open(report_path, 'w', encoding='utf-8') as f:
    f.write(f"Rollback of {rem_id}\n")
    f.write(f"Restored: {restored}\nFailed: {failed}\n")
    for e in errors:
        f.write(f"ERROR: {e}\n")

if failed:
    print(f"ROLLBACK_PARTIAL restored={restored} failed={failed}", file=sys.stderr)
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
print(f"ROLLBACK_OK restored={restored}")
PY
)"
    local rb_rc=$?
    if (( rb_rc != 0 )); then
      print -u2 -- "ERROR: Rollback failed."
      print -u2 -- "$rb_out"
      return 1
    fi
    /bin/mv "$RUN_DIR/rollback_report.txt" "$FINAL_REPORT" 2>/dev/null || true
    print -- "$rb_out"
    return 0
  fi

  # --- Dry-run / apply ---
  if [[ ! -f "$TRIAGE_CSV" ]]; then
    print -u2 -- "ERROR: Missing triage assignments: $TRIAGE_CSV"
    return 1
  fi

  if (( DO_APPLY == 1 )); then
    if [[ -z "$ApprovalRef" ]]; then
      print -u2 -- "ERROR: --apply requires LIFEOS_REMEDIATION_APPROVED=<DECISIONS id> (e.g. D19)."
      return 1
    fi
    if (( LIMIT <= 0 )); then
      print -u2 -- "ERROR: First apply pilots require --limit N (>0). Refusing unbounded apply."
      return 1
    fi
  fi

  local REMEDIATION_ID="REM-$(/bin/date '+%Y%m%d')-$(/bin/date '+%H%M%S')"
  local TIMESTAMP=$(/bin/date '+%Y-%m-%dT%H:%M:%S%z')
  local QROOT="$QUARANTINE_BASE/$REMEDIATION_ID"
  local LEDGER_CSV="$RUN_DIR/ledger.csv"
  local LEDGER_JSON="$RUN_DIR/ledger.json"
  local PROPOSAL_CSV="$RUN_DIR/proposal.csv"
  local SUMMARY_PATH="$RUN_DIR/summary.md"
  local STAGED_REPORT="$RUN_DIR/${TASK_NUM}_documents_batch1_remediation.txt"

  local gen_out
  gen_out="$(/usr/bin/python3 - "$TRIAGE_CSV" "$LEDGER_CSV" "$LEDGER_JSON" "$PROPOSAL_CSV" \
    "$SUMMARY_PATH" "$STAGED_REPORT" "$REMEDIATION_ID" "$TIMESTAMP" "$QROOT" \
    "$LIMIT" "$DO_APPLY" "$ApprovalRef" "$QUARANTINE_BASE" <<'PY'
import csv, json, os, shutil, sys

(triage_csv, ledger_csv, ledger_json, proposal_csv, summary_md, report_path,
 rem_id, timestamp, qroot, limit_s, do_apply_s, approval_ref, qbase) = sys.argv[1:14]

limit = int(limit_s)
do_apply = do_apply_s == '1'

with open(triage_csv, newline='', encoding='utf-8') as f:
    all_rows = list(csv.DictReader(f))

batch1 = [r for r in all_rows if str(r.get('BatchNumber')) == '1']
if not batch1:
    print("ERROR: No Batch 1 rows in triage assignments", file=sys.stderr)
    sys.exit(1)

triage_ids = set(r['TriageID'] for r in batch1)
cls_ids = set(r['SourceClassificationID'] for r in batch1)
inv_ids = set(r['SourceInventoryID'] for r in batch1)
if len(triage_ids) != 1 or len(cls_ids) != 1 or len(inv_ids) != 1:
    print("ERROR: Batch 1 references inconsistent upstream IDs", file=sys.stderr)
    sys.exit(1)
source_triage_id = next(iter(triage_ids))
source_cls_id = next(iter(cls_ids))
source_inv_id = next(iter(inv_ids))

# Prefer smallest files for safe pilots
def size_of(r):
    try:
        return int(r.get('SizeBytes') or 0)
    except ValueError:
        return 0

batch1.sort(key=size_of)
if limit > 0:
    selected = batch1[:limit]
else:
    selected = batch1

docs_root = '/Users/eduardofgiovannini/Documents'
qbase_real = os.path.realpath(qbase)
records = []
for r in selected:
    original = r['FullPath']
    if not original.startswith(docs_root + os.sep) and original != docs_root:
        print(f"ERROR: Path outside Documents: {original}", file=sys.stderr)
        sys.exit(1)
    rel = original[len(docs_root):].lstrip('/')
    proposed = os.path.join(qroot, rel)
    if not (proposed.startswith(qroot + os.sep) or proposed == qroot):
        print(f"ERROR: Proposed path escapes quarantine: {proposed}", file=sys.stderr)
        sys.exit(1)
    if not proposed.startswith(qbase + os.sep) and not proposed.startswith(os.path.realpath(qbase) + os.sep):
        # Soft check: qroot is under qbase by construction
        if not qroot.startswith(qbase):
            print(f"ERROR: Quarantine root outside base: {qroot}", file=sys.stderr)
            sys.exit(1)
    records.append({
        'RemediationID': rem_id,
        'SourceTriageID': source_triage_id,
        'SourceClassificationID': source_cls_id,
        'SourceInventoryID': source_inv_id,
        'OriginalFullPath': original,
        'ProposedNewPath': proposed,
        'Action': 'move',
        'Timestamp': timestamp,
        'ApprovalRef': approval_ref if do_apply else '',
        'Status': 'proposed',
        'SizeBytes': str(size_of(r)),
    })

allow_empty = os.environ.get('ALLOW_EMPTY_RESULT', '0') == '1'
if len(batch1) > 0 and len(records) == 0 and not allow_empty:
    print("ERROR: Plausibility guard: Batch 1 non-empty but 0 proposals", file=sys.stderr)
    sys.exit(1)

# Write proposal/ledger before any mutation
fieldnames = list(records[0].keys()) if records else [
    'RemediationID', 'SourceTriageID', 'SourceClassificationID', 'SourceInventoryID',
    'OriginalFullPath', 'ProposedNewPath', 'Action', 'Timestamp', 'ApprovalRef', 'Status', 'SizeBytes'
]
for path in (ledger_csv, proposal_csv):
    with open(path, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(records)
with open(ledger_json, 'w', encoding='utf-8') as f:
    json.dump(records, f, indent=2)

applied = 0
failed = 0
errors = []
if do_apply:
    os.makedirs(qroot, exist_ok=True)
    for rec in records:
        src = rec['OriginalFullPath']
        dst = rec['ProposedNewPath']
        if not os.path.exists(src):
            rec['Status'] = 'failed'
            failed += 1
            errors.append(f"missing source: {src}")
            continue
        if os.path.exists(dst):
            rec['Status'] = 'failed'
            failed += 1
            errors.append(f"destination exists: {dst}")
            continue
        # Final containment
        real_dst_parent = os.path.realpath(os.path.dirname(dst))
        # dirname may not exist yet
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        real_dst_parent = os.path.realpath(os.path.dirname(dst))
        if not real_dst_parent.startswith(os.path.realpath(qroot)):
            rec['Status'] = 'failed'
            failed += 1
            errors.append(f"escape quarantine: {dst}")
            continue
        try:
            shutil.move(src, dst)
            rec['Status'] = 'applied'
            applied += 1
        except Exception as e:
            rec['Status'] = 'failed'
            failed += 1
            errors.append(f"{src}: {e}")
    # Rewrite ledger with statuses
    with open(ledger_csv, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(records)
    with open(ledger_json, 'w', encoding='utf-8') as f:
        json.dump(records, f, indent=2)

mode = 'APPLY' if do_apply else 'DRY-RUN'
total_bytes = sum(int(r['SizeBytes']) for r in records)
with open(summary_md, 'w', encoding='utf-8') as f:
    f.write(f"# Remediation Summary — Documents Batch 1 ({mode})\n\n")
    f.write(f"- Remediation ID: {rem_id}\n")
    f.write(f"- Source Triage ID: {source_triage_id}\n")
    f.write(f"- Source Classification ID: {source_cls_id}\n")
    f.write(f"- Source Inventory ID: {source_inv_id}\n")
    f.write(f"- Timestamp: {timestamp}\n")
    f.write(f"- Quarantine root: {qroot}\n")
    f.write(f"- Proposed moves: {len(records)}\n")
    f.write(f"- Total size (bytes): {total_bytes:,}\n")
    f.write(f"- ApprovalRef: {approval_ref or '(none — dry-run)'}\n")
    if do_apply:
        f.write(f"- Applied: {applied}\n- Failed: {failed}\n")
    f.write("\n## Safety\n\n- Action is move-to-quarantine only. No deletion.\n")
    f.write("- Rollback via: `./scripts/17_documents_batch1_remediation.zsh --rollback " + rem_id + "`\n")
    if errors:
        f.write("\n## Errors\n")
        for e in errors:
            f.write(f"- {e}\n")

with open(report_path, 'w', encoding='utf-8') as f:
    f.write(f"LifeOS Organizer — Documents Batch 1 Remediation ({mode})\n")
    f.write(f"Remediation ID: {rem_id}\n")
    f.write(f"Proposed: {len(records)}  Applied: {applied}  Failed: {failed}\n")
    f.write(f"Quarantine: {qroot}\n")
    f.write(f"ApprovalRef: {approval_ref or '(none)'}\n")
    f.write("No deletion capability invoked.\n")

if do_apply and failed:
    print(f"APPLY_PARTIAL rem={rem_id} applied={applied} failed={failed}", file=sys.stderr)
    for e in errors:
        print(e, file=sys.stderr)
    # Still publish ledger so partial apply is recoverable
else:
    print(f"Completed {rem_id} ({mode}): {len(records)} proposed, {applied} applied, {failed} failed, {total_bytes} bytes.")
PY
)"
  local gen_rc=$?
  if (( gen_rc != 0 )); then
    print -u2 -- "ERROR: Remediation generation/apply failed."
    print -u2 -- "$gen_out"
    return 1
  fi

  # Validate staged ledger
  if ! /usr/bin/python3 - "$LEDGER_CSV" "$LEDGER_JSON" "$SUMMARY_PATH" "$STAGED_REPORT" \
    "$REMEDIATION_ID" "$TRIAGE_CSV" "$QUARANTINE_BASE" <<'PY'
import csv, json, os, re, sys
ledger_csv, ledger_json, summary, report, rem_id, triage_csv, qbase = sys.argv[1:8]
if not re.fullmatch(r"REM-\d{8}-\d{6}", rem_id):
    raise SystemExit("Invalid RemediationID")
rows = list(csv.DictReader(open(ledger_csv, newline='', encoding='utf-8')))
recs = json.load(open(ledger_json, encoding='utf-8'))
if len(rows) != len(recs):
    raise SystemExit("CSV/JSON mismatch")
batch1_paths = set()
with open(triage_csv, newline='', encoding='utf-8') as f:
    for r in csv.DictReader(f):
        if str(r.get('BatchNumber')) == '1':
            batch1_paths.add(r['FullPath'])
allow_empty = os.environ.get('ALLOW_EMPTY_RESULT', '0') == '1'
if len(batch1_paths) > 0 and len(rows) == 0 and not allow_empty:
    raise SystemExit("Plausibility: empty ledger but Batch 1 non-empty")
qbase_real = os.path.realpath(qbase)
for r in rows:
    if r.get('RemediationID') != rem_id:
        raise SystemExit("Inconsistent RemediationID")
    if r.get('Action') != 'move':
        raise SystemExit("Non-move action forbidden")
    if r['OriginalFullPath'] not in batch1_paths:
        raise SystemExit(f"Path not in Batch 1: {r['OriginalFullPath']}")
    prop = r['ProposedNewPath']
    if f"/{rem_id}/" not in prop.replace('\\', '/'):
        raise SystemExit(f"Proposed path missing RemediationID segment: {prop}")
    if not prop.startswith(qbase):
        raise SystemExit(f"Proposed path outside quarantine base: {prop}")
for path in (summary, report):
    if rem_id not in open(path, encoding='utf-8').read():
        raise SystemExit(f"Missing RemediationID in {path}")
print("VALIDATE_OK")
PY
  then
    print -u2 -- 'ERROR: Staged remediation validation failed; nothing published.'
    return 1
  fi

  /bin/mv "$LEDGER_CSV" "$OUTPUT_DIR/ledger.csv" || return 1
  /bin/mv "$LEDGER_JSON" "$OUTPUT_DIR/ledger.json" || return 1
  /bin/mv "$PROPOSAL_CSV" "$OUTPUT_DIR/proposal.csv" || return 1
  /bin/mv "$SUMMARY_PATH" "$OUTPUT_DIR/summary.md" || return 1
  /bin/mv "$STAGED_REPORT" "$FINAL_REPORT" || return 1
  print -- "$gen_out"
}
