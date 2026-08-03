# LifeOS Organizer — Shared Classification Engine
# Sourced by scripts/1N_<target>_classification.zsh wrapper scripts. Defines
# functions only — never executed directly, no shebang. Mirrors the
# inventory engine's proven architecture (scripts/lib/inventory_engine.zsh,
# DECISIONS.md D1/D5-D7): mkdir execution lock, mktemp -d staging, a
# generation step, a separate validation step, atomic publish, EXIT-trap
# cleanup with -g-declared trap state (D7 taught this project why that
# scoping matters — see that file's run_inventory_task header comment).
#
# Structural guarantee: this engine's Python generation step opens exactly
# one input file — inventory/<Target>/metadata.csv, already published and
# validated by the inventory phase. It never calls find, stat, mdls, or any
# filesystem-walking primitive, and it never opens a write handle to
# anything outside classification/<Target>/. That is what makes "read-only,
# metadata-only" a structural property of this file rather than a promise
# made in a comment elsewhere.
#
# Requires PROJECT_DIR to already be set by the sourcing script.

# run_classification_task <TASK_NUM> <TARGET_NAME>
# TASK_NUM: zero-padded task number, e.g. "10".
# TARGET_NAME: must have a published, validated inventory/<Target>/metadata.csv.
run_classification_task() {
  local TASK_NUM="$1"
  local TARGET_NAME="$2"
  local target_lower="${TARGET_NAME:l}"

  local INVENTORY_CSV="$PROJECT_DIR/inventory/$TARGET_NAME/metadata.csv"
  local OUTPUT_DIR="$PROJECT_DIR/classification/$TARGET_NAME"
  local FINAL_REPORT_PATH="$PROJECT_DIR/reports/${TASK_NUM}_${target_lower}_classification.txt"
  # -g for the same reason documented at length in inventory_engine.zsh: the
  # EXIT trap fires after this function returns, so anything it references
  # must survive past the function's own scope.
  typeset -g LOCK_DIR="$PROJECT_DIR/logs/.task${TASK_NUM}.lock"

  if [[ "$(/bin/pwd -P)" != "$PROJECT_DIR" ]]; then
    print -u2 -- "ERROR: Run this script from $PROJECT_DIR"
    return 1
  fi

  if [[ ! -f "$INVENTORY_CSV" ]]; then
    print -u2 -- "ERROR: No published inventory found at $INVENTORY_CSV. Run the target's inventory script first."
    return 1
  fi

  if [[ ! -d "$OUTPUT_DIR" ]]; then
    print -u2 -- "ERROR: $OUTPUT_DIR does not exist. Create it before running this task (mirrors the inventory framework's pre-created output directories)."
    return 1
  fi

  # Staleness policy, operator-approved 2026-08-02 (DECISIONS.md D10).
  # Empty values mean "skip the staleness dimension for this target" —
  # Pictures/Movies/Music are intentionally not assigned staleness labels.
  local stale1='' stale2='' stale3=''
  case "$TARGET_NAME" in
    Downloads) stale1=30; stale2=90; stale3=180 ;;
    Documents|Desktop) stale1=180; stale2=365; stale3=730 ;;
    Pictures|Movies|Music) ;;
    *) ;;
  esac

  if ! /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
    local holder_pid=''
    [[ -f "$LOCK_DIR/pid" ]] && holder_pid="$(<"$LOCK_DIR/pid")"
    if [[ -n "$holder_pid" ]] && /bin/kill -0 "$holder_pid" 2>/dev/null; then
      print -u2 -- "ERROR: Another Task $TASK_NUM run (PID $holder_pid) holds the execution lock ($LOCK_DIR). Refusing to run concurrently."
      return 1
    fi
    print -u2 -- "WARNING: Reclaiming stale execution lock (holder PID '${holder_pid:-unknown}' not running)."
    /bin/rm -rf "$LOCK_DIR"
    /bin/mkdir "$LOCK_DIR" || { print -u2 -- 'ERROR: Cannot acquire execution lock.'; return 1; }
  fi
  print -- "$$" > "$LOCK_DIR/pid"

  local CLASSIFICATION_ID="CLS-$(/bin/date '+%Y%m%d')-$(/bin/date '+%H%M%S')"
  typeset -g RUN_DIR
  RUN_DIR="$(/usr/bin/mktemp -d "$OUTPUT_DIR/.task${TASK_NUM}.XXXXXX")" || { /bin/rm -rf "$LOCK_DIR"; print -u2 -- 'ERROR: Cannot create staging directory.'; return 1; }
  local CSV_PATH="$RUN_DIR/classification_proposal.csv"
  local JSON_PATH="$RUN_DIR/classification_proposal.json"
  local SUMMARY_PATH="$RUN_DIR/summary.md"
  local STAGED_REPORT_PATH="$RUN_DIR/${TASK_NUM}_${target_lower}_classification.txt"
  cleanup() { /bin/rm -rf "$RUN_DIR" "$LOCK_DIR"; }
  trap cleanup EXIT HUP INT TERM

  local TIMESTAMP=$(/bin/date '+%Y-%m-%dT%H:%M:%S%z')

  local gen_output
  gen_output="$(/usr/bin/python3 - "$INVENTORY_CSV" "$CSV_PATH" "$JSON_PATH" "$SUMMARY_PATH" "$STAGED_REPORT_PATH" "$CLASSIFICATION_ID" "$TIMESTAMP" "$TARGET_NAME" "$stale1" "$stale2" "$stale3" <<'PY'
import csv, json, sys, datetime

(inventory_csv, out_csv, out_json, out_summary, out_report,
 classification_id, timestamp, target_name,
 stale1, stale2, stale3) = sys.argv[1:12]

# Known ephemeral build/cache path substrings. A file matching one of these
# AND part of an exact name+size match group is treated as structural
# evidence of a regeneratable build artifact, not a claim that two files are
# copies of each other's content.
BUILD_PATTERNS = ['/.build/', '/node_modules/', '/.venv/', '/DerivedData/', 'CompilationCache.noindex']

# Static extension -> type lookup. Anything not listed here is left
# unclassified rather than guessed at.
TYPE_MAP = {
    'pdf': 'document', 'doc': 'document', 'docx': 'document', 'txt': 'document',
    'md': 'document', 'rtf': 'document', 'pages': 'document',
    'xlsx': 'spreadsheet', 'csv': 'spreadsheet', 'numbers': 'spreadsheet',
    'png': 'image', 'jpg': 'image', 'jpeg': 'image', 'heic': 'image', 'gif': 'image',
    'tiff': 'image', 'svg': 'image', 'webp': 'image',
    'py': 'source-code', 'js': 'source-code', 'ts': 'source-code', 'mjs': 'source-code',
    'java': 'source-code', 'c': 'source-code', 'h': 'source-code', 'cpp': 'source-code',
    'swift': 'source-code', 'go': 'source-code', 'rb': 'source-code', 'sh': 'source-code', 'zsh': 'source-code',
    'zip': 'archive', 'tar': 'archive', 'gz': 'archive', 'dmg': 'archive', 'pkg': 'archive',
    'mov': 'video', 'mp4': 'video', 'm4v': 'video',
    'mp3': 'audio', 'm4a': 'audio', 'wav': 'audio', 'aiff': 'audio',
    'json': 'data', 'xml': 'data', 'yaml': 'data', 'yml': 'data',
}

with open(inventory_csv, newline='', encoding='utf-8') as f:
    rows = list(csv.DictReader(f))

inventory_ids = set(r['InventoryID'] for r in rows)
if len(inventory_ids) != 1:
    print(f"ERROR: source inventory has {len(inventory_ids)} distinct InventoryIDs, expected exactly 1", file=sys.stderr)
    sys.exit(1)
source_inventory_id = next(iter(inventory_ids))

records = []
warnings = []


def add(full_path, rel_path, dimension, label, tier, reason, requires_review):
    records.append({
        'ClassificationID': classification_id,
        'SourceInventoryID': source_inventory_id,
        'TargetName': target_name,
        'FullPath': full_path,
        'RelativePath': rel_path,
        'Dimension': dimension,
        'ProposedLabel': label,
        'ConfidenceTier': tier,
        'ConfidenceReason': reason,
        'RequiresReview': 'true' if requires_review else 'false',
    })


def parse_date(s):
    try:
        return datetime.datetime.strptime(s[:19], '%Y-%m-%dT%H:%M:%S')
    except Exception:
        return None


now = datetime.datetime.now()

# Package directories excluded by default (operator-approved 2026-08-02,
# DECISIONS.md D10) — their internals were never inventoried (pruned at
# scan time), so nothing meaningful can be classified about them here.
usable_rows = []
package_skipped = 0
for r in rows:
    if r.get('IsPackage') == 'true':
        package_skipped += 1
        continue
    usable_rows.append(r)

for r in usable_rows:
    if r['IsDirectory'] == 'true':
        continue
    full, rel = r['FullPath'], r['RelativePath']

    # --- project/workspace grouping: top-level path segment, deterministic ---
    parts = rel.split('/') if rel != '.' else []
    group_label = 'workspace:root' if len(parts) <= 1 else f'workspace:{parts[0]}'
    add(full, rel, 'project-grouping', group_label, 'High',
        'Deterministic path read: top-level folder segment under the target root.', False)

    # --- file type / extension ---
    ext = (r.get('Extension') or '[none]').lower()
    if ext in TYPE_MAP:
        add(full, rel, 'file-type', TYPE_MAP[ext], 'High',
            f'Extension .{ext} matched the static type lookup.', False)
    else:
        add(full, rel, 'file-type', 'unclassified-type', 'Low',
            f'Extension {r.get("Extension")!r} is not in the static type lookup.', True)

    # --- staleness (target-specific thresholds; skipped if not configured) ---
    if stale1:
        d = parse_date(r.get('ModificationDate', ''))
        if d is None:
            warnings.append(f'Could not parse ModificationDate for staleness: {rel}')
        else:
            age_days = (now - d).days
            t1, t2, t3 = int(stale1), int(stale2), int(stale3)
            if age_days < t1:
                label, reason = 'fresh', f'Modified {age_days}d ago (< {t1}d).'
            elif age_days < t2:
                label, reason = 'aging', f'Modified {age_days}d ago ({t1}-{t2}d).'
            elif age_days < t3:
                label, reason = 'stale', f'Modified {age_days}d ago ({t2}-{t3}d).'
            else:
                label, reason = 'very-stale', f'Modified {age_days}d ago (> {t3}d).'
            add(full, rel, 'staleness', label, 'High', reason, False)

# --- duplicate-risk, within this target only (operator-approved scope, D10) ---
name_size_groups = {}
name_only_groups = {}
for r in usable_rows:
    if r['IsDirectory'] == 'true':
        continue
    try:
        size = int(r['SizeBytes'])
    except (ValueError, KeyError):
        size = None
    if not size:
        continue
    name_size_groups.setdefault((r['Name'], size), []).append(r)
    name_only_groups.setdefault(r['Name'], []).append(r)

for (name, size), group in name_size_groups.items():
    if len(group) < 2:
        continue
    all_build_pattern = all(any(p in row['FullPath'] for p in BUILD_PATTERNS) for row in group)
    for row in group:
        if all_build_pattern:
            add(row['FullPath'], row['RelativePath'], 'duplicate-risk', 'regeneratable-build-artifact', 'High',
                f'Exact name+size match ({size} bytes) across {len(group)} entries, all inside known build/cache paths.',
                False)
        else:
            add(row['FullPath'], row['RelativePath'], 'duplicate-risk', 'possible-duplicate-candidate', 'Medium',
                f'Exact name+size match ({size} bytes) across {len(group)} entries. Name+size is a heuristic, '
                'not a content-hash proof (RISK_REGISTER R8).', True)

for name, group in name_only_groups.items():
    sizes = {int(r['SizeBytes']) for r in group if r.get('SizeBytes', '').isdigit()}
    if len(group) < 2 or len(sizes) < 2:
        continue
    for row in group:
        add(row['FullPath'], row['RelativePath'], 'duplicate-risk', 'same-name-different-size', 'Low',
            f'{len(group)} entries share the name {name!r} with differing sizes — possibly different revisions.',
            True)

with open(out_csv, 'w', newline='', encoding='utf-8') as f:
    fieldnames = ['ClassificationID', 'SourceInventoryID', 'TargetName', 'FullPath', 'RelativePath',
                  'Dimension', 'ProposedLabel', 'ConfidenceTier', 'ConfidenceReason', 'RequiresReview']
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    for rec in records:
        w.writerow(rec)

with open(out_json, 'w', encoding='utf-8') as f:
    json.dump(records, f, indent=2)

tier_counts = {'High': 0, 'Medium': 0, 'Low': 0}
dim_counts = {}
for rec in records:
    tier_counts[rec['ConfidenceTier']] = tier_counts.get(rec['ConfidenceTier'], 0) + 1
    dim_counts[rec['Dimension']] = dim_counts.get(rec['Dimension'], 0) + 1
review_queue = [r for r in records if r['RequiresReview'] == 'true']

with open(out_summary, 'w', encoding='utf-8') as f:
    f.write(f"# Classification Summary — {target_name} (DRY RUN — proposal only)\n\n")
    f.write(f"- Classification ID: {classification_id}\n")
    f.write(f"- Source Inventory ID: {source_inventory_id}\n")
    f.write(f"- Timestamp: {timestamp}\n")
    f.write(f"- Total records: {len(records)}\n")
    f.write(f"- Package directories excluded: {package_skipped}\n\n")
    f.write("## Confidence breakdown\n")
    for tier in ['High', 'Medium', 'Low']:
        f.write(f"- {tier}: {tier_counts.get(tier, 0)}\n")
    f.write("\n## By dimension\n")
    for dim, cnt in sorted(dim_counts.items()):
        f.write(f"- {dim}: {cnt}\n")
    f.write(f"\n## Review queue\n- {len(review_queue)} record(s) require human review (Medium/Low tier). "
            "High-tier records may be proposed automatically but nothing is auto-applied — this project has no mutation phase yet.\n")
    f.write("\n## Warnings\n")
    if warnings:
        for w_ in warnings[:50]:
            f.write(f"- {w_}\n")
        if len(warnings) > 50:
            f.write(f"- ...and {len(warnings) - 50} more\n")
    else:
        f.write("- None\n")
    f.write("\n## Known limitations\n")
    f.write("- Duplicate-risk detection compares exact Name+SizeBytes only; fuzzy near-duplicate name matching "
            "(e.g. \"file copy.ext\", \"file (1).ext\") is not implemented in this version.\n")
    f.write("- Duplicate-risk comparison is scoped within this target only, per operator decision (DECISIONS.md D10).\n")
    f.write("\n---\n")
    f.write(f"Footer: Classification {classification_id} is a read-only proposal. It does not authorize, stage, "
            "or perform any file move, rename, copy, delete, or tag.\n")

with open(out_report, 'w', encoding='utf-8') as f:
    f.write(f"LifeOS Organizer — {target_name} Classification Proposal (DRY RUN)\n")
    f.write(f"Classification ID: {classification_id}\n")
    f.write(f"Source Inventory ID: {source_inventory_id}\n")
    f.write(f"Timestamp: {timestamp}\n")
    f.write(f"Total records: {len(records)}\n")
    f.write(f"Confidence — High: {tier_counts.get('High', 0)}, Medium: {tier_counts.get('Medium', 0)}, "
            f"Low: {tier_counts.get('Low', 0)}\n")
    f.write(f"Review queue: {len(review_queue)}\n")
    f.write(f"Warnings: {len(warnings)}\n")
    f.write(f"Safety result: no user file was modified, moved, renamed, deleted, copied, or opened for content "
            f"inspection. Input was inventory/{target_name}/metadata.csv only — the filesystem was not rescanned.\n")

print(f"Completed {classification_id}: {len(records)} records "
      f"({tier_counts.get('High', 0)} high / {tier_counts.get('Medium', 0)} medium / {tier_counts.get('Low', 0)} low), "
      f"{len(review_queue)} in review queue, {len(warnings)} warnings.")
PY
)"
  local gen_exit=$?
  if (( gen_exit != 0 )); then
    print -u2 -- "ERROR: Classification generation failed."
    print -u2 -- "$gen_output"
    return 1
  fi

  if ! /usr/bin/python3 - "$CSV_PATH" "$JSON_PATH" "$SUMMARY_PATH" "$STAGED_REPORT_PATH" "$CLASSIFICATION_ID" "$INVENTORY_CSV" <<'PY'
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
inv_ids = set(r['InventoryID'] for r in inv_rows)
if len(inv_ids) != 1:
    raise SystemExit("Source inventory has more than one InventoryID; cannot validate traceability")
expected_source_id = next(iter(inv_ids))
valid_paths = set(r['FullPath'] for r in inv_rows)
valid_tiers = {'High', 'Medium', 'Low'}

# R11 plausibility guard (DECISIONS.md D16): refuse to publish an empty
# classification when the source inventory has usable non-package files.
# Consistency checks above would pass (0 == 0) for a silently failed
# generation — the same D14/R10 failure class one layer up the pipeline.
usable_files = sum(
    1 for r in inv_rows
    if r.get('IsPackage') != 'true' and r.get('IsDirectory') == 'false'
)
allow_empty = os.environ.get('ALLOW_EMPTY_RESULT', '0') == '1'
if usable_files > 0 and len(records) == 0 and not allow_empty:
    raise SystemExit(
        f"Plausibility guard: source inventory has {usable_files} usable file(s) but "
        "classification produced 0 records. Refusing to publish; previous artifact untouched. "
        "Rerun after fixing generation, or set ALLOW_EMPTY_RESULT=1 to bypass explicitly."
    )

for rec in records:
    if rec.get('ClassificationID') != classification_id:
        raise SystemExit("Record with inconsistent ClassificationID")
    if rec.get('SourceInventoryID') != expected_source_id:
        raise SystemExit("Record with inconsistent SourceInventoryID")
    if rec.get('ConfidenceTier') not in valid_tiers:
        raise SystemExit(f"Invalid ConfidenceTier: {rec.get('ConfidenceTier')}")
    expected_review = 'false' if rec['ConfidenceTier'] == 'High' else 'true'
    if rec.get('RequiresReview') != expected_review:
        raise SystemExit(f"RequiresReview inconsistent with tier for {rec.get('FullPath')}")
    if rec.get('FullPath') not in valid_paths:
        raise SystemExit(f"Record references a path not present in the source inventory: {rec.get('FullPath')}")

for path in (summary_path, report_path):
    with open(path, encoding='utf-8') as f:
        if classification_id not in f.read():
            raise SystemExit(f"Missing Classification ID in {path}")

print("VALIDATE_OK")
PY
  then
    print -u2 -- 'ERROR: Staged classification artifact validation failed; no output was published.'
    return 1
  fi

  /bin/mv "$CSV_PATH" "$OUTPUT_DIR/classification_proposal.csv" || return 1
  /bin/mv "$JSON_PATH" "$OUTPUT_DIR/classification_proposal.json" || return 1
  /bin/mv "$SUMMARY_PATH" "$OUTPUT_DIR/summary.md" || return 1
  /bin/mv "$STAGED_REPORT_PATH" "$FINAL_REPORT_PATH" || return 1
  print -- "$gen_output"
}
